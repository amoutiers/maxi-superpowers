#!/usr/bin/env bash
# Test that a skill is read from this worktree for a naive prompt.
# Usage: run-codex-trigger-test.sh <skill-name> <prompt-file>
set -euo pipefail

SKILL_NAME="${1:?usage: run-codex-trigger-test.sh <skill-name> <prompt-file>}"
PROMPT_FILE="${2:?usage: run-codex-trigger-test.sh <skill-name> <prompt-file>}"

if [[ ! "$SKILL_NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "ERROR: unsafe skill name: $SKILL_NAME" >&2
  exit 1
fi

ROOT="$(git rev-parse --show-toplevel)"
OUTPUT_ROOT="$ROOT/.superpowers/sdd/integration"
USER_CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
OUTPUT_DIR="$OUTPUT_ROOT/$TIMESTAMP-$$/$SKILL_NAME"
LOG_FILE="$OUTPUT_DIR/codex-output.jsonl"
ISOLATED_CODEX_HOME="$OUTPUT_DIR/codex-home"
EXPECTED_SKILL_PATH="$ROOT/skills/$SKILL_NAME/SKILL.md"
MARKETPLACE_NAME="maxi-superpowers"
PLUGIN_NAME="maxi"
MARKETPLACE_DIR="$ISOLATED_CODEX_HOME/marketplace"
PLUGIN_DIR="$MARKETPLACE_DIR/plugins/$PLUGIN_NAME"
MARKETPLACE_LOG="$OUTPUT_DIR/plugin-install.log"
INSTALLED_SKILL_PATH=""
INSTALLED_SKILL_RELATIVE_PATH=""
TIMEOUT_SECONDS=300
TIMEOUT_GRACE_SECONDS=5

run_codex_with_deadline() {
  local output_file="$1"
  shift

  perl "$ROOT/tests/integration/run-with-deadline.pl" \
    "$TIMEOUT_SECONDS" "$TIMEOUT_GRACE_SECONDS" -- "$@" >> "$output_file" 2>&1
}

if [ ! -f "$PROMPT_FILE" ]; then
  echo "ERROR: prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi

if [ ! -f "$USER_CODEX_HOME/auth.json" ]; then
  echo "ERROR: Codex authentication file not found: $USER_CODEX_HOME/auth.json" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to verify Codex JSONL output" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR" "$ISOLATED_CODEX_HOME"
trap 'rm -rf "$ISOLATED_CODEX_HOME"' EXIT

ln -s "$USER_CODEX_HOME/auth.json" "$ISOLATED_CODEX_HOME/auth.json"
mkdir -p "$PLUGIN_DIR" "$MARKETPLACE_DIR/.agents/plugins"
cp -R "$ROOT/.codex-plugin" "$PLUGIN_DIR/.codex-plugin"
cp -R "$ROOT/skills" "$PLUGIN_DIR/skills"
cp "$ROOT/.agents/plugins/marketplace.json" "$MARKETPLACE_DIR/.agents/plugins/marketplace.json"

PROMPT=$(cat "$PROMPT_FILE")
PROMPT="$PROMPT

TEST-ONLY: Identify and read the applicable skill, then stop after reading it. Do not execute its workflow, ask for consent, or dispatch subagents."
printf '%s\n' "$PROMPT" > "$OUTPUT_DIR/prompt.txt"
export CODEX_HOME="$ISOLATED_CODEX_HOME"

echo "=== Skill Triggering Test: $SKILL_NAME ==="
echo "Prompt file: $PROMPT_FILE"
echo "Output dir: $OUTPUT_DIR"
echo ""
echo "Installing local plugin snapshot ..."
: > "$MARKETPLACE_LOG"
if run_codex_with_deadline "$MARKETPLACE_LOG" codex plugin marketplace add "$MARKETPLACE_DIR"; then
  :
else
  CODEX_STATUS=$?
  echo "ERROR: failed to add local marketplace. See $MARKETPLACE_LOG" >&2
  exit "$CODEX_STATUS"
fi
if run_codex_with_deadline "$MARKETPLACE_LOG" codex plugin add "$PLUGIN_NAME@$MARKETPLACE_NAME"; then
  :
else
  CODEX_STATUS=$?
  echo "ERROR: failed to install local plugin. See $MARKETPLACE_LOG" >&2
  exit "$CODEX_STATUS"
fi

INSTALLED_SKILL_PATH=$(find "$ISOLATED_CODEX_HOME/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME" \
  -type f -path "*/skills/$SKILL_NAME/SKILL.md" -print -quit)
if [ -z "$INSTALLED_SKILL_PATH" ]; then
  echo "ERROR: installed skill snapshot not found. See $MARKETPLACE_LOG" >&2
  exit 1
fi
if ! cmp -s "$EXPECTED_SKILL_PATH" "$INSTALLED_SKILL_PATH"; then
  echo "ERROR: installed skill snapshot differs from this worktree" >&2
  exit 1
fi
INSTALLED_SKILL_RELATIVE_PATH="${INSTALLED_SKILL_PATH#"$ROOT/"}"
echo "Running codex exec ..."

: > "$LOG_FILE"
if run_codex_with_deadline "$LOG_FILE" codex exec --ephemeral --json --sandbox read-only "$PROMPT"; then
  CODEX_STATUS=0
else
  CODEX_STATUS=$?
fi

echo ""
echo "=== Results ==="

if [ "$CODEX_STATUS" -ne 0 ]; then
  echo "FAIL: Codex exited with status $CODEX_STATUS" >&2
  echo ""
  echo "Log: $LOG_FILE"
  exit "$CODEX_STATUS"
elif ! grep -Fq '"type":"turn.completed"' "$LOG_FILE"; then
  echo "FAIL: Codex did not complete its turn" >&2
elif grep -Fq '"type":"turn.failed"' "$LOG_FILE"; then
  echo "FAIL: Codex reported a failed turn" >&2
elif grep -Fq 'failed to load plugin' "$LOG_FILE"; then
  echo "FAIL: Codex failed to load the local plugin" >&2
elif ! tr -d '\000' < "$LOG_FILE" | grep -a '^{' | jq -e \
  --arg installed_skill_path "$INSTALLED_SKILL_RELATIVE_PATH" \
  --arg skill_name "name: $SKILL_NAME" '
    select(
      .type == "item.completed" and
      .item.type == "command_execution" and
      .item.status == "completed" and
      .item.exit_code == 0 and
      ((.item.command // "") | contains($installed_skill_path)) and
      ((.item.aggregated_output // "") | contains($skill_name))
    )
  ' > /dev/null; then
  echo "FAIL: Skill '$SKILL_NAME' was NOT triggered from this worktree" >&2
else
  echo "PASS: Skill '$SKILL_NAME' was triggered from this worktree"
  echo ""
  echo "Log: $LOG_FILE"
  exit 0
fi

echo ""
echo "Log: $LOG_FILE"
exit 1
