---
type: llm
---
PASS only if the answer gets all four right:
1. `StableValue` was renamed to `LazyConstant` in JDK 26 and is still a preview API on 27 (its API changed again), so code compiled with --enable-preview on 25 must be rewritten for 27 or replaced with a final-API approach.
2. Reflective mutation of final fields prints a warning from JDK 26 (JEP 500, "prepare to make final mean final"), with deny planned as a future default; fix the helper (constructor injection, non-final field, or inject the value), with --enable-final-field-mutation (or the illegal-final-field-mutation option) only as a temporary measure.
3. `Thread.stop()` no longer exists on JDK 27 (it threw UnsupportedOperationException since 20), so the watchdog must switch to cooperative cancellation such as interrupt() or Future.cancel(true).
4. JDK 27 selects G1 in every environment (JEP 523), so small containers no longer get Serial GC automatically; pass -XX:+UseSerialGC explicitly if they want the old choice, otherwise measure memory.
FAIL if any of the four is missing or wrong (for example claiming Thread.stop still throws on 27, or that StableValue is final).
