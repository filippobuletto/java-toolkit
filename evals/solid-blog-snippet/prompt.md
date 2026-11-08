---
description: SOLID skill must catch the broken blog snippet, name the real defect, and give a delegating fix that compiles
tags: [solid]
runs: 3
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---
I found this Liskov Substitution example in a "SOLID Java" blog post and want to use it in a training. Is it correct Java, and does it really show an LSP violation? Give me the version I should show.

```java
// BAD
public class DataHashSet extends HashSet {
  int addCount = 0;
  public boolean function add(Object object) {
    addCount++;
    return super.add(object);
  }
  // the size of count will be added twice!
  public boolean function addAll(Collection collection) {
    addCount += collection.size();
    return super.addAll(collection);
  }
}

// GOOD: Delegation Over Subtyping
public class DataHashSet implements Set {
  int addCount = 0;
  Set set;
  public DataHashSet(Set set) {
    this.set = set;
  }
  public boolean add(Object object) {
    addCount++;
    return this.set.add(object);
  }
  public boolean addAll(Collection collection) {
    addCount += collection.size();
    return this.set.addAll(collection);
  }
}
```
