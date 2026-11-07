---
description: Secure-coding skill must catch the broken Oracle guide snippet and give a fix that compiles and validates
tags: [security]
runs: 3
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---
I copied this from Oracle's Secure Coding Guidelines for Java SE (guideline 8-3) into our codebase, but something feels off. Is it correct, and is it safe against crafted serialized streams? Give me the version we should use.

```java
public final class Nonnegative implements java.io.Serializable {
    private static final long serialVersionUID = 1L;
    private int value;
    public Nonnegative(int value) {
        // Make check before assignment.
        this.data = nonnegative(value);
    }
    private static int nonnegative(int value) {
        if (value < 0) {
            throw new IllegalArgumentException(value +
                                               " is negative");
        }
        return value;
    }
    private void readObject(
        java.io.ObjectInputStream in
    ) throws java.io.IOException, ClassNotFoundException {
        java.io.ObjectInputStream.GetField fields =
            in.readFields();
        this.value = nonnegative(field.get(value, 0));
    }
}
```
