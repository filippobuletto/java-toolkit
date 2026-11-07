---
name: java-assess
description: Read-only audit of a Java project before a JDK upgrade. Runs the plugin's detect and scan scripts, a baseline build, and jdeps / jdeprscan / javac lint on compiled classes, then writes .java-upgrade/assessment.md listing breaking changes, obsolete JVM flags, build-blocker libraries and modernization candidates for a given current and target JDK.
when_to_use: Called by the java-upgrade router in its assess step, or when the user asks what would break or what needs changing to move a Java codebase to a newer JDK, asks for a JDK compatibility report, or wants to know which internal or deprecated APIs the code uses.
argument-hint: "[project-root] [from-jdk] [to-jdk]"
---

# Java upgrade assessment

Read-only: never edit project files. Only write inside `.java-upgrade/`.

Inputs: project root (default cwd), `from` and `to` feature releases. If `from` is missing take `java_release` from detect; if `to` is missing ask.

Scripts live in the router skill:

- `bash ${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/scripts/detect.sh <root>`
- `bash ${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/scripts/scan.sh <root> --from <from> --to <to> [--summary]`

## 1. Facts

Run detect. Record build tool, wrapper, versions, `uses`, CI/Docker/pinned JDKs, installed `jdk.N` homes. Note which JDKs the hop chain needs and which of them are missing.

## 2. Baseline build

Build and test on the current JDK with the wrapper when present:

- Maven: `JAVA_HOME=<jdk.from> ./mvnw -B -ntp verify` (or `mvn`)
- Gradle: `JAVA_HOME=<jdk.from> ./gradlew build`

Record result and test count. If `jdk.from` is not installed use the closest installed JDK that is still at least `from` and say so. A failing baseline is the first finding; continue the static parts but mark the assessment `baseline: red`.

## 3. Static scan

Run `scan.sh --summary` first for counts, then the full output for the signal ids that need file lists. Group by category: `removed`, `flag`, `deprecated`, `behavior`, `build`, `modernize`. For large repos (more than ~50 hits for one id) keep the count and the top directories, not every line.

Regex signals give candidates, not proof. Open a sample of each id and drop false positives (comments, strings, test fixtures) before reporting.

## 4. Class-file tools (when the build produced classes)

Use the target JDK's tools when installed (`<jdk.to>/bin/...`), else the newest installed JDK with `--release`/`--multi-release` capped at its version.

Classpath:

- Maven: `./mvnw -q dependency:build-classpath -Dmdep.outputFile=.java-upgrade/classpath.txt`
- Gradle: run without a classpath; add one only if results are incomplete.

Commands (classes dir: Maven `target/classes`, Gradle `build/classes/java/main`):

```bash
jdeps --jdk-internals --multi-release <to> --class-path "$(cat .java-upgrade/classpath.txt)" target/classes
jdeprscan --release <to> --for-removal --class-path "$(cat .java-upgrade/classpath.txt)" target/classes
```

Also run `jdeps --jdk-internals --multi-release <to>` on each dependency jar from the classpath: old libraries that use JDK internals are the usual blocker on 16+ and need a version bump, not a code change. Report library name and version for each hit.

`jdeprscan --for-removal` does not accept `--release` 8 or lower; that is fine because targets are 9+.

## 5. Write `.java-upgrade/assessment.md`

```markdown
# Assessment: JDK <from> → <to>

Baseline: green|red (<command>, <n> tests)
Hop chain: <a>→<b>→… ; missing JDKs: <list or none>

## Build
<tool, wrapper, plugin versions, release setting and where it is set, modules>

## Must fix (removed, flag)
| Signal | JDK | Hits | Where | Fix reference |

## Will warn or change behavior (deprecated, behavior)
| Signal | JDK | Hits | Where | Note |

## Build blockers
| Library | Found version | Needed for <to> |

## JDK internals (jdeps) and for-removal APIs (jdeprscan)
| Class or jar | API | Replacement |

## Modernization candidates (optional)
| Feature | Min JDK | Hits | Example location |

## Out of scope / prerequisites
<framework majors, javax→jakarta namespace moves, anything this plugin does not change>
```

Each "Fix reference" names the hop file in `java-migrate/references/` or `java-build/references/`, taken from the "Removals and breaking changes" table in `${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/references/jdk-matrix.md`.

Return a short summary to the caller: baseline status, counts per category, missing JDKs, prerequisites.
