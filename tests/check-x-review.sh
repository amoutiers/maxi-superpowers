#!/usr/bin/env bash
# Validate the independent review-record owner and its persisted record contract.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

SKILL="$ROOT/skills/x-review/SKILL.md"
TEMPLATE="$ROOT/skills/x-review/review-template.md"
failures=0

assert_equal() {
  local actual="$1" expected="$2" label="$3"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL [$label]: expected '$expected', got '$actual'" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

assert_literal() {
  local file="$1" literal="$2" label="$3"
  if ! grep -Fq "$literal" "$file"; then
    echo "FAIL [$label]: missing literal '$literal' in $file" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

assert_file_exists "$SKILL" "x-review skill"
assert_file_exists "$TEMPLATE" "x-review template"

if [ -f "$TEMPLATE" ]; then
  assert_starts_with_yaml_frontmatter "$TEMPLATE" "review template frontmatter"

  actual_fields="$(awk '
    NR == 1 && $0 == "---" { frontmatter = 1; next }
    frontmatter && $0 == "---" { exit }
    frontmatter && /^[a-z0-9_]+:/ { sub(/:.*/, ""); print }
  ' "$TEMPLATE" | LC_ALL=C sort)"
  expected_fields="$(printf '%s\n' \
    derived_from reviewed_document reviewed_revision reviewed_sha256 \
    reviewer_context reviewer_context_matches_harness revision \
    structural_contributors verdict writer_context | LC_ALL=C sort)"
  assert_equal "$actual_fields" "$expected_fields" "review template exact field set"

  assert_grep "$TEMPLATE" '^revision: 1$' "review template initial revision"
  assert_grep "$TEMPLATE" '^writer_context: <verified-reviewer-context>$' "review template writer context"
  assert_grep "$TEMPLATE" '^structural_contributors:$' "review template contributors"
  assert_grep "$TEMPLATE" '^  - <verified-reviewer-context>$' "review template initial contributor"
  assert_grep "$TEMPLATE" '^derived_from:$' "review template direct input"
  assert_grep "$TEMPLATE" '^  - <reviewed-document>@<reviewed-revision>$' "review template exact input revision"
  assert_grep "$TEMPLATE" '^reviewed_document: <reviewed-document>$' "review template reviewed document"
  assert_grep "$TEMPLATE" '^reviewed_revision: <reviewed-revision>$' "review template reviewed revision"
  assert_grep "$TEMPLATE" '^reviewed_sha256: <reviewed-sha256>$' "review template reviewed SHA-256"
  assert_grep "$TEMPLATE" '^reviewer_context: <verified-reviewer-context>$' "review template reviewer context"
  assert_grep "$TEMPLATE" '^reviewer_context_matches_harness: true$' "review template harness-context equality"
  assert_grep "$TEMPLATE" '^verdict: approved$' "review template approved verdict"
  assert_grep "$TEMPLATE" '^## Findings$' "review template findings body"
  assert_grep "$TEMPLATE" '^## Verdict$' "review template verdict body"
  assert_grep "$TEMPLATE" '^## Verification Results$' "review template verification body"
  assert_grep "$TEMPLATE" 'canonical structural projection' "review template structural-digest verification"
  assert_grep "$TEMPLATE" 'absent from the subject.*structural_contributors' "review template independence verification"
fi

if [ -f "$SKILL" ]; then
  assert_grep "$SKILL" 'Only accept exactly `spec.md` or `plan.md`' "x-review rejects unknown subjects"
  assert_grep "$SKILL" 'root `spec.md`.*exactly one `replay_contract: bounded-v1`.*before dispatch.*before write' "x-review requires exact forward eligibility"
  assert_grep "$SKILL" 'Revision metadata alone.*never.*eligible' "x-review never infers eligibility from revision metadata"
  assert_grep "$SKILL" 'current subject revision.*claimed revision.*exactly match' "x-review rejects revision mismatch"
  assert_grep "$SKILL" '[Rr]ecompute.*reviewed_sha256.*canonical structural projection' "x-review recomputes the structural SHA-256"
  assert_grep "$SKILL" '[Oo]mit only.*top-level `status:` and `updated:`.*first YAML frontmatter block.*preserve every other line.*one LF' "x-review defines the canonical structural projection"
  assert_grep "$SKILL" 'status.*timestamp.*preserve.*digest.*other byte change.*invalidates' "x-review distinguishes non-structural and structural changes"
  assert_grep "$SKILL" 'returned path, revision, and SHA-256.*exactly equal.*envelope.*freshly reread.*structural digest' "x-review binds return identity to envelope and current subject"
  assert_grep "$SKILL" 'returned reviewer context.*exactly equal.*envelope.*harness-issued context' "x-review binds reviewer context to envelope and harness"
  assert_grep "$SKILL" 'returned reviewer context.*independently absent from both.*structural_contributors' "x-review keeps reviewer context independent"
  assert_grep "$SKILL" 'missing.*reviewer context' "x-review rejects missing context"
  assert_grep "$SKILL" 'verdict.*exactly `approved`' "x-review rejects non-approved verdict"
  assert_grep "$SKILL" 'structural_contributors.*reviewer context' "x-review checks subject contributors"
  assert_literal "$SKILL" '^[A-Za-z][A-Za-z0-9._-]{0,127}$' "x-review defines canonical context grammar"
  assert_grep "$SKILL" 'newline.*carriage return.*tab.*space' "x-review rejects multiline and whitespace contexts"
  assert_literal "$SKILL" 'YAML-significant scalars `null`, `true`, `false`, `yes`, `no`, `on`, `off`, `y`, and `n`' "x-review rejects YAML-significant context scalars"
  assert_grep "$SKILL" '[Bb]efore dispatch.*selected review record.*structural_contributors' "x-review rejects reused record context before dispatch"
  assert_grep "$SKILL" '[Bb]efore writing.*reread.*selected review record.*structural_contributors' "x-review rejects reused record context before write"
  assert_grep "$SKILL" 'before dispatch.*returned reviewer context.*before writing' "x-review validates context grammar at both boundaries"
  assert_grep "$SKILL" '[Pp]ersisted contributor metadata.*overrides.*claim or instruction.*fresh' "x-review rejects contradictory freshness instructions"
  assert_grep "$SKILL" 'Never normalize, quote, escape, truncate, or repair.*context' "x-review cannot sanitize malformed contexts into acceptance"
  assert_grep "$SKILL" 'Reject the entire result.*write nothing' "x-review fails closed"
  assert_literal "$SKILL" 'Any failed gate stops with neither review dispatch nor write.' "x-review failed gates do not dispatch or write"

  assert_grep "$SKILL" 'complete current artifact content' "x-review sends complete current bytes"
  assert_grep "$SKILL" 'evaluate the envelope bytes, not `HEAD`' "x-review reviews uncommitted bytes"
  assert_grep "$SKILL" 'superpowers:requesting-code-review' "x-review delegates through vendored review skill"
  assert_grep "$SKILL" 'checklist and output format are retained' "x-review retains vendored review contract"
  assert_not_grep "$SKILL" '^### Strengths$' "x-review does not copy vendored output prompt"
  assert_not_grep "$SKILL" '^#### Critical' "x-review does not copy vendored review checklist"

  assert_grep "$SKILL" 'create.*revision: 1' "x-review initializes review records"
  assert_grep "$SKILL" 'replace `writer_context` with the verified reviewer context' "x-review updates writer context"
  assert_grep "$SKILL" 'append.*verified reviewer context.*structural_contributors' "x-review appends contributors"
  assert_grep "$SKILL" 'preserve.*existing structural contributors' "x-review preserves contributor history"
  assert_grep "$SKILL" 'derived_from.*current subject path and revision' "x-review persists exact direct input"
  assert_grep "$SKILL" 'persist.*findings.*verdict' "x-review persists review body"
  assert_grep "$SKILL" 'both verification results' "x-review persists verification evidence"
  assert_grep "$SKILL" 'plan.md.*replay_continuation: tasks@<current-plan-revision>' "x-review recognizes the plan continuation marker"
  assert_grep "$SKILL" 'no prior `reviews/plan-review.md`.*revision: 1.*--previous-revision 0' "x-review first plan review uses predecessor zero"
  assert_grep "$SKILL" 'existing.*revision `n`.*revision `n + 1`.*--previous-revision n' "x-review replacement review uses exact predecessor"
  assert_literal "$SKILL" 'bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed reviews/plan-review.md --previous-revision <0-or-n> --start-phase tasks' "x-review uses exact post-write planner command"
  assert_grep "$SKILL" '[Dd]isplay.*`CONTINUATION|tasks@<current-plan-revision>`.*`REPLAY|tasks`.*`REPLAY|analyze`' "x-review displays the bounded continuation"
  assert_grep "$SKILL" 'fresh literal `yes`.*later owner.*never execute' "x-review cannot consume continuation consent"
  assert_grep "$SKILL" 'spec.md.*replay_continuation: plan@<current-spec-revision>' "x-review recognizes the spec continuation marker"
  assert_grep "$SKILL" 'no prior `reviews/spec-review.md`.*revision: 1.*--previous-revision 0' "x-review first spec review uses predecessor zero"
  assert_grep "$SKILL" 'existing.*spec review.*revision `n`.*revision `n + 1`.*--previous-revision n' "x-review replacement spec review uses exact predecessor"
  assert_literal "$SKILL" 'bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed reviews/spec-review.md --previous-revision <0-or-n> --start-phase plan' "x-review uses exact spec post-write planner command"
  assert_grep "$SKILL" '[Dd]isplay.*`CONTINUATION|plan@<current-spec-revision>`.*`REPLAY|plan`' "x-review displays the post-spec-review continuation"

  assert_literal "$SKILL" 'This skill may write only the selected mapped review record.' "x-review writes only the selected mapped record"
  assert_grep "$SKILL" 'never change.*`status`' "x-review does not mutate status"
  assert_grep "$SKILL" 'never execute.*successor' "x-review does not execute successor phases"
  assert_grep "$SKILL" 'display.*remaining continuation' "x-review may display continuation"
  assert_grep "$SKILL" 'never create or write `workflow.md`' "x-review forbids workflow ledger"
  assert_grep "$SKILL" 'never create or write `.maxi-ops`' "x-review forbids ops directory"
fi

summary_and_exit "x-review checks"
