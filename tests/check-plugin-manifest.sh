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

# Aligned 1:1 with superpowers v6.1.1: no root plugin.json and no
# .antigravity-plugin/ package directory. Antigravity installs from the repo
# root and reads .claude-plugin/plugin.json (Claude Code manifest).
for stale in "$ROOT/plugin.json" "$ROOT/.antigravity-plugin"; do
  if [ -e "$stale" ]; then
    echo "FAIL [$(basename "$stale"): should be removed (Antigravity now installs from repo root)]" >&2
    failures=$((failures + 1))
  else
    echo "OK  [no $(basename "$stale")]"
  fi
done

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
