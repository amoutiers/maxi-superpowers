#!/usr/bin/env bash
# Validates VENDORED.md has all required structural lines.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

VENDORED="$ROOT/VENDORED.md"
failures=0

assert_file_exists "$VENDORED" "VENDORED.md"
[ ! -f "$VENDORED" ] && summary_and_exit "VENDORED.md checks"

assert_grep "$VENDORED" "^- \*\*Upstream\*\*:" "VENDORED.md: Upstream line"
assert_grep "$VENDORED" "^- \*\*Pinned version\*\*: v[0-9]" "VENDORED.md: Pinned version (v + semver)"
assert_grep "$VENDORED" "^- \*\*Subtree prefix\*\*: vendor/superpowers/" "VENDORED.md: Subtree prefix"
assert_grep "$VENDORED" "^- \*\*Last synced\*\*: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" "VENDORED.md: Last synced (YYYY-MM-DD)"

summary_and_exit "VENDORED.md checks"
