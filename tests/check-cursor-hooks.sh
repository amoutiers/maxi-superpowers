#!/usr/bin/env bash
# Validates hooks/hooks-cursor.json (Cursor sessionStart manifest).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

MANIFEST="$ROOT/hooks/hooks-cursor.json"
failures=0

assert_file_exists "$MANIFEST" "hooks-cursor.json"
[ ! -f "$MANIFEST" ] && summary_and_exit "cursor hooks checks"

assert_json_valid "$MANIFEST" "hooks-cursor.json: valid JSON"
assert_jq "$MANIFEST" 'has("version")' "true" "hooks-cursor.json: has version"
assert_jq "$MANIFEST" 'has("hooks")' "true" "hooks-cursor.json: has hooks"
assert_jq "$MANIFEST" '.hooks.sessionStart | length > 0' "true" "hooks-cursor.json: sessionStart present"
assert_jq "$MANIFEST" '.hooks.sessionStart[0].command | contains("session-start")' "true" "hooks-cursor.json: runs session-start"
assert_jq "$MANIFEST" '.hooks.sessionStart[0].command | contains("./hooks/run-hook.cmd")' "true" "hooks-cursor.json: invokes run-hook.cmd"

summary_and_exit "cursor hooks checks"