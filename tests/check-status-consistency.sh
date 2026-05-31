#!/usr/bin/env bash
# The full 10-status SET must be IDENTICAL across every file that enumerates it on a single
# line (spec-template, CLAUDE.md, board), and board must not retain stale "8"-count phrasing.
# Canonical source: skills/specify/spec-template.md "# Allowed values:" line.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

ALL=(drafting specified clarified planned tasked analyzed implementing done parked cancelled)

# Print the subset of ALL appearing as whole words in a single line.
# Portable: tr -c collapses every non-letter byte (incl. '|', the multibyte '→', backticks) to
# spaces, so we never parse separators directly.
present_set() {
  local norm s
  norm=" $(printf '%s' "$1" | tr -c 'a-zA-Z' ' ') "
  for s in "${ALL[@]}"; do
    case "$norm" in *" $s "*) echo "$s";; esac
  done | sort -u
}

# Canonical set from the spec template.
canon_line="$(grep "^# Allowed values:" "$ROOT/skills/specify/spec-template.md")"
CANON="$(present_set "$canon_line")"
canon_count="$(printf '%s\n' "$CANON" | grep -c .)"
if [ "$canon_count" -ne 10 ]; then
  echo "FAIL [canonical]: expected 10 statuses in spec-template, got $canon_count" >&2
  failures=$((failures + 1))
fi

# Each enumerating line must carry exactly the canonical set.
check_line() {  # $1=relpath  $2=grep -E pattern isolating the list line  $3=label
  local line
  line="$(grep -E "$2" "$ROOT/$1" | head -1 || true)"
  if [ -z "$line" ]; then
    echo "FAIL [$3]: no status-list line found in $1" >&2; failures=$((failures + 1)); return
  fi
  if [ "$(present_set "$line")" = "$CANON" ]; then
    echo "OK  [$3]"
  else
    echo "FAIL [$3]: status set in $1 differs from canonical (got: $(present_set "$line" | tr '\n' ' '))" >&2
    failures=$((failures + 1))
  fi
}
check_line "CLAUDE.md"             'drafting.*\|.*cancelled' "CLAUDE.md status list"
check_line "skills/board/SKILL.md" 'drafting.*cancelled'     "board status list"

# Board renders 10 buckets — the stale "8" phrasing must be gone (this is the RED of Task 2).
assert_not_grep "$ROOT/skills/board/SKILL.md" "8 pipeline statuses" "board: no stale '8 pipeline statuses'"
assert_not_grep "$ROOT/skills/board/SKILL.md" "all 8 headings"      "board: no stale 'all 8 headings'"

summary_and_exit "status consistency checks"
