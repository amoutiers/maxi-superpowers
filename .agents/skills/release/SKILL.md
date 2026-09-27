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

Update every version-bearing manifest. The JSON files use `"version"`; the
Hermes YAML manifest uses `version:`:

```
.claude-plugin/plugin.json   # Claude Code plugin manifest
.codex-plugin/plugin.json    # Codex plugin manifest
.cursor-plugin/plugin.json   # Cursor plugin manifest
.devin-plugin/plugin.json    # Devin plugin manifest
.hermes-plugin/plugin.yaml   # Hermes plugin manifest
.kimi-plugin/plugin.json     # Kimi Code plugin manifest
.muse-plugin/plugin.json     # Muse plugin manifest
gemini-extension.json        # Gemini extension manifest
package.json                 # npm and Pi package manifest
```

### 6. Commit release artifacts (commit 1 of 2)

```bash
git add CHANGELOG.md .claude-plugin/plugin.json .codex-plugin/plugin.json \
  .cursor-plugin/plugin.json .devin-plugin/plugin.json .hermes-plugin/plugin.yaml \
  .kimi-plugin/plugin.json .muse-plugin/plugin.json gemini-extension.json package.json
git commit -m "chore(release): vX.Y.Z"
```

### 7. Update marketplace metadata and commit (commit 2 of 2)

Get the SHA of commit 1, update marketplace metadata and the Muse marketplace version, then make a second commit. The tag goes on this second commit. Read the plugin name and version from `.claude-plugin/plugin.json`; select that named entry in each marketplace. Pin only remote object sources. The Muse source is the local `./` string and has no commit pin.

```bash
RELEASE_SHA=$(git rev-parse HEAD)
node -e "
  const fs = require('fs');
  const releaseSha = process.argv[1];
  const plugin = JSON.parse(fs.readFileSync('.claude-plugin/plugin.json', 'utf8'));
  const paths = ['.claude-plugin/marketplace.json', '.agents/plugins/marketplace.json', '.muse-plugin/marketplace.json'];
  const documents = paths.map(p => [p, JSON.parse(fs.readFileSync(p, 'utf8'))]);
  for (const [p, d] of documents) {
    const entry = d.plugins?.find(item => item.name === plugin.name);
    if (!entry) throw new Error('Plugin ' + plugin.name + ' missing from ' + p);
    if (p === '.muse-plugin/marketplace.json') entry.version = plugin.version;
    const source = entry.source;
    if (source && typeof source === 'object' && source.source !== 'local') {
      source.commit = releaseSha;
    }
  }
  for (const [p, d] of documents) {
    fs.writeFileSync(p, JSON.stringify(d, null, 2) + '\n');
  }
" "$RELEASE_SHA"
git add .claude-plugin/marketplace.json .agents/plugins/marketplace.json .muse-plugin/marketplace.json
git commit -m "chore(release): pin marketplace.json to vX.Y.Z"
```

Commit-pinned marketplace entries now point to commit 1 (version bump + CHANGELOG). Users who install from a pinned marketplace get that code. The Muse marketplace keeps its local `./` source and receives the new version in commit 2.

### 8. Tag and push

```bash
git tag "vX.Y.Z"
git push origin master
# Push only the canonical release tag. Never use `git push origin --tags`, which
# could also publish unrelated local tags (for example imported superpowers tags).
git push origin "vX.Y.Z"
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
| Only bumping a subset of manifests | Bump and stage all nine manifests listed in step 5 |
| Creating a plugin-prefixed tag | Create and push only the canonical `vX.Y.Z` tag |
