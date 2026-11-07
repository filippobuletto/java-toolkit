---
type: llm
---
PASS only if the answer states that records (16), switch expressions (14) and virtual threads (21) are all above release 11 and cannot be used while the library targets 11, and offers what is available on 11 (for example var, String isBlank/strip/lines, Files.readString, HttpClient, List.of) or raising the release as a separate decision.
FAIL if it suggests using any of the three features while keeping release 11.
