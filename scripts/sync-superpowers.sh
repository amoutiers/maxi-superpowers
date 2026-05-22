#!/usr/bin/env bash
# Sync vendored superpowers skills into skills/; only overwrites vendored skills. Any maxi-native skills in skills/ (not present in vendor/superpowers/skills/) are left untouched.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
SRC="$ROOT/vendor/superpowers/skills"
DST="$ROOT/skills"

if [ ! -d "$SRC" ]; then
  echo "ERROR: $SRC does not exist — run 'git subtree add' first" >&2
  exit 1
fi

shopt -s nullglob
synced=0
for skill_dir in "$SRC"/*/; do
  name=$(basename "$skill_dir")
  [ -n "$name" ] || { echo "ERROR: empty skill name from '$skill_dir'" >&2; exit 1; }
  rm -rf "$DST/$name"
  cp -r "$skill_dir" "$DST/$name"
  synced=$((synced + 1))
done

if [ "$synced" -eq 0 ]; then
  echo "WARNING: 0 skills synced — check that vendor/superpowers/skills/ is populated" >&2
  exit 1
fi

echo "Synced $synced skills from vendor/superpowers into skills/"
