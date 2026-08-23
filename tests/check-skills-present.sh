#!/usr/bin/env bash
# Check that all current maxi-native skills exist as skills/<name>/SKILL.md
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

SKILLS_DIR="$ROOT/skills"
failures=0

MAXI_SKILLS=(
  x-adr analyze board cancel clarify constitution x-develop implement migrate-adr migrate-from-brownfield migrate-from-speckit park plan review resume revise specify tasks using-maxi
)

if [ "${#MAXI_SKILLS[@]}" -ne 19 ]; then
  echo "FAIL [maxi-native skill inventory]: expected 19 registered skills, got ${#MAXI_SKILLS[@]}" >&2
  failures=$((failures + 1))
else
  echo "OK  [maxi-native skill inventory]: 19 registered skills"
fi

for skill in "${MAXI_SKILLS[@]}"; do
  assert_file_exists "$SKILLS_DIR/$skill/SKILL.md" "$skill"
done

assert_file_exists "$ROOT/tests/check-review-boundaries.sh" "fixed review boundary check"
assert_file_exists "$SKILLS_DIR/review/design-reviewer.md" "dedicated design reviewer support file"
assert_not_grep "$SKILLS_DIR/review/SKILL.md" 'x-review\|bounded replay\|replay_continuation' "review has no obsolete handoff contract"

summary_and_exit "maxi-native skill checks"
