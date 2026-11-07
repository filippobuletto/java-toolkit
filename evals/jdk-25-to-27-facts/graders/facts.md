---
type: llm
---
PASS only if the answer says all three of these:
1. String Templates were removed (not available on 23+ / 25) and must be rewritten with concatenation, String.formatted/format or similar;
2. StructuredTaskScope.ShutdownOnFailure no longer exists in 25; structured concurrency is still a preview API, so either use an ExecutorService (for example virtual threads) with futures, or opt into the new preview API StructuredTaskScope.open(...) knowingly;
3. -XX:+ZGenerational is obsolete on 24+ and should be removed, keeping -XX:+UseZGC.
FAIL if it suggests keeping any of them as-is or claims they work on 25 without changes.
