#!/usr/bin/env bash
# Validates Codex plugin manifest and marketplace structure.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

MANIFEST="$ROOT/.codex-plugin/plugin.json"
PACKAGE="$ROOT/package.json"
MARKETPLACE="$ROOT/.agents/plugins/marketplace.json"
RELEASE_SKILL="$ROOT/.agents/skills/release/SKILL.md"
PLUGIN_LINK="$ROOT/plugins/maxi"
failures=0

assert_file_exists "$MANIFEST" ".codex-plugin/plugin.json"
assert_file_exists "$PACKAGE" "package.json"
if [ -f "$MANIFEST" ]; then
  assert_json_valid "$MANIFEST" ".codex-plugin/plugin.json: valid JSON"
  assert_jq "$MANIFEST" ".name" "maxi" ".codex-plugin/plugin.json: name is maxi"
  assert_jq "$MANIFEST" ".version | test(\"^[0-9]+\\\\.[0-9]+\\\\.[0-9]+([+-].*)?$\")" "true" ".codex-plugin/plugin.json: version is semver-compatible"
  if [ -f "$PACKAGE" ]; then
    assert_jq "$MANIFEST" '.version' "$(jq -r '.version' "$PACKAGE")" ".codex-plugin/plugin.json: version matches package.json"
  fi
  assert_jq "$MANIFEST" ".skills" "./skills" ".codex-plugin/plugin.json: skills path"
  assert_jq "$MANIFEST" ".hooks == {}" "true" ".codex-plugin/plugin.json: hooks is empty object (Codex native skill discovery)"
  assert_jq "$MANIFEST" ".interface.displayName" "maxi" ".codex-plugin/plugin.json: interface displayName"
  assert_jq "$MANIFEST" ".interface.defaultPrompt | length > 0" "true" ".codex-plugin/plugin.json: default prompts"
fi

assert_file_exists "$MARKETPLACE" ".agents/plugins/marketplace.json"
if [ -f "$MARKETPLACE" ]; then
  assert_json_valid "$MARKETPLACE" ".agents/plugins/marketplace.json: valid JSON"
  assert_jq "$MARKETPLACE" ".name" "maxi-superpowers" ".agents marketplace: name"
  assert_jq "$MARKETPLACE" ".plugins | length" "1" ".agents marketplace: one plugin"
  assert_jq "$MARKETPLACE" ".plugins[0].name" "maxi" ".agents marketplace: plugin name"
  assert_jq "$MARKETPLACE" ".plugins[0].source.source" "local" ".agents marketplace: local source"
  assert_jq "$MARKETPLACE" ".plugins[0].source.path" "./plugins/maxi" ".agents marketplace: plugin source path"
  assert_jq "$MARKETPLACE" ".plugins[0].policy.installation" "AVAILABLE" ".agents marketplace: install policy"
  assert_jq "$MARKETPLACE" ".plugins[0].policy.authentication" "ON_INSTALL" ".agents marketplace: auth policy"
fi

assert_file_exists "$RELEASE_SKILL" ".agents release skill"
if [ -f "$RELEASE_SKILL" ]; then
  assert_grep "$RELEASE_SKILL" ".codex-plugin/plugin.json" ".agents release skill: uses .codex-plugin manifest path"
  assert_grep "$RELEASE_SKILL" ".agents/plugins/marketplace.json" ".agents release skill: uses .agents marketplace path"
  assert_not_grep "$RELEASE_SKILL" ".Codex-plugin" ".agents release skill: no stale .Codex-plugin path"
fi

if [ ! -L "$PLUGIN_LINK" ]; then
  echo "FAIL [plugins/maxi]: expected symlink to repository root" >&2
  failures=$((failures + 1))
elif [ "$(readlink "$PLUGIN_LINK")" != ".." ]; then
  echo "FAIL [plugins/maxi]: expected symlink target '..', got '$(readlink "$PLUGIN_LINK")'" >&2
  failures=$((failures + 1))
else
  echo "OK  [plugins/maxi]: symlink points to repository root"
fi

summary_and_exit "Codex plugin checks"
