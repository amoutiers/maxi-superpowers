#!/usr/bin/env bash
# Executable behavior coverage for the Maxi TNNN-to-SDD Task N adapter.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
PROJECT="$ROOT/skills/x-develop/project-tasks.sh"
RECONCILE="$ROOT/skills/x-develop/reconcile-tasks.sh"
RECORD="$ROOT/skills/x-develop/record-terminal.sh"
RESULT="$ROOT/skills/x-develop/result-contract.sh"
TASK_BRIEF="$ROOT/skills/subagent-driven-development/scripts/task-brief"
REVIEW_PACKAGE="$ROOT/skills/subagent-driven-development/scripts/review-package"
FIXTURES="$ROOT/tests/fixtures/x-develop-adapter"

for helper in project-tasks.sh reconcile-tasks.sh record-terminal.sh result-contract.sh; do
  if [ ! -f "$ROOT/skills/x-develop/$helper" ]; then
    echo "FAIL [missing $helper]" >&2
    exit 1
  fi
done

WORK_RAW="$(mktemp -d)"
WORK="$(cd -P "$WORK_RAW" && pwd)"
trap 'rm -rf "$WORK"' EXIT
failures=0

ok() { echo "OK  [$1]"; }
fail() { echo "FAIL [$1]: ${2:-assertion failed}" >&2; failures=$((failures + 1)); }
assert_eq() { [ "$1" = "$2" ] && ok "$3" || fail "$3" "expected '$2', got '$1'"; }
assert_has() { grep -Fq -- "$2" "$1" && ok "$3" || fail "$3" "missing '$2'"; }
assert_not_has() { ! grep -Fq -- "$2" "$1" && ok "$3" || fail "$3" "unexpected '$2'"; }
sha() { shasum -a 256 "$1" | awk '{print $1}'; }

COMPLETE_1_CLEAN='Task 1: complete (commits 1111111..2222222, review clean)'
COMPLETE_1_PARKED='Task 1: complete (commits 1111111..2222222, 2 parked)'
COMPLETE_2_CLEAN='Task 2: complete (commits 2222222..3333333, review clean)'
COMPLETE_2_PARKED='Task 2: complete (commits 2222222..3333333, 2 parked)'
COMPLETE_3_CLEAN='Task 3: complete (commits 3333333..4444444, review clean)'

init_repo() {
  local repo="$1"
  mkdir -p "$repo/docs/maxi/specs/adapter-sample" "$repo/.superpowers/sdd/projections"
  git -C "$repo" init -q
  git -C "$repo" config user.email adapter@example.invalid
  git -C "$repo" config user.name 'Adapter Test'
  printf '.superpowers/\n' > "$repo/.gitignore"
}

write_spec() {
  local path="$1" mode="$2" slug="${3:-adapter-sample}"
  {
    echo '---'
    echo "slug: $slug"
    echo 'created: 2026-08-19'
    echo 'updated: 2026-08-19'
    echo 'status: analyzed'
    echo 'revision: 3'
    [ "$mode" = marker ] && echo 'replay_contract: bounded-v1'
    echo '---'
    echo
    echo "# Spec: $slug"
  } > "$path"
}

seed_case() {
  local repo="$1" mode="${2:-marker}" slug="${3:-adapter-sample}"
  local dir="$repo/docs/maxi/specs/$slug"
  mkdir -p "$dir" "$repo/.superpowers/sdd/projections"
  write_spec "$dir/spec.md" "$mode" "$slug"
  cp "$FIXTURES/plan.md" "$dir/plan.md"
  cp "$FIXTURES/tasks.md" "$dir/tasks.md"
  if [ "$slug" != adapter-sample ]; then
    sed "s/adapter-sample/$slug/g" "$dir/plan.md" > "$dir/plan.md.tmp" && mv "$dir/plan.md.tmp" "$dir/plan.md"
    sed "s/adapter-sample/$slug/g" "$dir/tasks.md" > "$dir/tasks.md.tmp" && mv "$dir/tasks.md.tmp" "$dir/tasks.md"
  fi
}

run_project() {
  local repo="$1" slug out state
  slug="${2:-adapter-sample}"
  out="${3:-$repo/.superpowers/sdd/projections/requested.md}"
  state="${4:-$repo/.superpowers/sdd/active-$slug}"
  local dir="$repo/docs/maxi/specs/$slug"
  set +e
  PROJECT_OUTPUT="$(cd / && bash "$PROJECT" --spec "$dir/spec.md" --plan "$dir/plan.md" --tasks "$dir/tasks.md" --output "$out" --state-file "$state" 2>&1)"
  PROJECT_STATUS=$?
  set -e
}

assert_rejected_without_projection() {
  local repo="$1" label="$2"
  run_project "$repo"
  [ "$PROJECT_STATUS" -ne 0 ] && ok "$label rejects" || fail "$label rejects" 'command succeeded'
  if find "$repo/.superpowers/sdd/projections" -type f -name '*-sdd.md' -print -quit | grep -q .; then
    fail "$label leaves no output" 'projection was created'
  else
    ok "$label leaves no output"
  fi
}

REPO="$WORK/projection-repo"
init_repo "$REPO"
seed_case "$REPO"
git -C "$REPO" add .gitignore docs
git -C "$REPO" commit -qm 'fixture'

PLAN="$REPO/docs/maxi/specs/adapter-sample/plan.md"
TASKS="$REPO/docs/maxi/specs/adapter-sample/tasks.md"
SPEC="$REPO/docs/maxi/specs/adapter-sample/spec.md"
STATE="$REPO/.superpowers/sdd/active-adapter-sample"
plan_before="$(sha "$PLAN")"
tasks_before="$(sha "$TASKS")"

run_project "$REPO"
assert_eq "$PROJECT_STATUS" 0 'canonical projection succeeds'
PROJECTION="$PROJECT_OUTPUT"
[ "$PROJECTION" = "$(cd -P "$(dirname "$PROJECTION")" && pwd)/$(basename "$PROJECTION")" ] && ok 'projection path is canonical absolute' || fail 'projection path is canonical absolute'
case "$(basename "$PROJECTION")" in
  adapter-sample-p-r7-????????????-t-r4-????????????-sdd.md) ok 'marker basename exact form' ;;
  *) fail 'marker basename exact form' "$(basename "$PROJECTION")" ;;
esac
assert_eq "$(sha "$PLAN")" "$plan_before" 'plan bytes stay immutable'
assert_eq "$(sha "$TASKS")" "$tasks_before" 'tasks bytes stay immutable during projection'
assert_has "$PROJECTION" '**Spec:** `spec.md`' 'preamble preserves Spec'
assert_has "$PROJECTION" '**Goal:** Exercise deterministic Maxi-to-SDD projection.' 'preamble preserves Goal'
assert_has "$PROJECTION" '**Architecture:** One projection adapter with immutable workspaces.' 'preamble preserves Architecture'
assert_has "$PROJECTION" '## Global Constraints' 'preamble preserves Global Constraints'
line_t1="$(grep -n '^### Task 1: T001 ' "$PROJECTION" | cut -d: -f1)"
line_t2="$(grep -n '^### Task 2: T002 ' "$PROJECTION" | cut -d: -f1)"
line_t3="$(grep -n '^### Task 3: T003 ' "$PROJECTION" | cut -d: -f1)"
[ "$line_t1" -lt "$line_t2" ] && [ "$line_t2" -lt "$line_t3" ] && ok 'mapped projection follows source plan order' || fail 'mapped projection follows source plan order'
assert_has "$PROJECTION" '### Task 99: This fenced heading is not executable' 'backtick-fenced heading stays in Task 1 body'
assert_has "$PROJECTION" 'Keep this line after the backtick fence.' 'Task 1 body is complete'
if grep -Eq '^[[:space:]]+```' "$PROJECTION"; then
  fail 'indented backtick delimiters are normalized' 'an indented backtick delimiter remains'
else
  ok 'indented backtick delimiters are normalized'
fi
assert_has "$PROJECTION" '```markdown' 'tilde opening fence is normalized'
assert_has "$PROJECTION" '### Task 88: This tilde-fenced heading is not executable' 'tilde-fenced heading stays in Task 2 body'
assert_not_has "$PROJECTION" '~~~' 'tilde fence delimiters are absent'
assert_has "$PROJECTION" 'Write the complete third task body through end of file.' 'final task body is complete'
assert_eq "$(cat "$STATE")" "$PROJECTION" 'active pointer stores one canonical projection'

# The anchor lives in the ordinary upstream ledger and must not disturb the
# upstream workspace helper that owns that ledger location.
PROJECTION_LEDGER="$REPO/.superpowers/sdd/$(basename "$PROJECTION" .md)/progress.md"
assert_eq "$(sed -n '1p' "$PROJECTION_LEDGER")" "# SDD ledger — plan: $PROJECTION" 'selection ledger keeps upstream plan identity'
assert_eq "$(grep -c '^Maxi selection:' "$PROJECTION_LEDGER")" 1 'selection ledger has one canonical anchor'
assert_eq "$(sed -n '2p' "$PROJECTION_LEDGER")" 'Maxi selection: T001 T002 T003' 'selection ledger anchors the exact initial set'
assert_eq "$(grep -c '^Maxi projection SHA256:' "$PROJECTION_LEDGER")" 1 'selection ledger has one projection-byte anchor'
assert_eq "$(sed -n '3p' "$PROJECTION_LEDGER")" "Maxi projection SHA256: $(sha "$PROJECTION")" 'ledger anchors the exact distributed projection bytes'
selection_ledger_hash="$(sha "$PROJECTION_LEDGER")"
UPSTREAM_WORKSPACE="$(cd "$REPO" && bash "$ROOT/skills/subagent-driven-development/scripts/sdd-workspace" "$PROJECTION")"
assert_eq "$UPSTREAM_WORKSPACE" "$(dirname "$PROJECTION_LEDGER")" 'upstream workspace accepts anchored ordinary ledger'
assert_eq "$(sha "$PROJECTION_LEDGER")" "$selection_ledger_hash" 'upstream workspace preserves selection anchor'

# The real upstream extractor must retain every complete projected body.
for task_number in 1 2 3; do
  brief="$WORK/task-$task_number-brief.md"
  if (cd "$REPO" && bash "$TASK_BRIEF" "$PROJECTION" "$task_number" "$brief") >/dev/null 2>&1; then
    ok "upstream task-brief extracts Task $task_number"
  else
    fail "upstream task-brief extracts Task $task_number" 'extractor rejected the projection'
  fi
