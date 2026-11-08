#!/usr/bin/env bash
# Outline of the Quarkus wiki migration guides for one hop, used to draft and refresh
# skills/java-quarkus-migrate/references/<from>-to-<to>.md.
#
# Usage: quarkus-guide-outline.sh WIKI_DIR FROM TO
#   WIKI_DIR  clone of https://github.com/quarkusio/quarkus.wiki.git
#   FROM TO   dotted Quarkus streams; prints guides with FROM < version <= TO
#
# Output, one line per section heading:
#   <version>  <level>  <auto|manual>  <heading>
# auto = heading carries :white_check_mark: (handled by quarkus update recipes).
set -euo pipefail

[[ $# -eq 3 ]] || { sed -n '2,12p' "$0" >&2; exit 2; }
wiki=$1 from=$2 to=$3

key() { awk -F. '{ printf "%d%03d\n", $1, $2 }' <<<"$1"; }
lo=$(key "$from") hi=$(key "$to")

for f in "$wiki"/Migration-Guide-[0-9]*.*; do
  v=$(basename "$f"); v=${v#Migration-Guide-}; v=${v%%[:.]a*}; v=${v%.md}
  [[ "$v" =~ ^[0-9]+\.[0-9]+$ ]] || continue
  k=$(key "$v")
  (( k > lo && k <= hi )) || continue
  printf '%s\t%s\n' "$k" "$f"
done | sort -n | while IFS=$'\t' read -r _ f; do
  v=$(basename "$f"); v=${v#Migration-Guide-}; v=${v%.*}
  awk -v v="$v" '
    /^(=|#)+ / {
      match($0, /^(=|#)+/); lvl = RLENGTH - 1
      if (lvl < 1) next
      h = substr($0, RLENGTH + 2)
      auto = (h ~ /:white_check_mark:/) ? "auto" : "manual"
      gsub(/ *:[a-z_]+: */, " ", h); sub(/ +$/, "", h)
      printf "%s\t%d\t%s\t%s\n", v, lvl, auto, h
    }' "$f"
done
