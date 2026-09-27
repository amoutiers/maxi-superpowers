#!/usr/bin/env bash
# Retain a complete installed Codex upgrade session in an external Git fixture.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
PROBE="${1:-}"
[ "$#" -le 1 ] && { [ -z "$PROBE" ] || [ "$PROBE" = --probe-design ]; } || {
  echo 'Usage: run-codex-upgrade-test.sh [--probe-design]' >&2; exit 2;
}
command -v jq >/dev/null
command -v python3 >/dev/null
USER_CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
[ -f "$USER_CODEX_HOME/auth.json" ] || { echo 'ERROR: Codex auth missing' >&2; exit 1; }
if [ -z "$PROBE" ] && [ -n "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ]; then
  echo 'ERROR: source worktree must be clean' >&2; exit 1
fi
SOURCE_HEAD="$(git -C "$ROOT" rev-parse HEAD)"
OUTPUT="$ROOT/.superpowers/sdd/integration/$(date +%Y%m%d%H%M%S)-$$/upgrade"
mkdir -p "$OUTPUT"
RUNTIME="$(mktemp -d "${TMPDIR:-/tmp}/maxi-upgrade.XXXXXX")"
RUNTIME="$(cd "$RUNTIME" && pwd -P)"
printf '%s\n' "$RUNTIME" > "$OUTPUT/runtime-path.txt"
export CODEX_HOME="$RUNTIME/codex-home" PYTHONDONTWRITEBYTECODE=1
mkdir -p "$CODEX_HOME" "$RUNTIME/marketplace/plugins/maxi" \
  "$RUNTIME/marketplace/.agents/plugins" "$RUNTIME/pre-done-fixture" \
  "$RUNTIME/migration-pre-done-fixture"
mkdir -p "$RUNTIME/pre-done-fixture/.git" \
  "$RUNTIME/migration-pre-done-fixture/.git"
ln -s "$USER_CODEX_HOME/auth.json" "$CODEX_HOME/auth.json"
cp -R "$ROOT/.codex-plugin" "$ROOT/skills" "$RUNTIME/marketplace/plugins/maxi/"
cp "$ROOT/.agents/plugins/marketplace.json" \
  "$RUNTIME/marketplace/.agents/plugins/marketplace.json"
run_bounded() {
  local log="$1"; shift
  perl "$ROOT/tests/integration/run-with-deadline.pl" 900 5 -- "$@" \
    </dev/null > "$log" 2>&1
}
run_bounded "$OUTPUT/install-marketplace.log" codex plugin marketplace add "$RUNTIME/marketplace"
run_bounded "$OUTPUT/install-plugin.log" codex plugin add maxi@maxi-superpowers
INSTALLED="$(find "$CODEX_HOME/plugins/cache/maxi-superpowers/maxi" -type d -name skills -print)"
[ -d "$INSTALLED" ] && [ "$(printf '%s\n' "$INSTALLED" | wc -l | tr -d ' ')" -eq 1 ] || {
  echo 'ERROR: missing or ambiguous installed skills' >&2; exit 1;
}
diff -rq "$ROOT/skills" "$INSTALLED" > "$OUTPUT/installed-diff.txt"
cp -R "$INSTALLED" "$OUTPUT/installed-skills"

FIXTURE="$RUNTIME/fixture"
mkdir -p "$FIXTURE/docs/maxi"
cat > "$FIXTURE/docs/maxi/constitution.md" <<'EOF'
# Fixture constitution

Use the complete Maxi pipeline and installed skills. Keep two executable tasks
and review each task and the whole branch. Preserve native evidence and Git history.
EOF
cat > "$FIXTURE/AGENTS.md" <<'EOF'
# Fixture instructions

Use the installed Maxi plugin, not the source checkout. Work only in this external
fixture. This test's user requests authorize the stated local owner phases and
local Git commits. Never push, merge, or create a PR. Read the exact installed
owner SKILL.md before each phase. This fixture is already an isolated external
Git repository. Use its current dedicated branch in place for SDD; do not
create or move to another worktree.
EOF
printf '.superpowers/\n' > "$FIXTURE/.gitignore"
git -C "$FIXTURE" init -q -b main
git -C "$FIXTURE" config user.name 'Maxi Upgrade Test'
git -C "$FIXTURE" config user.email 'upgrade@example.invalid'
git -C "$FIXTURE" config commit.gpgsign false
git -C "$FIXTURE" add .
git -C "$FIXTURE" commit -qm 'seed upgrade fixture'
STAGES_FILE="$OUTPUT/stages.json"
printf '[]\n' > "$STAGES_FILE"
printf '{}\n' > "$OUTPUT/native-offsets.json"

collect_native() {
  local stage="$1" repo="$2" dir="$OUTPUT/stages/$1"
  python3 - "$CODEX_HOME/sessions" "$repo" "$OUTPUT/native-offsets.json" "$dir" <<'PY'
import json, pathlib, sys
sessions_root, fixture, offsets_path, output = map(pathlib.Path, sys.argv[1:])
offsets = json.loads(offsets_path.read_text())
sessions = []
native = output / 'native'
native.mkdir(parents=True, exist_ok=True)
for path in sessions_root.rglob('*.jsonl'):
    lines = path.read_text(errors='replace').splitlines()
    if not lines:
        continue
    try:
        meta = json.loads(lines[0])
    except json.JSONDecodeError:
        continue
    if meta.get('type') != 'session_meta' or meta.get('payload', {}).get('cwd') != str(fixture):
        continue
    key = str(path)
    old = offsets.get(key, 0)
    if old > len(lines):
        raise SystemExit('native session shrank')
    new = [json.loads(line) for line in lines[old:] if line.startswith('{')]
    if new:
        sessions.append({'agent': meta['payload'].get('agent_path') or '/root',
                         'cwd': str(fixture), 'events': new})
        (native / path.name).write_text('\n'.join(lines) + '\n')
    offsets[key] = len(lines)
(output / 'sessions.json').write_text(json.dumps(sessions))
offsets_path.write_text(json.dumps(offsets))
PY
}

run_stage() {
  local name="$1" prompt="$2" repo="${3:-$FIXTURE}" dir="$OUTPUT/stages/$1" code=0
  local writable="$RUNTIME/pre-done-fixture"
  [ "$name" = migration ] && writable="$RUNTIME/migration-pre-done-fixture"
  mkdir -p "$dir/snapshot"
  printf '%s\n' "$prompt" > "$dir/prompt.txt"
  if [ "$name" = design ] || [ "$name" = migration ]; then
    (cd "$repo"; run_bounded "$dir/raw.log" codex exec --json --sandbox workspace-write \
      --add-dir "$repo/.git" --add-dir "$writable" --add-dir "$writable/.git" \
      --cd "$repo" "$prompt") || code=$?
  else
    local roots="sandbox_workspace_write.writable_roots=[\"$repo/.git\",\"$writable\",\"$writable/.git\"]"
    (cd "$repo"; run_bounded "$dir/raw.log" codex exec resume --json -c "$roots" \
      "$THREAD" "$prompt") || code=$?
  fi
  tr -d '\000' < "$dir/raw.log" | awk '/^\{/' > "$dir/cli.jsonl"
  collect_native "$name" "$repo"
  if [ -d "$repo/docs" ]; then cp -R "$repo/docs" "$dir/snapshot/docs"; fi
  jq --arg name "$name" --argjson code "$code" '. + [{name:$name,exit_code:$code}]' \
    "$STAGES_FILE" > "$STAGES_FILE.tmp"
  mv "$STAGES_FILE.tmp" "$STAGES_FILE"
  [ "$code" -eq 0 ] && jq -se '
    ([.[] | select(.type == "thread.started")] | length) == 1 and
    ([.[] | select(.type == "turn.completed")] | length) == 1 and
    all(.[]; .type != "turn.failed" and .type != "error")' "$dir/cli.jsonl" >/dev/null || {
    echo "INCOMPLETE: $name; evidence: $dir" >&2; exit 1;
  }
}