done
assert_has "$WORK/task-1-brief.md" '### Task 99: This fenced heading is not executable' 'Task 1 brief retains fenced heading'
assert_has "$WORK/task-1-brief.md" 'Keep this line after the backtick fence.' 'Task 1 brief retains complete tail'
assert_not_has "$WORK/task-1-brief.md" '### Task 2: T002 ' 'Task 1 brief stops at Task 2'
assert_has "$WORK/task-2-brief.md" '### Task 88: This tilde-fenced heading is not executable' 'Task 2 brief retains normalized fenced heading'
assert_has "$WORK/task-2-brief.md" 'Keep this line after the tilde fence.' 'Task 2 brief retains complete tail'
assert_not_has "$WORK/task-2-brief.md" '### Task 3: T003 ' 'Task 2 brief stops at Task 3'
assert_has "$WORK/task-3-brief.md" 'Write the complete third task body through end of file.' 'Task 3 brief retains complete tail'

projection_hash="$(sha "$PROJECTION")"
sed 's/- \[ \] T001/- [x] T001/' "$TASKS" > "$TASKS.tmp" && mv "$TASKS.tmp" "$TASKS"
sed 's/^updated: .*/updated: 2026-08-20/' "$TASKS" > "$TASKS.tmp" && mv "$TASKS.tmp" "$TASKS"
run_project "$REPO"
assert_eq "$PROJECT_STATUS" 0 'checkbox and updated-only resume succeeds'
assert_eq "$PROJECT_OUTPUT" "$PROJECTION" 'checkbox and updated-only change preserves workspace identity'
assert_eq "$(sha "$PROJECTION")" "$projection_hash" 'existing projection bytes are never regenerated'

# A projection cannot attest a rewritten body by updating its own stored hash.
TAMPERED="$WORK/tampered-projection"
init_repo "$TAMPERED"
seed_case "$TAMPERED"
run_project "$TAMPERED"
TAMPERED_PROJECTION="$PROJECT_OUTPUT"
sed 's/Write the complete first task body\./Write a forged first task body./' "$TAMPERED_PROJECTION" > "$TAMPERED/change"
mv "$TAMPERED/change" "$TAMPERED_PROJECTION"
tampered_body_sha="$(awk '
  NR == 1 && $0 == "---" { fm = 1; next }
  fm && $0 == "---" { fm = 0; next }
  !fm { print }
' "$TAMPERED_PROJECTION" | shasum -a 256 | awk '{print $1}')"
sed "s/^projection_body_sha256: .*/projection_body_sha256: $tampered_body_sha/" "$TAMPERED_PROJECTION" > "$TAMPERED/change"
mv "$TAMPERED/change" "$TAMPERED_PROJECTION"
tampered_projection_sha="$(sha "$TAMPERED_PROJECTION")"
run_project "$TAMPERED"
[ "$PROJECT_STATUS" -ne 0 ] && ok 'rewritten projection with recomputed self-hash is rejected' || fail 'rewritten projection with recomputed self-hash is rejected' 'command accepted forged canonical bytes'
assert_eq "$(sha "$TAMPERED_PROJECTION")" "$tampered_projection_sha" 'forged existing projection is never regenerated'

# A predecessor cannot attest forged bytes by updating only its internal body
# hash before a structural correction creates a successor.
FORGED_PREDECESSOR="$WORK/forged-predecessor"
init_repo "$FORGED_PREDECESSOR"
seed_case "$FORGED_PREDECESSOR"
run_project "$FORGED_PREDECESSOR"
FORGED_PREDECESSOR_PROJECTION="$PROJECT_OUTPUT"
FORGED_PREDECESSOR_STATE="$FORGED_PREDECESSOR/.superpowers/sdd/active-adapter-sample"
sed 's/Write the complete first task body\./Write a forged predecessor task body./' "$FORGED_PREDECESSOR_PROJECTION" > "$FORGED_PREDECESSOR/change"
mv "$FORGED_PREDECESSOR/change" "$FORGED_PREDECESSOR_PROJECTION"
forged_predecessor_body_sha="$(awk '
  NR == 1 && $0 == "---" { fm = 1; next }
  fm && $0 == "---" { fm = 0; next }
  !fm { print }
' "$FORGED_PREDECESSOR_PROJECTION" | shasum -a 256 | awk '{print $1}')"
sed "s/^projection_body_sha256: .*/projection_body_sha256: $forged_predecessor_body_sha/" "$FORGED_PREDECESSOR_PROJECTION" > "$FORGED_PREDECESSOR/change"
mv "$FORGED_PREDECESSOR/change" "$FORGED_PREDECESSOR_PROJECTION"
sed 's/Write the second file/Write the structurally corrected second file/' "$FORGED_PREDECESSOR/docs/maxi/specs/adapter-sample/tasks.md" > "$FORGED_PREDECESSOR/change"
mv "$FORGED_PREDECESSOR/change" "$FORGED_PREDECESSOR/docs/maxi/specs/adapter-sample/tasks.md"
run_project "$FORGED_PREDECESSOR"
[ "$PROJECT_STATUS" -ne 0 ] && ok 'rehashed forged predecessor rejects before successor creation' || fail 'rehashed forged predecessor rejects before successor creation' 'forged predecessor authorized a successor'
assert_eq "$(cat "$FORGED_PREDECESSOR_STATE")" "$FORGED_PREDECESSOR_PROJECTION" 'forged predecessor keeps the active pointer unchanged'
assert_eq "$(find "$FORGED_PREDECESSOR/.superpowers/sdd/projections" -type f -name '*-sdd.md' | wc -l | tr -d ' ')" 1 'forged predecessor creates no successor projection'

# The projection cannot define its own selected-task set after reconciliation.
OMITTED="$WORK/omitted-selected-task"
init_repo "$OMITTED"
seed_case "$OMITTED"
run_project "$OMITTED"
OMITTED_PROJECTION="$PROJECT_OUTPUT"
OMITTED_TASKS="$OMITTED/docs/maxi/specs/adapter-sample/tasks.md"
OMITTED_LEDGER="$OMITTED/.superpowers/sdd/$(basename "$OMITTED_PROJECTION" .md)/progress.md"
mkdir -p "$(dirname "$OMITTED_LEDGER")"
printf '# SDD ledger — plan: %s\nMaxi selection: T001 T002 T003\nMaxi projection SHA256: %s\n%s\n' "$OMITTED_PROJECTION" "$(sha "$OMITTED_PROJECTION")" "$COMPLETE_1_CLEAN" > "$OMITTED_LEDGER"
bash "$RECONCILE" --projection "$OMITTED_PROJECTION" --ledger "$OMITTED_LEDGER" --tasks "$OMITTED_TASKS" >/dev/null
awk '
  /^### Task 1: T001 / { skip = 1; next }
  /^### Task 2: T002 / { skip = 0; sub(/^### Task 2:/, "### Task 1:") }
  /^### Task 3: T003 / { sub(/^### Task 3:/, "### Task 2:") }
  !skip { print }
' "$OMITTED_PROJECTION" > "$OMITTED/change"
mv "$OMITTED/change" "$OMITTED_PROJECTION"
omitted_body_sha="$(awk '
  NR == 1 && $0 == "---" { fm = 1; next }
  fm && $0 == "---" { fm = 0; next }
  !fm { print }
' "$OMITTED_PROJECTION" | shasum -a 256 | awk '{print $1}')"
sed "s/^projection_body_sha256: .*/projection_body_sha256: $omitted_body_sha/" "$OMITTED_PROJECTION" > "$OMITTED/change"
mv "$OMITTED/change" "$OMITTED_PROJECTION"
omitted_projection_sha="$(sha "$OMITTED_PROJECTION")"
run_project "$OMITTED"
[ "$PROJECT_STATUS" -ne 0 ] && ok 'projection cannot self-attest its selected-task set' || fail 'projection cannot self-attest its selected-task set' 'rehashed omission was accepted'
assert_eq "$(sha "$OMITTED_PROJECTION")" "$omitted_projection_sha" 'selected-task forgery is never regenerated'

# Without its immutable initial-selection ledger anchor, a projection cannot
# bless an omitted selected task before the first completion exists.
NO_ANCHOR="$WORK/no-anchor-omission"
init_repo "$NO_ANCHOR"
seed_case "$NO_ANCHOR"
run_project "$NO_ANCHOR"
NO_ANCHOR_PROJECTION="$PROJECT_OUTPUT"
NO_ANCHOR_TASKS="$NO_ANCHOR/docs/maxi/specs/adapter-sample/tasks.md"
NO_ANCHOR_LEDGER="$NO_ANCHOR/.superpowers/sdd/$(basename "$NO_ANCHOR_PROJECTION" .md)/progress.md"
if [ -e "$NO_ANCHOR_LEDGER" ]; then mv "$NO_ANCHOR_LEDGER" "$NO_ANCHOR_LEDGER.saved"; fi
sed 's/- \[ \] T001/- [x] T001/' "$NO_ANCHOR_TASKS" > "$NO_ANCHOR/change"
mv "$NO_ANCHOR/change" "$NO_ANCHOR_TASKS"
awk '
  /^### Task 1: T001 / { skip = 1; next }
  /^### Task 2: T002 / { skip = 0; sub(/^### Task 2:/, "### Task 1:") }
  /^### Task 3: T003 / { sub(/^### Task 3:/, "### Task 2:") }
  !skip { print }
' "$NO_ANCHOR_PROJECTION" > "$NO_ANCHOR/change"
mv "$NO_ANCHOR/change" "$NO_ANCHOR_PROJECTION"
no_anchor_body_sha="$(awk '
  NR == 1 && $0 == "---" { fm = 1; next }
  fm && $0 == "---" { fm = 0; next }
  !fm { print }
' "$NO_ANCHOR_PROJECTION" | shasum -a 256 | awk '{print $1}')"
sed "s/^projection_body_sha256: .*/projection_body_sha256: $no_anchor_body_sha/" "$NO_ANCHOR_PROJECTION" > "$NO_ANCHOR/change"
mv "$NO_ANCHOR/change" "$NO_ANCHOR_PROJECTION"
no_anchor_projection_sha="$(sha "$NO_ANCHOR_PROJECTION")"
run_project "$NO_ANCHOR"
[ "$PROJECT_STATUS" -ne 0 ] && ok 'missing selection anchor rejects pre-completion omission' || fail 'missing selection anchor rejects pre-completion omission' 'anchorless rehashed omission was accepted'
assert_eq "$(sha "$NO_ANCHOR_PROJECTION")" "$no_anchor_projection_sha" 'anchorless forgery is never regenerated'

