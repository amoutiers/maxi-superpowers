#!/usr/bin/env bash
# Tests scripts/_update-vendored-md.sh in isolation against a VENDORED.md copy.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

failures=0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git -C "$TMP" init -q
cp "$ROOT/VENDORED.md" "$TMP/VENDORED.md"

mkdir -p "$TMP/scripts"
cp "$ROOT/scripts/_update-vendored-md.sh" "$TMP/scripts/"

TEST_TAG="v9.9.9"
TEST_DATE="2099-01-01"
(cd "$TMP" && bash scripts/_update-vendored-md.sh "$TEST_TAG" "$TEST_DATE")

assert_grep "$TMP/VENDORED.md" "^\- \*\*Pinned version\*\*: $TEST_TAG" \
  "bump-script: pinned version updated to $TEST_TAG"

assert_grep "$TMP/VENDORED.md" "^\- \*\*Last synced\*\*: $TEST_DATE" \
  "bump-script: last synced updated to $TEST_DATE"

assert_grep "$TMP/VENDORED.md" "^\- \*\*Upstream\*\*:" \
  "bump-script: upstream line unchanged"

if [ -f "$TMP/VENDORED.md.bak" ]; then
  echo "FAIL [bump-script: .bak file not cleaned up]" >&2
  failures=$((failures + 1))
else
  echo "OK  [bump-script: no .bak file]"
fi

summary_and_exit "bump script checks"
