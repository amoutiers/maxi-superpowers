#!/usr/bin/env bash
# Asserts the bootstrap preamble is identical across all three harness
# injectors, mirroring superpowers v6.1.1:
#   - hooks/session-start (Claude Code, Antigravity, Cursor, Copilot CLI)
#   - .opencode/plugins/maxi.js (OpenCode)
#   - .pi/extensions/maxi.ts (Pi)
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

HOOK="$ROOT/hooks/session-start"
PLUGIN="$ROOT/.opencode/plugins/maxi.js"
PI_EXT="$ROOT/.pi/extensions/maxi.ts"
failures=0

assert_file_exists "$HOOK" "hooks/session-start"
assert_file_exists "$PLUGIN" ".opencode/plugins/maxi.js"
assert_file_exists "$PI_EXT" ".pi/extensions/maxi.ts"

# Stale per-harness wrappers must be gone.
for stale in session-start-core session-start-claude session-start-codex session-start-antigravity; do
  if [ -e "$ROOT/hooks/$stale" ]; then
    echo "FAIL [stale wrapper hooks/$stale]: should be removed" >&2
    failures=$((failures + 1))
  fi
done

# Canonical preamble fragments that MUST appear verbatim in all three injectors.
CANON_HEADER="You have maxi."
CANON_SENTENCE="**Below is the full content of your 'maxi:using-maxi' skill - your introduction to the maxi spec-driven pipeline. For all other maxi skills, use the 'Skill' tool:**"

for f in "$HOOK" "$PLUGIN" "$PI_EXT"; do
  assert_grep "$f" "$CANON_HEADER" "bootstrap header present in $(basename "$f")"
  if grep -qF "$CANON_SENTENCE" "$f"; then
    echo "OK  [bootstrap sentence present in $(basename "$f")]"
  else
    echo "FAIL [bootstrap sentence present in $(basename "$f")]: canonical preamble drifted" >&2
    failures=$((failures + 1))
  fi
done

# The hook must emit the right JSON per harness shape (env-aware).
assert_grep "$HOOK" 'CURSOR_PLUGIN_ROOT' "session-start: detects Cursor"
assert_grep "$HOOK" 'CLAUDE_PLUGIN_ROOT' "session-start: detects Claude Code"
assert_grep "$HOOK" 'COPILOT_CLI' "session-start: detects Copilot CLI"

summary_and_exit "bootstrap parity checks"