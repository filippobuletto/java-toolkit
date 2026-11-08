#!/usr/bin/env bash
# Detect build facts of a Java project and the JDKs installed on this machine. Read-only.
#
# Usage: detect.sh [ROOT]
#
# Output: key=value lines (empty value = unknown / not found):
#   build_tool=maven|gradle|none      wrapper=mvnw|gradlew|none
#   java_release=N                    java_release_from=<property or setting that set it>
#   maven_modules=N  maven_version=   maven_compiler_plugin=  maven_surefire_plugin=  maven_failsafe_plugin=
#   gradle_dsl=kotlin|groovy          gradle_version=
#   uses=<comma list of build-blocker libraries found in build files>
#   quarkus_version=  quarkus_stream=X.Y  quarkus_platform=<BOM groupId>  quarkus_plugin=
#   quarkus_extensions=<comma list of quarkus-* artifactIds>  quarkus_cli=<installed CLI version>
#   ci_java=<comma list>  docker_java=<comma list>  pinned_java=<.sdkmanrc/.java-version/.tool-versions>
#   jdk.N=<home>                      one line per installed JDK feature release (sdkman, macOS, JAVA_HOME)
#   java_home=<JAVA_HOME>             java_home_release=N
set -euo pipefail

root="${1:-.}"
cd "$root"

out() { printf '%s=%s\n' "$1" "${2:-}"; }

# Normalize "1.8" / "VERSION_1_8" / "17" / "'21'" to a feature release number.
norm() {
  local v="${1//[\"\' ]/}"
  v="${v#JavaVersion.}"; v="${v#VERSION_}"; v="${v//_/.}"
  [[ "$v" == 1.* ]] && v="${v#1.}"
  v="${v%%.*}"
  [[ "$v" =~ ^[0-9]+$ ]] && echo "$v" || true
}

any_file() { local f; for f in "$@"; do [[ -f "$f" ]] && return 0; done; return 1; }

join() { awk 'NF && !seen[$0]++' | paste -sd, -; }

build_files() {
  find . \( -name .git -o -name target -o -name build -o -name .gradle -o -name node_modules \) -prune -o \
    -type f \( -name pom.xml -o -name '*.gradle' -o -name '*.gradle.kts' -o -name '*.versions.toml' -o -name gradle.properties \) -print 2>/dev/null
}

# --- build tool -----------------------------------------------------------------------------
tool=none
if [[ -f pom.xml ]]; then tool=maven
elif any_file build.gradle build.gradle.kts settings.gradle settings.gradle.kts; then tool=gradle; fi
out build_tool "$tool"
if [[ -f mvnw ]]; then out wrapper mvnw
elif [[ -f gradlew ]]; then out wrapper gradlew
else out wrapper none; fi

release= release_from=
q_version= q_platform= q_plugin=

# --- maven ----------------------------------------------------------------------------------
if [[ "$tool" == maven ]]; then
  pom=$(cat pom.xml)
  # prop <name>: value of <name> inside <properties>
  prop() {
    awk '/<properties>/{p=1} /<\/properties>/{p=0} p' <<<"$pom" |
      sed -nE "s|.*<$1>[[:space:]]*([^<]*[^<[:space:]])[[:space:]]*</$1>.*|\1|p" | head -n1
  }
  # resolve <value>: expand ${prop} references, up to 5 levels
  resolve() {
    local v="$1" i name
    for i in 1 2 3 4 5; do
      [[ "$v" =~ \$\{([^}]+)\} ]] || break
      name="${BASH_REMATCH[1]}"
      v="${v//\$\{$name\}/$(prop "$name")}"
    done
    echo "$v"
  }
  # plugin_conf <artifactId> <tag>: first <tag> value inside the plugin block
  plugin_conf() {
    awk -v a="<artifactId>$1</artifactId>" -v t="$2" '
      index($0, a) { p = 1 }
      p && match($0, "<" t ">[^<]*</" t ">") { s = substr($0, RSTART + length(t) + 2, RLENGTH - 2 * length(t) - 5); print s; exit }
      p && /<\/plugin>/ { exit }' <<<"$pom"
  }
  for key in maven.compiler.release plugin:release maven.compiler.source plugin:source java.version; do
    case "$key" in
      plugin:*) v=$(plugin_conf maven-compiler-plugin "${key#plugin:}") ;;
      *) v=$(prop "$key") ;;
    esac
    [[ -n "$v" ]] || continue
    v=$(norm "$(resolve "$v")")
    if [[ -n "$v" ]]; then release="$v"; release_from="${key/plugin:/maven-compiler-plugin.}"; break; fi
  done
  out maven_modules "$(grep -c '<module>' <<<"$pom" || true)"
  mv_url=$(sed -n 's/^distributionUrl=//p' .mvn/wrapper/maven-wrapper.properties 2>/dev/null || true)
  out maven_version "$(sed -nE 's|.*apache-maven-([0-9][^/-]*)-bin.*|\1|p' <<<"$mv_url")"
  for p in compiler surefire failsafe; do
    out "maven_${p}_plugin" "$(resolve "$(plugin_conf "maven-$p-plugin" version)")"
  done
  for key in quarkus.platform.version quarkus.version quarkus-plugin.version; do
    q_version=$(resolve "$(prop "$key")"); [[ -n "$q_version" ]] && break
  done
  q_platform=$(resolve "$(prop quarkus.platform.group-id)")
  q_plugin=$(resolve "$(plugin_conf quarkus-maven-plugin version)")
