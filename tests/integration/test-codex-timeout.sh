#!/usr/bin/env bash
# Exercises the portable Codex deadline with a local fake CLI.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
SOURCE_RUNNER="$ROOT/tests/integration/run-codex-trigger-test.sh"
DEADLINE_RUNNER="$ROOT/tests/integration/run-with-deadline.pl"
PROMPT_FILE="$ROOT/tests/integration/prompts/board.txt"
TEST_ROOT="$ROOT/.superpowers/sdd/integration-timeout-test-$$"
FAKE_BIN="$TEST_ROOT/bin"
TEST_RUNNER="$TEST_ROOT/run-codex-trigger-test.sh"

cleanup() {
  rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

if [ ! -x "$DEADLINE_RUNNER" ]; then
  echo "FAIL: deadline supervisor is missing or not executable: $DEADLINE_RUNNER" >&2
  exit 1
fi

mkdir -p "$FAKE_BIN"

cat > "$FAKE_BIN/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

emit_success() {
  repo_root=$(git rev-parse --show-toplevel)
  installed_skill_path="$CODEX_HOME/plugins/cache/maxi-superpowers/maxi/2.2.0/skills/board/SKILL.md"
  relative_skill_path="${installed_skill_path#"$repo_root/"}"
  printf '\0Codex diagnostic prefix\n'
  printf '{"type":"item.completed","item":{"type":"command_execution","command":"cat %s","aggregated_output":"---\\nname: board\\n---\\n","exit_code":0,"status":"completed"}}\n' "$relative_skill_path"
  printf '{"type":"turn.completed"}\n'
}

emit_insufficient_proof() {
  repo_root=$(git rev-parse --show-toplevel)
  installed_skill_path="$CODEX_HOME/plugins/cache/maxi-superpowers/maxi/2.2.0/skills/board/SKILL.md"
  relative_skill_path="${installed_skill_path#"$repo_root/"}"
  printf '{"type":"item.completed","item":{"type":"command_execution","command":"echo %s","aggregated_output":"not the skill","exit_code":0,"status":"completed"}}\n' "$relative_skill_path"
  printf '{"type":"turn.completed"}\n'
}

case "${1:-}" in
  plugin)
    if [ "${2:-}" = "add" ]; then
      if [ "${FAKE_CODEX_INSTALL_MODE:-success}" = "ignore-term" ]; then
        trap '' TERM
        while :; do :; done
      fi
      cache_dir="$CODEX_HOME/plugins/cache/maxi-superpowers/maxi/2.2.0"
      mkdir -p "$cache_dir"
      cp -R "$CODEX_HOME/marketplace/plugins/maxi/." "$cache_dir"
    fi
    ;;
  exec)
    case "${FAKE_CODEX_MODE:?}" in
      success)
        emit_success
        ;;
      insufficient-proof)
        emit_insufficient_proof
        ;;
      ignore-term)
        trap '' TERM
        while :; do :; done
        ;;
      term-nonzero)
        trap 'exit 7' TERM
        while :; do :; done
        ;;
      group-ignores-term)
        trap '' TERM
        (
          trap '' TERM
          end_time=$(($(date +%s) + 8))
          while [ "$(date +%s)" -lt "$end_time" ]; do
            printf 'alive\n' >> "$FAKE_DESCENDANT_HEARTBEAT"
            sleep 1
          done
        ) &
        while :; do :; done
        ;;
      boundary-success)
        trap 'emit_success; exit 0' TERM
        while :; do :; done
        ;;
      *)
        echo "unknown fake mode: $FAKE_CODEX_MODE" >&2
        exit 2
        ;;
    esac
    ;;
esac
EOF
chmod +x "$FAKE_BIN/codex"

sed \
  -e 's/TIMEOUT_SECONDS=300/TIMEOUT_SECONDS=3/' \
  -e 's/TIMEOUT_GRACE_SECONDS=5/TIMEOUT_GRACE_SECONDS=1/' \
  -e 's|^OUTPUT_ROOT=.*|OUTPUT_ROOT="${MAXI_TIMEOUT_TEST_OUTPUT_ROOT:?}"|' \
  "$SOURCE_RUNNER" > "$TEST_RUNNER"
chmod +x "$TEST_RUNNER"

run_case() {
  case_name="$1"
  mode="$2"
  install_mode="$3"
  expected_status="$4"
  expected_text="$5"
  max_elapsed="$6"
  case_root="$TEST_ROOT/$case_name"
  output_file="$case_root/output.txt"
  start_time=$(date +%s)

  mkdir -p "$case_root/user-codex"
  : > "$case_root/user-codex/auth.json"

  set +e
  PATH="$FAKE_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
    CODEX_HOME="$case_root/user-codex" \
    FAKE_CODEX_MODE="$mode" \
    FAKE_CODEX_INSTALL_MODE="$install_mode" \
    FAKE_DESCENDANT_HEARTBEAT="$case_root/descendant-heartbeat" \
    MAXI_TIMEOUT_TEST_OUTPUT_ROOT="$case_root/output" \
    "$TEST_RUNNER" board "$PROMPT_FILE" > "$output_file" 2>&1
  status=$?
  set -e

  elapsed=$(($(date +%s) - start_time))
  if [ "$status" -ne "$expected_status" ]; then
    cat "$output_file" >&2
    echo "FAIL [$case_name]: expected status $expected_status, got $status" >&2
    exit 1
  fi
  if ! grep -Fq "$expected_text" "$output_file"; then
    cat "$output_file" >&2
    echo "FAIL [$case_name]: missing '$expected_text'" >&2
    exit 1
  fi
  if [ "$elapsed" -gt "$max_elapsed" ]; then
    cat "$output_file" >&2
    echo "FAIL [$case_name]: portable watchdog took ${elapsed}s" >&2
    exit 1
  fi
  echo "PASS [$case_name]: status=$status elapsed=${elapsed}s"
}

assert_descendant_stopped() {
  heartbeat="$TEST_ROOT/process-group/descendant-heartbeat"
  sleep 1
  first_size=$(wc -c < "$heartbeat")
  sleep 2
  second_size=$(wc -c < "$heartbeat")
  if [ "$first_size" -ne "$second_size" ]; then
    echo "FAIL [process-group]: Codex descendant survived the deadline" >&2
    exit 1
  fi
  echo "PASS [process-group]: descendants stopped with their Codex process group"
}

# The bound starts before the material plugin staging, which can take several
# seconds on a loaded macOS filesystem. Fifteen seconds still exposes a runner
# that falls back to an unbounded Codex invocation.
run_case "before-deadline" success success 0 "PASS: Skill 'board' was triggered from this worktree" 15
run_case "insufficient-proof" insufficient-proof success 1 "FAIL: Skill 'board' was NOT triggered from this worktree" 15
run_case "install-ignores-term" success ignore-term 124 "ERROR: failed to install local plugin" 15
run_case "ignores-term" ignore-term success 124 "FAIL: Codex exited with status 124" 15
run_case "term-nonzero" term-nonzero success 124 "FAIL: Codex exited with status 124" 15
run_case "process-group" group-ignores-term success 124 "FAIL: Codex exited with status 124" 15
assert_descendant_stopped
run_case "boundary-success" boundary-success success 0 "PASS: Skill 'board' was triggered from this worktree" 15

echo "All Codex timeout regression tests passed."
