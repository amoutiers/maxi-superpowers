#!/usr/bin/env bash
# Run installed-plugin Git closure cases in external repositories with no remotes.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
CASES="$ROOT/tests/integration/git-closure-cases/cases.json"
CHECKER="$ROOT/tests/integration/git-closure-cases/check-evidence.py"
SELECTOR="${1:-all}"
[ "$#" -le 1 ] || { echo 'Usage: run-codex-git-closure-test.sh [all|core|case-name]' >&2; exit 2; }
command -v jq >/dev/null || { echo 'ERROR: jq required' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'ERROR: python3 required' >&2; exit 1; }
case "$SELECTOR" in
  all|core) ;;
  *) jq -e --arg name "$SELECTOR" 'any(.[]; .name == $name)' "$CASES" >/dev/null || {
       echo 'Usage: run-codex-git-closure-test.sh [all|core|case-name]' >&2; exit 2;
     } ;;
esac

USER_CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
[ -f "$USER_CODEX_HOME/auth.json" ] || { echo 'ERROR: Codex authentication file not found' >&2; exit 1; }
OUTPUT_DIR="$ROOT/.superpowers/sdd/integration/$(date +%Y%m%d%H%M%S)-$$/git-closure-$SELECTOR"
mkdir -p "$OUTPUT_DIR"
RUNTIME="$(mktemp -d "${TMPDIR:-/tmp}/maxi-git-closure.XXXXXX")"
RUNTIME="$(cd "$RUNTIME" && pwd -P)"
printf '%s\n' "$RUNTIME" > "$OUTPUT_DIR/runtime-path.txt"
export CODEX_HOME="$RUNTIME/codex-home"
export PYTHONDONTWRITEBYTECODE=1
mkdir -p "$CODEX_HOME" "$RUNTIME/marketplace/plugins/maxi" "$RUNTIME/marketplace/.agents/plugins"
ln -s "$USER_CODEX_HOME/auth.json" "$CODEX_HOME/auth.json"
cp -R "$ROOT/.codex-plugin" "$ROOT/skills" "$RUNTIME/marketplace/plugins/maxi/"
cp "$ROOT/.agents/plugins/marketplace.json" "$RUNTIME/marketplace/.agents/plugins/marketplace.json"

run_codex_with_deadline() {
  local log="$1"
  shift
  perl "$ROOT/tests/integration/run-with-deadline.pl" 300 5 -- "$@" </dev/null >> "$log" 2>&1
}

run_codex_with_deadline "$OUTPUT_DIR/install.log" codex plugin marketplace add "$RUNTIME/marketplace"
run_codex_with_deadline "$OUTPUT_DIR/install.log" codex plugin add maxi@maxi-superpowers
INSTALLED="$(find "$CODEX_HOME/plugins/cache/maxi-superpowers/maxi" -type d -name skills -print)"
[ -d "$INSTALLED" ] && [ "$(printf '%s\n' "$INSTALLED" | wc -l | tr -d ' ')" -eq 1 ] || {
  echo 'ERROR: missing or ambiguous installed skill snapshot' >&2; exit 1;
}
diff -rq "$ROOT/skills" "$INSTALLED" > "$OUTPUT_DIR/installed-diff.txt" || {
  echo 'ERROR: installed skill snapshot differs from source' >&2; exit 1;
}
cp -R "$INSTALLED" "$OUTPUT_DIR/installed-skills"
printf '%s\n' "Installed snapshot: $OUTPUT_DIR/installed-skills"

