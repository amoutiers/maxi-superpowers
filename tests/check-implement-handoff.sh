#!/usr/bin/env bash
# Instruction-contract coverage for the Maxi implement/x-develop ownership boundary.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
IMPLEMENT="$ROOT/skills/implement/SKILL.md"
DEVELOP="$ROOT/skills/x-develop/SKILL.md"

fail_contract() {
  echo "FAIL [implement handoff contract]: $1" >&2
  exit 1
}

require_literal() {
  local file="$1" literal="$2" label="$3"
  grep -Fq "$literal" "$file" || fail_contract "$label"
}

assert_grep() {
  local file="$1" pattern="$2" label="$3"
  grep -q "$pattern" "$file" || fail_contract "$label"
}

for file in "$IMPLEMENT" "$DEVELOP"; do
  [ -f "$file" ] || fail_contract "missing $(basename "$(dirname "$file")")/SKILL.md"
done

# implement owns the pipeline paths and terminal status, not incremental execution.
require_literal "$IMPLEMENT" 'Pass the exact canonical `spec.md`, `plan.md`, and `tasks.md` paths to `/maxi:x-develop`.' 'implement does not pass exact artifact paths'
require_literal "$IMPLEMENT" 'Accept only the exact `READY_TO_FINISH` token' 'implement accepts a weaker result'
require_literal "$IMPLEMENT" 'Do not tick task checkboxes in this skill' 'implement still owns incremental checkboxes'
require_literal "$IMPLEMENT" 'Do not dispatch another code review' 'implement still owns a duplicate final review'
require_literal "$IMPLEMENT" 'retain the returned projection lineage and aggregated `Ruling:` lines until branch/worktree completion' 'implement drops returned SDD evidence'
require_literal "$IMPLEMENT" 'invoke `superpowers:finishing-a-development-branch` only after the `done` write is persisted' 'branch finishing is not after done'
assert_grep "$ROOT/skills/implement/SKILL.md" \
  'readiness-contract.sh` `verify`' \
  "implement verifies readiness evidence"
assert_grep "$ROOT/skills/implement/SKILL.md" \
  'before any write or `/maxi:x-develop` dispatch' \
  "readiness verification is pre-write"
require_literal "$IMPLEMENT" 'exact loaded `analyze/SKILL.md`' 'implement does not bind the verifier to the loaded analyze skill'
assert_grep "$IMPLEMENT" 'canonical absolute.*`readiness_contract`' 'implement does not canonicalize the installed verifier path'
require_literal "$IMPLEMENT" 'regular, non-symlink file' 'implement accepts an unsafe installed verifier'
if [ "$(grep -Fc 'bash "$readiness_contract" verify \' "$IMPLEMENT")" -ne 2 ]; then
  fail_contract 'every implement readiness verification does not use the bound installed verifier'
fi
if grep -Fq 'bash skills/analyze/readiness-contract.sh' "$IMPLEMENT"; then
  fail_contract 'implement retains a project-relative verifier fallback'
fi

# x-develop owns one projection/ledger/review lifecycle and returns before finishing.
require_literal "$DEVELOP" '`project-tasks.sh`' 'x-develop does not create or verify a projection'
require_literal "$DEVELOP" '`reconcile-tasks.sh`' 'x-develop does not reconcile checkboxes'
require_literal "$DEVELOP" '`record-terminal.sh`' 'x-develop does not persist the terminal receipt'
require_literal "$DEVELOP" '`result-contract.sh`' 'x-develop does not validate the terminal result'
require_literal "$DEVELOP" 'Project each canonical `TNNN` once in tasks-file order for every root, ignoring replay metadata and historical plan annotations.' 'ordinary task projection is not universal'
require_literal "$DEVELOP" 'Recover a predecessor only from the validated active-projection pointer.' 'predecessor recovery is not fail closed'
require_literal "$DEVELOP" 'Reconcile the existing ledger before any resumed dispatch.' 'resume reconciliation is missing'
require_literal "$DEVELOP" 'Pass the printed canonical absolute projection path verbatim to every upstream SDD helper.' 'canonical projection identity is not preserved'
require_literal "$DEVELOP" 'Change directory to the bound physical Git worktree before every upstream SDD helper call.' 'foreign-cwd binding is missing'
require_literal "$DEVELOP" 'Use upstream SDD without fix-loop overrides.' 'upstream fix loop is still overridden'
require_literal "$DEVELOP" 'final-review-only' 'all-checked final review path is missing'
require_literal "$DEVELOP" 'Intercept immediately before upstream workspace deletion and `superpowers:finishing-a-development-branch`.' 'finish boundary is not intercepted'
require_literal "$DEVELOP" 'Return the projection lineage and aggregated `Ruling:` lines only together with `READY_TO_FINISH`.' 'result evidence contract is missing'
require_literal "$DEVELOP" 'return without a success token' 'blocked result can look successful'
require_literal "$DEVELOP" 'A checkbox alone never acquits a lineage task.' 'lineage can trust a checkbox without predecessor completion'
require_literal "$DEVELOP" 'Only canonical annotated upstream completion records acquit tasks; bare or malformed completion lines fail closed.' 'x-develop completion grammar does not match upstream'
require_literal "$DEVELOP" 'Reconstruct the canonical projection bytes from the bound spec, plan, tasks, and validated selection/lineage ledgers' 'projection verification can self-attest from stored bytes'
require_literal "$DEVELOP" 'Before any task dispatch, persist the exact initial selected-TNNN set in the ordinary SDD ledger' 'initial task selection is not anchored before dispatch'
require_literal "$DEVELOP" 'A missing, malformed, duplicate, or mismatched selection anchor fails closed.' 'invalid selection anchors can authorize projection reuse'
require_literal "$DEVELOP" "Every projection's exact distributed bytes are SHA-256-bound by its ordinary SDD ledger" 'projection bytes are not anchored outside the projection'
require_literal "$DEVELOP" 'Removing an anchored incomplete `TNNN` during structural correction fails before successor creation and leaves the active-projection pointer unchanged.' 'structural correction can erase an incomplete anchored task'
require_literal "$DEVELOP" 'Complete ledger lines containing `Ruling:` are preserved byte-for-byte in lineage order and hash-bound by the terminal receipt.' 'ruling evidence is not preserved and hash-bound'
require_literal "$DEVELOP" 'normalize every accepted backtick fence delimiter to column zero' 'projection does not preserve upstream task-brief extraction'
require_literal "$DEVELOP" "Regenerate each review package with upstream's \`review-package\` helper" 'review packages are not compared with their Git ranges'
require_literal "$DEVELOP" 'Before final-review work is dispatched, persist the harness-issued reviewer context' 'reviewer dispatch identity is not persisted before dispatch'
require_literal "$DEVELOP" 'For Codex, first allocate a fresh reviewer for an identity handshake only' 'Codex reviewer handshake is missing'
require_literal "$DEVELOP" 'capture the harness-returned canonical task path, persist it, then dispatch the review through a follow-up to that same reviewer' 'Codex final review does not bind the allocated reviewer'
require_literal "$DEVELOP" 'If the harness exposes no verifiable reviewer context, stop without a success token.' 'missing harness reviewer identity is not fail closed'
require_literal "$DEVELOP" 'A null fix package requires exactly `**Ready to merge?** Yes`; a non-null byte-exact fix package requires the initial `**Ready to merge?** With fixes` plus exactly `**Fix round:** All findings addressed, no new Critical/Important breakage`.' 'final verdict paths do not match upstream review grammar'
require_literal "$IMPLEMENT" '`analysis.md` is the required readiness review of the current design and tasks before code begins.' 'implement does not name the readiness boundary'

