# Confidential data and injection (CONFIDENTIAL-1 to 3, INJECT-1 to 9)

Contents: exceptions and logs · sensitive data in memory · output formats · SQL · HTML and XML output · command lines · XML parsing (XXE) · BMP and Swing · untrusted code and JNDI · floating-point values · review checklist.

## CONFIDENTIAL-1: purge exceptions at the trust boundary

Exception messages and types leak file paths, user names, existence of files and internal configuration. At a boundary, log the detail internally and throw a message you wrote yourself. Never put stack traces in responses, not even in HTML comments.

<!-- compile: jdk=8 -->
```java
import java.io.*;
import java.nio.file.*;
import java.util.Properties;
import java.util.logging.*;

static final Logger LOG = Logger.getLogger("config");

static Properties loadConfig(Path path) {
    try (InputStream in = Files.newInputStream(path)) {
        Properties p = new Properties();
        p.load(in);
        return p;
    } catch (IOException e) {
        LOG.log(Level.WARNING, "configuration load failed", e);
        throw new IllegalStateException("configuration unavailable");
    }
}
```

Build boundary messages from known fields. Filtering an exception's message by removing parts breaks when a library adds new detail later.

## CONFIDENTIAL-2 and 3: logs and memory

- Never log passwords, tokens, keys, national IDs, full card numbers. Watch generic layers (HTTP clients, SQL loggers, parsers in debug mode) that log whole payloads.
- `toString()` of records and Lombok `@Data` classes prints every field. Override it for types holding secrets.
- Keep secrets in `char[]`/`byte[]` and clear them with `Arrays.fill` after use (`Console.readPassword` returns `char[]`). The GC may already have copied them, so this narrows the window, it does not close it. Avoid needless copies (`new String(password)`).

## INJECT-1: generate valid formats with libraries

Parse and canonicalize first, then validate. Reject invalid input; do not repair it. Build XML, JSON, CSV and URLs with libraries, not string concatenation.

## INJECT-2: SQL

Use `PreparedStatement` with `?` parameters for every value:

<!-- compile: jdk=8 -->
```java
import java.sql.*;
import java.util.Optional;

static Optional<String> findEmail(Connection con, String userId) throws SQLException {
    String sql = "SELECT email FROM users WHERE user_id = ?";
    try (PreparedStatement stmt = con.prepareStatement(sql)) {
        stmt.setString(1, userId);
        try (ResultSet rs = stmt.executeQuery()) {
            return rs.next() ? Optional.of(rs.getString(1)) : Optional.empty();
        }
    }
}
```

Parameters cannot carry identifiers. Map table names, column names and sort direction through an allow-list:

<!-- compile: jdk=9 -->
```java
import java.util.Map;

static final Map<String, String> SORT_COLUMNS = Map.of("name", "last_name", "created", "created_at");

static String orderBy(String requested) {
    String column = SORT_COLUMNS.get(requested);
    if (column == null) {
        throw new IllegalArgumentException("unsupported sort key");
    }
    return " ORDER BY " + column;
}
```

The same applies to JPQL/HQL, JDBC `CallableStatement` calls and native queries in ORMs: bind values, never concatenate them.

## INJECT-3: HTML and XML output

