# Quarkus version matrix

Single source for Quarkus version facts used by `java-framework-upgrade` and `java-quarkus-migrate`. Checked 2026-11-08 against:

- Quarkus wiki migration guides, commit `4b6f152` (<https://github.com/quarkusio/quarkus/wiki/Migration-Guides>)
- Quarkus source at each LTS tag: `independent-projects/parent/pom.xml` (`maven.compiler.release`), `build-parent/pom.xml` (`recommended-java-version`, `supported-maven-versions`), `bom/application/pom.xml` (library versions)
- <https://quarkus.io/guides/update-quarkus>

## LTS streams

The hop chain only stops on these streams. Each LTS is the direct continuation of the minor before it, so its own guide has no changes; the hop reference covers the minors in between.

| Stream | Released | Latest tag | Min JDK | Recommended JDK | Jakarta EE | Hibernate ORM | Maven |
|--------|----------|------------|---------|-----------------|------------|---------------|-------|
| 2.13 | 2022-09-28 | 2.13.9.Final | 11 | 11 | EE 8 (`javax.*`) | 5.6 | 3.6.2+ |
| 2.16 | 2023-01-25 | 2.16.12.Final | 11 | 17 | EE 8 (`javax.*`) | 5.6 | 3.6.2+ |
| 3.2 | 2023-07-05 | 3.2.12.Final | 11 | 17 | EE 10 (`jakarta.*`) | 6.2 | 3.8.2+ |
| 3.8 | 2024-02-28 | 3.8.6.1 | 17 | 21 | EE 10 | 6.4 | 3.8.2+ |
| 3.15 | 2024-09-26 | 3.15.7 | 17 | 21 | EE 10 | 6.6 | 3.8.6+ |
| 3.20 | 2025-03-26 | 3.20.6.2 | 17 | 21 | EE 10 | 6.6 | 3.8.6+ |
| 3.27 | 2025-09-24 | 3.27.6.1 | 17 | 21 | EE 10 | 7.1 | 3.8.6+ |
| 3.33 | 2026-03-25 | 3.33.4.1 | 17 | 25 | EE 10 | 7.2 | 3.9.0+ |
| 3.40 | 2026-09-30 | 3.40.1.1 | 17 | 25 | EE 10 | 7.4 | 3.9.0+ |
| 4.0 | beta | 4.0.0.Beta3 | 21 | 25 | Jakarta REST 4.0 (EE 11 level) | 8.0 (beta) | 3.9.0+ |

2.16 is the last 2.x stream. `quarkus update` needs 2.13 or later as the starting point.

## Java minimum changes

| From | Min JDK | Source |
|------|---------|--------|
| 2.0 | 11 | Migration-Guide-2.0, "JDK 11" |
| 3.7 | 17 | Migration-Guide-3.7, "Java 17": "minimum version you need to use to build and run" |
| 4.0 | 21 | Migration-Guide-4.0, "Java 21 as the minimum version": "Java 17 is not supported anymore" |

Quarkus 3.0 to 3.6 still run on Java 11. The hop 3.2 → 3.8 crosses 3.7, so it needs JDK 17 before it starts.

Recommended JDK is what the Quarkus build recommends at that tag; running on a newer JDK than recommended is not covered by these facts.

## Update tooling

`quarkus update` runs OpenRewrite recipes from `io.quarkus:quarkus-update-recipes` (<https://github.com/quarkusio/quarkus-updates>). It applies every recipe between the project's version and the target stream. Recipes exist for 3.0 onward; there are none for 2.x minors. The recipes cover only part of a migration: guide items marked `:gear: :white_check_mark:` are automated, everything else is manual.

| Build | Command (one hop, applies the recipes) | Dry run (diff only) |
|-------|----------------------------------------|---------------------|
| CLI | `quarkus update --stream=<X.Y> --yes` | `--dry-run` |
| Maven | `./mvnw -B io.quarkus.platform:quarkus-maven-plugin:<target-version>:update -N -Dstream=<X.Y> -Drewrite=true` | `-DrewriteDryRun=true` |
| Gradle (Groovy DSL) | `./gradlew -PquarkusPluginVersion=<target-version> quarkusUpdate --stream=<X.Y> --rewrite` | `--rewriteDryRun` |

- Always pass the confirm flag (`--yes`, `-Drewrite=true`, `--rewrite`). Without a terminal the update asks "Do you want to apply the generated update recipes", reads no answer, prints `Project update has been skipped` and still exits 0 with BUILD SUCCESS. An empty `git diff` after a run means it was skipped.
- `<target-version>` is the latest tag of the target stream from the table above. The plugin must be at least as new as the target: a 2.16 project updates with the 3.2 plugin, not its own.
- `-PquarkusPluginVersion` works when the Gradle build reads the plugin version from `quarkusPluginVersion` in `gradle.properties` (the generated default). Otherwise set the plugin version in the build file by hand first.
- **Gradle Kotlin DSL is not supported.** The Gradle task fails with `QuarkusUpdateException: gradle-kotlin-dsl is not supported yet`. The 3.40 CLI also failed on a Kotlin DSL project, leaving the tree unchanged. For `build.gradle.kts`, raise `quarkusPlatformVersion` and `quarkusPluginVersion` in `gradle.properties` to the target tag by hand, and treat the hop's "Automated (verify)" items as manual.
- Other options (CLI `--x`, Maven `-Dx`, Gradle `--x`): `platformVersion`, `additionalUpdateRecipes`, `quarkusUpdateRecipes`, `rewritePluginVersion`; Maven and Gradle also take `rewrite=false` (version bump only), CLI `--no-rewrite`.
- The CLI must be at least as new as the target stream. The skills never install or upgrade it; they fall back to the Maven or Gradle form.
- Checked end to end 2026-11-08 with CLI 3.40.1.1, Maven 3.10.0 and the generated Gradle 8.14 wrapper on JDK 17: Maven 3.20 → 3.27 (version bump, `database.generation` → `schema-management.strategy`, `.enable` → `.enabled`), CLI 3.27 → 3.33 (`quarkus-junit5` → `quarkus-junit`, `@{argLine}`), Gradle Groovy 3.20 → 3.27. Build and tests green after each.

## Corrections

Advice the skills must not give:

| Wrong | Right |
|-------|-------|
| Quarkus 3.0 needs Java 17 | 3.0–3.6 run on Java 11; 17 is the minimum from 3.7 |
| Quarkus 4.0 is GA | 4.0.0.Beta3 is the newest 4.0 tag on 2026-11-08; treat 4.0 as beta |
| Quarkus 4.0 runs on Java 17 | 4.0 needs Java 21 |
| `quarkus update` handles the whole migration | It automates only `:white_check_mark:` items; Hibernate ORM API changes and behavior changes stay manual |
| Run the project's own plugin version for `update` | Use the target stream's plugin version |
| `@Transactional` REST endpoints still run on a worker thread | From 3.35 a `@Transactional` method returning `Uni` runs on the event loop unless it is `@Blocking` |
| Disable `quarkus.hibernate-orm.database.version-check.enabled` to fix a version error | Upgrade the database, or set `quarkus.datasource.db-version` to the actual server version (may disable dialect features) |
