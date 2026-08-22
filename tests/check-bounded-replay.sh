#!/usr/bin/env bash
# Verify the bounded replay planner against immutable forward-pipeline fixtures.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

FIXTURES="$ROOT/tests/fixtures/bounded-replay"
PLANNER="$ROOT/skills/revise/replay-plan.sh"
X_REVIEW="$ROOT/skills/x-review"
WORK="$(mktemp -d)"
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

assert_no_proposal_output() {
  local output="$1" label="$2"

  if printf '%s\n' "$output" | grep -Eq '^(CHANGED|STALE|CONTINUATION|REPLAY|REVIEW_REQUIRED)\|'; then
    echo "FAIL [$label]: proposal record emitted" >&2
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

correction_section() {
  awk '
    /^## Explicit Structural (Plan|Tasks) Correction$/ { capture = 1 }
    capture && /^## / && !/^## Explicit Structural (Plan|Tasks) Correction$/ { exit }
    capture { print }
  ' "$1"
}

assert_correction_section_grep() {
  local file="$1" pattern="$2" label="$3" section

  section="$(correction_section "$file")"
  if ! printf '%s\n' "$section" | grep -Eq "$pattern"; then
    echo "FAIL [$label]: correction section lacks '$pattern'" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

assert_correction_section_not_grep() {
  local file="$1" pattern="$2" label="$3" section

  section="$(correction_section "$file")"
  if printf '%s\n' "$section" | grep -Eq "$pattern"; then
    echo "FAIL [$label]: correction section contains '$pattern'" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
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

  # Non-legacy graph fixtures model future forward specs. Keep the eligibility
  # marker explicit in the copied case without retrofitting source fixtures.
  if [ -f "$CASE_DIR/spec.md" ] &&
     grep -q '^revision:' "$CASE_DIR/spec.md" &&
     ! grep -q '^replay_contract:' "$CASE_DIR/spec.md"; then
    awk '
      NR == 1 { print; print "replay_contract: bounded-v1"; next }
      { print }
    ' "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
    mv "$CASE_DIR/spec.md.tmp" "$CASE_DIR/spec.md"
  fi
}

bump_revision() {
  local file="$1" writer="$2"

  set_document_revision "$file" 2 "$writer"
}

set_document_revision() {
  local file="$1" revision="$2" writer="$3"
  local temp="$file.tmp"
  awk -v revision="$revision" -v writer="$writer" '
    /^revision: / { print "revision: " revision; next }
    /^writer_context: / { print "writer_context: " writer; next }
    /^derived_from:/ && !added { print "  - " writer; added = 1 }
    { print }
    END { if (!added) print "  - " writer }
  ' "$file" > "$temp"
  mv "$temp" "$file"
}

run_planner() {
  local source="$1" changed="$2" previous="$3" phase="$4" label="$5" physical_target="${6:-}" mode="${7:-}"
  local source_before source_after case_before case_after physical_before physical_after
  local -a command

  source_before="$(fixture_digest "$source")"
  case_before="$(fixture_digest "$CASE_DIR")"
  if [ -n "$physical_target" ]; then
    physical_before="$(physical_target_digest "$physical_target")"
  fi
  set +e
  command=(bash "$PLANNER" --spec-dir "$CASE_DIR" --changed "$changed" --previous-revision "$previous" --start-phase "$phase")
  case "$mode" in
    resume) command+=(--resume-current-review) ;;
    resume-source) command+=(--resume-current-source) ;;
  esac
  LAST_OUTPUT="$("${command[@]}" 2>&1)"
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

structural_sha256() {
  awk '
    NR == 1 && $0 == "---" { first_frontmatter = 1 }
    first_frontmatter && /^(status|updated):/ { next }
    { print }
    first_frontmatter && NR > 1 && $0 == "---" { first_frontmatter = 0 }
  ' "$1" | shasum -a 256 | awk '{print $1}'
}

write_review_frontmatter() {
  local file="$1" subject="$2" revision="$3" context="$4" reviewed_revision="$5"
  local digest previous_contributors='' temp="$file.tmp"

  digest="$(structural_sha256 "$CASE_DIR/$subject")"
  if [ "$revision" -gt 1 ]; then
    previous_contributors="$(awk '
      /^structural_contributors:$/ { capture = 1; next }
      capture && /^  - / { sub(/^  - /, ""); print; next }
      capture { exit }
    ' "$file")"
  fi
  awk -v revision="$revision" -v context="$context" -v subject="$subject" \
      -v reviewed_revision="$reviewed_revision" -v digest="$digest" \
      -v previous_contributors="$previous_contributors" '
    NR == 1 {
      print "---"
      print "revision: " revision
      print "writer_context: " context
      print "structural_contributors:"
      count = split(previous_contributors, prior, "\n")
      for (i = 1; i <= count; i++) if (prior[i] != "" && prior[i] != context) print "  - " prior[i]
      print "  - " context
      print "derived_from:"
      print "  - " subject "@" reviewed_revision
      print "reviewed_document: " subject
      print "reviewed_revision: " reviewed_revision
      print "reviewed_sha256: " digest
      print "reviewer_context: " context
      print "reviewer_context_matches_harness: true"
      print "verdict: approved"
      print "---"
      in_frontmatter = 1
      next
    }
    in_frontmatter && $0 == "---" { in_frontmatter = 0; next }
    !in_frontmatter { print }
  ' "$file" > "$temp"
  mv "$temp" "$file"
}

add_plan_continuation() {
  local file="$1" revision="$2"

  set_replay_continuation "$file" "tasks@$revision"
}

set_replay_continuation() {
  local file="$1" continuation="$2" temp="$file.tmp"

  awk -v continuation="$continuation" '
    /^replay_continuation:/ { next }
    /^derived_from:/ && !added { print "replay_continuation: " continuation; added = 1 }
    { print }
  ' "$file" > "$temp"
  mv "$temp" "$file"
}

analysis_owner_action() {
  local analysis_file="$1" result approved_replay

  result="$(awk '
    NR == 1 && $0 == "---" { frontmatter = 1; next }
    frontmatter && $0 == "---" { exit }
    frontmatter && /^analysis_result: / { print $2; exit }
  ' "$analysis_file")"
  approved_replay="$(awk -F ': ' '/^Approved replay: / { print $2; exit }' "$analysis_file")"

  case "$result:$approved_replay" in
    passed:yes)
      if grep -Fq '| `analysis_result: passed` | Persist the report, then apply the Step 8 status/timestamp rule. |' "$ANALYZE_SKILL"; then
        printf '%s\n' 'passing-result'
      else
        printf '%s\n' 'missing-passing-owner-branch'
      fi
      ;;
    failed:yes)
      if grep -Fq '| `analysis_result: failed` after an approved replay | Keep `status: tasked`, consume the earlier replay `yes`, start no correction, replay, or phase invocation, and require a new explicit user decision. |' "$ANALYZE_SKILL"; then
        printf '%s\n' 'stop-for-new-decision'
      else
        printf '%s\n' 'missing-failed-owner-branch'
      fi
      ;;
    *)
      printf 'unsupported-owner-branch:%s:%s\n' "$result" "$approved_replay"
      ;;
  esac
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

# Analysis metadata is parsed by the replay planner as an owned analysis result,
# not as review-envelope metadata or ordinary document content.
copy_fixture "$CURRENT" "valid-analysis-metadata"
run_planner "$CURRENT" tasks.md 0 analyze "valid analysis metadata"
assert_success "$LAST_STATUS" "valid analysis metadata accepted"
assert_equal "$LAST_OUTPUT" 'CHANGED|tasks.md|0|1
STALE|analysis.md
REPLAY|analyze' "valid analysis metadata preserves replay proposal"

copy_fixture "$CURRENT" "ordinary-analysis-metadata"
awk '
  /^derived_from:$/ {
    print "reviewer_context: fixture-spec-writer"
    print "reviewer_context_matches_harness: true"
    print "independence_verified: true"
    print "analysis_result: passed"
  }
  { print }
