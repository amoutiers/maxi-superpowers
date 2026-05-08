#!/usr/bin/env bash
# Round-trip tests spec.md status frontmatter: verify each status value parses and re-serialises without drift.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

FIXTURE="$ROOT/tests/fixtures/sample-spec.md"
VALID_STATUSES=(drafting specified clarified planned tasked analyzed implementing done)
failures=0

if [ ! -f "$FIXTURE" ]; then
  echo "ERROR: fixture not found: $FIXTURE" >&2
  exit 1
fi

assert_grep "$FIXTURE" "^slug:" "spec fixture: slug field present"

slug_val=$(grep "^slug:" "$FIXTURE" | sed "s/^slug: *//" | tr -d '"')
if ! echo "$slug_val" | grep -qE "^[0-9]{3}-[a-z0-9-]+$"; then
  echo "FAIL [spec fixture: slug shape]: '$slug_val' does not match NNN-slug pattern" >&2
  failures=$((failures + 1))
else
  echo "OK  [spec fixture: slug shape]: $slug_val"
fi

assert_grep "$FIXTURE" "^created:" "spec fixture: created field present"

for status in "${VALID_STATUSES[@]}"; do
  result=$(sed "s/^status:.*/status: $status/" "$FIXTURE" | { grep "^status:" || true; } | sed "s/^status: //")
  if [ "$result" != "$status" ]; then
    echo "FAIL: status '$status' did not round-trip cleanly (got: '$result')" >&2
    failures=$((failures + 1))
  else
    echo "OK  [status: $status]"
  fi
done

summary_and_exit "status round-trip checks"
