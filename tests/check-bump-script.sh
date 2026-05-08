#!/usr/bin/env bash
# Tests scripts/_update-vendored-md.sh in isolation against a VENDORED.md copy.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

failures=0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Set up tmp as a git repo with VENDORED.md
git -C "$TMP" init -q
git -C "$TMP" commit -q --allow-empty -m "init"
cp "$ROOT/VENDORED.md" "$TMP/VENDORED.md"
git -C "$TMP" add VENDORED.md
git -C "$TMP" commit -q -m "add VENDORED.md"

# Copy the update script
mkdir -p "$TMP/scripts"
cp "$ROOT/scripts/_update-vendored-md.sh" "$TMP/scripts/"

# Run the update script with a synthetic tag and date
TEST_TAG="v9.9.9"
TEST_DATE="2099-01-01"
(cd "$TMP" && bash scripts/_update-vendored-md.sh "$TEST_TAG" "$TEST_DATE")

# Assert: Pinned version line updated
if ! grep -q "^\- \*\*Pinned version\*\*: $TEST_TAG" "$TMP/VENDORED.md"; then
  echo "FAIL [bump-script: pinned version]: expected '**Pinned version**: $TEST_TAG'" >&2
  failures=$((failures + 1))
else
  echo "OK  [bump-script: pinned version updated to $TEST_TAG]"
fi

# Assert: Last synced line updated
if ! grep -q "^\- \*\*Last synced\*\*: $TEST_DATE" "$TMP/VENDORED.md"; then
  echo "FAIL [bump-script: last synced]: expected '**Last synced**: $TEST_DATE'" >&2
  failures=$((failures + 1))
else
  echo "OK  [bump-script: last synced updated to $TEST_DATE]"
fi

# Assert: Upstream line NOT changed
if ! grep -q "^\- \*\*Upstream\*\*:" "$TMP/VENDORED.md"; then
  echo "FAIL [bump-script: upstream line removed unexpectedly]" >&2
  failures=$((failures + 1))
else
  echo "OK  [bump-script: upstream line unchanged]"
fi

# Assert: no .bak file left
if [ -f "$TMP/VENDORED.md.bak" ]; then
  echo "FAIL [bump-script: .bak file not cleaned up]" >&2
  failures=$((failures + 1))
else
  echo "OK  [bump-script: no .bak file]"
fi

summary_and_exit "bump script checks"
