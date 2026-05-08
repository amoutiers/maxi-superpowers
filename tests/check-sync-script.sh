#!/usr/bin/env bash
# Tests scripts/sync-superpowers.sh against a synthetic vendor tree in a tmp dir.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

failures=0

# Setup: create tmp repo
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Initialize as git repo so git rev-parse --show-toplevel works
git -C "$TMP" init -q
git -C "$TMP" commit -q --allow-empty -m "init"

# Copy the sync script
mkdir -p "$TMP/scripts"
cp "$ROOT/scripts/sync-superpowers.sh" "$TMP/scripts/"

# Create synthetic vendor tree with 2 fake skills
mkdir -p "$TMP/vendor/superpowers/skills/fake-a"
echo "---
name: fake-a
description: Fake skill A
---
Content of fake-a" > "$TMP/vendor/superpowers/skills/fake-a/SKILL.md"

mkdir -p "$TMP/vendor/superpowers/skills/fake-b"
echo "---
name: fake-b
description: Fake skill B
---
Content of fake-b" > "$TMP/vendor/superpowers/skills/fake-b/SKILL.md"

# Pre-populate skills/ with:
# - a stale copy of fake-a (WRONG content — should be overwritten)
# - a maxi-native skill (should be left untouched)
mkdir -p "$TMP/skills/fake-a"
echo "STALE CONTENT" > "$TMP/skills/fake-a/SKILL.md"

mkdir -p "$TMP/skills/maxi-native"
echo "---
name: maxi-native
description: A maxi-native skill
---
Native content" > "$TMP/skills/maxi-native/SKILL.md"

# Run the sync script from the tmp repo (cd so git rev-parse finds TMP as root)
(cd "$TMP" && bash "$TMP/scripts/sync-superpowers.sh")

# Assert 1: skills/fake-a/SKILL.md is now identical to vendor copy
VENDOR_A="$TMP/vendor/superpowers/skills/fake-a/SKILL.md"
SYNCED_A="$TMP/skills/fake-a/SKILL.md"
if ! diff -q "$VENDOR_A" "$SYNCED_A" > /dev/null 2>&1; then
  echo "FAIL [sync-script: fake-a]: synced content differs from vendor" >&2
  failures=$((failures + 1))
else
  echo "OK  [sync-script: fake-a synced correctly]"
fi

# Assert 2: skills/fake-b/SKILL.md was created and is identical to vendor copy
VENDOR_B="$TMP/vendor/superpowers/skills/fake-b/SKILL.md"
SYNCED_B="$TMP/skills/fake-b/SKILL.md"
assert_file_exists "$SYNCED_B" "sync-script: fake-b created"
if [ -f "$SYNCED_B" ] && ! diff -q "$VENDOR_B" "$SYNCED_B" > /dev/null 2>&1; then
  echo "FAIL [sync-script: fake-b]: synced content differs from vendor" >&2
  failures=$((failures + 1))
else
  [ -f "$SYNCED_B" ] && echo "OK  [sync-script: fake-b synced correctly]"
fi

# Assert 3: maxi-native skill was NOT touched
NATIVE="$TMP/skills/maxi-native/SKILL.md"
if [ "$(cat "$NATIVE")" != "---
name: maxi-native
description: A maxi-native skill
---
Native content" ]; then
  echo "FAIL [sync-script: maxi-native]: native skill was modified by sync" >&2
  failures=$((failures + 1))
else
  echo "OK  [sync-script: maxi-native not touched]"
fi

summary_and_exit "sync script checks"
