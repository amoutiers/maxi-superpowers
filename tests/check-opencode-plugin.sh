#!/usr/bin/env bash
# Validates .opencode/plugins/maxi.js structure and required behavior.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

PLUGIN="$ROOT/.opencode/plugins/maxi.js"
INSTALL="$ROOT/.opencode/INSTALL.md"
failures=0

assert_file_exists "$PLUGIN" ".opencode/plugins/maxi.js"
[ ! -f "$PLUGIN" ] && summary_and_exit "opencode plugin checks"

assert_file_exists "$INSTALL" ".opencode/INSTALL.md"

# Check that the plugin exports MaxiPlugin
if grep -q 'export const MaxiPlugin' "$PLUGIN"; then
  echo "OK  [maxi.js: exports MaxiPlugin]"
else
  echo "FAIL [maxi.js: exports MaxiPlugin]: export not found" >&2
  failures=$((failures + 1))
fi

# Check that config hook is present
if grep -q "config:" "$PLUGIN"; then
  echo "OK  [maxi.js: has config hook]"
else
  echo "FAIL [maxi.js: has config hook]: config hook not found" >&2
  failures=$((failures + 1))
fi

# Check that experimental.chat.messages.transform hook is present
if grep -q "experimental.chat.messages.transform" "$PLUGIN"; then
  echo "OK  [maxi.js: has transform hook]"
else
  echo "FAIL [maxi.js: has transform hook]: transform hook not found" >&2
  failures=$((failures + 1))
fi

# Check bootstrap caching logic
if grep -q "_bootstrapCache" "$PLUGIN"; then
  echo "OK  [maxi.js: has bootstrap caching]"
else
  echo "FAIL [maxi.js: has bootstrap caching]: caching logic not found" >&2
  failures=$((failures + 1))
fi

# Check conditional injection (docs/maxi/ check)
if grep -q "docs/maxi" "$PLUGIN"; then
  echo "OK  [maxi.js: has conditional injection]"
else
  echo "FAIL [maxi.js: has conditional injection]: docs/maxi check not found" >&2
  failures=$((failures + 1))
fi

# Check that it loads using-maxi skill
if grep -q "using-maxi" "$PLUGIN"; then
  echo "OK  [maxi.js: loads using-maxi skill]"
else
  echo "FAIL [maxi.js: loads using-maxi skill]: using-maxi reference not found" >&2
  failures=$((failures + 1))
fi

# Check tool mapping for OpenCode
if grep -q "Tool Mapping for OpenCode" "$PLUGIN"; then
  echo "OK  [maxi.js: has OpenCode tool mapping]"
else
  echo "FAIL [maxi.js: has OpenCode tool mapping]: tool mapping not found" >&2
  failures=$((failures + 1))
fi

summary_and_exit "opencode plugin checks"