fi

# --- gradle ---------------------------------------------------------------------------------
if [[ "$tool" == gradle ]]; then
  if any_file build.gradle.kts settings.gradle.kts; then out gradle_dsl kotlin; else out gradle_dsl groovy; fi
  url=$(sed -n 's/^distributionUrl=//p' gradle/wrapper/gradle-wrapper.properties 2>/dev/null || true)
  out gradle_version "$(sed -nE 's#.*gradle-([0-9][^-]*)-(bin|all)\.zip.*#\1#p' <<<"$url")"
  gfiles=$(for x in build.gradle build.gradle.kts; do [[ -f "$x" ]] && echo "$x"; done || true)
  if [[ -n "$gfiles" ]]; then
    g=$(cat $gfiles)
    v=$(sed -nE 's/.*JavaLanguageVersion\.of\(([0-9]+)\).*/\1/p; s/.*jvmToolchain\(([0-9]+)\).*/\1/p' <<<"$g" | head -n1)
    if [[ -n "$v" ]]; then release="$v"; release_from=toolchain
    else
      v=$(sed -nE 's/.*options\.release(\.set)?[[:space:]]*[(=][[:space:]]*([0-9]+).*/\2/p' <<<"$g" | head -n1)
      if [[ -n "$v" ]]; then release="$v"; release_from=options.release
      else
        v=$(sed -nE 's/.*sourceCompatibility[[:space:]]*=[[:space:]]*([A-Za-z_.]*[0-9][0-9_.]*["'"'"']?).*/\1/p' <<<"$g" | head -n1)
        [[ -n "$v" ]] && { release=$(norm "$v"); release_from=sourceCompatibility; }
      fi
    fi
  fi
  gprop() { [[ -f gradle.properties ]] && sed -nE "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*([^[:space:]]+).*/\1/p" gradle.properties | head -n1 || true; }
  q_version=$(gprop quarkusPlatformVersion)
  q_platform=$(gprop quarkusPlatformGroupId)
  q_plugin=$(gprop quarkusPluginVersion)
  if [[ -z "$q_plugin" && -n "$gfiles" ]]; then
    q_plugin=$(sed -nE 's/.*id[[:space:]]*\(?[[:space:]]*["'"'"']io\.quarkus["'"'"'][[:space:]]*\)?[[:space:]]*version[[:space:]]*["'"'"']([^"'"'"']+).*/\1/p' <<<"$g" | head -n1)
  fi
  q_version=${q_version:-$q_plugin}
fi

out java_release "$release"
out java_release_from "$release_from"

# --- build-blocker libraries ----------------------------------------------------------------
files=$(build_files)
uses=""
if [[ -n "$files" ]]; then
  for lib in lombok mapstruct mockito byte-buddy jacoco errorprone kotlin aspectj spotbugs; do
    pat="$lib"
    [[ "$lib" == errorprone ]] && pat='errorprone|error_prone'
    [[ "$lib" == kotlin ]] && pat='kotlin-maven-plugin|org\.jetbrains\.kotlin|kotlin\('
    # shellcheck disable=SC2086
    if grep -qE "$pat" $files 2>/dev/null; then uses="$uses,$lib"; fi
  done