DESIGN_PROMPT='Run /maxi:specify with slug 0001-upgrade. Build a tiny Python line counter in exactly two executable tasks: Task 1 writes and tests core.py with count_nonempty(text), where whitespace-only lines do not count; Task 2 writes and tests a separate line_counter.py CLI that imports core.py, reads one UTF-8 file path, prints its decimal count plus LF, and gives concise stderr plus nonzero exit for unreadable input. Task 2 does not edit core.py. No network, dependencies, UI, or configuration. All product choices and design are approved. Complete design validation through the real owners and independent design review. Include Review Focus for both tasks. Stop at planned status with a current approved design report. Do not extract tasks, analyze, implement, or commit during this turn. Work only in this fixture.'
run_stage design "$DESIGN_PROMPT"
THREAD="$(jq -r 'select(.type == "thread.started") | .thread_id' "$OUTPUT/stages/design/cli.jsonl")"
if [ "$PROBE" = --probe-design ]; then
  echo "PROBE: design stage captured at $OUTPUT"
  exit 3
fi

run_stage tasks 'Run /maxi:tasks for 0001-upgrade using the approved plan. Extract exactly T001 and T002 with canonical (plan Task 1) and (plan Task 2) mappings. Stop after task extraction. Do not analyze or implement.'
run_stage readiness 'Run /maxi:analyze for 0001-upgrade and obtain current readiness evidence. Stop before implementation. Do not edit source files.'
SPEC_DIR="$FIXTURE/docs/maxi/specs/0001-upgrade"
git -C "$FIXTURE" add docs
if ! git -C "$FIXTURE" diff --cached --quiet; then
  git -C "$FIXTURE" commit -qm 'record reviewed upgrade design and readiness'
