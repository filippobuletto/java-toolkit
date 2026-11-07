# Build-blocker libraries

Libraries that read or generate class files, or hook into javac, must know the target JDK. Too old a version fails the build even when the application code is fine. Bump them to at least the version below; confirm the newest patch first. Versions checked 2026-11-07 (release notes and Maven Central).

Typical errors: `Unsupported class file major version 69`, `java.lang.IllegalArgumentException: Unsupported class file major version`, Lombok `NoSuchFieldError: com.sun.tools.javac...`, JaCoCo instrumentation errors, Byte Buddy "Java NN (69) is not supported by the current version of Byte Buddy".

Class file major version = JDK + 44 (JDK 21 = 65, 25 = 69, 27 = 71).

## Minimum versions per target JDK

| Library | 17 | 21 | 25 | 26 | 27 | Latest seen |
|---------|----|----|----|----|----|-------------|
| Lombok | 1.18.22 | 1.18.30 | 1.18.40 | 1.18.46 | 1.18.48 | 1.18.48 |
| JaCoCo | 0.8.8 | 0.8.11 | 0.8.14 | 0.8.15 | 0.8.16 | 0.8.16 |
| Byte Buddy | 1.11.x | 1.14.x | 1.17.5+ (1.18.x safest) | 1.18.x | 1.18.x | 1.18.17 |
| Mockito | 4.x | 5.x | 5.x (brings a matching Byte Buddy) | 5.x | 5.x | 5.24.0 |
| ASM | 9.1 | 9.5 | 9.8 | 9.9+ | 9.10+ | 9.11.1 |
| Kotlin (JVM target) | 1.6 | 1.9.20 | 2.3.0 | latest 2.x | latest 2.x | — |

The 17 column for Lombok, Byte Buddy, ASM and Kotlin is from release-note memory; the rest was checked. Treat a cell as a floor, not a recommendation: use the latest patch of that line.

### Notes per library

- **Lombok**: 1.18.40 stops copying Jackson annotations by default (check `lombok.config` if JSON output changes). 1.18.48 removes the long-deprecated `@Wither` and `@Delegate` from the jar and renames `@SuperBuilder` config keys; search for those before bumping. Configure as an annotation processor (see maven.md / gradle.md). With MapStruct add `lombok-mapstruct-binding`.
- **JaCoCo**: runs as an agent in the test JVM; Maven `argLine` must keep `@{argLine}` when other flags are added.
- **Byte Buddy**: often transitive via Mockito or Hibernate. Override the version in dependency management rather than adding a direct dependency. `-Dnet.bytebuddy.experimental=true` lets an older Byte Buddy try unknown class files; temporary only.
- **Mockito**: Mockito 1/2/3 do not work on 17+. 4 → 5 changed the default mock maker to inline (needs the agent setup on 21+). Mockito 5 requires Java 11+.
- **Error Prone**: 2.43.0+ needs JDK 21 to run javac; from 2.46.0 also `-XDaddTypeAnnotationsToSymbol=true` on JDK 21. Javac `--add-exports`/`--add-opens` flags for `jdk.compiler` are required on 16+ (see the Error Prone installation docs for the exact list for the version in use).
- **Kotlin**: the Kotlin compiler caps the JVM target it can emit. OpenRewrite's Java 25 recipe gates on Kotlin 2.3.0.
- **AspectJ**: the weaver must support the class file version; use the latest 1.9.2x for 21+.
- **SpotBugs, Checkstyle, PMD**: run on class files or source; bump to the latest release when they fail to parse new syntax (records, switch patterns, `_`).
- **Shade / javadoc / war / bundle plugins**: embed ASM or javadoc tooling; latest versions.

## Frameworks (prerequisites, not build blockers)

Do not upgrade these inside this plugin's steps; list them in the plan's prerequisites when they block the target:

- Spring Boot 2.7 (end of life) runs on Java 8 up to 21 with caveats; staying supported on 21+ means Boot 3.x (Jakarta namespace) or 4.x.
- Spring Boot 3.5 supports Java 17–25; Boot 4.x requires Java 17+ and supports up to 27 (Spring Framework 7 baseline: Java 17, Jakarta EE 11).
- Quarkus 3.x supports Java 17/21/25; Quarkus 4 (beta) requires Java 21.
- Hibernate 5 on 17+ needs `--add-opens`; 6.x/7.x are the supported lines.

## CI and containers

Keep one JDK per hop across:

- GitHub Actions: `actions/setup-java` `java-version: '<N>'` (keep the existing `distribution`).
- GitLab / Jenkins: image tags such as `maven:3.9-eclipse-temurin-<N>`, `eclipse-temurin:<N>-jdk`, `gradle:<ver>-jdk<N>`.
- Dockerfile runtime: `eclipse-temurin:<N>-jre` (tags exist for 21, 25, 27), `gcr.io/distroless/java<N>-debian13` (17, 21, 25; no 27). Keep the existing image family; change only the version.
- Launch scripts, `JAVA_TOOL_OPTIONS`, Helm values, systemd units: remove obsolete flags from the flag table in jdk-matrix.md.
- `.sdkmanrc`, `.java-version`, `.tool-versions`: update the pinned JDK.