fi
out uses "${uses#,}"

# --- Quarkus --------------------------------------------------------------------------------
out quarkus_version "$q_version"
out quarkus_stream "$(sed -nE 's/^([0-9]+\.[0-9]+).*/\1/p' <<<"$q_version")"
out quarkus_platform "$q_platform"
out quarkus_plugin "$q_plugin"
ext=""
if [[ -n "$files" ]]; then
  # shellcheck disable=SC2086
  ext=$(cat $files 2>/dev/null |
    sed -nE 's#.*<artifactId>(quarkus-[a-z0-9-]+)</artifactId>.*#\1#p; s#.*["'"'"'][a-z0-9.]+:(quarkus-[a-z0-9-]+)[:"'"'"'].*#\1#p' |
    { grep -vE -- '-bom$|^quarkus-(maven|gradle)-plugin$' || true; } | sort -u | join)
fi
out quarkus_extensions "$ext"
q_cli=""
command -v quarkus >/dev/null 2>&1 && q_cli=$(quarkus --version 2>/dev/null | head -n1 || true)
out quarkus_cli "$q_cli"

# --- CI, containers, pinned JDK -------------------------------------------------------------
ci=$( { { cat .github/workflows/*.y*ml 2>/dev/null || true; } | sed -nE "s/.*java-version:[[:space:]]*['\"]?([0-9.]+).*/\1/p"
        { cat .gitlab-ci.yml Jenkinsfile azure-pipelines.yml 2>/dev/null || true; } |
          sed -nE 's/.*(jdk|temurin|openjdk|corretto|zulu|java)[-:]?([0-9]+).*/\2/p'; } | while read -r v; do norm "$v"; done | join)
out ci_java "$ci"
docker=$(find . \( -name .git -o -name target -o -name node_modules \) -prune -o -type f \( -name 'Dockerfile*' -o -name '*.Dockerfile' -o -name 'Containerfile' \) -print 2>/dev/null |
  while read -r f; do
    sed -nE 's/^[[:space:]]*[Ff][Rr][Oo][Mm][[:space:]]+([^[:space:]]+).*/\1/p' "$f"
  done | sed -nE 's/.*(temurin|openjdk|jdk|jre|corretto|zulu|java|sapmachine|semeru|liberica)[^:]*:([0-9]+).*/\2/p; s/.*distroless\/java([0-9]+).*/\1/p' | join)
out docker_java "$docker"
pinned=$( { sed -nE 's/^java=([0-9.]+).*/\1/p' .sdkmanrc 2>/dev/null || true
            sed -nE 's/^([a-z-]*-)?([0-9.]+).*/\2/p' .java-version 2>/dev/null || true
            sed -nE 's/^java[[:space:]]+([a-z-]*-)?([0-9.]+).*/\2/p' .tool-versions 2>/dev/null || true; } | while read -r v; do norm "$v"; done | join)
out pinned_java "$pinned"

# --- installed JDKs -------------------------------------------------------------------------
release_of() { sed -nE 's/^JAVA_VERSION="([^"]+)".*/\1/p' "$1/release" 2>/dev/null | head -n1; }
{
  for h in "$HOME"/.sdkman/candidates/java/* /Library/Java/JavaVirtualMachines/*/Contents/Home /usr/lib/jvm/*; do
    [[ -d "$h" && ! -L "$h" && -f "$h/release" ]] || continue
    v=$(norm "$(release_of "$h")")
    [[ -n "$v" ]] && printf '%s\t%s\t%s\n' "$v" "$(release_of "$h")" "$h"
  done
} | sort -t$'\t' -k1,1n -k2,2r | awk -F'\t' '!seen[$1]++' | while IFS=$'\t' read -r v _ h; do out "jdk.$v" "$h"; done
out java_home "${JAVA_HOME:-}"
out java_home_release "$( [[ -n "${JAVA_HOME:-}" ]] && norm "$(release_of "$JAVA_HOME")" || true)"
