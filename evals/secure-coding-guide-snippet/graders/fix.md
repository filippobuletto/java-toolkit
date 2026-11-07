---
type: llm
---
PASS only if the answer:
1. States the snippet does not compile, naming both defects: the constructor assigns `this.data` although the field is `value`, and `readObject` uses an undefined `field` and passes `value` instead of the field name, where it should be `fields.get("value", 0)`.
2. Gives corrected code where the constructor assigns `this.value = nonnegative(value)` and `readObject` reads `fields.get("value", 0)` and validates it with the same check before assigning.
FAIL if it calls the snippet correct as written, or if the corrected readObject assigns the streamed value without validation.
