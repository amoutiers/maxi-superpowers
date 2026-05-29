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

# --- assertions added incrementally by later tasks ---

summary_and_exit "migrate-adr invariant checks"
