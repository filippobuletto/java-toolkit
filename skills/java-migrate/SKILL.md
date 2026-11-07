---
name: java-migrate
description: Fixes the code and runtime changes a JDK upgrade forces, one hop at a time (8→11, 11→17, 17→21, 21→25, 25→27). Covers removed Java EE and CORBA modules, Nashorn, JDK internal APIs and strong encapsulation, Security Manager, finalization, sun.misc.Unsafe, JNI restrictions, removed preview APIs, final-field mutation warnings and obsolete JVM flags, with the replacement for each.
when_to_use: Called by the java-upgrade router for the breaking-change steps of a hop, or when the user asks why code fails to compile or run on a newer JDK (for example "package javax.xml.bind does not exist", InaccessibleObjectException, "Nashorn engine not found", "Unrecognized VM option", Security Manager errors, Unsafe or JNI warnings), asks what changed between two Java versions, or asks whether an API, JVM flag or preview feature still exists or behaves the same on a given JDK (for example "does Thread.stop still work on 27", "is -XX:+ZGenerational still valid", "what happens to StableValue on 26").
argument-hint: "<hop: 8-to-11|11-to-17|17-to-21|21-to-25|25-to-27> [signal-ids]"
---

# Breaking changes per hop

Scope: application code, test code, and JVM flags in scripts/config. Build-file changes belong to java-build; optional idiom changes belong to java-modernize.

**Questions without a project task** ("what changes for X on JDK N"): skip the procedure. Look the item up in `${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/references/jdk-matrix.md`, load the hop reference for the releases involved, and answer from them with JEP number, JDK, and the fix. Do not run scripts or edit files.

Inputs: the hop, and the signal ids or files from `.java-upgrade/assessment.md`. If called without an assessment, run:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/scripts/scan.sh <root> --from <a> --to <b>
```

## Procedure

1. Load only the hop reference below. A multi-release jump loads each hop file in order.
2. For each signal id in the assessment: open the hits, confirm they are real, apply the fix from the reference. Group edits by signal id so each change is reviewable.
3. Build and test on the hop's JDK after each signal group. Behavior signals (charset, reflection, agents, GC selection) need a test run, not just a compile.
4. Signals with no code fix inside scope (needs a framework upgrade, or no replacement exists such as CORBA) go to the plan's prerequisites; do not hack around them.
5. Re-run `scan.sh --from <a> --to <b>`: no `flag` hits may remain. A `removed` hit fixed by adding a dependency still matches (the regex sees the import, not the pom); it is resolved when build and a call through that code pass on the hop JDK. Explain each remaining hit in progress.md.

## Rules

- Prefer the JDK replacement over adding a dependency; add a dependency only when the API has no JDK equivalent (JAXB, JAX-WS, Nashorn standalone).
- Escape-hatch flags (`--add-opens`, `--enable-native-access`, `--sun-misc-unsafe-memory-access=allow`, `--enable-final-field-mutation`, `-XX:+EnableDynamicAgentLoading`) are temporary: name the owning code or library and the follow-up in progress.md.
- Keep JDK-owned `javax.*` packages untouched (list in the router's hard rules).
- Facts and versions: `${CLAUDE_PLUGIN_ROOT}/skills/java-upgrade/references/jdk-matrix.md`.

## Hop references

| Hop | File | Main topics |
|-----|------|-------------|
| 8 → 11 | [8-to-11.md](references/8-to-11.md) | Java EE/CORBA removal (JEP 320), JavaFX, internal APIs, version string, `rt.jar`/`tools.jar`, unified GC logging |
| 11 → 17 | [11-to-17.md](references/11-to-17.md) | Strong encapsulation (JEP 396/403), Nashorn, Pack200, CMS, RMI activation, wrapper constructors, Security Manager deprecation |
| 17 → 21 | [17-to-21.md](references/17-to-21.md) | UTF-8 default (JEP 400), finalization (421), `Thread.stop`, dynamic agents (451), sequenced collection clashes (431), biased locking |
| 21 → 25 | [21-to-25.md](references/21-to-25.md) | Security Manager disabled (486), Unsafe memory access (471/498), JNI (472), annotation processing, String Templates removal, structured concurrency rewrite, ZGC flag, 32-bit |
| 25 → 27 | [25-to-27.md](references/25-to-27.md) | Final field mutation (500), Applet removal (504), G1 everywhere (523), compact headers (534), hybrid PQ TLS (527) |