FAILED=0
while IFS= read -r name; do
  CASE_DIR="$OUTPUT_DIR/$name"
  FIXTURE="$RUNTIME/$name"
  mkdir -p "$CASE_DIR" "$FIXTURE"
  jq --arg name "$name" '.[] | select(.name == $name)' "$CASES" > "$CASE_DIR/case.json"
  MAXI_MODE="$(jq -r '.maxi // ""' "$CASE_DIR/case.json")"
  jq -r '.prompt' "$CASE_DIR/case.json" > "$CASE_DIR/prompt.txt"
  git -C "$FIXTURE" init -q -b main
  git -C "$FIXTURE" config user.name 'Maxi Integration'
  git -C "$FIXTURE" config user.email 'integration@example.invalid'
  git -C "$FIXTURE" config commit.gpgsign false
  printf 'print("ready")\n' > "$FIXTURE/app.py"
  cat > "$FIXTURE/check.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "$(python3 app.py)" = ready ]
[ ! -f fail.flag ]
[ ! -f feature.txt ] || [ ! -f target.txt ]
EOF
  chmod +x "$FIXTURE/check.sh"
  printf 'evidence/\n.superpowers/\n' > "$FIXTURE/.gitignore"
  if jq -e 'has("policy")' "$CASE_DIR/case.json" >/dev/null; then
    jq -r '.policy' "$CASE_DIR/case.json" > "$FIXTURE/AGENTS.md"
  fi
  git -C "$FIXTURE" add .
  git -C "$FIXTURE" commit -qm 'fixture base'
  BASE="$(git -C "$FIXTURE" rev-parse HEAD)"
  git -C "$FIXTURE" switch -qc batch
  printf 'completed maintenance batch\n' > "$FIXTURE/feature.txt"
  if jq -e '.failing_test // false' "$CASE_DIR/case.json" >/dev/null; then
    printf 'requires correction\n' > "$FIXTURE/fail.flag"
  fi
  if jq -e '.keep // false' "$CASE_DIR/case.json" >/dev/null; then
    cat > "$FIXTURE/WORK.md" <<'EOF'
# Work tracking

Decision: keep branch batch locally until the separate deployment acceptance completes.
Resume condition: that acceptance is complete. The batch and requirements have not changed.
EOF
  fi
  if jq -e '.work_log // false' "$CASE_DIR/case.json" >/dev/null; then
    cat > "$FIXTURE/WORK.md" <<'EOF'
# Work log

Authorized independent maintenance scope: finish the local feature.txt change on branch batch.
Implementation: completed and committed. Required local verification: ./check.sh, which must be rerun before closure.
Review: REVIEW.md records the completed scope review.
Separate operation: deployment acceptance remains pending and is independent of this maintenance batch.
Next step: carry out any remaining local work and identify indispensable decisions.
EOF
    cat > "$FIXTURE/REVIEW.md" <<'EOF'
# Bounded maintenance review

Reviewed feature.txt and check.sh for the authorized scope. No blocking findings.
EOF
  fi
  if jq -e 'has("maxi")' "$CASE_DIR/case.json" >/dev/null; then
    SPEC_DIR="$FIXTURE/docs/maxi/specs/0001-fixture"
    mkdir -p "$SPEC_DIR" "$FIXTURE/docs/maxi"
    printf '# Constitution\n\nComplete every requirement and verify all tests before closure.\n' > "$FIXTURE/docs/maxi/constitution.md"
    cat > "$SPEC_DIR/spec.md" <<'EOF'
---
slug: 0001-fixture
created: 2026-09-26
updated: 2026-09-26
status: implementing
design_cycle: 0
---

# Fixture spec

Both requirements must be completed in the normal Maxi pipeline.
EOF
    if [ "$MAXI_MODE" = partial ]; then
      printf '# Tasks\n\n- [x] T001 Complete the first requirement (plan Task 1)\n- [ ] T002 Complete the second requirement (plan Task 2)\n' > "$SPEC_DIR/tasks.md"
    elif [[ "$MAXI_MODE" = terminal || "$MAXI_MODE" = missing-review || "$MAXI_MODE" = invalid-receipt ]]; then
      cat > "$SPEC_DIR/tasks.md" <<'EOF'
---
spec_slug: 0001-fixture
updated: 2026-09-26
---

# Tasks

