# Other language features and APIs

Contents: `var` (10/11) · `java.time` · `HttpClient` (11, HTTP/3 in 26) · Javadoc `@snippet` (18) and Markdown comments (23) · flexible constructor bodies (25) · module import declarations (25) · compact source files and instance main (25) · source launcher (11/22) · Class-File API (24).

## `var` — JEP 286 (10), lambda parameters JEP 323 (11)

Use where the type is obvious from the right-hand side; keep explicit types where it documents intent.

<!-- compile: jdk=10 fails-below -->
```java
import java.util.HashMap;
import java.util.List;
import java.util.Map;

static Map<String, List<String>> index(List<String> words) {
    var index = new HashMap<String, List<String>>();
    for (var word : words) {
        index.computeIfAbsent(word.substring(0, 1), k -> new java.util.ArrayList<>()).add(word);
    }
    return index;
}
```

Do not: `var x = service.load();` when the type is not evident, `var` with diamond (`var list = new ArrayList<>();` infers `ArrayList<Object>`), or mass conversion of a codebase. Style-only; adopt only if the team wants it.

## java.time (8)

Signal: `legacy-date`. Convert at boundaries first (`Date.toInstant()`, `Date.from(instant)`, `GregorianCalendar.toZonedDateTime()`), then inward. `DateTimeFormatter` is immutable and thread-safe; `SimpleDateFormat` is neither.

<!-- compile: jdk=8 -->
```java
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Date;

static final DateTimeFormatter DAY = DateTimeFormatter.ofPattern("yyyy-MM-dd").withZone(ZoneId.of("UTC"));

static String day(Date legacy) {
    Instant instant = legacy.toInstant();
    return DAY.format(instant);
}
```

Pattern letters differ in places (`u` vs `y`, `Y` week-year in both); test formatted output.

## HttpClient — JEP 321 (11)

Signal: `http-url-connection`. Migrate when touching the code, not as a sweep.

<!-- compile: jdk=11 fails-below -->
```java
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

static final HttpClient CLIENT = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(5))
        .build();

static String get(String url) throws IOException, InterruptedException {
    HttpRequest request = HttpRequest.newBuilder(URI.create(url)).timeout(Duration.ofSeconds(10)).GET().build();
    return CLIENT.send(request, HttpResponse.BodyHandlers.ofString()).body();
}
```

Reuse one client (it holds the connection pool). HTTP/3 is opt-in from 26 with `HttpClient.Version.HTTP_3`; HTTP/2 stays the default.

## Javadoc: `@snippet` (JEP 413, 18) and Markdown comments (JEP 467, 23)

`@snippet` replaces `<pre>{@code …}</pre>` and can include code from files. Markdown comments use `///`:

<!-- compile: jdk=23 -->
```java
/// Returns the **absolute** value of `a`.
///
/// If `a` is negative, returns its negation; see [Math#abs(int)].
///
/// @param a the value
/// @return the absolute value
static int abs(int a) {
    return a < 0 ? -a : a;
}
```

Converting existing HTML Javadoc is optional and noisy in diffs; do it only on request. Javadoc older than 23 renders `///` as plain comments (lost docs) — only for projects building docs on 23+.

## Flexible constructor bodies — JEP 513, final 25

Statements before `super(...)` / `this(...)`: validate or compute arguments without static helper methods. Those statements cannot read `this` (fields may be assigned, not read).

<!-- compile: jdk=25 fails-below -->
```java
static class Base {
    final long size;
    Base(long size) { this.size = size; }
}

static class Positive extends Base {
    Positive(long size) {
        if (size <= 0) throw new IllegalArgumentException("size must be positive: " + size);
        super(size);
    }
}
```

## Module import declarations — JEP 511, final 25

`import module java.base;` imports all packages exported by a module. Good for scripts, examples, tests; avoid in production code where explicit imports document dependencies, and watch for ambiguous simple names (`List` from `java.util` and `java.awt` with `import module java.desktop;`).

<!-- compile: jdk=25 fails-below -->
```java
import module java.base;

static List<Path> files(String dir) throws IOException {
    try (Stream<Path> s = Files.list(Path.of(dir))) {
        return s.toList();
    }
}
```

## Compact source files and instance main methods — JEP 512, final 25

For scripts, tools and teaching: a source file without a class declaration and an instance `void main()`. `java.lang.IO` provides `println`/`readln`. Run with `java Main.java`.

<!-- compile: jdk=25 raw fails-below -->
```java
void main() {
    IO.println("Hello from a compact source file");
}
```

Not for application code: such files cannot be referenced by other classes.

## Source launcher — JEP 330 (11), multi-file JEP 458 (22)

`java Tool.java args` runs a single file (11); from 22 the launched file can use other source files in the same directory tree. Replaces small build setups for helper scripts.

## Class-File API — JEP 484, final 24

`java.lang.classfile` replaces ASM for code that reads or writes class files on 24+. Only relevant for projects that own bytecode tooling (agents, build plugins). Libraries supporting older JDKs keep ASM.

<!-- compile: jdk=24 fails-below -->
```java
import java.lang.classfile.ClassFile;
import java.lang.classfile.ClassModel;
import java.lang.classfile.MethodModel;
import java.util.List;

static List<String> methodNames(byte[] classBytes) {
    ClassModel model = ClassFile.of().parse(classBytes);
    return model.methods().stream().map(MethodModel::methodName).map(n -> n.stringValue()).toList();
}
```
