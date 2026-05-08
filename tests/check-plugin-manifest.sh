#!/usr/bin/env bash
# Validates .claude-plugin/plugin.json structure and required fields.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

MANIFEST="$ROOT/.claude-plugin/plugin.json"
failures=0

assert_file_exists "$MANIFEST" "plugin.json"
[ ! -f "$MANIFEST" ] && summary_and_exit "plugin manifest checks"

assert_json_valid "$MANIFEST" "plugin.json: valid JSON"

REQUIRED_KEYS=(name description version author repository license)
for key in "${REQUIRED_KEYS[@]}"; do
  assert_jq "$MANIFEST" ".${key} | . != null" "true" "plugin.json: has ${key}"
done

assert_jq "$MANIFEST" ".name" "maxi" "plugin.json: name is maxi"

# semver shape check
assert_jq "$MANIFEST" ".version | test(\"^[0-9]+\\\\.[0-9]+\\\\.[0-9]+$\")" "true" "plugin.json: version is semver"

summary_and_exit "plugin manifest checks"
