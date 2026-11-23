---
description: On JDK 17, a simplify-and-modernize request converts the value class to a record and the build stays green
tags: [simplifier]
runs: 1
max_turns: 20
timeout_seconds: 1500
allowed_tools: [Read, Glob, Grep, Skill, Agent, Bash, Edit, Write]
---
I just wrote the order classes under src/main. Use the java-simplifier agent to simplify my recent changes and modernize them to the Java features our release supports; behavior must stay exactly the same.

When it is done, run `./mvnw -q verify > verify.log 2>&1; echo "exit=$?" >> verify.log` and tell me the exit code.
