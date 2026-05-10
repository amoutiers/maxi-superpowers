#!/usr/bin/env bash
# Validates the shape of all 5 maxi templates and their fixtures.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

failures=0

check_template() {
  local file="$1" label="$2" has_frontmatter="$3"
  shift 3
  local frontmatter_fields=()
  local body_sections=()
  local in_fm=true
  for arg in "$@"; do
    if [ "$arg" = "--" ]; then
      in_fm=false
      continue
    fi
    if $in_fm; then
      frontmatter_fields+=("$arg")
    else
      body_sections+=("$arg")
    fi
  done

  local before=$failures

  assert_file_exists "$file" "$label: file present"
  [ ! -f "$file" ] && return

  if [ "$has_frontmatter" = "true" ]; then
    assert_starts_with_yaml_frontmatter "$file" "$label: frontmatter"
    for field in "${frontmatter_fields[@]}"; do
      assert_grep "$file" "^${field}" "$label: ${field}"
    done
  fi

  for section in "${body_sections[@]}"; do
    assert_grep "$file" "$section" "$label: ${section}"
  done

  if [ "$failures" -eq "$before" ]; then
    echo "OK  [$label]"
  fi
}

# adr-template
check_template \
  "$ROOT/templates/adr-template.md" "adr-template.md" "true" \
  "adr:" "slug:" "status:" "date:" "updated:" "decider:" "related_specs:" "related_principles:" "related_requirements:" "supersedes:" "superseded_by:" \
  "--" \
  "^## Context" "^## Considered Options" "^## Decision" "^## Consequences" "^## Confirmation"

# adr fixture
check_template \
  "$ROOT/tests/fixtures/sample-adr.md" "fixtures/sample-adr.md" "true" \
  "adr:" "slug:" "status:" "date:" "updated:" "decider:" "related_specs:" "related_principles:" "related_requirements:" "supersedes:" "superseded_by:" \
  "--" \
  "^## Context" "^## Considered Options" "^## Decision" "^## Consequences" "^## Confirmation"

# spec-template
check_template \
  "$ROOT/templates/spec-template.md" "spec-template.md" "true" \
  "slug:" "created:" "updated:" "status:" \
  "--" \
  "^## User Scenarios" "^## Requirements" "^## Clarifications" "^## Success Criteria"

# spec fixture
check_template \
  "$ROOT/tests/fixtures/sample-spec.md" "fixtures/sample-spec.md" "true" \
  "slug:" "created:" "updated:" "status:" \
  "--" \
  "^## User Scenarios" "^## Requirements" "^## Clarifications" "^## Success Criteria"

# constitution-template
check_template \
  "$ROOT/templates/constitution-template.md" "constitution-template.md" "true" \
  "version:" "ratified:" "last_amended:" \
  "--" \
  "## Core Principles"

# plan-template
check_template \
  "$ROOT/templates/plan-template.md" "plan-template.md" "true" \
  "slug:" "spec_slug:" "created:" "updated:" \
  "--" \
  "## Summary" "## Technical Context" "## Constitution Check"

# tasks-template
check_template \
  "$ROOT/templates/tasks-template.md" "tasks-template.md" "true" \
  "description:" "slug:" "spec_slug:" "created:" "updated:" \
  "--" \
  "## Format:" "## Path Conventions"

summary_and_exit "template checks"