' "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
mv "$CASE_DIR/spec.md.tmp" "$CASE_DIR/spec.md"
run_planner "$CURRENT" spec.md 0 clarify "ordinary analysis metadata"
assert_exit "$LAST_STATUS" 2 "ordinary document analysis metadata rejected"
assert_no_proposal_output "$LAST_OUTPUT" "ordinary document metadata emits no proposal"

copy_fixture "$CURRENT" "malformed-analysis-metadata"
sed '/^independence_verified: true$/d' "$CASE_DIR/analysis.md" > "$CASE_DIR/analysis.md.tmp"
mv "$CASE_DIR/analysis.md.tmp" "$CASE_DIR/analysis.md"
run_planner "$CURRENT" analysis.md 0 analyze "missing analysis independence evidence"
assert_exit "$LAST_STATUS" 2 "malformed analysis metadata rejected"
assert_no_proposal_output "$LAST_OUTPUT" "malformed analysis emits no proposal"

for review in spec plan; do
  review_file="$CURRENT/reviews/$review-review.md"
  subject="$CURRENT/$review.md"
  writer="$(awk '/^writer_context: / { print $2; exit }' "$review_file")"
  reviewer="$(awk '/^reviewer_context: / { print $2; exit }' "$review_file")"
  reviewed_sha256="$(awk '/^reviewed_sha256: / { print $2; exit }' "$review_file")"
  assert_grep "$review_file" '^verdict: approved$' "$review review approved"
  assert_grep "$review_file" '^reviewer_context_matches_harness: true$' "$review review harness equality"
  assert_equal "$writer" "$reviewer" "$review review writer equals reviewer"
  assert_equal "$reviewed_sha256" "$(structural_sha256 "$subject")" "$review review canonical structural digest"
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

# T007 eligibility is explicit and future-only. Revision metadata never opts a
# root into replay, and malformed marker attempts fail before graph parsing.
copy_fixture "$CURRENT" "eligibility-exact-marker"
run_planner "$CURRENT" tasks.md 0 analyze "eligibility exact marker"
assert_success "$LAST_STATUS" "eligibility exact marker succeeds"

copy_fixture "$CURRENT" "eligibility-unmarked-versioned"
sed '/^replay_contract:/d' "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
mv "$CASE_DIR/spec.md.tmp" "$CASE_DIR/spec.md"
run_planner "$CURRENT" spec.md 0 clarify "eligibility unmarked versioned"
assert_exit "$LAST_STATUS" 4 "eligibility unmarked versioned is unsupported"
assert_equal "$LAST_OUTPUT" 'UNSUPPORTED_LEGACY' "eligibility unmarked versioned emits only unsupported"

ACTUAL_0019="$ROOT/docs/maxi/specs/0019-artifact-analysis-convergence"
CASE_DIR="$ACTUAL_0019"
run_planner "$ACTUAL_0019" spec.md 0 clarify "actual unmarked 0019"
assert_exit "$LAST_STATUS" 4 "actual unmarked 0019 is unsupported"
assert_equal "$LAST_OUTPUT" 'UNSUPPORTED_LEGACY' "actual unmarked 0019 emits only unsupported"

for marker_case in duplicate wrong-value; do
  copy_fixture "$CURRENT" "eligibility-$marker_case"
  case "$marker_case" in
    duplicate)
      awk '/^replay_contract:/ { print; print } !/^replay_contract:/ { print }' \
        "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
      ;;
    wrong-value)
      sed 's/^replay_contract:.*/replay_contract: bounded-v2/' \
        "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
      ;;
  esac
  mv "$CASE_DIR/spec.md.tmp" "$CASE_DIR/spec.md"
  run_planner "$CURRENT" spec.md 0 clarify "eligibility $marker_case"
  assert_exit "$LAST_STATUS" 2 "eligibility $marker_case is malformed"
  assert_no_proposal_output "$LAST_OUTPUT" "eligibility $marker_case emits no proposal"
done

# The persisted digest is structural. Operational status/timestamp transitions
# preserve approval; every retained byte class invalidates it.
copy_fixture "$CURRENT" "digest-non-structural"
set_replay_continuation "$CASE_DIR/spec.md" 'plan@1'
write_review_frontmatter "$CASE_DIR/reviews/spec-review.md" spec.md 1 fixture-spec-reviewer 1
sed -e 's/^status:.*/status: planned/' -e 's/^updated:.*/updated: 2026-08-05/' \
  "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
mv "$CASE_DIR/spec.md.tmp" "$CASE_DIR/spec.md"
run_planner "$CURRENT" reviews/spec-review.md 0 plan "digest non-structural"
assert_success "$LAST_STATUS" "digest non-structural planner exit"
assert_output_contains "$LAST_OUTPUT" 'REPLAY|plan' "digest status and timestamp preserve approval"

for structural_case in body revision writer contributors dependency continuation other-frontmatter; do
  copy_fixture "$CURRENT" "digest-structural-$structural_case"
  case "$structural_case" in
    dependency|continuation) ;;
    *) set_replay_continuation "$CASE_DIR/spec.md" 'plan@1' ;;
  esac
  review_path=reviews/spec-review.md
  case "$structural_case" in
    body)
      awk '{ print } END { print "changed structural body byte" }' "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
      mv "$CASE_DIR/spec.md.tmp" "$CASE_DIR/spec.md"
      ;;
    revision)
      sed 's/^revision: 1$/revision: 2/' "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
      mv "$CASE_DIR/spec.md.tmp" "$CASE_DIR/spec.md"
      set_replay_continuation "$CASE_DIR/spec.md" 'plan@2'
      ;;
    writer)
      sed -e 's/^writer_context: fixture-spec-writer$/writer_context: fixture-spec-writer-2/' \
          -e 's/^  - fixture-spec-writer$/  - fixture-spec-writer-2/' \
          "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
      mv "$CASE_DIR/spec.md.tmp" "$CASE_DIR/spec.md"
      ;;
    contributors)
      awk '/^replay_continuation:/ && !added { print "  - fixture-extra-contributor"; added = 1 } { print }' \
        "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
      mv "$CASE_DIR/spec.md.tmp" "$CASE_DIR/spec.md"
      ;;
    dependency)
      review_path=reviews/plan-review.md
      awk '/^  - reviews\/spec-review.md@1$/ { print; print "  - spec.md@1"; next } { print }' \
        "$CASE_DIR/plan.md" > "$CASE_DIR/plan.md.tmp"
      mv "$CASE_DIR/plan.md.tmp" "$CASE_DIR/plan.md"
      ;;
    continuation)
      review_path=reviews/plan-review.md
      add_plan_continuation "$CASE_DIR/plan.md" 1
      ;;
    other-frontmatter)
      awk '/^revision:/ && !added { print "custom_structural_field: retained"; added = 1 } { print }' \
        "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
      mv "$CASE_DIR/spec.md.tmp" "$CASE_DIR/spec.md"
      ;;
  esac
  case "$review_path" in
    reviews/spec-review.md) run_planner "$CURRENT" "$review_path" 0 plan "digest structural $structural_case" ;;
    reviews/plan-review.md) run_planner "$CURRENT" "$review_path" 0 tasks "digest structural $structural_case" ;;
  esac
  assert_success "$LAST_STATUS" "digest structural $structural_case planner exit"
  subject_name="${review_path#reviews/}"
  subject_name="${subject_name%-review.md}.md"
  subject_revision="$(awk '/^revision: / { print $2; exit }' "$CASE_DIR/$subject_name")"
  assert_output_contains "$LAST_OUTPUT" "REVIEW_REQUIRED|$subject_name|$subject_revision" "digest structural $structural_case invalidates approval"
done

