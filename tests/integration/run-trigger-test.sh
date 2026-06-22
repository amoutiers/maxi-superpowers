#!/usr/bin/env bash
# Test that a skill auto-triggers from a naive prompt.
# Usage: run-trigger-test.sh <skill-name> <prompt-file> [max-turns]
set -euo pipefail

SKILL_NAME="${1:?usage: run-trigger-test.sh <skill-name> <prompt-file>}"
PROMPT_FILE="${2:?usage: run-trigger-test.sh <skill-name> <prompt-file>}"
MAX_TURNS="${3:-3}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/maxi-superpowers-tests/${TIMESTAMP}/skill-triggering/${SKILL_NAME}"
mkdir -p "$OUTPUT_DIR"

PROMPT=$(cat "$PROMPT_FILE")
LOG_FILE="$OUTPUT_DIR/claude-output.json"

cp "$PROMPT_FILE" "$OUTPUT_DIR/prompt.txt"

echo "=== Skill Triggering Test: $SKILL_NAME ==="
echo "Prompt file: $PROMPT_FILE"
echo "Output dir: $OUTPUT_DIR"
echo ""
echo "Running claude -p ..."

CLAUDE_CMD=(
  claude -p "$PROMPT"
  --plugin-dir "$PLUGIN_DIR"
  --dangerously-skip-permissions
  --max-turns "$MAX_TURNS"
  --output-format stream-json
  --verbose
)

if command -v timeout >/dev/null 2>&1; then
  timeout 300 "${CLAUDE_CMD[@]}" > "$LOG_FILE" 2>&1 || true
else
  echo "WARNING: 'timeout' not found (install coreutils for macOS). Running without timeout." >&2
  "${CLAUDE_CMD[@]}" > "$LOG_FILE" 2>&1 || true
fi

echo ""
echo "=== Results ==="

# Check that the Skill tool was invoked for this skill
# Stream-json format has lines with "name":"Skill" for tool use blocks
# and "skill":"<name>" or "skill":"maxi:<name>" in the input
SKILL_PATTERN='"skill":"(maxi:)?'"${SKILL_NAME}"'"'
if grep -q '"name":"Skill"' "$LOG_FILE" && grep -qE "$SKILL_PATTERN" "$LOG_FILE"; then
  echo "PASS: Skill '$SKILL_NAME' was triggered"
  TRIGGERED=true
else
  echo "FAIL: Skill '$SKILL_NAME' was NOT triggered"
  echo ""
  echo "Skills triggered in this run:"
  grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none)"
  TRIGGERED=false
fi

echo ""
echo "Log: $LOG_FILE"

if [ "$TRIGGERED" = "true" ]; then
  exit 0
else
  exit 1
fi
