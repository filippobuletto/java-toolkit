---
type: regex
pattern: 'assertEquals\(List\.of\("a"\), order\.getItems\(\)\)'
match: 'count:2'
target: { source: file, path: src/test/java/com/example/orders/OrderTest.java }
---
