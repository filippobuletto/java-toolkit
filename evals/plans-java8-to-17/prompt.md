---
description: Router detects a Java 8 Maven project, plans 8→11→17, and waits for confirmation before editing
tags: [router, smoke]
runs: 3
max_turns: 40
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill, Bash, Write]
---
Upgrade this project to Java 17. Write the plan but don't change any code yet.
