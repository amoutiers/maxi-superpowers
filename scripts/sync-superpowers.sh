#!/usr/bin/env bash
# Sync vendored superpowers skills into skills/; only overwrites vendored skills. Any maxi-native skills in skills/ (not present in vendor/superpowers/skills/) are left untouched.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
VENDOR_DIR="$ROOT/vendor/superpowers"
SRC="$VENDOR_DIR/skills"
DST="$ROOT/skills"

if [ ! -d "$SRC" ]; then
  echo "ERROR: $SRC does not exist — run 'git subtree add' first" >&2
  exit 1
fi

shopt -s nullglob

SYNCED_LIST="$VENDOR_DIR/.synced-skills"

# Remove orphaned vendored skills (skills that were synced before but no longer exist upstream)
if [ -f "$SYNCED_LIST" ]; then
  while IFS= read -r orphan; do
    [ -z "$orphan" ] && continue
    if [ ! -d "$SRC/$orphan" ] && [ -d "$DST/$orphan" ]; then
      echo "Removing orphaned vendored skill: $orphan"
      rm -rf "$DST/$orphan"
    fi
  done < "$SYNCED_LIST"
fi

synced=0
synced_names=()
for skill_dir in "$SRC"/*/; do
  name=$(basename "$skill_dir")
  [ -n "$name" ] || { echo "ERROR: empty skill name from '$skill_dir'" >&2; exit 1; }
  rm -rf "$DST/$name"
  cp -r "$skill_dir" "$DST/$name"
  synced=$((synced + 1))
  synced_names+=("$name")
done

if [ "$synced" -eq 0 ]; then
  echo "WARNING: 0 skills synced — check that vendor/superpowers/skills/ is populated" >&2
  exit 1
fi

# Update synced skills list for next run
printf '%s\n' "${synced_names[@]}" > "$SYNCED_LIST"

echo "Synced $synced skills from vendor/superpowers into skills/"
