# Access control and the Security Manager (ACCESS-1 to 20)

Contents: applicability · what still matters on 24+ · doPrivileged rules (before 24) · caller-sensitive APIs · invocation handlers · global state · construction and serialization · review checklist.

## Applicability

The Security Manager was deprecated for removal in 17 (JEP 411) and permanently disabled in 24 (JEP 486). On 24+ `System.getSecurityManager()` returns `null`, `AccessController.doPrivileged` just runs the action, and `-Djava.security.manager=…` stops the JVM at startup.

- Release ≥ 24: section 9 of the guide does not protect anything. Remove Security Manager code (java-migrate skill, 21-to-25.md) and isolate untrusted code in separate processes or containers with least OS privileges (FUNDAMENTALS-3).
- Release < 24 with a Security Manager installed: apply the rules below, and plan the removal.
- Either way, the sections on caller-sensitive APIs and invocation handlers still apply: they are about Java language access, not only permissions.

## What still matters on 24+

- Do not hand out capability objects created with your access: `Method`/`Field`/`Constructor` after `setAccessible(true)`, `MethodHandle`, `VarHandle`, `MethodHandles.Lookup` (a full-privilege lookup can define hidden classes in your nest, 15+), `StackWalker` with `RETAIN_CLASS_REFERENCE`, lambdas that wrap privileged work (ACCESS-13).
- Do not call caller-sensitive APIs with class names, resource names or module objects chosen by untrusted code (ACCESS-8, 9, 14).
- Validate methods in `InvocationHandler`s (ACCESS-15).
- Treat process-wide setters as security-relevant global state (ACCESS-17).

## doPrivileged rules (before 24)

Permission checks intersect every frame on the stack. `doPrivileged` truncates the check at its caller, so:

- Never pass caller-provided actions, property names or paths into a privileged block. Hard-code them or validate against a fixed set (ACCESS-3).
- Keep the block as small as possible and check what it returns before handing it back.
- A `null` `AccessControlContext` adds no restriction. Check stored contexts for `null` before using them.
- Reduce privileges by passing a context with a `ProtectionDomain` holding only the needed permissions, after checking the caller already has them (ACCESS-4).

<!-- compile: jdk=17 -->
```java
import java.security.*;

static void runInContext(Runnable task, AccessControlContext acc) {
    if (acc == null) {
        throw new SecurityException("Missing AccessControlContext");
    }
    AccessController.doPrivileged((PrivilegedAction<Void>) () -> {
        task.run();
        return null;
    }, acc);
}

static void doWithFile(Runnable task, String knownPath) {
    Permission perm = new java.io.FilePermission(knownPath, "read,write");
    AccessController.checkPermission(perm);
    PermissionCollection perms = perm.newPermissionCollection();
    perms.add(perm);
    AccessController.doPrivileged((PrivilegedAction<Void>) () -> {
        task.run();
        return null;
    }, new AccessControlContext(new ProtectionDomain[] {new ProtectionDomain(null, perms)}));
}
```

Cache results of privileged operations only with the permission that produced them, and re-check it on every hit (ACCESS-5):

<!-- compile: jdk=17 -->
```java
import java.security.*;
import java.util.concurrent.*;

interface Thing {}

static final class CacheEntry {
    final Thing value;
    final Permission permission;

    CacheEntry(Thing value, Permission permission) {
        this.value = value;
        this.permission = permission;
    }
}

static final ConcurrentMap<String, CacheEntry> CACHE = new ConcurrentHashMap<>();

static Thing getThing(String key) {
    CacheEntry entry = CACHE.get(key);
    if (entry != null) {
        AccessController.checkPermission(entry.permission);
        return entry.value;
    }
    Permission perm = permissionFor(key);
    AccessController.checkPermission(perm);
    PermissionCollection perms = perm.newPermissionCollection();
    perms.add(perm);
    Thing value = AccessController.doPrivileged((PrivilegedAction<Thing>) () -> createThing(key),
            new AccessControlContext(new ProtectionDomain[] {new ProtectionDomain(null, perms)}));
    CACHE.putIfAbsent(key, new CacheEntry(value, perm));
    return value;
}

static Permission permissionFor(String key) {
    return new java.util.PropertyPermission(key, "read");
}

static Thing createThing(String key) {
    return new Thing() {};
}
```

Store `AccessController.getContext()` when registering callbacks and run them with it (ACCESS-6). New threads inherit the context of the code that constructed the `Thread` (ACCESS-7).

## Caller-sensitive APIs (ACCESS-8 to 12, 14)

These methods decide based on the immediate caller's class, class loader or module, so calling them on behalf of untrusted code lends it your identity. `Method.invoke` is skipped when finding the caller (ACCESS-11).

