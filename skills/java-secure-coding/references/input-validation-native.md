# Input validation and native code (INPUT-1 to 4, JNI-1 to 10)

Contents: validate inputs · file paths · ZIP and JAR files · API validation behavior · native wrappers · library loading · native code practices · review checklist.

## INPUT-1, 2: validate at the boundary, again before sensitive use

- Validate input from untrusted sources where it enters, and again right before a security-sensitive use, with checks specific to that use. Earlier validation may have assumed another context.
- Validate after the defensive copy, never before (MUTABLE-3).
- Return values of upcalls into untrusted code are input (INPUT-2). Two calls to an untrusted `ClassLoader.loadClass` may return different classes.
- Keep convenience parsing (lenient formats, auto-correction) out of programmatic interfaces.

## Paths from untrusted names

Resolve against a fixed base, normalize, and check the result stays inside it. `normalize()` removes `..` but does not follow symbolic links; for existing files compare real paths as well.

<!-- compile: jdk=8 -->
```java
import java.io.IOException;
import java.nio.file.*;

static Path resolveInside(Path baseDir, String untrustedName) throws IOException {
    Path root = baseDir.toRealPath();
    Path candidate = root.resolve(untrustedName).normalize();
    if (!candidate.startsWith(root)) {
        throw new IllegalArgumentException("path escapes base directory");
    }
    if (Files.exists(candidate) && !candidate.toRealPath().startsWith(root)) {
        throw new IllegalArgumentException("path escapes base directory through a link");
    }
    return candidate;
}
```

`Path.startsWith` compares name elements, so `/srv/data2` does not start with `/srv/data`. `String.startsWith` on path strings gets this wrong. An absolute `untrustedName` replaces the base in `resolve`; the check above catches it.

## ZIP and JAR files

Archives can hold conflicting, duplicate or missing entries, and signed JARs can contain unsigned entries. `ZipFile` reads the central directory and `ZipInputStream` reads local headers, so the two APIs can see different content. Use one API consistently, and on extraction check every entry name (zip slip), the entry count and the total size:

<!-- compile: jdk=8 -->
```java
import java.io.*;
import java.nio.file.*;
import java.util.zip.*;

static void unzip(Path zip, Path destDir, int maxEntries, long maxTotalBytes) throws IOException {
    Path root = destDir.toRealPath();
    int entries = 0;
    long total = 0;
    byte[] buf = new byte[8192];
    try (ZipInputStream in = new ZipInputStream(Files.newInputStream(zip))) {
        for (ZipEntry e; (e = in.getNextEntry()) != null; ) {
            if (++entries > maxEntries) {
                throw new IOException("too many entries");
            }
            Path target = root.resolve(e.getName()).normalize();
            if (!target.startsWith(root)) {
                throw new IOException("entry escapes destination");
            }
            if (e.isDirectory()) {
                Files.createDirectories(target);
                continue;
            }
            Files.createDirectories(target.getParent());
            try (OutputStream out = Files.newOutputStream(target, StandardOpenOption.CREATE_NEW)) {
                for (int n; (n = in.read(buf)) > 0; ) {
                    total += n;
                    if (total > maxTotalBytes) {
                        throw new IOException("archive expands beyond " + maxTotalBytes + " bytes");
                    }
                    out.write(buf, 0, n);
                }
            }
        }
    }
}
```

`CREATE_NEW` refuses to overwrite existing files, including a duplicate entry name. Count bytes actually read; `ZipEntry.getSize()` comes from the archive and can lie.

## INPUT-4: know what an API really validates

- Do not assume a parser rejects input that violates its documented syntax unless the documentation says it throws. `java.net.URI`, `URL`, `InetAddress` and file-path APIs are lenient in places.
- If an object's constructor validates, use the constructed object afterwards, not the original string; the constructor may have normalized or escaped it.
- Different parsers disagree on URLs, paths and archives (`URI` vs `URL` vs an HTTP client vs a proxy). Parse once with one API and pass the parsed object along.
- Add context checks on top of syntax checks: ranges, allow-lists, host allow-lists for outbound requests (SSRF).

## INPUT-3, JNI-4: private native methods behind validating wrappers

Native code gets no bounds checks. Declare `native` methods `private` and validate in a Java wrapper; copy mutable arrays first so the caller cannot change them during the call:

<!-- compile: jdk=9 fails-below -->
```java
import java.util.Objects;

static final class NativeMethodWrapper {
    private native void nativeOperation(byte[] data, int offset, int len);

    public void doOperation(byte[] data, int offset, int len) {
        byte[] copy = data.clone();
        Objects.checkFromIndexSize(offset, len, copy.length);
        nativeOperation(copy, offset, len);
    }
}
```

`checkFromIndexSize` (9) is the overflow-safe form of `offset < 0 || len < 0 || offset > length - len`; the guide's `Math.addExact` variant is also correct. Keep native addresses (`long` handles) in private fields, never hand them to untrusted code, and prefer stateless native calls.

## JNI-6: load libraries safely

- `System.loadLibrary("mylib")` takes a library *name* and maps it to `libmylib.so`, `libmylib.dylib` or `mylib.dll` on `java.library.path`. A path such as `"/com/foo/MyLib.so"` throws `UnsatisfiedLinkError` (errata.md). `System.load` takes an absolute path.
- Never build either argument from untrusted input. Do not load libraries on behalf of other code; `loadLibrary` uses the immediate caller's class loader.
- From JDK 24 (JEP 472) loading a library and linking a native method print a warning unless native access is enabled: `--enable-native-access=<module>` or `ALL-UNNAMED`, or the `Enable-Native-Access: ALL-UNNAMED` manifest attribute for executable JARs. Grant it to the one module that needs it (java-migrate skill, 21-to-25.md).
- Avoid relative `RPATH`/`RUNPATH` entries and writable directories on `LD_LIBRARY_PATH`; inspect native libraries with `checksec`.

## JNI-1, 2, 3, 5, 7 to 10: native code practices

- Prefer pure Java, and from 22 the Foreign Function and Memory API (JEP 454) over hand-written JNI glue (JNI-1).
- Native code ignores Java access control, can re-register native methods of other classes and can read any memory in the process (JNI-3).
- Revalidate inputs on the native side: unsigned C types turn negative Java ints into huge values (JNI-7). Run tests with `-Xcheck:jni`.
- Check for pending exceptions after every JNI call into Java and handle `NULL` returns (`GetFieldID`, `NewStringUTF`) (JNI-8).
- Test concurrent access; synchronize shared native state (JNI-5).
- Build with stack protectors, ASLR, NX, RELRO; ship 64-bit builds (JNI-9).
- Bundled JREs and native dependencies need security updates like any dependency (JNI-10, FUNDAMENTALS-8).

## Review checklist

- File names, archive entries and URLs from input are resolved against a base and checked with `Path.startsWith` or an allow-list.
- Archive extraction counts entries and bytes read.
- No `public native` methods; wrappers copy and range-check arguments.
- `System.loadLibrary` gets a constant name; `System.load` a constant absolute path.
- `--enable-native-access` names a module, not `ALL-UNNAMED`, where the code is modular.
