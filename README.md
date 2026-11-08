<div align="center">

# java-toolkit

A Claude Code plugin with skills for Java projects. Its first skill set upgrades Java projects from JDK 8 up to JDK 27. It reads your Maven or Gradle build and your code, writes a plan you approve, then moves the project one LTS release at a time and checks the build and tests after every step. Optional skills adopt newer language features such as records, pattern matching and virtual threads. A secure-coding skill reviews and writes Java code against the Oracle Secure Coding Guidelines for Java SE. A SOLID skill reviews and writes Java code against the five SOLID design principles.

[![Version](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fraw.githubusercontent.com%2Ffilippobuletto%2Fjava-toolkit%2Fmain%2F.claude-plugin%2Fplugin.json&query=%24.version&label=version)](.claude-plugin/plugin.json)
[![License](https://img.shields.io/github/license/filippobuletto/java-toolkit)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-D97757?logo=claude&logoColor=white)](https://code.claude.com/docs/en/plugins)
[![Java](https://img.shields.io/badge/JDK-8%E2%80%9327-ED8B00?logo=openjdk&logoColor=white)](skills/java-upgrade/references/jdk-matrix.md)
[![Bash](https://img.shields.io/badge/shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)](skills/java-upgrade/scripts)

</div>

```text
/java-toolkit:java-upgrade 21
```

## How it works

The `java-upgrade` skill is the entry point. It routes work to four focused skills:

| Skill | Role |
| :- | :- |
| `java-upgrade` | Detects the build and JDKs, asks for the target, writes `.java-upgrade/plan.md`, runs the confirmed plan step by step, tracks `progress.md`, writes `summary.md` |
| `java-assess` | Read-only audit: baseline build, signal scan, `jdeps --jdk-internals`, `jdeprscan --for-removal`; writes `assessment.md` |
| `java-build` | Maven and Gradle changes: `release` and toolchains, wrapper and plugin versions, annotation processors, Mockito agent, build-blocker libraries (Lombok, JaCoCo, Byte Buddy, Error Prone, Kotlin), CI and Docker JDK |
| `java-migrate` | Fixes what each hop breaks: 8→11, 11→17, 17→21, 21→25, 25→27 |
| `java-modernize` | Optional feature adoption gated by the project's release, with "do not convert when" rules |

Two scripts do the mechanical part. `detect.sh` reports build tool, wrapper, Java release and where it is set, plugin versions, build-blocker libraries, CI/Docker/pinned JDKs and the JDKs installed on the machine. `scan.sh` runs a catalog of patterns (`signals.tsv`) over sources, build files and launch scripts and reports each hit with its category, the JDK where it matters and the fix.

```text
$ scan.sh . --from 8 --to 17 --summary
jaxb      removed  11  2  JEP 320: JAXB removed from JDK. Add jakarta.xml.bind-api + ...
cms-gc    flag     14  1  JEP 363: CMS removed in 14. Use G1 (default) or ZGC
...
```

`scan.sh --security` switches to a second catalog slice for `java-secure-coding`: 20 candidate signals from the Oracle guidelines (deserialization, XML factories, SQL and command construction, mutable statics, native methods, TLS trust overrides, archives, `--add-opens`). Upgrade scans never report them, and in security mode comment lines are skipped.

Ground rules the skills follow: no edits before you confirm the plan, green baseline first, one hop at a time, no preview features or modernization unless you opt in, tests are never weakened, and JDKs are never installed for you.

All version facts live in one file, [jdk-matrix.md](skills/java-upgrade/references/jdk-matrix.md), checked against openjdk.org. It also lists common wrong advice that the skills avoid, such as String Templates (removed in 23), `-XX:+ZGenerational` (obsolete in 24) and `StructuredTaskScope.ShutdownOnFailure` (gone in 25).

Out of scope: framework major upgrades (Spring Boot, Jakarta EE namespace moves, Hibernate, JUnit majors). The plan lists them as prerequisites when they block the target JDK.

## Secure coding

`java-secure-coding` applies the [Secure Coding Guidelines for Java SE](https://www.oracle.com/java/technologies/javase/seccodeguide.html) (document 11.0) in three modes: explain a guideline, write code that follows it, or review a code base. A review maps trust boundaries, finds candidate sites with `rg`, and reports findings by guideline id (`SERIAL-3`, `INJECT-5`) with fixes that compile on the project's release. Security Manager guidelines are flagged as dead code from JDK 24.

The guide's own snippets contain bugs: missing generic type parameters, `GzipOutputStream`, `prepStmt`, `fields.get("data")`, a `readObject` that drops every field, an `InvocationHandler` whose `hashCode` returns `true`, `System.loadLibrary("/com/foo/MyLib.so")`, plus wrong facts and method names. Each one was compiled or run on JDK 21 and 25 and is listed with its evidence in [errata.md](skills/java-secure-coding/references/errata.md). The skill ships corrected versions, compiled by `compile-snippets.sh`.

## SOLID design

`java-solid` explains, writes and reviews Java code against the five SOLID principles. A review starts from churn hotspots in `git log`, finds candidate sites with `rg`, and reports each finding with its evidence (who changes the class, which edit repeats, which client breaks) and a fix that compiles on the project's release. Each principle has rules for when not to apply it, so the skill does not add interfaces nobody needs.

The references add current Java: `sealed` types with exhaustive `switch` as the closed-set form of open/closed, records and `final` classes against substitution bugs, `InstantSource` as interface segregation in the JDK, and constructor injection without a framework. Every example compiles on the JDK its marker claims, checked by `compile-snippets.sh`.

## Requirements

- `bash` (3.2+), `awk`, `sed`, `find`; `rg` is used when present, `grep -E` otherwise
- The JDKs for each hop installed locally (SDKMAN, `/Library/Java/JavaVirtualMachines` and `/usr/lib/jvm` are detected)
- Maven or Gradle, or the project's wrapper

## Install

```text
/plugin marketplace add filippobuletto/claude-plugins
/plugin install java-toolkit@filippobuletto
```

## Usage

| Command | Does |
| :- | :- |
| `/java-toolkit:java-upgrade 21` | Assess and plan an upgrade to 21, then wait for your confirmation |
| `/java-toolkit:java-upgrade 25 assess` | Assessment only |
| `/java-toolkit:java-upgrade apply` | Run the confirmed plan |
| `/java-toolkit:java-upgrade resume` | Continue from `.java-upgrade/progress.md` |
| `/java-toolkit:java-modernize records src/main/java` | Convert value classes to records |
| `/java-toolkit:java-secure-coding review src/main/java` | Security review against the Oracle guidelines |
| `/java-toolkit:java-solid review src/main/java` | Design review against the SOLID principles |

Plain requests such as "upgrade this project to Java 21" also trigger the router.

## Development

```bash
bash tests/run.sh               # detect.sh / scan.sh against tests/fixtures
bash tests/compile-snippets.sh  # compile every marked snippet in references/ on its claimed JDK
claude plugin validate . --strict
claude --plugin-dir .
```

Behavior evals (`claude plugin eval`, costs API usage; each case also runs a no-plugin baseline):

```bash
claude plugin eval . --scaffold --allow-tools Bash Write --max-cost-usd 5
```

`compile-snippets.sh` compiles each code block preceded by `<!-- compile: jdk=N [fails-below] [preview] [raw] -->` with an installed JDK (`--release N`); `fails-below` also checks that `--release N-1` rejects it, which proves the minimum JDK claimed in the text. Missing JDKs are skipped, never downloaded.

## License

[MIT](LICENSE)
