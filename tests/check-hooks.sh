#!/usr/bin/env bash
# Validates hooks/hooks.json structure and referenced hook scripts.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

HOOKS_DIR="$ROOT/hooks"
HOOKS_JSON="$HOOKS_DIR/hooks.json"
CLAUDE_HOOKS_JSON="$HOOKS_DIR/hooks-claude.json"
CODEX_HOOKS_JSON="$HOOKS_DIR/hooks-codex.json"
failures=0

assert_file_exists "$HOOKS_JSON" "hooks.json"
[ ! -f "$HOOKS_JSON" ] && summary_and_exit "hooks checks"

assert_json_valid "$HOOKS_JSON" "hooks.json: valid JSON"
assert_jq "$HOOKS_JSON" 'keys == ["hooks"]' "true" "hooks.json: strict Codex-compatible top-level keys"
assert_jq "$HOOKS_JSON" ".hooks.SessionStart | length > 0" "true" "hooks.json: SessionStart hooks present"

assert_file_exists "$HOOKS_DIR/run-hook.cmd" "run-hook.cmd"
assert_executable "$HOOKS_DIR/run-hook.cmd" "run-hook.cmd"

assert_file_exists "$HOOKS_DIR/session-start" "session-start"
assert_executable "$HOOKS_DIR/session-start" "session-start"

assert_file_exists "$CLAUDE_HOOKS_JSON" "hooks-claude.json"
if [ -f "$CLAUDE_HOOKS_JSON" ]; then
  assert_json_valid "$CLAUDE_HOOKS_JSON" "hooks-claude.json: valid JSON"
  assert_jq "$CLAUDE_HOOKS_JSON" 'keys == ["hooks"]' "true" "hooks-claude.json: strict top-level keys"
  assert_jq "$CLAUDE_HOOKS_JSON" '.hooks.SessionStart[0].hooks[0].command | contains("${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd")' "true" "hooks-claude.json: uses Claude CLAUDE_PLUGIN_ROOT"
  if cmp -s "$HOOKS_JSON" "$CLAUDE_HOOKS_JSON"; then
    echo "OK  [hooks.json matches hooks-claude.json]"
  else
    echo "FAIL [hooks.json matches hooks-claude.json]: mismatch detected" >&2
    failures=$((failures + 1))
  fi
fi

assert_file_exists "$CODEX_HOOKS_JSON" "hooks-codex.json"
if [ -f "$CODEX_HOOKS_JSON" ]; then
  assert_json_valid "$CODEX_HOOKS_JSON" "hooks-codex.json: valid JSON"
  assert_jq "$CODEX_HOOKS_JSON" 'keys == ["hooks"]' "true" "hooks-codex.json: strict Codex-compatible top-level keys"
  assert_jq "$CODEX_HOOKS_JSON" '.hooks.SessionStart[0].hooks[0].command | contains("${PLUGIN_ROOT}/hooks/run-hook.cmd")' "true" "hooks-codex.json: uses Codex PLUGIN_ROOT"
fi

assert_file_exists "$HOOKS_DIR/session-start-codex" "session-start-codex"
assert_executable "$HOOKS_DIR/session-start-codex" "session-start-codex"

# Validate root hooks.json for Antigravity
ROOT_HOOKS="$ROOT/hooks.json"
assert_file_exists "$ROOT_HOOKS" "root hooks.json"
if [ -f "$ROOT_HOOKS" ]; then
  assert_json_valid "$ROOT_HOOKS" "root hooks.json: valid JSON"
  assert_jq "$ROOT_HOOKS" 'keys == ["hooks"]' "true" "root hooks.json: strict Codex-compatible top-level keys"
  assert_jq "$ROOT_HOOKS" ".hooks.SessionStart | length > 0" "true" "root hooks.json: SessionStart hooks present"
  
  # Check if root hooks.json is structurally identical to hooks/hooks.json (modulo CLAUDE_PLUGIN_ROOT -> extensionPath)
  normalized_hooks_json=$(sed 's/\${CLAUDE_PLUGIN_ROOT}/\${extensionPath}/g' "$HOOKS_JSON")
  root_hooks_content=$(cat "$ROOT_HOOKS")
  if [ "$normalized_hooks_json" = "$root_hooks_content" ]; then
    echo "OK  [root hooks.json matches hooks/hooks.json structure]"
  else
    echo "FAIL [root hooks.json matches hooks/hooks.json structure]: mismatch detected" >&2
    failures=$((failures + 1))
  fi
fi

# --- M1 (2026-05-30 review): session-start must emit valid JSON in a maxi project, ---
# --- and stay silent (empty, exit 0) outside one. ---
HOOK="$HOOKS_DIR/session-start"
TMP_PROJ="$(mktemp -d)"; TMP_EMPTY="$(mktemp -d)"
trap 'rm -rf "$TMP_PROJ" "$TMP_EMPTY"' EXIT
mkdir -p "$TMP_PROJ/docs/maxi"

hook_out="$(cd "$TMP_PROJ" && CLAUDE_PLUGIN_ROOT="$ROOT" bash "$HOOK")"
if printf '%s' "$hook_out" | jq empty 2>/dev/null; then
  echo "OK  [session-start: emits valid JSON in a maxi project]"
else
  echo "FAIL [session-start: emits valid JSON in a maxi project]" >&2
  failures=$((failures + 1))
fi

empty_out="$(cd "$TMP_EMPTY" && CLAUDE_PLUGIN_ROOT="$ROOT" bash "$HOOK")"
if [ -z "$empty_out" ]; then
  echo "OK  [session-start: silent outside a maxi project]"
else
  echo "FAIL [session-start: silent outside a maxi project]: got output" >&2
  failures=$((failures + 1))
fi

CODEX_HOOK="$HOOKS_DIR/session-start-codex"
codex_hook_out="$(cd "$TMP_PROJ" && PLUGIN_ROOT="$ROOT" bash "$CODEX_HOOK")"
if printf '%s' "$codex_hook_out" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart" and (.hookSpecificOutput.additionalContext | contains("maxi:using-maxi"))' >/dev/null 2>&1; then
  echo "OK  [session-start-codex: emits Codex SessionStart additionalContext in a maxi project]"
else
  echo "FAIL [session-start-codex: emits Codex SessionStart additionalContext in a maxi project]" >&2
  failures=$((failures + 1))
fi

codex_empty_out="$(cd "$TMP_EMPTY" && PLUGIN_ROOT="$ROOT" bash "$CODEX_HOOK")"
if [ -z "$codex_empty_out" ]; then
  echo "OK  [session-start-codex: silent outside a maxi project]"
else
  echo "FAIL [session-start-codex: silent outside a maxi project]: got output" >&2
  failures=$((failures + 1))
fi

summary_and_exit "hooks checks"
