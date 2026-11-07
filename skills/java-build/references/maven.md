# Maven

Contents: versions · release property · wrapper · toolchains · enforcer · annotation processors · Mockito agent · surefire JVM flags · lint.

Versions checked against Maven Central and maven.apache.org on 2026-11-07. Confirm the newest patch before writing them.

## Versions

| Component | Recommended | Notes |
|-----------|-------------|-------|
| Maven | 3.9.16 or 3.10.0 | Maven 4 is still RC; do not switch to it during a JDK upgrade |
| maven-compiler-plugin | 3.16.0 | `release` needs 3.6+; `jdkToolchain` 3.6+ |
| maven-surefire-plugin / failsafe | 3.6.1 | 2.x forks fail or mis-parse on newer JDKs; 3.x needed for JUnit 5 |
| maven-jar-plugin | 3.5.1 | |
| maven-enforcer-plugin | 3.7.0 | |
| maven-toolchains-plugin | 3.3.0 | Only if not using `jdkToolchain` |
| maven-wrapper-plugin | 3.3.4 | |
| maven-javadoc-plugin, maven-shade-plugin, maven-war-plugin | latest | Old versions ship ASM that cannot read new class files |

Very old plugins (compiler < 3.8, surefire 2.x, shade < 3.5, javadoc < 3.6) are the usual cause of failures right after the switch. Bump them in step 1 while still on the current JDK.

## Release property

Set it once in the root (or parent) pom; remove `maven.compiler.source` / `maven.compiler.target` and any `<source>`/`<target>` in plugin configuration.

```xml
<properties>
  <maven.compiler.release>21</maven.compiler.release>
</properties>
```

If the project uses Spring Boot's parent, `java.version` drives `maven.compiler.release`; change `java.version` instead.

`release` 8 is valid when compiling on JDK 9+, so the first step of an 8 → 11 hop can be: run Maven on JDK 11 with `release` 8, then raise to 11.

## Wrapper

```bash
./mvnw wrapper:wrapper -Dmaven=3.9.16   # or the version chosen above
```

No wrapper yet: offer `mvn wrapper:wrapper` to the user as a separate step; do not add one silently.

## Toolchains (build with a JDK other than the one running Maven)

`~/.m2/toolchains.xml` (user machine; do not commit):

```xml
<toolchains>
  <toolchain>
    <type>jdk</type>
    <provides><version>25</version></provides>
    <configuration><jdkHome>/path/to/jdk-25</jdkHome></configuration>
  </toolchain>
</toolchains>
```

Compiler plugin selection (no extra plugin needed):

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-compiler-plugin</artifactId>
  <version>3.16.0</version>
  <configuration>
    <jdkToolchain><version>25</version></jdkToolchain>
  </configuration>
</plugin>
```

Surefire also accepts `<jdkToolchain>`. Simpler during an upgrade: run Maven itself with `JAVA_HOME=<jdk.N>`.

## Enforcer

Fail fast on the wrong JDK or Maven:

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-enforcer-plugin</artifactId>
  <version>3.7.0</version>
  <executions>
    <execution>
      <id>enforce-versions</id>
      <goals><goal>enforce</goal></goals>
      <configuration>
        <rules>
          <requireJavaVersion><version>[21,)</version></requireJavaVersion>
          <requireMavenVersion><version>[3.9,)</version></requireMavenVersion>
        </rules>
      </configuration>
    </execution>
  </executions>
</plugin>
```

## Annotation processors

From JDK 21 javac warns, and from 23 it no longer runs processors that are only discovered on the class path. The compiler plugin doc: "Starting with JDK 21, this option [`proc`] must be set explicitly." Declare processors on the processor path; this is the stable fix:

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-compiler-plugin</artifactId>
  <version>3.16.0</version>
  <configuration>
    <annotationProcessorPaths>
      <path>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <version>${lombok.version}</version>
      </path>
      <path>
        <groupId>org.mapstruct</groupId>
        <artifactId>mapstruct-processor</artifactId>
        <version>${mapstruct.version}</version>
      </path>
      <!-- Lombok + MapStruct together also need org.projectlombok:lombok-mapstruct-binding -->
    </annotationProcessorPaths>
  </configuration>
</plugin>
```

Quick alternative when processors come from many dependencies: `<proc>full</proc>` (user property `maven.compiler.proc`). Note: once `annotationProcessorPaths` is set, only those paths are searched, so list every processor the build used.

Symptom of a missing processor: "cannot find symbol" for Lombok-generated getters/builders or MapStruct `*Impl` classes, only on 23+.

## Mockito agent (JDK 21+, JEP 451)

From the Mockito javadoc ("Explicitly setting up instrumentation for inline mocking"):

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-dependency-plugin</artifactId>
  <executions>
    <execution>
      <goals><goal>properties</goal></goals>
    </execution>
  </executions>
</plugin>
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-surefire-plugin</artifactId>
  <configuration>
    <argLine>@{argLine} -javaagent:${org.mockito:mockito-core:jar}</argLine>
  </configuration>
</plugin>
```

`@{argLine}` keeps JaCoCo's agent. If nothing else defines `argLine`, add an empty `<argLine/>` property in `<properties>`, otherwise the literal `@{argLine}` reaches the JVM and the fork fails.

Fallback only: `-XX:+EnableDynamicAgentLoading` in `argLine`.

## Surefire JVM flags

Strong encapsulation (17+) makes old reflective libraries fail in tests with `InaccessibleObjectException`. Preferred fix: bump the library. Temporary fix, one package at a time:

```xml
<argLine>@{argLine} --add-opens java.base/java.lang=ALL-UNNAMED</argLine>
```

Record each `--add-opens` and its owning library in progress.md. JNI (24+): `--enable-native-access=ALL-UNNAMED`.

## Lint during the upgrade

```xml
<configuration>
  <showWarnings>true</showWarnings>
  <showDeprecation>true</showDeprecation>
  <compilerArgs>
    <arg>-Xlint:deprecation,removal</arg>
  </compilerArgs>
</configuration>
```

Collect the warnings into the assessment; remove the extra flags afterwards if the project did not have them.

## Multi-module

Put the release, plugin versions (`<pluginManagement>`) and processor paths in the parent. Child poms that override `maven.compiler.*` or plugin versions are a common source of mixed results; remove the overrides.
