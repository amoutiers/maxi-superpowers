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

summary_and_exit "integration harness checks"
