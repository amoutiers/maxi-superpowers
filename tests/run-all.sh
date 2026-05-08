#!/usr/bin/env bash
# Run all maxi-superpowers tests.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
TESTS_DIR="$ROOT/tests"
failures=0

run_check() {
  local script="$1"
  local label="$2"
  echo "=== $label ==="
  if bash "$script"; then
    echo "--- PASS: $label"
  else
    echo "--- FAIL: $label" >&2
    failures=$((failures + 1))
  fi
  echo ""
}

run_check "$TESTS_DIR/check-frontmatter.sh"    "Skill frontmatter validation"
run_check "$TESTS_DIR/check-sync-invariant.sh" "Vendor/skills sync invariant"
run_check "$TESTS_DIR/check-spec-fixture.sh"   "Spec fixture round-trip"
run_check "$TESTS_DIR/check-adr-template.sh"   "ADR template and fixture validation"

if [ "$failures" -gt 0 ]; then
  echo "FAILED: $failures check(s) failed" >&2
  exit 1
fi

echo "All checks passed."
