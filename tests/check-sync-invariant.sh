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
  vendor_skill="$vendor_dir/SKILL.md"
  skills_skill="$SKILLS/$name/SKILL.md"

  if [ ! -f "$vendor_skill" ]; then
    echo "SKIP [$name]: no SKILL.md in vendor (unusual)" >&2
    continue
  fi

  local_failures_before=$failures

  assert_file_exists "$skills_skill" "$name: skills/ copy"
  if [ "$failures" -gt "$local_failures_before" ]; then continue; fi

  assert_files_equal "$vendor_skill" "$skills_skill" "$name: SKILL.md in sync with vendor"
done

summary_and_exit "vendor sync checks"
