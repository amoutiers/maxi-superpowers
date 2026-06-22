#!/usr/bin/env bash
# Validates the optional Claude integration harness without invoking Claude.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

HARNESS="$ROOT/tests/integration/run-trigger-test.sh"
RUN_ALL="$ROOT/tests/integration/run-all.sh"
failures=0

assert_file_exists "$HARNESS" "run-trigger-test.sh"
assert_file_exists "$RUN_ALL" "integration run-all.sh"

if [ -f "$HARNESS" ]; then
  assert_not_grep "$HARNESS" '\${TIMEOUT_CMD\[@\]}' "run-trigger-test: no empty-array command prefix under set -u"
  assert_grep "$HARNESS" "CLAUDE_CMD=" "run-trigger-test: builds a non-empty Claude command array"
  assert_grep "$HARNESS" "timeout 300" "run-trigger-test: still uses timeout when available"
  assert_grep "$HARNESS" "verbose" "run-trigger-test: stream-json output uses verbose mode"
  assert_grep "$HARNESS" '"${CLAUDE_CMD\[@\]}"' "run-trigger-test: falls back to direct Claude command"
fi

if [ -f "$RUN_ALL" ]; then
  assert_grep "$RUN_ALL" 'find "\$PROMPTS_DIR"' "integration run-all: derives skills from prompt files"
  assert_not_grep "$RUN_ALL" '^SKILLS=([^)]' "integration run-all: no non-empty inline hard-coded skill array"
  assert_not_grep "$RUN_ALL" '^  "[[:alnum:]_-]*"$' "integration run-all: no hard-coded skill array entries"
fi

summary_and_exit "integration harness checks"
