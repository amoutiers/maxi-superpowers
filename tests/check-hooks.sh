#!/usr/bin/env bash
# Validates hooks manifests and the unified session-start hook.
# Model aligned 1:1 with superpowers v6.3.0:
#   - hooks/hooks.json: root manifest for Claude Code + Antigravity
#   - hooks/hooks-cursor.json: Cursor manifest (sessionStart + additional_context)
#   - hooks/session-start: single env-aware hook, gated on docs/maxi/
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

HOOKS_DIR="$ROOT/hooks"
HOOKS_JSON="$HOOKS_DIR/hooks.json"
CURSOR_HOOKS_JSON="$HOOKS_DIR/hooks-cursor.json"
MUSE_PLUGIN="$ROOT/.muse-plugin/plugin.json"
failures=0

# --- root manifest: hooks.json (Claude Code + Antigravity) ---
assert_file_exists "$HOOKS_JSON" "hooks.json"
[ ! -f "$HOOKS_JSON" ] && summary_and_exit "hooks checks"

assert_json_valid "$HOOKS_JSON" "hooks.json: valid JSON"
assert_jq "$HOOKS_JSON" 'keys == ["hooks"]' "true" "hooks.json: strict top-level keys"
assert_jq "$HOOKS_JSON" ".hooks.SessionStart | length > 0" "true" "hooks.json: SessionStart hooks present"
assert_jq "$HOOKS_JSON" '.hooks.SessionStart[0].hooks[0].command | contains("${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd")' "true" "hooks.json: uses CLAUDE_PLUGIN_ROOT"
assert_jq "$HOOKS_JSON" '.hooks.SessionStart[0].hooks[0].command | contains("session-start")' "true" "hooks.json: runs session-start"
assert_jq "$HOOKS_JSON" '.hooks.SessionStart[0].hooks[0].shell' "bash" "hooks.json: SessionStart command uses bash"

# --- Cursor manifest: hooks-cursor.json ---
assert_file_exists "$CURSOR_HOOKS_JSON" "hooks-cursor.json"
if [ -f "$CURSOR_HOOKS_JSON" ]; then
  assert_json_valid "$CURSOR_HOOKS_JSON" "hooks-cursor.json: valid JSON"
  assert_jq "$CURSOR_HOOKS_JSON" 'has("version") and has("hooks")' "true" "hooks-cursor.json: version + hooks keys"
  assert_jq "$CURSOR_HOOKS_JSON" '.hooks.sessionStart | length > 0' "true" "hooks-cursor.json: sessionStart present"
  assert_jq "$CURSOR_HOOKS_JSON" '.hooks.sessionStart[0].command | contains("session-start")' "true" "hooks-cursor.json: runs session-start"
fi

# --- unified hook + polyglot wrapper ---
assert_file_exists "$HOOKS_DIR/run-hook.cmd" "run-hook.cmd"
assert_executable "$HOOKS_DIR/run-hook.cmd" "run-hook.cmd"

assert_file_exists "$HOOKS_DIR/session-start" "session-start"
assert_executable "$HOOKS_DIR/session-start" "session-start"
assert_grep "$HOOKS_DIR/session-start" "You have maxi." "session-start: carries maxi bootstrap header"

# Stale per-harness wrappers must be gone.
for stale in session-start-core session-start-claude session-start-codex session-start-antigravity; do
  if [ -e "$HOOKS_DIR/$stale" ]; then
    echo "FAIL [stale wrapper $stale]: should be removed" >&2
    failures=$((failures + 1))
  else
    echo "OK  [no stale $stale]"
  fi
done

# Stale alias manifests must be gone.
for stale in hooks-claude.json hooks-codex.json hooks-antigravity.json; do
  if [ -e "$HOOKS_DIR/$stale" ]; then
    echo "FAIL [stale manifest $stale]: should be removed" >&2
    failures=$((failures + 1))
  else
    echo "OK  [no stale $stale]"
  fi
done

# The .antigravity-plugin/ package directory is gone (Antigravity installs from repo root).
if [ -e "$ROOT/.antigravity-plugin" ]; then
  echo "FAIL [.antigravity-plugin/]: should be removed (Antigravity installs from repo root)" >&2
  failures=$((failures + 1))
else
  echo "OK  [no .antigravity-plugin/]"
fi

# --- behavior: the unified hook emits the right JSON shape per harness ---
TMP_PROJ="$(mktemp -d)"; TMP_EMPTY="$(mktemp -d)"
trap 'rm -rf "$TMP_PROJ" "$TMP_EMPTY"' EXIT
mkdir -p "$TMP_PROJ/docs/maxi"
HOOK="$HOOKS_DIR/session-start"