if grep -Eq 'replay_contract|marker-bound|legacy compatibility' "$DEVELOP"; then
  fail_contract 'x-develop retains marker-specific projection branching'
fi

# The changed implementation/review boundary must be visible in every Mandatory Sync 5 surface.
for doc in \
  "$ROOT/docs/pipeline-flow.md" \
  "$ROOT/docs/delegation-map.md" \
  "$ROOT/skills/using-maxi/SKILL.md" \
  "$ROOT/AGENTS.md" \
  "$ROOT/docs/architecture.md"; do
  require_literal "$doc" 'READY_TO_FINISH' "$(basename "$doc") omits the terminal receipt gate"
  require_literal "$doc" 'Upstream SDD owns the only whole-branch review' "$(basename "$doc") keeps ambiguous final-review ownership"
  require_literal "$doc" 'immutable initial task-selection anchor' "$(basename "$doc") omits the selection anchor gate"
  require_literal "$doc" 'Only canonical annotated upstream completion records acquit tasks; bare or malformed completion lines fail closed.' "$(basename "$doc") omits the upstream completion grammar gate"
  require_literal "$doc" 'A null fix package requires exactly `**Ready to merge?** Yes`; a non-null byte-exact fix package requires the initial `**Ready to merge?** With fixes` plus exactly `**Fix round:** All findings addressed, no new Critical/Important breakage`.' "$(basename "$doc") omits the conditional final-review gate"
  require_literal "$doc" "Every projection's exact distributed bytes are SHA-256-bound by its ordinary SDD ledger; missing, duplicate, malformed, or mismatched projection-byte anchors fail closed across the current and predecessor lineage." "$(basename "$doc") omits the projection-byte anchor gate"
  require_literal "$doc" 'Removing an anchored incomplete `TNNN` during structural correction fails before successor creation and leaves the active-projection pointer unchanged.' "$(basename "$doc") omits the anchored-task removal gate"
  require_literal "$doc" 'Complete ledger lines containing `Ruling:` are preserved byte-for-byte in lineage order and hash-bound by the terminal receipt.' "$(basename "$doc") omits the ruling evidence contract"
done

if grep -Fq '**Fresh subagent per dispatch:**' "$DEVELOP" || grep -Fq '**Review loop cap:**' "$DEVELOP"; then
  fail_contract 'obsolete v6.1 fix-loop overrides remain'
fi

implement_ready_line="$(grep -nF 'Accept only the exact `READY_TO_FINISH` token' "$IMPLEMENT" | head -1 | cut -d: -f1)"
implement_done_line="$(grep -nF 'status: implementing' "$IMPLEMENT" | tail -1 | cut -d: -f1)"
implement_finish_line="$(grep -nF 'invoke `superpowers:finishing-a-development-branch` only after the `done` write is persisted' "$IMPLEMENT" | head -1 | cut -d: -f1)"
[ "$implement_ready_line" -lt "$implement_done_line" ] || fail_contract 'done is not gated by READY_TO_FINISH'
[ "$implement_done_line" -lt "$implement_finish_line" ] || fail_contract 'branch finishing can run before done'

echo 'All implement handoff checks passed.'
