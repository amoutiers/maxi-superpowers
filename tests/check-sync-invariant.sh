#!/usr/bin/env bash
# Verifies vendor/superpowers/skills/ and skills/ are in sync for all vendored skills.
# Fails if any vendored skill is missing from skills/ or has a different SKILL.md.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
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

  if [ ! -f "$skills_skill" ]; then
    echo "FAIL [$name]: missing from skills/ — run scripts/sync-superpowers.sh" >&2
    failures=$((failures + 1))
    continue
  fi

  if ! diff -q "$vendor_skill" "$skills_skill" > /dev/null 2>&1; then
    echo "FAIL [$name]: SKILL.md differs from vendor — run scripts/sync-superpowers.sh" >&2
    failures=$((failures + 1))
    continue
  fi

  echo "OK  [$name]"
done

if [ "$failures" -gt 0 ]; then
  echo ""
  echo "FAILED: $failures vendored skill(s) out of sync" >&2
  exit 1
fi

echo ""
echo "All vendored skills are in sync."
