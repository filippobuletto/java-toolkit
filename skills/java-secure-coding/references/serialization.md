# Serialization and deserialization (SERIAL-1 to 6)

Contents: avoid it · sensitive fields · readObject as a constructor · duplicate checks · records · filters · review checklist.

Deserializing untrusted data with `ObjectInputStream` is a code-execution risk: gadget classes on the class path run during `readObject`. First choice: do not do it. Use a data format (JSON, Protobuf) bound to explicit types. Third-party serializers (Jackson polymorphic typing, XStream, Kryo, Hessian, SnakeYAML) carry the same risk when they choose classes from the input; follow their own hardening (FUNDAMENTALS-8).

## SERIAL-1: keep security-sensitive classes non-serializable

`Serializable` adds a public interface to every field and a hidden constructor. Watch for accidental serializability through a serializable superclass or interface, and for serializable lambdas (`(Runnable & Serializable) () -> …`).

## SERIAL-2: keep sensitive data out of the stream

Private fields are readable in the byte stream. Options: `transient`, a `serialPersistentFields` array, `writeObject` with `putFields`, `writeReplace` with a serial proxy, or `Externalizable`.

## SERIAL-3: readObject is a constructor

Deserialization skips constructors. `readObject` must repeat the constructor's validation and defensive copies, and assign safe defaults to fields the stream does not set. Read with `readFields()` so values are checked and copied before assignment. `GetField.get` always takes a default value.

<!-- compile: jdk=14 -->
```java
import java.io.*;

static final class ByteString implements Serializable {
    @Serial private static final long serialVersionUID = 1L;
    private byte[] data;

    ByteString(byte[] data) {
        this.data = data.clone();
    }

    @Serial
    private void readObject(ObjectInputStream in) throws IOException, ClassNotFoundException {
        ObjectInputStream.GetField fields = in.readFields();
        byte[] streamed = (byte[]) fields.get("data", null);
        if (streamed == null) {
            throw new InvalidObjectException("data is missing");
        }
        this.data = streamed.clone();
    }
}

static final class Nonnegative implements Serializable {
    @Serial private static final long serialVersionUID = 1L;
    private int value;

    Nonnegative(int value) {
        this.value = nonnegative(value);
    }

    private static int nonnegative(int value) {
        if (value < 0) {
            throw new IllegalArgumentException(value + " is negative");
        }
        return value;
    }

    @Serial
    private void readObject(ObjectInputStream in) throws IOException, ClassNotFoundException {
        ObjectInputStream.GetField fields = in.readFields();
        try {
            this.value = nonnegative(fields.get("value", 0));
        } catch (IllegalArgumentException e) {
            throw new InvalidObjectException(e.getMessage());
        }
    }
}
```

`@java.io.Serial` (14) marks serialization members; `javac -Xlint:serial` then reports misdeclared ones. Fields cannot be `final` when `readObject` assigns them; use a serial proxy (`writeReplace` + `readResolve`) when they must be.

Until deserialization completes, the object must be unusable (an `initialized` flag checked by public methods, or fields left `null`). Field types of security-sensitive serializable classes should be final classes, or `readObject` must check exact types.

## SERIAL-4: duplicate security checks

Checks done in constructors and setters go into `readObject`/`readObjectNoData`; checks guarding getters go into `writeObject`. Both must still call `defaultReadObject`/`readFields` and `defaultWriteObject`/`writeFields` once: the guide's versions skip them and lose data (errata.md).

