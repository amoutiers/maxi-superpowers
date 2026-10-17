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

missing_keys=$(jq -r '
  . as $obj |
  ["name","description","version","author","repository","license"] |
  map(select($obj[.] == null)) |
  join(", ")
' "$MANIFEST")
if [ -n "$missing_keys" ]; then
  echo "FAIL [plugin.json: required keys]: missing or null: $missing_keys" >&2
  failures=$((failures + 1))
else
  echo "OK  [plugin.json: all required keys present]"
fi

assert_jq "$MANIFEST" ".name" "maxi" "plugin.json: name is maxi"

assert_jq "$MANIFEST" ".version | test(\"^[0-9]+\\\\.[0-9]+\\\\.[0-9]+$\")" "true" "plugin.json: version is semver"

# The root plugin.json shim is obsolete; hosts use their native package manifest.
if [ -e "$ROOT/plugin.json" ]; then
  echo "FAIL [root plugin.json]: obsolete shim" >&2
  failures=$((failures + 1))
else
  echo "OK  [no root plugin.json]"
fi

# --- M4 (2026-05-30 review): package.json version must match the manifest ---
PKG="$ROOT/package.json"
assert_file_exists "$PKG" "package.json"
if [ -f "$PKG" ]; then
  manifest_ver="$(jq -r '.version' "$MANIFEST")"
  pkg_ver="$(jq -r '.version' "$PKG")"
  if [ "$manifest_ver" = "$pkg_ver" ]; then
    echo "OK  [package.json version matches plugin.json]"
  else
    echo "FAIL [package.json version matches plugin.json]: $pkg_ver != $manifest_ver" >&2
    failures=$((failures + 1))
  fi
fi

summary_and_exit "plugin manifest checks"
