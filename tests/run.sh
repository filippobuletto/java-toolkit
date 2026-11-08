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
bad=$(awk -F'\t' '!/^#/ && NF && (NF != 6 || $2 !~ /^(removed|deprecated|behavior|flag|build|modernize|security)$/ || $3 !~ /^[0-9]+$/ || $4 !~ /^(java|build|config)$/) { print NR": "$0 }' "$SCRIPTS/signals.tsv")
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

check "detect plain java: no Quarkus" "" "$(kv quarkus_version "$out")"

out=$(detect "$FIX/quarkus-2.16-maven")
check "detect quarkus maven: version from platform property" "2.16.12.Final" "$(kv quarkus_version "$out")"
check "detect quarkus maven: stream" "2.16" "$(kv quarkus_stream "$out")"
check "detect quarkus maven: platform group" "io.quarkus.platform" "$(kv quarkus_platform "$out")"
check "detect quarkus maven: plugin version resolved" "2.16.12.Final" "$(kv quarkus_plugin "$out")"
check "detect quarkus maven: extensions" \
  "quarkus-arc,quarkus-hibernate-orm-panache,quarkus-jdbc-postgresql,quarkus-junit5,quarkus-resteasy-reactive-jackson" \
  "$(kv quarkus_extensions "$out")"
check "detect quarkus maven: release" "11" "$(kv java_release "$out")"

out=$(detect "$FIX/quarkus-3.20-gradle-kts")
check "detect quarkus gradle: version from gradle.properties" "3.20.6.2" "$(kv quarkus_version "$out")"
check "detect quarkus gradle: stream" "3.20" "$(kv quarkus_stream "$out")"
check "detect quarkus gradle: platform group" "io.quarkus.platform" "$(kv quarkus_platform "$out")"
check "detect quarkus gradle: plugin version" "3.20.6.2" "$(kv quarkus_plugin "$out")"
check "detect quarkus gradle: extensions" \
  "quarkus-hibernate-orm,quarkus-junit5,quarkus-opentelemetry,quarkus-rest,quarkus-tls-registry" \
  "$(kv quarkus_extensions "$out")"

if command -v quarkus >/dev/null 2>&1; then
  repo=$(mktemp -d /private/tmp/java-upgrade-quarkus-repo.XXXX)
  cp -R "$FIX/quarkus-2.16-maven/." "$repo" && git -C "$repo" init -q
  out=$(detect "$repo")
  check "detect quarkus: reports the installed CLI" "true" "$([[ -n $(kv quarkus_cli "$out") ]] && echo true || echo false)"
  check "detect quarkus: CLI call leaves no files in the project" "" "$(cd "$repo" && git status --porcelain --ignored | grep -F .quarkus || true)"
fi

groovy=$(mktemp -d /private/tmp/java-upgrade-quarkus-groovy.XXXX)
printf "plugins {\n    id 'java'\n    id 'io.quarkus' version '3.8.6'\n}\n" >"$groovy/build.gradle"
out=$(detect "$groovy")
check "detect quarkus groovy: plugin version from plugins block" "3.8.6" "$(kv quarkus_plugin "$out")"
check "detect quarkus groovy: version falls back to plugin" "3.8" "$(kv quarkus_stream "$out")"

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

# --- scan.sh --security ----------------------------------------------------------------------
SEC="$FIX/secure-coding"
out=$(scan "$SEC" --security)
check "scan --security: signals found" \
  "add-opens,archive-read,cloneable,invocation-handler,jdbc-statement,jndi-context,jndi-trust-flags,log-secret,module-opens,native-public,object-input-stream,process-exec,public-static-final-mutable,public-static-mutable,read-object-impl,script-engine,sql-concat,tls-trust,xml-decoder,xml-factory" \
  "$(ids "$out")"
check "scan --security: only the security category" "security" "$(cut -f2 <<<"$out" | sort -u)"
check "scan --security: hardened file has no hits" "" "$(grep -F 'Hardened.java' <<<"$out")"
check "scan --security: location is relative path:line" \
  "src/main/java/com/example/secure/Archive.java:10" "$(awk -F'\t' '$1 == "archive-read" { print $4; exit }' <<<"$out")"
check "scan --security: flags found in launch script" "start.sh" \
  "$(awk -F'\t' '$1 == "add-opens" { split($4, a, ":"); print a[1] }' <<<"$out")"

sum=$(scan "$SEC" --security --summary)
check "scan --security --summary: xml-factory counts every factory" "3" "$(awk -F'\t' '$1 == "xml-factory" { print $4 }' <<<"$sum")"
check "scan --security --summary: sql-concat finds call and variable forms" "2" "$(awk -F'\t' '$1 == "sql-concat" { print $4 }' <<<"$sum")"
check "scan --security --summary: jdbc-statement counts createStatement" "2" "$(awk -F'\t' '$1 == "jdbc-statement" { print $4 }' <<<"$sum")"
check "scan --security --summary: xml-decoder skips the import line" "1" "$(awk -F'\t' '$1 == "xml-decoder" { print $4 }' <<<"$sum")"
check "scan --security --summary: script-engine skips the import line" "1" "$(awk -F'\t' '$1 == "script-engine" { print $4 }' <<<"$sum")"
check "scan --security --summary: public static final mutable fields" "2" "$(awk -F'\t' '$1 == "public-static-final-mutable" { print $4 }' <<<"$sum")"

