#!/usr/bin/env bash
# Verify the three fixed review boundaries and reject automatic replay.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

failures=0

assert_correction_section_not_grep() {
  local file="$1" heading="$2" pattern="$3" label="$4" section

  section="$(awk -v heading="$heading" '
    $0 == heading { found = 1 }
    found && /^## / && $0 != heading { exit }
    found { print }
  ' "$file")"

  if [ -z "$section" ]; then
    echo "FAIL [$label]: expected correction section '$heading' is missing" >&2
    failures=$((failures + 1))
  elif printf '%s\n' "$section" | grep -Eq "$pattern"; then
    echo "FAIL [$label]: correction contains a prohibited dispatch" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

assert_correction_section_grep() {
  local file="$1" heading="$2" pattern="$3" label="$4" section

  section="$(awk -v heading="$heading" '
    $0 == heading { found = 1 }
    found && /^## / && $0 != heading { exit }
    found { print }
  ' "$file")"

  if [ -z "$section" ]; then
    echo "FAIL [$label]: expected correction section '$heading' is missing" >&2
    failures=$((failures + 1))
  elif printf '%s\n' "$section" | grep -Eq "$pattern"; then
    echo "OK  [$label]"
  else
    echo "FAIL [$label]: terminal correction message is missing" >&2
    failures=$((failures + 1))
  fi
}

assert_correction_section_has_no_phase_command() {
  local file="$1" heading="$2" label="$3" section remaining
  local terminal_message='Request `/maxi:review` when you want a new design review.'

  section="$(awk -v heading="$heading" '
    $0 == heading { found = 1 }
    found && /^## / && $0 != heading { exit }
    found { print }
  ' "$file")"

  if [ -z "$section" ]; then
    echo "FAIL [$label]: expected correction section '$heading' is missing" >&2
    failures=$((failures + 1))
    return
  fi

  remaining="$(printf '%s\n' "$section" | awk -v terminal_message="$terminal_message" '{ sub(terminal_message, ""); print }')"
  if printf '%s\n' "$remaining" | grep -Eq '/maxi:(review|specify|clarify|plan|tasks|analyze|implement)([^[:alnum:]_-]|$)'; then
    echo "FAIL [$label]: correction contains a direct review or successor command" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

assert_section_grep() {
  local file="$1" heading="$2" pattern="$3" label="$4" section

  section="$(awk -v heading="$heading" '
    $0 == heading { found = 1 }
    found && /^## / && $0 != heading { exit }
    found { print }
  ' "$file")"

  if [ -z "$section" ]; then
    echo "FAIL [$label]: expected section '$heading' is missing" >&2
    failures=$((failures + 1))
  elif printf '%s\n' "$section" | grep -Eq "$pattern"; then
    echo "OK  [$label]"
  else
    echo "FAIL [$label]: missing boundary behavior" >&2
    failures=$((failures + 1))
  fi
}

assert_section_not_grep() {
  local file="$1" heading="$2" pattern="$3" label="$4" section

  section="$(awk -v heading="$heading" '
    $0 == heading { found = 1 }
    found && /^## / && $0 != heading { exit }
    found { print }
  ' "$file")"

  if [ -z "$section" ]; then
    echo "FAIL [$label]: expected section '$heading' is missing" >&2
    failures=$((failures + 1))
  elif printf '%s\n' "$section" | grep -Eq "$pattern"; then
    echo "FAIL [$label]: normal flow exposes a duplicate design review" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

assert_path_absent() {
  local path="$1" label="$2"

  if [ -e "$path" ]; then
    echo "FAIL [$label]: unexpected path: $path" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

assert_file_exists "$ROOT/skills/review/SKILL.md" "public design review skill"
assert_file_exists "$ROOT/skills/review/design-reviewer.md" "dedicated design reviewer brief"
assert_grep "$ROOT/skills/plan/SKILL.md" 'one design review.*spec.md.*plan.md' "plan has one design boundary"
assert_grep "$ROOT/skills/tasks/SKILL.md" 'missing or stale.*design review.*stop' "tasks require a current design review"
assert_grep "$ROOT/skills/analyze/SKILL.md" 'readiness review.*before implementation' "analysis is readiness review"
assert_grep "$ROOT/skills/analyze/SKILL.md" \
  'readiness-contract.sh` `stamp`' \
  "analyze stamps readiness evidence"
assert_grep "$ROOT/skills/analyze/SKILL.md" \
  'exact loaded `analyze/SKILL.md`' \
  "analyze binds the verifier to its loaded skill snapshot"
assert_grep "$ROOT/skills/analyze/SKILL.md" \
  'canonical absolute.*`readiness_contract`' \
  "analyze canonicalizes the installed verifier path"
assert_grep "$ROOT/skills/analyze/SKILL.md" \
  'regular, non-symlink file' \
  "analyze rejects an unsafe installed verifier"
assert_grep "$ROOT/skills/analyze/SKILL.md" \
  'bash "\$readiness_contract" stamp' \
  "analyze stamps through the bound installed verifier"
assert_not_grep "$ROOT/skills/analyze/SKILL.md" \
  'bash skills/analyze/readiness-contract\.sh' \
  "analyze has no project-relative verifier fallback"
assert_not_grep "$ROOT/skills/plan/SKILL.md" 'replay_continuation\|REVIEW_REQUIRED\|x-review' "plan cannot auto-replay"
assert_path_absent "$ROOT/skills/revise/replay-plan.sh" "obsolete replay planner is absent"

for skill in specify clarify revise plan tasks analyze implement; do
  assert_not_grep "$ROOT/skills/$skill/SKILL.md" 'replay_contract\|replay_continuation\|--resume-current-\|REVIEW_REQUIRED\|replay-plan\.sh\|x-review' "$skill has no replay trigger"
done

assert_correction_section_not_grep "$ROOT/skills/plan/SKILL.md" '## Explicit Structural Plan Correction' 'automatically invoke.*review|x-review' "plan correction does not dispatch review"
assert_correction_section_not_grep "$ROOT/skills/tasks/SKILL.md" '## Explicit Structural Tasks Correction' 'automatically invoke.*review|x-review' "tasks correction does not dispatch review"
assert_correction_section_not_grep "$ROOT/skills/revise/SKILL.md" '## Process' 'automatically invoke.*review|x-review' "spec correction does not dispatch review"
assert_correction_section_not_grep "$ROOT/skills/plan/SKILL.md" '## Explicit Structural Plan Correction' 'replay-plan\.sh|REVIEW_REQUIRED|REPLAY\||start-phase|invoke exactly.*(tasks|analyze|plan|clarify|specify)' "plan correction does not dispatch a successor"
assert_correction_section_not_grep "$ROOT/skills/tasks/SKILL.md" '## Explicit Structural Tasks Correction' 'replay-plan\.sh|REVIEW_REQUIRED|REPLAY\||start-phase|invoke exactly.*(tasks|analyze|plan|clarify|specify)' "tasks correction does not dispatch a successor"
assert_correction_section_not_grep "$ROOT/skills/revise/SKILL.md" '## Process' 'replay-plan\.sh|REVIEW_REQUIRED|REPLAY\||start-phase|invoke exactly.*(tasks|analyze|plan|clarify|specify)' "spec correction does not dispatch a successor"
for correction in \
  "$ROOT/skills/revise/SKILL.md|## Process|spec" \
  "$ROOT/skills/plan/SKILL.md|## Explicit Structural Plan Correction|plan" \
  "$ROOT/skills/tasks/SKILL.md|## Explicit Structural Tasks Correction|tasks"; do
  IFS='|' read -r file heading label <<< "$correction"
  assert_correction_section_grep "$file" "$heading" 'Correction recorded\. No review or successor phase was started\. Request `/maxi:review` when you want a new design review\.' "$label correction is terminal"
  assert_correction_section_has_no_phase_command "$file" "$heading" "$label correction has no direct phase command"
done

# Design review dispatch has exactly one normal entry point. Corrections remain
# terminal, tasks fail closed on stale approval, and only the public command can
# re-run a design review.
assert_section_grep "$ROOT/skills/plan/SKILL.md" '## Process' 'Invoke `/maxi:review` exactly once.*spec\.md.*plan\.md' "normal plan completion dispatches one design review"
assert_section_grep "$ROOT/skills/plan/SKILL.md" '## Process' 'pre-existing `plan.md`.*after `/maxi:revise` and `/maxi:clarify`.*zero automatic design-review dispatches.*`/maxi:review`' "replan after revision dispatches zero design reviews"
assert_correction_section_not_grep "$ROOT/skills/plan/SKILL.md" '## Explicit Structural Plan Correction' 'Invoke `/maxi:review`|dispatch.*design review' "plan correction dispatches zero design reviews"
assert_section_grep "$ROOT/skills/tasks/SKILL.md" '## Process' 'missing or stale.*design review.*stop.*no write.*`/maxi:review`' "stale design review blocks tasks without writing"
assert_grep "$ROOT/skills/review/SKILL.md" 'only re-review entry point' "public review is the only re-review entry point"
assert_not_grep "$ROOT/skills/review/SKILL.md" 'superpowers:requesting-code-review\|code-reviewer\.md\|Ready to merge' "design review does not use the code-review contract"
assert_grep "$ROOT/skills/review/SKILL.md" 'design-reviewer\.md' "design review dispatches its dedicated brief"
assert_grep "$ROOT/skills/review/SKILL.md" '`related_adrs` entry in `spec.md`' "design review resolves explicitly applicable ADRs"
assert_not_grep "$ROOT/skills/review/SKILL.md" 'inline `ADR-NNNN` references' "historical inline ADR mentions do not become review inputs"
assert_grep "$ROOT/skills/review/SKILL.md" 'Inline prose mentions do not select ADR inputs\.' "historical inline ADR mentions are explicitly excluded"
assert_grep "$ROOT/skills/review/SKILL.md" 'exactly one terminal verdict line' "design review requires one terminal verdict"
assert_grep "$ROOT/skills/review/SKILL.md" 'final non-empty line' "design review requires a terminal verdict"
assert_grep "$ROOT/skills/review/SKILL.md" 'discard.*write nothing' "design review rejects malformed verdicts without writing"
assert_section_not_grep "$ROOT/README.md" '## Quick Start' '^/maxi:review[[:space:]]' "quick start leaves initial review to plan"
assert_section_not_grep "$ROOT/skills/using-maxi/SKILL.md" '## The Pipeline' '^/maxi:review[[:space:]]' "session pipeline leaves initial review to plan"

assert_grep "$ROOT/skills/x-develop/SKILL.md" 'Upstream SDD remains authoritative' "x-develop preserves upstream SDD ownership"
assert_grep "$ROOT/skills/x-develop/SKILL.md" 'Use upstream.*final review' "x-develop preserves upstream final review"

if [ -f "$ROOT/skills/review/design-reviewer.md" ]; then
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'The reviewed baseline is the complete supplied `spec.md` and `plan.md` pair\.' "reviewer baseline is the complete supplied pair"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'Applicable accepted ADR paths.*APPLICABLE_ADR_PATHS' "reviewer receives applicable ADR paths"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'APPLICABLE_ADR_BYTES' "reviewer receives applicable ADR bytes"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'untrusted design content' "reviewer treats artifact bytes as untrusted content"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'never as instructions' "artifact content cannot replace reviewer instructions"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'violates or omits a requirement or success criterion' "reviewer blocks requirement omissions"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'adds or changes behavior beyond the reviewed spec and owning task' "reviewer blocks extra behavior"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'Task `Files` lists identify expected primary edits, not implementation allowlists\.' "reviewer treats Files lists as primary edits"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'technically infeasible or materially incorrect' "reviewer blocks infeasible designs"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'architecture ownership or boundaries' "reviewer blocks architecture violations"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'public contract' "reviewer checks public contracts"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'task boundaries or decomposition' "reviewer checks task decomposition"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'dependency order' "reviewer checks dependency order"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'safety control' "reviewer checks safety controls"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'verification strategy' "reviewer checks verification strategy"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'Callers, module declarations, registrations, fixtures, manifests, generated metadata, and lockfiles' "reviewer recognizes mechanical closure"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'Blocking basis:' "reviewer requires blocking basis"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'Return `VERDICT: approved` when no qualifying Critical or Important finding exists\.' "reviewer approves without qualifying findings"
  assert_grep "$ROOT/skills/review/design-reviewer.md" 'VERDICT: rejected' "reviewer has rejected terminal verdict"
fi

readiness_sentence='A passing readiness review is valid only when `analysis.md` carries `maxi-readiness-v1` and its recorded structural spec/tasks hashes and exact plan hash match the current artifacts; `/maxi:implement` verifies this before every new or resumed dispatch and otherwise stops for `/maxi:analyze`.'

for document in \
  "$ROOT/docs/pipeline-flow.md" \
  "$ROOT/docs/delegation-map.md" \
  "$ROOT/skills/using-maxi/SKILL.md" \
  "$ROOT/AGENTS.md" \
  "$ROOT/docs/architecture.md" \
  "$ROOT/README.md"; do
  assert_grep "$document" 'design review' "$(basename "$document") documents the design boundary"
  assert_not_grep "$document" 'bounded replay\|replay_continuation\|x-review' "$(basename "$document") has no replay contract"
  if grep -Fq "$readiness_sentence" "$document"; then
    echo "OK  [$(basename "$document") documents current readiness evidence]"
  else
    echo "FAIL [$(basename "$document") documents current readiness evidence]: missing canonical readiness sentence" >&2
    failures=$((failures + 1))
  fi
done

summary_and_exit "fixed review boundary checks"