- [x] T001 Complete the requirement (plan Task 1)
EOF
    else
      printf '# Tasks\n\n- [ ] T001 Complete the requirement (plan Task 1)\n' > "$SPEC_DIR/tasks.md"
    fi
    if [[ "$MAXI_MODE" = terminal || "$MAXI_MODE" = missing-review || "$MAXI_MODE" = invalid-receipt ]]; then
      printf '# Plan\n\n### Task 1: First requirement\n\nImplement and verify it.\n' > "$SPEC_DIR/plan.md"
    else
      printf '# Plan\n\n### Task 1: First requirement\n\nImplement and verify it.\n\n### Task 2: Second requirement\n\nImplement and verify it.\n' > "$SPEC_DIR/plan.md"
    fi
  fi
  git -C "$FIXTURE" add .
  git -C "$FIXTURE" commit -qm 'verified local batch fixture'
  if jq -e '.no_pending // false' "$CASE_DIR/case.json" >/dev/null; then
    git -C "$FIXTURE" reset -q --hard main
  fi
  BATCH_TIP="$(git -C "$FIXTURE" rev-parse HEAD)"
  TERMINAL_RECEIPT=""
  TERMINAL_BEFORE=""
  if [[ "$MAXI_MODE" = terminal || "$MAXI_MODE" = missing-review || "$MAXI_MODE" = invalid-receipt ]]; then
    TERMINAL_RECEIPT="$(bash "$ROOT/tests/integration/git-closure-cases/seed-terminal-fixture.sh" \
      "$FIXTURE" "$BASE" "$INSTALLED")"
    BATCH_TIP="$(git -C "$FIXTURE" rev-parse HEAD)"
    if [ "$MAXI_MODE" = missing-review ]; then
      rm "$(dirname "$TERMINAL_RECEIPT")/maxi-final-review.md"
    elif [ "$MAXI_MODE" = invalid-receipt ]; then
      sed 's/^outcome: finish$/outcome: invalid/' "$TERMINAL_RECEIPT" > "$TERMINAL_RECEIPT.tmp"
      mv "$TERMINAL_RECEIPT.tmp" "$TERMINAL_RECEIPT"
    fi
    TERMINAL_BEFORE="$CASE_DIR/terminal-before.txt"
    if [ "$MAXI_MODE" = terminal ]; then
      bash "$INSTALLED/x-develop/result-contract.sh" --tasks "$SPEC_DIR/tasks.md" \
        --receipt "$TERMINAL_RECEIPT" > "$TERMINAL_BEFORE" 2>&1
      grep -Fxq READY_TO_FINISH "$TERMINAL_BEFORE"
    elif bash "$INSTALLED/x-develop/result-contract.sh" --tasks "$SPEC_DIR/tasks.md" \
      --receipt "$TERMINAL_RECEIPT" > "$TERMINAL_BEFORE" 2>&1; then
      echo "ERROR: invalid terminal fixture unexpectedly verified: $name" >&2
      exit 1
    fi
  fi
  if jq -e '.combined_failure // false' "$CASE_DIR/case.json" >/dev/null; then
    git -C "$FIXTURE" switch -q main
    printf 'independent main change\n' > "$FIXTURE/target.txt"
    git -C "$FIXTURE" add target.txt
    git -C "$FIXTURE" commit -qm 'independent target change'
    git -C "$FIXTURE" switch -q batch
  fi
  if jq -e '.ignored // false' "$CASE_DIR/case.json" >/dev/null; then
    mkdir -p "$FIXTURE/evidence"
    printf 'unique ignored local evidence\n' > "$FIXTURE/evidence/unique.txt"
  fi
  SECOND_WORKTREE=""
  if jq -e '.second_worktree // false' "$CASE_DIR/case.json" >/dev/null; then
    SECOND_WORKTREE="$RUNTIME/$name-in-use"
    git -C "$FIXTURE" worktree add -q "$SECOND_WORKTREE" main
  fi
  if jq -e '.detached // false' "$CASE_DIR/case.json" >/dev/null; then
    git -C "$FIXTURE" checkout -q --detach "$BATCH_TIP"
  fi
  TARGET_BEFORE="$(git -C "$FIXTURE" rev-parse refs/heads/main)"
  STATUS_BEFORE="$(git -C "$FIXTURE" status --porcelain=v1 --untracked-files=all)"
  printf '{}\n' > "$CASE_DIR/protected.json"
  while IFS= read -r relative; do
    digest="$(shasum -a 256 "$FIXTURE/$relative" | cut -d ' ' -f 1)"
    jq --arg key "$relative" --arg value "$digest" '. + {($key):$value}' \
      "$CASE_DIR/protected.json" > "$CASE_DIR/protected.tmp"
    mv "$CASE_DIR/protected.tmp" "$CASE_DIR/protected.json"
  done < <(jq -r '.protected[]' "$CASE_DIR/case.json")
  jq -n --slurpfile c "$CASE_DIR/case.json" --slurpfile p "$CASE_DIR/protected.json" \
    --arg fixture "$FIXTURE" --arg cli "$CASE_DIR/cli.jsonl" --arg target "$TARGET_BEFORE" \
    --arg tip "$BATCH_TIP" --arg status "$STATUS_BEFORE" --arg second "$SECOND_WORKTREE" \
    --arg receipt "$TERMINAL_RECEIPT" --arg terminal_before "$TERMINAL_BEFORE" \
    --arg maxi "$INSTALLED/using-maxi/SKILL.md" --arg implement "$INSTALLED/implement/SKILL.md" \
    --arg finishing "$INSTALLED/finishing-a-development-branch/SKILL.md" \
    '{case:$c[0],fixture:$fixture,cli:$cli,target_before:$target,batch_tip:$tip,
      status_before:$status,second_worktree:$second,terminal_receipt:$receipt,
      terminal_before:$terminal_before,protected_before:$p[0],
      installed:{"using-maxi":$maxi,"implement":$implement,
                 "finishing-a-development-branch":$finishing},exit_code:null}' > "$CASE_DIR/evidence.json"
  code=0
  (cd "$FIXTURE"; perl "$ROOT/tests/integration/run-with-deadline.pl" 300 5 -- \
    codex exec --json --sandbox workspace-write --add-dir "$FIXTURE/.git" \
      --cd "$FIXTURE" "$(cat "$CASE_DIR/prompt.txt")" \
    </dev/null > "$CASE_DIR/cli.jsonl" 2> "$CASE_DIR/cli.stderr") || code=$?
  jq --argjson code "$code" '.exit_code = $code' "$CASE_DIR/evidence.json" > "$CASE_DIR/evidence.tmp"
  mv "$CASE_DIR/evidence.tmp" "$CASE_DIR/evidence.json"
  git -C "$FIXTURE" status --porcelain=v1 --untracked-files=all > "$CASE_DIR/status-after.txt"
  git -C "$FIXTURE" show-ref > "$CASE_DIR/refs-after.txt"
  git -C "$FIXTURE" worktree list --porcelain > "$CASE_DIR/worktrees-after.txt"
  git -C "$FIXTURE" diff "$BASE" > "$CASE_DIR/final.diff"
  if python3 "$CHECKER" "$CASE_DIR/evidence.json" > "$CASE_DIR/result.json" 2> "$CASE_DIR/assertions.log"; then
    echo "PASS: $name; evidence: $CASE_DIR"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL/INCOMPLETE: $name (exit $code); evidence: $CASE_DIR"
    head -1 "$CASE_DIR/assertions.log"
  fi
done < <(jq -r --arg selector "$SELECTOR" '.[] | select($selector == "all" or .name == $selector or ($selector == "core" and (.name | startswith("ordinary-")))) | .name' "$CASES")
echo "Git closure cases failed/incomplete: $FAILED; runtime preserved at $RUNTIME"
[ "$FAILED" -eq 0 ]
