# Errata: Oracle Secure Coding Guidelines for Java SE

Defects in the code and facts of the source guide (document version 11.0, June 2025, <https://www.oracle.com/java/technologies/javase/seccodeguide.html>). Never copy a snippet from the guide without checking this table. The corrected code lives in the topic references, compiled by `tests/compile-snippets.sh`.

Contents: compile errors · runtime and semantic errors · wrong facts and names · JAXP security guide · how this was checked.

## Compile errors

Each snippet was compiled verbatim with javac 21, adding stubs only for names the guide leaves undefined.

| Guideline | Snippet | Defect | javac says | Fix (reference) |
|-----------|---------|--------|------------|-----------------|
| DOS-2 | `readFileBuffered(InputStream in -> {…})` | A typed lambda parameter needs parentheses | `')' or ',' expected` | `(InputStream in) -> …` or `in -> …` (dos-resources.md) |
| DOS-2 | `public R readFileBuffered(InputStreamHandler handler)` | No `<R>` type parameter; the handler result is never returned, yet the caller above expects a `long` | `cannot find symbol: class R` | `<R> R readFileBuffered(…, InputStreamHandler<R>)` returning `handler.handle(…)` (dos-resources.md) |
| DOS-2 | `public  R locked(Action action)` | No `<R>` type parameter; raw `Action` | `cannot find symbol: class R` | `<R> R locked(Lock, Supplier<R>)` (dos-resources.md) |
| DOS-2 | `new GzipOutputStream(rawOut)` | Class is `java.util.zip.GZIPOutputStream` | `cannot find symbol: class GzipOutputStream` | dos-resources.md |
| INJECT-2 | `ResultSet rs = prepStmt.executeQuery();` | Variable is `stmt`; statement and result set never closed | `cannot find symbol: variable prepStmt` | `stmt.executeQuery()` inside try-with-resources (injection.md) |
| MUTABLE-5 | `WindowOps.op` uses `extras` | The map is declared `private` in `Window`, so `WindowOps` cannot see it | `cannot find symbol: variable extras` | Map belongs to `WindowOps` (mutability.md) |
| SERIAL-3 | `fields.get("data")` in `ByteString` | `GetField` has no one-argument `get`; every overload takes a default value. Also NPEs on a stream with `data == null` | `no suitable method found for get(String)` | `fields.get("data", null)`, null check, then `clone()` (serialization.md) |
| SERIAL-3 | `Nonnegative` constructor `this.data = …` | Field is `value` | `cannot find symbol: variable data` | `this.value = nonnegative(value)` (serialization.md) |
| SERIAL-3 | `nonnegative(field.get(value, 0))` | Variable is `fields`, and the first argument is the field name string | `cannot find symbol: variable field` | `fields.get("value", 0)` (serialization.md) |
| SERIAL-4 | `SecureName.readObject(ObjectInputStream in)` | `readFields()` throws `IOException` and `ClassNotFoundException`; the method declares neither | `unreported exception IOException` | Declare `throws IOException, ClassNotFoundException` (serialization.md) |
| SERIAL-4 | `SecureValue.writeObject(ObjectOutputStream out)` | `out.writeObject` throws `IOException`, undeclared. See also the runtime table | `unreported exception IOException` | serialization.md |
| ACCESS-3 | `doPrivileged(new PrivilegedAction<Void>() { public Void run() { // ... } }, acc)` | `run()` returns `Void` with no `return` | `missing return statement` | `return null;` (access-control-legacy.md) |
| ACCESS-5 | `private static final Map cache;` | Raw `Map` (raw in the page HTML too, so not an escaping loss): `cache.get(key)` is `Object`. The comment cites Guideline 9-2; the technique is 9-4. A static `HashMap` is also unsafe for concurrent callers | `incompatible types: Object cannot be converted to CacheEntry` | `ConcurrentHashMap<String, CacheEntry>` (access-control-legacy.md) |

## Runtime and semantic errors

These compile once the missing `throws` are added, then misbehave. Output from JDK 21 and 25.

| Guideline | Snippet | Defect | Observed | Fix (reference) |
|-----------|---------|--------|----------|-----------------|
| SERIAL-4 | `SensitiveClass.readObject` | Never calls `defaultReadObject()` or `readFields()`, so every serialized field is dropped and stays at its default value | a field set before serialization reads back `null` | Check, then `in.defaultReadObject()` (serialization.md) |
| SERIAL-4 | `SecureValue.writeObject` | Writes `value` without calling `defaultWriteObject()`/`writeFields()` first. The serialization spec (section 2.3) requires exactly one of them "even if no optional data is written". The round trip only works because the class has one object field, so the default reader happens to consume the next object | works by accident; breaks when a field is added | `securityCheck(); out.defaultWriteObject();` (serialization.md) |
| ACCESS-15 | `InvocationHandler.invoke`, `hashCode` branch | Returns `true` for `hashCode()` | `ClassCastException: class java.lang.Boolean cannot be cast to class java.lang.Integer` on `proxy.hashCode()` | Return an `int` (`System.identityHashCode(proxy)`) (access-control-legacy.md) |
| ACCESS-9, JNI-6 | `System.loadLibrary("/com/foo/MyLib.so")` | `loadLibrary` takes a library name and maps it to a platform file name (`MyLib` → `libMyLib.so`). A path is rejected | `UnsatisfiedLinkError: Directory separator should not appear in library name: /com/foo/MyLib.so` | `System.loadLibrary("MyLib")`, or `System.load` with an absolute path (input-validation-native.md) |
| INJECT-9 | "casting … to short, integer and long … positive infinite value is transformed to `Integer.MAX_VALUE`" | True for `int` only. `(long)+Inf` is `Long.MAX_VALUE`; `(short)+Inf` is `-1`, because the double is narrowed to `int` first, then to `short` | `(short)+Inf=-1 (short)-Inf=0 (long)+Inf=9223372036854775807` | injection.md |

## Wrong facts and names

| Guideline | Guide says | Right |
|-----------|-----------|-------|
| EXTEND-5 | "Java SE 15 introduced sealed classes" | Preview in 15 (JEP 360) and 16 (JEP 397), final in 17 (JEP 409, the guide's own reference [30]). Without `--enable-preview`, `sealed` needs release 17 |
| INJECT-8 | Running annotation processors found in the code base "is disabled by default" | Only from JDK 23. Before 23, javac ran any processor it found on the class path (21–22 warn). See jdk-matrix.md |
| INJECT-9 | `isNan` | `Double.isNaN` |
| MUTABLE-12 | `Arrays.asList()` "creates a copy backed by the array" | It creates no copy. It returns a fixed-size view, so writes go both ways (the guide's conclusion stands) |
| ACCESS-8 | Diagram shows `xx.lib.LibClass` being instantiated | The code above it calls `OtherClass.class.newInstance()`. `Class.newInstance` is deprecated since 9; use `getDeclaredConstructor().newInstance()` |
| ACCESS-4 | `someMethod(PrivilegedAction<Void> action)` in the no-permissions example | `action` is never used; an anonymous action runs instead |
| ACCESS-10 | `java.lang.reflect.AccessibleObject.tryAccessible` | `trySetAccessible` |
| ACCESS-14 | `MethodHandles.privateLookupIn` uses the caller's module | Not `@CallerSensitive` in JDK 11, 17 or 21. It checks the `Lookup` passed as its second argument |
| ACCESS-17 | `java.net.Datagram.setDatagramSocketImplFactory` | `java.net.DatagramSocket.setDatagramSocketImplFactory` |
| ACCESS-17 | `javax.security.auth.login.Policy.setPolicy` | Class was `javax.security.auth.Policy`, absent from JDK 11 on |
| ACCESS-17 | `java.rmi.activation.ActivationGroup.createGroup`, `setSystem` "(deprecated)" | RMI Activation was removed in 17 (JEP 407) |
| ACCESS-17 | `java.beans.PropertyEditorFinder.registerEditor`, `setEdiorSearchPath` | `java.beans.PropertyEditorManager.registerEditor`, `setEditorSearchPath` |
| ACCESS-17 | `javax.print.StreamPrintServiceFactory.lookupStreamPrintServices` | `lookupStreamPrintServiceFactories` |

Checked and correct, despite looking suspicious: `label.putClientProperty("html.disable", true)` (autoboxing yields `Boolean.TRUE`), `InetAddress` is `sealed … permits Inet4Address, Inet6Address` with both subclasses `final`, `HttpCookie` is `final`, `Integer.MIN_VALUE == -Integer.MIN_VALUE` and `== Math.abs(Integer.MIN_VALUE)`, `Objects.checkFromIndexSize(1, Integer.MAX_VALUE, 10)` throws, the `NativeMethodWrapper` overflow checks, the serialization filter backports (8u121, 7u131, 6u141).

## JAXP security guide

The Secure Coding guide points to the JAXP Security Guide for XML settings (its reference [29]). The JDK 25, 26 and 27 editions have the same content and these defects. Defaults below were read from `conf/jaxp.properties` and observed on JDK 27.

| Section | Guide says | Right |
|---------|-----------|-------|
| Limiting Entity Expansion | "By default, entityExpansionLimit is set to 64,000" | 2500 since 24, as the guide's own Table 12-2 says. 64000 was the default up to 23 |
| Limiting the Number of Element Attributes | "By default, jdk.xml.elementAttributeLimit is set to 10,000" | 200 since 24 (Table 12-2 again) |
| Table 12-2 | `jdk.xml.xpathTotalOpLimit` default 100000 | 10000 (`jaxp.properties`, module summary) |
| Table 12-3 | `TransformerFactory`: FSP enabled "false" | `getFeature(FEATURE_SECURE_PROCESSING)` returns `true` by default for DOM, SAX, schema and transformer factories; only `XPathFactory` returns `false`. The guide's own FSP section agrees |
| Table 12-4 | Captioned "The jdk.xml.enableExtensionFunctions Property" | Describes `jdk.xml.overrideDefaultParser` |
| Element attribute sample | "sets the parser property …/entity-expansion-limit to 20" | The code sets `…/elementAttributeLimit` |
| Entity expansion and attribute samples | `dfactory.setAttribute(…)` then `dbFactory.newDocumentBuilder()`; `new Integer("10000")` | One variable name; `Integer.valueOf` (the constructors are deprecated since 9) |
| Entity Resolvers for SAX and DOM | `DocumentBuilder builder = …; docBuilder.setEntityResolver(resolver);` | One variable name |
| Catalog Resolver | `URI catalogUri = URI.create("…")` | Missing `;` |
| XInclude example | `href=toc.xml"` | `href="toc.xml"` |
| Command-line example | `java -DentityExpansionLimit=10000` | Works only as the legacy name; use `-Djdk.xml.entityExpansionLimit=10000` |

## How this was checked

- Snippets: every code block of the guide compiled verbatim with javac 21 (the last LTS where the Security Manager APIs still run), with stubs only for undefined names. Diagrams, method lists and `...` pseudo-code were judged by reading.
- Behavior: a runner on JDK 21 and 25 for the proxy `hashCode`, `loadLibrary`, floating-point casts, serialization round trips, `Arrays.asList`, `InetAddress` and `HttpCookie` modifiers.
- Method lists: each entry looked up in the JDK 11, 17 and 21 `src.zip`, including its `@CallerSensitive` annotation.
- Facts: JEP pages 360 and 409, the Java Object Serialization Specification (JDK 25, section 2.3), JDK-8306632 and JDK-8343022, the `java.xml` module summaries of JDK 21 to 27.
- XML: the JAXP security guides of JDK 22 to 27 read and diffed (25 = 26 = 27), `jaxp.properties` and the strict template compared on 21, 25 and 27, and an attack run (external file entity, entity bomb, XSLT extension call) against default and hardened factories on 21, 25 and 27, with and without `jdk.xml.dtd.support`, `jdk.xml.jdkcatalog.resolve` and the strict template, plus Woodstox 7.1 on the class path.
