---
type: llm
---
PASS only if the answer states all of:
1. The 3.x LTS releases are 3.2, 3.8, 3.15, 3.20, 3.27, 3.33 and 3.40 (no missing or extra ones).
2. Quarkus 3.2 runs on Java 11; Java 17 is the minimum from Quarkus 3.7.
3. RESTEasy Reactive was renamed to Quarkus REST in 3.9, so the artifact is `quarkus-rest-jackson` (quarkus update rewrites it).
4. Turning off the version check is an escape hatch, not the fix: upgrade the database, or set `quarkus.datasource.db-version` to the real server version and accept that some dialect features may be disabled.
FAIL if any of the four is wrong or missing.
