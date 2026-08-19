#!/usr/bin/env bash
# Validates the v6.3 declarative harness manifests as one packaging surface.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

PKG="$ROOT/package.json"
CURSOR="$ROOT/.cursor-plugin/plugin.json"
KIMI="$ROOT/.kimi-plugin/plugin.json"
DEVIN="$ROOT/.devin-plugin/plugin.json"
GEMINI="$ROOT/gemini-extension.json"
GEMINI_CONTEXT="$ROOT/GEMINI.md"
CODEX="$ROOT/.codex-plugin/plugin.json"
HOOKS="$ROOT/hooks/hooks.json"
failures=0

assert_file_exists "$PKG" "package.json"
if [ -f "$PKG" ]; then
  assert_json_valid "$PKG" "package.json: valid JSON"
  package_version="$(jq -r '.version' "$PKG")"
else
  package_version=""
fi

for manifest in "$CURSOR" "$KIMI" "$DEVIN" "$GEMINI"; do
  label="${manifest#"$ROOT/"}"
  assert_file_exists "$manifest" "$label"
  if [ -f "$manifest" ]; then
    assert_json_valid "$manifest" "$label: valid JSON"
    assert_jq "$manifest" '.name' 'maxi' "$label: name is maxi"
    assert_jq "$manifest" '.version' "$package_version" "$label: version matches package.json"
  fi
done

if [ -f "$CODEX" ]; then
  assert_jq "$CODEX" '.version' "$package_version" ".codex-plugin/plugin.json: version matches package.json"
fi

if [ -f "$HOOKS" ]; then
  assert_jq "$HOOKS" '.hooks.SessionStart[0].hooks[0].shell' 'bash' "hooks.json: SessionStart command uses bash"
fi

if [ -f "$CURSOR" ]; then
  cursor_skills="$(jq -r '.skills // empty' "$CURSOR")"
  cursor_hooks="$(jq -r '.hooks // empty' "$CURSOR")"
  if [ "$cursor_skills" = './skills/' ] && [ -d "$ROOT/${cursor_skills#./}" ]; then
    echo "OK  [.cursor-plugin/plugin.json: skills path resolves]"
  else
    echo "FAIL [.cursor-plugin/plugin.json: skills path resolves]" >&2
    failures=$((failures + 1))
  fi
  if [ "$cursor_hooks" = './hooks/hooks-cursor.json' ] && [ -f "$ROOT/${cursor_hooks#./}" ]; then
    echo "OK  [.cursor-plugin/plugin.json: hooks path resolves]"
  else
    echo "FAIL [.cursor-plugin/plugin.json: hooks path resolves]" >&2
    failures=$((failures + 1))
  fi
fi

if [ -f "$KIMI" ]; then
  assert_jq "$KIMI" '.skills' './skills/' ".kimi-plugin/plugin.json: skills path"
  assert_jq "$KIMI" '.sessionStart.skill' 'using-maxi' ".kimi-plugin/plugin.json: session start skill"
  for tool in AskUserQuestion TodoList Agent Skill Read Write Edit Bash Grep Glob FetchURL WebSearch; do
    assert_jq "$KIMI" ".skillInstructions | contains(\"$tool\")" 'true' ".kimi-plugin/plugin.json: names $tool"
  done
fi

if [ -f "$GEMINI" ]; then
  assert_jq "$GEMINI" '.contextFileName' 'GEMINI.md' "gemini-extension.json: context file"
fi
assert_file_exists "$GEMINI_CONTEXT" "GEMINI.md"
if [ -f "$GEMINI_CONTEXT" ]; then
  assert_grep "$GEMINI_CONTEXT" '^@./skills/using-maxi/SKILL.md$' "GEMINI.md: imports using-maxi"
  assert_grep "$GEMINI_CONTEXT" '^@./skills/using-superpowers/references/gemini-tools.md$' "GEMINI.md: imports Gemini tools"
fi

if [ -f "$DEVIN" ]; then
  assert_jq "$DEVIN" 'has("hooks") or has("sessionStart") or has("skills") or has("contextFileName")' 'false' ".devin-plugin/plugin.json: metadata-only"
fi

if bash "$ROOT/tests/check-pi-extension.sh"; then
  echo "OK  [Pi: project-gated first-session and post-compaction bootstrap]"
else
  echo "FAIL [Pi: project-gated first-session and post-compaction bootstrap]" >&2
  failures=$((failures + 1))
fi

summary_and_exit "declarative harness checks"
