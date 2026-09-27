#!/usr/bin/env bash
# Validates the optional Codex integration harness without invoking Codex.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

HARNESS="$ROOT/tests/integration/run-codex-trigger-test.sh"
READINESS_HARNESS="$ROOT/tests/integration/run-codex-readiness-test.sh"
OLD_HARNESS="$ROOT/tests/integration/run-trigger-test.sh"
RUN_ALL="$ROOT/tests/integration/run-all.sh"
FAST_RUN_ALL="$ROOT/tests/run-all.sh"
TIMEOUT_TEST="$ROOT/tests/integration/test-codex-timeout.sh"
DEADLINE_RUNNER="$ROOT/tests/integration/run-with-deadline.pl"
failures=0

assert_file_exists "$HARNESS" "run-codex-trigger-test.sh"
assert_file_exists "$READINESS_HARNESS" "Codex readiness lifecycle runner"
assert_file_exists "$RUN_ALL" "integration run-all.sh"
assert_file_exists "$FAST_RUN_ALL" "fast tier run-all.sh"
assert_file_exists "$TIMEOUT_TEST" "Codex timeout regression test"
assert_file_exists "$DEADLINE_RUNNER" "Codex deadline supervisor"

if [ -e "$OLD_HARNESS" ]; then
  echo "FAIL [legacy Claude runner]: unexpected file: $OLD_HARNESS" >&2
  failures=$((failures + 1))
else
  echo "OK  [legacy Claude runner]"
fi

if [ -f "$HARNESS" ]; then
  assert_not_grep "$HARNESS" 'claude' "run-codex-trigger-test: no Claude dependency"
  assert_not_grep "$HARNESS" '/tmp' "run-codex-trigger-test: no system temporary directory"
  assert_not_grep "$HARNESS" 'MAXI_INTEGRATION_OUTPUT_ROOT' "run-codex-trigger-test: output root is not externally overrideable"
  assert_grep "$HARNESS" 'OUTPUT_ROOT="\$ROOT/\.superpowers/sdd/integration"' "run-codex-trigger-test: fixes output below the worktree"
  assert_grep "$HARNESS" 'OUTPUT_DIR="\$OUTPUT_ROOT/\$TIMESTAMP-\$\$/\$SKILL_NAME"' "run-codex-trigger-test: makes output path process-unique"
  assert_grep "$HARNESS" '\[\[ ! "\$SKILL_NAME" =~ \^\[A-Za-z0-9_-\]+\$ \]\]' "run-codex-trigger-test: rejects unsafe skill names before path construction"
  assert_grep "$HARNESS" 'CODEX_HOME=' "run-codex-trigger-test: isolates CODEX_HOME"
  assert_grep "$HARNESS" 'ln -s.*auth.json' "run-codex-trigger-test: symlinks existing auth.json"
  assert_grep "$HARNESS" 'cp -R.*\.codex-plugin' "run-codex-trigger-test: materially stages plugin manifest"
  assert_grep "$HARNESS" 'cp -R.*skills' "run-codex-trigger-test: materially stages skills"
  assert_grep "$HARNESS" 'cp.*\.agents/plugins/marketplace.json' "run-codex-trigger-test: stages supported marketplace manifest"
  assert_grep "$HARNESS" '^run_codex_with_deadline()' "run-codex-trigger-test: shares one portable Codex deadline helper"
  assert_grep "$HARNESS" 'perl "\$ROOT/tests/integration/run-with-deadline\.pl"' "run-codex-trigger-test: delegates deadlines to the owning supervisor"
  assert_not_grep "$HARNESS" 'CODEX_PID|WATCHDOG_PID|kill -TERM|kill -KILL' "run-codex-trigger-test: has no racy raw-PID watchdog"
  assert_grep "$HARNESS" 'run_codex_with_deadline "\$MARKETPLACE_LOG" codex plugin marketplace add' "run-codex-trigger-test: bounds marketplace installation"
  assert_grep "$HARNESS" 'run_codex_with_deadline "\$MARKETPLACE_LOG" codex plugin add' "run-codex-trigger-test: bounds plugin installation"
  assert_grep "$HARNESS" 'plugins/cache' "run-codex-trigger-test: locates installed plugin snapshot"
  assert_grep "$HARNESS" 'cmp -s.*EXPECTED_SKILL_PATH.*INSTALLED_SKILL_PATH' "run-codex-trigger-test: verifies installed skill snapshot"
  assert_grep "$HARNESS" 'INSTALLED_SKILL_RELATIVE_PATH="\${INSTALLED_SKILL_PATH#"\$ROOT/"}"' "run-codex-trigger-test: normalizes installed snapshot below the worktree"
  assert_grep "$HARNESS" 'codex exec --ephemeral --json --sandbox read-only' "run-codex-trigger-test: invokes isolated read-only Codex JSONL"
  assert_grep "$HARNESS" 'TEST-ONLY: Identify and read the applicable skill, then stop after reading it. Do not execute its workflow, ask for consent, or dispatch subagents.' "run-codex-trigger-test: stops after skill selection"
  assert_grep "$HARNESS" 'TIMEOUT_SECONDS=300' "run-codex-trigger-test: fixes the fallback deadline at 300 seconds"
  assert_grep "$HARNESS" 'TIMEOUT_GRACE_SECONDS=5' "run-codex-trigger-test: fixes a short termination grace period"
  assert_not_grep "$HARNESS" 'command -v timeout' "run-codex-trigger-test: uses one portable watchdog path"
  assert_grep "$HARNESS" 'run_codex_with_deadline "\$LOG_FILE" codex exec --ephemeral --json --sandbox read-only' "run-codex-trigger-test: bounds isolated read-only Codex JSONL"
  assert_grep "$HARNESS" ': > "\$MARKETPLACE_LOG"' "run-codex-trigger-test: initializes the install log once"
  assert_grep "$HARNESS" ': > "\$LOG_FILE"' "run-codex-trigger-test: initializes the execution log once"
  assert_grep "$HARNESS" 'CODEX_STATUS.*-ne 0' "run-codex-trigger-test: rejects a non-zero Codex exit"
  assert_grep "$HARNESS" 'turn.completed' "run-codex-trigger-test: requires a completed Codex turn"
  assert_grep "$HARNESS" 'turn.failed' "run-codex-trigger-test: rejects failed Codex turns"
  assert_grep "$HARNESS" 'failed to load plugin' "run-codex-trigger-test: rejects plugin loader failures"
  assert_grep "$HARNESS" 'jq -e' "run-codex-trigger-test: parses JSONL proof structurally"
  assert_grep "$HARNESS" 'item.completed' "run-codex-trigger-test: requires a completed command result"
  assert_grep "$HARNESS" 'aggregated_output' "run-codex-trigger-test: requires command output from the installed skill"
  assert_grep "$HARNESS" 'tr -d' "run-codex-trigger-test: removes binary prefixes before JSON parsing"