# A YAML list item is legal only in the immediately active contributor or
# dependency block. Stray items must fail before any proposal is emitted.
for list_case in normal-after-revision normal-after-writer normal-after-ended-derived \
                 review-after-revision review-after-writer review-after-sha review-after-ended-derived; do
  copy_fixture "$CURRENT" "stray-list-$list_case"
  case "$list_case" in
    normal-after-revision) target=spec.md; anchor='revision:' ;;
    normal-after-writer) target=spec.md; anchor='writer_context:' ;;
    normal-after-ended-derived) target=spec.md; anchor='derived_from: []' ;;
    review-after-revision) target=reviews/spec-review.md; anchor='revision:' ;;
    review-after-writer) target=reviews/spec-review.md; anchor='writer_context:' ;;
    review-after-sha) target=reviews/spec-review.md; anchor='reviewed_sha256:' ;;
    review-after-ended-derived) target=reviews/spec-review.md; anchor='reviewed_document:' ;;
  esac
  awk -v anchor="$anchor" 'index($0, anchor) == 1 && !added { print; print "  - stray-list-item"; added = 1; next } { print }' \
    "$CASE_DIR/$target" > "$CASE_DIR/$target.tmp"
  mv "$CASE_DIR/$target.tmp" "$CASE_DIR/$target"
  case "$target" in
    spec.md) run_planner "$CURRENT" tasks.md 0 analyze "stray list $list_case" ;;
    reviews/spec-review.md) run_planner "$CURRENT" reviews/spec-review.md 0 plan "stray list $list_case" ;;
  esac
  assert_exit "$LAST_STATUS" 2 "stray list $list_case rejected"
  assert_no_proposal_output "$LAST_OUTPUT" "stray list $list_case emits no proposal"
done

# Template comments, including colons, are valid YAML frontmatter and close an
# active list. A following list item is therefore stray metadata, just as it is
# after a scalar.
copy_fixture "$CURRENT" "template-comments"
set_replay_continuation "$CASE_DIR/spec.md" 'plan@1'
for target in spec.md reviews/spec-review.md; do
  awk '
    /^  - .*writer$/ && !added { print; print "# template guidance: retained"; added = 1; next }
    { print }
  ' "$CASE_DIR/$target" > "$CASE_DIR/$target.tmp"
  mv "$CASE_DIR/$target.tmp" "$CASE_DIR/$target"
done
run_planner "$CURRENT" tasks.md 0 analyze "template comments"
assert_success "$LAST_STATUS" "marked forward documents with template comments accepted"
run_planner "$CURRENT" reviews/spec-review.md 0 plan "review template comments"
assert_success "$LAST_STATUS" "marked review documents with template comments accepted"

for list_case in normal-after-comment review-after-comment; do
  copy_fixture "$CURRENT" "stray-list-$list_case"
  case "$list_case" in
    normal-after-comment) target=spec.md; marker='fixture-spec-writer' ;;
    review-after-comment) target=reviews/spec-review.md; marker='fixture-spec-reviewer' ;;
  esac
  awk -v marker="$marker" '
    $0 == "  - " marker && !added { print; print "# template guidance"; print "  - stray-list-item"; added = 1; next }
    { print }
  ' "$CASE_DIR/$target" > "$CASE_DIR/$target.tmp"
  mv "$CASE_DIR/$target.tmp" "$CASE_DIR/$target"
  case "$target" in
    spec.md) run_planner "$CURRENT" tasks.md 0 analyze "stray list $list_case" ;;
    reviews/spec-review.md) run_planner "$CURRENT" reviews/spec-review.md 0 plan "stray list $list_case" ;;
  esac
  assert_exit "$LAST_STATUS" 2 "stray list $list_case rejected"
  assert_no_proposal_output "$LAST_OUTPUT" "stray list $list_case emits no proposal"
done

# Owner contracts fail closed at independent-review and replay-consent boundaries.
CLARIFY_SKILL="$ROOT/skills/clarify/SKILL.md"
PLAN_SKILL="$ROOT/skills/plan/SKILL.md"
TASKS_SKILL="$ROOT/skills/tasks/SKILL.md"
ANALYZE_SKILL="$ROOT/skills/analyze/SKILL.md"
IMPLEMENT_SKILL="$ROOT/skills/implement/SKILL.md"
REVISE_SKILL="$ROOT/skills/revise/SKILL.md"

assert_file_exists "$CLARIFY_SKILL" "clarify owner skill"
assert_file_exists "$PLAN_SKILL" "plan owner skill"
assert_file_exists "$TASKS_SKILL" "tasks owner skill"
assert_file_exists "$ANALYZE_SKILL" "analyze owner skill"
assert_file_exists "$IMPLEMENT_SKILL" "implement owner skill"
assert_file_exists "$REVISE_SKILL" "revise owner skill"

if [ -f "$CLARIFY_SKILL" ]; then
  assert_grep "$CLARIFY_SKILL" 'CHANGED.*STALE.*REPLAY.*REVIEW_REQUIRED' "clarify renders the complete planner record set"
  assert_grep "$CLARIFY_SKILL" 'previous revision.*current revision.*stale paths.*executable sequence.*review handoff' "clarify renders the replay proposal before execution"
  assert_grep "$CLARIFY_SKILL" 'entire response is exactly the lowercase literal `yes`' "clarify accepts only literal yes"
  assert_grep "$CLARIFY_SKILL" 'Silence, `ok`, prior consent.*no phase invocation' "clarify rejects ambiguous or reused consent"
  assert_grep "$CLARIFY_SKILL" '[Ss]top.*`REVIEW_REQUIRED`.*no phase after.*review handoff' "clarify stops at review handoff"
  assert_grep "$CLARIFY_SKILL" 'matching external review.*display.*remaining.*new literal `yes`' "clarify requires new consent after review"
  assert_grep "$CLARIFY_SKILL" 'planner.*read-only.*never writes.*never invokes' "clarify keeps planner read-only"
  assert_grep "$CLARIFY_SKILL" '[Nn]ever create or write `workflow.md`.*`.maxi-ops`' "clarify forbids undeclared runtime state"
  assert_grep "$CLARIFY_SKILL" 'replay_continuation: clarify@<current-spec-revision>.*Pending Source Continuation Presenter' "clarify recognizes persisted source continuation"
  assert_grep "$CLARIFY_SKILL" 'bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed spec.md --previous-revision <current-spec-revision> --start-phase clarify --resume-current-source' "clarify uses exact source resume command"
  assert_grep "$CLARIFY_SKILL" 'CONTINUATION\|clarify@<current-spec-revision>.*REPLAY\|clarify.*fresh literal `yes`' "clarify presents and consents to resumed source segment"
  assert_grep "$CLARIFY_SKILL" 'rejection.*ambiguous.*interruption.*changes no byte.*later `/maxi:clarify`.*repeats' "clarify source resume survives declined or interrupted consent"
  assert_grep "$CLARIFY_SKILL" '[Ii]mmediately before.*clarif.*revalidate.*marker' "clarify revalidates source marker before work"
  assert_grep "$CLARIFY_SKILL" 'including.*no-content-change.*replay_continuation: plan@<current-spec-revision>.*same owner write.*status.*clarified' "clarify persists plan continuation on every completion"
  assert_grep "$CLARIFY_SKILL" '[Oo]nly the exact `replay_contract: bounded-v1` root marker.*provenance.*replay_continuation.*planner' "clarify activates future-only behavior only for the root marker"
  assert_grep "$CLARIFY_SKILL" 'unmarked revision-bearing.*ordinary legacy clarification.*no provenance.*no replay continuation.*no planner' "clarify preserves actual 0019 legacy behavior"
fi

