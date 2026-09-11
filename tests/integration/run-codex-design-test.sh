#!/usr/bin/env bash
# Live installed-owner behavior. Runtime homes/fixtures remain outside ancestor AGENTS.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
CASE_GROUP="${1:-all}"
[ "$#" -le 1 ] || exit 2
command -v jq >/dev/null || { echo 'ERROR: jq required' >&2; exit 1; }
CASES="$ROOT/tests/integration/design-cases/cases.json"
case "$CASE_GROUP" in
  initial|revision|boundaries|all) ;;
  *) jq -e --arg name "$CASE_GROUP" 'any(.[]; .name == $name)' "$CASES" >/dev/null || {
    echo 'Usage: run-codex-design-test.sh [initial|revision|boundaries|all|case-name]' >&2
    exit 2
  };;
esac
USER_CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
[ -f "$USER_CODEX_HOME/auth.json" ] || { echo 'ERROR: Codex authentication file not found' >&2; exit 1; }
SOURCE_HEAD_BEFORE=$(git -C "$ROOT" rev-parse HEAD)
[ -z "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ] || { echo 'ERROR: source worktree must be clean' >&2; exit 1; }
OUTPUT_DIR="$ROOT/.superpowers/sdd/integration/$(date +%Y%m%d%H%M%S)-$$/design-$CASE_GROUP"
mkdir -p "$OUTPUT_DIR"
RUNTIME=$(mktemp -d "${TMPDIR:-/tmp}/maxi-design.XXXXXX")
RUNTIME="$(cd "$RUNTIME" && pwd -P)"
# Preserve fixtures, sessions and snapshots for inspection, including failed runs.
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
  perl "$ROOT/tests/integration/run-with-deadline.pl" 600 5 -- "$@" </dev/null >> "$log" 2>&1
}
run_codex_with_deadline "$OUTPUT_DIR/install.log" codex plugin marketplace add "$RUNTIME/marketplace"
run_codex_with_deadline "$OUTPUT_DIR/install.log" codex plugin add maxi@maxi-superpowers
INSTALLED=$(find "$CODEX_HOME/plugins/cache/maxi-superpowers/maxi" -type d -name skills -print)
[ -d "$INSTALLED" ] || { echo 'ERROR: ambiguous/missing installed skills' >&2; exit 1; }
diff -rq "$ROOT/skills" "$INSTALLED" > "$OUTPUT_DIR/installed-diff.txt"
printf '{}\n' > "$OUTPUT_DIR/installed.json"
while IFS= read -r file; do
  jq --arg path "$file" --rawfile content "$file" '. + {($path):$content}' "$OUTPUT_DIR/installed.json" > "$OUTPUT_DIR/installed.tmp"
  mv "$OUTPUT_DIR/installed.tmp" "$OUTPUT_DIR/installed.json"
