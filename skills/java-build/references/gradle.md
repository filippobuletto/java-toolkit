# Gradle

Contents: compatibility matrix · wrapper · toolchains · release option · annotation processors · Mockito agent · test JVM flags · lint. Kotlin DSL first, Groovy after.

Facts from <https://docs.gradle.org/current/userguide/compatibility.html> (Gradle 9.9.0 current, checked 2026-11-07).

## Compatibility matrix

Toolchain support = Gradle can compile/test with that JDK. Running Gradle = the JVM Gradle itself runs on.

| Java | Toolchain support from | Running Gradle supported |
|------|------------------------|--------------------------|
| 8 – 14 | n/a | up to 8.14.x only |
| 15 | 6.7 | 6.7 to 8.14.x |
| 16 | 7.0 | 7.0 to 8.14.x |
| 17 | 7.3 | 7.3 and after |
| 21 | 8.4 | 8.5 and after |
| 22 | 8.7 | 8.8 and after |
| 23 | 8.10 | 8.10 and after |
| 24 | 8.14 | 8.14 and after |
| 25 | 9.1.0 | 9.1.0 and after |
| 26 | 9.4.0 | 9.4.0 and after |
| 27 | 9.8.0 | 9.8.0 and after |

Gradle 9 needs JDK 17+ to run. A project on Java 8 or 11 can still use Gradle 9 by running Gradle on 17+ and compiling with a toolchain for 8/11.

Symptom of a too-old Gradle: `Unsupported class file major version NN` while compiling the build script, or the daemon refusing to start.

## Wrapper

```bash
./gradlew wrapper --gradle-version 9.9.0
./gradlew wrapper    # second run refreshes gradle-wrapper.jar and scripts with the new version
```

Large Gradle jumps (7 → 8 → 9) bring their own deprecations. If the build prints deprecation warnings on the current version (`--warning-mode all`), fix them first, one Gradle major at a time.

## Toolchains

`settings.gradle.kts` (auto-provisioning; optional, but needed when developers or CI do not have the JDK installed):

```kotlin
plugins {
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}
```

`build.gradle.kts`:

```kotlin
java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(25)
    }
}
```

Groovy:

```groovy
java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(25)
    }
}
```

Replace `sourceCompatibility` / `targetCompatibility` with the toolchain. Kotlin JVM projects: `kotlin { jvmToolchain(25) }`.

Multi-project: set the toolchain once in a convention plugin (`buildSrc` or `build-logic`) or `subprojects {}`; remove per-project copies.

## Release option (compile for an older release on a newer toolchain)

```kotlin
tasks.withType<JavaCompile>().configureEach {
    options.release = 17
}
```

Groovy: `options.release = 17`. Use it for libraries that must keep supporting an older JDK while building on a newer one.

## Annotation processors

Gradle passes the `annotationProcessor` configuration as an explicit processor path, so the JDK 23 change does not break correctly configured builds. Processors declared only in `implementation` / `compileOnly` stop running: move them.

```kotlin
dependencies {
    compileOnly("org.projectlombok:lombok:1.18.48")
    annotationProcessor("org.projectlombok:lombok:1.18.48")
    testCompileOnly("org.projectlombok:lombok:1.18.48")
    testAnnotationProcessor("org.projectlombok:lombok:1.18.48")
}
```

## Mockito agent (JDK 21+, JEP 451)

From the Mockito javadoc. Kotlin DSL:

```kotlin
val mockitoAgent = configurations.create("mockitoAgent")
dependencies {
    testImplementation(libs.mockito)
    mockitoAgent(libs.mockito) { isTransitive = false }
}

abstract class MockitoAgentProvider : CommandLineArgumentProvider {
    @get:InputFiles
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val agentJar: ConfigurableFileCollection

    override fun asArguments(): Iterable<String> =
        listOf("-javaagent:${agentJar.asPath}")
}

tasks {
    test {
        jvmArgumentProviders.add(objects.newInstance<MockitoAgentProvider>().apply {
            agentJar.from(mockitoAgent)
        })
    }
}
```

Groovy DSL:

```groovy
configurations {
    mockitoAgent
}
dependencies {
    testImplementation(libs.mockito)
    mockitoAgent(libs.mockito) {
        transitive = false
    }
}

abstract class MockitoAgentProvider implements CommandLineArgumentProvider {
    @InputFiles
    @PathSensitive(PathSensitivity.RELATIVE)
    abstract ConfigurableFileCollection getAgentJar()

    @Override
    Iterable<String> asArguments() {
        ["-javaagent:${agentJar.asPath}"]
    }
}

tasks {
    test {
        jvmArgumentProviders.add(objects.newInstance(MockitoAgentProvider).tap {
            agentJar.from(configurations.mockitoAgent)
        })
    }
}
```

Replace `libs.mockito` with the coordinate string when the project has no version catalog.

## Test JVM flags

```kotlin
tasks.withType<Test>().configureEach {
    jvmArgs("--add-opens", "java.base/java.lang=ALL-UNNAMED")   // temporary, name the library in progress.md
}
```

JNI (24+): `jvmArgs("--enable-native-access=ALL-UNNAMED")`. Application run task: same flags on `tasks.named<JavaExec>("run")` or `application { applicationDefaultJvmArgs = listOf(...) }`.

## Lint during the upgrade

```kotlin
tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.addAll(listOf("-Xlint:deprecation,removal"))
}
```

Build with `./gradlew build --warning-mode all` to see Gradle deprecations too.
