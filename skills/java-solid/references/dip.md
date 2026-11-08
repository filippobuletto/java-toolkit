# Dependency Inversion Principle (DIP)

Contents: rule · example · wiring · smells · when not to apply · checklist.

## Rule

High-level policy does not depend on low-level detail; both depend on an abstraction, and the policy side owns it. The interface lives in the policy package and speaks its language (`InvoiceStore.find`), not the detail's (`Connector.open`). Source dependencies then point from the JDBC code toward the domain, against the flow of control.

Dependency injection is one way to hand the detail to the policy at run time. DIP is the direction of the source dependency; constructor injection achieves it without any framework.

## Example

<!-- compile: jdk=16 -->
```java
import java.util.HashMap;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Objects;
import java.util.Optional;

// Policy: owns the abstraction.
record Invoice(String id, long amountCents, boolean paid) {
    Invoice markPaid() {
        return new Invoice(id, amountCents, true);
    }
}

interface InvoiceStore {
    Optional<Invoice> find(String id);

    void save(Invoice invoice);
}

static final class InvoiceService {
    private final InvoiceStore store;

    InvoiceService(InvoiceStore store) {
        this.store = Objects.requireNonNull(store);
    }

    void pay(String id) {
        Invoice invoice = store.find(id).orElseThrow(() -> new NoSuchElementException("invoice " + id));
        store.save(invoice.markPaid());
    }
}

// Detail: depends on the policy's interface. A JdbcInvoiceStore sits beside it.
static final class InMemoryInvoiceStore implements InvoiceStore {
    private final Map<String, Invoice> invoices = new HashMap<>();

    @Override
    public Optional<Invoice> find(String id) {
        return Optional.ofNullable(invoices.get(id));
    }

    @Override
    public void save(Invoice invoice) {
        invoices.put(invoice.id(), invoice);
    }
}
```

## Wiring

- Constructor injection at a composition root (`main`, a configuration class) is enough. Spring, CDI and Guice automate the same wiring.
- `ServiceLoader` with module `uses` / `provides` (9) lets a policy module find implementations it never names.
- Volatile ambient inputs are dependencies too. Inject `InstantSource` or `Clock` instead of calling `Instant.now()`, and a configuration record instead of reading `System.getProperty` or `System.getenv` inside policy code.

## Smells

- Policy code creates infrastructure: `new JdbcTemplate(...)`, `HttpClient.newHttpClient()`, `new FooRepositoryImpl()`.
- Static calls into infrastructure or singletons: `Foo.getInstance()`, static `*Util` that does I/O.
- Domain packages import `java.sql`, HTTP clients or framework types. `jdeps -verbose:package` on the compiled classes shows the direction.
- Interfaces that mirror one implementation's methods and live in its package.

## When not to apply

- Stable concretions are fine: `String`, collections, `java.time` values, records, pure functions.
- One implementation with no boundary to cross (no I/O, no test seam needed) does not need an interface.
- Do not add a `FooImpl` for every `Foo`. Invert at boundaries: persistence, network, clock, file system, external services.

## Checklist

1. Find where policy code touches I/O, time, configuration or frameworks.
2. Define an interface in the policy package, named after what the policy needs.
3. Move the existing code into an implementation in the detail package.
4. Inject the implementation through the constructor at the composition root; tests use an in-memory or stub implementation.