done < <(find "$INSTALLED" -type f \( -name SKILL.md -o -path "$INSTALLED/specify/spec-author.md" \))
HELPER="$INSTALLED/review/design-contract.sh"
printf '%s\n' "$SOURCE_HEAD_BEFORE" > "$OUTPUT_DIR/source-head.txt"
cp -R "$INSTALLED" "$OUTPUT_DIR/installed-skills"
FAILED=0
while IFS= read -r name; do
  DIR="$OUTPUT_DIR/$name"
  FIXTURE="$RUNTIME/$name"
  mkdir -p "$DIR" "$FIXTURE/docs/maxi"
  jq --arg name "$name" '.[] | select(.name == $name)' "$CASES" > "$DIR/case.json"
  printf '%s\n' "$FIXTURE" > "$DIR/fixture-path.txt"
  printf '# Constitution\n\nUse the Maxi phases and applicable tests. Delegate to Superpowers when it provides the capability. Preserve canonical artifacts and lifecycle gates.\n' > "$FIXTURE/docs/maxi/constitution.md"
  if jq -e '.seeded' "$DIR/case.json" >/dev/null; then
    while IFS= read -r path; do
      mkdir -p "$(dirname "$FIXTURE/$path")"
      jq -rj --arg path "$path" '.[$path]' "$ROOT/tests/integration/design-cases/seed.json" > "$FIXTURE/$path"
    done < <(jq -r 'keys[]' "$ROOT/tests/integration/design-cases/seed.json")
  else
    # Real minimal source is present before design; agents may inspect but not implement it.
    printf '# Future line counter; design work must leave this file untouched.\n' > "$FIXTURE/counter.py"
  fi
  SPEC_DIR="$FIXTURE/docs/maxi/specs/0001-line-counter"
  status=$(jq -r '.status // ""' "$DIR/case.json")
  case "$status" in
    parked|cancelled) sed -i.bak "s/status: planned/status: $status/" "$SPEC_DIR/spec.md"; rm "$SPEC_DIR/spec.md.bak";;
    reopened) sed -i.bak 's/status: planned/status: done/' "$SPEC_DIR/spec.md"; rm "$SPEC_DIR/spec.md.bak";;
    missing) rm "$SPEC_DIR/reviews/design-review.md";;
  esac
  git -C "$FIXTURE" init -q
  git -C "$FIXTURE" add .
  git -C "$FIXTURE" -c user.name='Maxi Integration' -c user.email='integration@example.invalid' commit -qm 'test: seed design fixture'
  FIXTURE_HEAD_BEFORE=$(git -C "$FIXTURE" rev-parse HEAD)
  printf '%s\n' "$FIXTURE_HEAD_BEFORE" > "$DIR/fixture-head.txt"
  jq -r '.prompt' "$DIR/case.json" > "$DIR/prompt.txt"
  start=$(date +%s)
  code=0
  (cd "$FIXTURE"; run_codex_with_deadline "$DIR/turn-0.jsonl" codex exec --json --sandbox workspace-write --cd "$FIXTURE" "$(cat "$DIR/prompt.txt")") || code=$?
  # Require one explicit session ID. Never use --last or ephemeral sessions.
  tr -d '\000' < "$DIR/turn-0.jsonl" | awk '/^\{/' | jq -s '[.[] | select(.type == "thread.started") | .thread_id] | unique' > "$DIR/session-ids.json"
  if ! jq -e 'length == 1 and (.[0] | type == "string")' "$DIR/session-ids.json" >/dev/null; then code=1; fi
  if [ "$code" -eq 0 ]; then
    session_id=$(jq -r '.[0]' "$DIR/session-ids.json")
    turn=0
    while IFS= read -r answer; do
      # A scripted answer is only sent after the corresponding real question.
      if ! tr -d '\000' < "$DIR/turn-$turn.jsonl" | awk '/^\{/' | jq -se --argjson turn "$turn" '
        [.[] | select(.type == "item.completed" and .item.type == "agent_message") | .item.text] | join("\n") |
        test("\\?") and (if $turn == 0 then
          test("whitespace|space";"i") and test("path|stdin";"i") and test("JSON|text";"i")
          else test("key";"i") end)' >/dev/null; then
        code=1
        printf '%s\n' 'INCOMPLETE: expected product question was not observed; no scripted answer sent' > "$DIR/questions.log"
        break
      fi
      turn=$((turn + 1))
      # Fixed fixture answers are replayed in the same cwd/home/session.
      (cd "$FIXTURE"; run_codex_with_deadline "$DIR/turn-$turn.jsonl" codex exec resume --json "$session_id" "$answer") || { code=$?; break; }
    done < <(jq -r '.answers[]' "$DIR/case.json")
  fi
  elapsed=$(( $(date +%s) - start ))
  : > "$DIR/cli.jsonl"
  for log in "$DIR"/turn-*.jsonl; do tr -d '\000' < "$log" | awk '/^\{/' >> "$DIR/cli.jsonl"; done
  printf '[]\n' > "$DIR/sessions.json"
  while IFS= read -r session; do
    if jq -se --arg fixture "$FIXTURE" '.[0].type == "session_meta" and .[0].payload.cwd == $fixture' "$session" >/dev/null; then
      cp "$session" "$DIR/$(basename "$session")"
      jq -s '{agent:(.[0].payload.agent_path // "/root"), events:.}' "$session" > "$DIR/session.tmp"
      jq --slurpfile next "$DIR/session.tmp" '. + $next' "$DIR/sessions.json" > "$DIR/sessions.tmp"
      mv "$DIR/sessions.tmp" "$DIR/sessions.json"
    fi
  done < <(find "$CODEX_HOME/sessions" -type f -name '*.jsonl')
  { git -C "$FIXTURE" diff --name-only HEAD; git -C "$FIXTURE" ls-files --others --exclude-standard; } | sort -u | jq -Rsc 'split("\n") | map(select(length > 0))' > "$DIR/changes.json"
  printf '{}\n' > "$DIR/files.json"
  while IFS= read -r path; do
    [ -f "$FIXTURE/$path" ] || continue
    jq --arg path "$path" --rawfile content "$FIXTURE/$path" '. + {($path):$content}' "$DIR/files.json" > "$DIR/files.tmp"
    mv "$DIR/files.tmp" "$DIR/files.json"
  done < <(jq -nr --slurpfile c "$DIR/case.json" --slurpfile d "$DIR/changes.json" '$c[0].allowed + $d[0] | unique[]')
  verified=false; outcome=none
  if jq -e '.review' "$DIR/case.json" >/dev/null && [ -f "$SPEC_DIR/reviews/design-review.md" ]; then
    id=$(sed -n 's/^operation_id: //p' "$SPEC_DIR/reviews/design-review.md" | head -1)
    if bash "$HELPER" operation "$SPEC_DIR/reviews/design-review.md" "$SPEC_DIR/spec.md" "$SPEC_DIR/plan.md" "$FIXTURE" "$id" > "$DIR/operation.txt" 2>&1; then
      if grep -q '^phase: approved$' "$DIR/operation.txt"; then
        if bash "$HELPER" verify "$SPEC_DIR/reviews/design-review.md" "$SPEC_DIR/spec.md" "$SPEC_DIR/plan.md" "$FIXTURE" > "$DIR/verify.txt" 2>&1; then verified=true; outcome=approved; fi
      elif grep -q '^phase: stopped$' "$DIR/operation.txt"; then
        # A truthful bounded stop is valid behavior, never an approval.
        verified=true; outcome=stopped
      fi
    fi
  fi
  head_unchanged=false; source_unchanged=false
  [ "$(git -C "$FIXTURE" rev-parse HEAD)" != "$FIXTURE_HEAD_BEFORE" ] || head_unchanged=true
  if [ "$(git -C "$ROOT" rev-parse HEAD)" = "$SOURCE_HEAD_BEFORE" ] && [ -z "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ]; then source_unchanged=true; fi
  max_questions=0
  case "$name" in questions) max_questions=4;; parked|cancelled|missing-continuity) max_questions=1;; esac
  jq -n --slurpfile c "$DIR/case.json" --slurpfile cli "$DIR/cli.jsonl" --slurpfile sessions "$DIR/sessions.json" --slurpfile files "$DIR/files.json" --slurpfile changes "$DIR/changes.json" --slurpfile installed "$OUTPUT_DIR/installed.json" --arg helper "$HELPER" --arg outcome "$outcome" --argjson verified "$verified" --argjson head "$head_unchanged" --argjson source "$source_unchanged" --argjson code "$code" --argjson elapsed "$elapsed" --argjson max_questions "$max_questions" '$c[0] + {cli:$cli,sessions:$sessions[0],files:$files[0],changes:$changes[0],installed:$installed[0],helper:$helper,outcome:$outcome,verified:$verified,head_unchanged:$head,source_unchanged:$source,exit_code:$code,elapsed_seconds:$elapsed,max_questions:$max_questions}' > "$DIR/evidence.json"
  cp -R "$FIXTURE/docs" "$DIR/final-docs"
  git -C "$FIXTURE" diff HEAD > "$DIR/final.diff"
  if jq -e -f "$ROOT/tests/integration/assert-design-events.jq" "$DIR/evidence.json" > "$DIR/result.json" 2> "$DIR/assertions.log"; then
    echo "PASS: $name (${elapsed}s); evidence: $DIR"
  else
    FAILED=$((FAILED + 1))
    echo "FAIL/INCOMPLETE: $name (${elapsed}s, exit $code); evidence: $DIR"
    cat "$DIR/assertions.log"
  fi
 done < <(jq -r --arg group "$CASE_GROUP" '.[] | select($group == "all" or .group == $group or .name == $group) | .name' "$CASES")
echo "Design cases failed/incomplete: $FAILED; runtime preserved at $RUNTIME"
[ "$FAILED" -eq 0 ]
