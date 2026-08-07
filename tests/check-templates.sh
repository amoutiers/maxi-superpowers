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
  "adr:" "slug:" "status:" "created:" "updated:" "decider:" "supersedes:" "superseded_by:" \
  "--" \
  "^## Context" "^## Decision Drivers" "^## Considered Options" "^## Decision" "^## Consequences" "^## Confirmation"
assert_not_grep "$ROOT/skills/x-adr/adr-template.md" "^related_specs:" "adr-template.md: no related_specs"
assert_not_grep "$ROOT/skills/x-adr/adr-template.md" "^related_principles:" "adr-template.md: no related_principles"
assert_not_grep "$ROOT/skills/x-adr/adr-template.md" "^related_requirements:" "adr-template.md: no related_requirements"

# adr fixture
check_template \
  "$ROOT/tests/fixtures/sample-adr.md" "fixtures/sample-adr.md" "true" \
  "adr:" "slug:" "status:" "created:" "updated:" "decider:" "supersedes:" "superseded_by:" \
  "--" \
  "^## Context" "^## Decision Drivers" "^## Considered Options" "^## Decision" "^## Consequences" "^## Confirmation"
assert_not_grep "$ROOT/tests/fixtures/sample-adr.md" "^related_specs:" "sample-adr.md: no related_specs"
assert_not_grep "$ROOT/tests/fixtures/sample-adr.md" "^related_principles:" "sample-adr.md: no related_principles"
assert_not_grep "$ROOT/tests/fixtures/sample-adr.md" "^related_requirements:" "sample-adr.md: no related_requirements"

# spec-template
check_template \
  "$ROOT/skills/specify/spec-template.md" "spec-template.md" "true" \
  "slug:" "created:" "updated:" "status:" "revision: 1$" \
  "writer_context: <unique-writer-context>$" "structural_contributors:" \
  "  - <unique-writer-context>$" "derived_from: \[\]$" "related_adrs:" \
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
  "slug:" "spec_slug:" "created:" "updated:" "revision: 1$" \
  "writer_context: <unique-writer-context>$" "structural_contributors:" \
  "  - <unique-writer-context>$" "derived_from:" \
  "--" \
  "## Summary" "## Technical Context" "## Constitution Check"
assert_grep "$ROOT/skills/plan/plan-template.md" '^  - <direct-input-path>@<exact-revision>$' "plan-template.md: direct input revisions"

# tasks-template
check_template \
  "$ROOT/skills/tasks/tasks-template.md" "tasks-template.md" "true" \
  "slug:" "spec_slug:" "created:" "updated:" "revision: 1$" \
  "writer_context: <unique-writer-context>$" "structural_contributors:" \
  "  - <unique-writer-context>$" "derived_from:" \
  "--" \
  "## Format:" "## Path Conventions"
assert_grep "$ROOT/skills/tasks/tasks-template.md" '^  - <direct-input-path>@<exact-revision>$' "tasks-template.md: direct input revisions"

# review-template
check_template \
  "$ROOT/skills/x-review/review-template.md" "review-template.md" "true" \
  "revision: 1$" "writer_context: <verified-reviewer-context>$" "structural_contributors:" \
  "  - <verified-reviewer-context>$" "derived_from:" \
  "reviewed_document:" "reviewed_revision:" "reviewed_sha256:" "reviewer_context:" \
  "reviewer_context_matches_harness: true$" "verdict: approved$" \
  "--" \
  "^## Findings" "^## Verdict" "^## Verification Results"
assert_grep "$ROOT/skills/x-review/review-template.md" '^  - <reviewed-document>@<reviewed-revision>$' "review-template.md: direct input revision"

# Structural rewrite and review-gate contracts live in their owning skills.
assert_grep "$ROOT/skills/specify/SKILL.md" 'replace its `writer_context` with the new unique context' "specify: structural rewrite replaces active writer context"
assert_grep "$ROOT/skills/specify/SKILL.md" '^replay_contract: bounded-v1$' "specify: forward creation writes exact replay marker"
assert_grep "$ROOT/skills/specify/SKILL.md" 'only producer.*`replay_contract: bounded-v1`' "specify: sole replay marker producer"
assert_not_grep "$ROOT/skills/specify/spec-template.md" '^replay_contract:' "spec template: no replay marker retrofit"
for ingress in \
  "$ROOT/skills/migrate-from-speckit/SKILL.md" \
  "$ROOT/skills/migrate-from-brownfield/SKILL.md" \
  "$ROOT/skills/migrate-from-brownfield/brownfield.sh"; do
  assert_not_grep "$ingress" 'replay_contract: bounded-v1' "$(basename "$(dirname "$ingress")")/$(basename "$ingress"): no replay marker"
done
assert_grep "$ROOT/skills/plan/SKILL.md" 'load `spec.md`.*`reviews/spec-review.md`' "plan: reads current spec review"
assert_grep "$ROOT/skills/plan/SKILL.md" 'missing, does not have `verdict: approved`, does not target `spec.md`, or its `reviewed_revision` does not equal the current spec revision' "plan: rejects missing stale or non-approved spec review"
assert_grep "$ROOT/skills/plan/SKILL.md" 'unmarked root.*read only `spec.md` and `constitution.md`.*do not read.*review.*x-review' "plan: legacy branch does not read or hand off a review"
assert_grep "$ROOT/skills/tasks/SKILL.md" 'unmarked root.*read `plan.md`.*do not read.*review.*x-review' "tasks: legacy branch does not read or hand off a review"

