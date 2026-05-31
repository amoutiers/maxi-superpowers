#!/usr/bin/env bash
# Validates the spec fixture's required fields (slug shape, created). Status-list consistency moved to check-status-consistency.sh.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

FIXTURE="$ROOT/tests/fixtures/sample-spec.md"

if [ ! -f "$FIXTURE" ]; then
  echo "ERROR: fixture not found: $FIXTURE" >&2
  exit 1
fi

assert_grep "$FIXTURE" "^slug:" "spec fixture: slug field present"

slug_val=$(grep "^slug:" "$FIXTURE" | sed "s/^slug: *//" | tr -d '"')
if ! echo "$slug_val" | grep -qE "^[0-9]{4}-[a-z0-9-]+$"; then
  echo "FAIL [spec fixture: slug shape]: '$slug_val' does not match NNNN-slug pattern" >&2
  failures=$((failures + 1))
else
  echo "OK  [spec fixture: slug shape]: $slug_val"
fi

assert_grep "$FIXTURE" "^created:" "spec fixture: created field present"

summary_and_exit "spec fixture checks"
