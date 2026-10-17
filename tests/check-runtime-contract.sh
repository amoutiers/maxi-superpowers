#!/usr/bin/env bash
# Exercise snapshot selection against a co-installed foreign engine.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"
RESOLVER="$ROOT/skills/using-maxi/resolve-skill.sh"
assert_file_exists "$RESOLVER" "installed skill resolver"
if [ ! -f "$RESOLVER" ]; then summary_and_exit "runtime contract checks"; fi

TMP="$(mktemp -d)"
TMP="$(cd -P "$TMP" && pwd)"
trap 'rm -rf "$TMP"' EXIT
SNAPSHOT="$TMP/installed Maxi/skills"
FOREIGN="$TMP/standalone Superpowers/skills"
mkdir -p "$SNAPSHOT/plan" "$FOREIGN/subagent-driven-development"
printf 'Maxi owner\n' > "$SNAPSHOT/plan/SKILL.md"
printf 'Foreign engine\n' > "$FOREIGN/subagent-driven-development/SKILL.md"

for skill in writing-plans subagent-driven-development finishing-a-development-branch; do
  mkdir -p "$SNAPSHOT/$skill"
  printf 'Bundled %s\n' "$skill" > "$SNAPSHOT/$skill/SKILL.md"
  actual="$(bash "$RESOLVER" "$SNAPSHOT/plan/SKILL.md" "$skill")"
  if [ "$actual" != "$SNAPSHOT/$skill/SKILL.md" ]; then
    echo "FAIL [same snapshot]: $skill resolved to $actual" >&2
    failures=$((failures + 1))
  else
    echo "OK  [same snapshot]: $skill"
  fi
done

reject() {
  local label="$1"
  shift
  if bash "$RESOLVER" "$@" > "$TMP/stdout" 2> "$TMP/stderr"; then
    echo "FAIL [$label]: resolver accepted invalid input" >&2
    failures=$((failures + 1))
  elif [ -s "$TMP/stdout" ]; then
    echo "FAIL [$label]: failed resolution emitted a usable path" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

rm "$SNAPSHOT/subagent-driven-development/SKILL.md"
reject "missing bundled skill cannot fall back to co-installed engine" "$SNAPSHOT/plan/SKILL.md" subagent-driven-development
ln -s "$FOREIGN/subagent-driven-development/SKILL.md" "$SNAPSHOT/subagent-driven-development/SKILL.md"
reject "foreign skill file symlink" "$SNAPSHOT/plan/SKILL.md" subagent-driven-development
rm "$SNAPSHOT/subagent-driven-development/SKILL.md"
rmdir "$SNAPSHOT/subagent-driven-development"
ln -s "$FOREIGN/subagent-driven-development" "$SNAPSHOT/subagent-driven-development"
reject "foreign skill directory symlink" "$SNAPSHOT/plan/SKILL.md" subagent-driven-development
reject "missing loaded owner" "$SNAPSHOT/missing/SKILL.md" writing-plans
reject "relative owner" skills/plan/SKILL.md writing-plans
reject "path traversal" "$SNAPSHOT/plan/SKILL.md" ../standalone
reject "absolute skill name" "$SNAPSHOT/plan/SKILL.md" "$FOREIGN/subagent-driven-development"
reject "missing arguments"

summary_and_exit "runtime contract checks"
