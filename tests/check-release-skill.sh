#!/usr/bin/env bash
# Guards local release instructions for maxi-specific pre-flight requirements.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

AGENTS_SKILL_DIR="$ROOT/.agents/skills/release"
CLAUDE_SKILL_DIR="$ROOT/.claude/skills/release"
SKILL="$AGENTS_SKILL_DIR/SKILL.md"
failures=0

assert_file_exists "$SKILL" ".agents release skill"

if [ ! -L "$CLAUDE_SKILL_DIR" ]; then
  echo "FAIL [.claude release skill]: expected symlink to .agents release skill" >&2
  failures=$((failures + 1))
elif [ "$(readlink "$CLAUDE_SKILL_DIR")" != "../../.agents/skills/release" ]; then
  echo "FAIL [.claude release skill]: expected symlink target '../../.agents/skills/release', got '$(readlink "$CLAUDE_SKILL_DIR")'" >&2
  failures=$((failures + 1))
else
  echo "OK  [.claude release skill]: symlink points to .agents release skill"
fi

assert_file_exists "$CLAUDE_SKILL_DIR/SKILL.md" ".claude release skill resolves"

if [ -f "$SKILL" ]; then
  assert_grep "$SKILL" "doc-consistency" "release skill: runs doc-consistency before release"
  assert_grep "$SKILL" ".claude/skills/doc-consistency" "release skill: documents Claude doc-consistency path"
  assert_grep "$SKILL" ".agents/skills/doc-consistency" "release skill: documents .agents doc-consistency path"
  assert_grep "$SKILL" "bash tests/run-all.sh" "release skill: still runs fast tier"
  assert_grep "$SKILL" "Abort if tests fail" "release skill: keeps test failure abort"
  assert_grep "$SKILL" ".claude-plugin/plugin.json" "release skill: includes Claude plugin manifest"
  assert_grep "$SKILL" ".codex-plugin/plugin.json" "release skill: includes Codex plugin manifest"
  assert_grep "$SKILL" ".claude-plugin/marketplace.json" "release skill: includes Claude marketplace"
  assert_grep "$SKILL" ".agents/plugins/marketplace.json" "release skill: includes Codex marketplace"
fi

summary_and_exit "release skill checks"
