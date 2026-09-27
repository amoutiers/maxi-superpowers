#!/usr/bin/env bash
# Guards local release instructions for maxi-specific pre-flight requirements.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

AGENTS_SKILL_DIR="$ROOT/.agents/skills/release"
CLAUDE_SKILL_DIR="$ROOT/.claude/skills/release"
SKILL="$AGENTS_SKILL_DIR/SKILL.md"
failures=0

assert_file_exists "$SKILL" ".agents release skill"

if [ ! -L "$CLAUDE_SKILL_DIR" ]; then
  echo "FAIL [.claude release skill]: expected symlink to .agents release skill" >&2
  failures=$((failures + 1))
elif [ "$(readlink "$CLAUDE_SKILL_DIR")" != "../../.agents/skills/release" ]; then
  echo "FAIL [.claude release skill]: expected symlink target '../../.agents/skills/release', got '$(readlink "$CLAUDE_SKILL_DIR")'" >&2
  failures=$((failures + 1))
else
  echo "OK  [.claude release skill]: symlink points to .agents release skill"
fi

assert_file_exists "$CLAUDE_SKILL_DIR/SKILL.md" ".claude release skill resolves"

if [ -f "$SKILL" ]; then
  BUMP_SECTION=$(sed -n '/^### 5\. Bump version$/,/^### 6\. Commit release artifacts/p' "$SKILL")
  STAGING_SECTION=$(sed -n '/^### 6\. Commit release artifacts/,/^### 7\. Update marketplace metadata/p' "$SKILL")
  MARKETPLACE_SECTION=$(sed -n '/^### 7\. Update marketplace metadata/,/^### 8\. Tag and push/p' "$SKILL")

  for manifest in \
    .claude-plugin/plugin.json \
    .codex-plugin/plugin.json \
    .cursor-plugin/plugin.json \
    .devin-plugin/plugin.json \
    .hermes-plugin/plugin.yaml \
    .kimi-plugin/plugin.json \
    .muse-plugin/plugin.json \
    gemini-extension.json \
    package.json; do
    if grep -Fq "$manifest" <<<"$BUMP_SECTION"; then
      echo "OK  [release skill: bumps $manifest]"
    else
      echo "FAIL [release skill: bumps $manifest]" >&2
      failures=$((failures + 1))
    fi

    if grep -Fq "$manifest" <<<"$STAGING_SECTION"; then
      echo "OK  [release skill: stages $manifest]"
    else
      echo "FAIL [release skill: stages $manifest]" >&2
      failures=$((failures + 1))
    fi
  done

  assert_not_grep "$SKILL" '^plugin\.json[[:space:]]' "release skill: no root plugin.json inventory entry"
  assert_grep "$SKILL" "doc-consistency" "release skill: runs doc-consistency before release"
  assert_grep "$SKILL" ".claude/skills/doc-consistency" "release skill: documents Claude doc-consistency path"
  assert_grep "$SKILL" ".agents/skills/doc-consistency" "release skill: documents .agents doc-consistency path"
  assert_grep "$SKILL" "bash tests/run-all.sh" "release skill: still runs fast tier"
  assert_grep "$SKILL" "Abort if tests fail" "release skill: keeps test failure abort"
  assert_grep "$SKILL" 'git tag "vX.Y.Z"' "release skill: creates the canonical version tag"
  assert_not_grep "$SKILL" 'git tag.*--vX.Y.Z' "release skill: never creates a plugin-prefixed tag"
  assert_grep "$SKILL" 'git push origin "vX.Y.Z"' "release skill: pushes only the canonical version tag"

  if grep -Fq 'git add .claude-plugin/marketplace.json .agents/plugins/marketplace.json .muse-plugin/marketplace.json' <<<"$MARKETPLACE_SECTION"; then
    echo "OK  [release skill: stages all marketplaces in commit 2]"
  else
    echo "FAIL [release skill: stages all marketplaces in commit 2]" >&2
    failures=$((failures + 1))
  fi
  if grep -Fq '.muse-plugin/marketplace.json' <<<"$MARKETPLACE_SECTION"; then
    echo "OK  [release skill: updates Muse marketplace version in commit 2]"
  else
    echo "FAIL [release skill: updates Muse marketplace version in commit 2]" >&2
    failures=$((failures + 1))
  fi

  # Execute the release skill's actual marketplace update against a local fixture.
  release_js="$(sed -n '/^node -e "$/,/^" "\$RELEASE_SHA"$/p' "$SKILL" | sed '1d;$d')"
  if [ -z "$release_js" ]; then
    echo "FAIL [release skill: marketplace update snippet extractable]" >&2
    failures=$((failures + 1))
  elif ! command -v node >/dev/null 2>&1; then
    echo "SKIP [release skill: marketplace update behavior] (node not installed)"
  else
    fixture="$(mktemp -d)"
    mkdir -p "$fixture/.claude-plugin" "$fixture/.agents/plugins" "$fixture/.muse-plugin"
    printf '%s\n' '{"name":"maxi","version":"9.8.7"}' > "$fixture/.claude-plugin/plugin.json"
    printf '%s\n' '{"plugins":[{"name":"decoy","source":{"source":"github","commit":"keep"}},{"name":"maxi","source":{"source":"github","commit":"old"}}]}' > "$fixture/.claude-plugin/marketplace.json"
    printf '%s\n' '{"plugins":[{"name":"decoy","source":{"source":"github","commit":"keep"}},{"name":"maxi","source":{"source":"local","path":"./plugins/maxi"}}]}' > "$fixture/.agents/plugins/marketplace.json"
    printf '%s\n' '{"plugins":[{"name":"maxi","version":"1.0.0","source":"./"}]}' > "$fixture/.muse-plugin/marketplace.json"
    if (cd "$fixture" && node -e "$release_js" '1234567'); then
      if jq -e '.plugins[0] == {"name":"decoy","source":{"source":"github","commit":"keep"}} and .plugins[1].source.commit == "1234567"' "$fixture/.claude-plugin/marketplace.json" >/dev/null &&
        jq -e '.plugins[0] == {"name":"decoy","source":{"source":"github","commit":"keep"}} and .plugins[1].source == {"source":"local","path":"./plugins/maxi"}' "$fixture/.agents/plugins/marketplace.json" >/dev/null &&
        jq -e '.plugins[0] == {"name":"maxi","version":"9.8.7","source":"./"}' "$fixture/.muse-plugin/marketplace.json" >/dev/null; then
        echo "OK  [release skill: matches plugin identity and updates only supported fields]"
      else
        echo "FAIL [release skill: marketplace update behavior]" >&2
        failures=$((failures + 1))
      fi
    else
      echo "FAIL [release skill: marketplace update snippet executes]" >&2
      failures=$((failures + 1))
    fi
    rm -rf "$fixture"
  fi
fi

assert_grep "$ROOT/.gitignore" '^\.superpowers/$' ".superpowers/: execution scratch is ignored"

summary_and_exit "release skill checks"
