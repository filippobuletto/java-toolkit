# Framework upgrade workflow: state files and templates

The router keeps framework upgrade state in `.framework-upgrade/` at the project root. JDK hops keep their own state in `.java-upgrade/`. Suggest adding both to `.gitignore` unless the user wants the plan versioned.

| File | Written by | When |
|------|-----------|------|
| `assessment.md` | java-framework-upgrade | Before planning; refreshed at the start of each hop |
| `plan.md` | java-framework-upgrade | After assessment; the user confirms it before any edit |
| `progress.md` | java-framework-upgrade | Updated after every step |
| `summary.md` | java-framework-upgrade | When the last step is verified |

## Resume rule

If `.framework-upgrade/progress.md` exists, read it before anything else, report the current step, and continue from the first step that is not `done`. Re-run `detect.sh` to confirm that `quarkus_version` and `java_release` match what progress claims. If a JDK step is `in progress`, resume `java-upgrade` first.

## Hop chain

1. `from` = `quarkus_stream` from `detect.sh`. If it is not an LTS, the first hop goes to the next LTS above it.
2. `to` = the user's target. Never assume it.
3. Chain = Quarkus LTS streams strictly between `from` and `to`, then `to`. LTS streams: 3.2, 3.8, 3.15, 3.20, 3.27, 3.33, 3.40 (4.0 beta). For example, 2.16 → 3.40 runs 3.2, 3.8, 3.15, 3.20, 3.27, 3.33, 3.40, and 3.22 → 3.33 runs 3.27, 3.33.
4. The user may ask to jump in one recipe run (for example `--stream=3.40` from 3.8). Allow it, but still apply every hop reference in order and keep the JDK interleave.

## JDK interleave

Before each framework hop, compare the hop's minimum JDK (matrix) with the project's `java_release` at that point in the plan:

- Minimum above the release: insert a JDK step to the minimum, or to the user's JDK target if that is higher and supported by the hop, before the framework hop.
- User wants a JDK above what the current framework supports: put the JDK step after the framework hop that supports it.
- JDK target set but not forced: offer it as the last step, after the last framework hop.

Example, Quarkus 2.16 on JDK 11 → 3.40 with JDK 21:

```text
1  Quarkus 2.16 → 3.2       JDK 11
2  JDK 11 → 17              java-upgrade (3.7+ needs 17)
3  Quarkus 3.2 → 3.8        JDK 17
4  Quarkus 3.8 → … → 3.40   JDK 17, one step per LTS
5  JDK 17 → 21              java-upgrade (optional, user target)
```

## Stop rules

Stop and report, without improvising a workaround, when:

- The baseline build or tests fail before any change.
- The git tree is dirty before a recipe run.
- A hop needs a JDK that is not installed. Name it and suggest `sdk install java <version>`; do not install it.
- Neither the CLI (at least the target stream) nor the Maven/Gradle plugin form can run the update.
- A Quarkiverse or third-party extension has no release for the target stream.
- A test fails after a step and the cause is not understood after one focused investigation.
- The only fix would weaken or delete a test, or lower a database version check without the user's agreement.

## plan.md template

```markdown
# Framework upgrade plan: <project>

## Goal
Quarkus <from> → <to>, JDK <release> → <release>, build tool <maven|gradle> <version>.

## Options (confirm or change)
- Working branch: framework-upgrade/<to> (yes/no)
- Commit after each verified hop: no | yes
- Quarkus 4.0 beta: no
- JDK target: <keep minimum | N>
- Adopt newer language features (java-modernize): no

## Current state
- Quarkus: <version>, platform <group>, plugin <version>, CLI <version or none>
- Extensions: <list>; outside the platform: <list with target-stream availability>
- JDK: release <n>, CI <ci_java>, Docker <docker_java>; installed <list>

## Prerequisites outside this plan
- <extensions without a target release, database upgrades, missing JDKs>

## Steps
| # | Step | JDK | Skill / reference | Verification |
|---|------|-----|-------------------|--------------|
| 1 | Quarkus 2.16 → 3.2 | 11 | java-quarkus-migrate 2.13-to-3.2 | build + tests green on JDK 11 |
| 2 | JDK 11 → 17 | 17 | java-upgrade 17 | its summary.md, build + tests green on JDK 17 |
| 3 | Quarkus 3.2 → 3.8 | 17 | java-quarkus-migrate 3.2-to-3.8 | build + tests green on JDK 17 |

## Risks
- <behavior changes to watch: threading, transactions, Hibernate query semantics, Dev Services defaults>
```

## progress.md template

```markdown
# Progress

| # | Step | Status | Evidence |
|---|------|--------|----------|
| 1 | Quarkus 2.16 → 3.2 | done | `quarkus update --stream=3.2`, 41 files; `./mvnw -B -ntp verify` green on JDK 11 (12 tests) |
| 2 | JDK 11 → 17 | in progress | .java-upgrade/progress.md |

## Recipe changes outside the hop reference
## Remaining scan hits (explained)
## Escape hatches (temporary)
## Log
- <date> <what changed> — <why> — <how verified>
```

Status values: `todo`, `in progress`, `done`, `blocked: <reason>`.

## summary.md template

```markdown
# Framework upgrade summary

| | Before | After |
|-|--------|-------|
| Quarkus | | |
| JDK release | | |
| Hibernate ORM | | |
| Extensions renamed | | |
| Tests | <n> passing | <n> passing |

## Changes by hop
## Escape hatches still in place
## Not done / follow-ups
```

## Build commands

Prefer the wrapper. Select the JDK per command without changing global state:

- Maven: `JAVA_HOME=<jdk.N> ./mvnw -B -ntp verify`
- Gradle: `JAVA_HOME=<jdk.N> ./gradlew build`
- Read `jdk.N` paths from `detect.sh` output.