fi

if [ -f "$READINESS_HARNESS" ]; then
  assert_grep "$READINESS_HARNESS" 'codex exec.*--sandbox workspace-write' "readiness runner permits fixture writes"
  assert_grep "$READINESS_HARNESS" 'codex exec.*--cd.*FIXTURE' "readiness runner binds the fixture root"
  assert_grep "$READINESS_HARNESS" 'After /maxi:analyze, run one separate shell command containing only:' "readiness runner explicitly requests separate verifier proof"
  assert_grep "$READINESS_HARNESS" 'bash \\"\$INSTALLED_READINESS_CONTRACT\\" verify' "readiness runner prompts with the installed verifier"
  assert_grep "$READINESS_HARNESS" '\\"\$SPEC_DIR/analysis\.md\\" \\"\$SPEC_DIR/spec\.md\\" \\"\$SPEC_DIR/plan\.md\\" \\"\$SPEC_DIR/tasks\.md\\"' "readiness runner prompts with the exact absolute artifact tuple"
  assert_grep "$READINESS_HARNESS" 'Do not combine that verifier command with stamp or any other command' "readiness runner forbids combined verifier proof"
  assert_grep "$READINESS_HARNESS" 'git -C.*init' "readiness runner creates an isolated Git fixture"
  assert_grep "$READINESS_HARNESS" 'bash "\$INSTALLED_READINESS_CONTRACT" verify' "readiness runner verifies stamped evidence"
  assert_grep "$READINESS_HARNESS" 'SOURCE_STATE_BEFORE' "readiness runner snapshots source state"
  assert_grep "$READINESS_HARNESS" 'SOURCE_STATE_AFTER' "readiness runner verifies source state"
  assert_grep "$READINESS_HARNESS" 'FIXTURE_HEAD_BEFORE' "readiness runner snapshots fixture HEAD before Codex"
  assert_grep "$READINESS_HARNESS" 'FIXTURE_HEAD_AFTER' "readiness runner snapshots fixture HEAD after Codex"
  assert_grep "$READINESS_HARNESS" 'FIXTURE_HEAD_AFTER.*!=.*FIXTURE_HEAD_BEFORE' "readiness runner rejects fixture commits"
  assert_grep "$READINESS_HARNESS" 'command -v jq' "readiness runner requires jq"
  assert_grep "$READINESS_HARNESS" 'jq -e' "readiness runner parses JSONL structurally"
  assert_grep "$READINESS_HARNESS" '\.type == "turn.completed"' "readiness runner requires a top-level completed event"
  assert_grep "$READINESS_HARNESS" '\.type == "turn.failed"' "readiness runner rejects a top-level failed event"
  assert_not_grep "$READINESS_HARNESS" 'grep .*turn\.completed\|grep .*turn\.failed' "readiness runner does not substring-match terminal events"
  assert_grep "$READINESS_HARNESS" 'arg verifier "\$INSTALLED_READINESS_CONTRACT"' "readiness runner binds command proof to the installed verifier"
  assert_grep "$READINESS_HARNESS" 'arg analysis "\$SPEC_DIR/analysis\.md"' "readiness runner binds command proof to analysis.md"
  assert_grep "$READINESS_HARNESS" 'arg spec "\$SPEC_DIR/spec\.md"' "readiness runner binds command proof to spec.md"
  assert_grep "$READINESS_HARNESS" 'arg plan "\$SPEC_DIR/plan\.md"' "readiness runner binds command proof to plan.md"
  assert_grep "$READINESS_HARNESS" 'arg tasks "\$SPEC_DIR/tasks\.md"' "readiness runner binds command proof to tasks.md"
  assert_grep "$READINESS_HARNESS" 'arg project_root "\$FIXTURE"' "readiness runner binds explicit project root"
  assert_grep "$READINESS_HARNESS" 'cmp -s "\$ROOT/skills/review/review-inputs.sh" "\$INSTALLED_REVIEW_INPUTS"' "readiness runner byte checks installed decision-input helper"
  assert_grep "$READINESS_HARNESS" 'cmp -s "\$ROOT/skills/review/approval-guard.sh" "\$INSTALLED_APPROVAL_GUARD"' "readiness runner byte checks installed approval guard"
  assert_grep "$READINESS_HARNESS" 'cp "\$INSTALLED_READINESS_CONTRACT" "\$INSTALLED_REVIEW_INPUTS" "\$INSTALLED_APPROVAL_GUARD"' "readiness runner retains verified helper snapshots"
  assert_grep "$READINESS_HARNESS" 'def shell_words:' "readiness runner parses the verifier command into shell words"
  assert_grep "$READINESS_HARNESS" '\.type == "item.completed"' "readiness runner requires a completed verifier command item"
  assert_grep "$READINESS_HARNESS" '\.item\.type == "command_execution"' "readiness runner requires verifier command execution"
  assert_grep "$READINESS_HARNESS" '\.item\.exit_code == 0' "readiness runner requires verifier command success"
  assert_grep "$READINESS_HARNESS" '\.item\.status == "completed"' "readiness runner requires completed verifier command status"
  assert_grep "$READINESS_HARNESS" '\$words == \["/bin/zsh", "-lc", "bash",' "readiness runner requires the complete Codex shell argv"
  assert_grep "$READINESS_HARNESS" '\$verifier, "verify", \$analysis, \$spec, \$plan, \$tasks, \$project_root\]' "readiness runner requires the exact verifier argv"
  assert_not_grep "$READINESS_HARNESS" 'any(range' "readiness runner does not accept a verifier command subsequence"
  assert_not_grep "$READINESS_HARNESS" 'contains\(\$verifier\)' "readiness runner does not substring-match the verifier command"
  assert_not_grep "$READINESS_HARNESS" 'contains\("READINESS_VERIFIED"\)' "readiness runner does not substring-match verifier output"
  assert_grep "$READINESS_HARNESS" '\.item\.aggregated_output == "READINESS_VERIFIED"' "readiness runner requires exact verifier output"
  assert_grep "$READINESS_HARNESS" 'length == 1' "readiness runner requires exactly one verifier proof item"
  if awk '/^if \[ -n "\$SOURCE_STATE_BEFORE" \]; then/{ dirty = NR } /^mkdir -p "\$SPEC_DIR"/{ output = NR } /codex exec .*--sandbox workspace-write/{ exec = NR } END { exit !(dirty && output && exec && dirty < output && dirty < exec) }' "$READINESS_HARNESS"; then
    echo "OK  [readiness runner rejects dirty source before output and Codex]"
  else
    echo "FAIL [readiness runner rejects dirty source before output and Codex]" >&2
    failures=$((failures + 1))
  fi
  if awk '/^SOURCE_STATE_AFTER=/{ after = NR } /^echo "=== Results ==="$/{ results = NR } END { exit !(after && results && after < results) }' "$READINESS_HARNESS"; then
    echo "OK  [readiness runner snapshots final source state before result checks]"
  else
    echo "FAIL [readiness runner snapshots final source state before result checks]" >&2
    failures=$((failures + 1))
  fi
  if awk '/^FIXTURE_HEAD_BEFORE=/{ before = NR } /codex exec .*--sandbox workspace-write/{ exec = NR } /^FIXTURE_HEAD_AFTER=/{ after = NR } END { exit !(before && exec && after && before < exec && exec < after) }' "$READINESS_HARNESS"; then
    echo "OK  [readiness runner brackets Codex with fixture HEAD snapshots]"
  else
    echo "FAIL [readiness runner brackets Codex with fixture HEAD snapshots]" >&2
    failures=$((failures + 1))
  fi