# Every reused projection requires one exact, unique, matching selection anchor.
for anchor_case in absent malformed duplicate mismatch; do
  ANCHOR_REPO="$WORK/anchor-$anchor_case"
  init_repo "$ANCHOR_REPO"
  seed_case "$ANCHOR_REPO"
  run_project "$ANCHOR_REPO"
  ANCHOR_PROJECTION="$PROJECT_OUTPUT"
  ANCHOR_LEDGER="$ANCHOR_REPO/.superpowers/sdd/$(basename "$ANCHOR_PROJECTION" .md)/progress.md"
  mkdir -p "$(dirname "$ANCHOR_LEDGER")"
  printf '# SDD ledger — plan: %s\nMaxi projection SHA256: %s\n' "$ANCHOR_PROJECTION" "$(sha "$ANCHOR_PROJECTION")" > "$ANCHOR_LEDGER"
  case "$anchor_case" in
    absent) ;;
    malformed) printf 'Maxi selection: T001,T002,T003\n' >> "$ANCHOR_LEDGER" ;;
    duplicate) printf 'Maxi selection: T001 T002 T003\nMaxi selection: T001 T002 T003\n' >> "$ANCHOR_LEDGER" ;;
    mismatch) printf 'Maxi selection: T001 T002\n' >> "$ANCHOR_LEDGER" ;;
  esac
  anchor_projection_sha="$(sha "$ANCHOR_PROJECTION")"
  run_project "$ANCHOR_REPO"
  [ "$PROJECT_STATUS" -ne 0 ] && ok "$anchor_case selection anchor rejects" || fail "$anchor_case selection anchor rejects" 'invalid selection anchor was accepted'
  assert_eq "$(sha "$ANCHOR_PROJECTION")" "$anchor_projection_sha" "$anchor_case selection anchor preserves projection"
done

# Every reused projection requires one exact byte anchor in its ordinary
# ledger, independent from the projection's self-reported body hash.
for projection_anchor_case in absent malformed duplicate mismatch; do
  PROJECTION_ANCHOR_REPO="$WORK/projection-anchor-$projection_anchor_case"
  init_repo "$PROJECTION_ANCHOR_REPO"
  seed_case "$PROJECTION_ANCHOR_REPO"
  run_project "$PROJECTION_ANCHOR_REPO"
  PROJECTION_ANCHOR_PROJECTION="$PROJECT_OUTPUT"
  PROJECTION_ANCHOR_STATE="$PROJECTION_ANCHOR_REPO/.superpowers/sdd/active-adapter-sample"
  PROJECTION_ANCHOR_LEDGER="$PROJECTION_ANCHOR_REPO/.superpowers/sdd/$(basename "$PROJECTION_ANCHOR_PROJECTION" .md)/progress.md"
  case "$projection_anchor_case" in
    absent) grep -Fv 'Maxi projection SHA256:' "$PROJECTION_ANCHOR_LEDGER" > "$PROJECTION_ANCHOR_REPO/change" ;;
    malformed) sed 's/^Maxi projection SHA256: .*/Maxi projection SHA256: malformed/' "$PROJECTION_ANCHOR_LEDGER" > "$PROJECTION_ANCHOR_REPO/change" ;;
    duplicate) { cat "$PROJECTION_ANCHOR_LEDGER"; printf 'Maxi projection SHA256: %s\n' "$(sha "$PROJECTION_ANCHOR_PROJECTION")"; } > "$PROJECTION_ANCHOR_REPO/change" ;;
    mismatch) sed 's/^Maxi projection SHA256: .*/Maxi projection SHA256: 0000000000000000000000000000000000000000000000000000000000000000/' "$PROJECTION_ANCHOR_LEDGER" > "$PROJECTION_ANCHOR_REPO/change" ;;
  esac
  mv "$PROJECTION_ANCHOR_REPO/change" "$PROJECTION_ANCHOR_LEDGER"
  run_project "$PROJECTION_ANCHOR_REPO"
  [ "$PROJECT_STATUS" -ne 0 ] && ok "$projection_anchor_case projection-byte anchor rejects" || fail "$projection_anchor_case projection-byte anchor rejects" 'invalid projection-byte anchor was accepted'
  assert_eq "$(cat "$PROJECTION_ANCHOR_STATE")" "$PROJECTION_ANCHOR_PROJECTION" "$projection_anchor_case projection-byte anchor keeps active pointer"
done

# Any completion-like current-ledger record must use one exact upstream form.
for completion_case in bare duplicate wrong-number bad-sha free-annotation zero-parked suffix; do
  COMPLETION_REPO="$WORK/completion-$completion_case"
  init_repo "$COMPLETION_REPO"
  seed_case "$COMPLETION_REPO"
  run_project "$COMPLETION_REPO"
  COMPLETION_PROJECTION="$PROJECT_OUTPUT"
  COMPLETION_LEDGER="$COMPLETION_REPO/.superpowers/sdd/$(basename "$COMPLETION_PROJECTION" .md)/progress.md"
  case "$completion_case" in
    bare) printf 'Task 1: complete\n' >> "$COMPLETION_LEDGER" ;;
    duplicate) printf '%s\n%s\n' "$COMPLETE_1_CLEAN" "$COMPLETE_1_CLEAN" >> "$COMPLETION_LEDGER" ;;
    wrong-number) printf 'Task 4: complete (commits 1111111..2222222, review clean)\n' >> "$COMPLETION_LEDGER" ;;
    bad-sha) printf 'Task 1: complete (commits 111111..2222222, review clean)\n' >> "$COMPLETION_LEDGER" ;;
    free-annotation) printf 'Task 1: complete (commits 1111111..2222222, locally approved)\n' >> "$COMPLETION_LEDGER" ;;
    zero-parked) printf 'Task 1: complete (commits 1111111..2222222, 0 parked)\n' >> "$COMPLETION_LEDGER" ;;
    suffix) printf 'Task 1: complete (commits 1111111..2222222, review clean) trailing\n' >> "$COMPLETION_LEDGER" ;;
  esac
  run_project "$COMPLETION_REPO"
  [ "$PROJECT_STATUS" -ne 0 ] && ok "$completion_case completion record rejects at projection boundary" || fail "$completion_case completion record rejects at projection boundary" 'invalid current-ledger completion was accepted'
done

# A task checked before first projection is not part of the anchor; completing
# both selected tasks must still resume the ordinary projection unambiguously.
PRECHECKED="$WORK/prechecked-resume"
init_repo "$PRECHECKED"
seed_case "$PRECHECKED"
PRECHECKED_TASKS="$PRECHECKED/docs/maxi/specs/adapter-sample/tasks.md"
sed 's/- \[ \] T002/- [x] T002/' "$PRECHECKED_TASKS" > "$PRECHECKED/change"
mv "$PRECHECKED/change" "$PRECHECKED_TASKS"
run_project "$PRECHECKED"
PRECHECKED_PROJECTION="$PROJECT_OUTPUT"
PRECHECKED_LEDGER="$PRECHECKED/.superpowers/sdd/$(basename "$PRECHECKED_PROJECTION" .md)/progress.md"
mkdir -p "$(dirname "$PRECHECKED_LEDGER")"
printf '# SDD ledger — plan: %s\nMaxi selection: T001 T003\nMaxi projection SHA256: %s\n%s\n%s\n' "$PRECHECKED_PROJECTION" "$(sha "$PRECHECKED_PROJECTION")" "$COMPLETE_1_CLEAN" "$COMPLETE_2_PARKED" > "$PRECHECKED_LEDGER"
assert_eq "$(bash "$RECONCILE" --projection "$PRECHECKED_PROJECTION" --ledger "$PRECHECKED_LEDGER" --tasks "$PRECHECKED_TASKS")" 0 'prechecked projection reconciles both selected tasks'
run_project "$PRECHECKED"
assert_eq "$PROJECT_STATUS" 0 'prechecked completed projection resumes for whole-branch review'
assert_eq "$PROJECT_OUTPUT" "$PRECHECKED_PROJECTION" 'prechecked completed projection keeps immutable identity'
assert_has "$PRECHECKED_PROJECTION" 'execution_mode: ordinary' 'prechecked completed projection remains ordinary'
if find "$(dirname "$PRECHECKED_LEDGER")" -type f ! -name 'progress.md' -print -quit | grep -q .; then
  fail 'selection anchor creates no sidecar' 'unexpected persistent file beside ordinary ledger'
else
  ok 'selection anchor creates no sidecar'
fi

# A separately checked initial task is omitted before any projection exists.
CHECKED_REPO="$WORK/checked-repo"
init_repo "$CHECKED_REPO"
seed_case "$CHECKED_REPO"
sed 's/- \[ \] T002/- [x] T002/' "$CHECKED_REPO/docs/maxi/specs/adapter-sample/tasks.md" > "$CHECKED_REPO/tasks.tmp"
mv "$CHECKED_REPO/tasks.tmp" "$CHECKED_REPO/docs/maxi/specs/adapter-sample/tasks.md"
run_project "$CHECKED_REPO"
assert_eq "$PROJECT_STATUS" 0 'initial checked-state projection succeeds'
assert_not_has "$PROJECT_OUTPUT" 'T002' 'task checked before first execution is excluded'
assert_has "$PROJECT_OUTPUT" '### Task 1: T001 ' 'remaining Task 1 is retained'
assert_has "$PROJECT_OUTPUT" '### Task 2: T003 ' 'remaining Task 3 is renumbered sequentially'

# Every structural tasks field changes the identity.
for field in task-line phase goal dependency checkpoint; do
  CASE="$WORK/identity-$field"
  init_repo "$CASE"
  seed_case "$CASE"
  run_project "$CASE"
  old="$PROJECT_OUTPUT"
  case "$field" in
    task-line) sed 's/Write the second file/Write the corrected second file/' "$CASE/docs/maxi/specs/adapter-sample/tasks.md" > "$CASE/change" ;;
    phase) sed 's/Phase 3: Tilde fence/Phase 3: Corrected tilde fence/' "$CASE/docs/maxi/specs/adapter-sample/tasks.md" > "$CASE/change" ;;
    goal) sed 's/Finish the sample/Finish the corrected sample/' "$CASE/docs/maxi/specs/adapter-sample/tasks.md" > "$CASE/change" ;;
    dependency) sed 's/T002 depends on T001/T002 strictly depends on T001/' "$CASE/docs/maxi/specs/adapter-sample/tasks.md" > "$CASE/change" ;;
    checkpoint) sed 's/Third file ready/Corrected third file ready/' "$CASE/docs/maxi/specs/adapter-sample/tasks.md" > "$CASE/change" ;;
  esac
  mv "$CASE/change" "$CASE/docs/maxi/specs/adapter-sample/tasks.md"
  run_project "$CASE"
  [ "$PROJECT_STATUS" -eq 0 ] && [ "$PROJECT_OUTPUT" != "$old" ] && ok "$field correction creates successor workspace" || fail "$field correction creates successor workspace"
  assert_has "$PROJECT_OUTPUT" "predecessor_projection: $old" "$field correction links predecessor"