# Claude Code shape (CLAUDE_PLUGIN_ROOT, no COPILOT_CLI)
claude_out="$(cd "$TMP_PROJ" && CLAUDE_PLUGIN_ROOT="$ROOT" bash "$HOOK")"
if printf '%s' "$claude_out" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart" and (.hookSpecificOutput.additionalContext | contains("maxi:using-maxi"))' >/dev/null 2>&1; then
  echo "OK  [session-start: Claude Code shape in a maxi project]"
else
  echo "FAIL [session-start: Claude Code shape in a maxi project]" >&2
  failures=$((failures + 1))
fi

# Cursor shape (CURSOR_PLUGIN_ROOT)
cursor_out="$(cd "$TMP_PROJ" && CURSOR_PLUGIN_ROOT="$ROOT" bash "$HOOK")"
if printf '%s' "$cursor_out" | jq -e '.additional_context | contains("maxi:using-maxi")' >/dev/null 2>&1; then
  echo "OK  [session-start: Cursor shape in a maxi project]"
else
  echo "FAIL [session-start: Cursor shape in a maxi project]" >&2
  failures=$((failures + 1))
fi

# Copilot CLI shape (COPILOT_CLI=1)
copilot_out="$(cd "$TMP_PROJ" && COPILOT_CLI=1 bash "$HOOK")"
if printf '%s' "$copilot_out" | jq -e '.additionalContext | contains("maxi:using-maxi")' >/dev/null 2>&1; then
  echo "OK  [session-start: Copilot CLI shape in a maxi project]"
else
  echo "FAIL [session-start: Copilot CLI shape in a maxi project]" >&2
  failures=$((failures + 1))
fi

# Muse and Qwen require the nested SessionStart output observed in native sessions.
for label in muse muse-with-claude qwen; do
  case "$label" in
    muse) out="$(cd "$TMP_PROJ" && MUSE_PLUGIN_ROOT="$ROOT" bash "$HOOK")" ;;
    muse-with-claude) out="$(cd "$TMP_PROJ" && MUSE_PLUGIN_ROOT="$ROOT" CLAUDE_PLUGIN_ROOT="$ROOT" bash "$HOOK")" ;;
    qwen) out="$(cd "$TMP_PROJ" && QWEN_PROJECT_DIR="$TMP_PROJ" bash "$HOOK")" ;;
  esac
  if printf '%s' "$out" | jq -e 'keys == ["hookSpecificOutput"] and .hookSpecificOutput.hookEventName == "SessionStart" and (.hookSpecificOutput.additionalContext | contains("You have maxi."))' >/dev/null 2>&1; then
    echo "OK  [session-start: $label nested shape]"
  else
    echo "FAIL [session-start: $label nested shape]" >&2
    failures=$((failures + 1))
  fi
done

if [ -f "$MUSE_PLUGIN" ]; then
  muse_interpreter="$(jq -r '.capabilities.hooks[] | select(.event == "SessionStart") | .command[0]' "$MUSE_PLUGIN")"
  muse_script="$(jq -r '.capabilities.hooks[] | select(.event == "SessionStart") | .command[1]' "$MUSE_PLUGIN")"
  if [ -n "$muse_interpreter" ] && [ -n "$muse_script" ]; then
    declared_out="$(cd "$TMP_PROJ" && MUSE_PLUGIN_ROOT="$ROOT" "$muse_interpreter" "$ROOT/$muse_script")"
    if printf '%s' "$declared_out" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart" and (.hookSpecificOutput.additionalContext | contains("You have maxi."))' >/dev/null 2>&1; then
      echo "OK  [Muse declared Bash command runs the hook]"
    else
      echo "FAIL [Muse declared Bash command runs the hook]" >&2
      failures=$((failures + 1))
    fi
  else
    echo "FAIL [Muse declared Bash command has two arguments]" >&2
    failures=$((failures + 1))
  fi
fi

# Silent outside a maxi project
empty_out="$(cd "$TMP_EMPTY" && bash "$HOOK")"
if [ -z "$empty_out" ]; then
  echo "OK  [session-start: silent outside a maxi project]"
else
  echo "FAIL [session-start: silent outside a maxi project]: got output" >&2
  failures=$((failures + 1))
fi
for label in muse qwen; do
  if [ "$label" = muse ]; then
    empty_out="$(cd "$TMP_EMPTY" && MUSE_PLUGIN_ROOT="$ROOT" bash "$HOOK")"
  else
    empty_out="$(cd "$TMP_EMPTY" && QWEN_PROJECT_DIR="$TMP_EMPTY" bash "$HOOK")"
  fi
  if [ -z "$empty_out" ]; then
    echo "OK  [session-start: $label silent outside a maxi project]"
  else
    echo "FAIL [session-start: $label emitted outside a maxi project]" >&2
    failures=$((failures + 1))
  fi
done

summary_and_exit "hooks checks"
