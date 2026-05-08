#!/usr/bin/env bash
# Run all maxi-superpowers tests.
# Usage: bash tests/run-all.sh [--integration]
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
TESTS_DIR="$ROOT/tests"
failures=0
INTEGRATION=false

for arg in "$@"; do
  case "$arg" in
    --integration) INTEGRATION=true ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# Check for required tools
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required but not installed" >&2; exit 1; }

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

# Fast tier: structural and script invariant checks
run_check "$TESTS_DIR/check-frontmatter.sh"      "Skill frontmatter validation"
run_check "$TESTS_DIR/check-sync-invariant.sh"   "Vendor/skills sync invariant"
run_check "$TESTS_DIR/check-spec-fixture.sh"     "Spec fixture and field validation"
run_check "$TESTS_DIR/check-templates.sh"        "Template shape validation"
run_check "$TESTS_DIR/check-skills-present.sh"   "Maxi-native skills present"
run_check "$TESTS_DIR/check-plugin-manifest.sh"  "Plugin manifest validation"
run_check "$TESTS_DIR/check-hooks.sh"            "Hooks config validation"
run_check "$TESTS_DIR/check-vendored-doc.sh"     "VENDORED.md validation"
run_check "$TESTS_DIR/check-sync-script.sh"      "Sync script behavior"
run_check "$TESTS_DIR/check-bump-script.sh"      "Bump script behavior"

if [ "$failures" -gt 0 ]; then
  echo "FAILED: $failures check(s) failed" >&2
  exit 1
fi

echo "All fast checks passed."

# Integration tier: behavioral skill-triggering tests (opt-in)
if [ "$INTEGRATION" = "true" ]; then
  echo ""
  echo "=== Integration tier ==="
  INTEGRATION_DIR="$TESTS_DIR/integration"
  if [ ! -f "$INTEGRATION_DIR/run-all.sh" ]; then
    echo "ERROR: integration tests not found at $INTEGRATION_DIR/run-all.sh" >&2
    exit 1
  fi
  if bash "$INTEGRATION_DIR/run-all.sh"; then
    echo "--- PASS: Integration tier"
  else
    echo "--- FAIL: Integration tier" >&2
    exit 1
  fi
fi