done

# In lineage, only an exact predecessor-ledger completion can remove a task.
CORRECT="$WORK/correction-repo"
init_repo "$CORRECT"
seed_case "$CORRECT"
run_project "$CORRECT"
OLD_PROJECTION="$PROJECT_OUTPUT"
OLD_LEDGER="$CORRECT/.superpowers/sdd/$(basename "$OLD_PROJECTION" .md)/progress.md"
mkdir -p "$(dirname "$OLD_LEDGER")"
printf '# SDD ledger — plan: %s\nMaxi selection: T001 T002 T003\nMaxi projection SHA256: %s\n%s\nRuling: preserve old evidence\n' "$OLD_PROJECTION" "$(sha "$OLD_PROJECTION")" "$COMPLETE_1_PARKED" > "$OLD_LEDGER"
bash "$RECONCILE" --projection "$OLD_PROJECTION" --ledger "$OLD_LEDGER" --tasks "$CORRECT/docs/maxi/specs/adapter-sample/tasks.md" >/dev/null
sed 's/- \[ \] T002/- [x] T002/' "$CORRECT/docs/maxi/specs/adapter-sample/tasks.md" > "$CORRECT/change"
mv "$CORRECT/change" "$CORRECT/docs/maxi/specs/adapter-sample/tasks.md"
sed 's/Write the second file/Write the newly corrected second file/' "$CORRECT/docs/maxi/specs/adapter-sample/tasks.md" > "$CORRECT/change"
mv "$CORRECT/change" "$CORRECT/docs/maxi/specs/adapter-sample/tasks.md"
run_project "$CORRECT"
NEW_PROJECTION="$PROJECT_OUTPUT"
if grep -Eq '^### Task [1-9][0-9]*: T001 ' "$NEW_PROJECTION"; then
  fail 'successor excludes genuinely completed predecessor task' 'T001 executable heading remains'
else
  ok 'successor excludes genuinely completed predecessor task'
fi
assert_has "$NEW_PROJECTION" '### Task 1: T002 ' 'successor retains corrected pending task'
assert_has "$NEW_PROJECTION" '### Task 2: T003 ' 'successor retains every other pending task'

# A structural successor cannot erase an anchored, uncompleted task by
# removing it consistently from both current source artifacts.
DELETED_SELECTED="$WORK/deleted-selected-task"
init_repo "$DELETED_SELECTED"
seed_case "$DELETED_SELECTED"
run_project "$DELETED_SELECTED"
DELETED_PREDECESSOR="$PROJECT_OUTPUT"
DELETED_PLAN="$DELETED_SELECTED/docs/maxi/specs/adapter-sample/plan.md"
DELETED_TASKS="$DELETED_SELECTED/docs/maxi/specs/adapter-sample/tasks.md"
awk '/^### Task 3: / { exit } { print }' "$DELETED_PLAN" > "$DELETED_SELECTED/change"
mv "$DELETED_SELECTED/change" "$DELETED_PLAN"
awk '
  /^## Phase 1: Final body$/ { skip = 1; next }
  skip && /^## Phase 2:/ { skip = 0 }
  !skip { print }
' "$DELETED_TASKS" > "$DELETED_SELECTED/change"
mv "$DELETED_SELECTED/change" "$DELETED_TASKS"
run_project "$DELETED_SELECTED"
[ "$PROJECT_STATUS" -ne 0 ] && ok 'successor rejects deleted anchored T003' || fail 'successor rejects deleted anchored T003' 'structural successor silently discarded T003'
assert_eq "$(cat "$DELETED_SELECTED/.superpowers/sdd/active-adapter-sample")" "$DELETED_PREDECESSOR" 'deleted anchored task keeps predecessor active'

# Legacy roots ignore historical annotations and use tasks-file order exactly once.
LEGACY="$WORK/legacy-repo"
init_repo "$LEGACY"
seed_case "$LEGACY" legacy
LEGACY_TASKS="$LEGACY/docs/maxi/specs/adapter-sample/tasks.md"
sed 's/ (plan Task 3)/ (plan Task 900, Steps 1-3)/; s/ (plan Task 1)/ legacy note/; s/ (plan Task 2)/ (plan unknown historical syntax)/' "$LEGACY_TASKS" > "$LEGACY/change"
mv "$LEGACY/change" "$LEGACY_TASKS"
run_project "$LEGACY"
assert_eq "$PROJECT_STATUS" 0 'legacy projection succeeds without annotation parsing'
case "$(basename "$PROJECT_OUTPUT")" in
  adapter-sample-p-legacy-????????????-t-legacy-????????????-sdd.md) ok 'legacy basename exact form' ;;
  *) fail 'legacy basename exact form' "$(basename "$PROJECT_OUTPUT")" ;;
esac
legacy_t3="$(grep -n '^### Task 1: T003 ' "$PROJECT_OUTPUT" | cut -d: -f1)"
legacy_t1="$(grep -n '^### Task 2: T001 ' "$PROJECT_OUTPUT" | cut -d: -f1)"
legacy_t2="$(grep -n '^### Task 3: T002 ' "$PROJECT_OUTPUT" | cut -d: -f1)"
[ "$legacy_t3" -lt "$legacy_t1" ] && [ "$legacy_t1" -lt "$legacy_t2" ] && ok 'legacy projection follows tasks-file order' || fail 'legacy projection follows tasks-file order'
assert_eq "$(grep -c '^### Task [0-9][0-9]*: T001 ' "$PROJECT_OUTPUT")" 1 'legacy T001 projected once'
assert_eq "$(grep -c '^### Task [0-9][0-9]*: T002 ' "$PROJECT_OUTPUT")" 1 'legacy T002 projected once'
assert_eq "$(grep -c '^### Task [0-9][0-9]*: T003 ' "$PROJECT_OUTPUT")" 1 'legacy T003 projected once'

# Invalid mappings, IDs, and ambiguous fences fail before output.
for invalid in duplicate-map missing-map unknown-map nonnumeric-map duplicate-id fence-collision; do
  BAD="$WORK/bad-$invalid"
  init_repo "$BAD"
  seed_case "$BAD"
  bad_tasks="$BAD/docs/maxi/specs/adapter-sample/tasks.md"
  bad_plan="$BAD/docs/maxi/specs/adapter-sample/plan.md"
  case "$invalid" in
    duplicate-map) sed 's/(plan Task 2)/(plan Task 1)/' "$bad_tasks" > "$BAD/change" && mv "$BAD/change" "$bad_tasks" ;;
    missing-map) sed 's/ (plan Task 2)//' "$bad_tasks" > "$BAD/change" && mv "$BAD/change" "$bad_tasks" ;;
    unknown-map) sed 's/(plan Task 2)/(plan Task 4)/' "$bad_tasks" > "$BAD/change" && mv "$BAD/change" "$bad_tasks" ;;
    nonnumeric-map) sed 's/(plan Task 2)/(plan Task X)/' "$bad_tasks" > "$BAD/change" && mv "$BAD/change" "$bad_tasks" ;;
    duplicate-id) sed 's/T002/T003/' "$bad_tasks" > "$BAD/change" && mv "$BAD/change" "$bad_tasks" ;;
    fence-collision) awk '{ print } /~~~markdown/ { print "```collision" }' "$bad_plan" > "$BAD/change" && mv "$BAD/change" "$bad_plan" ;;
  esac
  assert_rejected_without_projection "$BAD" "$invalid"
done

# Canonical path reuse and symlink handling.
run_project "$REPO"
assert_eq "$PROJECT_OUTPUT" "$PROJECTION" 'foreign cwd reuses one canonical projection'
SYMLINK_FINAL="$REPO/.superpowers/sdd/projections/requested-link.md"
ln -s "$PROJECTION" "$SYMLINK_FINAL"
run_project "$REPO" adapter-sample "$SYMLINK_FINAL" "$STATE"
[ "$PROJECT_STATUS" -ne 0 ] && ok 'symlink output final component is rejected' || fail 'symlink output final component is rejected'
ln -s "$REPO/.superpowers/sdd/projections" "$REPO/projection-alias"
run_project "$REPO" adapter-sample "$REPO/projection-alias/requested.md" "$STATE"
assert_eq "$PROJECT_STATUS" 0 'symlink parent alias resolves safely'
assert_eq "$PROJECT_OUTPUT" "$PROJECTION" 'symlink parent alias resolves to byte-identical path'

# Cross-worktree artifacts fail closed.
FOREIGN="$WORK/foreign-repo"
init_repo "$FOREIGN"
seed_case "$FOREIGN"
set +e
foreign_output="$(bash "$PROJECT" --spec "$SPEC" --plan "$FOREIGN/docs/maxi/specs/adapter-sample/plan.md" --tasks "$TASKS" --output "$REPO/.superpowers/sdd/projections/foreign.md" --state-file "$STATE" 2>&1)"
foreign_status=$?
set -e
[ "$foreign_status" -ne 0 ] && ok 'source artifacts must share one physical worktree' || fail 'source artifacts must share one physical worktree' "$foreign_output"
run_project "$FOREIGN" adapter-sample "$REPO/.superpowers/sdd/projections/escape.md" "$FOREIGN/.superpowers/sdd/active-adapter-sample"
[ "$PROJECT_STATUS" -ne 0 ] && ok 'projection cannot escape bound worktree' || fail 'projection cannot escape bound worktree'

