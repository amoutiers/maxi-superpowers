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

assert_grep "$ROOT/AGENTS.md"            "$maxi_count maxi-native skills" "AGENTS.md states $maxi_count maxi-native skills"
assert_grep "$ROOT/docs/architecture.md" "$maxi_count maxi-native skills" "architecture.md states $maxi_count maxi-native skills"
assert_grep "$ROOT/README.md"             "$maxi_count maxi-native skills" "README.md states $maxi_count maxi-native skills"

# Every maxi-native skill must appear in the architecture.md skills/ tree.
for d in "$ROOT"/skills/*/; do
  name="$(basename "$d")"
  [ -d "$ROOT/vendor/superpowers/skills/$name" ] && continue
  assert_grep "$ROOT/docs/architecture.md" "$name/" "architecture.md tree lists $name/"
done

# Pipeline changes must stay coherent across every Mandatory Sync 5 surface.
SYNC_DOCS=(
  "$ROOT/docs/pipeline-flow.md"
  "$ROOT/docs/delegation-map.md"
  "$ROOT/skills/using-maxi/SKILL.md"
  "$ROOT/AGENTS.md"
  "$ROOT/docs/architecture.md"
)

for doc in "${SYNC_DOCS[@]}"; do
  label="$(basename "$doc")"
  assert_grep "$doc" '10-state FSM remains unchanged' "$label states the unchanged FSM"
  assert_grep "$doc" 'reviews/spec-review.md' "$label documents the specification review handoff"
  assert_grep "$doc" 'reviews/plan-review.md' "$label documents the plan review handoff"
  assert_grep "$doc" 'gates, not statuses or automatic replay phases' "$label distinguishes handoff gates from pipeline state"
  assert_grep "$doc" 'persisted and versioned' "$label documents persisted versioned reviews"
  assert_grep "$doc" 'x-review' "$label registers x-review"
  assert_grep "$doc" 'skills/revise/replay-plan.sh' "$label documents the bounded replay planner"
  assert_grep "$doc" 'read-only' "$label documents the planner as read-only"
  assert_grep "$doc" 'exceptional `specified` rollback' "$label documents the source-spec-gap rollback"
  assert_grep "$doc" 'owner-managed plan correction' "$label documents the explicit plan correction entry point"
  assert_grep "$doc" 'returns only to `planned`' "$label documents the canonical plan correction return status"
  assert_grep "$doc" 'owner-managed tasks correction' "$label documents the explicit tasks correction entry point"
  assert_grep "$doc" 'returns only to `tasked`' "$label documents the canonical tasks correction return status"
  assert_grep "$doc" 'replay_continuation: tasks@<current-plan-revision>' "$label documents the persisted plan continuation marker"
  assert_grep "$doc" 'no-write resume presenter' "$label documents tasks as the no-write continuation presenter"
  assert_grep "$doc" 'resume-current-review' "$label documents the current-review replay mode"
  assert_grep "$doc" 'fresh literal `yes`' "$label documents renewed consent after redisplay"
  assert_grep "$doc" 'marker-bound approved plan review.*predecessor review revision' "$label documents x-review's immediate marker-bound planner call"
  assert_grep "$doc" 'never executes a phase or obtains consent' "$label keeps x-review out of execution and consent"
  assert_grep "$doc" 'only the later no-write resume presenter' "$label assigns later redisplay to tasks only"
  assert_grep "$doc" 'Only new specs created through the normal forward pipeline' "$label documents the future-only boundary"
  assert_grep "$doc" 'For an unmarked root, plan and tasks use the ordinary pipeline: no review record, x-review handoff, review provenance, review reporting, or replay planner is required' "$label excludes review obligations from unmarked roots"
  assert_grep "$doc" 'never creates or writes `workflow.md` or `.maxi-ops`' "$label excludes workflow-ledger state"
done

# README is the public integration inventory even though it is not one of the
# five sync-locked pipeline files.
assert_grep "$ROOT/README.md" '10-state FSM remains unchanged' "README states the unchanged FSM"
assert_grep "$ROOT/README.md" 'reviews/spec-review.md' "README documents the specification review handoff"
assert_grep "$ROOT/README.md" 'reviews/plan-review.md' "README documents the plan review handoff"
assert_grep "$ROOT/README.md" 'gates, not statuses or automatic replay phases' "README distinguishes handoff gates from pipeline state"
assert_grep "$ROOT/README.md" 'persisted and versioned' "README documents persisted versioned reviews"
assert_grep "$ROOT/README.md" 'x-review' "README registers x-review"
assert_grep "$ROOT/README.md" 'skills/revise/replay-plan.sh' "README documents the bounded replay planner"
assert_grep "$ROOT/README.md" 'read-only' "README documents the planner as read-only"
assert_grep "$ROOT/README.md" 'exceptional `specified` rollback' "README documents the source-spec-gap rollback"
assert_grep "$ROOT/README.md" 'owner-managed plan correction' "README documents the explicit plan correction entry point"
assert_grep "$ROOT/README.md" 'returns only to `planned`' "README documents the canonical plan correction return status"
assert_grep "$ROOT/README.md" 'owner-managed tasks correction' "README documents the explicit tasks correction entry point"
assert_grep "$ROOT/README.md" 'returns only to `tasked`' "README documents the canonical tasks correction return status"
assert_grep "$ROOT/README.md" 'replay_continuation: tasks@<current-plan-revision>' "README documents the persisted plan continuation marker"
assert_grep "$ROOT/README.md" 'no-write resume presenter' "README documents tasks as the no-write continuation presenter"
assert_grep "$ROOT/README.md" 'resume-current-review' "README documents the current-review replay mode"
assert_grep "$ROOT/README.md" 'fresh literal `yes`' "README documents renewed consent after redisplay"
assert_grep "$ROOT/README.md" 'marker-bound approved plan review.*predecessor review revision' "README documents x-review's immediate marker-bound planner call"
assert_grep "$ROOT/README.md" 'never executes a phase or obtains consent' "README keeps x-review out of execution and consent"
assert_grep "$ROOT/README.md" 'only the later no-write resume presenter' "README assigns later redisplay to tasks only"
assert_grep "$ROOT/README.md" 'Only new specs created through the normal forward pipeline' "README documents the future-only boundary"
assert_grep "$ROOT/README.md" 'For an unmarked root, plan and tasks use the ordinary pipeline: no review record, x-review handoff, review provenance, review reporting, or replay planner is required' "README excludes review obligations from unmarked roots"
assert_grep "$ROOT/README.md" 'never creates or writes `workflow.md` or `.maxi-ops`' "README excludes workflow-ledger state"

# Task 7/8 contract details are public behavior, not implementation trivia.
for doc in "${SYNC_DOCS[@]}" "$ROOT/README.md"; do
  label="$(basename "$doc")"
  assert_grep "$doc" 'replay_contract: bounded-v1' "$label names the exact future-only eligibility marker"
  assert_grep "$doc" 'only `/maxi:specify` writes this marker' "$label assigns marker ownership to specify"
  assert_grep "$doc" 'UNSUPPORTED_LEGACY' "$label documents unmarked-spec rejection"
  assert_grep "$doc" 'reviewed_sha256' "$label documents the structural review digest"
  assert_grep "$doc" 'omits only root-frontmatter `status:` and `updated:`' "$label defines the canonical structural projection"
  assert_grep "$doc" 'exact ten-field review envelope' "$label documents the complete owner-gate envelope"
  assert_grep "$doc" 'reviewer_context_matches_harness' "$label names the harness-binding review field"
  assert_grep "$doc" 'positive record and reviewed revisions' "$label requires positive review revisions"
  assert_grep "$doc" 'exactly one mapped direct input' "$label requires the mapped review input"
  assert_grep "$doc" 'writer equals reviewer and appears in contributors' "$label binds review writer and contributor provenance"
  assert_grep "$doc" 'replay_continuation: clarify@<current-spec-revision>' "$label documents persisted clarify continuation"
  assert_grep "$doc" 'resume-current-source' "$label documents source continuation resume"
  assert_grep "$doc" 'resume-current-source` is legal only' "$label confines source continuation resume"
  assert_grep "$doc" 'replay_continuation: plan@<current-spec-revision>' "$label documents persisted plan continuation"
  assert_grep "$doc" 'spec review.*resume-current-review' "$label documents plan resume from the current spec review"
  assert_grep "$doc" 'plan review.*resume-current-review' "$label documents tasks resume from the current plan review"
  assert_grep "$doc" 'resume-current-review` accepts exactly two combinations' "$label confines review continuation resume"
  assert_grep "$doc" 'every transitive `derived_from` ancestor' "$label requires current transitive ancestry"
  assert_grep "$doc" 'stale `spec.md`, support artifact, or specification review' "$label documents plan-resume ancestor rejection"
  assert_grep "$doc" 'before any continuation output or write' "$label documents stale-ancestor fail-closed behavior"
done

assert_grep "$ROOT/AGENTS.md" 'check-x-review.sh' "AGENTS.md lists the targeted x-review fast check"
assert_grep "$ROOT/tests/run-all.sh" 'check-x-review.sh' "run-all.sh invokes the targeted x-review fast check"
assert_grep "$ROOT/docs/pipeline-flow.md" '^    REVIEW -\.->|"marker-bound plan review\\nwritten, then display only"| REPLAY$' "pipeline flow routes immediate marker-bound display from x-review"
assert_grep "$ROOT/docs/pipeline-flow.md" '^    TASKS -\.->|"marker-bound resume\\nno write before yes"| REPLAY$' "pipeline flow routes later marker-bound redisplay from tasks"
assert_not_grep "$ROOT/docs/pipeline-flow.md" '^    PLAN_REVIEW -\.->|"marker-bound plan review\\nwritten, then display only"| REPLAY$' "pipeline flow rejects obsolete plan-review-to-replay route"
assert_grep "$ROOT/skills/using-maxi/SKILL.md" '/maxi:plan.*`clarified`; for marker-bound roots, current approved' "using-maxi plan table preserves the unmarked status-only path"
assert_grep "$ROOT/skills/using-maxi/SKILL.md" '/maxi:tasks.*`planned`; for marker-bound roots, current approved' "using-maxi tasks table preserves the unmarked status-only path"
assert_grep "$ROOT/docs/delegation-map.md" '`plan`.*`clarified`; for marker-bound roots, current approved' "delegation map plan table preserves the unmarked status-only path"
assert_grep "$ROOT/docs/delegation-map.md" '`tasks`.*`planned`; for marker-bound roots, current approved' "delegation map tasks table preserves the unmarked status-only path"

# The retained original 0019 support artifacts are archival only. Their former
# workflow-ledger and artifact-graph design cannot prescribe the rewritten scope.
for legacy_artifact in \
  "$ROOT/docs/maxi/specs/0019-artifact-analysis-convergence/research.md" \
  "$ROOT/docs/maxi/specs/0019-artifact-analysis-convergence/data-model.md" \
  "$ROOT/docs/maxi/specs/0019-artifact-analysis-convergence/contracts/validator-cli.md"; do
  legacy_label="$(basename "$legacy_artifact")"
  assert_grep "$legacy_artifact" '^> \*\*Superseded historical artifact\.\*\*$' "$legacy_label is explicitly superseded"
  assert_grep "$legacy_artifact" '^> The content below is archival only and does not prescribe active Maxi behavior\.$' "$legacy_label has no active authority"
  assert_grep "$legacy_artifact" '^> It does not require creating or writing `workflow\.md`, `\.maxi-ops`, `workflow-ledger\.sh`, or `x-artifact-graph`\.$' "$legacy_label cannot revive the removed framework"
done

summary_and_exit "skill-count consistency checks"
