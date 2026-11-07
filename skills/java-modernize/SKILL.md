---
name: java-modernize
description: Adopts newer Java language features and APIs in existing code, gated by the project's JDK release. Converts value classes to records, instanceof chains and old switches to pattern matching and switch expressions, concatenated multi-line strings to text blocks, thread pools for blocking I/O to virtual threads, ThreadLocal to ScopedValue, and legacy collection, string, stream and date idioms to current APIs, with explicit rules for when not to convert.
when_to_use: User asks to modernize Java code, use records/sealed types/pattern matching/text blocks/virtual threads/scoped values, clean up code after a JDK upgrade, asks which newer Java features fit their code, or asks whether a language feature or API can be used on a given Java release or library target (for example "can we use records while targeting 11", "is ScopedValue still preview"). Also called by the java-upgrade router after the last hop is green when the user opted into modernization.
argument-hint: "[feature|all] [path]"
---

# Modernize Java code

Optional work. Never part of a hop's must-fix steps, never applied without the user opting in.

**Questions without a code change** ("can we use X on release N"): answer from the Gate rules and `jdk-matrix.md` (final-in JDK per feature) only. Name what is available at that release instead. Do not run scripts or edit files.

## Gate

1. Release `R` = `java_release` from `bash ${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/scripts/detect.sh <root>` (after an upgrade: the new release). A feature is allowed only if its "final in" JDK ≤ R, from `${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/references/jdk-matrix.md`.
2. Libraries that publish for consumers on older JDKs: gate on the lowest JDK they support, not the build JDK.
3. Preview features: excluded unless the user explicitly asks; then follow [preview-features.md](references/preview-features.md).

## Find candidates

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/scripts/scan.sh <root> --to <R> --summary | awk -F'\t' '$2 == "modernize"'
```

Signals are candidates. Read each site and apply the "do not convert when" rules of its reference before editing.

## Feature picker

| Signal / request | Min JDK | Reference |
|------------------|---------|-----------|
| `instanceof-cast`, `old-switch`, type or record patterns, `_` | 14–22 | [patterns-switch.md](references/patterns-switch.md) |
| `data-class`, closed hierarchies, sealed types | 16–17 | [records-sealed.md](references/records-sealed.md) |
| `multiline-concat`, `blank-check`, `read-all-bytes`, string formatting | 11–15 | [text-and-strings.md](references/text-and-strings.md) |
| `collect-tolist`, `unmodifiable-wrap`, `last-element`, gatherers | 9–24 | [collections-streams.md](references/collections-streams.md) |
| `fixed-pool`, `thread-local`, structured fan-out | 21–25 | [concurrency.md](references/concurrency.md) |
| `var`, `http-url-connection`, `legacy-date`, Markdown Javadoc, module imports, flexible constructors, compact source files | 8–25 | [language-misc.md](references/language-misc.md) |
| Anything marked preview in jdk-matrix.md | exact JDK | [preview-features.md](references/preview-features.md) |

## Procedure

1. Agree the feature list and paths with the user (or take them from plan.md).
2. One feature per change set, small batches (one package or ~20 sites). Behavior must not change; public API changes (a class becoming a record changes `getX()` to `x()`) need explicit user approval.
3. Build and run tests after each batch on the project JDK.
4. Do not reformat unrelated code or mix in other refactorings.
5. Report per feature: sites converted, sites skipped and why.
