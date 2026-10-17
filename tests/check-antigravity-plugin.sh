#!/usr/bin/env bash
# Validate the native package and discovery boundary without requiring a host install.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"
MANIFEST="$ROOT/.antigravity-plugin/plugin.json"
SKILL="$ROOT/skills/using-maxi/SKILL.md"
failures=0

assert_file_exists "$MANIFEST" "Antigravity native manifest"
if [ -f "$MANIFEST" ]; then
  assert_json_valid "$MANIFEST" "Antigravity manifest"
  assert_jq "$MANIFEST" '.name' 'maxi' "Antigravity plugin identity"
  assert_jq "$MANIFEST" '.version' "$(jq -r '.version' "$ROOT/package.json")" "Antigravity package version"
  assert_jq "$MANIFEST" '.author' "$(jq -r '.author' "$ROOT/.claude-plugin/plugin.json")" "Antigravity canonical author"
  assert_jq "$MANIFEST" '.description' "$(jq -r '.description' "$ROOT/package.json")" "Antigravity canonical description"
  assert_jq "$MANIFEST" '.displayName | length > 0' true "Antigravity display name"
  assert_jq "$MANIFEST" '.suggestedPrompts | length > 0 and all(.[]; type == "string" and length > 0)' true "Antigravity suggested prompts"
  assert_jq "$MANIFEST" '.logo' 'assets/logo.svg' "Antigravity reuses the existing logo"
  assert_file_exists "$ROOT/$(jq -r '.logo' "$MANIFEST")" "Antigravity logo resolves from package root"
  assert_jq "$MANIFEST" 'has("hooks") or has("rules") or has("category")' false "Antigravity avoids unsupported manifest fields"
fi

# Native discovery surfaces the description before loading the project-aware skill body.
assert_grep "$SKILL" '^description: Use when starting any conversation' "discovery requests the conversation-start check"
assert_grep "$SKILL" 'If.*docs/maxi/.*does not exist' "bootstrap checks the project before activation"
assert_grep "$SKILL" 'explicit Maxi command.*prerequisites' "explicit commands retain their prerequisites"
for shim in .antigravity-plugin/hooks .antigravity-plugin/rules .agents/rules; do
  if [ -e "$ROOT/$shim" ]; then
    echo "FAIL [$shim]: unsupported Antigravity bootstrap shim" >&2
    failures=$((failures + 1))
  else
    echo "OK  [no $shim]"
  fi
done
summary_and_exit "Antigravity native package checks"