# Pointer failures: missing target, malformed, foreign identity/location, and cycle.
for pointer_case in missing malformed foreign foreign-spec external provenance cycle; do
  POINTER="$WORK/pointer-$pointer_case"
  init_repo "$POINTER"
  seed_case "$POINTER"
  pointer_file="$POINTER/.superpowers/sdd/active-adapter-sample"
  case "$pointer_case" in
    missing) printf '%s\n' "$POINTER/.superpowers/sdd/projections/missing-sdd.md" > "$pointer_file" ;;
    malformed) printf 'one\ntwo\n' > "$pointer_file" ;;
    foreign)
      seed_case "$POINTER" marker foreign-slug
      run_project "$POINTER" foreign-slug "$POINTER/.superpowers/sdd/projections/foreign-requested.md" "$POINTER/.superpowers/sdd/foreign-state"
      printf '%s\n' "$PROJECT_OUTPUT" > "$pointer_file"
      ;;
    foreign-spec)
      shadow="$POINTER/docs/maxi/specs/shadow-root"
      mkdir -p "$shadow"
      write_spec "$shadow/spec.md" marker adapter-sample
      cp "$FIXTURES/plan.md" "$shadow/plan.md"
      sed 's/Write the second file/Write the foreign-root second file/' "$FIXTURES/tasks.md" > "$shadow/tasks.md"
      shadow_projection="$(bash "$PROJECT" --spec "$shadow/spec.md" --plan "$shadow/plan.md" --tasks "$shadow/tasks.md" --output "$POINTER/.superpowers/sdd/projections/shadow.md" --state-file "$POINTER/.superpowers/sdd/shadow-state")"
      printf '%s\n' "$shadow_projection" > "$pointer_file"
      ;;
    external)
      run_project "$POINTER"
      external_projection="$WORK/external-pointer-projection.md"
      mv "$PROJECT_OUTPUT" "$external_projection"
      printf '%s\n' "$external_projection" > "$pointer_file"
      ;;
    provenance)
      run_project "$POINTER"
      provenance_projection="$PROJECT_OUTPUT"
      sed 's/^plan_revision: 7$/plan_revision: 99/' "$provenance_projection" > "$POINTER/change"
      mv "$POINTER/change" "$provenance_projection"
      ;;
    cycle)
      run_project "$POINTER"
      cycle_projection="$PROJECT_OUTPUT"
      sed "s|^predecessor_projection: null$|predecessor_projection: $cycle_projection|" "$cycle_projection" > "$POINTER/change"
      mv "$POINTER/change" "$cycle_projection"
      ;;
  esac
  run_project "$POINTER"
  [ "$PROJECT_STATUS" -ne 0 ] && ok "$pointer_case active pointer fails closed" || fail "$pointer_case active pointer fails closed"
done

# Fresh all-checked execution still produces a final-review-only projection.
ALL_CHECKED="$WORK/all-checked"
init_repo "$ALL_CHECKED"
seed_case "$ALL_CHECKED"
sed 's/- \[ \]/- [x]/' "$ALL_CHECKED/docs/maxi/specs/adapter-sample/tasks.md" > "$ALL_CHECKED/change"
mv "$ALL_CHECKED/change" "$ALL_CHECKED/docs/maxi/specs/adapter-sample/tasks.md"
run_project "$ALL_CHECKED"
assert_eq "$PROJECT_STATUS" 0 'fresh all-checked projection succeeds'
assert_has "$PROJECT_OUTPUT" 'execution_mode: final-review-only' 'fresh all-checked projection requires final review'
assert_eq "$(grep -c '^### Task ' "$PROJECT_OUTPUT" || true)" 0 'final-review-only projection dispatches no tasks'

# Ordinary interruption after final reconciliation reuses its complete ledger.
INTERRUPTED="$WORK/interrupted"
init_repo "$INTERRUPTED"
seed_case "$INTERRUPTED"
run_project "$INTERRUPTED"
INT_PROJECTION="$PROJECT_OUTPUT"
INT_LEDGER="$INTERRUPTED/.superpowers/sdd/$(basename "$INT_PROJECTION" .md)/progress.md"
mkdir -p "$(dirname "$INT_LEDGER")"
printf '# SDD ledger — plan: %s\nMaxi selection: T001 T002 T003\nMaxi projection SHA256: %s\n%s\n%s\n%s\n' "$INT_PROJECTION" "$(sha "$INT_PROJECTION")" "$COMPLETE_1_CLEAN" "$COMPLETE_2_PARKED" "$COMPLETE_3_CLEAN" > "$INT_LEDGER"
remaining="$(bash "$RECONCILE" --projection "$INT_PROJECTION" --ledger "$INT_LEDGER" --tasks "$INTERRUPTED/docs/maxi/specs/adapter-sample/tasks.md")"
assert_eq "$remaining" 0 'last reconciliation reaches zero pending'
run_project "$INTERRUPTED"
assert_eq "$PROJECT_OUTPUT" "$INT_PROJECTION" 'completed ordinary projection is reused after interruption'
assert_has "$INT_PROJECTION" 'execution_mode: ordinary' 'interrupted run remains ordinary'

# Reconciliation preserves task numbering across interruptions.
RESUME="$WORK/resume"
init_repo "$RESUME"
seed_case "$RESUME"
run_project "$RESUME"
RESUME_PROJECTION="$PROJECT_OUTPUT"
RESUME_TASKS="$RESUME/docs/maxi/specs/adapter-sample/tasks.md"
RESUME_LEDGER="$RESUME/.superpowers/sdd/$(basename "$RESUME_PROJECTION" .md)/progress.md"
mkdir -p "$(dirname "$RESUME_LEDGER")"
printf '# SDD ledger — plan: %s\nMaxi selection: T001 T002 T003\nMaxi projection SHA256: %s\n%s\nRuling: keep numbering stable\n' "$RESUME_PROJECTION" "$(sha "$RESUME_PROJECTION")" "$COMPLETE_1_CLEAN" > "$RESUME_LEDGER"
foreign_ledger="$WORK/foreign-progress.md"
printf '# SDD ledger — plan: %s\nMaxi selection: T001 T002 T003\nMaxi projection SHA256: %s\n%s\n' "$RESUME_PROJECTION" "$(sha "$RESUME_PROJECTION")" "$COMPLETE_1_CLEAN" > "$foreign_ledger"
resume_tasks_before="$(sha "$RESUME_TASKS")"
set +e
bash "$RECONCILE" --projection "$RESUME_PROJECTION" --ledger "$foreign_ledger" --tasks "$RESUME_TASKS" >/dev/null 2>&1
foreign_ledger_status=$?
set -e
[ "$foreign_ledger_status" -ne 0 ] && ok 'reconciliation ledger stays in bound worktree' || fail 'reconciliation ledger stays in bound worktree'
assert_eq "$(sha "$RESUME_TASKS")" "$resume_tasks_before" 'foreign reconciliation leaves tasks byte-identical'
assert_eq "$(bash "$RECONCILE" --projection "$RESUME_PROJECTION" --ledger "$RESUME_LEDGER" --tasks "$RESUME_TASKS")" 2 'first reconciliation reports two pending'
assert_has "$RESUME_TASKS" '- [x] T001 ' 'first reconciliation checks only T001'
assert_has "$RESUME_TASKS" '- [ ] T002 ' 'first reconciliation leaves T002 pending'
assert_has "$RESUME_TASKS" '- [ ] T003 ' 'first reconciliation leaves T003 pending'
run_project "$RESUME"
assert_eq "$PROJECT_OUTPUT" "$RESUME_PROJECTION" 'resume keeps immutable projection'
assert_has "$RESUME_PROJECTION" '### Task 2: T002 ' 'resume keeps T002 as upstream Task 2'
printf '%s\n' "$COMPLETE_2_PARKED" >> "$RESUME_LEDGER"
assert_eq "$(bash "$RECONCILE" --projection "$RESUME_PROJECTION" --ledger "$RESUME_LEDGER" --tasks "$RESUME_TASKS")" 1 'second reconciliation reports one pending'
assert_has "$RESUME_TASKS" '- [x] T002 ' 'second reconciliation checks T002'
assert_eq "$(grep -c '^### Task 3: T003 ' "$RESUME_PROJECTION")" 1 'T003 remains pending exactly once in immutable projection'
assert_has "$RESUME_LEDGER" 'Ruling: keep numbering stable' 'ledger Ruling persists unchanged'

# Reconciliation rejects bare and malformed completion records before writing.
for completion_case in bare malformed; do
  RECONCILE_REPO="$WORK/reconcile-$completion_case"
  init_repo "$RECONCILE_REPO"
  seed_case "$RECONCILE_REPO"
  run_project "$RECONCILE_REPO"
  RECONCILE_PROJECTION="$PROJECT_OUTPUT"
  RECONCILE_TASKS="$RECONCILE_REPO/docs/maxi/specs/adapter-sample/tasks.md"
  RECONCILE_LEDGER="$RECONCILE_REPO/.superpowers/sdd/$(basename "$RECONCILE_PROJECTION" .md)/progress.md"
  case "$completion_case" in
    bare) printf 'Task 1: complete\n' >> "$RECONCILE_LEDGER" ;;
    malformed) printf 'Task 1: complete (commits 1111111..2222222, 0 parked)\n' >> "$RECONCILE_LEDGER" ;;
  esac
  reconcile_before="$(sha "$RECONCILE_TASKS")"
  set +e
  bash "$RECONCILE" --projection "$RECONCILE_PROJECTION" --ledger "$RECONCILE_LEDGER" --tasks "$RECONCILE_TASKS" >/dev/null 2>&1
  reconcile_status=$?
  set -e
  [ "$reconcile_status" -ne 0 ] && ok "$completion_case completion rejects at reconciliation boundary" || fail "$completion_case completion rejects at reconciliation boundary" 'invalid completion was accepted'
  assert_eq "$(sha "$RECONCILE_TASKS")" "$reconcile_before" "$completion_case reconciliation leaves tasks byte-identical"
done

# The skill contract must bind upstream helper calls to the selected worktree.
WORKSPACE_FROM_FOREIGN="$(cd "$RESUME" && bash "$ROOT/skills/subagent-driven-development/scripts/sdd-workspace" "$RESUME_PROJECTION")"
case "$WORKSPACE_FROM_FOREIGN" in "$RESUME/.superpowers/sdd/"*) ok 'upstream workspace is created in bound worktree' ;; *) fail 'upstream workspace is created in bound worktree' "$WORKSPACE_FROM_FOREIGN" ;; esac

if [ "${ADAPTER_PHASE:-all}" = core ]; then
  [ "$failures" -eq 0 ] || { echo "FAILED: $failures core adapter checks failed" >&2; exit 1; }
  echo 'All core adapter checks passed.'
  exit 0
fi

