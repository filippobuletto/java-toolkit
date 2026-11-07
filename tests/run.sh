#!/usr/bin/env bash
# Behavior tests for skills/java-upgrade/scripts/{detect,scan}.sh against tests/fixtures.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS="$ROOT/skills/java-upgrade/scripts"
FIX="$ROOT/tests/fixtures"
pass=0 fail=0

check() { # check <name> <expected> <actual>
  if [[ "$2" == "$3" ]]; then pass=$((pass + 1)); echo "ok   $1"
  else fail=$((fail + 1)); printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$1" "$2" "$3"; fi
}

# kv <key> <detect-output>: value of key=value line
kv() { sed -n "s/^$1=//p" <<<"$2" | head -n1; }

# ids <scan-output> [category|!category]: sorted unique signal ids, optionally filtered by category
ids() {
  local filter="${2:-}"
  awk -F'\t' -v f="$filter" '
    f == "" || (substr(f,1,1) == "!" ? $2 != substr(f,2) : $2 == f) { print $1 }' <<<"$1" | sort -u | paste -sd, -
}

detect() { bash "$SCRIPTS/detect.sh" "$1"; }
scan() { bash "$SCRIPTS/scan.sh" "$@"; }

# --- signal catalog is well formed ---------------------------------------------------------
bad=$(awk -F'\t' '!/^#/ && NF && (NF != 6 || $2 !~ /^(removed|deprecated|behavior|flag|build|modernize)$/ || $3 !~ /^[0-9]+$/ || $4 !~ /^(java|build|config)$/) { print NR": "$0 }' "$SCRIPTS/signals.tsv")
check "catalog: rows have 6 fields, known category/scope, numeric since" "" "$bad"
dups=$(awk -F'\t' '!/^#/ && NF { print $1 }' "$SCRIPTS/signals.tsv" | sort | uniq -d | paste -sd, -)
check "catalog: ids unique" "" "$dups"

# --- detect.sh -----------------------------------------------------------------------------
out=$(detect "$FIX/maven-java8")
check "detect java8: build tool" "maven" "$(kv build_tool "$out")"
check "detect java8: release normalized from 1.8" "8" "$(kv java_release "$out")"
check "detect java8: release source" "maven.compiler.source" "$(kv java_release_from "$out")"
check "detect java8: no wrapper" "none" "$(kv wrapper "$out")"
check "detect java8: single module" "0" "$(kv maven_modules "$out")"
check "detect java8: no blocker libs" "" "$(kv uses "$out")"
check "detect java8: compiler plugin version" "3.8.1" "$(kv maven_compiler_plugin "$out")"
check "detect java8: surefire version" "2.22.2" "$(kv maven_surefire_plugin "$out")"

out=$(detect "$FIX/maven-java17")
check "detect java17: release via property indirection" "17" "$(kv java_release "$out")"
check "detect java17: release source" "maven.compiler.release" "$(kv java_release_from "$out")"
check "detect java17: modules counted" "2" "$(kv maven_modules "$out")"
check "detect java17: blocker libs" "lombok,mockito,jacoco" "$(kv uses "$out")"
check "detect java17: CI JDK" "17" "$(kv ci_java "$out")"
check "detect java17: Docker JDK" "17" "$(kv docker_java "$out")"

out=$(detect "$FIX/gradle-kts-java21")
check "detect gradle: build tool" "gradle" "$(kv build_tool "$out")"
check "detect gradle: kotlin DSL" "kotlin" "$(kv gradle_dsl "$out")"
check "detect gradle: wrapper" "gradlew" "$(kv wrapper "$out")"
check "detect gradle: wrapper version" "8.5" "$(kv gradle_version "$out")"
check "detect gradle: toolchain release" "21" "$(kv java_release "$out")"
check "detect gradle: release source" "toolchain" "$(kv java_release_from "$out")"
check "detect gradle: blocker libs" "mockito" "$(kv uses "$out")"

empty=$(mktemp -d /private/tmp/java-upgrade-empty.XXXX)
check "detect empty dir: no build tool" "none" "$(kv build_tool "$(detect "$empty")")"

if [[ -d "$HOME/.sdkman/candidates/java" ]]; then
  n=$(detect "$FIX/maven-java8" | grep -c '^jdk\.[0-9]*=')
  check "detect: lists installed sdkman JDKs" "true" "$([[ $n -gt 0 ]] && echo true || echo false)"
fi

# --- scan.sh -------------------------------------------------------------------------------
out=$(scan "$FIX/maven-java8" --from 8 --to 17)
check "scan java8→17: breaking signals" \
  "cms-gc,deep-reflection,gc-log-flags,jaxb,nashorn,new-wrapper,permgen-flags" "$(ids "$out" '!modernize')"
check "scan java8→17: modernize candidates" \
  "data-class,instanceof-cast,multiline-concat,old-switch" "$(ids "$out" modernize)"
check "scan java8→17: clean file has no hits" "" "$(grep -F 'Clean.java' <<<"$out")"
check "scan java8→17: location is relative path:line" \
  "src/main/java/com/example/legacy/XmlCodec.java:4" "$(awk -F'\t' '$1 == "jaxb" { print $4; exit }' <<<"$out")"
check "scan java8→17: flags found in run.sh" "run.sh" "$(awk -F'\t' '$1 == "cms-gc" { split($4, a, ":"); print a[1] }' <<<"$out")"

out=$(scan "$FIX/maven-java8" --from 8 --to 25)
check "scan java8→25: adds finalize and Unsafe" \
  "cms-gc,deep-reflection,finalize,gc-log-flags,jaxb,nashorn,new-wrapper,permgen-flags,unsafe-memory" "$(ids "$out" '!modernize')"
check "scan java8→25: adds getLast candidate" \
  "data-class,instanceof-cast,last-element,multiline-concat,old-switch" "$(ids "$out" modernize)"

out=$(scan "$FIX/maven-java17" --from 17 --to 25)
check "scan java17→25: breaking signals" \
  "biased-locking,illegal-access,jacoco,jni,lombok,mockito-agent,security-manager,zgenerational" "$(ids "$out" '!modernize')"
check "scan java17→25: modernize candidates" "collect-tolist,fixed-pool,thread-local" "$(ids "$out" modernize)"

out=$(scan "$FIX/gradle-kts-java21" --from 21 --to 25)
check "scan gradle 21→25: dead preview APIs and preview flag" \
  "preview-flag,string-templates,structured-concurrency-old" "$(ids "$out" '!modernize')"

out=$(scan "$FIX/maven-java8")
check "scan without range: reports every hit" "true" "$([[ $(ids "$out") == *finalize* && $(ids "$out") == *last-element* ]] && echo true || echo false)"

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
