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

GLOBAL_CONSTRAINT_DOCS=(
  "$ROOT/docs/pipeline-flow.md"
  "$ROOT/docs/delegation-map.md"
  "$ROOT/skills/using-maxi/SKILL.md"
  "$ROOT/AGENTS.md"
  "$ROOT/docs/architecture.md"
)
GLOBAL_CONSTRAINT_SENTENCE='Every newly written `plan.md` carries exactly one `Global Constraints` section containing only applicable durable cross-task constraints from the spec and constitution; transient execution state and individual mutation authority are excluded, while a durable rule requiring fresh authorization is allowed.'

ADR_POLICY_DOCS=(
  "$ROOT/README.md"
  "$ROOT/docs/maxi/constitution.md"
  "$ROOT/docs/pipeline-flow.md"
  "$ROOT/docs/delegation-map.md"
  "$ROOT/skills/using-maxi/SKILL.md"
  "$ROOT/AGENTS.md"
  "$ROOT/docs/architecture.md"
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

for doc in "${GLOBAL_CONSTRAINT_DOCS[@]}"; do
  label="$(basename "$doc")"
  assert_grep "$doc" 'complete-body `maxi-v2` projections' "$label documents v2 execution"
  assert_grep "$doc" 'immutable `maxi-v1` files remain verifiable historical predecessors' "$label preserves historical v1 evidence"
  expected="$GLOBAL_CONSTRAINT_SENTENCE"
  if [ "$doc" = "$ROOT/docs/pipeline-flow.md" ]; then
    expected="- $GLOBAL_CONSTRAINT_SENTENCE"
  fi
  if ! grep -Fqx -- "$expected" "$doc"; then
    echo "FAIL [$label documents durable global constraints]" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label documents durable global constraints]"
  fi
done

for doc in "${ADR_POLICY_DOCS[@]}"; do
  label="$(basename "$doc")"
  assert_grep "$doc" 'direct `spec` link' "$label documents the direct ADR spec link"
  assert_grep "$doc" 'agent-proposed active-spec amendment' "$label documents active-spec amendments"
  assert_grep "$doc" 'initial active lifecycle' "$label limits amendments to the initial lifecycle"
  assert_grep "$doc" 'monotone.*watermark' "$label documents the permanent reopening watermark"
  assert_grep "$doc" 'reopened_from: done' "$label names the reopening watermark"
  assert_grep "$doc" 'closed-spec supersession' "$label documents closed-spec supersession"
done

assert_grep "$ROOT/README.md" 'direct `spec` link equals the current active spec slug' "README.md routes amendments through the current active spec slug"

for doc in "$ROOT/AGENTS.md" "$ROOT/docs/pipeline-flow.md" "$ROOT/docs/delegation-map.md" "$ROOT/docs/architecture.md" "$ROOT/skills/using-maxi/SKILL.md"; do
  assert_grep "$doc" 'maxi-design-review-v1' "$(basename "$doc"): versioned design approval"
  assert_grep "$doc" 'review_inputs_sha256' "$(basename "$doc"): decision-input bound gates"
  assert_grep "$doc" 'Candidate-based stamping' "$(basename "$doc"): atomic candidate publication"
done
summary_and_exit "skill-count consistency checks"