fi
git -C "$FIXTURE" switch -qc upgrade-lifecycle
BASE="$(git -C "$FIXTURE" rev-parse HEAD)"
printf '%s\n' "$BASE" > "$OUTPUT/base.txt"
run_stage first-task 'Run /maxi:implement for 0001-upgrade with Superpowers subagent-driven development. Complete and independently review Task 1, commit its work, append its canonical annotated completion to the ordinary SDD ledger, and reconcile the Maxi T001 checkbox. This is an explicit user-requested pause: after Task 1 is durably reviewed and reconciled, stop this turn with Task 2 pending. Do not select or execute Task 2 or start final review yet. Report the exact first-task commit.'
PROJECTION="$(cat "$FIXTURE/.superpowers/sdd/active-0001-upgrade")"
WORKSPACE="$FIXTURE/.superpowers/sdd/$(basename "$PROJECTION" .md)"
cp "$WORKSPACE/progress.md" "$OUTPUT/stages/first-task/snapshot/progress.md"
git -C "$FIXTURE" rev-parse HEAD > "$OUTPUT/stages/first-task/snapshot/head.txt"
if ! grep -q '^status: implementing$' "$SPEC_DIR/spec.md" ||
   ! grep -q '^- \[x\] T001 ' "$SPEC_DIR/tasks.md" ||
   ! grep -q '^- \[ \] T002 ' "$SPEC_DIR/tasks.md" ||
   ! grep -Eq '^Task 1: complete \(commits [0-9a-f]{7}\.\.[0-9a-f]{7}, (review clean|[1-9][0-9]* parked)\)$' "$WORKSPACE/progress.md" ||
   [ "$(git -C "$FIXTURE" rev-parse HEAD)" = "$BASE" ]; then
  echo "INCOMPLETE: first-task; evidence: $OUTPUT/stages/first-task" >&2
  exit 1