if [ -f "$PLAN_SKILL" ]; then
  assert_grep "$PLAN_SKILL" 'exact `replay_contract: bounded-v1` root marker.*Revision metadata alone.*never.*review gate' "plan keys the owner gate only to the forward marker"
  assert_grep "$PLAN_SKILL" 'missing, rejected, malformed, stale, or self-reviewed' "plan rejects every invalid review class"
  assert_grep "$PLAN_SKILL" 'before.*writing-plans.*before.*artifact write.*before.*status' "plan gates before all output and transition"
  assert_grep "$PLAN_SKILL" 'reviewed_document.*spec.md.*reviewed_revision.*current spec revision' "plan binds review to current spec revision"
  assert_grep "$PLAN_SKILL" 'exactly ten top-level fields.*revision.*writer_context.*structural_contributors.*derived_from.*reviewed_document.*reviewed_revision.*reviewed_sha256.*reviewer_context.*reviewer_context_matches_harness.*verdict' "plan requires the exact ten-field review envelope"
  assert_grep "$PLAN_SKILL" 'spec.md.*reviewed_sha256.*canonical structural projection.*omit.*status:.*updated:' "plan binds review to the current structural spec digest"
  assert_grep "$PLAN_SKILL" 'positive record.*reviewed revisions.*exactly one.*direct input.*canonical.*unique contributors.*writer_context.*reviewer_context.*writer equals reviewer.*appears in.*contributors' "plan validates review provenance completely"
  assert_grep "$PLAN_SKILL" 'reviewer_context_matches_harness.*true.*reviewer_context.*absent.*structural_contributors' "plan verifies reviewer independence"
  assert_grep "$PLAN_SKILL" '`x-review`.*sole writer.*never.*review record' "plan only validates review records"
  assert_grep "$PLAN_SKILL" '[Ee]xplicit.*structural.*correction.*`planned`.*`tasked`.*`analyzed`.*`implementing`' "plan correction has explicit accepted statuses"
  assert_grep "$PLAN_SKILL" '`parked`.*`cancelled`.*`done`.*blocked' "plan correction rejects terminal statuses"
  assert_grep "$PLAN_SKILL" 'capture.*previous.*plan revision.*before.*write' "plan correction captures predecessor revision"
  assert_grep "$PLAN_SKILL" 'replay_continuation: tasks@<current-plan-revision>' "plan correction persists continuation marker"
  assert_grep "$PLAN_SKILL" 'status.*`planned`.*bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed plan.md --previous-revision <captured> --start-phase tasks' "plan correction returns canonically and invokes planner"
  assert_correction_section_grep "$PLAN_SKILL" 'For a marked root, return.*replay-plan.sh' "plan correction scopes planner invocation to marked roots"
  assert_correction_section_grep "$PLAN_SKILL" 'For an unmarked root, return only.*without a continuation, planner, or review report' "plan correction keeps legacy recovery local"
  assert_correction_section_not_grep "$PLAN_SKILL" '^This correction.*A planner failure' "plan correction has no unscoped planner recovery"
  assert_grep "$PLAN_SKILL" 'never invokes `specify` or `clarify`.*never edits `tasks.md` or `analysis.md`' "plan correction excludes ancestors and descendants"
  assert_grep "$PLAN_SKILL" 'replay_continuation: plan@<current-spec-revision>.*pending continuation.*never.*normal' "plan separates resume from normal planning"
  assert_grep "$PLAN_SKILL" 'bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed reviews/spec-review.md --previous-revision <current-spec-review-revision> --start-phase plan --resume-current-review' "plan uses exact review resume command"
  assert_grep "$PLAN_SKILL" 'CONTINUATION\|plan@<current-spec-revision>.*REPLAY\|plan.*fresh literal `yes`' "plan presents and consents to resumed segment"
  assert_grep "$PLAN_SKILL" 'rejection.*ambiguous.*interruption.*changes no byte.*later `/maxi:plan`.*repeats' "plan resume survives declined or interrupted consent"
  assert_grep "$PLAN_SKILL" '[Ii]mmediately before.*planning.*revalidate.*marker.*complete review envelope.*current ancestry' "plan revalidates the complete resume boundary"
  assert_grep "$PLAN_SKILL" 'replay segment.*replay_continuation: tasks@<new-plan-revision>.*status.*planned.*--changed plan.md.*--start-phase tasks' "replayed plan persists tasks continuation and stops for review"
  assert_grep "$PLAN_SKILL" '[Aa]n exact `replay_contract: bounded-v1` root marker.*pending continuation presenter.*no-write presenter' "plan routes continuation only for the root marker"
  assert_grep "$PLAN_SKILL" 'unmarked revision-bearing.*ordinary legacy planning.*no review record.*x-review.*handoff.*review provenance.*review reporting.*replay continuation.*planner' "plan preserves actual 0019 without review or replay obligations"
fi

if [ -f "$TASKS_SKILL" ]; then
  assert_grep "$TASKS_SKILL" 'exact `replay_contract: bounded-v1` root marker.*Revision metadata alone.*never.*review gate' "tasks keys the owner gate only to the forward marker"
  assert_grep "$TASKS_SKILL" 'missing, rejected, malformed, stale, or self-reviewed' "tasks rejects every invalid review class"
  assert_grep "$TASKS_SKILL" 'before.*task extraction.*before.*artifact write.*before.*status' "tasks gates before all output and transition"
  assert_grep "$TASKS_SKILL" 'reviewed_document.*plan.md.*reviewed_revision.*current plan revision' "tasks binds review to current plan revision"
  assert_grep "$TASKS_SKILL" 'exactly ten top-level fields.*revision.*writer_context.*structural_contributors.*derived_from.*reviewed_document.*reviewed_revision.*reviewed_sha256.*reviewer_context.*reviewer_context_matches_harness.*verdict' "tasks requires the exact ten-field review envelope"
  assert_grep "$TASKS_SKILL" 'plan.md.*reviewed_sha256.*canonical structural projection.*omit.*status:.*updated:' "tasks binds review to the current structural plan digest"
  assert_grep "$TASKS_SKILL" 'positive record.*reviewed revisions.*exactly one.*direct input.*canonical.*unique contributors.*writer_context.*reviewer_context.*writer equals reviewer.*appears in.*contributors' "tasks validates review provenance completely"
  assert_grep "$TASKS_SKILL" 'reviewer_context_matches_harness.*true.*reviewer_context.*absent.*structural_contributors' "tasks verifies reviewer independence"
  assert_grep "$TASKS_SKILL" '`x-review`.*sole writer.*never.*review record' "tasks only validates review records"
  assert_grep "$TASKS_SKILL" '[Ee]xplicit.*structural.*correction.*`tasked`.*`analyzed`.*`implementing`' "tasks correction has explicit accepted statuses"
  assert_grep "$TASKS_SKILL" '`planned`.*replay_continuation.*pending continuation.*never.*normal initial extraction' "tasks separates resume from initial extraction"
  assert_grep "$TASKS_SKILL" 'marked root.*normal initial extraction.*only.*plan revision `1`.*no `replay_continuation` marker' "tasks limits marked initial extraction to revision one"
  assert_grep "$TASKS_SKILL" 'marked root.*plan revision.*greater than `1`.*missing or malformed.*marker.*fails closed.*before.*write.*status' "tasks rejects a marked corrected plan without an exact continuation marker"
  assert_grep "$TASKS_SKILL" 'unmarked revision-bearing.*ordinary legacy initial extraction.*any plan revision.*no review record.*x-review.*handoff.*review provenance.*review reporting.*replay continuation.*planner' "tasks accepts actual 0019 legacy extraction without review or replay obligations"
  assert_grep "$TASKS_SKILL" 'bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed reviews/plan-review.md --previous-revision <current-plan-review-revision> --start-phase tasks --resume-current-review' "tasks uses exact resume planner command"
  assert_grep "$TASKS_SKILL" 'fresh literal `yes` immediately after.*display.*revalidate.*marker.*review.*before writing' "tasks binds consent to displayed current continuation"
  assert_grep "$TASKS_SKILL" 'rejection.*ambiguous.*interruption.*changes nothing.*later `/maxi:tasks`.*no-write' "tasks resume survives a declined or interrupted consent"
  assert_correction_section_grep "$TASKS_SKILL" 'Read.*capture.*previous.*tasks revision.*before.*write' "tasks correction captures its predecessor before writing"
  assert_correction_section_grep "$TASKS_SKILL" 'For a marked root, return.*replay-plan.sh' "tasks correction scopes planner invocation to marked roots"
  assert_correction_section_grep "$TASKS_SKILL" 'For an unmarked root, return only.*without a continuation, planner, or review report' "tasks correction keeps legacy recovery local"
  assert_correction_section_not_grep "$TASKS_SKILL" '^Correction replay:' "tasks correction has no unscoped replay recovery"
  assert_grep "$TASKS_SKILL" 'never invokes `specify`, `clarify`, or `plan`' "tasks correction excludes ancestors"
  assert_grep "$TASKS_SKILL" '[Ii]mmediately before writing.*revalidate.*marker.*complete review envelope.*current ancestry' "tasks revalidates the complete resume boundary"
