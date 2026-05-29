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

# --- US4: rejection log (FR-011, 012, 014) ---
assert_grep "$MIGRATE" "append its domain label" "FR-011 discovered skip appends to .rejected"
assert_grep "$MIGRATE" "not logged" "FR-012 imported skip not logged"
assert_grep "$MIGRATE" "bookkeeping" "FR-014 .rejected exempt from Iron Rule"

# --- US5: subagent return contract + constitution use (FR-015, 016) ---
assert_grep "$MIGRATE" "domain_label" "FR-015 schema domain_label"
assert_grep "$MIGRATE" "source_path" "FR-015 schema source_path"
assert_grep "$MIGRATE" "Return schema" "FR-015 explicit return-schema block"
assert_grep "$MIGRATE" "constitution's principles" "FR-016 principles passed to Discoverer"

# --- US6: significance rubric (FR-017, 018) ---
assert_grep "$MIGRATE" "costly to reverse" "FR-017 rubric in Discoverer"
assert_grep "$ADR" "costly to reverse" "FR-018 rubric in adr description"

# --- US7: polish (FR-019..021) ---
assert_grep "$MIGRATE" "git log -n 200" "FR-019 git log -n 200"
assert_not_grep "$MIGRATE" "git log -200" "FR-019 old flag removed"
assert_not_grep "$MIGRATE" "(t) = tentative" "FR-020 tentative numbers removed"
assert_grep "$MIGRATE" "assigned sequentially at write time" "FR-020 write-time note"
assert_grep "$MIGRATE" "regenerate.*README.*once" "FR-021 single regen"

summary_and_exit "migrate-adr invariant checks"