<!-- compile: jdk=14 -->
```java
import java.io.*;

static void securityCheck() {
    // e.g. verify the caller's authorization
}

static final class SensitiveClass implements Serializable {
    @Serial private static final long serialVersionUID = 1L;
    private String owner;

    SensitiveClass(String owner) {
        securityCheck();
        this.owner = owner;
    }

    @Serial
    private void readObject(ObjectInputStream in) throws IOException, ClassNotFoundException {
        securityCheck();
        in.defaultReadObject();
    }
}

static final class SecureName implements Serializable {
    @Serial private static final long serialVersionUID = 1L;
    private static final String DEFAULT = "DEFAULT";
    private String name = DEFAULT;

    void setName(String name) {
        if (java.util.Objects.equals(name, this.name)) {
            return;
        }
        securityCheck();
        this.name = validate(name);
    }

    private static String validate(String name) {
        if (name == null || name.isEmpty()) {
            throw new IllegalArgumentException("name");
        }
        return name;
    }

    @Serial
    private void readObject(ObjectInputStream in) throws IOException, ClassNotFoundException {
        ObjectInputStream.GetField fields = in.readFields();
        String streamed = (String) fields.get("name", DEFAULT);
        if (!DEFAULT.equals(streamed)) {
            securityCheck();
            try {
                streamed = validate(streamed);
            } catch (IllegalArgumentException e) {
                throw new InvalidObjectException("invalid name");
            }
        }
        this.name = streamed;
    }
}

static final class SecureValue implements Serializable {
    @Serial private static final long serialVersionUID = 1L;
    private String value;

    String getValue() {
        securityCheck();
        return value;
    }

    @Serial
    private void writeObject(ObjectOutputStream out) throws IOException {
        securityCheck();
        out.defaultWriteObject();
    }
}
```

## Records serialize through their constructor

A serializable record (16) is deserialized by calling its canonical constructor, so the compact constructor's validation and copies run for stream data too. No `readObject` is needed, and none is used if declared.

<!-- compile: jdk=16 fails-below -->
```java
import java.io.Serializable;

record Range(int from, int to) implements Serializable {
    Range {
        if (from < 0 || from > to) {
            throw new IllegalArgumentException("bad range " + from + ".." + to);
        }
    }
}
```

## SERIAL-6: filter untrusted streams

Serialization filters (JEP 290: JDK 9, backported to 8u121) check each class, array length, graph depth, reference count and stream size before an object is created. Use an allow-list ending in `!*`:

<!-- compile: jdk=9 fails-below -->
```java
import java.io.*;

static final ObjectInputFilter MESSAGE_FILTER = ObjectInputFilter.Config.createFilter(
        "maxdepth=10;maxrefs=1000;maxarray=10000;maxbytes=65536;"
        + "com.example.messages.*;java.base/java.lang.String;java.base/java.lang.Number;!*");

static Object readMessage(InputStream in) throws IOException, ClassNotFoundException {
    try (ObjectInputStream ois = new ObjectInputStream(in)) {
        ois.setObjectInputFilter(MESSAGE_FILTER);
        return ois.readObject();
    }
}
```

Pattern syntax (`ObjectInputFilter.Config.createFilter`): patterns are separated by `;`, the first match decides, `pkg.*` matches one package, `pkg.**` includes subpackages, `module/` prefixes a module, `!` rejects. Whitespace counts as part of a pattern. For arrays the element type is matched. Undecided classes are allowed unless something rejects them, hence the final `!*`.

JVM-wide options:

| Option | From | Use |
|--------|------|-----|
| `-Djdk.serialFilter=<patterns>` or the `jdk.serialFilter` security property | 9 (8u121) | Filter for every stream without its own filter. Setting it with `System.setProperty` at runtime has no effect |
| `-Djdk.serialFilterFactory=<class>`, `ObjectInputFilter.Config.setSerialFilterFactory` | 17 (JEP 415) | Choose a filter per stream or per context |
| `ObjectInputFilter.allowFilter`, `rejectFilter`, `merge`, `rejectUndecidedClass` | 17 | Combine filters in code |

Allow-lists beat reject-lists: a rejected class's subclasses are still accepted, and gadget lists are never complete. RMI applies built-in filters to the registry and DGC; exported objects need their own (`sun.rmi.registry.registryFilter` and per-object filters).

## Review checklist

- `ObjectInputStream`, `XMLDecoder`, or a third-party polymorphic deserializer reads data from outside the process: finding, unless a strict allow-list filter is set.
- Every serializable class with constructor validation has a `readObject` that repeats it (or is a record).
- `readObject`/`writeObject` call `defaultReadObject`/`readFields` and `defaultWriteObject`/`writeFields` exactly once and declare `throws IOException, ClassNotFoundException` / `IOException`.
- Sensitive fields are `transient` or excluded with `serialPersistentFields`.
- Mutable fields are copied in `readObject`.
