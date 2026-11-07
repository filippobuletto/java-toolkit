# Extensibility, mutability and construction (EXTEND, MUTABLE, OBJECT)

Contents: accessibility and modules · final and sealed types · superclass changes · immutable values · defensive copies · identity · static state · exposing collections · object construction · review checklist.

## EXTEND-1, 2: shrink the surface

- Public only for published API; everything else package-private or private. Interface members are implicitly public.
- In a module, export only API packages. Packages that are not exported stay inaccessible, even their public classes. Prefer qualified `opens … to <framework module>` over unqualified `opens`.
- Each `--add-opens`/`--add-exports` on a command line breaks encapsulation for every caller and blocks JDK upgrades. Name its owner and plan its removal (java-migrate skill).

```java
module com.example.billing {
    exports com.example.billing.api;
    opens com.example.billing.model to com.fasterxml.jackson.databind;
}
```

## EXTEND-4: class loaders

A `ClassLoader` reference gives access to classes and resource URLs the holder could not reach otherwise, and can be cast to a subclass with dangerous methods. Do not return or store loaders received from untrusted code, and treat the thread context class loader as attacker-settable.

## EXTEND-5: final, or designed for inheritance

Make classes `final` unless designed for extension. For a closed hierarchy use `sealed` (final in 17; preview only in 15–16, see errata.md) with `final` leaves; avoid `non-sealed`. Records are implicitly final.

<!-- compile: jdk=17 fails-below -->
```java
sealed interface Credential permits Password, ApiKey {}

record Password(char[] secret) implements Credential {}

record ApiKey(String id, byte[] key) implements Credential {}
```

`java.net.InetAddress` is a JDK example: `sealed … permits Inet4Address, Inet6Address`, both `final`.

## EXTEND-6: a superclass can change under you

A subclass that guards some inherited methods breaks when the superclass adds new ones (`java.security.Provider` lost its checks when `Hashtable` gained `entrySet` in 1.2). Default methods added to an interface do the same. Prefer composition: hold the collection in a private field and expose only guarded operations.

## MUTABLE-1: prefer immutable value types

Immutable classes are final, have final fields, copy mutable inputs and outputs, and hide constructors behind factories when caching or validation needs it. Use `java.time` instead of `Date`/`Calendar`. A record is only shallowly immutable: copy array and collection components in the compact constructor and accessor.

<!-- compile: jdk=16 fails-below -->
```java
import java.util.List;

record Packet(byte[] payload, List<String> tags) {
    Packet {
        payload = payload.clone();
        tags = List.copyOf(tags);
    }

    @Override
    public byte[] payload() {
        return payload.clone();
    }
}
```

`List.copyOf` (10) rejects `null` elements and returns an unmodifiable list. The record's generated `equals` compares the array by identity; override `equals`/`hashCode` with `Arrays.equals`/`Arrays.hashCode` if value equality matters.

## MUTABLE-2, 3, 6, 7: copy at every crossing

- Returning internal mutable state: return a copy (MUTABLE-2).
- Receiving mutable input: copy first, then validate and use the copy, so a caller cannot change it between check and use (TOCTOU, MUTABLE-3). Validation must run after the copy.
- Passing internal state to untrusted code counts as output (MUTABLE-6); values returned by untrusted code count as input (MUTABLE-7).
- Copy untrusted values with a constructor or factory of the concrete type you trust, never with `clone()` on a subclassable type: `Date.clone()` of an attacker's `Date` subclass runs attacker code and returns an attacker object. `clone()` is safe only on a final class (`HttpCookie`) or a trusted instance.
- A collection copy is shallow. Copy mutable elements too.

<!-- compile: jdk=8 -->
```java
import java.util.*;

static final class Period {
    private final Date start;
    private final Date end;

    Period(Date start, Date end) {
        this.start = new Date(start.getTime());
        this.end = new Date(end.getTime());
        if (this.start.after(this.end)) {
            throw new IllegalArgumentException("start after end");
        }
    }

    Date start() {
        return new Date(start.getTime());
    }
}

static List<Date> deepCopy(Collection<? extends Date> dates) {
    List<Date> copy = new ArrayList<>(dates.size());
    for (Date d : dates) {
        copy.add(new Date(d.getTime()));
    }
    return copy;
}
```

`Arrays.asList` wraps an array without copying, so it is no defense. Arrays go out as `array.clone()`.

