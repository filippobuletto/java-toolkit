---
type: llm
---
PASS only if the answer:
- says Quarkus 4.0 is not GA yet (beta, for example 4.0.0.Beta3) and that adopting it is an explicit opt-in;
- says 4.0 needs Java 21, so the service must move from Java 17 to 21 first;
- recommends going through the 3.33 and 3.40 LTS streams before 4.0, one hop at a time.
FAIL if it treats 4.0 as a released GA version, says 4.0 runs on Java 17, or plans a direct 3.27 → 4.0 jump without the intermediate LTS hops.
