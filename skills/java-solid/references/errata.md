# Errata: "SOLID Java" blog post

Defects in the code and claims of the source post (<https://blog.filippobuletto.info/solid-java/>, updated 2019-02-16). Never copy a snippet from the post without checking this table. The corrected code lives in the principle references, compiled by `tests/compile-snippets.sh`.

Contents: compile errors · runtime and semantic errors · wrong labels and claims · how this was checked.

## Compile errors

| Principle | Snippet | Defect | javac says | Fix (reference) |
|-----------|---------|--------|------------|-----------------|
| SRP | GOOD `UserSettingService` | `securityService` is never declared or injected | `cannot find symbol` | Inject an `AccessPolicy` through the constructor (srp.md) |
| OCP | GOOD `ConsoleLog.log()`, `FileLog.log()` | Package-private methods cannot implement a public interface method | `log() in ConsoleLog cannot implement log() in Log` … `attempting to assign weaker access privileges; was public` | `public void write(String message)` (ocp.md) |
| LSP | BAD `public boolean function add(Object object)` | `function` is not a Java keyword | `';' expected`, `invalid method declaration; return type required` | Drop `function`; the runtime table shows what the fixed code then does |
| LSP | GOOD `DataHashSet implements Set` | Implements 2 of the 13 abstract `Set` methods; raw types | `DataHashSet is not abstract and does not override abstract method clear() in Set` | Extend `AbstractSet<E>` and delegate (lsp.md) |
| ISP | `Driver`, `Mechanic` | Constructors drop `car`; `this.car` is never declared | `cannot find symbol` | Store the narrow interface in a `final` field (isp.md) |
| DIP | GOOD `MySqlConnector implements Connector {}` and the three other implementations | Empty bodies do not implement `open()` / `find(String)` | `MySqlConnector is not abstract and does not override abstract method open() in Connector` | dip.md |
| DIP | GOOD `Database` constructor | `connector` and `finder` fields are never declared | `cannot find symbol` | dip.md |

## Runtime and semantic errors

| Principle | Snippet | Defect | Observed | Fix (reference) |
|-----------|---------|--------|----------|-----------------|
| LSP | BAD `DataHashSet extends HashSet`, with `function` removed | `HashSet.addAll` calls the overridden `add`, so every element is counted twice. The comment says so, yet the bug is self-use inside the superclass (fragile base class, Effective Java 3rd ed. Item 18), not a substitution failure: a client holding a `Set` sees correct set behavior | `addAll(List.of("x","y","z"))` → `addCount=6 size=3` | Composition over `AbstractSet` (lsp.md) |
| SRP | GOOD `SecurityService.checkAccess` | Declared `static` but called through an instance. A static call cannot be replaced or mocked, which contradicts the post's own benefit "can be now tested separately" | compiles once declared; no test seam | Instance method on an injected interface (srp.md) |
| OCP | GOOD `Log.log()` | Takes no message, so no logger built on it can log anything | — | `LogSink.write(String)` (ocp.md) |

## Wrong labels and claims

| Section | Post says | Right |
|---------|-----------|-------|
| SRP | "Class implementing feature 1 AND feature 2 … violates SRP" | The test is who asks for changes, not how many features. Martin (2014): changes "can only originate from a single person, or rather, a single tightly coupled group of people". Two features owned by one group can share a class |
| OCP | Smell: class X referencing class Y directly means Y should be injected | That is a DIP smell (dip.md). OCP smells are type-code branching and edits to a class for every new variant |
| LSP | "This is an extension of open/close principle" | LSP stands on its own (Liskov 1987; Liskov and Wing 1994). OCP through subtyping depends on it |
| LSP | Example and "Delegation Over Subtyping" | The example shows the fragile base class problem. See the runtime table; lsp.md has a substitution example (`equals` symmetry) |
| DIP | BAD reads `System.getProperty("MSSQLConnection")`; GOOD names `MySqlConnector` | Two different databases; the example changes vendor while claiming only to change structure |
| DIP | GOOD `Connector` / `Finder` | Abstractions mirror the low-level operations and live beside them, and `Database` forwards calls without adding policy. In DIP the high-level module owns the abstraction and names it after its own needs (dip.md) |
| DIP | "dependency injection1" | `1` is the footnote marker for JSR-330 `@Inject`. DIP needs no framework: constructor injection is enough |

## How this was checked

Each snippet was compiled verbatim with javac 21.0.13 and 25.0.5 (identical results). Only names the post leaves undefined were stubbed (`User`, `Status`, `Speed`, `Gas`, `Engine`, `Connection`), plus a `return true;` in the comment-only body of `SecurityService.checkAccess`. Public classes were compiled from files named after them. The LSP runtime result comes from the BAD snippet with `function` removed, run on JDK 21 and 25.