## MUTABLE-4: offer copies of your mutable classes

Give mutable value classes a copy constructor or static copy factory. Do not implement `Cloneable`: the copied fields cannot be final, every mutable field needs manual copying, and a non-final class's `clone()` returns the subclass.

## MUTABLE-5: do not trust overridable equality

An input's `equals`/`hashCode` can claim to be another object. Key security-relevant maps by identity (`IdentityHashMap`) or by a key object the caller cannot create or override:

<!-- compile: jdk=8 -->
```java
import java.util.*;

static class Window {
    final class PrivateKey {
        Window window() {
            return Window.this;
        }
    }

    final PrivateKey privateKey = new PrivateKey();
}

static final class Extra {}

static final class WindowOps {
    private final Map<Window, Extra> byIdentity = new IdentityHashMap<>();
    private final Map<Window.PrivateKey, Extra> byKey = new WeakHashMap<>();

    Extra byWindow(Window window) {
        return byIdentity.get(window);
    }

    Extra byPrivateKey(Window window) {
        return byKey.get(window.privateKey);
    }
}
```

`PrivateKey` is final and keeps `Object.equals`, so a `Window` subclass cannot fake a match. In the guide this map is declared inside `Window`, where `WindowOps` cannot reach it (errata.md).

## MUTABLE-8: wrap modifiable state

Keep the field private and route changes through a method that validates (and copies, for mutable types) before assignment.

## MUTABLE-9 to 11: static state

- Public and protected static fields are `final` (MUTABLE-9).
- A `public static final` field holds an immutable value. Arrays and collections are not: use `List.of`/`Map.of` (9) or `List.copyOf` (10). `Collections.unmodifiableList` is only a view of a list that someone may still hold and mutate (MUTABLE-10).
- Private mutable statics leak through any method that returns or passes them; treat them as public. Cache only immutable values in statics (MUTABLE-11).

<!-- compile: jdk=9 fails-below -->
```java
import java.util.List;

public static final List<String> ROLES = List.of("reader", "writer", "admin");

private static final byte[] MAGIC = {0x7f, 'E', 'L', 'F'};

static byte[] magic() {
    return MAGIC.clone();
}
```

## MUTABLE-12: do not expose modifiable collections

Getters return `List.copyOf(field)` (snapshot) or `Collections.unmodifiableList(field)` (live read-only view), never the field. Deep-copy when elements are mutable.

## OBJECT-1 to 5: construction

- Prefer static factories over public constructors for sensitive classes; serialization and `clone` add hidden constructors (OBJECT-1).
- A non-final class must be unusable until its constructor completes. A constructor that throws after `Object()` returned leaves an instance a finalizer can resurrect; throw before the superclass constructor runs instead (OBJECT-3, ACCESS-19).
- Constructors, `clone`, `readObject` and `readObjectNoData` must not call overridable methods; they leak `this` half-built (OBJECT-4).
- Non-final classes can be cloned by a subclass that implements `Cloneable`; the "pointer to implementation" pattern or a `final` class prevents it (OBJECT-5).

Before 25, run the check inside the argument of `this(…)` or `super(…)`:

<!-- compile: jdk=8 -->
```java
static class Connector {
    private final String host;

    protected Connector(String host) {
        this(checkHost(host), null);
    }

    private Connector(String host, Void checked) {
        this.host = host;
    }

    private static String checkHost(String host) {
        if (host == null || host.isEmpty()) {
            throw new IllegalArgumentException("host");
        }
        return host;
    }
}
```

From 25, flexible constructor bodies (JEP 513) allow the check as plain statements before `super()`:

<!-- compile: jdk=25 fails-below -->
```java
static class Connector {
    private final String host;

    protected Connector(String host) {
        if (host == null || host.isBlank()) {
            throw new IllegalArgumentException("host");
        }
        super();
        this.host = host;
    }
}
```

Finalization is deprecated for removal since 18 (JEP 421); never rely on `finalize`, and run tests with `--finalization=disabled` to find code that does.

## Review checklist

- Non-API classes are not public; modules export only API packages; no blanket `opens`.
- Security-relevant classes are `final` or `sealed` with final leaves.
- Getters of mutable fields return copies; constructors and setters copy before validating.
- No `clone()` on input of a subclassable type.
- No public non-final static fields; no public static arrays or mutable collections.
- Constructors do not call overridable methods; validation throws before `super()` completes.
