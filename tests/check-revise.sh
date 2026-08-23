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

assert_non_yes_no_write() {
  if printf '%s\n' "$process_section" | awk '
    BEGIN { RS = "" }
    $0 ~ /non[- ]yes|anything other than.*yes|response.*not.*yes/ &&
      $0 ~ /do not write|write nothing|no file (is )?written|writes no file/ { found = 1 }
    END { exit(found ? 0 : 1) }
  '; then
    echo "OK  [non-yes response writes nothing]"
  else
    echo "FAIL [non-yes response writes nothing]: non-yes and no-write must be stated together" >&2
    failures=$((failures + 1))
  fi
}

assert_file_exists "$REVISE" "revise SKILL.md"

# A completed spec is a valid rollback source, while the existing A+ picker
# and explicit consent boundary remain unchanged.
assert_grep "$REVISE" 'Valid for:.*done' "done is an accepted revision source"
assert_grep "$REVISE" 'A+ picker' "A+ rollback picker is preserved"
assert_grep "$REVISE" 'About to roll back' "rollback confirmation is preserved"
assert_grep "$REVISE" 'explicit `yes`' "rollback still requires explicit yes"
assert_not_grep "$REVISE" 'done (shipped)' "done is not treated as shipped"
assert_not_grep "$REVISE" 'status: done.*Refuse\|Refuse.*status: done' "done is not refused"

# Reopening writes a permanent lifecycle watermark and records the revision in
# the spec only; later transitions must not clear the watermark.
assert_grep "$REVISE" 'reopened_from: done' "reopening writes the done watermark"
assert_grep "$REVISE" 'retain.*reopened_from: done\|reopened_from: done.*retain' "watermark is retained"
assert_grep "$REVISE" 'never.*clear.*reopened_from\|reopened_from.*never.*clear' "watermark cannot be cleared"
assert_grep "$REVISE" 'Clarifications' "reopening records a revision note"
assert_grep "$REVISE" 'Only `spec.md` is written' "reopening keeps artifact ownership"
if printf '%s\n' "$process_section" | grep -Eq 'On explicit `yes` only'; then
  echo "OK  [write is gated by explicit yes]"
else
  echo "FAIL [write is gated by explicit yes]: missing explicit consent write boundary" >&2
  failures=$((failures + 1))
fi
assert_non_yes_no_write
assert_process_order 'On explicit `yes` only' 'write `spec.md`' "write follows explicit yes"

summary_and_exit "revise invariant checks"