fi

if [ -f "$ANALYZE_SKILL" ]; then
  assert_grep "$ANALYZE_SKILL" 'fresh reviewer context issued by the harness' "analyze requires a fresh harness reviewer context"
  assert_grep "$ANALYZE_SKILL" 'reviewer context.*absent.*current `spec.md`.*`plan.md`.*`tasks.md`.*structural_contributors' "analyze verifies three-artifact independence"
  assert_grep "$ANALYZE_SKILL" 'before.*analysis write.*before.*status transition' "analyze verifies independence before output"
  assert_grep "$ANALYZE_SKILL" '^reviewer_context: <same-unique-writer-context>$' "analysis records reviewer context"
  assert_grep "$ANALYZE_SKILL" '^reviewer_context_matches_harness: true$' "analysis records harness equality"
  assert_grep "$ANALYZE_SKILL" '^independence_verified: true$' "analysis records independence result"
  assert_grep "$ANALYZE_SKILL" '^analysis_result: <passed-or-failed>$' "analysis records explicit result"
  assert_not_grep "$ANALYZE_SKILL" '^verdict: <passed-or-failed>$' "analysis does not collide with review verdict grammar"
  assert_grep "$ANALYZE_SKILL" 'derived_from.*reviewed current revisions' "analysis records reviewed current revisions"
  assert_grep "$ANALYZE_SKILL" 'approved replay.*analysis result.*failed.*new explicit user decision' "failed replay analysis requires a new decision"
  assert_grep "$ANALYZE_SKILL" 'no correction.*no replay.*no phase invocation' "failed replay analysis cannot loop"
  assert_grep "$ANALYZE_SKILL" 'analysis_result.*failed.*leave.*status.*`tasked`' "failed initial analysis does not advance status"
  assert_grep "$ANALYZE_SKILL" 'Never structurally modifies source artifact bodies.*sole source-file write.*non-structural.*status/timestamp' "analyze overview scopes source writes structurally"
  assert_grep "$ANALYZE_SKILL" 'writes no structural source artifact content.*sole source-file write.*non-structural.*status/timestamp' "analyze independence gate scopes source writes structurally"
  assert_grep "$ANALYZE_SKILL" 'Editing structural content in any source artifact' "analyze red flag scopes source writes structurally"
  assert_grep "$ANALYZE_SKILL" 'Structural source edits are forbidden.*status/timestamp.*non-structural' "analyze rationalization counter preserves the source-write exception"
  assert_not_grep "$ANALYZE_SKILL" 'Never modifies source artifacts' "analyze has no absolute source-write prohibition"
  assert_not_grep "$ANALYZE_SKILL" 'writes no source artifact' "analyze has no contradictory source-write statement"
  assert_not_grep "$ANALYZE_SKILL" 'Editing any source artifact' "analyze red flags have no absolute source-write prohibition"
  assert_not_grep "$ANALYZE_SKILL" 'may NEVER modify spec.md' "analyze counters have no absolute spec-write prohibition"
fi

if [ -f "$IMPLEMENT_SKILL" ]; then
  assert_grep "$IMPLEMENT_SKILL" 'absent, malformed, stale, failed, or non-independent' "implement rejects every invalid analysis class"
  assert_grep "$IMPLEMENT_SKILL" 'before.*status.*before.*task.*before.*x-develop' "implement gates before all mutation and delegation"
  assert_grep "$IMPLEMENT_SKILL" 'derived_from.*exact current revisions.*`spec.md`.*`plan.md`.*`tasks.md`' "implement rejects stale analysis inputs"
  assert_grep "$IMPLEMENT_SKILL" 'reviewer_context_matches_harness.*true.*independence_verified.*true.*analysis_result.*passed' "implement requires verified passing analysis"
  assert_grep "$IMPLEMENT_SKILL" 'reviewer_context.*absent.*current `spec.md`.*`plan.md`.*`tasks.md`.*structural_contributors' "implement rechecks analysis independence"
fi

if [ -f "$REVISE_SKILL" ]; then
  assert_grep "$REVISE_SKILL" 'real missing or ambiguous requirement.*exceptional.*`specified`' "revise retains exceptional specified rollback"
  assert_grep "$REVISE_SKILL" 'never.*replay `specify`' "revise never replays specify"
  assert_grep "$REVISE_SKILL" 'CHANGED.*STALE.*REPLAY.*REVIEW_REQUIRED' "revise renders the complete planner record set"
  assert_grep "$REVISE_SKILL" 'previous revision.*current revision.*stale paths.*executable sequence.*review handoff' "revise renders the replay proposal before execution"
  assert_grep "$REVISE_SKILL" 'entire response is exactly the lowercase literal `yes`' "revise accepts only literal yes"
  assert_grep "$REVISE_SKILL" 'Silence, `ok`, prior consent.*no phase invocation' "revise rejects ambiguous or reused consent"
  assert_grep "$REVISE_SKILL" '[Ss]top.*`REVIEW_REQUIRED`.*no phase after.*review handoff' "revise stops at review handoff"
  assert_grep "$REVISE_SKILL" 'matching external review.*display.*remaining.*new literal `yes`' "revise requires new consent after review"
  assert_grep "$REVISE_SKILL" 'failed analysis.*new explicit user decision.*no correction.*no replay' "revise cannot repeat a failed replay"
  assert_grep "$REVISE_SKILL" 'planner.*read-only.*never writes.*never invokes' "revise keeps planner read-only"
  assert_grep "$REVISE_SKILL" '[Nn]ever create or write `workflow.md`.*`.maxi-ops`' "revise forbids undeclared runtime state"
  assert_grep "$REVISE_SKILL" 'specified.*replay_continuation: clarify@<new-spec-revision>.*same.*spec.md.*write' "revise persists exceptional clarify continuation"
  assert_grep "$REVISE_SKILL" '[Oo]nly the exact `replay_contract: bounded-v1` root marker.*provenance.*replay_continuation.*planner' "revise activates future-only behavior only for the root marker"
  assert_grep "$REVISE_SKILL" 'unmarked revision-bearing.*legacy revise.*no provenance.*no replay continuation.*no planner' "revise preserves actual 0019 legacy behavior"
fi

# The persisted result, not the planner's terminal output, selects the analyze owner
# branch after an approved replay. A passing control proves the probe is branch-sensitive.
copy_fixture "$CURRENT" "failed-analysis-after-approved-replay"
awk '
  /^analysis_result: / {
    print "analysis_result: failed"
    next
  }
  { print }
  END {
    print ""
    print "## Replay Outcome Fixture"
    print ""
    print "Approved replay: yes"
    print "Analysis result: failed"
  }
' "$CASE_DIR/analysis.md" > "$CASE_DIR/analysis.md.tmp"
mv "$CASE_DIR/analysis.md.tmp" "$CASE_DIR/analysis.md"
run_planner "$CURRENT" "analysis.md" 0 analyze "failed analysis after approved replay"
assert_success "$LAST_STATUS" "failed analysis fixture planner exit"
assert_equal "$LAST_OUTPUT" 'CHANGED|analysis.md|0|1' "failed analysis fixture directs no automatic action"
if printf '%s\n' "$LAST_OUTPUT" | grep -Eq '^(REPLAY|CORRECTION)\|'; then
  echo "FAIL [failed analysis fixture waits for decision]: directed action found" >&2
  failures=$((failures + 1))
else
  echo "OK  [failed analysis fixture waits for decision]"
fi
assert_equal "$(analysis_owner_action "$CASE_DIR/analysis.md")" 'stop-for-new-decision' "failed analysis fixture selects owner stop branch"

copy_fixture "$CURRENT" "passed-analysis-after-approved-replay"
awk '
  /^analysis_result: / {
    print "analysis_result: passed"
    next
  }
  { print }
  END {
    print ""
    print "## Replay Outcome Fixture"
    print ""
    print "Approved replay: yes"
    print "Analysis result: passed"
  }
