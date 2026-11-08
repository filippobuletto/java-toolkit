#!/usr/bin/env bash
# Seed the workspace with the Quarkus 2.16 Maven fixture from this repository.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../tests/fixtures/quarkus-2.16-maven" && pwd)"
cp -R "$src/." .
