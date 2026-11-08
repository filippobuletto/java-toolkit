---
type: llm
focus: { source: file, path: .framework-upgrade/plan.md }
---
PASS only if the plan:
- targets Quarkus 3.40 through the LTS streams 3.2, 3.8, 3.15, 3.20, 3.27, 3.33, 3.40 in order, each hop pinned to its stream (for example `--stream=3.2`);
- puts a JDK 11 → 17 step, routed to java-upgrade, before the 3.2 → 3.8 hop (Quarkus 3.7+ needs Java 17), and keeps the 2.16 → 3.2 hop on JDK 11;
- names the javax → jakarta namespace change for the 2.16 → 3.2 hop and says Hibernate ORM 6 API changes need manual review;
- names the RESTEasy Reactive → Quarkus REST rename (quarkus-resteasy-reactive-jackson, quarkus.resteasy-reactive.path) in the 3.8 → 3.15 hop;
- does not include Quarkus 4.0 unless marked as an opt-in beta option.
FAIL if it plans a single jump without per-hop verification, raises the JDK inside a Quarkus step, or recommends Quarkus 4.0 as the target.
