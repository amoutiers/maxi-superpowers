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

# Validate shared root plugin.json
ROOT_MANIFEST="$ROOT/plugin.json"
assert_file_exists "$ROOT_MANIFEST" "root plugin.json"
if [ -f "$ROOT_MANIFEST" ]; then
  assert_json_valid "$ROOT_MANIFEST" "root plugin.json: valid JSON"
  if diff -u "$MANIFEST" "$ROOT_MANIFEST" >/dev/null 2>&1; then
    echo "OK  [root plugin.json matches .claude-plugin/plugin.json]"
  else
    echo "FAIL [root plugin.json matches .claude-plugin/plugin.json]: files differ" >&2
    failures=$((failures + 1))
  fi
fi

ANTIGRAVITY_MANIFEST="$ROOT/.antigravity-plugin/plugin.json"
assert_file_exists "$ANTIGRAVITY_MANIFEST" ".antigravity-plugin/plugin.json"
if [ ! -L "$ANTIGRAVITY_MANIFEST" ]; then
  echo "FAIL [.antigravity-plugin/plugin.json]: expected symlink to root plugin.json" >&2
  failures=$((failures + 1))
elif [ "$(readlink "$ANTIGRAVITY_MANIFEST")" != "../plugin.json" ]; then
  echo "FAIL [.antigravity-plugin/plugin.json]: expected symlink target '../plugin.json', got '$(readlink "$ANTIGRAVITY_MANIFEST")'" >&2
  failures=$((failures + 1))
else
  echo "OK  [.antigravity-plugin/plugin.json]: symlink points to root plugin.json"
fi

for entry in skills hooks; do
  path="$ROOT/.antigravity-plugin/$entry"
  if [ ! -e "$path" ]; then
    echo "FAIL [.antigravity-plugin/$entry]: path not found: $path" >&2
    failures=$((failures + 1))
  elif [ ! -L "$path" ]; then
    echo "FAIL [.antigravity-plugin/$entry]: expected symlink to ../$entry" >&2
    failures=$((failures + 1))
  elif [ "$(readlink "$path")" != "../$entry" ]; then
    echo "FAIL [.antigravity-plugin/$entry]: expected symlink target '../$entry', got '$(readlink "$path")'" >&2
    failures=$((failures + 1))
  else
    echo "OK  [.antigravity-plugin/$entry]: symlink points to ../$entry"
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
