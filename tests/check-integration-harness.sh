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
  assert_grep "$READINESS_HARNESS" 'git -C.*init' "readiness runner creates an isolated Git fixture"
  assert_grep "$READINESS_HARNESS" 'readiness-contract.sh.*verify' "readiness runner verifies stamped evidence"
  assert_grep "$READINESS_HARNESS" 'SOURCE_STATE_BEFORE' "readiness runner snapshots source state"
  assert_grep "$READINESS_HARNESS" 'SOURCE_STATE_AFTER' "readiness runner verifies source state"
  if awk '/^SOURCE_STATE_AFTER=/{ after = NR } /^echo "=== Results ==="$/{ results = NR } END { exit !(after && results && after < results) }' "$READINESS_HARNESS"; then
    echo "OK  [readiness runner snapshots final source state before result checks]"
  else
    echo "FAIL [readiness runner snapshots final source state before result checks]" >&2
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
