---
name: java-secure-coding
description: Reviews and writes Java code against the Oracle Secure Coding Guidelines for Java SE (document 11.0), with compile-checked fixes and an errata of the guide's own broken snippets. Covers denial of service and resource limits, confidential data in exceptions and logs, SQL, command and XML injection (XXE), mutability and defensive copies, sealed and final types, object construction, Java serialization and deserialization filters, input validation, path traversal and zip slip, JNI, and the Security Manager rules that stop applying on JDK 24.
when_to_use: User asks for a security review or audit of Java code, asks whether Java code is secure or how to make it secure, asks about a specific risk in Java (deserialization, readObject, XXE or XML parser configuration, SQL injection, path traversal, zip bombs, defensive copying, sealed or final classes for security, JNI or loadLibrary, doPrivileged, InvocationHandler), cites a guideline id such as SERIAL-3 or INJECT-5, or asks about the Oracle secure coding guidelines or a snippet copied from them.
argument-hint: "[review|write|explain] [path|guideline-id]"
---

# Java secure coding

Source: Oracle "Secure Coding Guidelines for Java SE", version 11.0 (June 2025). Guideline ids (`SERIAL-3`, guideline 8-3) follow the guide. Several of its snippets do not compile or misbehave. **Never reproduce a snippet from the guide; use the corrected code in the references, and check [errata.md](references/errata.md) when a user quotes one.**

## Gate

1. Release `R` = `java_release` from `bash ${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/scripts/detect.sh <root>`, or ask when there is no build. Fixes must compile on `R`; each snippet's marker states its minimum JDK, and `${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/references/jdk-matrix.md` has the rest.
2. `R ≥ 24`: Security Manager guidelines (ACCESS-1 to 7, 16 to 20) protect nothing; report Security Manager code as dead or broken and route its removal to java-migrate. Below 24, apply them only if a Security Manager is installed.

## Modes

- **explain** (a question, no code to change): answer from the topic reference and errata. Do not run scripts or edit files.
- **write**: apply the relevant references while writing the code; mention the guideline ids the code relies on.
- **review**: read-only unless the user asks for fixes. Procedure below.

## Review procedure

1. Map trust boundaries first (FUNDAMENTALS-4): network handlers, file and archive input, message consumers, deserialization, native calls, plugin or script loading. Review code reachable from them before the rest.
2. Find candidate sites with the plugin scanner. It reports only security signals, ignores comment lines, and `--to <R>` hides signals that need a newer release:

   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/scripts/scan.sh <root> --security --to <R> --summary
   bash ${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/scripts/scan.sh <root> --security --to <R> | awk -F'\t' '$1 == "<signal-id>"'
   ```

   Each row carries the guideline id and the reference to load in its note. Signals are candidates, not findings: read the site and its data flow. Known gaps: `xml-factory` lists hardened and default factories alike, the scan sees one line at a time, and it includes test sources (skip them by path). It cannot see path handling from request input, `clone()` on subclassable inputs, `double` parsing at boundaries, or serializable classes that lack a `readObject`. Cover those by reading the code behind the trust boundaries from step 1.

3. Load only the references the hits need (table below) and judge each site against its rules and checklist.
4. Report findings ordered by severity. For each: `path:line`, guideline id, what an attacker controls and gains, and the fix as code that compiles on `R`. Separate confirmed findings from "needs context" items. Report no finding without a reachable source of untrusted data, except dangerous defaults (trust-all TLS, unfiltered deserialization, unhardened XML parsing of external files).
5. When fixing: one guideline per change set, then build and run tests. Do not weaken tests.

## References

| Topic | Guidelines | Reference |
|-------|------------|-----------|
| Resource exhaustion, zip bombs, try-with-resources, overflow-safe limits, exception policy, hash keys | DOS-1 to 5 | [dos-resources.md](references/dos-resources.md) |
| Exceptions and logs, secrets in memory, SQL, HTML/XML output, command lines, XXE and parser hardening, Swing HTML, JNDI and scripts, NaN/infinity | CONFIDENTIAL-1 to 3, INJECT-1 to 9 | [injection.md](references/injection.md) |
| Accessibility, modules, final and sealed, immutable values, records, defensive copies, identity keys, static state, constructors, finalizers | EXTEND-1 to 6, MUTABLE-1 to 12, OBJECT-1 to 5 | [mutability.md](references/mutability.md) |
| readObject/writeObject, sensitive fields, records, serialization filters | SERIAL-1 to 6 | [serialization.md](references/serialization.md) |
| Validation, paths, zip slip, parser discrepancies, native wrappers, loadLibrary, native access | INPUT-1 to 4, JNI-1 to 10 | [input-validation-native.md](references/input-validation-native.md) |
| doPrivileged, caller-sensitive APIs, invocation handlers, global setters | ACCESS-1 to 20 | [access-control-legacy.md](references/access-control-legacy.md) |
| Defects in the guide's snippets and facts | all | [errata.md](references/errata.md) |

## Fundamentals (FUNDAMENTALS-0 to 8)

- Write code that is obviously safe; avoid clever logic (0) and duplicated checks or data (2).
- Design APIs so misuse is hard: final classes, narrow interfaces, private fields (1, 6).
- Run with least privilege: separate processes, containers and OS permissions replace the Security Manager (3).
- Validate data where it crosses a trust boundary (4); check once at a few defined points and pass a capability object onward (5).
- Document security-relevant behavior: required permissions, thrown exceptions, caller sensitivity (7).
- Keep third-party code updated and configured securely; vulnerability scanners (OWASP Dependency-Check, Dependabot) and Gradle dependency verification belong in the build (8).
