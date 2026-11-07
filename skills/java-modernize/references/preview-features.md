# Preview features

Default: do not use. Only when the user explicitly opts in, for an application (never a published library), pinned to one exact JDK.

Contents: what preview means · opt-in checklist · build configuration · current previews (JDK 27) · never-shipped and withdrawn features.

## What preview means

- Code compiled with `--enable-preview` on JDK N runs only on JDK N (class files are marked). Every JDK bump requires recompiling and often rewriting.
- The API can change or be withdrawn between releases (String Templates were withdrawn after two previews; structured concurrency changed in 25 and 27).
- `--enable-preview` is needed at compile time, in tests, and at runtime.

## Opt-in checklist

Record in plan.md: the feature, the exact JDK, who owns re-validating it on the next JDK, and the fallback using final APIs. Keep preview usage in few, isolated classes.

## Build configuration

Maven:

```xml
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-compiler-plugin</artifactId>
  <configuration>
    <release>27</release>
    <enablePreview>true</enablePreview>
  </configuration>
</plugin>
<plugin>
  <groupId>org.apache.maven.plugins</groupId>
  <artifactId>maven-surefire-plugin</artifactId>
  <configuration>
    <argLine>@{argLine} --enable-preview</argLine>
  </configuration>
</plugin>
```

(`enablePreview` exists in maven-compiler-plugin 3.10.1+; older setups pass `<compilerArgs><arg>--enable-preview</arg></compilerArgs>`.)

Gradle (Kotlin DSL):

```kotlin
tasks.withType<JavaCompile>().configureEach { options.compilerArgs.add("--enable-preview") }
tasks.withType<Test>().configureEach { jvmArgs("--enable-preview") }
tasks.withType<JavaExec>().configureEach { jvmArgs("--enable-preview") }
```

Runtime: `java --enable-preview -jar app.jar`.

## Current previews (JDK 27)

| Feature | JEP (27) | Since | Notes |
|---------|----------|-------|-------|
| Primitive types in patterns, `instanceof`, `switch` | 532 | 23 | Unchanged from 26 |
| Structured concurrency | 533 | 21 | `StructuredTaskScope.open(Joiner…)`; changed in 25 and 27 |
| Lazy constants | 531 | 25 (as `StableValue`) | Renamed in 26; methods removed in 27 |
| PEM encodings | 538 | 25 | |
| Vector API | 537 | 16 | Incubator: `--add-modules jdk.incubator.vector`, not `--enable-preview` |

Primitive patterns on 27:

<!-- compile: jdk=27 preview -->
```java
static String status(int code) {
    return switch (code) {
        case 0 -> "ok";
        case 1 -> "warning";
        case int i when i >= 500 -> "server error " + i;
        case int i -> "other " + i;
    };
}
```

Structured concurrency on 27 (API valid only for 27):

<!-- compile: jdk=27 preview -->
```java
import java.util.concurrent.StructuredTaskScope;
import java.util.concurrent.StructuredTaskScope.Subtask;

static String both() throws Exception {
    try (var scope = StructuredTaskScope.open()) {
        Subtask<String> a = scope.fork(() -> "a");
        Subtask<String> b = scope.fork(() -> "b");
        scope.join();
        return a.get() + b.get();
    }
}
```

## Never shipped or withdrawn

| Feature | Status | Instead |
|---------|--------|---------|
| String Templates `STR."…"` (JEP 430/459/465) | Withdrawn; removed in 23 | `formatted`, `+`, bind parameters |
| Derived record creation `r with { … }` (JEP 468) | Candidate, never in a JDK | Explicit `withX` methods returning `new R(...)` |
| `StructuredTaskScope.ShutdownOnFailure` / `ShutdownOnSuccess` | Removed in 25 | `open(Joiner…)` (preview) or executor + futures |
| Value classes (JEP 401) | Not in any JDK through 27 | Records |