fi
run_stage resume "Resume /maxi:implement for 0001-upgrade in this same Codex session. Execute only pending Task 2, independently review and reconcile it, then obtain the one fresh whole-branch final review over actual Git history. Supply that reviewer the full exact spec.md and plan.md, including Review Focus, and the real byte-exact review package; persist its actual identity, verdicts, any declined-behavior rulings, and terminal receipt. Write the receipt beside the active projection's progress.md with the exact filename terminal-receipt.md, using record-terminal.sh --output. Run the installed result-contract in a separate command and observe READY_TO_FINISH. Immediately after READY_TO_FINISH and before the implementing-to-done write, copy the complete physical fixture, including .git and ignored .superpowers evidence, into the prepared external directory $RUNTIME/pre-done-fixture using Python shutil.copytree with dirs_exist_ok=True. That directory contains only an empty .git subdirectory, and both it and its .git are authorized writable roots. Confirm the copied .git and .superpowers exist and copied Git HEAD matches. Then let implement persist done. After the done write, run one separate read-only command to print the status line from $SPEC_DIR/spec.md so the native order is observable. For finishing, the user chooses option 3: keep this dedicated branch and external fixture locally, with no merge, push, or PR. Carry out that Git closure flow and report the actual deliberately retained outcome. Do not replay Task 1 or edit core.py."
PROJECTION="$(cat "$FIXTURE/.superpowers/sdd/active-0001-upgrade")"
WORKSPACE="$FIXTURE/.superpowers/sdd/$(basename "$PROJECTION" .md)"
cp "$WORKSPACE/progress.md" "$OUTPUT/stages/resume/snapshot/progress.md"
cp "$WORKSPACE/terminal-receipt.md" "$OUTPUT/stages/resume/snapshot/receipt.md"

# This historical seed is fixture input, not a claimed new live reviewer verdict.
MIGRATION="$RUNTIME/migration-fixture"
MIG_DIR="$MIGRATION/docs/maxi/specs/adapter-sample"
mkdir -p "$MIG_DIR" "$MIGRATION/docs/maxi"
cp "$FIXTURE/docs/maxi/constitution.md" "$MIGRATION/docs/maxi/constitution.md"
cat > "$MIG_DIR/spec.md" <<'EOF'
---
slug: adapter-sample
created: 2026-09-27
updated: 2026-09-27
status: analyzed
design_cycle: 0
related_adrs: []
---
# Historical two-task implementation
EOF
cat > "$MIG_DIR/plan.md" <<'EOF'
# Historical plan

## Global Constraints

- Preserve the original Git task ranges.

## Review Focus

- Review both historical files in the original range.

### Task 1: First historical file

Create historical-1.txt.

### Task 2: Second historical file

Create historical-2.txt.
EOF
cat > "$MIG_DIR/tasks.md" <<'EOF'
---
spec_slug: adapter-sample
updated: 2026-09-27
---
- [ ] T001 First historical file (plan Task 1)
- [ ] T002 Second historical file (plan Task 2)
EOF
printf '# Readiness\n\nHistorical completed tasks are valid.\n' > "$MIG_DIR/readiness-candidate.md"
INPUTS="$(bash "$INSTALLED/review/review-inputs.sh" hash "$MIGRATION")"
bash "$INSTALLED/analyze/readiness-contract.sh" stamp \
  "$MIG_DIR/readiness-candidate.md" "$MIG_DIR/analysis.md" "$MIG_DIR/spec.md" \
  "$MIG_DIR/plan.md" "$MIG_DIR/tasks.md" pass 0 "$MIGRATION" "$INPUTS"
rm "$MIG_DIR/readiness-candidate.md"
printf '.superpowers/\n' > "$MIGRATION/.gitignore"
cat > "$MIGRATION/AGENTS.md" <<'EOF'
# Historical fixture instructions

This external Git repository is already isolated. Use the current dedicated
branch in place. Do not create another worktree, push, merge, or create a PR.
The original task commits and v1 projection are historical fixture inputs.
Only a fresh final review and receipt can qualify the v2 continuation.
EOF
git -C "$MIGRATION" init -q -b main
git -C "$MIGRATION" config user.name 'Maxi Upgrade Test'
git -C "$MIGRATION" config user.email 'upgrade@example.invalid'
git -C "$MIGRATION" config commit.gpgsign false
git -C "$MIGRATION" add .
git -C "$MIGRATION" commit -qm 'historical fixture base'
MIG_BASE="$(git -C "$MIGRATION" rev-parse HEAD)"
MIG_PREV="$MIG_BASE"
MIG_LINES="$OUTPUT/migration-completions.txt"
: > "$MIG_LINES"
for task in 1 2; do
  printf 'historical %s\n' "$task" > "$MIGRATION/historical-$task.txt"
  git -C "$MIGRATION" add "historical-$task.txt"
  git -C "$MIGRATION" commit -qm "historical task $task"
  MIG_NOW="$(git -C "$MIGRATION" rev-parse HEAD)"
  printf 'Task %s: complete (commits %s..%s, review clean)\n' \
    "$task" "${MIG_PREV:0:7}" "${MIG_NOW:0:7}" >> "$MIG_LINES"
  MIG_PREV="$MIG_NOW"
