#!/usr/bin/env bash
# Check that all 11 maxi-native skills exist as skills/<name>/SKILL.md
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

SKILLS_DIR="$ROOT/skills"
failures=0

MAXI_SKILLS=(
  adr analyze board clarify constitution implement migrate-from-speckit plan specify tasks using-maxi
)

for skill in "${MAXI_SKILLS[@]}"; do
  assert_file_exists "$SKILLS_DIR/$skill/SKILL.md" "$skill"
done

summary_and_exit "maxi-native skill checks"
