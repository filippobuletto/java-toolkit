# Pattern matching and switch

Contents: instanceof patterns (16) · switch expressions (14) · type patterns in switch (21) · record patterns (21) · unnamed variables `_` (22) · primitive patterns (preview only) · do-not-convert rules.

Every block marked `compile: jdk=N` is compiled by `tests/compile-snippets.sh` on JDK N.

## Pattern matching for instanceof — JEP 394, final 16

Signal: `instanceof-cast`. Bind the variable instead of casting.

Before:

<!-- compile: jdk=8 -->
```java
String describe(Object obj) {
    if (obj instanceof String) {
        String s = (String) obj;
        return "text " + s.length();
    } else if (obj instanceof Integer) {
        Integer i = (Integer) obj;
        return "number " + i;
    }
    return "unknown";
}
```

After:

<!-- compile: jdk=16 fails-below -->
```java
String describe(Object obj) {
    if (obj instanceof String s) {
        return "text " + s.length();
    } else if (obj instanceof Integer i) {
        return "number " + i;
    }
    return "unknown";
}
```

The binding is in scope where the match is definitely true, including after a negated early return:

<!-- compile: jdk=16 -->
```java
int length(Object obj) {
    if (!(obj instanceof String s)) {
        return -1;
    }
    return s.length();
}
```

`equals` keeps the same shape; `o instanceof Point p && x == p.x` is the idiom.

## Switch expressions — JEP 361, final 14

Signal: `old-switch`. Convert when every branch assigns or returns one value. Arrow labels never fall through; an expression switch over an enum must be exhaustive, so the compiler flags a missing constant.

Before:

<!-- compile: jdk=8 -->
```java
enum Day { MON, TUE, WED, THU, FRI, SAT, SUN }

static String kind(Day day) {
    String result;
    switch (day) {
        case SAT:
        case SUN:
            result = "weekend";
            break;
        default:
            result = "workday";
    }
    return result;
}
```

After:

<!-- compile: jdk=14 fails-below -->
```java
enum Day { MON, TUE, WED, THU, FRI, SAT, SUN }

static String kind(Day day) {
    return switch (day) {
        case SAT, SUN -> "weekend";
        case MON, TUE, WED, THU, FRI -> "workday";
    };
}
```

Use `yield` when a branch needs statements:

<!-- compile: jdk=14 -->
```java
static int score(char grade) {
    return switch (grade) {
        case 'A' -> 100;
        case 'B' -> 85;
        default -> {
            if (grade < 'A') throw new IllegalArgumentException("grade " + grade);
            yield 0;
        }
    };
}
```

Listing every enum constant instead of `default` keeps the compiler check when constants are added. Keep `default` when the enum comes from another module that may grow.

## Type patterns in switch — JEP 441, final 21

Replaces `instanceof` chains over unrelated types. Guards use `when`. `case null` is explicit; without it a `null` selector still throws `NullPointerException`, as before.

<!-- compile: jdk=21 fails-below -->
```java
static String format(Object obj) {
    return switch (obj) {
        case null -> "null";
        case String s when s.isBlank() -> "blank text";
        case String s -> "text " + s;
        case Integer i when i > 100 -> "large " + i;
        case Integer i -> "small " + i;
        default -> "other " + obj.getClass().getSimpleName();
    };
}
```

Order matters: a more general pattern before a more specific one (`case CharSequence cs` before `case String s`) is a compile error ("dominated").

With a sealed hierarchy the switch is exhaustive without `default`, so adding a subtype breaks every switch that forgot it. That is the main payoff; see `records-sealed.md`.

<!-- compile: jdk=21 -->
```java
sealed interface Shape permits Circle, Square {}
record Circle(double radius) implements Shape {}
record Square(double side) implements Shape {}

static double area(Shape shape) {
    return switch (shape) {
        case Circle c -> Math.PI * c.radius() * c.radius();
        case Square s -> s.side() * s.side();
    };
}
```

## Record patterns — JEP 440, final 21

Deconstruct records directly, nested if needed. `var` infers component types.

<!-- compile: jdk=21 fails-below -->
```java
record Point(int x, int y) {}
record Line(Point from, Point to) {}

static String describe(Object obj) {
    return switch (obj) {
        case Line(Point(var x1, var y1), Point(var x2, var y2)) when x1 == x2 -> "vertical at x=" + x1;
        case Line(Point from, Point to) -> "line " + from + " to " + to;
        case Point(int x, int y) -> "point " + x + "," + y;
        default -> "unknown";
    };
}

static boolean onDiagonal(Object obj) {
    return obj instanceof Point(int x, int y) && x == y;
}
```

## Unnamed variables and patterns `_` — JEP 456, final 22

For pattern components, lambda parameters, catch parameters, and loop variables that are never read. JEP 443 was the 21 preview; do not use `_` on 21 without preview.

<!-- compile: jdk=22 fails-below -->
```java
import java.util.List;
import java.util.Map;

record Point(int x, int y) {}

static int xOf(Object obj) {
    return switch (obj) {
        case Point(int x, _) -> x;
        default -> 0;
    };
}

static int count(List<String> rows) {
    int n = 0;
    for (String _ : rows) n++;
    return n;
}

static int parse(String s) {
    try {
        return Integer.parseInt(s);
    } catch (NumberFormatException _) {
        return 0;
    }
}

static void fill(Map<String, List<String>> index, String key) {
    index.computeIfAbsent(key, _ -> new java.util.ArrayList<>()).add("x");
}
```

## Primitive types in patterns — preview only

JEP 455 (23) → 488 (24) → 507 (25) → 530 (26) → 532 (27, fifth preview, unchanged). Not final in any JDK through 27. Do not adopt unless the user explicitly opts into preview; see `preview-features.md`.

## Do not convert when

- A `switch` statement's branches do different side effects and do not produce a value: arrow labels (`case X -> stmt;`) are fine, but a switch *expression* is not.
- The old switch relies on fall-through that runs code in several cases in sequence.
- The `instanceof` chain checks interfaces implemented by the same object (`Closeable` and `Flushable`): the first matching case wins in a switch, which can change which branch runs.
- The code must still compile for an older release (library supporting older JDKs, multi-release source sets).
