---
name: java-upgrade
description: Plans and runs Java JDK upgrades from 8 up to 27 for Maven or Gradle projects. Detects the current JDK and build setup, scans the code for removed APIs, obsolete JVM flags and modernization candidates, writes a hop-by-hop plan for user approval, then routes each step to the java-build, java-migrate and java-modernize skills and verifies the build after every step.
when_to_use: User asks to upgrade, migrate or move a Java project to a newer JDK or Java version (for example "upgrade to Java 21", "migrate from Java 8 to 17", "make this build on JDK 25"), asks what blocks a JDK upgrade, or resumes an upgrade that has a .java-upgrade/ folder.
argument-hint: "[target-jdk] [assess|plan|apply|resume]"
---

# Java upgrade router

Hard rules (apply to every step):

1. Never assume the target JDK. Ask when `$ARGUMENTS` has none.
2. No edits before the user confirms `.java-upgrade/plan.md`.
3. One hop at a time through LTS releases; green build and tests on the hop's JDK before the next hop.
4. Green baseline first: if the build fails on the current JDK before changes, stop and report.
5. Never adopt preview features, and never apply java-modernize changes, unless the user opted in in the plan.
6. Never weaken, skip or delete tests to get green. Never add `-Xlint:none`, `-nowarn` or `--add-opens` blanket flags to silence a problem without naming it in progress.md.
7. Keep JDK-owned `javax.*` packages (`javax.sql`, `javax.naming`, `javax.crypto`, `javax.net`, `javax.security.auth`, `javax.swing`, `javax.xml.parsers`, `javax.annotation.processing`, `javax.script`, `javax.tools`, `javax.transaction.xa`). Only Java EE ones were removed.
8. Keep explicit charsets such as `StandardCharsets.UTF_8`.
9. Version facts come from [jdk-matrix.md](references/jdk-matrix.md). Do not use String Templates, `-XX:+ZGenerational`, `StructuredTaskScope.ShutdownOnFailure`, or `with` record expressions in any advice.
10. Do not install JDKs. If a hop needs one that is missing, stop and tell the user which one.

## Arguments

`$ARGUMENTS` may hold a target (`21`, `java 25`, `27`) and a mode:

| Mode | Does |
|------|------|
| `assess` | Steps 1–2 only, no plan |
| `plan` (default) | Steps 1–4, then waits for confirmation |
| `apply` | Executes a confirmed plan.md (step 5) |
| `resume` | Reads progress.md and continues |

If `.java-upgrade/progress.md` exists and no mode is given, ask whether to resume.

## Step 1: detect

Run `bash ${CLAUDE_SKILL_DIR}/scripts/detect.sh <project-root>`. Keys: `build_tool`, `wrapper`, `java_release`, `java_release_from`, plugin and wrapper versions, `uses` (build-blocker libraries), `ci_java`, `docker_java`, `pinned_java`, `jdk.N=<home>` per installed JDK, and `quarkus_*` keys when the project uses Quarkus.

- `build_tool=none`: not a Maven/Gradle project; ask how it is built before going further.
- Multi-module (`maven_modules` > 0, or Gradle subprojects): the release may be set per module; read child build files too.
- Several JDKs disagree (build vs CI vs Docker): report them all; the build file wins for `from`.

Then ask for the target if missing. Offer: next LTS above `from`, latest LTS (25), latest GA (27).

## Step 2: assess

Invoke the `java-toolkit:java-assess` skill with the project root, `from` and `to`. It writes `.java-upgrade/assessment.md` with signals from `scripts/scan.sh` and, when the project builds, `jdeps` and `jdeprscan` results. Confirm the baseline build result is in it.

## Step 3: route

Map assessment findings to skills:

| Finding | Route to |
|---------|----------|
| Build tool, wrapper, compiler/surefire plugin versions, `release`, toolchains, CI/Docker JDK | `java-toolkit:java-build` |
| `build` signals (Lombok, MapStruct, JaCoCo, Byte Buddy, Mockito agent, Error Prone, Kotlin, AspectJ) | `java-toolkit:java-build` (references/build-blockers.md) |
| `removed`, `deprecated`, `behavior`, `flag` signals, jdeps internal API use, jdeprscan for-removal hits | `java-toolkit:java-migrate` with the hop (`8-to-11`, `11-to-17`, `17-to-21`, `21-to-25`, `25-to-27`) |
| `modernize` signals, or the user asks for newer language features | `java-toolkit:java-modernize` (only after the last hop is green, and only if opted in) |
| Quarkus upgrade, or a Quarkus version whose minimum or recommended JDK conflicts with the target (`quarkus_version` from detect, facts in `${CLAUDE_PLUGIN_ROOT}/skills/java-quarkus-migrate/references/quarkus-matrix.md`) | `java-toolkit:java-framework-upgrade`: list it as a prerequisite step and hand over; that router interleaves JDK hops |
| Other framework upgrades (Spring Boot, Jakarta EE, Hibernate, JUnit majors) | Out of scope: list as prerequisites in the plan |

## Step 4: plan

Write `.java-upgrade/plan.md` from the template in [workflow.md](references/workflow.md): goal, options, current state, prerequisites, hops with numbered steps and a verification per step, optional modernization table, risks. Ordering inside a hop:

1. Build tool and plugin versions that also work on the current JDK (keeps the build green before the switch).
2. Build-blocker library bumps.
3. Switch release/toolchain to the hop's JDK.
4. Breaking-change fixes from the hop reference.
5. CI, Docker and launch-script JDK and flags.

Show the plan summary to the user and ask for confirmation, including the modernization and preview options. Stop here until they confirm.

## Step 5: apply

For each step in plan order:

1. Mark it `in progress` in `.java-upgrade/progress.md`.
2. Invoke the routed skill for that step with the exact scope (files, signal ids, hop). Keep the edit minimal.
3. Verify with the step's command using the right JDK (`JAVA_HOME=<jdk.N>` from detect output). Compare test counts with the baseline.
4. Mark `done` with evidence (command and result), or `blocked: <reason>` and follow the stop rules in workflow.md.

At the end of each hop re-run `scan.sh --from <a> --to <b>`. `flag` hits must be gone. `removed` hits that stay because the fix was a dependency (JAXB, Nashorn standalone) count as resolved once the build and a call through that code pass on the hop JDK; list them under "Remaining scan hits (explained)" in progress.md with that evidence, together with confirmed false positives.

After the last hop: write `.java-upgrade/summary.md`, then offer modernization if it was not opted in.

## Additional resources

- [references/jdk-matrix.md](references/jdk-matrix.md): feature status and minimum JDK, removals by release, flag changes, corrections. Load when any version fact is needed.
- [references/workflow.md](references/workflow.md): state files, resume rule, hop chain, stop rules, plan/progress/summary templates, build commands. Load in steps 4–5.
- `scripts/detect.sh`, `scripts/scan.sh`, `scripts/signals.tsv`: executed, not loaded. `scan.sh --help` prints usage.
