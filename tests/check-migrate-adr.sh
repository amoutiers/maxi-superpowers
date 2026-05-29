#!/usr/bin/env bash
# Check migrate-adr (and adr) SKILL.md invariants from spec 0002.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

MIGRATE="$ROOT/skills/migrate-adr/SKILL.md"
ADR="$ROOT/skills/adr/SKILL.md"
CLAUDEMD="$ROOT/CLAUDE.md"
CONSTITUTION="$ROOT/docs/maxi/constitution.md"
failures=0

assert_file_exists "$MIGRATE" "migrate-adr SKILL.md"

# --- US1: consent gate (FR-001..005) ---
assert_grep "$MIGRATE" "accept / skip / deprecate / edit" "FR-001 imported verbs"
assert_grep "$MIGRATE" "accept / skip / edit" "FR-004 discovered verbs"
assert_grep "$MIGRATE" "skip.*no file written" "FR-002 skip = no file"
assert_grep "$MIGRATE" "deprecate.*status: deprecated" "FR-003 deprecate writes deprecated"
assert_grep "$MIGRATE" "second ambiguous.*skip" "FR-005 ambiguous defaults to skip"
assert_not_grep "$MIGRATE" "no = import as deprecated" "FR-001 old binary prompt removed"

# --- US2: exclusion matching (FR-006..008, 013) ---
assert_grep "$MIGRATE" "strip stopwords" "FR-006 stopword strip"
assert_grep "$MIGRATE" "proper-noun" "FR-007 proper-noun set"
assert_grep "$MIGRATE" "partial.*overlap.*flag" "FR-007 partial overlap flags"
assert_grep "$MIGRATE" "shorter than 3 characters" "FR-008 short token flagged"
assert_not_grep "$MIGRATE" "either contains the other" "FR-006 old substring rule removed"

# --- US3: importer hardening (FR-009, 010) ---
assert_grep "$MIGRATE" "blocklist" "FR-009 filename blocklist"
assert_grep "$MIGRATE" "CONTRIBUTING.md" "FR-009 blocklist includes CONTRIBUTING"
assert_grep "$MIGRATE" "source:" "FR-010 source provenance field"

summary_and_exit "migrate-adr invariant checks"
