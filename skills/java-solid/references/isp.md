# Interface Segregation Principle (ISP)

Contents: rule · example · the JDK does it too · smells · when not to split · checklist.

## Rule

No client should depend on methods it does not use. The client owns the interface: name it after what the client needs, and let one class implement several of them.

## Example

Drivers ride, mechanics swap engines. Each holds only the interface it calls, so a change to engine handling never touches `Driver` or its tests.

<!-- compile: jdk=16 -->
```java
import java.util.Objects;

enum Status { OPEN, LOCKED }

record Gas(int litres) {}

record Speed(int kmh) {}

record Engine(String model) {}

interface RidableCar {
    Status open();

    Speed drive(Gas gas);
}

interface FixableCar {
    Engine changeEngine(Engine newEngine);
}

static final class Driver {
    private final RidableCar car;

    Driver(RidableCar car) {
        this.car = Objects.requireNonNull(car);
    }

    Speed ride() {
        car.open();
        return car.drive(new Gas(10));
    }
}

static final class Mechanic {
    private final FixableCar car;

    Mechanic(FixableCar car) {
        this.car = Objects.requireNonNull(car);
    }

    Engine fixEngine(Engine newEngine) {
        return car.changeEngine(newEngine);
    }
}
```

A `Car` class implements both interfaces. Below release 16, write the records as final classes.

## The JDK does it too

JDK 17 extracted `InstantSource` from the abstract class `Clock`: code that only needs "now" no longer depends on time zones. Accept it instead of `Clock`, and pass `Clock.systemUTC()` or a fixed source in tests.

<!-- compile: jdk=17 fails-below -->
```java
import java.time.Duration;
import java.time.InstantSource;

record Session(java.time.Instant expiresAt) {
    boolean isExpired(InstantSource time) {
        return time.instant().isAfter(expiresAt);
    }

    Session extend(InstantSource time, Duration ttl) {
        return new Session(time.instant().plus(ttl));
    }
}
```

The `java.util.function` interfaces are the narrowest interfaces there are: a parameter typed `Supplier<T>` or `Predicate<T>` accepts any lambda.

## Smells

- Implementations full of `UnsupportedOperationException` or empty bodies.
- Mocks that stub one method of a twenty-method interface.
- Adding a method forces edits or recompiles in clients that never call it.
- Default methods added to a fat interface to avoid touching implementers: the clients still see every method.

## When not to split

- Split by client group, not by method. One interface per method everywhere is noise.
- An interface with one client and one implementation needs no further split.

## Checklist

1. For each client, list the methods it calls on the interface.
2. Clients that call disjoint sets mark the split; name each new interface after its client's role.
3. The implementation implements all new interfaces; the old interface may extend them during migration.
4. Change each client's field and parameter types to its narrow interface; tests green.
