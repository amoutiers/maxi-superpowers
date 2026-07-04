#!/usr/bin/env bash
# Validates the Pi extension (.pi/extensions/maxi.ts) and package.json pi section.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

PI_EXT="$ROOT/.pi/extensions/maxi.ts"
PKG="$ROOT/package.json"
failures=0

assert_file_exists "$PI_EXT" ".pi/extensions/maxi.ts"
[ ! -f "$PI_EXT" ] && summary_and_exit "pi extension checks"

assert_file_exists "$PKG" "package.json"
[ ! -f "$PKG" ] && summary_and_exit "pi extension checks"

assert_grep "$PI_EXT" "maxiPiExtension\|maxi:" "maxi.ts: defines maxi extension"
assert_grep "$PI_EXT" "using-maxi" "maxi.ts: loads using-maxi skill"
assert_grep "$PI_EXT" "You have maxi." "maxi.ts: carries maxi bootstrap header"
assert_grep "$PI_EXT" '<EXTREMELY_IMPORTANT>' "maxi.ts: wraps in EXTREMELY_IMPORTANT"
assert_grep "$PI_EXT" "skillsDir\|skillPaths" "maxi.ts: registers skills dir"

assert_jq "$PKG" '.pi.extensions | index("./.pi/extensions/maxi.ts") != null' "true" "package.json: pi.extensions entry"
assert_jq "$PKG" '.pi.skills | index("./skills") != null' "true" "package.json: pi.skills entry"
assert_jq "$PKG" '.type == "module"' "true" "package.json: type is module"
assert_jq "$PKG" '.main == ".opencode/plugins/maxi.js"' "true" "package.json: main points to maxi.js"

summary_and_exit "pi extension checks"