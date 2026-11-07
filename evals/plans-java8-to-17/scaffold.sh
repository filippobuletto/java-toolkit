#!/usr/bin/env bash
# Seed the workspace with the Java 8 Maven fixture from this repository.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../tests/fixtures/maven-java8" && pwd)"
cp -R "$src/." .
