---
name: java-solid
description: Explains, applies and reviews the SOLID design principles in Java (single responsibility, open/closed, Liskov substitution, interface segregation, dependency inversion), with compile-checked examples gated by the project's JDK release and rules for when not to apply each principle. Covers sealed types and exhaustive switch as the closed-set form of open/closed, records and final classes against substitution bugs, equals symmetry, composition over inheritance, client-owned interfaces, InstantSource, and constructor injection without a framework.
when_to_use: User asks about SOLID or one of its principles in Java, asks for a design or code review of Java classes for coupling, cohesion, god classes, fat interfaces, inheritance misuse or testability, asks how to refactor a Java class to follow a principle, or asks whether an abstraction or interface is worth adding.
argument-hint: "[review|write|explain] [path|principle]"
---

# SOLID in Java

SOLID principles are heuristics for keeping change cheap. Evidence of change cost decides, not pattern matching: who asks for edits, which edits repeat, which tests are hard to write. An abstraction without a second implementation, a boundary or a test seam is cost without benefit.

## Gate

Release `R` = `java_release` from `bash ${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/scripts/detect.sh <root>`, or ask when there is no build. Code must compile on `R`; each snippet's marker states its minimum JDK. Below 16 write records as final classes; below 17 there is no `sealed`; below 21 no pattern `switch`. Adopting those features for their own sake is java-modernize's job.

## Modes

- **explain** (a question, no code to change): answer from the principle reference. Do not run scripts or edit files.
- **write**: apply the relevant references while writing; name the principle only where a design choice relies on it.
- **review**: read-only unless the user asks for fixes. Procedure below.

## Review procedure

1. Find hotspots first. Files that change with many unrelated commits are where SRP and OCP problems cost money:

   ```bash
   git -C <root> log --since=1.year --format= --name-only -- '*.java' | sort | uniq -c | sort -rn | head -20
   ```

2. Find candidate sites with the Grep tool (type `java`, line numbers on; skip hits under test directories). Hits are candidates, not findings; read each site:

   ```text
   # SRP: catch-all classes
   class \w*(Manager|Helper|Utils?|Processor)\b
   # OCP: type-code branching
   \binstanceof\s+\w+|switch\s*\(\s*\w*([Tt]ype|[Kk]ind)\w*
   # LSP, ISP: refused methods (show 3 lines of context before each hit)
   throw new UnsupportedOperationException
   # DIP: policy code creating or calling details
   new \w*(Repository|Dao|Client|Template|Connection)\w*\(|\.getInstance\(\)|System\.(getProperty|getenv)\(|\b(Instant|LocalDate|LocalDateTime|ZonedDateTime)\.now\(\)
   ```

   The patterns use ripgrep syntax (`\w`, `\b`, `\s`), which the Grep tool takes as is. From a shell, run them with `rg -n --type java -g '!**/test/**' '<pattern>' <root>`; plain `grep -E` does not support that syntax.

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

## Related skills

- java-modernize converts value classes to records and type switches to pattern matching.
- java-secure-coding EXTEND-5 and MUTABLE-1 want `final` classes and immutable values for the same reasons LSP does.
