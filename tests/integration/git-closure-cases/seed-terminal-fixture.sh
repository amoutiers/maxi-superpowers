#!/usr/bin/env bash
# Synthetic contract-valid terminal fixture, never a claim of live upstream review.
set -euo pipefail
FIXTURE="$1"
BASE="$2"
INSTALLED="$3"
SPEC_DIR="$FIXTURE/docs/maxi/specs/0001-fixture"
SPEC="$SPEC_DIR/spec.md"
PLAN="$SPEC_DIR/plan.md"
TASKS="$SPEC_DIR/tasks.md"
ANALYSIS="$SPEC_DIR/analysis.md"
mkdir -p "$FIXTURE/.superpowers/sdd/projections"
printf '# Synthetic fixture readiness, not a live readiness review.\n' > "$SPEC_DIR/readiness-candidate.md"
INPUTS="$(bash "$INSTALLED/review/review-inputs.sh" hash "$FIXTURE")"
bash "$INSTALLED/analyze/readiness-contract.sh" stamp \
  "$SPEC_DIR/readiness-candidate.md" "$ANALYSIS" "$SPEC" "$PLAN" "$TASKS" pass 0 "$FIXTURE" "$INPUTS"
rm "$SPEC_DIR/readiness-candidate.md"
git -C "$FIXTURE" add "$ANALYSIS"
git -C "$FIXTURE" commit -qm 'synthetic terminal readiness fixture'
PROJECTION="$(bash "$INSTALLED/x-develop/project-tasks.sh" --spec "$SPEC" --plan "$PLAN" \
  --tasks "$TASKS" --output "$FIXTURE/.superpowers/sdd/projections/requested.md" \
  --state-file "$FIXTURE/.superpowers/sdd/active-0001-fixture")"
WORKSPACE="$FIXTURE/.superpowers/sdd/$(basename "$PROJECTION" .md)"
LEDGER="$WORKSPACE/progress.md"
mkdir -p "$WORKSPACE"
printf '# SDD ledger \342\200\224 plan: %s\nMaxi selection: none\nMaxi projection SHA256: %s\n' \
  "$PROJECTION" "$(shasum -a 256 "$PROJECTION" | cut -d ' ' -f 1)" > "$LEDGER"
HEAD="$(git -C "$FIXTURE" rev-parse HEAD)"
(cd "$FIXTURE"; bash "$INSTALLED/subagent-driven-development/scripts/review-package" \
  "$PROJECTION" "$BASE" "$HEAD" "$WORKSPACE/review-full.diff" >/dev/null)
printf 'reviewer_context: /root/synthetic_fixture_reviewer\n' > "$WORKSPACE/final-reviewer-dispatch.identity"
sha() { shasum -a 256 "$1" | cut -d ' ' -f 1; }
cat > "$WORKSPACE/maxi-final-review.md" <<EOF
---
worktree: $FIXTURE
merge_base: $BASE
reviewed_head: $HEAD
reviewed_tree: $(git -C "$FIXTURE" rev-parse 'HEAD^{tree}')
projection: $PROJECTION
projection_sha256: $(sha "$PROJECTION")
full_review_package: $WORKSPACE/review-full.diff
full_review_package_sha256: $(sha "$WORKSPACE/review-full.diff")
fix_review_package: null
fix_review_package_sha256: null
spec: $SPEC
spec_sha256: $(sha "$SPEC")
tasks: $TASKS
tasks_sha256: $(sha "$TASKS")
reviewer_context: /root/synthetic_fixture_reviewer
outcome: finish
---

### Strengths
Synthetic fixture contract input only.

### Issues

#### Critical (Must Fix)
None.

#### Important (Should Fix)
None.

#### Minor (Nice to Have)
None.

### Recommendations
None.

### Assessment

**Ready to merge?** Yes

**Reasoning:** Synthetic fixture envelope for terminal contract verification.
EOF
bash "$INSTALLED/x-develop/record-terminal.sh" --worktree "$FIXTURE" --merge-base "$BASE" \
  --projection "$PROJECTION" --ledger "$LEDGER" --final-review "$WORKSPACE/maxi-final-review.md" \
  --spec "$SPEC" --tasks "$TASKS" --output "$WORKSPACE/terminal-receipt.md"
RESULT="$(bash "$INSTALLED/x-develop/result-contract.sh" --tasks "$TASKS" \
  --receipt "$WORKSPACE/terminal-receipt.md")"
printf '%s\n' "$RESULT" | grep -Fxq READY_TO_FINISH
printf '%s\n' "$WORKSPACE/terminal-receipt.md"
