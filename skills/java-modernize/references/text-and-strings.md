# Text blocks and String API

Contents: text blocks (15) · indentation and escapes · String methods (11–15) · formatting · no String Templates · do-not-convert rules.

## Text blocks — JEP 378, final 15

Signal: `multiline-concat`. Good for SQL, JSON, XML, HTML, and test fixtures.

Before:

<!-- compile: jdk=8 -->
```java
static final String QUERY = "SELECT id, name\n" +
        "FROM customer\n" +
        "WHERE active = 1\n";
```

After:

<!-- compile: jdk=15 fails-below -->
```java
static final String QUERY = """
        SELECT id, name
        FROM customer
        WHERE active = 1
        """;
```

The two are equal strings. Rules that keep them equal:

- Incidental indentation (the common leading whitespace, counting the closing `"""`) is removed. Put the closing delimiter at the left edge of the content to keep no indentation.
- Closing `"""` on its own line adds a trailing `\n`; closing it at the end of the last content line does not. Match the original.
- Trailing spaces are stripped. Keep one with `\s`.
- `\` at line end joins lines (no newline), for long single-line strings.
- Line terminators are normalized to `\n`, even on Windows sources.

<!-- compile: jdk=15 -->
```java
static final String JSON = """
        {
          "name": "%s",
          "tags": ["a", "b"]\
        }""";

static String json(String name) {
    return JSON.formatted(name);
}
```

Check equality when converting a constant that tests or wire formats depend on: write a quick test asserting old == new before deleting the old form.

## String methods

| Method | JDK | Use instead of |
|--------|-----|----------------|
| `isBlank()` | 11 | `s.trim().isEmpty()` (signal `blank-check`) |
| `strip()`, `stripLeading()`, `stripTrailing()` | 11 | `trim()` when Unicode whitespace matters |
| `lines()` | 11 | `split("\\R")` |
| `repeat(n)` | 11 | loops / `StringUtils.repeat` |
| `Files.readString`, `Files.writeString` | 11 | `new String(Files.readAllBytes(p))` (signal `read-all-bytes`) |
| `indent(n)`, `transform(f)` | 12 | manual prefixing |
| `formatted(args)` | 15 | `String.format(fmt, args)` |
| `stripIndent()`, `translateEscapes()` | 15 | |

<!-- compile: jdk=11 fails-below -->
```java
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

static boolean hasContent(String s) {
    return s != null && !s.isBlank();
}

static long nonEmptyLines(Path file) throws IOException {
    return Files.readString(file, StandardCharsets.UTF_8).lines().filter(l -> !l.isBlank()).count();
}
```

`trim()` and `strip()` differ: `trim()` removes chars ≤ U+0020, `strip()` removes Unicode whitespace. Keep `trim()` where the old behavior is relied on.

## No String Templates

`STR."…"` was a preview in 21–22 and was removed in 23. Never introduce it. Use `+`, `formatted`, `StringBuilder`, or `MessageFormat`; for SQL use bind parameters.

## Do not convert when

- The string is built conditionally across lines (`if` between parts) — a text block cannot express it; a `StringBuilder` or `String.join` may.
- The string's exact trailing whitespace or `\r\n` line endings matter and the conversion would change them.
- The project must compile for a release below 15.
