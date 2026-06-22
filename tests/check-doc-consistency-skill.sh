#!/usr/bin/env bash
# Guards the local doc-consistency skill against stale Mandatory Sync wording.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

CLAUDE_SKILL="$ROOT/.claude/skills/doc-consistency/SKILL.md"
CODEX_SKILL="$ROOT/.agents/skills/doc-consistency/SKILL.md"
failures=0

assert_file_exists "$CLAUDE_SKILL" ".claude doc-consistency skill"
assert_file_exists "$CODEX_SKILL" ".agents doc-consistency skill"

for skill in "$CLAUDE_SKILL" "$CODEX_SKILL"; do
  [ -f "$skill" ] || continue
  case "$skill" in
    */.claude/*) label=".claude" ;;
    */.agents/*) label=".agents" ;;
    *) label="$(basename "$skill")" ;;
  esac
  assert_grep "$skill" "Mandatory-Sync-5" "$label doc-consistency: names Sync-5"
  assert_grep "$skill" "five sync-locked files" "$label doc-consistency: describes five sync files"
  assert_grep "$skill" "AGENTS.md" "$label doc-consistency: checks AGENTS.md"
  assert_grep "$skill" "docs/architecture.md" "$label doc-consistency: includes architecture.md"
  assert_not_grep "$skill" "Mandatory-Sync-4" "$label doc-consistency: no stale Sync-4"
  assert_not_grep "$skill" "four sync-locked files" "$label doc-consistency: no stale four-file wording"
done

summary_and_exit "doc-consistency skill checks"
