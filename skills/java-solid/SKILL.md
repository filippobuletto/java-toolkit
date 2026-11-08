---
name: java-solid
description: Explains, applies and reviews the SOLID design principles in Java (single responsibility, open/closed, Liskov substitution, interface segregation, dependency inversion), with compile-checked examples gated by the project's JDK release, rules for when not to apply each principle, and an errata of the broken snippets in the "SOLID Java" blog post. Covers sealed types and exhaustive switch as the closed-set form of open/closed, records and final classes against substitution bugs, equals symmetry, composition over inheritance, client-owned interfaces, InstantSource, and constructor injection without a framework.
when_to_use: User asks about SOLID or one of its principles in Java, asks for a design or code review of Java classes for coupling, cohesion, god classes, fat interfaces, inheritance misuse or testability, asks how to refactor a Java class to follow a principle, asks whether an abstraction or interface is worth adding, or quotes a snippet from the "SOLID Java" post at blog.filippobuletto.info.
argument-hint: "[review|write|explain] [path|principle]"
---

# SOLID in Java

Source: "SOLID Java" (<https://blog.filippobuletto.info/solid-java/>, 2019), extended with Martin's definitions and current Java. Every snippet in the post has a defect. **Never reproduce a snippet from the post; use the corrected code in the references, and check [errata.md](references/errata.md) when a user quotes one.**

SOLID principles are heuristics for keeping change cheap. Evidence of change cost decides, not pattern matching: who asks for edits, which edits repeat, which tests are hard to write. An abstraction without a second implementation, a boundary or a test seam is cost without benefit.

## Gate

Release `R` = `java_release` from `bash ${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/scripts/detect.sh <root>`, or ask when there is no build. Code must compile on `R`; each snippet's marker states its minimum JDK. Below 16 write records as final classes; below 17 there is no `sealed`; below 21 no pattern `switch`. Adopting those features for their own sake is java-modernize's job.

## Modes

- **explain** (a question, no code to change): answer from the principle reference and errata. Do not run scripts or edit files.
- **write**: apply the relevant references while writing; name the principle only where a design choice relies on it.
- **review**: read-only unless the user asks for fixes. Procedure below.

## Review procedure

1. Find hotspots first. Files that change with many unrelated commits are where SRP and OCP problems cost money:

   ```bash
   git -C <root> log --since=1.year --format= --name-only -- '*.java' | sort | uniq -c | sort -rn | head -20
   ```

2. Find candidate sites. Hits are candidates, not findings; read each site:

   ```bash
   # SRP: catch-all classes
   rg -n --type java -g '!**/test/**' 'class \w*(Manager|Helper|Utils?|Processor)\b' <root>
   # OCP: type-code branching
   rg -n --type java -g '!**/test/**' -e '\binstanceof\s+\w+' -e 'switch\s*\(\s*\w*(type|kind)\w*' <root>
   # LSP, ISP: refused methods
   rg -n --type java -g '!**/test/**' -B3 'throw new UnsupportedOperationException' <root>
   # DIP: policy code creating or calling details
   rg -n --type java -g '!**/test/**' -e 'new \w*(Repository|Dao|Client|Template|Connection)\w*\(' -e '\.getInstance\(\)' -e 'System\.(getProperty|getenv)\(' -e '\b(Instant|LocalDate|LocalDateTime|ZonedDateTime)\.now\(\)' <root>
   ```

   Not visible to search: constructors with many collaborators, `equals` overridden in subclasses, interfaces whose clients use disjoint methods, import direction between packages (`jdeps -verbose:package`). Read the hotspot classes for those.

3. Load only the references the candidates need and judge each against its smells and "when not to" rules.
4. Report findings ordered by change cost. For each: `path:line`, principle, the evidence (who changes it, which edit repeats, which client breaks, which test is hard), and the fix as code that compiles on `R`. Report "leave as is" when the fix costs more than it saves.
5. When fixing: one principle per change set; behavior and public API unchanged unless the user approves; build and run tests after each step. Do not weaken tests.

## References

| Principle | Read when | Reference |
|-----------|-----------|-----------|
| Single responsibility | Classes owned by several groups, god classes, large test setup | [srp.md](references/srp.md) |
| Open/closed | Type-code branching, edits for every new variant, sealed versus interface | [ocp.md](references/ocp.md) |
| Liskov substitution | Subclass overrides, `equals` in hierarchies, refused methods, extending concrete classes | [lsp.md](references/lsp.md) |
| Interface segregation | Fat interfaces, mocks that stub a fraction of an interface, `Clock` versus `InstantSource` | [isp.md](references/isp.md) |
| Dependency inversion | Policy code creating infrastructure, static singletons, `now()` and `getenv` in domain code | [dip.md](references/dip.md) |
| Defects in the source post | Any snippet quoted from the post | [errata.md](references/errata.md) |

## Related skills

- java-modernize converts value classes to records and type switches to pattern matching.
- java-secure-coding EXTEND-5 and MUTABLE-1 want `final` classes and immutable values for the same reasons LSP does.
