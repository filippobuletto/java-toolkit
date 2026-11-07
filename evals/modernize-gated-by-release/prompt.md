---
description: Modernize skill must not suggest features above the project's release
tags: [modernize]
runs: 3
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---
Our library still targets Java 11 for consumers (maven.compiler.release is 11). Which newer Java language features can we adopt in it today? We were thinking about records, switch expressions, and virtual threads.
