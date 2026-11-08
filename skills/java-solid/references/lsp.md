# Liskov Substitution Principle (LSP)

Contents: rule · equals across a hierarchy · optional operations · composition over inheritance · smells · checklist.

## Rule

Code written against a type must keep working with any subtype (Liskov and Wing 1994). An override may not:

- demand more of its input (stronger preconditions),
- promise less about its result (weaker postconditions),
- break the supertype's invariants,
- throw exceptions the supertype contract does not allow.

Compiling is not enough. The contract lives in the Javadoc and in what callers rely on.

## equals across a hierarchy

A subclass that adds state and overrides `equals` breaks symmetry (Effective Java 3rd ed. Item 10). Collections then behave differently depending on argument order.

<!-- compile: jdk=8 -->
```java
static class Point {
    final int x, y;

    Point(int x, int y) {
        this.x = x;
        this.y = y;
    }

    @Override
    public boolean equals(Object o) {
        return o instanceof Point && ((Point) o).x == x && ((Point) o).y == y;
    }

    @Override
    public int hashCode() {
        return 31 * x + y;
    }
}

// Violates LSP: point.equals(colorPoint) is true, colorPoint.equals(point) is false.
static class ColorPoint extends Point {
    final String color;

    ColorPoint(int x, int y, String color) {
        super(x, y);
        this.color = color;
    }

    @Override
    public boolean equals(Object o) {
        return o instanceof ColorPoint && super.equals(o) && ((ColorPoint) o).color.equals(color);
    }
}
```

Compose instead. Records are final, so no subtype can break their `equals`.

<!-- compile: jdk=16 fails-below -->
```java
record Point(int x, int y) {}

record ColorPoint(Point point, String color) {}
```

## Optional operations

`Collection` documents `add` and `remove` as optional, so `List.of(...)` may throw `UnsupportedOperationException` and still honor `List`. Callers of a `List` they did not create must not assume it is mutable. Do not copy this design in your own types: split read and write into separate interfaces (isp.md) so an implementation never refuses a method it declares.

## Composition over inheritance

Subclassing a concrete class couples you to its self-use. `HashSet.addAll` calls `add`, so a subclass counting in both double-counts (errata.md). Hold the delegate instead. `AbstractCollection.addAll` documents that it calls `add` for each element, so counting in `add` alone is correct.

<!-- compile: jdk=8 -->
```java
import java.util.AbstractSet;
import java.util.Iterator;
import java.util.Objects;
import java.util.Set;

static final class CountingSet<E> extends AbstractSet<E> {
    private final Set<E> delegate;
    private int addCount;

    CountingSet(Set<E> delegate) {
        this.delegate = Objects.requireNonNull(delegate);
    }

    @Override
    public boolean add(E e) {
        addCount++;
        return delegate.add(e);
    }

    @Override
    public boolean contains(Object o) {
        return delegate.contains(o);
    }

    @Override
    public Iterator<E> iterator() {
        return delegate.iterator();
    }

    @Override
    public int size() {
        return delegate.size();
    }

    int addCount() {
        return addCount;
    }
}
```

Make classes `final` unless designed for extension (Effective Java Item 19; secure-coding EXTEND-5). From 17, `sealed` limits who may substitute.

## Smells

- Overrides that throw `UnsupportedOperationException`, do nothing, or reject inputs the supertype accepts.
- Callers check `instanceof SomeSubtype` to work around one implementation.
- `equals` in a subclass that adds fields; `getClass() != o.getClass()` in `equals` (fixes symmetry by refusing substitution).
- Base-class tests fail when run against a subclass.

## Checklist

1. Read the supertype contract (Javadoc, tests); list preconditions, postconditions, exceptions.
2. Check each override against the list.
3. Run the supertype's tests against every implementation: an abstract contract test class with one concrete subclass per implementation.
4. Fix a violating subtype by composition, by splitting the interface, or by making the hierarchy `sealed` and the leaves `final`.