done
MIG_HEAD="$MIG_PREV"
git -C "$MIGRATION" switch -qc upgrade-migration
MIG_OLD="$(bash "$ROOT/tests/fixtures/x-develop-adapter/emit-v1.sh" "$MIGRATION")"
MIG_OLD_LEDGER="$MIGRATION/.superpowers/sdd/$(basename "$MIG_OLD" .md)/progress.md"
cat "$MIG_LINES" >> "$MIG_OLD_LEDGER"
sed 's/^- \[ \]/- [x]/' "$MIG_DIR/tasks.md" > "$MIG_DIR/tasks.tmp"
mv "$MIG_DIR/tasks.tmp" "$MIG_DIR/tasks.md"
sed 's/^status: analyzed$/status: implementing/' "$MIG_DIR/spec.md" > "$MIG_DIR/spec.tmp"
mv "$MIG_DIR/spec.tmp" "$MIG_DIR/spec.md"
bash "$INSTALLED/analyze/readiness-contract.sh" verify \
  "$MIG_DIR/analysis.md" "$MIG_DIR/spec.md" "$MIG_DIR/plan.md" \
  "$MIG_DIR/tasks.md" "$MIGRATION" > "$OUTPUT/migration-readiness.txt"
[ "$(cat "$OUTPUT/migration-readiness.txt")" = READINESS_VERIFIED ]
python3 - "$MIGRATION" <<'PY'
from pathlib import Path
import subprocess
import sys

root = Path(sys.argv[1])
spec_dir = Path('docs/maxi/specs/adapter-sample')
analysis = str(spec_dir / 'analysis.md')
subprocess.run(['git', '-C', str(root), 'ls-files', '--error-unmatch', analysis],
               check=True, stdout=subprocess.DEVNULL)
assert not (root / spec_dir / 'readiness-candidate.md').exists()
status = subprocess.check_output(['git', '-C', str(root), 'status',
                                  '--porcelain=v1', '-z', '--untracked-files=all'])
assert set(status.decode().rstrip('\0').split('\0')) == {
    ' M ' + str(spec_dir / 'spec.md'),
    ' M ' + str(spec_dir / 'tasks.md'),
}, status
PY
run_stage migration 'Run /maxi:implement for the analyzed, already-completed historical adapter-sample. The v1 projection and its two completion records are seeded fixture inputs backed by genuine original Git commits. Upgrade through the installed project-tasks helper to an empty v2 successor. Do not reexecute historical tasks. Obtain a fresh actual independent whole-branch final review of the original nonempty Git range, supplying the reviewer complete exact spec and plan including Review Focus plus the review package. Persist actual identity/verdict and a new terminal receipt beside the active projection progress.md with the exact filename terminal-receipt.md, using record-terminal.sh --output. Then run the installed result-contract in a separate shell command containing only the verifier invocation, and report its actual READY_TO_FINISH output. This user-requested boundary stops before writing done or invoking branch finishing; leave spec status implementing so the runner can independently revalidate the receipt.' "$MIGRATION"

python3 - "$ROOT" "$OUTPUT" "$RUNTIME" "$INSTALLED" "$FIXTURE" "$MIGRATION" "$BASE" "$MIG_BASE" "$MIG_HEAD" "$MIG_OLD" "$MIG_OLD_LEDGER" <<'PY'
import importlib.util, json, pathlib, re, subprocess, sys
root, output, runtime, installed, fixture, migration = map(pathlib.Path, sys.argv[1:7])
base, migration_base, migration_head = sys.argv[7:10]
migration_old, migration_old_ledger = map(pathlib.Path, sys.argv[10:12])
module_path = root / 'tests/integration/upgrade-cases/check-evidence.py'
spec = importlib.util.spec_from_file_location('upgrade_checker', module_path)
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)
def head(repo, ref):
    return subprocess.check_output(['git', '-C', str(repo), 'rev-parse', '--verify',
                                    f'{ref}^{{commit}}'], text=True).strip()