' "$CASE_DIR/analysis.md" > "$CASE_DIR/analysis.md.tmp"
mv "$CASE_DIR/analysis.md.tmp" "$CASE_DIR/analysis.md"
assert_equal "$(analysis_owner_action "$CASE_DIR/analysis.md")" 'passing-result' "passing analysis fixture selects owner passing branch"

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
set_replay_continuation "$CASE_DIR/spec.md" 'clarify@2'
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
CONTINUATION|clarify@2
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

# A rejected or interrupted source proposal is re-presented from its persisted marker.
for resume_case in rejection non-literal-yes fresh-session-interruption; do
  copy_fixture "$CURRENT" "resume-clarify-$resume_case"
  bump_revision "$CASE_DIR/spec.md" "fixture-revise-writer"
  set_replay_continuation "$CASE_DIR/spec.md" 'clarify@2'
  run_planner "$CURRENT" spec.md 2 clarify "resume clarify $resume_case" '' resume-source
  assert_success "$LAST_STATUS" "resume clarify $resume_case planner exit"
  assert_equal "$LAST_OUTPUT" 'CONTINUATION|clarify@2
REPLAY|clarify' "resume clarify $resume_case exact display"
done

# A clarified specification must hand off to review before planning.
copy_fixture "$CURRENT" "clarified-spec"
bump_revision "$CASE_DIR/spec.md" "fixture-clarify-writer"
set_replay_continuation "$CASE_DIR/spec.md" 'plan@2'
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
CONTINUATION|plan@2
REVIEW_REQUIRED|spec.md|2'
assert_equal "$LAST_OUTPUT" "$expected_clarified_spec_output" "clarified spec exact handoff tail"
assert_no_replay_after_review "$LAST_OUTPUT" "clarified spec stops after review handoff"

# A newly approved review reopens only its immediate successor segment.
copy_fixture "$CURRENT" "spec-review-approved"
set_replay_continuation "$CASE_DIR/spec.md" 'plan@1'
write_review_frontmatter "$CASE_DIR/reviews/spec-review.md" spec.md 2 fixture-new-spec-reviewer 1
run_planner "$CURRENT" "reviews/spec-review.md" 1 plan "approved spec review"
assert_success "$LAST_STATUS" "approved spec review planner exit"
expected_spec_review_output='CHANGED|reviews/spec-review.md|1|2
STALE|analysis.md
STALE|plan.md
STALE|reviews/plan-review.md
STALE|tasks.md
CONTINUATION|plan@1
REPLAY|plan'
assert_equal "$LAST_OUTPUT" "$expected_spec_review_output" "approved spec review exact records"

# Plan consent is never reused: every rejected, ambiguous, or interrupted
# presentation resumes from the already-current spec review without rewriting it.
for resume_case in rejection non-literal-yes fresh-session-interruption; do
  copy_fixture "$CURRENT" "resume-plan-$resume_case"
  set_replay_continuation "$CASE_DIR/spec.md" 'plan@1'
  write_review_frontmatter "$CASE_DIR/reviews/spec-review.md" spec.md 1 fixture-resume-spec-reviewer 1
  run_planner "$CURRENT" reviews/spec-review.md 1 plan "resume plan $resume_case" '' resume
  assert_success "$LAST_STATUS" "resume plan $resume_case planner exit"
  assert_equal "$LAST_OUTPUT" 'CONTINUATION|plan@1
REPLAY|plan' "resume plan $resume_case exact display"
done

copy_fixture "$CURRENT" "plan-review-approved"
write_review_frontmatter "$CASE_DIR/reviews/plan-review.md" plan.md 2 fixture-new-plan-reviewer 1
run_planner "$CURRENT" "reviews/plan-review.md" 1 tasks "approved plan review"
assert_success "$LAST_STATUS" "approved plan review planner exit"
expected_plan_review_output='CHANGED|reviews/plan-review.md|1|2
STALE|analysis.md
STALE|tasks.md
REPLAY|tasks
REPLAY|analyze'
assert_equal "$LAST_OUTPUT" "$expected_plan_review_output" "approved plan review exact records"

# A corrected plan binds the review handoff to its exact revision. The first and
# replacement review branches both display, but never execute, the remainder.
copy_fixture "$CURRENT" "corrected-plan-first-review"
bump_revision "$CASE_DIR/plan.md" "fixture-corrected-plan-writer"
add_plan_continuation "$CASE_DIR/plan.md" 2
rm "$CASE_DIR/reviews/plan-review.md"
rm "$CASE_DIR/tasks.md" "$CASE_DIR/analysis.md"
run_planner "$CURRENT" "plan.md" 1 tasks "corrected plan before first review"
assert_success "$LAST_STATUS" "corrected plan before first review planner exit"
assert_output_contains "$LAST_OUTPUT" 'REVIEW_REQUIRED|plan.md|2' "corrected plan stops for first review"
cp "$CURRENT/reviews/plan-review.md" "$CASE_DIR/reviews/plan-review.md"
write_review_frontmatter "$CASE_DIR/reviews/plan-review.md" plan.md 1 fixture-first-plan-reviewer 2
run_planner "$CURRENT" "reviews/plan-review.md" 0 tasks "corrected plan first review"
assert_success "$LAST_STATUS" "corrected plan first review planner exit"
assert_output_contains "$LAST_OUTPUT" 'CONTINUATION|tasks@2' "first plan review displays bound continuation"
assert_output_contains "$LAST_OUTPUT" 'REPLAY|tasks' "first plan review displays tasks"
assert_output_contains "$LAST_OUTPUT" 'REPLAY|analyze' "first plan review displays analyze"

copy_fixture "$CURRENT" "corrected-plan-replacement-review"
bump_revision "$CASE_DIR/plan.md" "fixture-corrected-plan-writer"
add_plan_continuation "$CASE_DIR/plan.md" 2
write_review_frontmatter "$CASE_DIR/reviews/plan-review.md" plan.md 2 fixture-replacement-plan-reviewer 2
run_planner "$CURRENT" "reviews/plan-review.md" 1 tasks "corrected plan replacement review"
assert_success "$LAST_STATUS" "corrected plan replacement review planner exit"
assert_output_contains "$LAST_OUTPUT" 'CONTINUATION|tasks@2' "replacement plan review displays bound continuation"
assert_output_contains "$LAST_OUTPUT" 'REPLAY|tasks' "replacement plan review displays tasks"
assert_output_contains "$LAST_OUTPUT" 'REPLAY|analyze' "replacement plan review displays analyze"

# Rejection, a non-literal answer, and an interrupted session all resume by
# redisplaying the already-current review without requiring its predecessor.
for resume_case in rejection non-literal-yes fresh-session-interruption; do
  copy_fixture "$CURRENT" "resume-$resume_case"
  bump_revision "$CASE_DIR/plan.md" "fixture-corrected-plan-writer"
  add_plan_continuation "$CASE_DIR/plan.md" 2
  write_review_frontmatter "$CASE_DIR/reviews/plan-review.md" plan.md 2 fixture-resume-plan-reviewer 2
  run_planner "$CURRENT" "reviews/plan-review.md" 2 tasks "resume $resume_case" '' resume
  assert_success "$LAST_STATUS" "resume $resume_case planner exit"
  assert_equal "$LAST_OUTPUT" 'CONTINUATION|tasks@2
REPLAY|tasks
REPLAY|analyze' "resume $resume_case exact display"
done

