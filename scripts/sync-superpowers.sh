#!/usr/bin/env bash
# Sync vendored superpowers skills into skills/, preserving maxi-native skills.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
SRC="$ROOT/vendor/superpowers/skills"
DST="$ROOT/skills"

if [ ! -d "$SRC" ]; then
  echo "ERROR: $SRC does not exist — run 'git subtree add' first" >&2
  exit 1
fi

synced=0
for skill_dir in "$SRC"/*/; do
  name=$(basename "$skill_dir")
  rm -rf "$DST/$name"
  cp -r "$skill_dir" "$DST/$name"
  synced=$((synced + 1))
done

echo "Synced $synced skills from vendor/superpowers into skills/"
