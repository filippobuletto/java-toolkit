#!/usr/bin/env bash
# Scan a Java project for upgrade signals listed in signals.tsv (same directory).
#
# Usage: scan.sh [ROOT] [--from N] [--to N] [--summary] [--security | --framework NAME]
#   --from N    current JDK feature release (default 0)
#   --to N      target JDK feature release (default 99)
#   --summary   one line per signal with hit count instead of one line per hit
#   --security  report only the security signals (Oracle Secure Coding Guidelines candidates) and
#               nothing else; without it security signals are never reported. --to N hides signals
#               that need a newer release, --from is ignored
#   --framework quarkus
#               report only framework signals from ../../java-framework-upgrade/scripts/<NAME>.tsv;
#               --from/--to are dotted framework streams (2.16, 3.40) and every category uses FROM < since <= TO
#
# Output (TSV, no header), ordered removed, flag, deprecated, behavior, build, modernize:
#   default:   id  category  since  path:line  note  matched-text
#   --summary: id  category  since  hits       note  first-path:line
# Range rule: removed/deprecated/behavior when FROM < since <= TO; flag/build/modernize/security when since <= TO.
# Uses rg when available, otherwise grep -E. Read-only.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
catalog="$here/signals.tsv"
root=. from= to= summary=0 security=0 framework=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) from="$2"; shift 2 ;;
    --to) to="$2"; shift 2 ;;
    --summary) summary=1; shift ;;
    --security) security=1; shift ;;
    --framework) framework="$2"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    -*) echo "scan.sh: unknown option $1" >&2; exit 2 ;;
    *) root="$1"; shift ;;
  esac
done

# key <version>: comparable integer; a framework stream 3.9 becomes 3009, a JDK release stays as is
key() { if [[ -n "$framework" ]]; then awk -F. '{ printf "%d\n", $1 * 1000 + $2 }' <<<"$1"; else echo "$1"; fi; }

if [[ -n "$framework" ]]; then
  (( security == 0 )) || { echo "scan.sh: --security and --framework are exclusive" >&2; exit 2; }
  catalog="$here/../../java-framework-upgrade/scripts/$framework.tsv"
  [[ "$framework" =~ ^[a-z-]+$ && -f "$catalog" ]] || { echo "scan.sh: unknown framework $framework" >&2; exit 2; }
  : "${from:=0.0}" "${to:=999.0}"
  [[ "$from" =~ ^[0-9]+\.[0-9]+$ && "$to" =~ ^[0-9]+\.[0-9]+$ ]] || { echo "scan.sh: --from/--to must be X.Y streams" >&2; exit 2; }
else
  : "${from:=0}" "${to:=99}"
  [[ "$from" =~ ^[0-9]+$ && "$to" =~ ^[0-9]+$ ]] || { echo "scan.sh: --from/--to must be integers" >&2; exit 2; }
fi
from=$(key "$from") to=$(key "$to")
cd "$root"

excluded_dirs=(.git target build .gradle node_modules .idea .java-upgrade out)
java_globs=('*.java')
build_globs=(pom.xml '*.gradle' '*.gradle.kts' gradle.properties '*.versions.toml' jvm.config maven.config)
config_globs=("${build_globs[@]}" '*.sh' 'Dockerfile*' '*.Dockerfile' '*.yml' '*.yaml' '*.properties'
  '*.conf' '*.cfg' '*.cmd' '*.bat' '*.env' Procfile Jenkinsfile Makefile '*.service')

# search <pattern> <glob>...: prints path:line:text
search() {
  local pattern="$1"; shift
  local args=() g d
  if command -v rg >/dev/null 2>&1; then
    for d in "${excluded_dirs[@]}"; do args+=(-g "!$d/"); done
    for g in "$@"; do args+=(-g "$g"); done
    rg --no-heading --line-number --with-filename --hidden --no-messages --color never "${args[@]}" -e "$pattern" . | sed 's|^\./||' || true
  else
    for d in "${excluded_dirs[@]}"; do args+=("--exclude-dir=$d"); done
    for g in "$@"; do args+=("--include=$g"); done
    grep -rEnI "${args[@]}" -e "$pattern" . 2>/dev/null | sed 's|^\./||' || true
  fi
}

rank() { case "$1" in removed) echo 1 ;; flag|renamed) echo 2 ;; deprecated) echo 3 ;; behavior) echo 4 ;; build) echo 5 ;; *) echo 6 ;; esac; }

ordered=$(awk -F'\t' '!/^#/ && NF' "$catalog" | while IFS=$'\t' read -r id cat since scope pattern note; do
  printf '%s\t%06d\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(rank "$cat")" "$(key "$since")" "$id" "$cat" "$since" "$scope" "$pattern" "$note"
done | sort -t$'\t' -k1,1n -k2,2n -k3,3 | cut -f3-)

while IFS=$'\t' read -r id cat since scope pattern note; do
  [[ "$cat" == security ]] && sec=1 || sec=0
  (( sec == security )) || continue
  k=$(key "$since")
  case "$cat" in
    removed|deprecated|behavior|renamed) (( from < k && k <= to )) || continue ;;
    *) (( k <= to )) || continue ;;
  esac
  case "$scope" in
    java) globs=("${java_globs[@]}") ;;
    build) globs=("${build_globs[@]}") ;;
    *) globs=("${config_globs[@]}") ;;
  esac
  hits=$(search "$pattern" "${globs[@]}" | sort -t: -k1,1 -k2,2n)
  # Security and framework candidates in Java sources: ignore javadoc and comment lines (examples and warnings quote the patterns)
  if (( sec )) || [[ -n "$framework" ]] && [[ "$scope" == java ]]; then
    hits=$(awk '{ t = $0; sub(/^[^:]*:[^:]*:/, "", t) } t !~ /^[[:space:]]*(\*|\/\/|\/\*)/' <<<"$hits")
  fi
  [[ -n "$hits" ]] || continue
  if (( summary )); then
    count=$(wc -l <<<"$hits" | tr -d ' ')
    first=$(head -n1 <<<"$hits" | cut -d: -f1,2)
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$cat" "$since" "$count" "$note" "$first"
  else
    while IFS= read -r hit; do
      loc=$(cut -d: -f1,2 <<<"$hit")
      text=$(cut -d: -f3- <<<"$hit" | sed -E 's/^[[:space:]]+//' | cut -c1-160)
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$cat" "$since" "$loc" "$note" "$text"
    done <<<"$hits"
  fi
done <<<"$ordered"