| Kind | Examples |
|------|----------|
| Skip a check when the caller's loader is an ancestor (ACCESS-8) | `Class.getClassLoader`, `Class.getDeclaredMethods`/`Fields`/`Constructors`, `ClassLoader.getParent`, `getSystemClassLoader`, `Thread.getContextClassLoader`, `Proxy.newProxyInstance`, `MethodHandleProxies.asInterfaceInstance`, `StackWalker.getCallerClass`, `SymbolLookup.loaderLookup` |
| Use the caller's loader (ACCESS-9) | `Class.forName`, `System.load`/`loadLibrary`, `Runtime.load`/`loadLibrary`, `ResourceBundle.getBundle`, `DriverManager.getConnection`/`getDriver(s)`/`deregisterDriver`, `Logger.getLogger` |
| Language access checked against the caller (ACCESS-10) | `MethodHandles.lookup`, `AccessibleObject.setAccessible`/`trySetAccessible`/`canAccess`, `Constructor.newInstance`, `Field.get*`/`set*`, `Method.invoke`, `Atomic*FieldUpdater.newUpdater` |
| Use the caller's module (ACCESS-14) | `Module.addExports`/`addOpens`/`addReads`/`addUses`, `Class.getResource(AsStream)`, `Module.getResource(AsStream)`, `ServiceLoader.load`, `System.getLogger`, `ResourceBundle.getBundle` |

Rules: never call these on `Class`, `ClassLoader`, `Constructor`, `Field`, `Method` or `Module` objects received from untrusted code; never pass them untrusted names; never return their results to untrusted code; do not name interface methods after them or call them from default methods (ACCESS-12). The guide's full lists have wrong names (errata.md).

## ACCESS-15: invocation handlers

An `InvocationHandler` acts with its creator's access. Check the proxy, dispatch on name and parameter count, return the declared type, and reject everything else:

<!-- compile: jdk=8 -->
```java
import java.lang.reflect.*;

static final class RunnableHandler implements InvocationHandler {
    private final Runnable target;

    RunnableHandler(Runnable target) {
        this.target = target;
    }

    @Override
    public Object invoke(Object proxy, Method method, Object[] args) {
        if (!Proxy.isProxyClass(proxy.getClass()) || Proxy.getInvocationHandler(proxy) != this) {
            throw new IllegalArgumentException("handler mismatch");
        }
        String name = method.getName();
        int params = method.getParameterCount();
        if (name.equals("hashCode") && params == 0) {
            return System.identityHashCode(proxy);
        }
        if (name.equals("equals") && params == 1) {
            return proxy == args[0];
        }
        if (name.equals("toString") && params == 0) {
            return "RunnableProxy@" + Integer.toHexString(System.identityHashCode(proxy));
        }
        if (name.equals("run") && params == 0) {
            target.run();
            return null;
        }
        throw new UnsupportedOperationException(method.toString());
    }
}
```

Returning the wrong boxed type fails at the call site: the guide's handler returns `true` from `hashCode` and throws `ClassCastException` (errata.md).

## ACCESS-16, 17: package access and global state

- Containers (code hosting less trusted code) add internal packages to the `package.access` security property before untrusted code runs. On 24+ use modules instead (EXTEND-2).
- Isolate unrelated code with separate class loaders (ACCESS-17). The system and thread context class loaders are reachable by everyone.
- Process-wide setters change behavior for all code in the JVM: `System.setProperty`/`setProperties`/`setOut`/`setErr`/`setIn`, `Locale.setDefault`, `TimeZone.setDefault`, `Authenticator.setDefault`, `CookieHandler.setDefault`, `ProxySelector.setDefault`, `ResponseCache.setDefault`, `URL.setURLStreamHandlerFactory`, `HttpsURLConnection.setDefaultHostnameVerifier`/`setDefaultSSLSocketFactory`, `SSLContext.setDefault`, `DatagramSocket.setDatagramSocketImplFactory`, `Thread.setDefaultUncaughtExceptionHandler`, `NamingManager.setInitialContextFactoryBuilder`. Call them once at startup from trusted code, never with untrusted input. A permissive `HostnameVerifier` or trust-all `SSLContext` set as default is a critical finding.

## ACCESS-18 to 20: construction and serialization under a Security Manager

- Check permissions in every public and protected constructor, static factory, `readObject`, `readObjectNoData` and `clone` of a security-sensitive class (ACCESS-18).
- Make the check throw before `Object()` completes so no partially initialized instance exists (ACCESS-19, mutability.md, OBJECT section).
- Do not serialize or deserialize with more privileges than the data deserves (ACCESS-20).

## Review checklist

- Project release ≥ 24 and code still calls `System.getSecurityManager`, `AccessController` or `setSecurityManager`: route to java-migrate (dead code or startup failure).
- `doPrivileged` blocks take no caller-controlled names or actions.
- No reflective objects, method handles or full-privilege lookups returned to callers.
- Caller-sensitive methods receive no untrusted class, resource or library names.
- Invocation handlers reject unknown methods and return the declared types.
- No trust-all TLS defaults or global setters driven by input.