plan_forward_provenance="$(awk '
  /^## Forward Provenance Contract$/ { capture = 1 }
  capture && /^## Artifact reference links$/ { exit }
  capture { print }
' "$ROOT/skills/plan/SKILL.md")"
if printf '%s\n' "$plan_forward_provenance" | grep -Fq 'quickstart.md'; then
  echo "FAIL [plan: forward provenance excludes quickstart.md]" >&2
  failures=$((failures + 1))
else
  echo "OK  [plan: forward provenance excludes quickstart.md]"
fi

analyze_forward_provenance="$(awk '
  /^### Step 7 / { capture = 1 }
  capture && /^### Step 8 / { exit }
  capture { print }
' "$ROOT/skills/analyze/SKILL.md")"
if printf '%s\n' "$analyze_forward_provenance" | grep -Fq 'quickstart.md'; then
  echo "FAIL [analyze: forward provenance excludes quickstart.md]" >&2
  failures=$((failures + 1))
else
  echo "OK  [analyze: forward provenance excludes quickstart.md]"
fi
assert_grep "$ROOT/skills/plan/SKILL.md" '`quickstart.md`.*optional.*not.*pipeline-owned.*no revision.*provenance' "plan: quickstart optional output remains outside revision graph"
assert_grep "$ROOT/skills/analyze/SKILL.md" '`quickstart.md`.*optional.*not.*direct input.*forward-pipeline analysis' "analyze: quickstart optional output remains outside direct inputs"

# analysis.md has no separate template, so its owning skill carries the output contract.
assert_grep "$ROOT/skills/analyze/SKILL.md" '^revision: 1$' "analyze: initial revision"
assert_grep "$ROOT/skills/analyze/SKILL.md" '^writer_context: <unique-writer-context>$' "analyze: unique writer context"
assert_grep "$ROOT/skills/analyze/SKILL.md" '^structural_contributors:$' "analyze: structural contributors"
assert_grep "$ROOT/skills/analyze/SKILL.md" '^  - <unique-writer-context>$' "analyze: initial contributor"
assert_grep "$ROOT/skills/analyze/SKILL.md" '^derived_from:$' "analyze: direct inputs"
assert_grep "$ROOT/skills/analyze/SKILL.md" '^  - spec.md@<exact-revision-read>$' "analyze: spec input revision"
assert_grep "$ROOT/skills/analyze/SKILL.md" '^  - <support-artifact-path>@<exact-revision-read>$' "analyze: support input revisions"
assert_grep "$ROOT/skills/analyze/SKILL.md" '^  - plan.md@<exact-revision-read>$' "analyze: plan input revision"
assert_grep "$ROOT/skills/analyze/SKILL.md" '^  - tasks.md@<exact-revision-read>$' "analyze: tasks input revision"
assert_grep "$ROOT/skills/analyze/SKILL.md" 'future-only contract only when.*exact `replay_contract: bounded-v1` root marker.*Revision metadata alone never activates' "analyze: future-only contract is marker-bound"
assert_grep "$ROOT/skills/analyze/SKILL.md" 'For an unmarked root, skip independent reviewer-context, structural-contributor, revision, provenance, and analysis-metadata requirements' "analyze: unmarked roots bypass every future-only requirement"
assert_grep "$ROOT/skills/analyze/SKILL.md" 'For an eligible root, read the complete current frontmatter.*structural_contributors' "analyze: contributor check is marker-bound"
assert_grep "$ROOT/skills/implement/SKILL.md" 'future-only contract only when.*exact `replay_contract: bounded-v1` root marker.*Revision metadata alone never activates' "implement: future-only contract is marker-bound"

# Spec 0019 is the revision-bearing pre-mechanism regression: it stays
# unmarked, so analyze and implement must retain their legacy behavior for it.
ACTUAL_0019_SPEC="$ROOT/docs/maxi/specs/0019-artifact-analysis-convergence/spec.md"
assert_grep "$ACTUAL_0019_SPEC" '^revision: [1-9][0-9]*$' "actual 0019: revision-bearing"
assert_not_grep "$ACTUAL_0019_SPEC" '^replay_contract:' "actual 0019: remains unmarked"

# The actual generated migration outputs are checked by both migration suites.
# The legacy replay fixture remains an unversioned boundary input here.
assert_not_grep "$ROOT/tests/fixtures/bounded-replay/legacy/spec.md" '^revision:' "legacy replay spec: no revision metadata"
assert_not_grep "$ROOT/tests/fixtures/bounded-replay/legacy/spec.md" '^writer_context:' "legacy replay spec: no writer context"
assert_not_grep "$ROOT/tests/fixtures/bounded-replay/legacy/spec.md" '^structural_contributors:' "legacy replay spec: no structural contributors"
assert_not_grep "$ROOT/tests/fixtures/bounded-replay/legacy/spec.md" '^derived_from:' "legacy replay spec: no derived provenance"

summary_and_exit "template checks"
