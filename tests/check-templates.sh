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
  "$ROOT/skills/x-adr/adr-template.md" "adr-template.md" "true" \
  "adr:" "slug:" "spec:" "status:" "created:" "updated:" "decider:" "supersedes:" "superseded_by:" \
  "--" \
  "^## Context" "^## Decision Drivers" "^## Considered Options" "^## Decision" "^## Consequences" "^## Confirmation"
assert_not_grep "$ROOT/skills/x-adr/adr-template.md" "^related_specs:" "adr-template.md: no related_specs"
assert_not_grep "$ROOT/skills/x-adr/adr-template.md" "^related_principles:" "adr-template.md: no related_principles"
assert_not_grep "$ROOT/skills/x-adr/adr-template.md" "^related_requirements:" "adr-template.md: no related_requirements"
assert_grep "$ROOT/skills/x-adr/adr-template.md" "^spec: null$" "adr-template.md: unlinked ADR default"

# adr fixture
check_template \
  "$ROOT/tests/fixtures/sample-adr.md" "fixtures/sample-adr.md" "true" \
  "adr:" "slug:" "spec:" "status:" "created:" "updated:" "decider:" "supersedes:" "superseded_by:" \
  "--" \
  "^## Context" "^## Decision Drivers" "^## Considered Options" "^## Decision" "^## Consequences" "^## Confirmation"
assert_not_grep "$ROOT/tests/fixtures/sample-adr.md" "^related_specs:" "sample-adr.md: no related_specs"
assert_not_grep "$ROOT/tests/fixtures/sample-adr.md" "^related_principles:" "sample-adr.md: no related_principles"
assert_not_grep "$ROOT/tests/fixtures/sample-adr.md" "^related_requirements:" "sample-adr.md: no related_requirements"
assert_grep "$ROOT/tests/fixtures/sample-adr.md" "^spec: 0001-sample-feature$" "sample-adr.md: direct creating-spec link"

# spec-template
check_template \
  "$ROOT/skills/specify/spec-template.md" "spec-template.md" "true" \
  "slug:" "created:" "updated:" "status:" "related_adrs:" \
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
  "$ROOT/skills/constitution/constitution-template.md" "constitution-template.md" "true" \
  "version:" "created:" "updated:" \
  "--" \
  "## Core Principles"

# plan-template
check_template \
  "$ROOT/skills/plan/plan-template.md" "plan-template.md" "true" \
  "slug:" "spec_slug:" "created:" "updated:" \
  "--" \
  "## Summary" "## Technical Context" "## Constitution Check"

# tasks-template
check_template \
  "$ROOT/skills/tasks/tasks-template.md" "tasks-template.md" "true" \
  "slug:" "spec_slug:" "created:" "updated:" \
  "--" \
  "## Format:" "## Path Conventions"
if grep '^- \[[ xX]\] T\(XXX\|[0-9][0-9][0-9]\) ' "$ROOT/skills/tasks/tasks-template.md" | grep -Ev '\(plan Task [1-9][0-9]*\)$' >/dev/null; then
  echo "FAIL [tasks-template.md: terminal plan mapping]: every sample task needs one terminal plan Task N mapping" >&2
  failures=$((failures + 1))
else
  echo "OK  [tasks-template.md: terminal plan mapping]"
fi
assert_grep "$ROOT/skills/tasks/SKILL.md" 'exactly one terminal `(plan Task <positive integer>)` mapping' "tasks: exact terminal plan mapping contract"
assert_grep "$ROOT/skills/tasks/SKILL.md" 'bijection.*`plan.md`.*`Task N`' "tasks: plan mapping is bijective"

# review-template
check_template \
  "$ROOT/skills/review/review-template.md" "review-template.md" "true" \
  "reviewed_spec_sha256:" "reviewed_plan_sha256:" "verdict: approved$" \
  "--" \
  "^## Findings" "^## Verdict" "^## Verification"

# Review gates are intentionally limited to the explicit design-review record.
assert_grep "$ROOT/skills/tasks/SKILL.md" 'reviews/design-review.md' "tasks: reads the design review"
for skill in specify clarify revise plan tasks analyze implement; do
  assert_not_grep "$ROOT/skills/$skill/SKILL.md" 'replay_contract\|replay_continuation\|replay-plan\.sh\|x-review' "$skill: no replay metadata"
done

summary_and_exit "template checks"
