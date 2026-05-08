#!/usr/bin/env bash
# Tests scripts/sync-superpowers.sh against a synthetic vendor tree in a tmp dir.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

failures=0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git -C "$TMP" init -q

mkdir -p "$TMP/scripts"
cp "$ROOT/scripts/sync-superpowers.sh" "$TMP/scripts/"

mkdir -p "$TMP/vendor/superpowers/skills/fake-a"
printf -- "---\nname: fake-a\ndescription: Fake skill A\n---\nContent of fake-a\n" \
  > "$TMP/vendor/superpowers/skills/fake-a/SKILL.md"

mkdir -p "$TMP/vendor/superpowers/skills/fake-b"
printf -- "---\nname: fake-b\ndescription: Fake skill B\n---\nContent of fake-b\n" \
  > "$TMP/vendor/superpowers/skills/fake-b/SKILL.md"

mkdir -p "$TMP/skills/fake-a"
echo "STALE CONTENT" > "$TMP/skills/fake-a/SKILL.md"

mkdir -p "$TMP/skills/maxi-native"
printf -- "---\nname: maxi-native\ndescription: A maxi-native skill\n---\nNative content\n" \
  > "$TMP/skills/maxi-native/SKILL.md"
NATIVE_BEFORE="$TMP/native_before.md"
cp "$TMP/skills/maxi-native/SKILL.md" "$NATIVE_BEFORE"

(cd "$TMP" && bash "$TMP/scripts/sync-superpowers.sh")

assert_files_equal \
  "$TMP/vendor/superpowers/skills/fake-a/SKILL.md" \
  "$TMP/skills/fake-a/SKILL.md" \
  "sync-script: fake-a synced correctly"

assert_file_exists "$TMP/skills/fake-b/SKILL.md" "sync-script: fake-b created"
assert_files_equal \
  "$TMP/vendor/superpowers/skills/fake-b/SKILL.md" \
  "$TMP/skills/fake-b/SKILL.md" \
  "sync-script: fake-b synced correctly"

assert_files_equal \
  "$NATIVE_BEFORE" \
  "$TMP/skills/maxi-native/SKILL.md" \
  "sync-script: maxi-native not touched"

summary_and_exit "sync script checks"
