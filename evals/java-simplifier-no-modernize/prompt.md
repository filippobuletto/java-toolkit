---
description: On JDK 17, a plain simplify request does not convert the value class to a record (modernization is opt-in)
tags: [simplifier]
runs: 1
max_turns: 20
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Agent, Bash, Edit, Write]
---
I just wrote the order classes under src/main. Use the java-simplifier agent to simplify my recent changes for readability; behavior must stay exactly the same.

When it is done, run `./mvnw -q verify > verify.log 2>&1; echo "exit=$?" >> verify.log` and tell me the exit code.
