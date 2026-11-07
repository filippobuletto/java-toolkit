#!/usr/bin/env bash
# Compile every Java snippet in skills/**/references/*.md that is preceded by a marker line:
#
#   <!-- compile: jdk=N [fails-below] [preview] [raw] -->
#
#   jdk=N        must compile with javac --release N
#   fails-below  must NOT compile with --release N-1 (proves the feature's minimum JDK)
#   preview      compile with --enable-preview; needs an installed JDK whose feature release is exactly N
#   raw          compile the block as Main.java unchanged (compact source files); default wraps the block
#                in `class Snippet { ... }` with its import lines hoisted
#
# javac comes from the installed JDKs reported by skills/java-upgrade/scripts/detect.sh: the smallest
# feature release >= max(N, 11). No JDK is downloaded.
# Usage: compile-snippets.sh [file.md...]
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
work=$(mktemp -d /private/tmp/java-upgrade-snippets.XXXX)
pass=0 fail=0 skip=0

jdks=$(bash "$ROOT/skills/java-upgrade/scripts/detect.sh" "$work" | sed -nE 's/^jdk\.([0-9]+)=(.*)/\1 \2/p')

# javac_for <N> <exact:0|1>: path of javac to use, empty when none installed
javac_for() {
  local want="$1" exact="$2" min v h
  min=$(( want > 11 ? want : 11 ))
  while read -r v h; do
    [[ -n "$v" ]] || continue
    if (( exact )); then (( v == want )) && { echo "$h/bin/javac"; return; }
    else (( v >= min )) && { echo "$h/bin/javac"; return; }; fi
  done <<<"$jdks"
}

# compile <javac> <release> <preview:0|1> <dir> <file>: exit status of javac
compile() {
  local args=(--release "$2" -proc:none -nowarn -Xlint:none -d "$4/out")
  (( $3 )) && args+=(--enable-preview)
  "$1" "${args[@]}" "$5" >"$4/javac.log" 2>&1
}

files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
  while IFS= read -r f; do files+=("$f"); done < <(find "$ROOT/skills" -path '*/references/*.md' | sort)
fi

for md in "${files[@]}"; do
  rel="${md#"$ROOT"/}"
  n=0
  while IFS=$'\t' read -r line opts; do
    n=$((n + 1))
    dir="$work/$(basename "$md" .md)-$line"; mkdir -p "$dir/out"
    awk -v start="$line" 'NR > start && /^```/ { if (inside) exit; inside = 1; next } inside' "$md" > "$dir/block.txt"
    jdk=$(sed -nE 's/.*jdk=([0-9]+).*/\1/p' <<<"$opts")
    preview=0; [[ "$opts" == *preview* ]] && preview=1
    if [[ "$opts" == *raw* ]]; then
      src="$dir/Main.java"; cp "$dir/block.txt" "$src"
    else
      src="$dir/Snippet.java"
      { grep -E '^import ' "$dir/block.txt"; echo 'class Snippet {'; grep -vE '^(import|package) ' "$dir/block.txt"; echo '}'; } > "$src"
    fi
    javac=$(javac_for "$jdk" "$preview")
    name="$rel:$line (jdk=$jdk${opts//jdk=$jdk/})"
    if [[ -z "$javac" ]]; then skip=$((skip + 1)); echo "SKIP $name: no installed JDK"; continue; fi
    if compile "$javac" "$jdk" "$preview" "$dir" "$src"; then
      pass=$((pass + 1)); echo "ok   $name"
    else
      fail=$((fail + 1)); echo "FAIL $name"; sed 's/^/     /' "$dir/javac.log" | head -n 15
      continue
    fi
    if [[ "$opts" == *fails-below* ]]; then
      if compile "$javac" "$((jdk - 1))" 0 "$dir" "$src"; then
        fail=$((fail + 1)); echo "FAIL $name: also compiles with --release $((jdk - 1))"
      else
        pass=$((pass + 1)); echo "ok   $name: rejected by --release $((jdk - 1))"
      fi
    fi
  done < <(grep -nE '^<!-- compile: .* -->$' "$md" | sed -E 's/^([0-9]+):<!-- compile: (.*) -->$/\1\t\2/')
  (( n )) || echo "--   $rel: no compile markers"
done

echo
echo "$pass passed, $fail failed, $skip skipped"
[[ $fail -eq 0 ]]
