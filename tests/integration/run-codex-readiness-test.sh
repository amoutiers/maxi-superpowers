#!/usr/bin/env bash
# Exercise the tasked -> analyzed readiness lifecycle in an isolated Git fixture.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
OUTPUT_ROOT="$ROOT/.superpowers/sdd/integration"
USER_CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
TIMESTAMP=$(date +%Y%m%d%H%M%S)
OUTPUT_DIR="$OUTPUT_ROOT/$TIMESTAMP-$$/readiness"
FIXTURE="$OUTPUT_DIR/fixture"
SPEC_DIR="$FIXTURE/docs/maxi/specs/0001-readiness-integration"
LOG_FILE="$OUTPUT_DIR/codex-output.jsonl"
ISOLATED_CODEX_HOME="$OUTPUT_DIR/codex-home"
MARKETPLACE_NAME="maxi-superpowers"
PLUGIN_NAME="maxi"
MARKETPLACE_DIR="$ISOLATED_CODEX_HOME/marketplace"
PLUGIN_DIR="$MARKETPLACE_DIR/plugins/$PLUGIN_NAME"
MARKETPLACE_LOG="$OUTPUT_DIR/plugin-install.log"
INSTALLED_ANALYZE_DIR=""
TIMEOUT_SECONDS=300
TIMEOUT_GRACE_SECONDS=5

run_codex_with_deadline() {
  local output_file="$1"
  shift

  perl "$ROOT/tests/integration/run-with-deadline.pl" \
    "$TIMEOUT_SECONDS" "$TIMEOUT_GRACE_SECONDS" -- "$@" >> "$output_file" 2>&1
}

if [ ! -f "$USER_CODEX_HOME/auth.json" ]; then
  echo "ERROR: Codex authentication file not found" >&2
  exit 1
fi

mkdir -p "$SPEC_DIR" "$ISOLATED_CODEX_HOME"
trap 'rm -rf "$ISOLATED_CODEX_HOME"' EXIT

ln -s "$USER_CODEX_HOME/auth.json" "$ISOLATED_CODEX_HOME/auth.json"
mkdir -p "$PLUGIN_DIR" "$MARKETPLACE_DIR/.agents/plugins"
cp -R "$ROOT/.codex-plugin" "$PLUGIN_DIR/.codex-plugin"
cp -R "$ROOT/skills" "$PLUGIN_DIR/skills"
cp "$ROOT/.agents/plugins/marketplace.json" "$MARKETPLACE_DIR/.agents/plugins/marketplace.json"

cat > "$FIXTURE/docs/maxi/constitution.md" <<'EOF'
# Constitution

- Implementation changes MUST include applicable tests.
- Maxi pipeline phases MUST not be skipped.
EOF

cat > "$SPEC_DIR/spec.md" <<'EOF'
---
slug: 0001-readiness-integration
created: 2026-08-30
updated: 2026-08-30
status: tasked
---

# Fixture spec

Requirement A, including its applicable test.
EOF

cat > "$SPEC_DIR/plan.md" <<'EOF'
---
slug: 0001-readiness-integration
spec_slug: 0001-readiness-integration
created: 2026-08-30
updated: 2026-08-30
---

# Plan

Implement requirement A and its applicable test.
EOF

cat > "$SPEC_DIR/tasks.md" <<'EOF'
---
description: Fixture tasks
slug: 0001-readiness-integration
spec_slug: 0001-readiness-integration
created: 2026-08-30
updated: 2026-08-30
---

- [ ] T001 Implement requirement A and its applicable test
EOF

git -C "$FIXTURE" init -q
git -C "$FIXTURE" add docs
git -C "$FIXTURE" -c user.name='Maxi Integration' -c user.email='integration@example.invalid' \
  commit -qm 'test: seed readiness fixture'

export CODEX_HOME="$ISOLATED_CODEX_HOME"

echo "=== Readiness Lifecycle Test ==="
echo "Output dir: $OUTPUT_DIR"
echo ""
echo "Installing local plugin snapshot ..."
: > "$MARKETPLACE_LOG"
if run_codex_with_deadline "$MARKETPLACE_LOG" codex plugin marketplace add "$MARKETPLACE_DIR"; then
  :