def read_stage(name):
    return json.loads((output / 'stages' / name / 'sessions.json').read_text())
projection = pathlib.Path((fixture / '.superpowers/sdd/active-0001-upgrade').read_text().strip())
workspace = fixture / '.superpowers/sdd' / projection.stem
ledger = workspace / 'progress.md'
lines = ledger.read_text()
endpoints = []
for number in (1, 2):
    matches = re.findall(rf'(?m)^Task {number}: complete \(commits ([a-f0-9]{{7}})\.\.([a-f0-9]{{7}}), (?:review clean|[1-9][0-9]* parked)\)$', lines)
    if len(matches) != 1:
        raise ValueError(f'missing canonical Task {number} completion')
    endpoints.append(tuple(head(fixture, ref) for ref in matches[0]))
if endpoints[0][0] != base or endpoints[1][0] != endpoints[0][1]:
    raise ValueError('task completion history is discontinuous')
receipt = workspace / 'terminal-receipt.md'
final_review = workspace / 'maxi-final-review.md'
postturn = checker.run_boundary_verifier(
    fixture, runtime / 'pre-done-fixture', installed,
    fixture / 'docs/maxi/specs/0001-upgrade/tasks.md', receipt, root)
migration_projection = pathlib.Path((migration / '.superpowers/sdd/active-adapter-sample').read_text().strip())
migration_workspace = migration / '.superpowers/sdd' / migration_projection.stem
migration_receipt = migration_workspace / 'terminal-receipt.md'
migration_report = migration_workspace / 'maxi-final-review.md'
design_report = fixture / 'docs/maxi/specs/0001-upgrade/reviews/design-review.md'
operations = re.findall(r'<!-- maxi-design-operation-v1\n(.*?)\n-->',
                        design_report.read_text(), flags=re.S)
design_match = re.findall(r'(?m)^reviewer: (\S+)$', operations[0]) if operations else []
if len(design_match) != 1:
    raise ValueError('missing managed design reviewer identity')
evidence = {
    'version': 1, 'source_skills': str(root / 'skills'), 'installed': str(installed),
    'fixture': str(fixture), 'base': base, 'first': endpoints[0][1],
    'head': endpoints[1][1], 'projection': str(projection), 'ledger': str(ledger),
    'receipt': str(receipt), 'final_review': str(final_review),
    'tasks': str(fixture / 'docs/maxi/specs/0001-upgrade/tasks.md'),
    'context': checker.field(receipt, 'reviewer_context'),
    'design_context': design_match[0],
    'pre_done_fixture': str(runtime / 'pre-done-fixture'),
    'postturn_verifier': postturn,
    'task_reviews': [
        checker.collect_task_review(read_stage('first-task'), 'first-task',
                                    fixture, workspace, *endpoints[0]),
        checker.collect_task_review(read_stage('resume'), 'resume',
                                    fixture, workspace, *endpoints[1]),
    ],
    'migration': {
        'fixture': str(migration), 'base': migration_base, 'head': migration_head,
        'old_projection': str(migration_old), 'old_ledger': str(migration_old_ledger),
        'projection': str(migration_projection), 'ledger': str(migration_workspace / 'progress.md'),
        'receipt': str(migration_receipt), 'final_review': str(migration_report),
        'context': checker.field(migration_receipt, 'reviewer_context'),
        'tasks': str(migration / 'docs/maxi/specs/adapter-sample/tasks.md'),
        'pre_done_fixture': str(runtime / 'migration-pre-done-fixture'),
    },
    'stages': json.loads((output / 'stages.json').read_text()),
}
(output / 'evidence.json').write_text(json.dumps(evidence, indent=2) + '\n')
PY
python3 "$ROOT/tests/integration/upgrade-cases/check-evidence.py" "$OUTPUT" > "$OUTPUT/result.json"
if [ "$(git -C "$ROOT" rev-parse HEAD)" != "$SOURCE_HEAD" ] || \
   [ -n "$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)" ]; then
  echo "INCOMPLETE: source worktree changed; evidence: $OUTPUT" >&2
  exit 1
fi
echo "PASS: installed upgrade lifecycle; evidence: $OUTPUT"
