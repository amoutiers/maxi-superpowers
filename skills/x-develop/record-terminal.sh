#!/usr/bin/env bash
# Record hash-bound evidence at the intercepted upstream Finish boundary.
set -euo pipefail

LC_ALL=C
export LC_ALL

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
PROJECT_HELPER="$SCRIPT_DIR/project-tasks.sh"
REVIEW_PACKAGE_HELPER="$SCRIPT_DIR/../subagent-driven-development/scripts/review-package"
[ -f "$PROJECT_HELPER" ] || { echo 'ERROR: projection helper is missing' >&2; exit 2; }
[ -f "$REVIEW_PACKAGE_HELPER" ] || { echo 'ERROR: upstream review-package helper is missing' >&2; exit 2; }

die() { echo "ERROR: $*" >&2; exit 2; }
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
under() { case "$1" in "$2"|"$2"/*) return 0 ;; *) return 1 ;; esac; }

canonical_file() {
  local path="$1" parent physical
  [ -f "$path" ] && [ ! -L "$path" ] || return 1
  parent="$(cd -P "$(dirname "$path")" 2>/dev/null && pwd)" || return 1
  physical="$parent/$(basename "$path")"
  [ "$path" = "$physical" ] || return 1
  printf '%s\n' "$physical"
}

field() {
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 { if ($0 == "---") fm = 1; next }
    fm && $0 == "---" { exit }
    fm && index($0, key ": ") == 1 { count++; value = substr($0, length(key) + 3) }
    END { if (count == 1) print value; else exit 1 }
  ' "$file"
}

valid_context() {
  local value="$1" lowered

  printf '%s\n' "$value" | grep -Eq '^[A-Za-z][A-Za-z0-9._-]{0,127}$' || return 1
  lowered="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  case "$lowered" in
    null|true|false|yes|no|on|off|y|n) return 1 ;;
  esac
  return 0
}

exact_final_review_fields() {
  local actual expected
  actual="$(awk '
    NR == 1 { if ($0 != "---") exit 2; fm = 1; next }
    fm && $0 == "---" { closed = 1; exit }
    fm && /^[^[:space:]][^:]*:/ { key = $0; sub(/:.*/, "", key); print key }
    END { if (!closed) exit 2 }
  ' "$1" | sort)" || return 1
  expected="$(printf '%s\n' fix_review_package fix_review_package_sha256 full_review_package full_review_package_sha256 merge_base outcome projection projection_sha256 reviewed_head reviewed_tree reviewer_context spec spec_sha256 tasks tasks_sha256 worktree | sort)"
  [ "$actual" = "$expected" ]
}

projection_body_sha() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm { print }' "$1" | shasum -a 256 | awk '{print $1}'
}

verify_projection() {
  local projection="$1" root="$2" slug="$3" stored predecessor
  canonical_file "$projection" >/dev/null || return 1
  under "$projection" "$root/.superpowers/sdd" || return 1
  [ "$(field "$projection" sdd_projection 2>/dev/null)" = maxi-v1 ] || return 1
  [ "$(field "$projection" slug 2>/dev/null)" = "$slug" ] || return 1
  stored="$(field "$projection" projection_body_sha256 2>/dev/null)" || return 1
  [ "$stored" = "$(projection_body_sha "$projection")" ] || return 1
  predecessor="$(field "$projection" predecessor_projection 2>/dev/null)" || return 1
  [ "$predecessor" = null ] || canonical_file "$predecessor" >/dev/null || return 1
}

tasks_structural_sha() {
  awk '
    NR == 1 && $0 == "---" { fm = 1 }
    fm && /^updated:/ { next }
    /^- \[[ xX]\] T[0-9][0-9][0-9] / { sub(/^- \[[ xX]\]/, "- [ ]") }
    { print }
    fm && NR > 1 && $0 == "---" { fm = 0 }
  ' "$1" | shasum -a 256 | awk '{print $1}'
}

package_range() {
  sed -n '1s/^# Review package: \([0-9a-f]\{40\}\)\.\.\([0-9a-f]\{40\}\)$/\1|\2/p' "$1"
}

verify_package_bytes() {
  local worktree="$1" projection="$2" start="$3" end="$4" package="$5" expected="$6"
  (cd "$worktree" && bash "$REVIEW_PACKAGE_HELPER" "$projection" "$start" "$end" "$expected") >/dev/null || return 1
  cmp -s "$expected" "$package"
}

