# Concurrency

Contents: virtual threads (21) · pinning (fixed in 24) · scoped values (25) · fan-out without preview APIs · structured concurrency status · do-not-convert rules.

## Virtual threads — JEP 444, final 21

Signal: `fixed-pool`. Virtual threads make thread-per-task cheap for **blocking I/O** (HTTP calls, JDBC, file I/O). They do not make CPU-bound work faster.

<!-- compile: jdk=21 fails-below -->
```java
import java.util.List;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.function.Function;

static <T, R> List<R> fetchAll(List<T> inputs, Function<T, R> blockingCall)
        throws InterruptedException, ExecutionException {
    try (ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor()) {
        List<Future<R>> futures = inputs.stream()
                .map(in -> executor.submit(() -> blockingCall.apply(in)))
                .toList();
        List<R> results = new java.util.ArrayList<>();
        for (Future<R> f : futures) results.add(f.get());
        return results;
    }   // close() waits for all tasks
}

static Thread startWorker(Runnable task) {
    return Thread.ofVirtual().name("worker-", 0).start(task);
}
```

Rules:

- Never pool virtual threads. One per task; the executor above creates them on demand.
- A fixed pool also acted as a **concurrency limit** (for example, at most 20 calls to a fragile backend). Keep that limit explicitly with a `Semaphore`, otherwise thousands of concurrent calls hit the backend or exhaust the JDBC pool.
- `ThreadLocal` caches of expensive objects (one `SimpleDateFormat` per thread) become one per task: replace with thread-safe objects (`DateTimeFormatter`) or explicit pools.
- Frameworks: Spring Boot `spring.threads.virtual.enabled=true` (3.2+), Quarkus `@RunOnVirtualThread`, Helidon 4 by default. Use the framework switch instead of hand-made executors.

<!-- compile: jdk=21 -->
```java
import java.util.concurrent.Semaphore;
import java.util.function.Supplier;

static final Semaphore BACKEND_PERMITS = new Semaphore(20);

static <T> T callBackend(Supplier<T> call) throws InterruptedException {
    BACKEND_PERMITS.acquire();
    try {
        return call.get();
    } finally {
        BACKEND_PERMITS.release();
    }
}
```

## Pinning — JEP 491 (24)

On 21–23 a virtual thread blocking inside `synchronized` pins its carrier thread; heavy use can starve the scheduler. On 21–23 replace long blocking sections inside `synchronized` with `ReentrantLock`. From 24 `synchronized` no longer pins (native frames still do); no change needed.

## Scoped values — JEP 506, final 25

Signal: `thread-local`. `ScopedValue` binds a value for the duration of a call; readers get it with `get()`. Immutable, automatically inherited by structured child tasks, no `remove()` leaks.

<!-- compile: jdk=25 fails-below -->
```java
static final ScopedValue<String> REQUEST_ID = ScopedValue.newInstance();

static String handle(String requestId) throws Exception {
    return ScopedValue.where(REQUEST_ID, requestId).call(() -> service());
}

static String service() {
    String id = REQUEST_ID.isBound() ? REQUEST_ID.get() : "none";
    return "handled " + id;
}

static void handleAsync(String requestId, Runnable work) {
    ScopedValue.where(REQUEST_ID, requestId).run(work);
}
```

Convert a `ThreadLocal` only when it is set once at the start of a unit of work, read below it, and cleared at the end (request context, tenant id, security principal). Keep `ThreadLocal` when:

- Code calls `set` repeatedly or mutates the value during the scope.
- It caches a per-thread object for reuse.
- Libraries read it (MDC in logging, Spring `RequestContextHolder`, transaction synchronization). Those need the library's own support.
- The value must be visible in threads not started inside the scope (plain executors do not inherit scoped values).

`orElse(null)` is not allowed; use `isBound()`.

## Fan-out without preview APIs

Structured concurrency (`StructuredTaskScope`) is preview in every JDK through 27, and its API changed in 25 and again in 27. For "run subtasks, fail fast, cancel the rest" use final APIs:

<!-- compile: jdk=21 -->
```java
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

record UserAndOrder(String user, String order) {}

static UserAndOrder load(Callable<String> user, Callable<String> order)
        throws InterruptedException, ExecutionException {
    try (ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor()) {
        Future<String> u = executor.submit(user);
        Future<String> o = executor.submit(order);
        try {
            return new UserAndOrder(u.get(), o.get());
        } catch (ExecutionException | InterruptedException e) {
            u.cancel(true);
            o.cancel(true);
            throw e;
        }
    }
}
```

If the user opts into preview on an exact JDK, see `preview-features.md`.

## Do not convert when

- Work is CPU-bound (parsing, compression, crypto loops): keep a bounded platform pool sized to cores, or parallel streams.
- The pool's size was a deliberate throttle and no replacement limit is added.
- Native code or `Object.wait` dominate on 21–23 (pinning).
- The project runs on a release below 21 (virtual threads) or 25 (scoped values).
