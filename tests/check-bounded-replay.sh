#!/usr/bin/env bash
# Verify the bounded replay planner against immutable forward-pipeline fixtures.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

FIXTURES="$ROOT/tests/fixtures/bounded-replay"
PLANNER="$ROOT/skills/revise/replay-plan.sh"
X_REVIEW="$ROOT/skills/x-review"
WORK="$(mktemp -d /private/tmp/maxi-bounded-replay.XXXXXX)"
failures=0

trap 'rm -rf "$WORK"' EXIT

assert_equal() {
  local actual="$1" expected="$2" label="$3"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL [$label]: expected '$expected', got '$actual'" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

assert_derived_from_exact() {
  local file="$1" expected="$2" label="$3"
  local actual

  actual="$(awk '
    /^derived_from:$/ { capture = 1; next }
    capture && /^  - / { sub(/^  - /, ""); print; next }
    capture { exit }
  ' "$file")"
  assert_equal "$actual" "$expected" "$label"
}

assert_output_contains() {
  local output="$1" expected="$2" label="$3"
  if ! printf '%s\n' "$output" | grep -Fqx "$expected"; then
    echo "FAIL [$label]: missing record '$expected'" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

assert_no_replay_after_review() {
  local output="$1" label="$2"

  if printf '%s\n' "$output" | awk -F '|' '
    $1 == "REVIEW_REQUIRED" { review_required = 1; next }
    review_required && $1 == "REPLAY" { invalid = 1 }
    END { exit invalid }
  '; then
    echo "OK  [$label]"
  else
    echo "FAIL [$label]: replay record follows review handoff" >&2
    failures=$((failures + 1))
  fi
}

assert_success() {
  local status="$1" label="$2"
  if [ "$status" -ne 0 ]; then
    echo "FAIL [$label]: expected success, got exit $status" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

assert_failure() {
  local status="$1" label="$2"
  if [ "$status" -eq 0 ]; then
    echo "FAIL [$label]: expected failure" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

assert_exit() {
  local status="$1" expected="$2" label="$3"
  assert_equal "$status" "$expected" "$label"
}

fixture_digest() {
  (
    cd "$1"
    find . \( -type f -o -type l \) -print | LC_ALL=C sort | while IFS= read -r path; do
      if [ -L "$path" ]; then
        printf 'SYMLINK %s -> %s\n' "$path" "$(readlink "$path")"
      else
        shasum -a 256 "$path"
      fi
    done
  ) | shasum -a 256 | awk '{print $1}'
}

physical_target_digest() {
  local path="$1"

  if [ -L "$path" ]; then
    printf 'SYMLINK %s -> %s\n' "$path" "$(readlink "$path")"
  elif [ -f "$path" ]; then
    shasum -a 256 "$path"
  else
    printf 'MISSING %s\n' "$path"
  fi | shasum -a 256 | awk '{print $1}'
}

copy_fixture() {
  local source="$1" label="$2"
  CASE_DIR="$WORK/$label"
  mkdir -p "$CASE_DIR"
  cp -R "$source/." "$CASE_DIR/"
}

bump_revision() {
  local file="$1" writer="$2"
  local temp="$file.tmp"
  awk -v writer="$writer" '
    /^revision: / { print "revision: 2"; next }
    /^writer_context: / { print "writer_context: " writer; next }
    /^derived_from:/ && !added { print "  - " writer; added = 1 }
    { print }
    END { if (!added) print "  - " writer }
  ' "$file" > "$temp"
  mv "$temp" "$file"
}

run_planner() {
  local source="$1" changed="$2" previous="$3" phase="$4" label="$5" physical_target="${6:-}"
  local source_before source_after case_before case_after physical_before physical_after

  source_before="$(fixture_digest "$source")"
  case_before="$(fixture_digest "$CASE_DIR")"
  if [ -n "$physical_target" ]; then
    physical_before="$(physical_target_digest "$physical_target")"
  fi
  set +e
  LAST_OUTPUT="$(bash "$PLANNER" --spec-dir "$CASE_DIR" --changed "$changed" --previous-revision "$previous" --start-phase "$phase" 2>&1)"
  LAST_STATUS=$?
  set -e
  case_after="$(fixture_digest "$CASE_DIR")"
  source_after="$(fixture_digest "$source")"

  assert_equal "$source_after" "$source_before" "$label source fixture remains unchanged"
  assert_equal "$case_after" "$case_before" "$label planner makes no write"
  if [ -n "$physical_target" ]; then
    physical_after="$(physical_target_digest "$physical_target")"
    assert_equal "$physical_after" "$physical_before" "$label physical escape target remains unchanged"
  fi
}

# Current forward-pipeline fixtures have unique authors and valid independent reviews.
CURRENT="$FIXTURES/current"
CURRENT_DOCUMENTS='spec.md research.md data-model.md contracts/api.md reviews/spec-review.md plan.md reviews/plan-review.md tasks.md analysis.md'
contexts=''
for document in $CURRENT_DOCUMENTS; do
  file="$CURRENT/$document"
  assert_file_exists "$file" "current $document exists"
  assert_grep "$file" '^revision: 1$' "current $document revision 1"
  assert_grep "$file" '^structural_contributors:$' "current $document structural contributors"
  assert_grep "$file" '^derived_from:' "current $document direct inputs declared"
  context="$(awk '/^writer_context: / { print $2; exit }' "$file")"
  if [ -z "$context" ]; then
    echo "FAIL [current $document writer context]: missing" >&2
    failures=$((failures + 1))
  else
    contexts="$contexts\n$context"
    echo "OK  [current $document writer context]"
    assert_grep "$file" "^  - $context$" "current $document writer is structural contributor"
  fi
done

duplicate_contexts="$(printf '%b\n' "$contexts" | sed '/^$/d' | LC_ALL=C sort | uniq -d)"
if [ -n "$duplicate_contexts" ]; then
  echo "FAIL [current writer contexts]: duplicate context(s): $duplicate_contexts" >&2
  failures=$((failures + 1))
else
  echo "OK  [current writer contexts are unique]"
fi

assert_derived_from_exact "$CURRENT/research.md" 'spec.md@1' "current research exact direct inputs"
assert_derived_from_exact "$CURRENT/data-model.md" 'spec.md@1' "current data model exact direct inputs"
assert_derived_from_exact "$CURRENT/contracts/api.md" 'spec.md@1' "current contract exact direct inputs"
assert_derived_from_exact "$CURRENT/plan.md" 'spec.md@1
research.md@1
data-model.md@1
contracts/api.md@1
reviews/spec-review.md@1' "current plan exact direct inputs"
assert_derived_from_exact "$CURRENT/tasks.md" 'spec.md@1
research.md@1
data-model.md@1
contracts/api.md@1
plan.md@1
reviews/plan-review.md@1' "current tasks exact direct inputs"
assert_derived_from_exact "$CURRENT/analysis.md" 'spec.md@1
research.md@1
data-model.md@1
contracts/api.md@1
plan.md@1
tasks.md@1' "current analysis exact direct inputs"

for review in spec plan; do
  review_file="$CURRENT/reviews/$review-review.md"
  subject="$CURRENT/$review.md"
  reviewer="$(awk '/^reviewer_context: / { print $2; exit }' "$review_file")"
  assert_grep "$review_file" '^verdict: approved$' "$review review approved"
  if [ -n "$reviewer" ] && ! grep -Fqx "  - $reviewer" "$subject"; then
    echo "OK  [$review review is independent]"
  else
    echo "FAIL [$review review is independent]: reviewer is a structural contributor" >&2
    failures=$((failures + 1))
  fi
done

# T001 is intentionally RED. The remaining cases become executable as T004 and T005 add
# the review writer and read-only planner, respectively.
assert_file_exists "$PLANNER" "replay planner implementation exists"
assert_file_exists "$X_REVIEW/SKILL.md" "x-review implementation exists"
assert_file_exists "$X_REVIEW/review-template.md" "x-review template exists"

if [ "$failures" -gt 0 ]; then
  summary_and_exit "bounded replay checks"
fi

# A plan revision invalidates its review, tasks, and analysis, and stops at the handoff.
copy_fixture "$CURRENT" "plan-revision"
bump_revision "$CASE_DIR/plan.md" "fixture-plan-revision-writer"
run_planner "$CURRENT" "plan.md" 1 tasks "plan revision"
assert_success "$LAST_STATUS" "plan revision planner exit"
expected_plan_output='CHANGED|plan.md|1|2
STALE|analysis.md
STALE|reviews/plan-review.md
STALE|tasks.md
REVIEW_REQUIRED|plan.md|2'
assert_equal "$LAST_OUTPUT" "$expected_plan_output" "plan revision exact records"

# A tasks-only structural change has no affected ancestor and replays only analyze.
copy_fixture "$CURRENT" "tasks-revision"
bump_revision "$CASE_DIR/tasks.md" "fixture-tasks-revision-writer"
run_planner "$CURRENT" "tasks.md" 1 analyze "tasks revision"
assert_success "$LAST_STATUS" "tasks revision planner exit"
expected_tasks_output='CHANGED|tasks.md|1|2
STALE|analysis.md
REPLAY|analyze'
assert_equal "$LAST_OUTPUT" "$expected_tasks_output" "tasks revision exact records"

# A revise-owned source change starts clarification and stops for a fresh spec review.
copy_fixture "$CURRENT" "revised-spec"
bump_revision "$CASE_DIR/spec.md" "fixture-revise-writer"
run_planner "$CURRENT" "spec.md" 1 clarify "revised source spec"
assert_success "$LAST_STATUS" "revised source spec planner exit"
expected_revised_spec_output='CHANGED|spec.md|1|2
STALE|analysis.md
STALE|contracts/api.md
STALE|data-model.md
STALE|plan.md
STALE|research.md
STALE|reviews/plan-review.md
STALE|reviews/spec-review.md
STALE|tasks.md
REPLAY|clarify
REVIEW_REQUIRED|spec.md|2'
assert_equal "$LAST_OUTPUT" "$expected_revised_spec_output" "revised source spec exact handoff tail"
assert_no_replay_after_review "$LAST_OUTPUT" "revised source spec stops after review handoff"
if printf '%s\n' "$LAST_OUTPUT" | grep -Fqx 'REPLAY|specify'; then
  echo "FAIL [revised source spec never replays specify]" >&2
  failures=$((failures + 1))
else
  echo "OK  [revised source spec never replays specify]"
fi

# A clarified specification must hand off to review before planning.
copy_fixture "$CURRENT" "clarified-spec"
bump_revision "$CASE_DIR/spec.md" "fixture-clarify-writer"
run_planner "$CURRENT" "spec.md" 1 plan "clarified spec"
assert_success "$LAST_STATUS" "clarified spec planner exit"
expected_clarified_spec_output='CHANGED|spec.md|1|2
STALE|analysis.md
STALE|contracts/api.md
STALE|data-model.md
STALE|plan.md
STALE|research.md
STALE|reviews/plan-review.md
STALE|reviews/spec-review.md
STALE|tasks.md
REVIEW_REQUIRED|spec.md|2'
assert_equal "$LAST_OUTPUT" "$expected_clarified_spec_output" "clarified spec exact handoff tail"
assert_no_replay_after_review "$LAST_OUTPUT" "clarified spec stops after review handoff"

# A newly approved review reopens only its immediate successor segment.
copy_fixture "$CURRENT" "spec-review-approved"
bump_revision "$CASE_DIR/reviews/spec-review.md" "fixture-new-spec-review-writer"
run_planner "$CURRENT" "reviews/spec-review.md" 1 plan "approved spec review"
assert_success "$LAST_STATUS" "approved spec review planner exit"
expected_spec_review_output='CHANGED|reviews/spec-review.md|1|2
STALE|analysis.md
STALE|plan.md
STALE|reviews/plan-review.md
STALE|tasks.md
REPLAY|plan'
assert_equal "$LAST_OUTPUT" "$expected_spec_review_output" "approved spec review exact records"

copy_fixture "$CURRENT" "plan-review-approved"
bump_revision "$CASE_DIR/reviews/plan-review.md" "fixture-new-plan-review-writer"
run_planner "$CURRENT" "reviews/plan-review.md" 1 tasks "approved plan review"
assert_success "$LAST_STATUS" "approved plan review planner exit"
expected_plan_review_output='CHANGED|reviews/plan-review.md|1|2
STALE|analysis.md
STALE|tasks.md
REPLAY|tasks
REPLAY|analyze'
assert_equal "$LAST_OUTPUT" "$expected_plan_review_output" "approved plan review exact records"

# Invalid graph metadata always fails closed and never alters its copied input.
copy_fixture "$FIXTURES/missing-review" "missing-review"
bump_revision "$CASE_DIR/spec.md" "fixture-missing-review-revise-writer"
run_planner "$FIXTURES/missing-review" "spec.md" 1 plan "missing review"
assert_success "$LAST_STATUS" "missing review planner exit"
assert_output_contains "$LAST_OUTPUT" 'REVIEW_REQUIRED|spec.md|2' "missing review handoff"
assert_no_replay_after_review "$LAST_OUTPUT" "missing review stops later replay"

copy_fixture "$FIXTURES/self-review" "self-review"
run_planner "$FIXTURES/self-review" "reviews/spec-review.md" 0 plan "self review"
assert_exit "$LAST_STATUS" 2 "self review rejected as metadata"

copy_fixture "$CURRENT" "malformed-contributors"
awk '
  /^structural_contributors:/ { print "structural_contributors: malformed"; skip = 1; next }
  skip && /^  - / { next }
  { skip = 0; print }
' "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
mv "$CASE_DIR/spec.md.tmp" "$CASE_DIR/spec.md"
run_planner "$CURRENT" "spec.md" 0 clarify "malformed contributors"
assert_exit "$LAST_STATUS" 2 "malformed contributors rejected as metadata"

# Context values are literal metadata, even when they resemble pathname globs.
copy_fixture "$CURRENT" "glob-context"
glob_pattern="$CASE_DIR/glob-target-*"
glob_match="$CASE_DIR/glob-target-reviewer"
: > "$glob_match"
awk -v context="$glob_pattern" '
  /^writer_context: / { print "writer_context: " context; next }
  /^  - fixture-spec-writer$/ { print "  - " context; next }
  { print }
' "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
mv "$CASE_DIR/spec.md.tmp" "$CASE_DIR/spec.md"
awk -v reviewer="$glob_match" '
  /^reviewer_context: / { print "reviewer_context: " reviewer; next }
  { print }
' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp"
mv "$CASE_DIR/reviews/spec-review.md.tmp" "$CASE_DIR/reviews/spec-review.md"
run_planner "$CURRENT" "tasks.md" 0 analyze "literal glob context"
assert_success "$LAST_STATUS" "literal glob context does not expand"
expected_glob_context_output='CHANGED|tasks.md|0|1
STALE|analysis.md
REPLAY|analyze'
assert_equal "$LAST_OUTPUT" "$expected_glob_context_output" "literal glob context exact records"

copy_fixture "$CURRENT" "multiple-direct-inputs"
bump_revision "$CASE_DIR/research.md" "fixture-research-revision-writer"
run_planner "$CURRENT" "research.md" 1 plan "multiple direct inputs"
assert_success "$LAST_STATUS" "multiple direct inputs planner exit"
assert_output_contains "$LAST_OUTPUT" 'STALE|plan.md' "multiple direct inputs stale descendant"

# Support documents replay planning only; a changed terminal analysis has no producer replay.
copy_fixture "$CURRENT" "support-revision"
bump_revision "$CASE_DIR/research.md" "fixture-support-revision-writer"
run_planner "$CURRENT" "research.md" 1 plan "support revision"
assert_success "$LAST_STATUS" "support revision planner exit"
expected_support_output='CHANGED|research.md|1|2
STALE|analysis.md
STALE|plan.md
STALE|reviews/plan-review.md
STALE|tasks.md
REPLAY|plan'
assert_equal "$LAST_OUTPUT" "$expected_support_output" "support revision exact records"

copy_fixture "$FIXTURES/missing-review" "support-missing-review"
cp "$CURRENT/research.md" "$CASE_DIR/research.md"
bump_revision "$CASE_DIR/research.md" "fixture-support-missing-review-writer"
run_planner "$FIXTURES/missing-review" "research.md" 1 plan "support missing review"
assert_success "$LAST_STATUS" "support missing review planner exit"
expected_support_review_output='CHANGED|research.md|1|2
REVIEW_REQUIRED|spec.md|1'
assert_equal "$LAST_OUTPUT" "$expected_support_review_output" "support stops at missing spec review"
assert_no_replay_after_review "$LAST_OUTPUT" "support stops later replay after missing spec review"

copy_fixture "$CURRENT" "analysis-revision"
bump_revision "$CASE_DIR/analysis.md" "fixture-analysis-revision-writer"
run_planner "$CURRENT" "analysis.md" 1 analyze "analysis revision"
assert_success "$LAST_STATUS" "analysis revision planner exit"
assert_equal "$LAST_OUTPUT" 'CHANGED|analysis.md|1|2' "analysis revision has no replay"

copy_fixture "$FIXTURES/cycle" "disconnected-cycle"
run_planner "$FIXTURES/cycle" "spec.md" 0 clarify "disconnected cycle"
assert_exit "$LAST_STATUS" 3 "disconnected cycle rejected with graph exit"

copy_fixture "$FIXTURES/escape" "physical-escape"
outside="$WORK/physical-escape-outside.md"
cp "$CASE_DIR/escape-target.md" "$outside"
mkdir -p "$CASE_DIR/contracts"
ln -s "$outside" "$CASE_DIR/contracts/api.md"
run_planner "$FIXTURES/escape" "spec.md" 0 clarify "physical symlink escape" "$outside"
assert_exit "$LAST_STATUS" 3 "physical symlink escape rejected with graph exit"

copy_fixture "$FIXTURES/legacy" "legacy"
run_planner "$FIXTURES/legacy" "spec.md" 0 clarify "legacy input"
assert_exit "$LAST_STATUS" 4 "legacy input uses unsupported exit"
assert_output_contains "$LAST_OUTPUT" 'UNSUPPORTED_LEGACY' "legacy input unsupported"

# Arguments and selected paths fail closed with their documented exit classes.
copy_fixture "$CURRENT" "bad-start-phase"
run_planner "$CURRENT" "spec.md" 0 specify "specify phase"
assert_exit "$LAST_STATUS" 2 "specify phase rejected as bad arguments"

copy_fixture "$CURRENT" "leading-zero-previous"
run_planner "$CURRENT" "spec.md" 00 clarify "leading-zero previous revision"
assert_exit "$LAST_STATUS" 2 "leading-zero previous revision rejected as bad arguments"

copy_fixture "$CURRENT" "oversize-previous"
run_planner "$CURRENT" "spec.md" 18446744073709551616 clarify "oversize previous revision"
assert_exit "$LAST_STATUS" 2 "oversize previous revision rejected as bad arguments"

copy_fixture "$CURRENT" "malformed-previous"
run_planner "$CURRENT" "spec.md" 1x clarify "malformed previous revision"
assert_exit "$LAST_STATUS" 2 "malformed previous revision rejected as bad arguments"

copy_fixture "$CURRENT" "unsupported-path"
run_planner "$CURRENT" "workflow.md" 0 clarify "unsupported path"
assert_exit "$LAST_STATUS" 2 "unsupported selected path rejected as bad arguments"

copy_fixture "$CURRENT" "missing-path"
run_planner "$CURRENT" "contracts/missing.md" 0 plan "missing path"
assert_exit "$LAST_STATUS" 3 "missing supported path rejected with graph exit"

summary_and_exit "bounded replay checks"