WORKTREE='' MERGE_BASE='' PROJECTION='' LEDGER='' FINAL_REVIEW='' SPEC='' TASKS='' OUTPUT=''
while [ $# -gt 0 ]; do
  case "$1" in
    --worktree) [ $# -ge 2 ] || die 'missing worktree'; WORKTREE="$2"; shift 2 ;;
    --merge-base) [ $# -ge 2 ] || die 'missing merge base'; MERGE_BASE="$2"; shift 2 ;;
    --projection) [ $# -ge 2 ] || die 'missing projection'; PROJECTION="$2"; shift 2 ;;
    --ledger) [ $# -ge 2 ] || die 'missing ledger'; LEDGER="$2"; shift 2 ;;
    --final-review) [ $# -ge 2 ] || die 'missing final review'; FINAL_REVIEW="$2"; shift 2 ;;
    --spec) [ $# -ge 2 ] || die 'missing spec'; SPEC="$2"; shift 2 ;;
    --tasks) [ $# -ge 2 ] || die 'missing tasks'; TASKS="$2"; shift 2 ;;
    --output) [ $# -ge 2 ] || die 'missing output'; OUTPUT="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$WORKTREE" ] && [ -n "$MERGE_BASE" ] && [ -n "$PROJECTION" ] && [ -n "$LEDGER" ] && [ -n "$FINAL_REVIEW" ] && [ -n "$SPEC" ] && [ -n "$TASKS" ] && [ -n "$OUTPUT" ] || die 'all arguments are required'

[ -d "$WORKTREE" ] && [ ! -L "$WORKTREE" ] || die 'worktree is missing or symlinked'
PHYSICAL_ROOT="$(cd -P "$WORKTREE" && pwd)"
[ "$WORKTREE" = "$PHYSICAL_ROOT" ] || die 'worktree path is not canonical'
[ "$(git -C "$PHYSICAL_ROOT" rev-parse --show-toplevel 2>/dev/null)" = "$PHYSICAL_ROOT" ] || die 'not a physical Git worktree root'
PROJECTION="$(canonical_file "$PROJECTION")" || die 'projection is missing, symlinked, or noncanonical'
LEDGER="$(canonical_file "$LEDGER")" || die 'ledger is missing, symlinked, or noncanonical'
FINAL_REVIEW="$(canonical_file "$FINAL_REVIEW")" || die 'final review is missing, symlinked, or noncanonical'
SPEC="$(canonical_file "$SPEC")" || die 'spec is missing, symlinked, or noncanonical'
TASKS="$(canonical_file "$TASKS")" || die 'tasks is missing, symlinked, or noncanonical'
for path in "$PROJECTION" "$LEDGER" "$FINAL_REVIEW" "$SPEC" "$TASKS"; do under "$path" "$PHYSICAL_ROOT" || die "path escapes worktree: $path"; done
[ "$(dirname "$SPEC")" = "$(dirname "$TASKS")" ] || die 'spec and tasks are not colocated'

[ ! -L "$OUTPUT" ] || die 'receipt output is a symlink'
OUTPUT_PARENT="$(cd -P "$(dirname "$OUTPUT")" 2>/dev/null && pwd)" || die 'receipt parent is missing'
OUTPUT="$OUTPUT_PARENT/$(basename "$OUTPUT")"
[ "$OUTPUT_PARENT" = "$(dirname "$LEDGER")" ] || die 'receipt must be beside current ledger'
under "$OUTPUT" "$PHYSICAL_ROOT/.superpowers/sdd" || die 'receipt escapes SDD workspace'

case "$MERGE_BASE" in *[!0-9a-f]*|'') die 'merge base must be full lowercase SHA' ;; esac
[ "${#MERGE_BASE}" -eq 40 ] || die 'merge base must be full lowercase SHA'
[ "$(git -C "$PHYSICAL_ROOT" rev-parse "$MERGE_BASE^{commit}" 2>/dev/null)" = "$MERGE_BASE" ] || die 'merge base is not a commit'

SLUG="$(field "$SPEC" slug 2>/dev/null)" || die 'spec slug is missing or duplicated'
verify_projection "$PROJECTION" "$PHYSICAL_ROOT" "$SLUG" || die 'current projection is invalid'
[ "$(field "$PROJECTION" source_spec 2>/dev/null)" = "$SPEC" ] || die 'projection spec mismatch'
[ "$(field "$PROJECTION" tasks_structural_sha256 2>/dev/null)" = "$(tasks_structural_sha "$TASKS")" ] || die 'projection tasks identity mismatch'