# Terminal receipt: build a reviewed Git range, two-workspace lineage, and exact review envelope.
TERM="$WORK/terminal"
init_repo "$TERM"
seed_case "$TERM"
printf 'base\n' > "$TERM/app.txt"
git -C "$TERM" add .gitignore app.txt docs
git -C "$TERM" commit -qm 'base'
MERGE_BASE="$(git -C "$TERM" rev-parse HEAD)"
run_project "$TERM"
TERM_OLD="$PROJECT_OUTPUT"
TERM_OLD_LEDGER="$TERM/.superpowers/sdd/$(basename "$TERM_OLD" .md)/progress.md"
mkdir -p "$(dirname "$TERM_OLD_LEDGER")"
printf '# SDD ledger — plan: %s\nMaxi selection: T001 T002 T003\nMaxi projection SHA256: %s\n%s\nTask 1: parked — deferred option — Ruling: first workspace ruling\n' "$TERM_OLD" "$(sha "$TERM_OLD")" "$COMPLETE_1_CLEAN" > "$TERM_OLD_LEDGER"
bash "$RECONCILE" --projection "$TERM_OLD" --ledger "$TERM_OLD_LEDGER" --tasks "$TERM/docs/maxi/specs/adapter-sample/tasks.md" >/dev/null
sed 's/- \[ \] T002/- [x] T002/' "$TERM/docs/maxi/specs/adapter-sample/tasks.md" > "$TERM/change"
mv "$TERM/change" "$TERM/docs/maxi/specs/adapter-sample/tasks.md"
sed 's/Write the second file/Write the corrected terminal file/' "$TERM/docs/maxi/specs/adapter-sample/tasks.md" > "$TERM/change"
mv "$TERM/change" "$TERM/docs/maxi/specs/adapter-sample/tasks.md"
run_project "$TERM"
TERM_PROJECTION="$PROJECT_OUTPUT"
assert_has "$TERM_PROJECTION" '### Task 1: T002 ' 'terminal successor retains checkbox-only uncompleted task'
assert_has "$TERM_PROJECTION" '### Task 2: T003 ' 'terminal successor retains remaining pending task'
TERM_LEDGER="$TERM/.superpowers/sdd/$(basename "$TERM_PROJECTION" .md)/progress.md"
mkdir -p "$(dirname "$TERM_LEDGER")"
printf '# SDD ledger — plan: %s\nMaxi selection: T002 T003\nMaxi projection SHA256: %s\n%s\n%s\nTask 2: Ruling: successor workspace ruling\n' "$TERM_PROJECTION" "$(sha "$TERM_PROJECTION")" "$COMPLETE_1_CLEAN" "$COMPLETE_2_PARKED" > "$TERM_LEDGER"
bash "$RECONCILE" --projection "$TERM_PROJECTION" --ledger "$TERM_LEDGER" --tasks "$TERM/docs/maxi/specs/adapter-sample/tasks.md" >/dev/null
printf 'reviewed implementation\n' >> "$TERM/app.txt"
git -C "$TERM" add app.txt
git -C "$TERM" commit -qm 'implementation'
REVIEWED_HEAD="$(git -C "$TERM" rev-parse HEAD)"
REVIEWED_TREE="$(git -C "$TERM" rev-parse HEAD^{tree})"
FULL_PACKAGE="$TERM/.superpowers/sdd/$(basename "$TERM_PROJECTION" .md)/review-full.diff"
(cd "$TERM" && bash "$REVIEW_PACKAGE" "$TERM_PROJECTION" "$MERGE_BASE" "$REVIEWED_HEAD" "$FULL_PACKAGE") >/dev/null
FINAL_REVIEW="$(dirname "$TERM_LEDGER")/maxi-final-review.md"
REVIEWER_IDENTITY="$(dirname "$TERM_LEDGER")/final-reviewer-dispatch.identity"
printf 'reviewer_context: independent-reviewer\n' > "$REVIEWER_IDENTITY"
TERM_SPEC="$TERM/docs/maxi/specs/adapter-sample/spec.md"
TERM_TASKS="$TERM/docs/maxi/specs/adapter-sample/tasks.md"
{
  echo '---'
  echo "worktree: $TERM"
  echo "merge_base: $MERGE_BASE"
  echo "reviewed_head: $REVIEWED_HEAD"
  echo "reviewed_tree: $REVIEWED_TREE"
  echo "projection: $TERM_PROJECTION"
  echo "projection_sha256: $(sha "$TERM_PROJECTION")"
  echo "full_review_package: $FULL_PACKAGE"
  echo "full_review_package_sha256: $(sha "$FULL_PACKAGE")"
  echo 'fix_review_package: null'
  echo 'fix_review_package_sha256: null'
  echo "spec: $TERM_SPEC"
  echo "spec_sha256: $(sha "$TERM_SPEC")"
  echo "tasks: $TERM_TASKS"
  echo "tasks_sha256: $(sha "$TERM_TASKS")"
  echo 'reviewer_context: independent-reviewer'
  echo 'outcome: finish'
  echo '---'
  echo
  echo '### Strengths'
  echo '- The reviewed change matches its task projection.'
  echo
  echo '### Issues'
  echo
  echo '#### Critical (Must Fix)'
  echo 'None.'
  echo
  echo '#### Important (Should Fix)'
  echo 'None.'
  echo
  echo '#### Minor (Nice to Have)'
  echo 'None.'
  echo
  echo '### Recommendations'
  echo 'None.'
  echo
  echo '### Assessment'
  echo
  echo '**Ready to merge?** Yes'
  echo
  echo '**Reasoning:** The complete Git range satisfies the projection and has no blocking findings.'
} > "$FINAL_REVIEW"

# A valid-looking range header is not a review package, even with matching hashes.
TRUNCATED_PACKAGE="$(dirname "$TERM_LEDGER")/review-truncated.diff"
printf '# Review package: %s..%s\n' "$MERGE_BASE" "$REVIEWED_HEAD" > "$TRUNCATED_PACKAGE"
TRUNCATED_REVIEW="$FINAL_REVIEW.truncated-package"
awk -v package="$TRUNCATED_PACKAGE" -v digest="$(sha "$TRUNCATED_PACKAGE")" '
  /^full_review_package: / { print "full_review_package: " package; next }
  /^full_review_package_sha256: / { print "full_review_package_sha256: " digest; next }
  { print }
' "$FINAL_REVIEW" > "$TRUNCATED_REVIEW"
TRUNCATED_RECEIPT="$(dirname "$TERM_LEDGER")/truncated-package-receipt.md"
set +e
bash "$RECORD" --worktree "$TERM" --merge-base "$MERGE_BASE" --projection "$TERM_PROJECTION" --ledger "$TERM_LEDGER" --final-review "$TRUNCATED_REVIEW" --spec "$TERM_SPEC" --tasks "$TERM_TASKS" --output "$TRUNCATED_RECEIPT" >/dev/null 2>&1
truncated_status=$?
set -e
[ "$truncated_status" -ne 0 ] && [ ! -e "$TRUNCATED_RECEIPT" ] && ok 'truncated review package creates no receipt' || fail 'truncated review package creates no receipt' 'valid-looking header was accepted as the package'

# The final reviewer must be the exact harness identity persisted before dispatch.
mv "$REVIEWER_IDENTITY" "$REVIEWER_IDENTITY.saved"
MISSING_IDENTITY_RECEIPT="$(dirname "$TERM_LEDGER")/missing-reviewer-identity-receipt.md"
set +e
bash "$RECORD" --worktree "$TERM" --merge-base "$MERGE_BASE" --projection "$TERM_PROJECTION" --ledger "$TERM_LEDGER" --final-review "$FINAL_REVIEW" --spec "$TERM_SPEC" --tasks "$TERM_TASKS" --output "$MISSING_IDENTITY_RECEIPT" >/dev/null 2>&1
missing_identity_status=$?
set -e
mv "$REVIEWER_IDENTITY.saved" "$REVIEWER_IDENTITY"
[ "$missing_identity_status" -ne 0 ] && [ ! -e "$MISSING_IDENTITY_RECEIPT" ] && ok 'missing harness reviewer identity creates no receipt' || fail 'missing harness reviewer identity creates no receipt'

FORGED_REVIEW="$FINAL_REVIEW.forged-reviewer"
sed 's/^reviewer_context: independent-reviewer$/reviewer_context: forged-reviewer/' "$FINAL_REVIEW" > "$FORGED_REVIEW"
FORGED_RECEIPT="$(dirname "$TERM_LEDGER")/forged-reviewer-receipt.md"
set +e
bash "$RECORD" --worktree "$TERM" --merge-base "$MERGE_BASE" --projection "$TERM_PROJECTION" --ledger "$TERM_LEDGER" --final-review "$FORGED_REVIEW" --spec "$TERM_SPEC" --tasks "$TERM_TASKS" --output "$FORGED_RECEIPT" >/dev/null 2>&1
forged_status=$?
set -e
[ "$forged_status" -ne 0 ] && [ ! -e "$FORGED_RECEIPT" ] && ok 'forged reviewer identity creates no receipt' || fail 'forged reviewer identity creates no receipt' 'arbitrary review context was accepted'

# Receipt creation rejects bare and malformed completion evidence.
cp "$TERM_LEDGER" "$TERM_LEDGER.canonical"
for completion_case in bare malformed; do
  case "$completion_case" in
    bare)
      awk -v first="$COMPLETE_1_CLEAN" -v second="$COMPLETE_2_PARKED" '
        $0 == first { print "Task 1: complete"; next }
        $0 == second { print "Task 2: complete"; next }
        { print }
      ' "$TERM_LEDGER.canonical" > "$TERM_LEDGER"
      ;;
    malformed)
      awk -v first="$COMPLETE_1_CLEAN" '
        $0 == first { print "Task 1: complete (commits 111111..2222222, review clean)"; next }
        { print }
      ' "$TERM_LEDGER.canonical" > "$TERM_LEDGER"
      ;;
  esac
  INVALID_COMPLETION_RECEIPT="$(dirname "$TERM_LEDGER")/$completion_case-completion-receipt.md"
  set +e
  bash "$RECORD" --worktree "$TERM" --merge-base "$MERGE_BASE" --projection "$TERM_PROJECTION" --ledger "$TERM_LEDGER" --final-review "$FINAL_REVIEW" --spec "$TERM_SPEC" --tasks "$TERM_TASKS" --output "$INVALID_COMPLETION_RECEIPT" >/dev/null 2>&1
  invalid_completion_status=$?
  set -e
  [ "$invalid_completion_status" -ne 0 ] && [ ! -e "$INVALID_COMPLETION_RECEIPT" ] && ok "$completion_case completion rejects at receipt boundary" || fail "$completion_case completion rejects at receipt boundary" 'invalid completion created a terminal receipt'
done
mv "$TERM_LEDGER.canonical" "$TERM_LEDGER"

