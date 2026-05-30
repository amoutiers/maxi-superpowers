#!/usr/bin/env bash
# Asserts the bootstrap preamble is identical across both harness injectors:
#   hooks/session-start (Claude Code / bash) and .opencode/plugins/maxi.js (OpenCode).
# Editing one without the other silently diverges the two harnesses.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

HOOK="$ROOT/hooks/session-start"
PLUGIN="$ROOT/.opencode/plugins/maxi.js"
failures=0

assert_file_exists "$HOOK" "session-start"
assert_file_exists "$PLUGIN" "maxi.js"

# Canonical preamble fragments that MUST appear verbatim in both injectors.
CANON_HEADER="You have maxi."
CANON_SENTENCE="**Below is the full content of your 'maxi:using-maxi' skill - your introduction to the maxi spec-driven pipeline. For all other maxi skills, use the 'Skill' tool:**"

for f in "$HOOK" "$PLUGIN"; do
  assert_grep "$f" "$CANON_HEADER" "bootstrap header present in $(basename "$f")"
  if grep -qF "$CANON_SENTENCE" "$f"; then
    echo "OK  [bootstrap sentence present in $(basename "$f")]"
  else
    echo "FAIL [bootstrap sentence present in $(basename "$f")]: canonical preamble drifted" >&2
    failures=$((failures + 1))
  fi
done

summary_and_exit "bootstrap parity checks"
