---
description: Advice for a 21→25 move must not recommend String Templates, ShutdownOnFailure or ZGenerational
tags: [facts]
runs: 3
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---
We're moving our Java 21 service to Java 25. We use STR."..." string templates in a few places, StructuredTaskScope.ShutdownOnFailure for fan-out calls, and start the JVM with -XX:+UseZGC -XX:+ZGenerational. What do we need to change?
