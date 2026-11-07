# Denial of service and resources (DOS-1 to DOS-5)

Contents: disproportionate resources · releasing resources · overflow-safe limit checks · exception policy · untrusted hash keys · review checklist.

## DOS-1: bound what input can make you spend

Check sizes before work, not after. Typical sinks:

- Decompression (zip bombs): limit the decompressed bytes, never trust the compressed size or entry metadata.
- XML entity expansion ("billion laughs"): see injection.md, XML section.
- Image and font headers: read the dimensions and reject them before allocating pixel buffers.
- Untrusted lengths, counts, offsets: compare with a maximum before allocating or copying.
- Regular expressions on untrusted input: `java.util.regex` has no timeout. Avoid nested quantifiers such as `(a+)+` and bound the input length first.
- Java and JavaBeans XML deserialization: avoid it; see serialization.md.
- Logging of attacker-triggered events: rate-limit or aggregate.
- Parsing loops: every iteration must consume input or exit.

Decompress with a hard limit:

<!-- compile: jdk=11 fails-below -->
```java
import java.io.*;
import java.util.zip.GZIPInputStream;

static byte[] gunzip(InputStream compressed, int maxBytes) throws IOException {
    try (InputStream in = new GZIPInputStream(compressed)) {
        byte[] out = in.readNBytes(maxBytes + 1);
        if (out.length > maxBytes) {
            throw new IOException("decompressed size exceeds " + maxBytes + " bytes");
        }
        return out;
    }
}
```

`readNBytes(int)` is from 11. On 8, copy through a buffer and count. ZIP archives need the same per-entry and total limits plus a path check; see input-validation-native.md.

## DOS-2: release resources on every path

Use try-with-resources for anything `AutoCloseable`. Put the acquire/release pair in one method ("execute around") and pass the work in as a lambda.

<!-- compile: jdk=8 -->
```java
import java.io.*;
import java.nio.file.*;

@FunctionalInterface
interface InputStreamHandler<R> {
    R handle(InputStream in) throws IOException;
}

static <R> R readFileBuffered(Path path, InputStreamHandler<R> handler) throws IOException {
    try (InputStream in = Files.newInputStream(path)) {
        return handler.handle(new BufferedInputStream(in));
    }
}

static long byteSum(Path path) throws IOException {
    return readFileBuffered(path, in -> {
        long sum = 0;
        for (int b; (b = in.read()) != -1; ) {
            sum += b;
        }
        return sum;
    });
}
```

Locks are not `AutoCloseable`. Keep the standard idiom and do not rearrange it:

<!-- compile: jdk=8 -->
```java
import java.util.concurrent.locks.Lock;
import java.util.function.Supplier;

static <R> R locked(Lock lock, Supplier<R> action) {
    lock.lock();
    try {
        return action.get();
    } finally {
        lock.unlock();
    }
}
```

Flush buffered output inside the `try` so a failed flush throws. Declare every decorator that holds native memory (`GZIPOutputStream`, `Deflater`, `Inflater`) as its own resource, so it closes even when an outer wrapper's constructor fails:

<!-- compile: jdk=8 -->
```java
import java.io.*;
import java.nio.file.*;
import java.util.zip.GZIPOutputStream;

@FunctionalInterface
interface OutputStreamHandler {
    void handle(OutputStream out) throws IOException;
}

static void writeGzipFile(Path path, OutputStreamHandler handler) throws IOException {
    try (OutputStream rawOut = Files.newOutputStream(path);
         OutputStream compressedOut = new GZIPOutputStream(rawOut)) {
        BufferedOutputStream out = new BufferedOutputStream(compressedOut);
        handler.handle(out);
        out.flush();
    }
}
```

A `try` that blocks forever never reaches its `finally`. Put timeouts on network and lock waits (`Socket.setSoTimeout`, `HttpClient` timeouts, `Lock.tryLock(timeout)`).

## DOS-3: limit checks must not overflow

`current + extra > max` overflows to a negative sum for large values and lets the check pass. Rearrange the comparison, or use the exact-arithmetic methods (8) that throw `ArithmeticException`:

<!-- compile: jdk=8 -->
```java
static long current;
static final long MAX = 1L << 30;

static void checkGrowBy(long extra) {
    if (extra < 0 || current > MAX - extra) {
        throw new IllegalArgumentException("limit exceeded");
    }
}

static int totalSize(int headerBytes, int count, int elementBytes) {
    return Math.addExact(headerBytes, Math.multiplyExact(count, elementBytes));
}
```

For offset/length pairs use `Objects.checkFromIndexSize` (9). It throws `IndexOutOfBoundsException` and is overflow-safe:

<!-- compile: jdk=9 fails-below -->
```java
import java.io.*;
import java.util.Objects;

static void write(OutputStream sink, byte[] b, int off, int len) throws IOException {
    Objects.checkFromIndexSize(off, len, b.length);
    for (int i = 0; i < len; i++) {
        sink.write(b[off + i]);
    }
}
```

`Integer.MIN_VALUE == -Integer.MIN_VALUE` and `Math.abs(Integer.MIN_VALUE) < 0`; the same holds for `long`. `Math.absExact` (15) throws instead.

## DOS-4: an exception policy at the dispatch level

Most code propagates exceptions. Code that dispatches units of work (request handlers, executors, consumers) catches `Throwable` per unit, discards that unit, logs, cleans up, and moves on. Exit and let a supervisor restart the process when the state is unrecoverable (`OutOfMemoryError` in shared caches, corrupted invariants). Set a `Thread.UncaughtExceptionHandler` on long-lived threads as a last resort.

## DOS-5: untrusted hash keys

Many attacker-chosen keys with equal hash codes turn a `HashMap` into a list. Since JDK 8 (JEP 180) colliding buckets become balanced trees when the keys are `Comparable`, so lookups degrade to O(log n), not O(n). Use `Comparable` key types (`String`, records of comparable fields) for maps filled from untrusted input, and cap the number of entries (JSON objects, form fields, headers).

## Review checklist

- Every `new byte[n]`, `new ArrayList<>(n)` or `ByteBuffer.allocate(n)` with `n` from input has an upper bound.
- `+` and `*` in size checks are rearranged or use `Math.*Exact`.
- `GZIPInputStream`, `InflaterInputStream`, `ZipInputStream` reads are counted against a limit.
- Every stream, channel, connection and lock is released in try-with-resources or `finally`.
- Network and lock waits have timeouts.
