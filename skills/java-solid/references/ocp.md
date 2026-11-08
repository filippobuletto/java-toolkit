# Open/Closed Principle (OCP)

Contents: rule · open set of variants · closed set of variants · smells · when not to apply · checklist.

## Rule

Add behavior by adding code, not by editing code that works. Apply it where variation actually happens: decide whether new variants or new operations arrive more often, and make that axis cheap.

| What changes often | Shape | Adding a variant | Adding an operation |
|--------------------|-------|------------------|---------------------|
| New variants (payment providers, log sinks, plugins) | Interface + implementations | New class, no edits | Edit every implementation |
| New operations over a fixed set (AST nodes, protocol messages, shapes) | `sealed` interface + exhaustive `switch` | Compiler flags every `switch` to update | New method, no edits to the types |

## Open set of variants

Callers supply the variant; `Logger` never changes when a sink is added. A single-method interface takes a lambda or method reference.

<!-- compile: jdk=11 -->
```java
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.Objects;

@FunctionalInterface
interface LogSink {
    void write(String message);
}

static final class FileSink implements LogSink {
    private final Path file;

    FileSink(Path file) {
        this.file = Objects.requireNonNull(file);
    }

    @Override
    public void write(String message) {
        try {
            Files.writeString(file, message + System.lineSeparator(),
                    StandardOpenOption.CREATE, StandardOpenOption.APPEND);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}

static final class Logger {
    private final LogSink sink;

    Logger(LogSink sink) {
        this.sink = Objects.requireNonNull(sink);
    }

    void log(String message) {
        sink.write(message);
    }
}

static void wire() {
    Logger console = new Logger(System.out::println);
    Logger file = new Logger(new FileSink(Path.of("app.log")));
}
```

The logger only shows the shape. For real logging use `System.Logger` (9) or SLF4J.

## Closed set of variants

From release 21, a `sealed` hierarchy with an exhaustive `switch` keeps the variant set closed and operations open. Write no `default` branch: without one, adding a record to `permits` makes javac reject every `switch` that misses it.

<!-- compile: jdk=21 fails-below -->
```java
sealed interface Shape permits Circle, Rect {}

record Circle(double radius) implements Shape {}

record Rect(double width, double height) implements Shape {}

static double area(Shape shape) {
    return switch (shape) {
        case Circle(double r) -> Math.PI * r * r;
        case Rect(double w, double h) -> w * h;
    };
}
```

Here a `switch` over types is the design, not a smell. On 17–20, `sealed` works but the `switch` needs `instanceof` chains or a visitor; see java-modernize patterns-switch.md.

## Smells

- An `if`/`else` or `switch` on a type code (`String`, `enum`, `instanceof`) repeated in several classes, each edited when a variant is added.
- A class edited for every new provider, format or channel.
- A `default` branch that throws "unsupported type" over a hierarchy that could be `sealed`.

## When not to apply

- One implementation and no second in sight: no interface yet. Extract it when the second variant arrives; inside one code base the refactoring is cheap.
- One `switch` in a factory or composition root is the single place that knows all variants. Leave it.
- Published libraries are the exception: callers cannot edit your code, so extension points must exist up front.

## Checklist

1. Find the variation axis from history: which edits repeat (`git log -p` on the class).
2. Variants open-ended → interface with implementations; fixed set with growing operations → `sealed` plus exhaustive `switch` (gate on the release).
3. Move each branch body into its variant; the branching code receives the variant.
4. Tests green after each moved branch.