# A matching plan and plan review cannot hide a stale transitive ancestor.
for stale_ancestor in spec research data-model contract spec-review; do
  copy_fixture "$CURRENT" "resume-stale-ancestor-$stale_ancestor"
  set_replay_continuation "$CASE_DIR/spec.md" 'plan@1'
  write_review_frontmatter "$CASE_DIR/reviews/spec-review.md" spec.md 1 fixture-current-spec-reviewer 1
  add_plan_continuation "$CASE_DIR/plan.md" 1
  write_review_frontmatter "$CASE_DIR/reviews/plan-review.md" plan.md 1 fixture-current-plan-reviewer 1
  plan_before="$(shasum -a 256 "$CASE_DIR/plan.md" | awk '{print $1}')"
  plan_review_before="$(shasum -a 256 "$CASE_DIR/reviews/plan-review.md" | awk '{print $1}')"
  case "$stale_ancestor" in
    spec)
      bump_revision "$CASE_DIR/spec.md" fixture-stale-spec-writer
      set_replay_continuation "$CASE_DIR/spec.md" 'plan@2'
      ;;
    research) bump_revision "$CASE_DIR/research.md" fixture-stale-research-writer ;;
    data-model) bump_revision "$CASE_DIR/data-model.md" fixture-stale-data-model-writer ;;
    contract) bump_revision "$CASE_DIR/contracts/api.md" fixture-stale-contract-writer ;;
    spec-review)
      write_review_frontmatter "$CASE_DIR/reviews/spec-review.md" spec.md 2 fixture-new-spec-reviewer 1
      ;;
  esac
  assert_equal "$(shasum -a 256 "$CASE_DIR/plan.md" | awk '{print $1}')" "$plan_before" "stale $stale_ancestor keeps plan bytes matched"
  assert_equal "$(shasum -a 256 "$CASE_DIR/reviews/plan-review.md" | awk '{print $1}')" "$plan_review_before" "stale $stale_ancestor keeps plan review bytes matched"
  run_planner "$CURRENT" reviews/plan-review.md 1 tasks "resume stale ancestor $stale_ancestor" '' resume
  assert_exit "$LAST_STATUS" 2 "resume stale ancestor $stale_ancestor fails closed"
  assert_no_proposal_output "$LAST_OUTPUT" "resume stale ancestor $stale_ancestor emits no continuation"
  run_planner "$CURRENT" reviews/plan-review.md 0 tasks "post-write stale ancestor $stale_ancestor"
  assert_exit "$LAST_STATUS" 2 "post-write stale ancestor $stale_ancestor fails closed"
  assert_no_proposal_output "$LAST_OUTPUT" "post-write stale ancestor $stale_ancestor emits no continuation"
done

# One deterministic chain persists every handoff from a revised source through
# both independent reviews. Planner calls only present; owner writes are modeled
# explicitly between calls.
copy_fixture "$CURRENT" "complete-spec-to-tasks-continuation"
set_document_revision "$CASE_DIR/spec.md" 2 fixture-e2e-revise-writer
set_replay_continuation "$CASE_DIR/spec.md" 'clarify@2'
run_planner "$CURRENT" spec.md 1 clarify "e2e revised source"
assert_success "$LAST_STATUS" "e2e revised source planner exit"
assert_output_contains "$LAST_OUTPUT" 'CONTINUATION|clarify@2' "e2e persists clarify marker"
assert_output_contains "$LAST_OUTPUT" 'REPLAY|clarify' "e2e presents clarify"
E2E_OUTPUT="$LAST_OUTPUT"

# Model rejection of the first proposal, then a fresh-session presenter call.
run_planner "$CURRENT" spec.md 2 clarify "e2e resumed clarify" '' resume-source
assert_success "$LAST_STATUS" "e2e resumed clarify planner exit"
assert_equal "$LAST_OUTPUT" 'CONTINUATION|clarify@2
REPLAY|clarify' "e2e resumed clarify exact records"
E2E_OUTPUT="$E2E_OUTPUT
$LAST_OUTPUT"

# Model clarify's owner write, including the no-gap handoff metadata replacement.
set_document_revision "$CASE_DIR/spec.md" 3 fixture-e2e-clarify-writer
set_replay_continuation "$CASE_DIR/spec.md" 'plan@3'
run_planner "$CURRENT" spec.md 2 plan "e2e clarified source"
assert_success "$LAST_STATUS" "e2e clarified source planner exit"
assert_output_contains "$LAST_OUTPUT" 'CONTINUATION|plan@3' "e2e persists plan marker"
assert_output_contains "$LAST_OUTPUT" 'REVIEW_REQUIRED|spec.md|3' "e2e stops for spec review"
E2E_OUTPUT="$E2E_OUTPUT
$LAST_OUTPUT"

# Model x-review's sole review write and both initial and resumed plan presentations.
write_review_frontmatter "$CASE_DIR/reviews/spec-review.md" spec.md 2 fixture-e2e-spec-reviewer 3
run_planner "$CURRENT" reviews/spec-review.md 1 plan "e2e spec review post-write"
assert_success "$LAST_STATUS" "e2e spec review planner exit"
assert_output_contains "$LAST_OUTPUT" 'CONTINUATION|plan@3' "e2e spec review preserves plan marker"
assert_output_contains "$LAST_OUTPUT" 'REPLAY|plan' "e2e spec review presents plan"
E2E_OUTPUT="$E2E_OUTPUT
$LAST_OUTPUT"
run_planner "$CURRENT" reviews/spec-review.md 2 plan "e2e resumed plan" '' resume
assert_success "$LAST_STATUS" "e2e resumed plan planner exit"
assert_equal "$LAST_OUTPUT" 'CONTINUATION|plan@3
REPLAY|plan' "e2e resumed plan exact records"
E2E_OUTPUT="$E2E_OUTPUT
$LAST_OUTPUT"

# Model plan's owner writes. Every support input and the plan move to the exact
# current source/review revisions before the new tasks continuation is proposed.
for support in research.md data-model.md contracts/api.md; do
  set_document_revision "$CASE_DIR/$support" 2 "fixture-e2e-${support##*/}-writer"
  sed 's/spec.md@1/spec.md@3/' "$CASE_DIR/$support" > "$CASE_DIR/$support.tmp"
  mv "$CASE_DIR/$support.tmp" "$CASE_DIR/$support"
done
set_document_revision "$CASE_DIR/plan.md" 2 fixture-e2e-plan-writer
sed -e 's/spec.md@1/spec.md@3/' \
    -e 's/research.md@1/research.md@2/' \
    -e 's/data-model.md@1/data-model.md@2/' \
    -e 's#contracts/api.md@1#contracts/api.md@2#' \
    -e 's#reviews/spec-review.md@1#reviews/spec-review.md@2#' \
    "$CASE_DIR/plan.md" > "$CASE_DIR/plan.md.tmp"
mv "$CASE_DIR/plan.md.tmp" "$CASE_DIR/plan.md"
add_plan_continuation "$CASE_DIR/plan.md" 2
run_planner "$CURRENT" plan.md 1 tasks "e2e replayed plan"
assert_success "$LAST_STATUS" "e2e replayed plan planner exit"
assert_output_contains "$LAST_OUTPUT" 'CONTINUATION|tasks@2' "e2e persists tasks marker"
assert_output_contains "$LAST_OUTPUT" 'REVIEW_REQUIRED|plan.md|2' "e2e stops for plan review"
E2E_OUTPUT="$E2E_OUTPUT
$LAST_OUTPUT"

# Model the second x-review write and the separate tasks consent presentation.
write_review_frontmatter "$CASE_DIR/reviews/plan-review.md" plan.md 2 fixture-e2e-plan-reviewer 2
run_planner "$CURRENT" reviews/plan-review.md 1 tasks "e2e plan review post-write"
assert_success "$LAST_STATUS" "e2e plan review planner exit"
assert_output_contains "$LAST_OUTPUT" 'CONTINUATION|tasks@2' "e2e plan review preserves tasks marker"
assert_output_contains "$LAST_OUTPUT" 'REPLAY|tasks' "e2e plan review presents tasks"
E2E_OUTPUT="$E2E_OUTPUT
$LAST_OUTPUT"
run_planner "$CURRENT" reviews/plan-review.md 2 tasks "e2e resumed tasks" '' resume
assert_success "$LAST_STATUS" "e2e resumed tasks planner exit"
assert_equal "$LAST_OUTPUT" 'CONTINUATION|tasks@2
REPLAY|tasks
REPLAY|analyze' "e2e resumed tasks exact records"
E2E_OUTPUT="$E2E_OUTPUT
$LAST_OUTPUT"
if printf '%s\n' "$E2E_OUTPUT" | grep -Fqx 'REPLAY|specify'; then
  echo "FAIL [e2e chain never replays specify]" >&2
  failures=$((failures + 1))