Encode for the exact context (HTML body, attribute, JavaScript, URL, CSS) at output time, with a maintained encoder (the template engine's auto-escaping, OWASP Java Encoder). Allow-list what is known safe rather than block-listing dangerous characters. Turning off auto-escaping in a template is a finding.

## INJECT-4: no untrusted data on command lines

Untrusted text can become an option (`-x`, `/x`) or split into several arguments. Never run a shell (`sh -c`, `cmd /c`) with untrusted text. Pass arguments as a list and end options with `--` where the program supports it:

<!-- compile: jdk=8 -->
```java
import java.io.IOException;
import java.nio.file.Path;

static Process searchFile(String literal, Path file) throws IOException {
    return new ProcessBuilder("grep", "-F", "--", literal, file.toString())
            .redirectErrorStream(true)
            .start();
}
```

On Windows the target program re-parses one command line, so list arguments are not a complete defense there. Prefer passing data through stdin or a temporary file.

## INJECT-5: XML parsing (XXE, SSRF, entity expansion)

DTDs let a document pull local files and URLs (XXE, SSRF) and expand entities without bound. XInclude and XSLT `document()`, `import` and `include` do the same. `FEATURE_SECURE_PROCESSING` (FSP) is on by default and limits entity expansion, but the JDK default does **not** restrict external access. Configure every factory explicitly.

DOM and SAX, when the input has no reason to carry a DTD:

<!-- compile: jdk=8 -->
```java
import javax.xml.XMLConstants;
import javax.xml.parsers.*;

static DocumentBuilder secureDocumentBuilder() throws ParserConfigurationException {
    DocumentBuilderFactory f = DocumentBuilderFactory.newInstance();
    f.setNamespaceAware(true);
    f.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
    f.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
    f.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
    f.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
    f.setXIncludeAware(false);
    f.setExpandEntityReferences(false);
    return f.newDocumentBuilder();
}

static SAXParser secureSaxParser() throws Exception {
    SAXParserFactory f = SAXParserFactory.newInstance();
    f.setNamespaceAware(true);
    f.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
    f.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
    return f.newSAXParser();
}
```

StAX, transformers, schema validation and XPath:

<!-- compile: jdk=8 -->
```java
import javax.xml.XMLConstants;
import javax.xml.stream.XMLInputFactory;
import javax.xml.transform.TransformerFactory;
import javax.xml.validation.SchemaFactory;
import javax.xml.xpath.XPathFactory;

static XMLInputFactory secureStax() {
    XMLInputFactory f = XMLInputFactory.newInstance();
    f.setProperty(XMLInputFactory.SUPPORT_DTD, false);
    f.setProperty(XMLInputFactory.IS_SUPPORTING_EXTERNAL_ENTITIES, false);
    return f;
}

static TransformerFactory secureTransformerFactory() throws Exception {
    TransformerFactory f = TransformerFactory.newInstance();
    f.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
    f.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
    f.setAttribute(XMLConstants.ACCESS_EXTERNAL_STYLESHEET, "");
    return f;
}

static SchemaFactory secureSchemaFactory() throws Exception {
    SchemaFactory f = SchemaFactory.newInstance(XMLConstants.W3C_XML_SCHEMA_NS_URI);
    f.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
    f.setProperty(XMLConstants.ACCESS_EXTERNAL_DTD, "");
    f.setProperty(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
    return f;
}

static XPathFactory secureXPathFactory() throws Exception {
    XPathFactory f = XPathFactory.newInstance();
    f.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
    return f;
}
```

FSP on `TransformerFactory` and `XPathFactory` also turns off extension functions, which otherwise let a stylesheet call Java code (INJECT-8).

JVM-wide settings, all without code changes:

| Setting | From | Effect |
|---------|------|--------|
| `-Djdk.xml.dtd.support=deny` (or `ignore`) | 22 | Rejects (or skips) DTDs in every JDK parser. Has no effect on a factory where `disallow-doctype-decl` or `SUPPORT_DTD` is set explicitly |
| `-Djava.xml.config.file=<copy of conf/jaxp-strict.properties.template>` | 23 (template) | Strict limits and external-access settings for all processors |
| `-Djdk.xml.entityExpansionLimit=2000` and the other `jdk.xml.*` limits | 8 | Tighter processing limits |

These `jdk.xml.*` properties and the `XMLConstants.ACCESS_EXTERNAL_*` attributes apply to the JDK's built-in parser. A third-party parser on the class path (Apache Xerces, Saxon, Woodstox) may be picked up by `newInstance()` and ignore them. Configure that library with its own features, or use `newDefaultInstance()` (9) to force the JDK implementation.

Indirect XML parsers count too (INJECT-5 note): SOAP stacks, `java.beans.XMLDecoder`, `java.util.prefs`, office-document and SVG libraries, configuration loaders.

## INJECT-6 and 7: BMP files and Swing HTML

- BMP images can reference local ICC profile files; avoid them for untrusted input or decode in a separate low-privilege process.
- Swing components render text starting with `<html>` as HTML. For untrusted text, set `component.putClientProperty("html.disable", Boolean.TRUE)` on each component.

## INJECT-8: untrusted code paths

These APIs run code or load classes from data. Treat any untrusted input reaching them as code execution:

- `javax.script` engines (Nashorn left the JDK in 15; GraalJS, Rhino and Groovy engines come from libraries).
- XSLT and XPath extension functions (off with FSP, see above).
- `java.beans.XMLDecoder` (JavaBeans long-term persistence): the XML can instantiate any class and call any method. Never decode untrusted XML with it.
- `javax.sound.midi.MidiSystem.getSoundbank`.
- RMI remote class loading: `java.rmi.server.useCodebaseOnly` must stay `true` (default since 7u21).
- JNDI lookups with untrusted names (the Log4Shell pattern). Keep `com.sun.jndi.ldap.object.trustURLCodebase` and `com.sun.jndi.ldap.object.trustSerialData` at their default `false`, set `jdk.jndi.object.factoriesFilter`, `jdk.jndi.ldap.object.factoriesFilter` and `jdk.jndi.rmi.object.factoriesFilter` to allow-lists, and apply a deserialization filter (serialization.md).
- Annotation processors: from JDK 23 javac runs none unless configured; before 23 it ran any processor found on the class path (errata.md). Configure processors explicitly in the build (java-build skill).
- SQL features that run code outside the database (`xp_cmdshell`, `COPY … PROGRAM`, UDF loading).

## INJECT-9: NaN and infinity from untrusted numbers

`Double.parseDouble("NaN")` and `"Infinity"` parse fine, propagate through arithmetic and break comparisons (`NaN != NaN`, so `equals`-by-`==` lookups fail). Casts hide them:

| Cast | NaN | +Infinity | -Infinity |
|------|-----|-----------|-----------|
| `(int)` | 0 | `Integer.MAX_VALUE` | `Integer.MIN_VALUE` |
| `(long)` | 0 | `Long.MAX_VALUE` | `Long.MIN_VALUE` |
| `(short)`, `(byte)` | 0 | -1 | 0 |

Reject non-finite values at the boundary, especially before authorization decisions, allocation sizes and JNI calls:

<!-- compile: jdk=8 -->
```java
static double parseAmount(String untrusted) {
    double value = Double.parseDouble(untrusted);
    if (!Double.isFinite(value)) {
        throw new IllegalArgumentException("amount must be a finite number");
    }
    return value;
}
```

Check `AffineTransform` and other 2D results the same way before using them for sizes.

## Review checklist

- No `Statement.execute*`/`createQuery` with concatenated input; identifiers go through allow-lists.
- Every XML factory that sees untrusted input is configured as above, including inside libraries.
- No `Runtime.exec(String)` or `sh -c` with input; `ProcessBuilder` gets a list.
- No `XMLDecoder`, `ScriptEngine.eval` or `InitialContext.lookup` on untrusted data.
- Boundary exceptions carry messages you wrote; logs carry no secrets.
- Parsed `double`/`float` values are checked with `Double.isFinite`.
