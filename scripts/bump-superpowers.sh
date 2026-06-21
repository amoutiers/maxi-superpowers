#!/usr/bin/env bash
# Bump vendored superpowers to a new tag, then re-sync skills.
set -euo pipefail

TAG="${1:?usage: bash scripts/bump-superpowers.sh <tag>}"
UPSTREAM="https://github.com/obra/superpowers.git"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Pulling superpowers $TAG from $UPSTREAM ..."
# fetch.tagOpt=--no-tags stops the internal `git fetch` from auto-following and
# importing every upstream superpowers tag (v3.x–v6.x) into this repo's tag
# namespace — which would otherwise pollute it and get pushed by `git push --tags`.
git -c fetch.tagOpt=--no-tags subtree pull --prefix=vendor/superpowers "$UPSTREAM" "$TAG" --squash

echo "Syncing skills ..."
bash "$SCRIPT_DIR/sync-superpowers.sh"

echo "Updating VENDORED.md ..."
bash "$SCRIPT_DIR/_update-vendored-md.sh" "$TAG" "$(date +%Y-%m-%d)"

echo "Done. Remember to commit: git add vendor/superpowers skills/ VENDORED.md && git commit -m 'chore: bump superpowers to $TAG'"
