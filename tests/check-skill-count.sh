#!/usr/bin/env bash
# Verifies the Maxi-native inventory and fixed review-boundary documentation.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

maxi_count=0
for d in "$ROOT"/skills/*/; do
  name="$(basename "$d")"
  [ -d "$ROOT/vendor/superpowers/skills/$name" ] || maxi_count=$((maxi_count + 1))
done

if [ "$maxi_count" -ne 19 ]; then
  echo "FAIL [maxi-native skill inventory]: expected 19, got $maxi_count" >&2
  failures=$((failures + 1))
else
  echo "OK  [maxi-native skill inventory]: 19 registered skills"
fi

for d in "$ROOT"/skills/*/; do
  name="$(basename "$d")"
  [ -d "$ROOT/vendor/superpowers/skills/$name" ] && continue
  assert_grep "$ROOT/docs/architecture.md" "$name/" "architecture tree lists $name/"
done

SYNC_DOCS=(
  "$ROOT/docs/pipeline-flow.md"
  "$ROOT/docs/delegation-map.md"
  "$ROOT/skills/using-maxi/SKILL.md"
  "$ROOT/AGENTS.md"
  "$ROOT/docs/architecture.md"
  "$ROOT/README.md"
)

for doc in "${SYNC_DOCS[@]}"; do
  label="$(basename "$doc")"
  assert_grep "$doc" "$maxi_count.*13 user-facing.*2 internal.*1 session.*3 migration skills" "$label has the native-skill breakdown"
  assert_grep "$doc" '10-state FSM remains unchanged' "$label keeps the FSM"
  assert_grep "$doc" 'design review' "$label documents the design boundary"
  assert_grep "$doc" 'readiness review' "$label documents the readiness boundary"
  assert_grep "$doc" 'final implementation review' "$label documents the final boundary"
  assert_grep "$doc" 'Upstream SDD owns task review, fix rounds, and the final implementation review' "$label preserves SDD final-review ownership"
  assert_not_grep "$doc" 'bounded replay\|replay_contract\|replay_continuation\|x-review\|reviews/spec-review.md\|reviews/plan-review.md' "$label excludes obsolete review mechanics"
done

summary_and_exit "skill-count consistency checks"