RECEIPT="$(dirname "$TERM_LEDGER")/terminal-receipt.md"
bash "$RECORD" --worktree "$TERM" --merge-base "$MERGE_BASE" --projection "$TERM_PROJECTION" --ledger "$TERM_LEDGER" --final-review "$FINAL_REVIEW" --spec "$TERM_SPEC" --tasks "$TERM_TASKS" --output "$RECEIPT"
[ -f "$RECEIPT" ] && ok 'terminal receipt is created at Finish boundary' || fail 'terminal receipt is created at Finish boundary'
assert_has "$RECEIPT" "reviewer_dispatch_identity: $REVIEWER_IDENTITY" 'receipt binds persisted reviewer dispatch identity'
assert_has "$RECEIPT" "reviewer_dispatch_identity_sha256: $(sha "$REVIEWER_IDENTITY")" 'receipt binds reviewer dispatch identity hash'
assert_has "$RECEIPT" 'reviewer_context: independent-reviewer' 'receipt binds reviewer context value'
RESULT_OUTPUT="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$RECEIPT")"
assert_has "$RECEIPT" 'Task 1: parked — deferred option — Ruling: first workspace ruling' 'receipt aggregates entire predecessor Ruling line'
assert_has "$RECEIPT" 'Task 2: Ruling: successor workspace ruling' 'receipt aggregates entire successor Ruling line'
assert_has <(printf '%s\n' "$RESULT_OUTPUT") 'READY_TO_FINISH' 'matching receipt emits READY_TO_FINISH'
assert_has <(printf '%s\n' "$RESULT_OUTPUT") 'Task 1: parked — deferred option — Ruling: first workspace ruling' 'result returns entire predecessor Ruling line with success'
assert_has <(printf '%s\n' "$RESULT_OUTPUT") 'Task 2: Ruling: successor workspace ruling' 'result returns entire successor Ruling line with success'
assert_has <(printf '%s\n' "$RESULT_OUTPUT") "LINEAGE: $TERM_OLD" 'result returns predecessor lineage with success'
assert_has <(printf '%s\n' "$RESULT_OUTPUT") "LINEAGE: $TERM_PROJECTION" 'result returns current lineage with success'

cp "$RECEIPT" "$RECEIPT.ruling-mutated"
sed 's/Ruling: first workspace ruling/Ruling: mutated workspace ruling/' "$RECEIPT.ruling-mutated" > "$RECEIPT.ruling-mutated.tmp"
mv "$RECEIPT.ruling-mutated.tmp" "$RECEIPT.ruling-mutated"
ruling_mutated_result="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$RECEIPT.ruling-mutated" 2>/dev/null || true)"
assert_not_has <(printf '%s\n' "$ruling_mutated_result") 'READY_TO_FINISH' 'mutated entire Ruling line invalidates ready'

# Rewriting receipt hashes must not bless bare, malformed, or incomplete evidence.
cp "$TERM_LEDGER" "$TERM_LEDGER.canonical"
cp "$RECEIPT" "$RECEIPT.canonical"
REHASH_DIR="$(dirname "$RECEIPT")/rehash"
mkdir -p "$REHASH_DIR"
for completion_case in bare malformed incomplete; do
  case "$completion_case" in
    bare)
      awk -v first="$COMPLETE_1_CLEAN" -v second="$COMPLETE_2_PARKED" '
        $0 == first { print "Task 1: complete"; next }
        $0 == second { print "Task 2: complete"; next }
        { print }
      ' "$TERM_LEDGER.canonical" > "$TERM_LEDGER"
      ;;
    malformed)
      awk -v first="$COMPLETE_1_CLEAN" '
        $0 == first { print "Task 1: complete (commits 1111111..2222222, 0 parked)"; next }
        { print }
      ' "$TERM_LEDGER.canonical" > "$TERM_LEDGER"
      ;;
    incomplete) grep -Fvx -- "$COMPLETE_2_PARKED" "$TERM_LEDGER.canonical" > "$TERM_LEDGER" ;;
  esac
  new_ledger_sha="$(sha "$TERM_LEDGER")"
  awk -v ledger="$TERM_LEDGER" -v digest="$new_ledger_sha" -v old="$(sha "$TERM_LEDGER.canonical")" '
    $0 == "ledger_sha256: " old { print "ledger_sha256: " digest; next }
    $0 == "LINEAGE_LEDGER: " ledger { terminal = 1; print; next }
    terminal && /^LINEAGE_LEDGER_SHA256: / { print "LINEAGE_LEDGER_SHA256: " digest; terminal = 0; next }
    { print }
  ' "$RECEIPT.canonical" > "$RECEIPT"
  grep '^LINEAGE: ' "$RECEIPT" | sed 's/^LINEAGE: //' > "$REHASH_DIR/lineage-projections"
  grep '^LINEAGE_PROJECTION_SHA256: ' "$RECEIPT" | sed 's/^LINEAGE_PROJECTION_SHA256: //' > "$REHASH_DIR/lineage-projection-hashes"
  grep '^LINEAGE_LEDGER: ' "$RECEIPT" | sed 's/^LINEAGE_LEDGER: //' > "$REHASH_DIR/lineage-ledgers"
  grep '^LINEAGE_LEDGER_SHA256: ' "$RECEIPT" | sed 's/^LINEAGE_LEDGER_SHA256: //' > "$REHASH_DIR/lineage-ledger-hashes"
  paste -d'|' "$REHASH_DIR/lineage-projections" "$REHASH_DIR/lineage-projection-hashes" "$REHASH_DIR/lineage-ledgers" "$REHASH_DIR/lineage-ledger-hashes" > "$REHASH_DIR/lineage-rehashed"
  lineage_rehash="$(sha "$REHASH_DIR/lineage-rehashed")"
  sed "s/^lineage_sha256: .*/lineage_sha256: $lineage_rehash/" "$RECEIPT" > "$RECEIPT.tmp" && mv "$RECEIPT.tmp" "$RECEIPT"
  invalid_rehashed="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$RECEIPT" 2>/dev/null || true)"
  assert_not_has <(printf '%s\n' "$invalid_rehashed") 'READY_TO_FINISH' "rehashed $completion_case ledger cannot emit ready"
done
mv "$TERM_LEDGER.canonical" "$TERM_LEDGER"
mv "$RECEIPT.canonical" "$RECEIPT"

cp "$FINAL_REVIEW" "$FINAL_REVIEW.saved"
cp "$RECEIPT" "$RECEIPT.saved"
sed 's/^reviewer_context: .*/reviewer_context: null/' "$FINAL_REVIEW.saved" > "$FINAL_REVIEW"
review_rehash="$(sha "$FINAL_REVIEW")"
sed "s/^final_review_sha256: .*/final_review_sha256: $review_rehash/" "$RECEIPT.saved" > "$RECEIPT"
invalid_context_rehashed="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$RECEIPT" 2>/dev/null || true)"
assert_not_has <(printf '%s\n' "$invalid_context_rehashed") 'READY_TO_FINISH' 'rehashed invalid reviewer context cannot emit ready'
mv "$FINAL_REVIEW.saved" "$FINAL_REVIEW"
mv "$RECEIPT.saved" "$RECEIPT"

# Any pending task blocks, while malformed task grammar fails closed.
cp "$TERM_TASKS" "$TERM_TASKS.saved"
awk '!changed && /^- \[x\] T003 / { sub(/^- \[x\]/, "- [ ]"); changed = 1 } { print }' "$TERM_TASKS.saved" > "$TERM_TASKS"
pending_output="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$RECEIPT" 2>/dev/null || true)"
assert_has <(printf '%s\n' "$pending_output") 'BLOCKED_PENDING_TASKS' 'pending checkbox emits blocked token'
assert_not_has <(printf '%s\n' "$pending_output") 'READY_TO_FINISH' 'pending checkbox cannot emit ready token'
printf '%s\n' '- [ ] T999 malformed duplicate task-like line' >> "$TERM_TASKS"
malformed_output="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$RECEIPT" 2>/dev/null || true)"
[ -z "$malformed_output" ] && ok 'malformed complete task file emits no token' || fail 'malformed complete task file emits no token' "$malformed_output"
mv "$TERM_TASKS.saved" "$TERM_TASKS"

# Mutating any bound receipt input invalidates terminal success.
for input in projection ledger final-review package reviewer-identity receipt; do
  case "$input" in
    projection) target="$TERM_PROJECTION" ;;
    ledger) target="$TERM_LEDGER" ;;
    final-review) target="$FINAL_REVIEW" ;;
    package) target="$FULL_PACKAGE" ;;
    reviewer-identity) target="$REVIEWER_IDENTITY" ;;
    receipt) target="$RECEIPT" ;;
  esac
  cp "$target" "$target.saved"
  printf '\nmutated\n' >> "$target"
  mutated="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$RECEIPT" 2>/dev/null || true)"
  assert_not_has <(printf '%s\n' "$mutated") 'READY_TO_FINISH' "$input hash mutation invalidates ready"
  mv "$target.saved" "$target"
done

# Git HEAD/tree, staged state, allowed dirty bytes, and disallowed paths are revalidated.
cp "$TERM_TASKS" "$WORK/term-tasks-reviewed"
printf 'new reviewed head\n' >> "$TERM/app.txt"
git -C "$TERM" add app.txt && git -C "$TERM" commit -qm 'post review'
head_changed="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$RECEIPT" 2>/dev/null || true)"
assert_not_has <(printf '%s\n' "$head_changed") 'READY_TO_FINISH' 'changed reviewed HEAD invalidates ready'
git -C "$TERM" reset --hard -q "$REVIEWED_HEAD"
cp "$WORK/term-tasks-reviewed" "$TERM_TASKS"

cp "$FINAL_REVIEW" "$FINAL_REVIEW.saved"
sed 's/^reviewed_tree: .*/reviewed_tree: 0000000000000000000000000000000000000000/' "$FINAL_REVIEW.saved" > "$FINAL_REVIEW"
tree_changed="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$RECEIPT" 2>/dev/null || true)"
assert_not_has <(printf '%s\n' "$tree_changed") 'READY_TO_FINISH' 'changed reviewed tree invalidates ready'
mv "$FINAL_REVIEW.saved" "$FINAL_REVIEW"

printf 'staged\n' >> "$TERM/app.txt" && git -C "$TERM" add app.txt
staged_changed="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$RECEIPT" 2>/dev/null || true)"
assert_not_has <(printf '%s\n' "$staged_changed") 'READY_TO_FINISH' 'staged state invalidates ready'
git -C "$TERM" reset -q HEAD app.txt && git -C "$TERM" checkout -q -- app.txt

