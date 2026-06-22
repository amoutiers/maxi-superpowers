---
name: release
description: Use when releasing a new version of the maxi plugin
---

# Release the maxi Plugin

## Overview

Guide for releasing a new plugin version. The skill handles everything local: CHANGELOG, version bump, marketplace metadata, commit, tag, push. The GitHub Action only creates the GitHub Release — it makes no commits.

## Prerequisites

`git-cliff` must be installed locally:
```bash
brew install git-cliff   # macOS
```

## Steps

### 1. Pre-flight (non-optional — always run these first)

```bash
git status --porcelain
```

If this prints **anything at all** — stop. Ask the user whether those files should be committed before releasing.

Detect and run the project's test suite — use the first that exists:

```bash
if [ -f tests/run-all.sh ]; then
  bash tests/run-all.sh
elif [ -f package.json ] && grep -q '"test"' package.json; then
  npm test
elif [ -f Makefile ] && grep -q '^test:' Makefile; then
  make test
else
  echo "No test suite detected — skipping"
fi
```

For maxi-superpowers releases, also run the local doc consistency pass before bumping versions:

```text
Use the `.agents/skills/doc-consistency` skill to review authored docs for drift.
Claude users reach the same review through `.claude/skills/doc-consistency`.
```

Abort or resolve findings before continuing with the release.

Abort if tests fail.

### 2. Show commits since last tag

```bash
PREV_TAG=$(git tag --list 'v*' --sort=-version:refname | head -1)
git log "${PREV_TAG}..HEAD" --oneline
```

### 3. Suggest version bump

| Condition | Bump |
|-----------|------|
| Any `BREAKING CHANGE` footer | major |
| Any `feat:` commit | minor |
| Only `fix:`, `chore:`, `docs:`, `refactor:` | patch |

Ask the user to confirm or override.

### 4. Generate CHANGELOG entry locally (before tagging)

Do this before any commits — the entry must be in the tagged commit.

```bash
PREV_TAG=$(git tag --list 'v*' --sort=-version:refname | head -1)
if [ -n "$PREV_TAG" ]; then
  git cliff "${PREV_TAG}..HEAD" --tag "vX.Y.Z" --prepend CHANGELOG.md
else
  git cliff --tag "vX.Y.Z" --prepend CHANGELOG.md
fi
```

### 5. Bump version

Update `"version"` in every file that tracks it — check for all of these:

```
plugin.json                  # root plugin manifest
.claude-plugin/plugin.json   # Claude Code plugin manifest
.codex-plugin/plugin.json    # Codex plugin manifest
package.json                 # npm manifest
```

### 6. Commit release artifacts (commit 1 of 2)

```bash
git add CHANGELOG.md plugin.json .claude-plugin/plugin.json .codex-plugin/plugin.json package.json
git commit -m "chore(release): vX.Y.Z"
```

### 7. Update marketplace metadata and commit (commit 2 of 2)

Get the SHA of commit 1, update marketplace metadata, then make a second commit. The tag goes on this second commit.

```bash
RELEASE_SHA=$(git rev-parse HEAD)
node -e "
  const fs = require('fs');
  const releaseSha = process.argv[1];
  for (const p of ['.claude-plugin/marketplace.json', '.agents/plugins/marketplace.json']) {
    if (!fs.existsSync(p)) continue;
    const d = JSON.parse(fs.readFileSync(p, 'utf8'));
    const source = d.plugins?.[0]?.source;
    if (source && source.source !== 'local') {
      source.commit = releaseSha;
    }
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
  }
" "$RELEASE_SHA"
git add .claude-plugin/marketplace.json .agents/plugins/marketplace.json
git commit -m "chore(release): pin marketplace.json to vX.Y.Z"
```

Commit-pinned marketplace entries now point to commit 1 (version bump + CHANGELOG). That is intentional — users who install from a pinned marketplace get the plugin code from commit 1, which has everything they need.

### 8. Tag and push

```bash
PLUGIN_NAME=$(jq -r .name plugin.json)
git tag "vX.Y.Z"
git tag "${PLUGIN_NAME}--vX.Y.Z"
git push origin master
# Push ONLY this release's two tags — never `git push origin --tags`, which would
# also push any foreign tags in the local namespace (e.g. superpowers tags that a
# `subtree pull` may have imported) to the plugin's public repo.
git push origin "vX.Y.Z" "${PLUGIN_NAME}--vX.Y.Z"
```

### 9. Report

```bash
REMOTE=$(git remote get-url origin | sed 's/.*github.com[:/]//' | sed 's/\.git$//')
echo "Action running at: https://github.com/${REMOTE}/actions"
```

## What the Action does (read-only — no commits)

- Generates release notes with git-cliff
- Creates the GitHub Release on the tag
- Nothing else

## Common Mistakes

| Mistake | Correct behavior |
|---------|-----------------|
| Relying on the Action to update CHANGELOG.md | Generate locally in step 4, before tagging |
| Relying on the Action to pin marketplace.json | Update marketplace metadata locally in step 7, before tagging |
| One commit for everything | Two commits: (1) version+CHANGELOG, (2) marketplace.json pin — tag on commit 2 |
| `git status` without `--porcelain` | `--porcelain` catches untracked files that plain `git status` calls "clean" |
| Only bumping `plugin.json` + `package.json` | Also check `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` |
| Only creating `vX.Y.Z` tag | Always create BOTH `vX.Y.Z` AND `{name}--vX.Y.Z` |
