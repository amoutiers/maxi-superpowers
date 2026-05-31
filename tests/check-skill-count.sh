#!/usr/bin/env bash
# Verifies the maxi-native skill count is consistent between the filesystem and the docs.
# Maxi-native = a skills/<name>/ directory with NO counterpart in vendor/superpowers/skills/.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

# Derive the maxi-native count from reality (no hard-coded list to drift).
maxi_count=0
for d in "$ROOT"/skills/*/; do
  name="$(basename "$d")"
  if [ ! -d "$ROOT/vendor/superpowers/skills/$name" ]; then
    maxi_count=$((maxi_count + 1))
  fi
done

if [ "$maxi_count" -eq 0 ]; then
  echo "FAIL [skill-count]: derived maxi-native count is 0 — is vendor/superpowers/skills/ present?" >&2
  failures=$((failures + 1))
fi

assert_grep "$ROOT/CLAUDE.md"            "$maxi_count maxi-native skills" "CLAUDE.md states $maxi_count maxi-native skills"
assert_grep "$ROOT/docs/architecture.md" "$maxi_count maxi-native skills" "architecture.md states $maxi_count maxi-native skills"

# Every maxi-native skill must appear in the architecture.md skills/ tree.
for d in "$ROOT"/skills/*/; do
  name="$(basename "$d")"
  [ -d "$ROOT/vendor/superpowers/skills/$name" ] && continue
  assert_grep "$ROOT/docs/architecture.md" "$name/" "architecture.md tree lists $name/"
done

summary_and_exit "skill-count consistency checks"
