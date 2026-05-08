#!/usr/bin/env bash
# Round-trip tests spec.md status frontmatter: verify each status value parses and re-serialises without drift.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
FIXTURE="$ROOT/tests/fixtures/sample-spec.md"
VALID_STATUSES="drafting specified clarified planned tasked analyzed implementing done"
failures=0

if [ ! -f "$FIXTURE" ]; then
  echo "ERROR: fixture not found: $FIXTURE" >&2
  exit 1
fi

for status in $VALID_STATUSES; do
  # Substitute status in fixture, extract it back, compare
  result=$(sed "s/^status:.*/status: $status/" "$FIXTURE" | grep "^status:" | sed "s/^status: //")
  if [ "$result" != "$status" ]; then
    echo "FAIL: status '$status' did not round-trip cleanly (got: '$result')" >&2
    failures=$((failures + 1))
  else
    echo "OK  [status: $status]"
  fi
done

if [ "$failures" -gt 0 ]; then
  echo ""
  echo "FAILED: $failures status value(s) failed round-trip" >&2
  exit 1
fi

echo ""
echo "All status values round-trip cleanly."
