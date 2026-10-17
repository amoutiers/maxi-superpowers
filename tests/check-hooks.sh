#!/usr/bin/env bash
# Validates hooks manifests and the unified session-start hook.
#   - hooks/hooks.json: root manifest for Claude Code, Copilot CLI and Qwen
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

# --- root manifest: hooks.json (Claude Code, Copilot CLI and Qwen) ---
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

# Both entry points must preserve the complete skill and host precedence even
# before another startup hook repairs PATH.
REPO_ROOT="$ROOT" BASH_BIN="$BASH" python3 - <<'PYTEST'
import json
import os
from pathlib import Path
import subprocess
import tempfile

root = Path(os.environ["REPO_ROOT"])
bash = os.environ["BASH_BIN"]
skill = (root / "skills/using-maxi/SKILL.md").read_text().rstrip("\n")
expected_context = (
    "<EXTREMELY_IMPORTANT>\nYou have maxi.\n\n"
    "**Below is the full content of your 'maxi:using-maxi' skill - your introduction "
    "to the maxi spec-driven pipeline. For all other maxi skills, use the 'Skill' tool:**\n\n"
    + skill + "\n</EXTREMELY_IMPORTANT>"
)
markers = ("CLAUDE_PLUGIN_ROOT", "CURSOR_PLUGIN_ROOT", "COPILOT_CLI", "MUSE_PLUGIN_ROOT", "QWEN_PROJECT_DIR")
cases = [
    ({}, "additionalContext"),
    ({"CLAUDE_PLUGIN_ROOT": "plugin"}, "nested"),
    ({"CURSOR_PLUGIN_ROOT": "plugin", "CLAUDE_PLUGIN_ROOT": "plugin"}, "additional_context"),
    ({"COPILOT_CLI": "1", "CLAUDE_PLUGIN_ROOT": "plugin"}, "additionalContext"),
    ({"MUSE_PLUGIN_ROOT": "plugin", "COPILOT_CLI": "1", "CLAUDE_PLUGIN_ROOT": "plugin"}, "nested"),
    ({"QWEN_PROJECT_DIR": "project", "COPILOT_CLI": "1", "CLAUDE_PLUGIN_ROOT": "plugin"}, "nested"),
    ({"CURSOR_PLUGIN_ROOT": "plugin", "MUSE_PLUGIN_ROOT": "plugin", "QWEN_PROJECT_DIR": "project"}, "additional_context"),
]
with tempfile.TemporaryDirectory() as tmp:
    project = Path(tmp) / "project"
    (project / "docs/maxi").mkdir(parents=True)
    for entry in ([bash, str(root / "hooks/session-start")],
                  [bash, str(root / "hooks/run-hook.cmd"), "session-start"]):
        for path in (os.environ["PATH"], ""):
            for additions, shape in cases:
                env = {key: value for key, value in os.environ.items() if key not in markers}
                env.update(additions, PATH=path)
                result = subprocess.run(entry, cwd=project, env=env, capture_output=True, text=True)
                assert result.returncode == 0 and not result.stderr, (entry, path, result.stderr)
                payload = json.loads(result.stdout)
                expected = ({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": expected_context}}
                            if shape == "nested" else {shape: expected_context})
                assert payload == expected, (entry, path, shape, "incomplete bootstrap or wrong shape")
                outside = subprocess.run(entry, cwd=tmp, env=env, capture_output=True, text=True)
                assert (outside.returncode, outside.stdout, outside.stderr) == (0, "", ""), outside
    # When cat is available it absorbs the output pipe, rather than relying on
    # printf alone on Windows. A stub records use without emulating cat.
    cat_bin = Path(tmp) / "bin"
    cat_bin.mkdir()
    cat_marker = Path(tmp) / "cat-used"
    cat_stub = cat_bin / "cat"
    cat_stub.write_text(f'#!{bash}\n: > "{cat_marker}"\nexec /bin/cat "$@"\n')
    cat_stub.chmod(0o755)
    result = subprocess.run([bash, str(root / "hooks/session-start")], cwd=project,
                            env={**os.environ, "PATH": str(cat_bin)}, capture_output=True, text=True)
    assert result.returncode == 0 and not result.stderr and cat_marker.exists(), result
    payload = json.loads(result.stdout)
    context = payload.get("additionalContext", payload.get("additional_context"))
    if context is None:
        context = payload["hookSpecificOutput"]["additionalContext"]
    assert context == expected_context
    # The Unix wrapper must preserve argument boundaries and failing hook status.
    hooks = Path(tmp) / "hooks with spaces"
    hooks.mkdir()
    (hooks / "run-hook.cmd").write_bytes((root / "hooks/run-hook.cmd").read_bytes())
    (hooks / "probe").write_text('printf "<%s>\\n" "$@"\nexit 7\n')
    result = subprocess.run([bash, str(hooks / "run-hook.cmd"), "probe", "two words", "*", ""],
                            env={**os.environ, "PATH": ""}, capture_output=True, text=True)
    assert (result.returncode, result.stdout, result.stderr) == (7, "<two words>\n<*>\n<>\n", ""), result

# Structural Windows contracts complement the optional native regression below.
wrapper = (root / "hooks/run-hook.cmd").read_text()
assert '"%SystemRoot%\\System32\\where.exe" $PATH:bash' in wrapper, "Windows lookup may search the current directory"
assert 'if defined LOCALAPPDATA if exist "%LOCALAPPDATA%\\Programs\\Git\\bin\\bash.exe"' in wrapper, "missing guarded per-user Git lookup"
for directory in ('%SystemRoot%\\System32\\', '%SystemRoot%\\Sysnative\\', '%LOCALAPPDATA%\\Microsoft\\WindowsApps\\'):
    assert f'if /i not "%%~dpB"=="{directory}"' in wrapper, f"missing WSL exclusion: {directory}"
assert 'if not "%%~xB"==""' in wrapper, "extensionless Bash matches must be skipped"
assert '\n"%BASH_EXE%" "%HOOK_DIR%%~1" %2 %3 %4 %5 %6 %7 %8 %9\nexit /b %ERRORLEVEL%\n' in wrapper, "Windows dispatch must preserve quoting and return the hook status outside a block"
print("Hook bootstrap, empty-PATH, precedence, argument and Windows structural checks passed")
PYTEST

# This suite exercises cmd.exe only when Git Bash on Windows is available.
bash "$ROOT/tests/hooks/test-run-hook-cmd-windows.sh"

summary_and_exit "hooks checks"