out=$(scan "$SEC" --security --to 8)
check "scan --security --to 8: hides module-only signals" "false" "$([[ $(ids "$out") == *module-opens* ]] && echo true || echo false)"
check "scan --security --to 8: keeps the rest" "true" "$([[ $(ids "$out") == *xml-factory* ]] && echo true || echo false)"

out=$(scan "$SEC" --from 8 --to 25)
check "scan without --security: never reports security signals" "" "$(ids "$out" security)"
out=$(scan "$FIX/maven-java8" --security)
check "scan --security: legacy fixture has none of the fixture-only signals" "false" "$([[ $(ids "$out") == *tls-trust* ]] && echo true || echo false)"

# --- scan.sh --framework quarkus -------------------------------------------------------------
QCAT="$ROOT/skills/java-framework-upgrade/scripts/quarkus.tsv"
bad=$(awk -F'\t' '!/^#/ && NF && (NF != 6 || $2 !~ /^(removed|renamed|deprecated|behavior)$/ || $3 !~ /^[0-9]+\.[0-9]+$/ || $4 !~ /^(java|build|config)$/) { print NR": "$0 }' "$QCAT")
check "quarkus catalog: rows have 6 fields, known category/scope, dotted since" "" "$bad"
dups=$(awk -F'\t' '!/^#/ && NF { print $1 }' "$QCAT" | sort | uniq -d | paste -sd, -)
check "quarkus catalog: ids unique" "" "$dups"

QREF="$ROOT/skills/java-quarkus-migrate/references"
unknown=$(for f in "$QREF"/*-to-*.md; do
    grep -oE '\(`[a-z0-9-]+`( signal)?\)' "$f" | sed -E 's/^\(`([a-z0-9-]+)`.*/\1/' | while read -r id; do
      awk -F'\t' -v id="$id" '$1 == id { found = 1 } END { exit !found }' "$QCAT" || echo "$(basename "$f"):$id"
    done
  done | sort -u | paste -sd, -)
check "quarkus references: every cited signal id is in the catalog" "" "$unknown"

QM="$FIX/quarkus-2.16-maven" QG="$FIX/quarkus-3.20-gradle-kts"
out=$(scan "$QM" --framework quarkus --from 2.16 --to 3.2)
check "scan quarkus 2.16→3.2: jakarta namespace" "javax-ee" "$(ids "$out")"
check "scan quarkus 2.16→3.2: location is relative path:line" \
  "src/main/java/org/acme/greeting/Greeting.java:5" "$(awk -F'\t' '$1 == "javax-ee" { print $4; exit }' <<<"$out")"
out=$(scan "$QM" --framework quarkus --from 2.16 --to 3.40)
check "scan quarkus 2.16→3.40: renames and behavior" \
  "javax-ee,junit5-artifacts,orm-database-generation,rest-reactive-artifact,rest-reactive-config,transactional-uni" "$(ids "$out")"
out=$(scan "$QG" --framework quarkus --from 3.20 --to 3.40)
check "scan quarkus 3.20→3.40: gradle fixture" \
  "http-host-localhost,junit5-artifacts,kafka-native-provider,tls-provider-package,transactional-uni" "$(ids "$out")"
check "scan quarkus 3.20→3.40: removed sorts first" "removed" "$(head -n1 <<<"$out" | cut -f2)"
out=$(scan "$QG" --framework quarkus --from 3.20 --to 3.33)
check "scan quarkus 3.20→3.33: only the 3.31 junit rename" "junit5-artifacts" "$(ids "$out")"
out=$(scan "$QG" --framework quarkus --from 3.33 --to 3.33)
check "scan quarkus empty range: nothing" "" "$(ids "$out")"
sum=$(scan "$QM" --framework quarkus --from 2.16 --to 3.2 --summary)
check "scan quarkus --summary: javax-ee counts every import" "7" "$(awk -F'\t' '$1 == "javax-ee" { print $4 }' <<<"$sum")"

check "scan without --framework: never reports Quarkus signals" "" \
  "$(ids "$(scan "$QM" --from 11 --to 21)" | tr ',' '\n' | grep -xFf <(awk -F'\t' '!/^#/ && NF { print $1 }' "$QCAT") | paste -sd, -)"
check "scan --framework quarkus: JDK signals never reported" "" "$(ids "$(scan "$FIX/maven-java8" --framework quarkus --from 2.13 --to 4.0)")"
scan "$QM" --framework spring --from 2.0 --to 3.0 >/dev/null 2>&1; rc=$?
check "scan --framework: unknown framework is a usage error" "2" "$rc"
scan "$QM" --framework quarkus --security >/dev/null 2>&1; rc=$?
check "scan --framework with --security: usage error" "2" "$rc"

echo
echo "$pass passed, $fail failed"
[[ $fail -eq 0 ]]