fi

if [ -f "$DEADLINE_RUNNER" ]; then
  assert_grep "$DEADLINE_RUNNER" 'setpgrp(0, 0)' "deadline supervisor: isolates a Codex process group"
  assert_grep "$DEADLINE_RUNNER" 'waitpid(\$child_pid, WNOHANG)' "deadline supervisor: reaps its own child before deadline actions"
  assert_grep "$DEADLINE_RUNNER" 'kill \$signal, -\$child_pid' "deadline supervisor: signals the owned process group"
  assert_grep "$DEADLINE_RUNNER" 'waitpid(\$child_pid, 0)' "deadline supervisor: reaps after forceful termination"
  assert_grep "$DEADLINE_RUNNER" 'return 124 if \$timed_out' "deadline supervisor: normalizes deadline-caused non-zero exits"
fi

if [ -f "$RUN_ALL" ]; then
  assert_grep "$RUN_ALL" 'find "\$PROMPTS_DIR"' "integration run-all: derives skills from prompt files"
  assert_not_grep "$RUN_ALL" '^SKILLS=([^)]' "integration run-all: no non-empty inline hard-coded skill array"
  assert_not_grep "$RUN_ALL" '^  "[[:alnum:]_-]*"$' "integration run-all: no hard-coded skill array entries"
  assert_grep "$RUN_ALL" 'run-codex-trigger-test.sh' "integration run-all: invokes Codex runner"
  assert_grep "$RUN_ALL" 'run-codex-readiness-test.sh' "integration run-all invokes readiness lifecycle"
  assert_not_grep "$RUN_ALL" 'run-trigger-test.sh' "integration run-all: does not invoke legacy Claude runner"
