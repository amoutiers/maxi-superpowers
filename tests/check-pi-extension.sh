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

TMP_PROBE="$(mktemp -d)"
trap 'rm -rf "$TMP_PROBE"' EXIT
cat > "$TMP_PROBE/probe.mjs" <<'EOF'
import assert from "node:assert/strict";
import { mkdtemp, mkdir, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const handlers = new Map();
const pi = {
  on(event, handler) {
    const registered = handlers.get(event) ?? [];
    registered.push(handler);
    handlers.set(event, registered);
  },
};
const handler = (event) => {
  const registered = handlers.get(event) ?? [];
  assert.equal(registered.length, 1, `expected one ${event} handler`);
  return registered[0];
};
const textOf = (message) => message.content.map((part) => part.text).join("\n");
const originalCwd = process.cwd();
const probeRoot = await mkdtemp(join(tmpdir(), "maxi-pi-gate-"));
const maxiProject = join(probeRoot, "project");
const fileProject = join(probeRoot, "file-project");
const cyclicProject = join(probeRoot, "cyclic-project");
const danglingProject = join(probeRoot, "dangling-project");
const outsideProject = join(probeRoot, "outside");

try {
  await mkdir(join(maxiProject, "docs", "maxi"), { recursive: true });
  await mkdir(join(fileProject, "docs"), { recursive: true });
  await writeFile(join(fileProject, "docs", "maxi"), "not a directory");
  await mkdir(join(cyclicProject, "docs"), { recursive: true });
  await symlink("maxi", join(cyclicProject, "docs", "maxi"));
  await mkdir(join(danglingProject, "docs"), { recursive: true });
  await symlink("missing", join(danglingProject, "docs", "maxi"));
  await mkdir(outsideProject, { recursive: true });
  const mod = await import(pathToFileURL(process.env.PI_EXT).href + `?probe=${Date.now()}`);
  mod.default(pi);
  const sessionStart = handler("session_start");
  const sessionCompact = handler("session_compact");
  const context = handler("context");
  const user = { role: "user", content: [{ type: "text", text: "Continue" }], timestamp: 1 };

  await sessionStart({}, {});
  process.chdir(outsideProject);
  assert.equal(await context({ messages: [user] }, {}), undefined, "first-session bootstrap must be silent outside docs/maxi");
  process.chdir(fileProject);
  assert.equal(await context({ messages: [user] }, {}), undefined, "first-session bootstrap must be silent when docs/maxi is a file");
  process.chdir(cyclicProject);
  assert.equal(await context({ messages: [user] }, {}), undefined, "first-session bootstrap must be silent when docs/maxi is a cyclic symlink");
  process.chdir(danglingProject);
  assert.equal(await context({ messages: [user] }, {}), undefined, "first-session bootstrap must be silent when docs/maxi is a dangling symlink");
  process.chdir(maxiProject);
  const firstSession = await context({ messages: [user] }, {});
  assert.equal(firstSession.messages.length, 2, "first-session bootstrap must inject inside docs/maxi");
  assert.match(textOf(firstSession.messages[0]), /You have maxi/);

  await sessionCompact({}, {});
  process.chdir(outsideProject);
  assert.equal(await context({ messages: [user] }, {}), undefined, "post-compaction bootstrap must be silent outside docs/maxi");
  process.chdir(fileProject);
  assert.equal(await context({ messages: [user] }, {}), undefined, "post-compaction bootstrap must be silent when docs/maxi is a file");
  process.chdir(cyclicProject);
  assert.equal(await context({ messages: [user] }, {}), undefined, "post-compaction bootstrap must be silent when docs/maxi is a cyclic symlink");
  process.chdir(danglingProject);
  assert.equal(await context({ messages: [user] }, {}), undefined, "post-compaction bootstrap must be silent when docs/maxi is a dangling symlink");
  process.chdir(maxiProject);
  const summary = { role: "compactionSummary", summary: "Earlier", timestamp: 1 };
  const postCompaction = await context({ messages: [summary, user] }, {});
  assert.equal(postCompaction.messages.length, 3, "post-compaction bootstrap must inject inside docs/maxi");
  assert.equal(postCompaction.messages[0], summary);
  assert.match(textOf(postCompaction.messages[1]), /You have maxi/);
} finally {
  process.chdir(originalCwd);
  await rm(probeRoot, { recursive: true, force: true });
}
EOF

if PI_EXT="$PI_EXT" node --experimental-strip-types "$TMP_PROBE/probe.mjs"; then
  echo "OK  [maxi.ts: dynamically gates first-session and post-compaction bootstrap]"
else
  echo "FAIL [maxi.ts: dynamically gates first-session and post-compaction bootstrap]" >&2
  failures=$((failures + 1))
fi

summary_and_exit "pi extension checks"