cp "$TERM_TASKS" "$TERM_TASKS.saved"
printf '\nallowed path changed\n' >> "$TERM_TASKS"
allowed_changed="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$RECEIPT" 2>/dev/null || true)"
assert_not_has <(printf '%s\n' "$allowed_changed") 'READY_TO_FINISH' 'allowed working-tree bytes invalidate ready'
mv "$TERM_TASKS.saved" "$TERM_TASKS"

printf 'unreviewed working tree\n' >> "$TERM/app.txt"
worktree_changed="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$RECEIPT" 2>/dev/null || true)"
assert_not_has <(printf '%s\n' "$worktree_changed") 'READY_TO_FINISH' 'disallowed working-tree path invalidates ready'
git -C "$TERM" checkout -q -- app.txt

# Missing review verdict prevents receipt creation.
NO_VERDICT="$FINAL_REVIEW.no-verdict"
grep -v '^\*\*Ready to merge?\*\* Yes$' "$FINAL_REVIEW" > "$NO_VERDICT"
NO_RECEIPT="$(dirname "$TERM_LEDGER")/no-verdict-receipt.md"
set +e
bash "$RECORD" --worktree "$TERM" --merge-base "$MERGE_BASE" --projection "$TERM_PROJECTION" --ledger "$TERM_LEDGER" --final-review "$NO_VERDICT" --spec "$TERM_SPEC" --tasks "$TERM_TASKS" --output "$NO_RECEIPT" >/dev/null 2>&1
no_verdict_status=$?
set -e
[ "$no_verdict_status" -ne 0 ] && [ ! -e "$NO_RECEIPT" ] && ok 'missing final verdict creates no receipt' || fail 'missing final verdict creates no receipt'

for nonterminal_verdict in No 'With fixes'; do
  verdict_slug="$(printf '%s' "$nonterminal_verdict" | tr '[:upper:] ' '[:lower:]-')"
  NONTERMINAL_REVIEW="$FINAL_REVIEW.$verdict_slug"
  sed "s/^\*\*Ready to merge?\*\* Yes$/\*\*Ready to merge?\*\* $nonterminal_verdict/" "$FINAL_REVIEW" > "$NONTERMINAL_REVIEW"
  NONTERMINAL_RECEIPT="$(dirname "$TERM_LEDGER")/$verdict_slug-receipt.md"
  set +e
  bash "$RECORD" --worktree "$TERM" --merge-base "$MERGE_BASE" --projection "$TERM_PROJECTION" --ledger "$TERM_LEDGER" --final-review "$NONTERMINAL_REVIEW" --spec "$TERM_SPEC" --tasks "$TERM_TASKS" --output "$NONTERMINAL_RECEIPT" >/dev/null 2>&1
  nonterminal_status=$?
  set -e
  [ "$nonterminal_status" -ne 0 ] && [ ! -e "$NONTERMINAL_RECEIPT" ] && ok "Ready to merge $nonterminal_verdict creates no receipt" || fail "Ready to merge $nonterminal_verdict creates no receipt"
done

LEGACY_VERDICT_REVIEW="$FINAL_REVIEW.legacy-verdict"
sed 's/^\*\*Ready to merge?\*\* Yes$/Verdict: approved/' "$FINAL_REVIEW" > "$LEGACY_VERDICT_REVIEW"
LEGACY_VERDICT_RECEIPT="$(dirname "$TERM_LEDGER")/legacy-verdict-receipt.md"
set +e
bash "$RECORD" --worktree "$TERM" --merge-base "$MERGE_BASE" --projection "$TERM_PROJECTION" --ledger "$TERM_LEDGER" --final-review "$LEGACY_VERDICT_REVIEW" --spec "$TERM_SPEC" --tasks "$TERM_TASKS" --output "$LEGACY_VERDICT_RECEIPT" >/dev/null 2>&1
legacy_verdict_status=$?
set -e
[ "$legacy_verdict_status" -ne 0 ] && [ ! -e "$LEGACY_VERDICT_RECEIPT" ] && ok 'legacy local verdict creates no receipt' || fail 'legacy local verdict creates no receipt'

# A whole-branch review that needed fixes terminates on the exact upstream
# scoped re-review conclusion, not on a fabricated second Ready=Yes verdict.
printf 'review fix\n' >> "$TERM/app.txt"
git -C "$TERM" add app.txt
git -C "$TERM" commit -qm 'review fix'
FIXED_HEAD="$(git -C "$TERM" rev-parse HEAD)"
FIXED_TREE="$(git -C "$TERM" rev-parse HEAD^{tree})"
FIX_PACKAGE="$(dirname "$TERM_LEDGER")/review-fix.diff"
(cd "$TERM" && bash "$REVIEW_PACKAGE" "$TERM_PROJECTION" "$REVIEWED_HEAD" "$FIXED_HEAD" "$FIX_PACKAGE") >/dev/null
FIX_REVIEW="$(dirname "$TERM_LEDGER")/maxi-final-fix-review.md"
awk -v head="$FIXED_HEAD" -v tree="$FIXED_TREE" -v package="$FIX_PACKAGE" -v digest="$(sha "$FIX_PACKAGE")" '
  /^reviewed_head: / { print "reviewed_head: " head; next }
  /^reviewed_tree: / { print "reviewed_tree: " tree; next }
  /^fix_review_package: / { print "fix_review_package: " package; next }
  /^fix_review_package_sha256: / { print "fix_review_package_sha256: " digest; next }
  /^\*\*Ready to merge\?\*\* Yes$/ {
    print "**Ready to merge?** With fixes"
    print "**Fix round:** All findings addressed, no new Critical/Important breakage"
    next
  }
  { print }
' "$FINAL_REVIEW" > "$FIX_REVIEW"
FIX_RECEIPT="$(dirname "$TERM_LEDGER")/terminal-fix-receipt.md"
set +e
bash "$RECORD" --worktree "$TERM" --merge-base "$MERGE_BASE" --projection "$TERM_PROJECTION" --ledger "$TERM_LEDGER" --final-review "$FIX_REVIEW" --spec "$TERM_SPEC" --tasks "$TERM_TASKS" --output "$FIX_RECEIPT" >/dev/null 2>&1
fix_receipt_status=$?
set -e
if [ "$fix_receipt_status" -eq 0 ] && [ -f "$FIX_RECEIPT" ]; then
  ok 'exact upstream fix-round conclusion creates receipt'
  FIX_RESULT="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$FIX_RECEIPT")"
  assert_has <(printf '%s\n' "$FIX_RESULT") 'READY_TO_FINISH' 'byte-exact fix package and exact upstream re-review conclusion emit ready'
else
  fail 'exact upstream fix-round conclusion creates receipt' 'valid upstream evidence was rejected'
fi

for fix_verdict_case in missing-conclusion local-suffix duplicate-conclusion mixed-ready no-initial-with-fixes reordered-conclusion; do
  BAD_FIX_REVIEW="$FIX_REVIEW.$fix_verdict_case"
  case "$fix_verdict_case" in
    missing-conclusion) grep -Fvx -- '**Fix round:** All findings addressed, no new Critical/Important breakage' "$FIX_REVIEW" > "$BAD_FIX_REVIEW" ;;
    local-suffix) sed 's/no new Critical\/Important breakage$/no new Critical\/Important breakage, no out-of-scope observation./' "$FIX_REVIEW" > "$BAD_FIX_REVIEW" ;;
    duplicate-conclusion) { cat "$FIX_REVIEW"; printf '%s\n' '**Fix round:** All findings addressed, no new Critical/Important breakage'; } > "$BAD_FIX_REVIEW" ;;
    mixed-ready) sed '/^\*\*Ready to merge?\*\* With fixes$/a\
**Ready to merge?** Yes' "$FIX_REVIEW" > "$BAD_FIX_REVIEW" ;;
    no-initial-with-fixes) sed 's/^\*\*Ready to merge?\*\* With fixes$/\*\*Ready to merge?\*\* No/' "$FIX_REVIEW" > "$BAD_FIX_REVIEW" ;;
    reordered-conclusion) awk '
      /^\*\*Ready to merge\?\*\* With fixes$/ { ready = $0; next }
      /^\*\*Fix round:\*\* All findings addressed, no new Critical\/Important breakage$/ { print; print ready; next }
      { print }
    ' "$FIX_REVIEW" > "$BAD_FIX_REVIEW" ;;
  esac
  BAD_FIX_RECEIPT="$(dirname "$TERM_LEDGER")/$fix_verdict_case-receipt.md"
  set +e
  bash "$RECORD" --worktree "$TERM" --merge-base "$MERGE_BASE" --projection "$TERM_PROJECTION" --ledger "$TERM_LEDGER" --final-review "$BAD_FIX_REVIEW" --spec "$TERM_SPEC" --tasks "$TERM_TASKS" --output "$BAD_FIX_RECEIPT" >/dev/null 2>&1
  bad_fix_status=$?
  set -e
  [ "$bad_fix_status" -ne 0 ] && [ ! -e "$BAD_FIX_RECEIPT" ] && ok "$fix_verdict_case fix-review evidence rejects" || fail "$fix_verdict_case fix-review evidence rejects" 'invalid fix-review evidence created a receipt'
done

if [ -f "$FIX_RECEIPT" ]; then
  cp "$FIX_REVIEW" "$FIX_REVIEW.saved"
  cp "$FIX_RECEIPT" "$FIX_RECEIPT.saved"
  sed 's/no new Critical\/Important breakage$/no new Critical\/Important breakage, no out-of-scope observation./' "$FIX_REVIEW.saved" > "$FIX_REVIEW"
  fix_review_rehash="$(sha "$FIX_REVIEW")"
  sed "s/^final_review_sha256: .*/final_review_sha256: $fix_review_rehash/" "$FIX_RECEIPT.saved" > "$FIX_RECEIPT"
  malformed_fix_result="$(bash "$RESULT" --tasks "$TERM_TASKS" --receipt "$FIX_RECEIPT" 2>/dev/null || true)"
  assert_not_has <(printf '%s\n' "$malformed_fix_result") 'READY_TO_FINISH' 'rehashed local-suffix conclusion cannot emit ready'
  mv "$FIX_REVIEW.saved" "$FIX_REVIEW"
  mv "$FIX_RECEIPT.saved" "$FIX_RECEIPT"
fi

if [ "$failures" -gt 0 ]; then
  echo "FAILED: $failures x-develop adapter checks failed" >&2
  exit 1
fi

echo 'All x-develop adapter checks passed.'