else
  echo "OK  [e2e chain never replays specify]"
fi

copy_fixture "$CURRENT" "resume-missing-marker"
run_planner "$CURRENT" "reviews/plan-review.md" 1 tasks "resume missing marker" '' resume
assert_exit "$LAST_STATUS" 2 "resume missing marker fails closed"

copy_fixture "$CURRENT" "resume-stale-marker"
add_plan_continuation "$CASE_DIR/plan.md" 2
run_planner "$CURRENT" "reviews/plan-review.md" 1 tasks "resume stale marker" '' resume
assert_exit "$LAST_STATUS" 2 "resume stale marker fails closed"

copy_fixture "$CURRENT" "resume-stale-review"
bump_revision "$CASE_DIR/plan.md" "fixture-corrected-plan-writer"
add_plan_continuation "$CASE_DIR/plan.md" 2
run_planner "$CURRENT" "reviews/plan-review.md" 1 tasks "resume stale review" '' resume
assert_exit "$LAST_STATUS" 2 "resume stale review fails closed"

copy_fixture "$CURRENT" "resume-review-wrong-combination"
run_planner "$CURRENT" "reviews/spec-review.md" 1 tasks "resume review wrong combination" '' resume
assert_exit "$LAST_STATUS" 2 "review resume flag rejects an unsupported path and phase"

copy_fixture "$CURRENT" "resume-source-missing-marker"
run_planner "$CURRENT" spec.md 1 clarify "resume source missing marker" '' resume-source
assert_exit "$LAST_STATUS" 2 "source resume requires its exact marker"
assert_no_proposal_output "$LAST_OUTPUT" "source resume missing marker emits no proposal"

copy_fixture "$CURRENT" "resume-source-wrong-combination"
set_replay_continuation "$CASE_DIR/spec.md" 'clarify@1'
run_planner "$CURRENT" spec.md 1 plan "resume source wrong combination" '' resume-source
assert_exit "$LAST_STATUS" 2 "source resume flag rejects an unsupported phase"
assert_no_proposal_output "$LAST_OUTPUT" "source resume wrong phase emits no proposal"

# The review envelope fails closed when required equality evidence is missing
# or malformed, and never accepts a digest that does not match current bytes.
for review_case in missing-sha malformed-sha mismatched-sha missing-harness false-harness extra-field uppercase-field hyphen-field malformed-old-contributor duplicate-contributor; do
  copy_fixture "$CURRENT" "review-envelope-$review_case"
  set_replay_continuation "$CASE_DIR/spec.md" 'plan@1'
  case "$review_case" in
    missing-sha) sed '/^reviewed_sha256:/d' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp" ;;
    malformed-sha) sed 's/^reviewed_sha256:.*/reviewed_sha256: xyz/' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp" ;;
    mismatched-sha) sed 's/^reviewed_sha256:.*/reviewed_sha256: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp" ;;
    missing-harness) sed '/^reviewer_context_matches_harness:/d' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp" ;;
    false-harness) sed 's/^reviewer_context_matches_harness:.*/reviewer_context_matches_harness: false/' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp" ;;
    extra-field) sed '/^reviewed_document:/i\
unexpected_review_field: value' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp" ;;
    uppercase-field) sed '/^reviewed_document:/i\
Unexpected_Field: value' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp" ;;
    hyphen-field) sed '/^reviewed_document:/i\
unexpected-field: value' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp" ;;
    malformed-old-contributor) awk '
      /^structural_contributors:$/ { print; print "  - 1invalid-old-contributor"; next }
      { print }
    ' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp" ;;
    duplicate-contributor)
      review_writer="$(awk '/^writer_context: / { print $2; exit }' "$CASE_DIR/reviews/spec-review.md")"
      awk -v context="$review_writer" '
        /^structural_contributors:$/ { print; print "  - " context; next }
        { print }
      ' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp"
      ;;
  esac
  mv "$CASE_DIR/reviews/spec-review.md.tmp" "$CASE_DIR/reviews/spec-review.md"
  run_planner "$CURRENT" "reviews/spec-review.md" 0 plan "review envelope $review_case"
  if [ "$review_case" = mismatched-sha ]; then
    assert_success "$LAST_STATUS" "review envelope mismatched SHA is handled as stale"
    assert_output_contains "$LAST_OUTPUT" 'REVIEW_REQUIRED|spec.md|1' "review envelope mismatched SHA cannot authorize replay"
  else
    assert_exit "$LAST_STATUS" 2 "review envelope $review_case rejected"
  fi
done

# Both persisted review contexts independently obey the canonical grammar.
for review_field_name in writer_context reviewer_context; do
  for malformed_context in '1leading' 'has space' 'has	tab' 'null' 'TRUE' 'False' 'YeS' 'NO' 'On' 'oFf' 'Y' 'n'; do
    copy_fixture "$CURRENT" "context-$review_field_name-$(printf '%s' "$malformed_context" | tr ' \t' '__')"
    awk -v field="$review_field_name" -v context="$malformed_context" '
      index($0, field ":") == 1 { print field ": " context; next }
      { print }
    ' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp"
    mv "$CASE_DIR/reviews/spec-review.md.tmp" "$CASE_DIR/reviews/spec-review.md"
    run_planner "$CURRENT" "reviews/spec-review.md" 0 plan "malformed $review_field_name $malformed_context"
    assert_exit "$LAST_STATUS" 2 "malformed $review_field_name $malformed_context rejected"
  done
done

long_context="A$(printf '%0128d' 0)"
for review_field_name in writer_context reviewer_context; do
  copy_fixture "$CURRENT" "context-$review_field_name-overlong"
  awk -v field="$review_field_name" -v context="$long_context" '
    index($0, field ":") == 1 { print field ": " context; next }
    { print }
  ' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp"
  mv "$CASE_DIR/reviews/spec-review.md.tmp" "$CASE_DIR/reviews/spec-review.md"
  run_planner "$CURRENT" "reviews/spec-review.md" 0 plan "overlong $review_field_name"
  assert_exit "$LAST_STATUS" 2 "overlong $review_field_name rejected"
done

for review_field_name in writer_context reviewer_context; do
  copy_fixture "$CURRENT" "context-$review_field_name-newline"
  awk -v field="$review_field_name" '
    index($0, field ":") == 1 { print field ": valid"; print "injected"; next }
    { print }
  ' "$CASE_DIR/reviews/spec-review.md" > "$CASE_DIR/reviews/spec-review.md.tmp"
  mv "$CASE_DIR/reviews/spec-review.md.tmp" "$CASE_DIR/reviews/spec-review.md"
  run_planner "$CURRENT" "reviews/spec-review.md" 0 plan "newline $review_field_name"
  assert_exit "$LAST_STATUS" 2 "newline $review_field_name rejected"
done

# Invalid graph metadata always fails closed and never alters its copied input.
copy_fixture "$FIXTURES/missing-review" "missing-review"
bump_revision "$CASE_DIR/spec.md" "fixture-missing-review-revise-writer"
set_replay_continuation "$CASE_DIR/spec.md" 'plan@2'
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
awk -v context="$glob_pattern" '
  /^writer_context: / { print "writer_context: " context; next }
  /^  - fixture-spec-writer$/ { print "  - " context; next }
  { print }
' "$CASE_DIR/spec.md" > "$CASE_DIR/spec.md.tmp"
mv "$CASE_DIR/spec.md.tmp" "$CASE_DIR/spec.md"
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
awk '
  /^revision: / { print "revision: 2"; next }
  /^writer_context: / { print "writer_context: fixture-analysis-revision-writer"; next }
  /^structural_contributors:$/ {
    print
    print "  - fixture-analysis-revision-writer"
    next
  }
  /^reviewer_context: / { print "reviewer_context: fixture-analysis-revision-writer"; next }
  { print }
' "$CASE_DIR/analysis.md" > "$CASE_DIR/analysis.md.tmp"
mv "$CASE_DIR/analysis.md.tmp" "$CASE_DIR/analysis.md"
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
