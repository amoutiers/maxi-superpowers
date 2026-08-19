#!/usr/bin/env bash
# Validates hooks/hooks-cursor.json (Cursor sessionStart manifest).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

MANIFEST="$ROOT/hooks/hooks-cursor.json"
PLUGIN_MANIFEST="$ROOT/.cursor-plugin/plugin.json"
failures=0

assert_file_exists "$MANIFEST" "hooks-cursor.json"
[ ! -f "$MANIFEST" ] && summary_and_exit "cursor hooks checks"

assert_json_valid "$MANIFEST" "hooks-cursor.json: valid JSON"
assert_jq "$MANIFEST" 'has("version")' "true" "hooks-cursor.json: has version"
assert_jq "$MANIFEST" 'has("hooks")' "true" "hooks-cursor.json: has hooks"
assert_jq "$MANIFEST" '.hooks.sessionStart | length > 0' "true" "hooks-cursor.json: sessionStart present"
assert_jq "$MANIFEST" '.hooks.sessionStart[0].command | contains("session-start")' "true" "hooks-cursor.json: runs session-start"
assert_jq "$MANIFEST" '.hooks.sessionStart[0].command | contains("./hooks/run-hook.cmd")' "true" "hooks-cursor.json: invokes run-hook.cmd"

assert_file_exists "$PLUGIN_MANIFEST" ".cursor-plugin/plugin.json"
if [ -f "$PLUGIN_MANIFEST" ]; then
  assert_json_valid "$PLUGIN_MANIFEST" ".cursor-plugin/plugin.json: valid JSON"
  assert_jq "$PLUGIN_MANIFEST" '.name' 'maxi' ".cursor-plugin/plugin.json: name is maxi"
  assert_jq "$PLUGIN_MANIFEST" '.skills' './skills/' ".cursor-plugin/plugin.json: skills path"
  assert_jq "$PLUGIN_MANIFEST" '.hooks' './hooks/hooks-cursor.json' ".cursor-plugin/plugin.json: hooks path"
  if [ -d "$ROOT/skills" ]; then
    echo "OK  [.cursor-plugin/plugin.json: skills path resolves]"
  else
    echo "FAIL [.cursor-plugin/plugin.json: skills path resolves]" >&2
    failures=$((failures + 1))
  fi
  if [ -f "$ROOT/hooks/hooks-cursor.json" ]; then
    echo "OK  [.cursor-plugin/plugin.json: hooks path resolves]"
  else
    echo "FAIL [.cursor-plugin/plugin.json: hooks path resolves]" >&2
    failures=$((failures + 1))
  fi
fi

summary_and_exit "cursor hooks checks"
