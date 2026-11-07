# Collections and streams

Contents: immutable factories (9–10) · Stream.toList (16) · sequenced collections (21) · stream gatherers (24) · other additions · do-not-convert rules.

## Immutable collection factories — JEP 269 (9), copyOf (10)

Signal: `unmodifiable-wrap`.

<!-- compile: jdk=10 fails-below -->
```java
import java.util.List;
import java.util.Map;
import java.util.Set;

static final List<String> LEVELS = List.of("low", "mid", "high");
static final Map<String, Integer> LIMITS = Map.of("low", 10, "high", 100);

static Set<String> snapshot(Set<String> live) {
    return Set.copyOf(live);
}
```

Semantics differ from `Collections.unmodifiableList(new ArrayList<>(…))` and `Arrays.asList`:

- `null` elements, keys or values throw `NullPointerException`; `contains(null)` throws too.
- Duplicates in `Set.of` / `Map.of` throw `IllegalArgumentException`.
- Iteration order of `Set.of` / `Map.of` is unspecified and varies between runs. Tests or output relying on order break.
- `Collections.unmodifiableList(x)` is a view that reflects later changes to `x`; `List.copyOf(x)` is a snapshot.
- `Arrays.asList` supports `set`; `List.of` does not.

## Stream.toList() — 16

Signal: `collect-tolist`.

<!-- compile: jdk=16 fails-below -->
```java
import java.util.List;

static List<String> upper(List<String> names) {
    return names.stream().map(String::toUpperCase).toList();
}
```

`toList()` returns an unmodifiable list and allows `null` elements. `Collectors.toList()` returns a mutable `ArrayList` in practice. Keep `Collectors.toList()` (or use `Collectors.toCollection(ArrayList::new)`) when any caller mutates the result; follow the value through callers before converting.

## Sequenced collections — JEP 431, final 21

Signal: `last-element`. One API for first/last/reversed on `List`, `Deque`, `LinkedHashSet`, `SortedSet`, `LinkedHashMap`, `SortedMap`.

<!-- compile: jdk=21 fails-below -->
```java
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.SequencedMap;

static String newest(List<String> events) {
    return events.getLast();
}

static List<String> newestFirst(List<String> events) {
    return events.reversed();
}

static Map.Entry<String, Integer> oldestEntry(LinkedHashMap<String, Integer> byInsertion) {
    SequencedMap<String, Integer> map = byInsertion;
    return map.firstEntry();
}
```

`getFirst()`/`getLast()` throw `NoSuchElementException` on an empty collection, like `get(0)` throws `IndexOutOfBoundsException`; exception types differ, so check `catch` blocks. `reversed()` is a view.

## Stream gatherers — JEP 485, final 24

Custom intermediate operations via `Stream.gather`. Built-ins in `java.util.stream.Gatherers`: `windowFixed`, `windowSliding`, `fold`, `scan`, `mapConcurrent`.

<!-- compile: jdk=24 fails-below -->
```java
import java.util.List;
import java.util.stream.Gatherers;
import java.util.stream.Stream;

static List<List<Integer>> pairs(List<Integer> values) {
    return values.stream().gather(Gatherers.windowSliding(2)).toList();
}

static List<Integer> runningTotals(List<Integer> values) {
    return values.stream().gather(Gatherers.scan(() -> 0, Integer::sum)).toList();
}

static String joined(Stream<String> parts) {
    return parts.gather(Gatherers.fold(() -> "", (acc, s) -> acc.isEmpty() ? s : acc + "," + s))
            .findFirst().orElse("");
}
```

`fold` takes a `Supplier` for the initial value, not a plain value. Use gatherers to replace hand-written stateful loops or external mutable accumulators; do not rewrite simple `map`/`filter` pipelines.

`mapConcurrent(n, f)` runs `f` on virtual threads with at most `n` in flight and keeps encounter order: a bounded parallel I/O fan-out without an executor.

## Other additions

| API | JDK |
|-----|-----|
| `Optional.orElseThrow()`, `Collectors.toUnmodifiableList/Set/Map` | 10 |
| `Optional.isEmpty()`, `Predicate.not`, `Collection.toArray(IntFunction)` | 11 |
| `Collectors.teeing` | 12 |
| `Stream.mapMulti` | 16 |
| `HashMap.newHashMap(n)` (sized for n entries) | 19 |

## Do not convert when

- Order, nullability or mutability of the result is relied on (rules above).
- The code is a hot loop where the stream version would allocate more; measure first.
- The project must compile for a release below the API's JDK.