expected_ledger="$PHYSICAL_ROOT/.superpowers/sdd/$(basename "$PROJECTION" .md)/progress.md"
[ "$LEDGER" = "$expected_ledger" ] || die 'ledger is outside the projection workspace'
IFS= read -r first < "$LEDGER" || die 'empty ledger'
[ "$first" = "# SDD ledger — plan: $PROJECTION" ] || die 'ledger plan identity mismatch'
REVIEWER_IDENTITY="$(canonical_file "$(dirname "$LEDGER")/final-reviewer-dispatch.identity")" || die 'persisted reviewer dispatch identity is missing, symlinked, or noncanonical'
[ "$REVIEWER_IDENTITY" = "$(dirname "$LEDGER")/final-reviewer-dispatch.identity" ] || die 'reviewer dispatch identity is not beside current ledger'
[ "$(wc -l < "$REVIEWER_IDENTITY" | tr -d ' ')" -eq 1 ] || die 'reviewer dispatch identity must contain one line'
IFS= read -r identity_line < "$REVIEWER_IDENTITY" || die 'empty reviewer dispatch identity'
case "$identity_line" in reviewer_context:\ *) DISPATCH_CONTEXT="${identity_line#reviewer_context: }" ;; *) die 'reviewer dispatch identity is malformed' ;; esac
valid_context "$DISPATCH_CONTEXT" || die 'invalid persisted reviewer dispatch context'
while IFS= read -r number; do
  [ "$(grep -c "^Task $number: complete$" "$LEDGER" || true)" -eq 1 ] || die "ledger does not complete Task $number"
done < <(sed -n 's/^### Task \([1-9][0-9]*\): T[0-9][0-9][0-9] .*/\1/p' "$PROJECTION")
PLAN="$(field "$PROJECTION" source_plan 2>/dev/null)" || die 'projection source plan is missing'
PLAN="$(canonical_file "$PLAN")" || die 'projection source plan is missing, symlinked, or noncanonical'
[ "$(dirname "$PLAN")" = "$(dirname "$SPEC")" ] || die 'projection source plan is outside the spec root'
STATE_FILE="$PHYSICAL_ROOT/.superpowers/sdd/active-$SLUG"
[ -f "$STATE_FILE" ] && [ ! -L "$STATE_FILE" ] || die 'active projection pointer is missing or symlinked'
[ "$(wc -l < "$STATE_FILE" | tr -d ' ')" -eq 1 ] || die 'active projection pointer is malformed'
IFS= read -r active_projection < "$STATE_FILE" || die 'active projection pointer is empty'
[ "$active_projection" = "$PROJECTION" ] || die 'terminal projection is not active'
verified_projection="$(cd "$PHYSICAL_ROOT" && bash "$PROJECT_HELPER" --spec "$SPEC" --plan "$PLAN" --tasks "$TASKS" --output "$PROJECTION" --state-file "$STATE_FILE" --verify-only)" || die 'projection cannot be reconstructed from canonical sources and lineage'
[ "$verified_projection" = "$PROJECTION" ] || die 'projection reconstruction returned another identity'

TMP="$(mktemp -d "$OUTPUT_PARENT/.terminal.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
REVERSE="$TMP/reverse"
: > "$REVERSE"
current="$PROJECTION"
seen='|'
while [ "$current" != null ]; do
  verify_projection "$current" "$PHYSICAL_ROOT" "$SLUG" || die 'broken projection lineage'
  [ "$(field "$current" source_spec 2>/dev/null)" = "$SPEC" ] || die 'lineage belongs to another spec root'
  case "$seen" in *"|$current|"*) die 'projection lineage cycle' ;; esac
  seen="$seen$current|"
  lineage_ledger="$PHYSICAL_ROOT/.superpowers/sdd/$(basename "$current" .md)/progress.md"
  lineage_ledger="$(canonical_file "$lineage_ledger")" || die 'lineage ledger missing or symlinked'
  IFS= read -r first < "$lineage_ledger" || die 'empty lineage ledger'
  [ "$first" = "# SDD ledger — plan: $current" ] || die 'lineage ledger identity mismatch'
  printf '%s|%s|%s|%s\n' "$current" "$(sha "$current")" "$lineage_ledger" "$(sha "$lineage_ledger")" >> "$REVERSE"
  current="$(field "$current" predecessor_projection 2>/dev/null)" || die 'lineage predecessor missing'
done
awk '{ line[NR] = $0 } END { for (i = NR; i >= 1; i--) print line[i] }' "$REVERSE" > "$TMP/lineage"
: > "$TMP/rulings"
while IFS='|' read -r lineage_projection projection_hash lineage_ledger ledger_hash; do
  grep '^Ruling:' "$lineage_ledger" >> "$TMP/rulings" || true
done < "$TMP/lineage"

