---
description: Quarkus version facts the base model may get wrong; answer must come from the Quarkus skills
tags: [facts, quarkus]
runs: 3
max_turns: 10
allowed_tools: [Read, Glob, Grep, Skill]
---
A few Quarkus questions before we plan our upgrades:

1. Which Quarkus 3.x releases are LTS?
2. Can we run Quarkus 3.2 on Java 11? From which Quarkus version is Java 17 required?
3. Our pom has `quarkus-resteasy-reactive-jackson`. Is that still the artifact name on the latest LTS?
4. After an upgrade we get "Persistence unit '<default>' was configured to run with a database version of at least '16'". Can we just turn the version check off?