fi

if [ -f "$FAST_RUN_ALL" ]; then
  assert_grep "$FAST_RUN_ALL" 'test-codex-timeout.sh' "fast tier: runs Codex timeout regression"
fi

# Behavioral checker regressions use recorded-shaped events, without Codex authentication.
CHECKER="$ROOT/tests/integration/assert-design-events.jq"
assert_file_exists "$CHECKER" "design event checker"
assert_file_exists "$ROOT/tests/integration/run-codex-design-test.sh" "installed design runner"
assert_grep "$RUN_ALL" 'run-codex-design-test.sh' "integration includes design behavior"
assert_grep "$RUN_ALL" 'run-codex-git-closure-test.sh' "integration includes Git closure behavior"
assert_file_exists "$ROOT/tests/integration/run-codex-git-closure-test.sh" "installed Git closure runner"
UPGRADE_RUNNER="$ROOT/tests/integration/run-codex-upgrade-test.sh"
UPGRADE_CHECKER="$ROOT/tests/integration/upgrade-cases/check-evidence.py"
assert_file_exists "$UPGRADE_RUNNER" "installed upgrade lifecycle runner"
assert_file_exists "$UPGRADE_CHECKER" "upgrade evidence checker"
assert_grep "$RUN_ALL" 'run-codex-upgrade-test.sh' "integration includes the installed upgrade lifecycle"
assert_grep "$UPGRADE_RUNNER" 'run-with-deadline.pl' "upgrade runner bounds Codex calls"
assert_grep "$UPGRADE_RUNNER" 'installed-diff.txt' "upgrade runner byte checks staged skills"
assert_grep "$UPGRADE_RUNNER" 'codex exec resume --json' "upgrade runner resumes the same session"
assert_grep "$UPGRADE_RUNNER" 'add-dir "\$repo/\.git"' "upgrade runner grants its isolated Git fixture write access"
assert_grep "$UPGRADE_RUNNER" 'sandbox_workspace_write.writable_roots' "upgrade runner preserves Git access on resume"
assert_grep "$UPGRADE_RUNNER" 'INCOMPLETE: first-task' "upgrade runner stops before Task 2 when Task 1 is incomplete"
assert_grep "$UPGRADE_RUNNER" 'pre-done-fixture' "upgrade runner retains the pre-done boundary"
assert_grep "$UPGRADE_RUNNER" 'check-evidence.py' "upgrade runner checks retained evidence"
if python3 "$ROOT/tests/integration/upgrade-cases/test-checker.py" >/dev/null; then
  echo "OK  [upgrade evidence checker regressions]"
else
  echo "FAIL [upgrade evidence checker regressions]" >&2
  failures=$((failures + 1))
fi
assert_file_exists "$ROOT/tests/integration/git-closure-cases/check-evidence.py" "Git closure evidence checker"
assert_file_exists "$ROOT/tests/integration/git-closure-cases/cases.json" "Git closure case matrix"
if python3 "$ROOT/tests/integration/git-closure-cases/test-checker.py" >/dev/null; then
  echo "OK  [Git closure checker regressions]"
else
  echo "FAIL [Git closure checker regressions]" >&2
  failures=$((failures + 1))
fi
assert_grep "$ROOT/tests/integration/run-codex-design-test.sh" 'codex exec resume --json "\$session_id"' "design resumes exact session"
assert_not_grep "$ROOT/tests/integration/run-codex-design-test.sh" 'codex exec --ephemeral' "design preserves structured sessions"
# Selector validation is exercised before authentication or runtime creation.
selector_home=$(mktemp -d)
for selector in initial revision boundaries all design-validation review-only; do
  selector_code=0
  CODEX_HOME="$selector_home" bash "$ROOT/tests/integration/run-codex-design-test.sh" "$selector" > "$selector_home/result" 2>&1 || selector_code=$?
  if [ "$selector_code" -eq 1 ] && grep -q 'authentication file not found' "$selector_home/result"; then
    echo "OK  [design selector accepted before auth: $selector]"
  else
    echo "FAIL [design selector rejected: $selector]" >&2
    failures=$((failures + 1))
  fi