exact_final_review_fields "$FINAL_REVIEW" || die 'final review envelope fields are not exact'
REVIEW_WORKTREE="$(field "$FINAL_REVIEW" worktree)"
REVIEW_BASE="$(field "$FINAL_REVIEW" merge_base)"
REVIEW_HEAD="$(field "$FINAL_REVIEW" reviewed_head)"
REVIEW_TREE="$(field "$FINAL_REVIEW" reviewed_tree)"
REVIEW_PROJECTION="$(field "$FINAL_REVIEW" projection)"
REVIEW_PROJECTION_HASH="$(field "$FINAL_REVIEW" projection_sha256)"
FULL_PACKAGE="$(field "$FINAL_REVIEW" full_review_package)"
FULL_PACKAGE_HASH="$(field "$FINAL_REVIEW" full_review_package_sha256)"
FIX_PACKAGE="$(field "$FINAL_REVIEW" fix_review_package)"
FIX_PACKAGE_HASH="$(field "$FINAL_REVIEW" fix_review_package_sha256)"
REVIEW_SPEC="$(field "$FINAL_REVIEW" spec)"
REVIEW_SPEC_HASH="$(field "$FINAL_REVIEW" spec_sha256)"
REVIEW_TASKS="$(field "$FINAL_REVIEW" tasks)"
REVIEW_TASKS_HASH="$(field "$FINAL_REVIEW" tasks_sha256)"
REVIEW_CONTEXT="$(field "$FINAL_REVIEW" reviewer_context)"
OUTCOME="$(field "$FINAL_REVIEW" outcome)"
[ "$REVIEW_WORKTREE" = "$PHYSICAL_ROOT" ] && [ "$REVIEW_BASE" = "$MERGE_BASE" ] || die 'final review worktree/base mismatch'
[ "$REVIEW_PROJECTION" = "$PROJECTION" ] && [ "$REVIEW_PROJECTION_HASH" = "$(sha "$PROJECTION")" ] || die 'final review projection mismatch'
[ "$REVIEW_SPEC" = "$SPEC" ] && [ "$REVIEW_SPEC_HASH" = "$(sha "$SPEC")" ] || die 'final review spec mismatch'
[ "$REVIEW_TASKS" = "$TASKS" ] && [ "$REVIEW_TASKS_HASH" = "$(sha "$TASKS")" ] || die 'final review tasks mismatch'
[ "$OUTCOME" = finish ] || die 'final review did not reach Finish boundary'
valid_context "$REVIEW_CONTEXT" || die 'invalid reviewer context'
[ "$REVIEW_CONTEXT" = "$DISPATCH_CONTEXT" ] || die 'final reviewer differs from persisted dispatch identity'
[ "$(grep -Fxc -- '**Ready to merge?** Yes' "$FINAL_REVIEW" || true)" -eq 1 ] || die 'final review is not canonically ready to merge'

case "$REVIEW_HEAD:$REVIEW_TREE" in *[!0-9a-f:]*|*:|:*) die 'invalid reviewed Git identity' ;; esac
[ "${#REVIEW_HEAD}" -eq 40 ] && [ "${#REVIEW_TREE}" -eq 40 ] || die 'reviewed Git identity is not full length'
[ "$(git -C "$PHYSICAL_ROOT" rev-parse HEAD)" = "$REVIEW_HEAD" ] || die 'current HEAD differs from reviewed HEAD'
[ "$(git -C "$PHYSICAL_ROOT" rev-parse HEAD^{tree})" = "$REVIEW_TREE" ] || die 'current tree differs from reviewed tree'
git -C "$PHYSICAL_ROOT" merge-base --is-ancestor "$MERGE_BASE" "$REVIEW_HEAD" || die 'review range is discontinuous'
git -C "$PHYSICAL_ROOT" diff --cached --quiet -- || die 'staged changes are not empty'

FULL_PACKAGE="$(canonical_file "$FULL_PACKAGE")" || die 'full review package is missing, symlinked, or noncanonical'
under "$FULL_PACKAGE" "$PHYSICAL_ROOT/.superpowers/sdd" || die 'full review package escapes workspace'
[ "$FULL_PACKAGE_HASH" = "$(sha "$FULL_PACKAGE")" ] || die 'full review package hash mismatch'
full_range="$(package_range "$FULL_PACKAGE")"
[ -n "$full_range" ] || die 'full review package header is malformed'
full_start="${full_range%%|*}"; initial_head="${full_range#*|}"
[ "$full_start" = "$MERGE_BASE" ] || die 'full review package starts at wrong commit'
verify_package_bytes "$PHYSICAL_ROOT" "$PROJECTION" "$MERGE_BASE" "$initial_head" "$FULL_PACKAGE" "$TMP/expected-full-review.diff" || die 'full review package bytes do not match the Git range'
if [ "$FIX_PACKAGE" = null ] || [ "$FIX_PACKAGE_HASH" = null ]; then
  [ "$FIX_PACKAGE" = null ] && [ "$FIX_PACKAGE_HASH" = null ] || die 'partial null fix package'
  [ "$initial_head" = "$REVIEW_HEAD" ] || die 'full review package does not end at reviewed HEAD'
