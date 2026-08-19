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

# --- H3 (2026-05-30 review): bootstrap dir must derive from the project directory ---
if grep -q "path.join(process.cwd(), 'docs/maxi')" "$PLUGIN"; then
  echo "FAIL [maxi.js: maxi dir not keyed on process.cwd()]: still uses process.cwd()" >&2
  failures=$((failures + 1))
else
  echo "OK  [maxi.js: maxi dir not keyed on process.cwd()]"
fi
assert_grep "$PLUGIN" "directory || process.cwd()" "maxi.js: bootstrap falls back via directory param"

# --- M1 (2026-05-30 review): the plugin must be syntactically valid JS ---
if command -v node >/dev/null 2>&1; then
  if node --input-type=module --check < "$PLUGIN" 2>/dev/null; then
    echo "OK  [maxi.js: valid JS syntax (node --check)]"
  else
    echo "FAIL [maxi.js: valid JS syntax (node --check)]" >&2
    failures=$((failures + 1))
  fi
else
  echo "SKIP [maxi.js: valid JS syntax] (node not installed)"
fi

# Behavior: cache must not let a non-maxi project suppress a later maxi project.
if command -v node >/dev/null 2>&1; then
  TMP_OC="$(mktemp -d)"
  mkdir -p "$TMP_OC/maxi/docs/maxi" "$TMP_OC/file/docs" "$TMP_OC/cyclic/docs" "$TMP_OC/dangling/docs" "$TMP_OC/plain"
  printf '%s\n' 'not a directory' > "$TMP_OC/file/docs/maxi"
  ln -s maxi "$TMP_OC/cyclic/docs/maxi"
  ln -s missing "$TMP_OC/dangling/docs/maxi"
  if node --input-type=module - "$PLUGIN" "$TMP_OC/plain" "$TMP_OC/file" "$TMP_OC/cyclic" "$TMP_OC/dangling" "$TMP_OC/maxi" <<'NODE'
const [pluginPath, plainDir, fileDir, cyclicDir, danglingDir, maxiDir] = process.argv.slice(2);
const mod = await import(`file://${pluginPath}`);

function output(text) {
  return { messages: [{ info: { role: 'user' }, parts: [{ type: 'text', text }] }] };
}

const plainPlugin = await mod.MaxiPlugin({ directory: plainDir });
const plainOutput = output('plain');
await plainPlugin['experimental.chat.messages.transform']({}, plainOutput);
if (plainOutput.messages[0].parts.some(p => p.type === 'text' && p.text.includes('You have maxi.'))) {
  throw new Error('bootstrap injected into non-maxi project');
}

const filePlugin = await mod.MaxiPlugin({ directory: fileDir });
const fileOutput = output('file');
await filePlugin['experimental.chat.messages.transform']({}, fileOutput);
if (fileOutput.messages[0].parts.some(p => p.type === 'text' && p.text.includes('You have maxi.'))) {
  throw new Error('bootstrap injected when docs/maxi is a file');
}

const cyclicPlugin = await mod.MaxiPlugin({ directory: cyclicDir });
const cyclicOutput = output('cyclic');
await cyclicPlugin['experimental.chat.messages.transform']({}, cyclicOutput);
if (cyclicOutput.messages[0].parts.some(p => p.type === 'text' && p.text.includes('You have maxi.'))) {
  throw new Error('bootstrap injected when docs/maxi is a cyclic symlink');
}

const danglingPlugin = await mod.MaxiPlugin({ directory: danglingDir });
const danglingOutput = output('dangling');
await danglingPlugin['experimental.chat.messages.transform']({}, danglingOutput);
if (danglingOutput.messages[0].parts.some(p => p.type === 'text' && p.text.includes('You have maxi.'))) {
  throw new Error('bootstrap injected when docs/maxi is a dangling symlink');
}

const maxiPlugin = await mod.MaxiPlugin({ directory: maxiDir });
const maxiOutput = output('maxi');
await maxiPlugin['experimental.chat.messages.transform']({}, maxiOutput);
if (!maxiOutput.messages[0].parts.some(p => p.type === 'text' && p.text.includes('You have maxi.'))) {
  throw new Error('bootstrap missing after prior non-maxi project');
}
NODE
  then
    echo "OK  [maxi.js: bootstrap cache is project-aware]"
  else
    echo "FAIL [maxi.js: bootstrap cache is project-aware]" >&2
    failures=$((failures + 1))
  fi
  rm -rf "$TMP_OC"
else
  echo "SKIP [maxi.js: bootstrap cache behavior] (node not installed)"
fi

summary_and_exit "opencode plugin checks"
