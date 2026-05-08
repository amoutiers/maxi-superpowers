#!/usr/bin/env bash
# Validates hooks/hooks.json structure and referenced hook scripts.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

HOOKS_DIR="$ROOT/hooks"
HOOKS_JSON="$HOOKS_DIR/hooks.json"
failures=0

assert_file_exists "$HOOKS_JSON" "hooks.json"
[ ! -f "$HOOKS_JSON" ] && summary_and_exit "hooks checks"

assert_json_valid "$HOOKS_JSON" "hooks.json: valid JSON"
assert_jq "$HOOKS_JSON" ".hooks.SessionStart | length > 0" "true" "hooks.json: SessionStart hooks present"

assert_file_exists "$HOOKS_DIR/run-hook.cmd" "run-hook.cmd"
assert_executable "$HOOKS_DIR/run-hook.cmd" "run-hook.cmd"

assert_file_exists "$HOOKS_DIR/session-start" "session-start"
assert_executable "$HOOKS_DIR/session-start" "session-start"

summary_and_exit "hooks checks"
