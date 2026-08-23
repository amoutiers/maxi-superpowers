#!/usr/bin/env bash
# Check migrate-adr (and adr) SKILL.md invariants from spec 0002.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

MIGRATE="$ROOT/skills/migrate-adr/SKILL.md"
IMPORT="$ROOT/skills/migrate-adr/import-subagent.md"
DISCOVER="$ROOT/skills/migrate-adr/discover-subagent.md"
ADR="$ROOT/skills/x-adr/SKILL.md"
AGENTSMD="$ROOT/AGENTS.md"
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

# --- US3: importer hardening (FR-009, 010) — now in import-subagent.md (spec 0004) ---
assert_grep "$IMPORT" "blocklist" "FR-009 filename blocklist"
assert_grep "$IMPORT" "CONTRIBUTING.md" "FR-009 blocklist includes CONTRIBUTING"
assert_grep "$IMPORT" "source:" "FR-010 source provenance field"

# --- US4: rejection log (FR-011, 012, 014) ---
assert_grep "$MIGRATE" "append its domain label" "FR-011 discovered skip appends to .rejected"
assert_grep "$MIGRATE" "not logged" "FR-012 imported skip not logged"
assert_grep "$MIGRATE" "bookkeeping" "FR-014 .rejected exempt from Iron Rule"

# --- US5: subagent return contract + constitution use (FR-015, 016) ---
assert_grep "$MIGRATE" "domain_label" "FR-015 schema domain_label"
assert_grep "$MIGRATE" "source_path" "FR-015 schema source_path"
assert_grep "$MIGRATE" "Return schema" "FR-015 explicit return-schema block"
# FR-016 (related_principles population) reversed by spec 0018 — assertion removed.

# --- US6: significance rubric (FR-017, 018) ---
assert_grep "$DISCOVER" "costly to reverse" "FR-017 rubric in Discoverer"
assert_grep "$ADR" "costly to reverse" "FR-018 rubric in adr description"

# --- US7: polish (FR-019..021) ---
assert_grep "$DISCOVER" "git log -n 200" "FR-019 git log -n 200"
assert_not_grep "$DISCOVER" "git log -200" "FR-019 old flag removed"
assert_not_grep "$MIGRATE" "(t) = tentative" "FR-020 tentative numbers removed"
assert_grep "$MIGRATE" "assigned sequentially at write time" "FR-020 write-time note"
assert_grep "$MIGRATE" "regenerate.*README.*once" "FR-021 single regen"
assert_not_grep "$MIGRATE" "Regenerate after every write" "FR-021 no stale per-write regen"
assert_not_grep "$MIGRATE" "Write ADR + regenerate README.md" "FR-021 digraph not per-write regen"

# --- US8: docs authoring flow (FR-022) ---
assert_grep "$AGENTSMD" "brainstorm" "FR-022 brainstorm in flow"
assert_grep "$AGENTSMD" "writing-skills" "FR-022 writing-skills in flow"
assert_not_grep "$AGENTSMD" "RED: run pressure scenario WITHOUT skill" "FR-022 old TDD cycle removed"

# --- US8: constitution decoupling + amendment (FR-024, 025) ---
assert_not_grep "$CONSTITUTION" "RED/GREEN/REFACTOR" "FR-024 no RGR ref"
assert_not_grep "$CONSTITUTION" "CLAUDE.md" "FR-024 no CLAUDE.md ref"
assert_not_grep "$CONSTITUTION" 'version: "1.1.0"' "FR-025 version bumped"

# --- FR-023: preserved non-defective behavior ---
assert_grep "$MIGRATE" "Subagent A" "FR-023 importer preserved"
assert_grep "$MIGRATE" "Subagent B" "FR-023 discoverer preserved"
assert_grep "$IMPORT" "Nygard" "FR-023 format-detection tables preserved"

# --- 0004 US3: SRP boundary enforcement (briefs separated from orchestrator, spec 0004) ---
assert_file_exists "$IMPORT" "import-subagent.md exists"
assert_file_exists "$DISCOVER" "discover-subagent.md exists"
assert_grep "$MIGRATE" "import-subagent.md" "SKILL.md references importer brief"
assert_grep "$MIGRATE" "discover-subagent.md" "SKILL.md references discoverer brief"
assert_not_grep "$MIGRATE" "Nygard → maxi mapping" "SRP boundary: importer mapping not in orchestrator"
assert_not_grep "$MIGRATE" "Filename blocklist" "SRP boundary: importer blocklist not in orchestrator"
assert_not_grep "$MIGRATE" "Significance rubric" "SRP boundary: discoverer rubric not in orchestrator"
assert_not_grep "$MIGRATE" "git log -n 200" "SRP boundary: discoverer git-history scan not in orchestrator"

# --- C1 (2026-05-30 review): no stale /maxi:adr after the x-adr rename ---
ADR_README="$ROOT/docs/maxi/adr/README.md"
assert_not_grep "$MIGRATE" "maxi:adr" "C1: no stale /maxi:adr in migrate-adr SKILL.md"
assert_file_exists "$ADR_README" "adr README.md"
assert_not_grep "$ADR_README" "maxi:adr" "C1: no stale /maxi:adr in adr README.md"

# --- Active-spec ADR amendment (spec 0020) ---
assert_grep "$ADR" 'spec: <full-spec-slug> or `spec: null`' "ADR direct creating-spec link"
assert_grep "$ADR" 'current active spec slug' "ADR links to the current active spec"
assert_grep "$ADR" 'full amended ADR.*exact diff.*yes' "ADR amendment requires full diff and explicit consent"
assert_grep "$ADR" 'drafting.*specified.*clarified.*planned.*tasked.*analyzed.*implementing' "ADR amendment active-status eligibility"
assert_grep "$ADR" 'missing.*null.*supersession' "ADR missing or null link falls back to supersession"
assert_grep "$ADR" 'done.*parked.*cancelled.*supersession' "ADR closed spec falls back to supersession"
assert_grep "$ADR" 'adr.*,.*slug.*,.*spec.*,.*created.*,.*status.*,.*supersedes.*,.*superseded_by' "ADR amendment preserves identity and supersession fields"
for file in "$MIGRATE" "$IMPORT" "$DISCOVER"; do
  label="$(basename "$file")"
  assert_grep "$file" 'spec: null' "$label creates unlinked migration ADRs"
done
assert_grep "$MIGRATE" 'Existing ADRs.*not.*rewritten' "migration leaves existing ADRs unchanged"

summary_and_exit "migrate-adr invariant checks"