done
selector_code=0
CODEX_HOME="$selector_home" bash "$ROOT/tests/integration/run-codex-design-test.sh" unknown-case > "$selector_home/result" 2>&1 || selector_code=$?
if [ "$selector_code" -eq 2 ] && ! grep -q 'authentication' "$selector_home/result"; then
  echo "OK  [design invalid selector rejected before auth]"
else
  echo "FAIL [design invalid selector reached auth]" >&2
  failures=$((failures + 1))
fi
rm -rf "$selector_home"

# Codex may read stdin even with a prompt argument. It must not consume the case list.
DESIGN_HARNESS="$ROOT/tests/integration/run-codex-design-test.sh"
if [ -f "$DESIGN_HARNESS" ]; then
  eval "$(sed -n '/^run_codex_with_deadline()/,/^}/p' "$DESIGN_HARNESS")"
  stdin_log=$(mktemp)
  labels=""
  while IFS= read -r label; do
    labels="$labels $label"
    run_codex_with_deadline "$stdin_log" cat
  done <<'LABELS'
one
two
LABELS
  rm "$stdin_log"
  if [ "$labels" = " one two" ]; then
    echo "OK  [design subprocess cannot consume case-list stdin]"
  else
    echo "FAIL [design subprocess consumed case-list stdin]" >&2
    failures=$((failures + 1))
  fi