else
  FIX_PACKAGE="$(canonical_file "$FIX_PACKAGE")" || die 'fix review package is missing, symlinked, or noncanonical'
  under "$FIX_PACKAGE" "$PHYSICAL_ROOT/.superpowers/sdd" || die 'fix review package escapes workspace'
  [ "$FIX_PACKAGE_HASH" = "$(sha "$FIX_PACKAGE")" ] || die 'fix review package hash mismatch'
  fix_range="$(package_range "$FIX_PACKAGE")"
  [ "$fix_range" = "$initial_head|$REVIEW_HEAD" ] || die 'fix review package range is discontinuous'
  verify_package_bytes "$PHYSICAL_ROOT" "$PROJECTION" "$initial_head" "$REVIEW_HEAD" "$FIX_PACKAGE" "$TMP/expected-fix-review.diff" || die 'fix review package bytes do not match the Git range'
fi

SPEC_REL="${SPEC#$PHYSICAL_ROOT/}"
TASKS_REL="${TASKS#$PHYSICAL_ROOT/}"
git -C "$PHYSICAL_ROOT" status --porcelain --untracked-files=all | awk '{ print substr($0, 4) }' | sort > "$TMP/working"
while IFS= read -r dirty; do
  [ -n "$dirty" ] || continue
  [ "$dirty" = "$SPEC_REL" ] || [ "$dirty" = "$TASKS_REL" ] || die "unreviewed working-tree path: $dirty"
done < "$TMP/working"

LINEAGE_HASH="$(sha "$TMP/lineage")"
RULINGS_HASH="$(sha "$TMP/rulings")"
WORKING_HASH="$(sha "$TMP/working")"
TEMP_RECEIPT="$(mktemp "$OUTPUT_PARENT/.terminal-receipt.XXXXXX")"
{
  echo '---'
  echo 'receipt_contract: maxi-sdd-terminal-v1'
  echo "worktree: $PHYSICAL_ROOT"
  echo "merge_base: $MERGE_BASE"
  echo "reviewed_head: $REVIEW_HEAD"
  echo "reviewed_tree: $REVIEW_TREE"
  echo "projection: $PROJECTION"
  echo "projection_sha256: $(sha "$PROJECTION")"
  echo "ledger: $LEDGER"
  echo "ledger_sha256: $(sha "$LEDGER")"
  echo "final_review: $FINAL_REVIEW"
  echo "final_review_sha256: $(sha "$FINAL_REVIEW")"
  echo "reviewer_dispatch_identity: $REVIEWER_IDENTITY"
  echo "reviewer_dispatch_identity_sha256: $(sha "$REVIEWER_IDENTITY")"
  echo "reviewer_context: $DISPATCH_CONTEXT"
  echo "full_review_package: $FULL_PACKAGE"
  echo "full_review_package_sha256: $FULL_PACKAGE_HASH"
  echo "fix_review_package: $FIX_PACKAGE"
  echo "fix_review_package_sha256: $FIX_PACKAGE_HASH"
  echo "spec: $SPEC"
  echo "spec_sha256: $(sha "$SPEC")"
  echo "tasks: $TASKS"
  echo "tasks_sha256: $(sha "$TASKS")"
  echo "lineage_sha256: $LINEAGE_HASH"
  echo "rulings_sha256: $RULINGS_HASH"
  echo "working_tree_paths_sha256: $WORKING_HASH"
  echo 'outcome: finish'
  echo '---'
  echo
  echo '## Working tree paths'
  sed 's/^/WORKING_TREE_PATH: /' "$TMP/working"
  echo
  echo '## Projection lineage'
  while IFS='|' read -r lineage_projection projection_hash lineage_ledger ledger_hash; do
    echo "LINEAGE: $lineage_projection"
    echo "LINEAGE_PROJECTION_SHA256: $projection_hash"
    echo "LINEAGE_LEDGER: $lineage_ledger"
    echo "LINEAGE_LEDGER_SHA256: $ledger_hash"
  done < "$TMP/lineage"
  echo
  echo '## Rulings'
  cat "$TMP/rulings"
} > "$TEMP_RECEIPT"
mv "$TEMP_RECEIPT" "$OUTPUT"
