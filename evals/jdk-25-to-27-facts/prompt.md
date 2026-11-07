---
description: JDK 26/27 facts the base model is less sure of; answer must come out right and from the migrate skill
tags: [facts]
runs: 3
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---
We're moving a Java 25 service to Java 27. A few things we do today:

1. Lazy initialization with `StableValue`, compiled with `--enable-preview`.
2. A test helper that sets `private final` fields through reflection (`Field.setAccessible(true)` then `Field.set`).
3. A legacy watchdog thread that calls `Thread.stop()` on stuck workers.
4. Our containers have 1 CPU and 1 GB of memory, and we never pass a GC flag.

What changes for each of these on Java 27, and what should we do?
