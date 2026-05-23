#!/usr/bin/env bash
# Run all skill-triggering integration tests.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROMPTS_DIR="$SCRIPT_DIR/prompts"

SKILLS=(
  "specify"
  "clarify"
  "plan"
  "tasks"
  "analyze"
  "implement"
  "constitution"
  "board"
)

echo "=== Maxi Skill Triggering Tests ==="
echo ""

PASSED=0
FAILED=0
RESULTS=()

for skill in "${SKILLS[@]}"; do
  prompt_file="$PROMPTS_DIR/${skill}.txt"

  if [ ! -f "$prompt_file" ]; then
    echo "SKIP: No prompt file for $skill"
    continue
  fi

  echo "Testing: $skill"
  if "$SCRIPT_DIR/run-trigger-test.sh" "$skill" "$prompt_file" 3; then
    PASSED=$((PASSED + 1))
    RESULTS+=("PASS: $skill")
  else
    FAILED=$((FAILED + 1))
    RESULTS+=("FAIL: $skill")
  fi

  echo ""
  echo "---"
  echo ""
done

echo ""
echo "=== Summary ==="
for result in "${RESULTS[@]}"; do
  echo "  $result"
done
echo ""
echo "Passed: $PASSED / $((PASSED + FAILED))"

if [ $FAILED -gt 0 ]; then
  exit 1
fi
