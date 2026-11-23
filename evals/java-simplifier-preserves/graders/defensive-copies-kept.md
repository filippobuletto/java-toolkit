---
type: regex
pattern: 'new ArrayList<>\((this\.)?items\)'
match: 'count:2'
target: { source: file, path: src/main/java/com/example/orders/Order.java }
---
