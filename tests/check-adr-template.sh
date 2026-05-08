#!/usr/bin/env bash
# Validates templates/adr-template.md structure and sample-adr.md fixture.
# Checks: required frontmatter fields and required body sections.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
TEMPLATE="$ROOT/templates/adr-template.md"
FIXTURE="$ROOT/tests/fixtures/sample-adr.md"
failures=0

REQUIRED_FRONTMATTER_FIELDS=(
  "^adr:"
  "^slug:"
  "^status:"
  "^date:"
  "^related_specs:"
  "^related_principles:"
  "^related_requirements:"
  "^supersedes:"
  "^superseded_by:"
)

REQUIRED_BODY_SECTIONS=(
  "^## Context"
  "^## Considered Options"
  "^## Decision"
  "^## Consequences"
  "^## Confirmation"
)

check_file() {
  local file="$1"
  local label="$2"
  local file_failures=0

  if [ ! -f "$file" ]; then
    echo "FAIL [$label]: file not found: $file" >&2
    failures=$((failures + 1))
    return
  fi

  # Must start with YAML frontmatter
  first_line=$(head -1 "$file")
  if [ "$first_line" != "---" ]; then
    echo "FAIL [$label]: does not start with YAML frontmatter (---)" >&2
    file_failures=$((file_failures + 1))
  fi

  # Check required frontmatter fields
  for field in "${REQUIRED_FRONTMATTER_FIELDS[@]}"; do
    if ! grep -q "$field" "$file"; then
      echo "FAIL [$label]: missing frontmatter field: $field" >&2
      file_failures=$((file_failures + 1))
    fi
  done

  # Check required body sections
  for section in "${REQUIRED_BODY_SECTIONS[@]}"; do
    if ! grep -q "$section" "$file"; then
      echo "FAIL [$label]: missing body section: $section" >&2
      file_failures=$((file_failures + 1))
    fi
  done

  if [ "$file_failures" -eq 0 ]; then
    echo "OK  [$label]"
  else
    failures=$((failures + file_failures))
  fi
}

check_file "$TEMPLATE" "templates/adr-template.md"
check_file "$FIXTURE"  "tests/fixtures/sample-adr.md"

if [ "$failures" -gt 0 ]; then
  echo ""
  echo "FAILED: $failures check(s) failed in ADR template validation" >&2
  exit 1
fi

echo ""
echo "ADR template and fixture passed all checks."