else
  CODEX_STATUS=$?
  echo "ERROR: failed to add local marketplace. See $MARKETPLACE_LOG" >&2
  exit "$CODEX_STATUS"
fi
if run_codex_with_deadline "$MARKETPLACE_LOG" codex plugin add "$PLUGIN_NAME@$MARKETPLACE_NAME"; then
  :
else
  CODEX_STATUS=$?
  echo "ERROR: failed to install local plugin. See $MARKETPLACE_LOG" >&2
  exit "$CODEX_STATUS"
fi

INSTALLED_ANALYZE_SKILL=$(find "$ISOLATED_CODEX_HOME/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME" \
  -type f -path '*/skills/analyze/SKILL.md' -print -quit)
if [ -z "$INSTALLED_ANALYZE_SKILL" ]; then
  echo "ERROR: installed analyze snapshot not found. See $MARKETPLACE_LOG" >&2
  exit 1
fi
INSTALLED_ANALYZE_DIR=$(dirname "$INSTALLED_ANALYZE_SKILL")
if ! cmp -s "$ROOT/skills/analyze/SKILL.md" "$INSTALLED_ANALYZE_DIR/SKILL.md"; then
  echo "ERROR: installed analyze skill differs from this worktree" >&2
  exit 1
fi
if ! cmp -s "$ROOT/skills/analyze/readiness-contract.sh" \
  "$INSTALLED_ANALYZE_DIR/readiness-contract.sh"; then
  echo "ERROR: installed readiness verifier differs from this worktree" >&2
  exit 1
fi

SOURCE_STATE_BEFORE=$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)
SOURCE_HEAD_BEFORE=$(git -C "$ROOT" rev-parse HEAD)

echo "Running codex exec ..."
: > "$LOG_FILE"
if run_codex_with_deadline "$LOG_FILE" \
  codex exec --ephemeral --json --sandbox workspace-write --cd "$FIXTURE" \
  "Run /maxi:analyze for 0001-readiness-integration. Complete the readiness review and its allowed status transition. Do not implement or commit anything."; then
  CODEX_STATUS=0
else
  CODEX_STATUS=$?
fi
SOURCE_STATE_AFTER=$(git -C "$ROOT" status --porcelain=v1 --untracked-files=all)
SOURCE_HEAD_AFTER=$(git -C "$ROOT" rev-parse HEAD)

echo ""
echo "=== Results ==="

if [ "$SOURCE_HEAD_AFTER" != "$SOURCE_HEAD_BEFORE" ] || \
   [ "$SOURCE_STATE_AFTER" != "$SOURCE_STATE_BEFORE" ]; then
  echo "FAIL: source worktree changed during readiness lifecycle" >&2
elif [ "$CODEX_STATUS" -ne 0 ]; then
  echo "FAIL: Codex exited with status $CODEX_STATUS" >&2
  echo "Log: $LOG_FILE"
  exit "$CODEX_STATUS"
elif ! grep -Fq '"type":"turn.completed"' "$LOG_FILE"; then
  echo "FAIL: Codex did not complete its turn" >&2
elif grep -Fq '"type":"turn.failed"' "$LOG_FILE"; then
  echo "FAIL: Codex reported a failed turn" >&2
elif grep -Fq 'failed to load plugin' "$LOG_FILE"; then
  echo "FAIL: Codex failed to load the local plugin" >&2
elif ! grep -q '^status: analyzed$' "$SPEC_DIR/spec.md"; then
  echo "FAIL: readiness lifecycle did not reach status: analyzed" >&2
elif ! bash "$INSTALLED_ANALYZE_DIR/readiness-contract.sh" verify \
  "$SPEC_DIR/analysis.md" \
  "$SPEC_DIR/spec.md" \
  "$SPEC_DIR/plan.md" \
  "$SPEC_DIR/tasks.md"; then
  echo "FAIL: installed readiness verifier rejected analysis.md" >&2
else
  echo "PASS: readiness lifecycle"
  echo "Log: $LOG_FILE"
  exit 0
fi

echo "Log: $LOG_FILE"
exit 1
