---
type: llm
---
PASS only if the answer:
1. States that neither snippet compiles: `function` is not a Java keyword, and the GOOD class implements `Set` without implementing its other abstract methods.
2. Explains that the double count comes from `HashSet.addAll` calling the overridden `add` (self-use, fragile base class), and that this is better described as composition over inheritance than as a Liskov substitution violation.
3. Gives corrected generic code that compiles: a class that delegates to a `Set<E>`, for example by extending `AbstractSet<E>` or forwarding every `Set` method, and counts each added element once.
FAIL if it calls either snippet correct as written, or if the corrected code still counts elements twice.
