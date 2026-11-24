# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
The versioned interface is the plugin install id, the skill and agent names,
and the options and output of `detect.sh` and `scan.sh`.

## [Unreleased]

## [0.3.0] - 2026-11-23

### Added

- `java-simplifier` agent, the plugin's first subagent. It simplifies recently
  changed Java code without changing behavior, with `java-solid`,
  `java-modernize` and `java-secure-coding` preloaded. It needs a green build
  before it edits, verifies with the project's build and tests, and undoes only
  its own edits when they break the build. It uses newer Java features only
  when the request asks to modernize, and it runs only when you ask for it by
  name.

## [0.2.1] - 2026-11-08

### Fixed

- `java-solid` reviews no longer fail when ripgrep is not installed. The search
  patterns used `\w`, `\b` and `\s`, which the `grep -E` fallback does not
  support; they now target Claude Code's Grep tool. The type-code pattern also
  matches camelCase selectors such as `paymentType`.

## [0.2.0] - 2026-11-08

Framework upgrades arrive, starting with Quarkus.

### Added

- `java-framework-upgrade` skill: detects the Quarkus version, plans one LTS
  hop at a time together with the JDK hops each one needs, waits for
  confirmation, and hands each hop to `java-quarkus-migrate`.
- `java-quarkus-migrate` skill: runs `quarkus update` pinned to the hop's
  stream, reviews the recipe diff, applies the manual items from the hop
  reference and verifies on the hop's JDK. Hop references cover 2.13 to the
  3.40 LTS. Quarkus 4.0 (Beta3) runs only on explicit opt-in. Gradle Kotlin
  DSL builds get the version bump by hand, because the update recipes do not
  support them.
- `detect.sh` reports `quarkus_version`, `quarkus_stream`, `quarkus_platform`,
  `quarkus_plugin`, `quarkus_extensions` and `quarkus_cli`.
- `scan.sh --framework quarkus` with a catalog of 57 Quarkus signals, reported
  when the change lands inside the requested hop. JDK and security scans do
  not read this catalog.

### Changed

- `java-upgrade` hands Quarkus upgrades, and JDK targets that conflict with the
  project's Quarkus version, to `java-framework-upgrade` instead of listing
  them as out of scope.

### Fixed

- `scan.sh --help` stops at the end of the header instead of printing part of
  the script.

## [0.1.5] - 2026-11-08

### Added

- `java-solid` skill: explains, writes and reviews Java code against the five
  SOLID principles, with one reference per principle that says when not to
  apply it and how current Java (sealed types, records, `InstantSource`,
  constructor injection) changes the answer.

## [0.1.4] - 2026-11-08

### Added

- `scan.sh --security` with 20 secure-coding signals: deserialization, XML
  factories, SQL and command construction, script engines, JNDI, secrets in
  logs, mutable statics, TLS trust overrides, archive readers and more. It
  skips comment lines, and upgrade scans never report these signals.

### Changed

- `java-secure-coding` reviews find candidate sites with
  `scan.sh --security` instead of untested inline searches that counted
  comments and imports as hits.

## [0.1.3] - 2026-11-07

### Added

- `java-secure-coding` skill: explains, applies and reviews code against the
  Oracle Secure Coding Guidelines for Java SE (document 11.0). The guide's own
  snippets contain compile errors, runtime bugs and wrong API names, so the
  skill ships corrected code and an errata file with the evidence. Its XML
  guidance is checked on JDK 21 to 27.
- `jdk-matrix.md` rows for `jdk.xml.dtd.support` (JDK 22), the strict JAXP
  template (JDK 23) and the built-in XML catalog.

### Fixed

- `java-migrate` now covers two XML default changes it missed: JDK 24 lowers
  the JAXP processing limits (2500 entity expansions instead of 64000, 200
  attributes per element instead of 10000), and JDK 25 disables XSLT extension
  functions by default.

## [0.1.2] - 2026-11-07

### Fixed

- `java-modernize` described its replacement for `StructuredTaskScope` fan-out
  as fail-fast, but it waited on tasks in submission order. It is now labeled
  as the simple form, next to a new fail-fast form based on
  `ExecutorCompletionService` that cancels the remaining tasks on the first
  failure.

## [0.1.1] - 2026-11-07

### Added

- `java-migrate` and `java-modernize` answer questions such as "what changes
  for X on Java 27" or "can we use records while targeting 11" from their
  references, without running scripts or editing code.

## [0.1.0] - 2026-11-07

First release, covering JDK upgrades from 8 to 27 on Maven and Gradle.

### Added

- `java-upgrade` skill: detects the project, writes a plan to
  `.java-upgrade/plan.md`, waits for confirmation, then upgrades one LTS hop
  at a time with a build and test run after every hop.
- `java-assess` skill: read-only audit with a baseline build, `scan.sh`,
  `jdeps` and `jdeprscan`.
- `java-build` skill: Maven and Gradle release settings, toolchains, wrapper
  and plugin versions, annotation processors, the Mockito agent and libraries
  that block a build on a newer JDK.
- `java-migrate` skill with one reference per hop: 8 to 11, 11 to 17, 17 to
  21, 21 to 25 and 25 to 27.
- `java-modernize` skill: adopts newer language and API features only up to
  the project's release.
- `detect.sh`: reports build tool, wrapper, Java release and where it is set,
  plugin and wrapper versions, blocking libraries, pinned JDKs in CI and
  Docker, and the JDKs installed on the machine.
- `scan.sh`: runs a catalog of 55 signals (removed APIs, obsolete JVM flags,
  deprecations, behavior changes, build blockers, modernization candidates)
  over sources, build files and launch scripts for a `--from`/`--to` JDK
  range. It uses ripgrep when present and `grep -E` otherwise.

[Unreleased]: https://github.com/filippobuletto/java-toolkit/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/filippobuletto/java-toolkit/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/filippobuletto/java-toolkit/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/filippobuletto/java-toolkit/compare/v0.1.5...v0.2.0
[0.1.5]: https://github.com/filippobuletto/java-toolkit/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/filippobuletto/java-toolkit/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/filippobuletto/java-toolkit/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/filippobuletto/java-toolkit/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/filippobuletto/java-toolkit/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/filippobuletto/java-toolkit/releases/tag/v0.1.0
