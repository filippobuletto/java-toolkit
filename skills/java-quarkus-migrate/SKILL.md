---
name: java-quarkus-migrate
description: Runs one Quarkus upgrade hop between LTS streams (2.13/2.16 → 3.2 → 3.8 → 3.15 → 3.20 → 3.27 → 3.33 → 3.40, and 3.40 → 4.0 beta on opt-in). Drives quarkus update (OpenRewrite recipes) pinned to the hop's stream, reviews the diff, then applies the manual items from the migration guides that the recipes do not cover — javax to jakarta, Hibernate ORM 6 and 7, Quarkus REST rename, config renames, behavior changes — and verifies the build on the hop's JDK.
when_to_use: Called by the java-framework-upgrade router for a Quarkus hop, or when the user asks what changed between two Quarkus versions, why a Quarkus app fails after an update (for example "package javax.ws.rs does not exist", "quarkus-resteasy-reactive not found", a Hibernate ORM 6 or 7 error, "Persistence unit was configured to run with a database version of at least"), which JDK a Quarkus version needs, or whether Quarkus 4.0 is ready.
argument-hint: "<hop: 2.13-to-3.2|3.2-to-3.8|3.8-to-3.15|3.15-to-3.20|3.20-to-3.27|3.27-to-3.33|3.33-to-3.40|3.40-to-4.0> [project-root]"
---

# Quarkus hop

Scope: one hop between Quarkus LTS streams, covering application code, tests, build files and Quarkus configuration. JDK changes belong to `java-toolkit:java-upgrade`; the router orders the two.

**Questions without a project task** ("what changed in 3.20", "which JDK for 3.33", "is 4.0 out"): skip the procedure. Answer from [quarkus-matrix.md](references/quarkus-matrix.md) and the hop references below, naming the Quarkus version, the change and the fix. Do not run scripts or edit files.

Inputs: the hop, the project root, the build JDK home (`jdk.N` from detect) and the CLI version (`quarkus_cli` from detect).

## Procedure

1. **Preflight.** Load the hop reference. Confirm that `git status` is clean, so the recipe diff stands alone, and that the build and tests pass on the hop's JDK before any change. If the hop's minimum JDK in [quarkus-matrix.md](references/quarkus-matrix.md) is above the build JDK, stop: the router must run the JDK hop first.
2. **Recipe run.** Run the update pinned to the hop's stream. Use the CLI if `quarkus_cli` is at least the target stream; otherwise use the Maven or Gradle form, with the plugin version from the reference header:

   ```bash
   quarkus update --stream=<X.Y>
   ./mvnw io.quarkus.platform:quarkus-maven-plugin:<target-version>:update -N -Dstream=<X.Y>
   ./gradlew -PquarkusPluginVersion=<target-version> quarkusUpdate --stream=<X.Y>
   ```

   On a large project, run with `rewriteDryRun` first and show the user the patch size. Never install or upgrade the CLI.
3. **Diff review.** Read `git diff`. Every item under "Automated (verify)" in the hop reference must appear in the diff or be not applicable. Record anything the recipe changed outside that list in progress.md. Revert nothing silently; when a recipe change looks wrong, ask.
4. **Manual items.** Run `scan.sh <root> --framework quarkus --from <a> --to <b>` from the `java-upgrade` scripts. Go through every Manual row of the reference: apply the fix, or mark it not applicable with a reason (extension not used, no hit). Group edits by area so each change is reviewable.
5. **Verify.** Build and test on the hop's JDK. Behavior rows (threading, transactions, Host validation, Hibernate query semantics, Dev Services defaults) need a test run, not only a compile. Compare test counts with the baseline.
6. **Rescan.** Re-run the scan. A `renamed` hit that remains is a miss by the recipe: fix it. `behavior` hits stay as candidates; list each with its verdict under "Remaining scan hits (explained)" in progress.md.

## Rules

- One stream per run. A multi-LTS jump runs this skill once per hop, in order.
- Prefer the configuration or code fix the guide names. Escape hatches such as `quarkus.hibernate-orm.database.version-check.enabled=false`, `quarkus.arc.fail-on-intercepted-private-method=false`, `quarkus.http.host-validation.require-localhost=false` or a forced older Dev Services provider are temporary. Name them in progress.md with a follow-up.
- Never weaken, skip or delete tests. A test that encoded old behavior (for example `FileUpload#fileName()` returning a path) changes only with the user's agreement.
- Database minimums (Hibernate dialects) are environment facts. Report the required version; do not lower `quarkus.datasource.db-version` without the user's agreement.
- Quarkiverse and third-party extensions follow their own release lines. If one has no version for the target stream, stop and list it as a prerequisite.
- Facts and versions come from [quarkus-matrix.md](references/quarkus-matrix.md). 4.0 is beta: run 3.40 → 4.0 only when the plan says the user opted in.

## Hop references

| Hop | File | JDK | Main topics |
|-----|------|-----|-------------|
| 2.13/2.16 → 3.2 | [2.13-to-3.2.md](references/2.13-to-3.2.md) | 11 | Jakarta EE 10 (`javax` → `jakarta`), Hibernate ORM 5.6 → 6.2, recipes start at 3.0 |
| 3.2 → 3.8 | [3.2-to-3.8.md](references/3.2-to-3.8.md) | 17 | Java 17 minimum (3.7) |
| 3.8 → 3.15 | [3.8-to-3.15.md](references/3.8-to-3.15.md) | 17 | RESTEasy Reactive → Quarkus REST (3.9), Hibernate ORM 6.6 |
| 3.15 → 3.20 | [3.15-to-3.20.md](references/3.15-to-3.20.md) | 17 | See reference |
| 3.20 → 3.27 | [3.20-to-3.27.md](references/3.20-to-3.27.md) | 17 | Hibernate ORM 7.0 / Jakarta Persistence 3.2 (3.24), ORM 7.1 |
| 3.27 → 3.33 | [3.27-to-3.33.md](references/3.27-to-3.33.md) | 17 | Hibernate ORM 7.2 |
| 3.33 → 3.40 | [3.33-to-3.40.md](references/3.33-to-3.40.md) | 17 | `@Transactional` threading, Host validation, Quarkus Data, ORM 7.4, TLS SPI move |
| 3.40 → 4.0 (beta) | [3.40-to-4.0.md](references/3.40-to-4.0.md) | 21 | Java 21 minimum, dropped relocations, Jackson package rename, Hibernate ORM 8 |
