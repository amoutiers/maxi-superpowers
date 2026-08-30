#!/usr/bin/env bash
# Tests scripts/sync-superpowers.sh against a synthetic vendor tree in a tmp dir.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

failures=0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

make_attack_fixture() {
  local dir="$1"
  git -C "$dir" init -q
  mkdir -p "$dir/scripts" "$dir/vendor/superpowers/skills/current" "$dir/skills/old"
  cp "$ROOT/scripts/sync-superpowers.sh" "$dir/scripts/"
  printf '%s\n' current > "$dir/vendor/superpowers/skills/current/SKILL.md"
  printf '%s\n' old > "$dir/skills/old/SKILL.md"
  printf '%s\n' sentinel > "$dir/.git/audit-sentinel"
}

assert_rejected_ledger() {
  local label="$1"
  shift
  local case_dir="$TMP/$label"
  mkdir -p "$case_dir"
  make_attack_fixture "$case_dir"
  printf '%s\n' "$@" > "$case_dir/vendor/superpowers/.synced-skills"
  if (cd "$case_dir" && bash scripts/sync-superpowers.sh >/dev/null 2>&1); then
    echo "FAIL [$label: unsafe ledger accepted]" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label: unsafe ledger rejected]"
  fi
  assert_file_exists "$case_dir/.git/audit-sentinel" "$label: git sentinel preserved"
  assert_file_exists "$case_dir/skills/old/SKILL.md" "$label: no prior orphan removal"
}

assert_rejected_ledger traversal old ../.git
assert_rejected_ledger absolute old /tmp/escape
assert_rejected_ledger separator old nested/name
assert_rejected_ledger dot old .
assert_rejected_ledger dotdot old ..
assert_rejected_ledger control old $'bad\tname'
assert_rejected_ledger duplicate old old

positive_dir="$TMP/positive"
mkdir -p "$positive_dir"
git -C "$positive_dir" init -q
mkdir -p "$positive_dir/scripts" "$positive_dir/vendor/superpowers/skills" "$positive_dir/skills"
cp "$ROOT/scripts/sync-superpowers.sh" "$positive_dir/scripts/"
for skill in old test-driven-development using_superpowers.v1; do
  mkdir -p "$positive_dir/vendor/superpowers/skills/$skill"
  printf '%s\n' "$skill" > "$positive_dir/vendor/superpowers/skills/$skill/SKILL.md"
done
printf '%s\n' old test-driven-development using_superpowers.v1 > "$positive_dir/vendor/superpowers/.synced-skills"
(cd "$positive_dir" && bash scripts/sync-superpowers.sh >/dev/null)
assert_file_exists "$positive_dir/skills/using_superpowers.v1/SKILL.md" "positive ledger: portable names accepted"

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
