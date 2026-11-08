---
name: java-framework-upgrade
description: Plans and runs framework upgrades for Java projects, one LTS stream at a time, as a companion to the java-upgrade JDK skills. Supports Quarkus from 2.13 to 3.40 (4.0 beta on opt-in). Detects the framework version, extensions and JDK, writes a plan that interleaves framework hops with the JDK hops they need, waits for approval, then routes each hop to the framework skill and verifies the build after every step.
when_to_use: User asks to upgrade, migrate or update a Quarkus application or its Quarkus version (for example "upgrade to Quarkus 3.40", "migrate from Quarkus 2 to 3", "move to the latest Quarkus LTS", "run quarkus update"), asks what blocks a framework upgrade, asks for a framework and JDK upgrade together, or resumes an upgrade that has a .framework-upgrade/ folder.
argument-hint: "[framework] [target-version] [assess|plan|apply|resume]"
---

# Framework upgrade router

Hard rules (apply to every step):

1. Never assume the target. Ask when `$ARGUMENTS` has none.
2. No edits before the user confirms `.framework-upgrade/plan.md`. Green baseline first.
3. One LTS hop at a time, each pinned to its stream. Build and tests must pass on the hop's JDK before the next hop.
4. A hop whose minimum JDK is above the build JDK waits for a JDK hop run by `java-toolkit:java-upgrade`. Never raise the JDK inside a framework step.
5. The git tree must be clean before each recipe run. Never commit, push or branch unless the plan says so.
6. Beta and preview targets (Quarkus 4.0) run only when the user opted in in the plan.
7. Never weaken, skip or delete tests. Name every escape-hatch property in progress.md.
8. Version facts come from the framework matrix (Quarkus: `${CLAUDE_PLUGIN_ROOT}/skills/java-quarkus-migrate/references/quarkus-matrix.md`) and JDK facts from `${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/references/jdk-matrix.md`.
9. Do not install JDKs or framework CLIs. If a hop needs one that is missing and no build-plugin fallback exists, stop and say which.

## Arguments

`$ARGUMENTS` may hold a framework (`quarkus`), a target (`3.40`, `latest`, `4.0`) and a mode:

| Mode | Does |
|------|------|
| `assess` | Steps 1–2 only, no plan |
| `plan` (default) | Steps 1–4, then waits for confirmation |
| `apply` | Executes a confirmed plan.md (step 5) |
| `resume` | Reads progress.md and continues |

If `.framework-upgrade/progress.md` exists and no mode is given, ask whether to resume.

## Step 1: detect

Run `bash ${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/scripts/detect.sh <project-root>`. Framework keys: `quarkus_version`, `quarkus_stream`, `quarkus_platform`, `quarkus_plugin`, `quarkus_extensions`, `quarkus_cli`. JDK keys: `java_release`, `ci_java`, `docker_java`, `jdk.N=<home>`.

- No framework detected: say which frameworks are supported and stop.
- `quarkus_stream` below 2.13: `quarkus update` does not support it. Stop and say the project must reach 2.13 by hand first.
- `quarkus_platform` is `io.quarkus` (core BOM, not the platform): note it; Quarkiverse versions must then be managed by hand.
- Multi-module: read child build files too; the version may be set per module.

Ask for the target if it is missing. Offer the next LTS above the current stream, the latest LTS (3.40), and 4.0 marked beta.

## Step 2: assess

Read-only. Write `.framework-upgrade/assessment.md` with:

- Baseline build and test result on the current JDK (`JAVA_HOME=<jdk.N>`, wrapper preferred), with the test count. A red baseline stops the upgrade.
- Hop chain (see [workflow.md](references/workflow.md)) with each hop's minimum JDK, and the JDK hops it forces.
- `scan.sh <root> --framework quarkus --from <current> --to <target> --summary`, then full output for the ids that need file lists. Open a sample of each id and drop false positives.
- Extensions outside the core platform (Quarkiverse, third party) and whether each has a release for the target stream.
- Installed JDKs and CLI versus what the chain needs.

## Step 3: route

| Work | Route to |
|------|----------|
| Quarkus hop (recipe run, manual items, verification) | `java-toolkit:java-quarkus-migrate` with the hop (`3.20-to-3.27`) |
| JDK hop the chain needs | `java-toolkit:java-upgrade` with the target JDK; it keeps its own `.java-upgrade/` state |
| Build tool or wrapper too old for the target (see the matrix Maven column) | `java-toolkit:java-build` |
| Newer Java language features | `java-toolkit:java-modernize`, only after the last hop, only if opted in |

## Step 4: plan

Write `.framework-upgrade/plan.md` from the template in [workflow.md](references/workflow.md): goal, options, current state, prerequisites, ordered steps (JDK hops interleaved with framework hops), verification per step, risks. Show the summary, including the 4.0 opt-in and the commit option, and stop until the user confirms.

## Step 5: apply

For each step in plan order:

1. Mark it `in progress` in `.framework-upgrade/progress.md`.
2. Invoke the routed skill with the exact scope. JDK steps run the full `java-upgrade` flow, including its own plan confirmation. Mark the step `done` only when its summary.md exists.
3. Verify with the step's command on the right JDK. Compare test counts with the baseline.
4. Mark `done` with evidence, or `blocked: <reason>` and follow the stop rules in workflow.md.

After the last step, write `.framework-upgrade/summary.md`.

## Additional resources

- [references/workflow.md](references/workflow.md): state files, hop chain with JDK interleave, stop rules, plan/progress/summary templates. Load in steps 2–5.
- `${CLAUDE_PLUGIN_ROOT}/skills/java-quarkus-migrate/references/quarkus-matrix.md`: Quarkus LTS streams, JDK minimums, update commands.
- `scripts/quarkus.tsv`: Quarkus signal catalog, read by `scan.sh --framework quarkus`. Not loaded.