fi
if command -v jq >/dev/null 2>&1 && [ -f "$CHECKER" ]; then
  sample="$ROOT/tests/integration/design-cases/checker-pass.json"
  if jq -e -f "$CHECKER" "$sample" >/dev/null; then
    echo "OK  [design checker: completed owner evidence and actual artifacts]"
  else
    echo "FAIL [design checker: positive transcript]" >&2
    failures=$((failures + 1))
  fi
  if jq '.sessions[0].events[0].payload.item.command[2] += "; cat unrelated.txt"' "$sample" | jq -e -f "$CHECKER" >/dev/null; then
    echo "OK  [design checker: finite brace before command separator]"
  else
    echo "FAIL [design checker: finite brace before command separator]" >&2
    failures=$((failures + 1))
  fi
  python_read=$(cat <<'PYTHON_READ'
python3 - <<'PY'
from pathlib import Path
base=Path('/installed')
for rel in ['plan/SKILL.md','clarify/SKILL.md']:
 p=base/rel
 print(p.read_text())
PY
PYTHON_READ
)
  if jq --arg command "$python_read" '.sessions[0].events[0].payload.item.command[2] = $command' "$sample" | jq -e -f "$CHECKER" >/dev/null; then
    echo "OK  [design checker: complete installed Python owner reads]"
  else
    echo "FAIL [design checker: complete installed Python owner reads]" >&2
    failures=$((failures + 1))
  fi
  if jq --arg command "${python_read/p.read_text()/p.name}" '.sessions[0].events[0].payload.item.command[2] = $command' "$sample" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
    echo "FAIL [design checker accepted Python owner names without content]" >&2
    failures=$((failures + 1))
  else
    echo "OK  [design checker rejects Python owner names without content]"
  fi
  for mutation in '/installed|/other' 'plan/SKILL.md|unknown/SKILL.md'; do
    wrong_command="${python_read/${mutation%%|*}/${mutation#*|}}"
    if jq --arg command "$wrong_command" '.sessions[0].events[0].payload.item.command[2] = $command' "$sample" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
      echo "FAIL [design checker accepted Python owner read with wrong path: $mutation]" >&2
      failures=$((failures + 1))
    else
      echo "OK  [design checker rejects Python owner read with wrong path: $mutation]"
    fi
  done
  if jq --arg command "$python_read" '.sessions[0].events[0].payload.item.command[2] = $command | .sessions[0].events[0].payload.item.aggregated_output = "PLAN only"' "$sample" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
    echo "FAIL [design checker accepted incomplete Python owner bytes]" >&2
    failures=$((failures + 1))
  else
    echo "OK  [design checker rejects incomplete Python owner bytes]"
  fi
  python_alias_read="${python_read/base=Path/b=Path}"
  python_alias_read="${python_alias_read/p=base/p=b}"
  if jq --arg command "$python_alias_read" '.sessions[0].events[0].payload.item.command[2] = $command' "$sample" | jq -e -f "$CHECKER" >/dev/null; then
    echo "OK  [design checker: observed Python base variable]"
  else
    echo "FAIL [design checker: observed Python base variable]" >&2
    failures=$((failures + 1))
  fi
  for wrong_command in "${python_alias_read/p=b/p=other}" "${python_alias_read/installed/other}"; do
    if jq --arg command "$wrong_command" '.sessions[0].events[0].payload.item.command[2] = $command' "$sample" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
      echo "FAIL [design checker accepted mismatched Python base variable]" >&2
      failures=$((failures + 1))
    else
      echo "OK  [design checker rejects mismatched Python base variable]"
    fi
  done
  newline=$'\n'
  for wrong_command in \
    "${python_read/ p=base/ base=Path('other'); p=base}" \
    "${python_read/ p=base/ base=Path('other')${newline} p=base}"; do
    if jq --arg command "$wrong_command" '.sessions[0].events[0].payload.item.command[2] = $command' "$sample" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
      echo "FAIL [design checker accepted reassigned Python installed base]" >&2
      failures=$((failures + 1))
    else
      echo "OK  [design checker rejects reassigned Python installed base]"
    fi
  done
  shell_read=$(cat <<'SHELL_READ'
p=/installed
cat "$p/plan/SKILL.md"
SHELL_READ
)
  if jq --arg command "$shell_read" '.sessions[0].events[0].payload.item.command[2] = $command' "$sample" | jq -e -f "$CHECKER" >/dev/null; then
    echo "OK  [design checker: observed shell variable cat read]"
  else
    echo "FAIL [design checker: observed shell variable cat read]" >&2
    failures=$((failures + 1))
  fi
  for wrong_command in "${shell_read/installed/other}" "${shell_read/\$p/\$other}" "${shell_read/plan/other}" "${shell_read/SKILL.md/SKILLXmd}" "${shell_read/cat /printf }" "${shell_read/cat /p=other; cat }"; do
    if jq --arg command "$wrong_command" '.sessions[0].events[0].payload.item.command[2] = $command' "$sample" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
      echo "FAIL [design checker accepted wrong shell variable cat read]" >&2
      failures=$((failures + 1))
    else
      echo "OK  [design checker rejects wrong shell variable cat read]"
    fi
  done
  question_sample=$(jq -c '
    .name = "questions" | .answers = ["independent choices", "dependent choice"] | .max_questions = 4 |
    .cli = [{"type":"turn.completed"},{"type":"turn.completed"},{"type":"turn.completed"},
      {"type":"item.completed","item":{"type":"agent_message","text":"Preview? Preview? Preview? Preview? Preview?"}}] |
    .sessions[0].events += [
      {"type":"turn_context","payload":{"turn_id":"turn-1"}},
      {"type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1","last_agent_message":"A? B? C?"}},
      {"type":"turn_context","payload":{"turn_id":"turn-2"}},
      {"type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-2","last_agent_message":"D?"}},
      {"type":"turn_context","payload":{"turn_id":"turn-3"}},
      {"type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-3","last_agent_message":"Choices recorded."}}
    ]' "$sample")
  if printf '%s\n' "$question_sample" | jq -e -f "$CHECKER" >/dev/null; then
    echo "OK  [design checker: scripted questions use completed final turns]"
  else
    echo "FAIL [design checker: scripted questions use completed final turns]" >&2
    failures=$((failures + 1))
  fi
  for mutation in \
    '.sessions[0].events[-5].payload.last_agent_message = "A? B? C? D? E?"' \
    'del(.sessions[0].events[-3])' \
    '.sessions[0].events[-3].payload.turn_id = "turn-1"' \
    '.sessions[0].events[-1].payload.last_agent_message = "Still?"'; do
    if printf '%s\n' "$question_sample" | jq "$mutation" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
      echo "FAIL [design checker accepted incomplete scripted final turn: $mutation]" >&2
      failures=$((failures + 1))
    else
      echo "OK  [design checker rejects incomplete scripted final turn]"
    fi
  done
  python_reserve=$(cat <<'PYTHON_RESERVE'
python3 - <<'PY'
import subprocess,json
result=subprocess.run(['bash',"/installed/review/design-contract.sh",'reserve',str(review)],capture_output=True,text=True)
print(json.dumps(dict(result=result.stdout,error=result.stderr,code=result.returncode)))
PY
PYTHON_RESERVE
)
  if jq --arg command "$python_reserve" '.sessions[0].events[1].payload.item |= (.command[2] = $command | .aggregated_output = ({result:.aggregated_output,error:"",code:0}|tojson))' "$sample" | jq -e -f "$CHECKER" >/dev/null; then
    echo "OK  [design checker: captured installed reservation]"
  else
    echo "FAIL [design checker: captured installed reservation]" >&2
    failures=$((failures + 1))
  fi
  for mutation in '.code = 1' '.error = "failed"' '.result = "not a reservation"'; do
    if jq --arg command "$python_reserve" --arg mutation "$mutation" '.sessions[0].events[1].payload.item |= (.command[2] = $command | .aggregated_output = ({result:.aggregated_output,error:"",code:0}|tojson))' "$sample" | jq ".sessions[0].events[1].payload.item.aggregated_output |= (fromjson | $mutation | tojson)" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
      echo "FAIL [design checker accepted invalid captured reservation: $mutation]" >&2
      failures=$((failures + 1))
    else
      echo "OK  [design checker rejects invalid captured reservation: $mutation]"
    fi
  done
  for wrong_command in "${python_reserve/design-contract.sh/design-contract.sh.bak}" "${python_reserve/reserve/preserve}" "${python_reserve/reserve/reserve!}" "${python_reserve/result=subprocess.run/result=wrong_run}"; do
    if jq --arg command "$wrong_command" '.sessions[0].events[1].payload.item |= (.command[2] = $command | .aggregated_output = ({result:.aggregated_output,error:"",code:0}|tojson))' "$sample" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
      echo "FAIL [design checker accepted wrong captured reservation call]" >&2
      failures=$((failures + 1))
    else
      echo "OK  [design checker rejects wrong captured reservation call]"
    fi
  done
  python_check_output=$(cat <<'PYTHON_CHECK_OUTPUT'
python3 - <<'PY'
import json,subprocess
from pathlib import Path
b=Path('/installed')
out=subprocess.check_output(['bash',str(b/'review/design-contract.sh'),'reserve',str(review)],text=True)
print(json.dumps({'reservation':out}))
PY
PYTHON_CHECK_OUTPUT
)
  if jq --arg command "$python_check_output" '.sessions[0].events[1].payload.item |= (.command[2] = $command | .aggregated_output = ({reservation:.aggregated_output}|tojson))' "$sample" | jq -e -f "$CHECKER" >/dev/null; then
    echo "OK  [design checker: observed JSON check_output reservation]"
  else
    echo "FAIL [design checker: observed JSON check_output reservation]" >&2
    failures=$((failures + 1))
  fi
  for wrong_command in "${python_check_output/installed/other}" "${python_check_output/str(b/str(other}" "${python_check_output/design-contract.sh/design-contract.sh.bak}" "${python_check_output/reserve/preserve}" "${python_check_output/reserve/reserve!}" "${python_check_output/check_output/wrong_call}"; do
    if jq --arg command "$wrong_command" '.sessions[0].events[1].payload.item |= (.command[2] = $command | .aggregated_output = ({reservation:.aggregated_output}|tojson))' "$sample" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
      echo "FAIL [design checker accepted wrong JSON check_output reservation]" >&2
      failures=$((failures + 1))
    else
      echo "OK  [design checker rejects wrong JSON check_output reservation]"
    fi
  done
  if jq --arg command "$python_check_output" '.sessions[0].events[1].payload.item |= (.command[2] = $command | .aggregated_output = ({reservation:"wrong"}|tojson))' "$sample" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
    echo "FAIL [design checker accepted wrong JSON reservation result]" >&2
    failures=$((failures + 1))
  else
    echo "OK  [design checker rejects wrong JSON reservation result]"
  fi
  python_raw_captured=$(cat <<'PYTHON_RAW_CAPTURED'
python3 - <<'PY'
import subprocess
from pathlib import Path
b=Path('/installed/review')
result=subprocess.run(['bash',str(b/'design-contract.sh'),'reserve',str(review)],text=True,capture_output=True)
print(result.stdout); print(result.stderr); result.check_returncode()
PY
PYTHON_RAW_CAPTURED
)
  python_raw_direct=$(cat <<'PYTHON_RAW_DIRECT'
python3 - <<'PY'
import subprocess
from pathlib import Path
b=Path("/installed/review")
subprocess.run(['bash',str(b/'design-contract.sh'),'reserve',str(review)],check=True)
PY
PYTHON_RAW_DIRECT
)
  for command in "$python_raw_captured" "$python_raw_direct"; do
    if jq --arg command "$command" '.sessions[0].events[1].payload.item.command[2] = $command' "$sample" | jq -e -f "$CHECKER" >/dev/null; then
      echo "OK  [design checker: observed raw subprocess reservation]"
    else
      echo "FAIL [design checker: observed raw subprocess reservation]" >&2
      failures=$((failures + 1))
    fi
  done
  for wrong_command in "${python_raw_direct/installed/other}" "${python_raw_direct/str(b/str(other}" "${python_raw_direct/design-contract.sh/design-contract.sh.bak}" "${python_raw_direct/reserve/preserve}" "${python_raw_direct/reserve/reserve!}" "${python_raw_direct/subprocess.run/wrong_run}" "${python_raw_direct/subprocess.run/b=Path('other'); subprocess.run}"; do
    if jq --arg command "$wrong_command" '.sessions[0].events[1].payload.item.command[2] = $command' "$sample" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
      echo "FAIL [design checker accepted wrong raw subprocess reservation]" >&2
      failures=$((failures + 1))
    else
      echo "OK  [design checker rejects wrong raw subprocess reservation]"
    fi
  done
  if jq --arg command "$python_raw_direct" '.sessions[0].events[1].payload.item |= (.command[2] = $command | .aggregated_output = "{\"reservation\":broken}")' "$sample" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
    echo "FAIL [design checker accepted malformed raw reservation output]" >&2
    failures=$((failures + 1))
  else
    echo "OK  [design checker rejects malformed raw reservation output]"
  fi
  if jq '.name = "settled-sdd-design" | .required["docs/maxi/specs/0001-line-counter/plan.md"] = [] | .files["docs/maxi/specs/0001-line-counter/plan.md"] = "## Global Constraints\n- One rule.\n## Review Focus\n- Task 1 tests the risk.\n### Task 1: Implement\n- [ ] Step 1\n- [ ] Step 2\n- [ ] Step 3\n- [ ] Step 4\n- [ ] Step 5\n- [ ] Step 6\n"' "$sample" | jq -e -f "$CHECKER" >/dev/null; then
    echo "OK  [design checker: focus ends before direct Task heading]"
  else
    echo "FAIL [design checker: focus absorbs task body]" >&2
    failures=$((failures + 1))
  fi
  if jq '.sessions[0].events[1].payload.item |= (.cwd = "file:///fixture" | .command[2] = "bash ../installed/review/design-contract.sh reserve")' "$sample" | jq -e -f "$CHECKER" >/dev/null; then
    echo "OK  [design checker: exact relative installed reservation helper]"
  else
    echo "FAIL [design checker: exact relative installed reservation helper]" >&2
    failures=$((failures + 1))
  fi
  if jq '.name = "review-only" | .outcome = "stopped" | .files["docs/maxi/specs/0001-line-counter/reviews/design-review.md"] |= (gsub("phase: approved"; "phase: stopped") | gsub("VERDICT: approved"; "VERDICT: rejected")) | .sessions[1].events = [.sessions[1].events[0]] | .cli += [{"type":"item.completed","item":{"type":"agent_message","text":"Everything is approved and complete."}}]' "$sample" | jq -e -f "$CHECKER" | jq -e '.result == "stopped"' >/dev/null; then
    echo "OK  [design checker: stopped is never approved by untrusted prose, even without reviewer terminal]"
  else
    echo "FAIL [design checker: stopped confused with approved]" >&2
    failures=$((failures + 1))
  fi
  while IFS= read -r mutation; do
    [ -n "$mutation" ] || continue
    if jq "$mutation" "$sample" | jq -e -f "$CHECKER" >/dev/null 2>&1; then
      echo "FAIL [design checker accepted: $mutation]" >&2
      failures=$((failures + 1))
    else
      echo "OK  [design checker rejects: $mutation]"
    fi
  done <<'MUTATIONS'
