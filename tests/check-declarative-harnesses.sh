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
MUSE_PLUGIN="$ROOT/.muse-plugin/plugin.json"
MUSE_MARKETPLACE="$ROOT/.muse-plugin/marketplace.json"
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

assert_file_exists "$MUSE_PLUGIN" ".muse-plugin/plugin.json"
assert_file_exists "$MUSE_MARKETPLACE" ".muse-plugin/marketplace.json"
if [ -f "$MUSE_PLUGIN" ]; then
  assert_json_valid "$MUSE_PLUGIN" "Muse plugin"
  assert_jq "$MUSE_PLUGIN" '.schemaVersion' '1' "Muse schema version"
  assert_jq "$MUSE_PLUGIN" '.name' 'maxi' "Muse plugin identity"
  assert_jq "$MUSE_PLUGIN" '.version' "$package_version" "Muse plugin version"
  assert_jq "$MUSE_PLUGIN" '.compat == {"source":"native","manifestDir":".muse-plugin"}' 'true' "Muse native compatibility"
  assert_jq "$MUSE_PLUGIN" '.capabilities.hooks | any(.event == "SessionStart" and .command == ["bash","hooks/session-start"])' 'true' "Muse Bash hook declaration"
  assert_jq "$MUSE_PLUGIN" '(.capabilities.skills | length == 34) and (.capabilities.skills | map(.id) | unique | length == 34) and all(.capabilities.skills[]; .path == ("skills/" + .id + "/SKILL.md"))' 'true' "Muse skill ids and paths are unique"
  expected_paths="$(find "$ROOT/skills" -mindepth 2 -maxdepth 2 -name SKILL.md | sed "s|$ROOT/||" | sort)"
  actual_paths="$(jq -r '.capabilities.skills[].path' "$MUSE_PLUGIN" | sort)"
  if [ "$actual_paths" = "$expected_paths" ]; then
    echo "OK  [Muse skills match all existing skill files]"
  else
    echo "FAIL [Muse skills differ from existing skill files]" >&2
    failures=$((failures + 1))
  fi
  # Mirror the future symlink-free Muse staging subset without changing the checkout.
  muse_stage="$(mktemp -d)"
  mkdir -p "$muse_stage/.muse-plugin" "$muse_stage/hooks"
  cp "$MUSE_PLUGIN" "$muse_stage/.muse-plugin/plugin.json"
  cp "$ROOT/hooks/session-start" "$muse_stage/hooks/session-start"
  cp -R "$ROOT/skills" "$muse_stage/skills"
  if [ -z "$(find "$muse_stage" -type l -print -quit)" ] &&
    [ -f "$muse_stage/hooks/session-start" ] &&
    jq -e -r '.capabilities.skills[].path' "$MUSE_PLUGIN" | while IFS= read -r path; do [ -f "$muse_stage/$path" ] && [ ! -L "$muse_stage/$path" ] || exit 1; done; then
    echo "OK  [Muse staged package has regular skill and hook paths without symlinks]"
  else
    echo "FAIL [Muse staged package has unsafe or missing paths]" >&2
    failures=$((failures + 1))
  fi
  rm -rf "$muse_stage"
  assert_jq "$MUSE_PLUGIN" 'tostring | test("superpowers-dev|Jesse Vincent|fsck.com") | not' 'true' "Muse plugin omits upstream branding and contacts"
fi
if [ -f "$MUSE_MARKETPLACE" ]; then
  assert_json_valid "$MUSE_MARKETPLACE" "Muse marketplace"
  assert_jq "$MUSE_MARKETPLACE" '.name' 'maxi' "Muse marketplace identity"
  assert_jq "$MUSE_MARKETPLACE" '.plugins | length == 1' 'true' "Muse marketplace has one plugin"
  assert_jq "$MUSE_MARKETPLACE" '.plugins[0].name' 'maxi' "Muse marketplace plugin identity"
  assert_jq "$MUSE_MARKETPLACE" '.plugins[0].version' "$package_version" "Muse marketplace plugin version"
  assert_jq "$MUSE_MARKETPLACE" '.plugins[0].source' './' "Muse marketplace local source"
  assert_jq "$MUSE_MARKETPLACE" 'tostring | test("superpowers-dev|Jesse Vincent|fsck.com") | not' 'true' "Muse marketplace omits upstream branding and contacts"
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
  assert_jq "$KIMI" 'keys | sort == ["author", "description", "homepage", "interface", "keywords", "license", "name", "sessionStart", "skillInstructions", "skills", "version"]' 'true' ".kimi-plugin/plugin.json: upstream manifest shape"
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
  for import in '@./skills/using-maxi/SKILL.md' '@./skills/using-superpowers/references/gemini-tools.md'; do
    if grep -Fqx "$import" "$GEMINI_CONTEXT"; then
      echo "OK  [GEMINI.md: imports $import]"
    else
      echo "FAIL [GEMINI.md: imports $import]" >&2
      failures=$((failures + 1))
    fi
  done
fi

if [ -f "$DEVIN" ]; then
  assert_jq "$DEVIN" 'has("skills") or has("hooks") or has("commands") or has("sessionStart") or has("contextFileName") or has("inject")' 'false' ".devin-plugin/plugin.json: metadata-only"
fi

if bash "$ROOT/tests/check-pi-extension.sh"; then
  echo "OK  [Pi: project-gated first-session and post-compaction bootstrap]"
else
  echo "FAIL [Pi: project-gated first-session and post-compaction bootstrap]" >&2
  failures=$((failures + 1))
fi

summary_and_exit "declarative harness checks"
