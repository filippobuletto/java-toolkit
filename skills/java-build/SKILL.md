---
name: java-build
description: Updates Maven or Gradle build configuration for a new JDK. Sets the compiler release or toolchain, bumps the build tool, wrapper and compiler/test plugin versions to ones that support the target JDK, fixes annotation processor setup, attaches the Mockito agent, bumps build-blocker libraries (Lombok, JaCoCo, Byte Buddy, Error Prone, Kotlin, AspectJ) and aligns the JDK in CI and Dockerfiles.
when_to_use: Called by the java-upgrade router for build steps of a hop, or when the user asks to change the Java version in pom.xml or build.gradle, set up toolchains, fix a build that fails only on a newer JDK (unsupported class file major version, Lombok or annotation processor errors, Mockito self-attach warning), or upgrade Maven/Gradle for a JDK.
argument-hint: "[target-jdk] [maven|gradle]"
---

# Build configuration for a JDK upgrade

Scope: build files, wrapper files, CI workflow JDK, Dockerfile base images and launch-script JVM flags. Not application code (that is java-migrate) and not framework majors.

Inputs: project root, target release `to`, the step from `.java-upgrade/plan.md` when called by the router. Facts from `bash ${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/scripts/detect.sh <root>`.

## Order inside a hop

1. **Tool versions first, on the current JDK.** Bump Maven/Gradle wrapper and plugins to versions that run on both the current and target JDK; build on the current JDK; must stay green.
2. **Build blockers.** Bump libraries from `uses` per [build-blockers.md](references/build-blockers.md); build on the current JDK.
3. **Switch the release.** Set the release / toolchain to `to`; build and test with `JAVA_HOME=<jdk.to>`.
4. **Annotation processing and agents.** Explicit processor path; Mockito `-javaagent` from 21.
5. **CI, Docker, scripts.** Same JDK everywhere; remove obsolete flags (see the flag table in `${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/references/jdk-matrix.md`).

Each numbered item is its own verified step; do not batch them.

## Rules

- One place for the Java version: a single property (Maven) or toolchain declaration (Gradle) that every module inherits. Remove duplicates in child modules instead of updating each.
- Use `release`, not `source`/`target`. `release` also checks API usage against the target JDK.
- Keep the wrapper. Change versions through the wrapper's own command, not by hand-editing the jar.
- Pick plugin and library versions from the references, then confirm the newest patch with the repository (`./mvnw versions:display-plugin-updates`, Maven Central metadata, or the Gradle plugin portal). Do not invent versions.
- Never add `--add-opens`, `-XX:+EnableDynamicAgentLoading`, `--enable-native-access`, or `-Dnet.bytebuddy.experimental=true` without recording which library needs it and the follow-up to remove it.
- Do not change dependency versions beyond what the target JDK requires; framework upgrades are prerequisites for the user.

## References

- [maven.md](references/maven.md): release property, plugin versions, wrapper, toolchains, enforcer, annotation processors, Mockito agent, `--add-opens` in surefire, lint flags. Load for Maven projects.
- [gradle.md](references/gradle.md): Gradle/JDK compatibility matrix, wrapper upgrade, toolchains and foojay resolver, release option, annotation processors, Mockito agent, both DSLs. Load for Gradle projects.
- [build-blockers.md](references/build-blockers.md): minimum versions per target JDK for Lombok, JaCoCo, Byte Buddy, Mockito, Error Prone, Kotlin, AspectJ, ASM, and CI/Docker JDK alignment. Load when `uses` is non-empty or a build fails with "Unsupported class file major version".