.cli += [{"type":"item.completed","item":{"type":"agent_message","text":"Which output format?"}}]
.files["docs/design.md"] = "duplicate"
.sessions[0].events += [.sessions[0].events[1], .sessions[0].events[1]]
.changes += ["counter.py"]
.sessions[0].events = []
.verified = false | .cli += [{"type":"item.completed","item":{"type":"agent_message","text":"Everything is approved and complete."}}]
.sessions[0].events += [{"type":"response_item","payload":{"type":"function_call","name":"spawn_agent","call_id":"unknown","arguments":"{\"task_name\":\"surprise\"}"}}]
.sessions[1].events = []
.sessions[0].events += [.sessions[0].events[4], .sessions[0].events[4]]
.sessions[0].events[0].payload.item.command[2] = "cat /installed/{plan,unknown}/SKILL.md"
.sessions[0].events[0].payload.item.command[2] = "cat /installed/{plan,clarify*}/SKILL.md"
.sessions[0].events[0].payload.item.command[2] = "cat /installed/{plan,unknown}/SKILL.md; cat unrelated.txt"
.sessions[0].events[0].payload.item.command[2] = "cat /installed/{plan,clarify}/SKILL.md;evil"
.sessions[0].events[0].payload.item.aggregated_output = ""
.sessions[0].events[1].payload.item.command[2] |= sub(" reserve"; " verify")
.sessions[0].events[1].payload.item |= (.cwd = "file:///wrong/fixture" | .command[2] = "bash ../installed/review/design-contract.sh reserve")
.sessions[0].events[1].payload.item |= (.cwd = "file:///fixture" | .command[2] = "bash ../other/review/design-contract.sh reserve")
.sessions[0].events[1].payload.item |= (.command[2] = "bash ../installed/review/design-contract.sh reserve")
.sessions[1].events |= map(select(.payload.type != "task_complete"))
.sessions[1].events |= map(select(.payload.item.type != "AgentMessage"))
.sessions[1].events[-1].payload.last_agent_message = "VERDICT: rejected"
.sessions[1].events[-2].payload.completed_at_ms = null
.outcome = "stopped" | .cli += [{"type":"item.completed","item":{"type":"agent_message","text":"VERDICT: approved"}}]
.outcome = "stopped" | .files["docs/maxi/specs/0001-line-counter/reviews/design-review.md"] |= (gsub("phase: approved"; "phase: stopped") | gsub("VERDICT: approved"; "VERDICT: rejected"))
del(.outcome)
.sessions[1].agent = "/root/other"
.sessions[1].events[-1].payload.turn_id = "other-turn"
.sessions[1].events[-1].payload.type = "unknown_terminal"
.sessions[1].events[-1].payload.last_agent_message = "VERDICT: rejected" | .sessions[1].events[-2].payload.item.content[0].text = "VERDICT: rejected"
.files["docs/maxi/specs/0001-line-counter/reviews/design-review.md"] |= gsub("VERDICT: approved"; "VERDICT: rejected")
.outcome = "stopped" | .files["docs/maxi/specs/0001-line-counter/reviews/design-review.md"] |= (gsub("phase: approved"; "phase: stopped") | gsub("VERDICT: approved"; "VERDICT: rejected")) | .cli += [{"type":"item.completed","item":{"type":"agent_message","text":"VERDICT: approved"}}]
MUTATIONS
fi

summary_and_exit "integration harness checks"
