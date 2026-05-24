#!/usr/bin/env bash
# Verifies vendor/superpowers/skills/ and skills/ are in sync for all vendored skills.
# Fails if any vendored skill is missing from skills/ or has a different SKILL.md.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

VENDOR="$ROOT/vendor/superpowers/skills"
SKILLS="$ROOT/skills"
failures=0

if [ ! -d "$VENDOR" ]; then
  echo "ERROR: $VENDOR does not exist — run 'git subtree add' first" >&2
  exit 1
fi

for vendor_dir in "$VENDOR"/*/; do
  name=$(basename "$vendor_dir")

  if [ ! -f "$vendor_dir/SKILL.md" ]; then
    echo "SKIP [$name]: no SKILL.md in vendor (unusual)" >&2
    continue
  fi

  skills_dir="$SKILLS/$name"

  if [ ! -d "$skills_dir" ]; then
    echo "FAIL [$name: skills/ copy]: directory missing" >&2
    failures=$((failures + 1))
    continue
  fi

  diff_output=$(diff -r "$vendor_dir" "$skills_dir" 2>&1 || true)
  if [ -n "$diff_output" ]; then
    echo "FAIL [$name: skill dir in sync with vendor]:" >&2
    echo "$diff_output" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$name: skill dir in sync with vendor]"
  fi
done

summary_and_exit "vendor sync checks"
