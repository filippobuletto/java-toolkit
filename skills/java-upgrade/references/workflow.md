# Upgrade workflow: state files and templates

The router keeps all upgrade state in `.java-upgrade/` at the project root, so a session can resume after compaction or restart. Suggest adding `.java-upgrade/` to `.gitignore` unless the user wants the plan versioned.

| File | Written by | When |
|------|-----------|------|
| `assessment.md` | java-assess | Before planning; refreshed at the start of each hop |
| `plan.md` | java-upgrade | After assessment; the user confirms it before any edit |
| `progress.md` | java-upgrade | Updated after every step |
| `summary.md` | java-upgrade | When the last hop is verified |

## Resume rule

If `.java-upgrade/progress.md` exists, read it before anything else, report the current step to the user, and continue from the first step that is not `done`. Re-run `detect.sh` to confirm the build still matches what progress claims.

## Hop chain

1. `from` = `java_release` from `detect.sh`. If empty, read the build file; if still unknown, ask.
2. `to` = user's target. Never assume it.
3. Chain = LTS releases strictly between `from` and `to`, then `to`: 8→21 is 8→11→17→21; 17→27 is 17→21→25→27; 25→26 is one hop.
4. Each hop ends with a green build and green tests on the hop's JDK before the next hop starts.
5. The user may ask to jump directly (for example 8→17 in one step). Allow it, but still apply every hop reference in order within the step.

## Stop rules

Stop and report to the user, without improvising a workaround, when:

- The baseline build or tests fail on the current JDK before any change.
- A hop needs a JDK that is not installed. Name the JDK and suggest `sdk install java <version>` (or the platform equivalent); do not install it.
- A fix needs a dependency change outside build-blocker scope (for example a framework major upgrade such as Spring Boot 2 → 3). Record it in the plan as a prerequisite. Quarkus upgrades go to `java-framework-upgrade`.
- A test fails after a step and the cause is not understood after one focused investigation.
- The only fix would weaken or delete a test.

## plan.md template

```markdown
# Java upgrade plan: <project>

## Goal
JDK <from> → <to>, build tool <maven|gradle> <version>.

## Options (confirm or change)
- Working branch: java-upgrade/<to> (yes/no)
- Run tests after every step: yes
- Adopt newer language features (java-modernize): no | yes, features: <list>
- Preview features: no

## Current state
- Build: <tool, wrapper, version, modules>
- JDK: release <from> (from <setting>), CI <ci_java>, Docker <docker_java>
- Installed JDKs: <list>
- Build-blocker libraries: <uses>

## Prerequisites outside this plan
- <framework or library upgrades the user must decide on>

## Hops
### Hop 1: <a> → <b>
| # | Step | Skill / reference | Verification |
|---|------|-------------------|--------------|
| 1 | Bump build tool and plugins | java-build | `<build command>` on JDK <a> still green |
| 2 | Set release <b>, build on JDK <b> | java-build | compiles on JDK <b> |
| 3 | Fix breaking signals: <ids> | java-migrate <a>-to-<b> | build + tests green on JDK <b> |
| 4 | Update CI / Docker / scripts JDK and flags | java-migrate | grep shows no obsolete flags |

### Hop 2: …

## Modernization (only if opted in)
| Feature | Signals | Files | Verification |
|---------|---------|-------|--------------|

## Risks
- <behavior changes to watch: charset, reflection, agents, GC>
```

## progress.md template

```markdown
# Progress

| Hop | Step | Status | Evidence |
|-----|------|--------|----------|
| 8→11 | 1 build plugins | done | `./mvnw -q verify` green on JDK 8 (12 tests) |
| 8→11 | 2 release 11 | in progress | |

## Log
- <date> <what changed> — <why> — <how verified>
```

Status values: `todo`, `in progress`, `done`, `blocked: <reason>`.

## summary.md template

```markdown
# Java upgrade summary

| | Before | After |
|-|--------|-------|
| JDK release | | |
| Build tool | | |
| Compiler / test plugins | | |
| Build-blocker libraries | | |
| Tests | <n> passing | <n> passing |

## Changes by hop
## Remaining warnings (jdeprscan, javac -Xlint, runtime)
## Not done / follow-ups
```

## Build commands

Prefer the wrapper. Select the JDK per command without changing global state:

- Maven: `JAVA_HOME=<jdk.N> ./mvnw -B -ntp verify` (or `mvn` when there is no wrapper)
- Gradle: `JAVA_HOME=<jdk.N> ./gradlew build` for running Gradle itself; toolchains decide the compile JDK
- Read `jdk.N` paths from `detect.sh` output.
