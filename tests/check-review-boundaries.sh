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
assert_grep "$ROOT/skills/plan/SKILL.md" 'one design review.*spec.md.*plan.md' "plan has one design boundary"
assert_grep "$ROOT/skills/tasks/SKILL.md" 'missing or stale.*design review.*stop' "tasks require a current design review"
assert_grep "$ROOT/skills/analyze/SKILL.md" 'readiness review.*before implementation' "analysis is readiness review"
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
assert_section_not_grep "$ROOT/README.md" '## Quick Start' '^/maxi:review[[:space:]]' "quick start leaves initial review to plan"
assert_section_not_grep "$ROOT/skills/using-maxi/SKILL.md" '## The Pipeline' '^/maxi:review[[:space:]]' "session pipeline leaves initial review to plan"

assert_grep "$ROOT/skills/x-develop/SKILL.md" 'Upstream SDD remains authoritative' "x-develop preserves upstream SDD ownership"
assert_grep "$ROOT/skills/x-develop/SKILL.md" 'Use upstream.*final review' "x-develop preserves upstream final review"

for document in \
  "$ROOT/docs/pipeline-flow.md" \
  "$ROOT/docs/delegation-map.md" \
  "$ROOT/skills/using-maxi/SKILL.md" \
  "$ROOT/AGENTS.md" \
  "$ROOT/docs/architecture.md"; do
  assert_grep "$document" 'design review' "$(basename "$document") documents the design boundary"
  assert_not_grep "$document" 'bounded replay\|replay_continuation\|x-review' "$(basename "$document") has no replay contract"
done

summary_and_exit "fixed review boundary checks"
