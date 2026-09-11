#!/usr/bin/env bash
# Check completed-spec reopening invariants from spec 0021.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

REVISE="$ROOT/skills/revise/SKILL.md"
failures=0

process_section="$(awk '
  $0 == "## Process" { found = 1 }
  found && /^## / && $0 != "## Process" { exit }
  found { print }
' "$REVISE")"

assert_process_order() {
  local before="$1" after="$2" label="$3" before_line after_line
  before_line="$(printf '%s\n' "$process_section" | grep -nF "$before" | head -1 | cut -d: -f1 || true)"
  after_line="$(printf '%s\n' "$process_section" | grep -nF "$after" | head -1 | cut -d: -f1 || true)"
  if [ -n "$before_line" ] && [ -n "$after_line" ] && [ "$before_line" -lt "$after_line" ]; then
    echo "OK  [$label]"
  else
    echo "FAIL [$label]: expected '$before' before '$after' in Process" >&2
    failures=$((failures + 1))
  fi
}

assert_file_exists "$REVISE" "revise SKILL.md"

# A completed spec is a valid rollback source
# and the authorization boundary remain enforced.
assert_grep "$REVISE" 'Valid for:.*done' "done is an accepted revision source"
assert_grep "$REVISE" 'Reuse explicit authorization' "existing authorization is reused"
assert_grep "$REVISE" 'mutation authority remains materially unclear' "real authorization gaps stop"
assert_grep "$REVISE" 'unresolved authorization question writes nothing' "unresolved authority writes nothing"
assert_not_grep "$REVISE" 'done (shipped)' "done is not treated as shipped"
assert_not_grep "$REVISE" 'status: done.*Refuse\|Refuse.*status: done' "done is not refused"

# A done rollback starts a distinct design cycle. Active-only rollbacks retain
# that cycle, so ADRs from a prior conception cannot be amended.
assert_not_grep "$REVISE" 'reopened_from' "reopening uses no boolean watermark"
assert_grep "$REVISE" 'design_cycle' "reopening records the design cycle"
assert_grep "$REVISE" 'increment' "done rollback increments the design cycle"
assert_grep "$REVISE" 'source is `done`' "only a done rollback advances the design cycle"
assert_grep "$REVISE" 'retain.*design_cycle' "non-done rollback retains the design cycle"
assert_grep "$REVISE" 'nonnegative integer.*stop before writing' "malformed design cycles fail closed"
assert_grep "$REVISE" 'Clarifications' "reopening records a revision note"
assert_grep "$REVISE" 'Only `spec.md` is written' "reopening keeps artifact ownership"
assert_process_order 'Reuse explicit authorization' 'write `spec.md`' "authorization precedes rollback write"
assert_grep "$REVISE" 'Never delete or rename downstream' "stale artifacts retained"
assert_grep "$REVISE" 'Never modify constitution or ADR files' "ADR authority preserved"
summary_and_exit "revise invariant checks"
