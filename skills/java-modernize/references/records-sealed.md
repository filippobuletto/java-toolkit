# Records and sealed types

Contents: records (16) · compact constructors and validation · records as API change · do-not-convert rules · sealed classes and interfaces (17) · combining with pattern switch.

## Records — JEP 395, final 16

Signal: `data-class` (hand-written `equals(Object)`). A record fits a class that is a transparent, shallowly immutable carrier of its fields.

Before:

<!-- compile: jdk=8 -->
```java
import java.util.Objects;

static final class Money {
    private final String currency;
    private final long cents;

    Money(String currency, long cents) {
        this.currency = Objects.requireNonNull(currency);
        this.cents = cents;
    }

    String currency() { return currency; }
    long cents() { return cents; }

    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof Money)) return false;
        Money m = (Money) o;
        return cents == m.cents && currency.equals(m.currency);
    }
    @Override public int hashCode() { return Objects.hash(currency, cents); }
    @Override public String toString() { return "Money[currency=" + currency + ", cents=" + cents + "]"; }
}
```

After:

<!-- compile: jdk=16 fails-below -->
```java
import java.util.Objects;

record Money(String currency, long cents) {
    Money {
        Objects.requireNonNull(currency, "currency");
        if (cents < 0) throw new IllegalArgumentException("cents < 0");
    }

    Money plus(Money other) {
        if (!currency.equals(other.currency)) throw new IllegalArgumentException("currency mismatch");
        return new Money(currency, cents + other.cents);
    }

    static Money zero(String currency) {
        return new Money(currency, 0);
    }
}
```

Compact constructors validate or normalize; they assign fields implicitly. Defensive copies of mutable components go there too (`items = List.copyOf(items);`).

"Wither" methods are plain methods returning `new Money(...)`. Derived record creation (`money with { cents = 0; }`, JEP 468) never shipped; do not write it.

## Records change the API

- Accessors are `currency()`, not `getCurrency()`. Callers, EL/JSP/Thymeleaf expressions, and frameworks that expect JavaBean getters break. Jackson 2.12+ handles records; older versions do not.
- `toString` format becomes `Money[currency=EUR, cents=5]`. Logs and tests that match the old format change.
- Records are `final`, extend `java.lang.Record`, and cannot declare instance fields beyond components.
- Serialization: record serialization uses the canonical constructor, and the stream format differs from the old class. Persisted serialized data of the old class will not deserialize into the record.

For public types, get user approval or keep JavaBean getters as extra methods during a transition.

## Do not convert to a record when

- The class is a JPA/Hibernate entity (needs no-arg constructor, mutable state, proxies) or any framework-managed mutable bean.
- Fields are mutated after construction, or identity matters (`==`, synchronization, caches keyed by identity).
- It extends another class or is meant to be subclassed.
- `equals` deliberately ignores some fields or compares by id only.
- Lazy or derived fields are cached in instance fields.
- The code must still compile for a release below 16.

Lombok `@Value` classes are usually good record candidates; `@Data` classes usually are not (mutable).

## Sealed classes and interfaces — JEP 409, final 17

Use when the set of subtypes is closed and known: domain results (`Success | Failure`), commands, AST nodes, state machines. Subtypes must be `final`, `sealed`, or `non-sealed`, and live in the same module (or same package in the unnamed module).

<!-- compile: jdk=17 fails-below -->
```java
sealed interface PaymentResult permits Approved, Declined, Pending {}
record Approved(String authCode) implements PaymentResult {}
record Declined(String reason) implements PaymentResult {}
final class Pending implements PaymentResult {
    final long retryAfterMillis;
    Pending(long retryAfterMillis) { this.retryAfterMillis = retryAfterMillis; }
}
```

`permits` can be omitted when all subtypes are in the same file.

## Sealed + pattern switch (21)

An exhaustive switch over a sealed type needs no `default`. Adding a subtype then fails compilation at every switch that does not handle it — the reason to prefer this over `default`.

<!-- compile: jdk=21 fails-below -->
```java
sealed interface PaymentResult permits Approved, Declined {}
record Approved(String authCode) implements PaymentResult {}
record Declined(String reason) implements PaymentResult {}

static String message(PaymentResult result) {
    return switch (result) {
        case Approved(var code) -> "approved " + code;
        case Declined(var reason) -> "declined: " + reason;
    };
}
```

## Do not seal when

- The hierarchy is a public extension point (plugins, SPI, framework callbacks).
- Subtypes live in other modules or are generated (proxies, mocks: Mockito cannot mock a sealed interface's unknown subtype, and final records cannot be mocked without the inline mock maker).
