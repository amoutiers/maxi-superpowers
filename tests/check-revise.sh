#!/usr/bin/env bash
# Check completed-spec reopening invariants from spec 0021.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

REVISE="$ROOT/skills/revise/SKILL.md"
failures=0

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

summary_and_exit "revise invariant checks"
