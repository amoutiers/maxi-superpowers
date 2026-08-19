#!/usr/bin/env bash
# Validate the complete terminal receipt and classify Maxi completion.
set -euo pipefail

LC_ALL=C
export LC_ALL

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
PROJECT_HELPER="$SCRIPT_DIR/project-tasks.sh"
REVIEW_PACKAGE_HELPER="$SCRIPT_DIR/../subagent-driven-development/scripts/review-package"
[ -f "$PROJECT_HELPER" ] || { echo 'ERROR: projection helper is missing' >&2; exit 2; }
[ -f "$REVIEW_PACKAGE_HELPER" ] || { echo 'ERROR: upstream review-package helper is missing' >&2; exit 2; }

quiet_fail() { echo "ERROR: $*" >&2; exit 2; }
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

validate_review_conclusion() {
  local review="$1" fix_package="$2" ready_total ready_line fix_total fix_line
  ready_total="$(awk 'index($0, "**Ready to merge?** ") == 1 { count++ } END { print count + 0 }' "$review")"
  fix_total="$(awk 'index($0, "**Fix round:** ") == 1 { count++ } END { print count + 0 }' "$review")"
  if [ "$fix_package" = null ]; then
    [ "$ready_total" -eq 1 ] && [ "$(grep -Fxc -- '**Ready to merge?** Yes' "$review" || true)" -eq 1 ] && [ "$fix_total" -eq 0 ]
  else
    [ "$ready_total" -eq 1 ] && [ "$(grep -Fxc -- '**Ready to merge?** With fixes' "$review" || true)" -eq 1 ] || return 1
    [ "$fix_total" -eq 1 ] && [ "$(grep -Fxc -- '**Fix round:** All findings addressed, no new Critical/Important breakage, no out-of-scope observation.' "$review" || true)" -eq 1 ] || return 1
    ready_line="$(grep -nF -- '**Ready to merge?** With fixes' "$review" | cut -d: -f1)"
    fix_line="$(grep -nF -- '**Fix round:** All findings addressed, no new Critical/Important breakage, no out-of-scope observation.' "$review" | cut -d: -f1)"
    [ "$ready_line" -lt "$fix_line" ]
  fi
}

projection_body_sha() {
  awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm { print }' "$1" | shasum -a 256 | awk '{print $1}'
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

validate_tasks() {
  awk '
    /^- \[[^]]*\] T/ && $0 !~ /^- \[[ xX]\] T[0-9][0-9][0-9] .+/ { bad = 1 }
    /^- \[[ xX]\] T[0-9][0-9][0-9] .+/ {
      id = substr($0, 7, 4); number = substr(id, 2) + 0
      if (seen[id]++) bad = 1
      present[number] = 1; count++
      if (substr($0, 1, 5) == "- [ ]") pending++
    }
    END {
      if (count == 0) bad = 1
      for (i = 1; i <= count; i++) if (!present[i]) bad = 1
      if (bad) exit 2
      print pending + 0
    }
  ' "$1"
}

exact_receipt_fields() {
  local actual expected
  actual="$(awk '
    NR == 1 { if ($0 != "---") exit 2; fm = 1; next }
    fm && $0 == "---" { closed = 1; exit }
    fm && /^[^[:space:]][^:]*:/ { key = $0; sub(/:.*/, "", key); print key }
    END { if (!closed) exit 2 }
  ' "$1" | sort)" || return 1
  expected="$(printf '%s\n' final_review final_review_sha256 fix_review_package fix_review_package_sha256 full_review_package full_review_package_sha256 ledger ledger_sha256 lineage_sha256 merge_base outcome projection projection_sha256 receipt_contract reviewed_head reviewed_tree reviewer_context reviewer_dispatch_identity reviewer_dispatch_identity_sha256 rulings_sha256 spec spec_sha256 tasks tasks_sha256 working_tree_paths_sha256 worktree | sort)"
  [ "$actual" = "$expected" ]
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

package_range() { sed -n '1s/^# Review package: \([0-9a-f]\{40\}\)\.\.\([0-9a-f]\{40\}\)$/\1|\2/p' "$1"; }

verify_package_bytes() {
  local worktree="$1" projection="$2" start="$3" end="$4" package="$5" expected="$6"
  (cd "$worktree" && bash "$REVIEW_PACKAGE_HELPER" "$projection" "$start" "$end" "$expected") >/dev/null || return 1
  cmp -s "$expected" "$package"
}

completion_number() {
  printf '%s\n' "$1" | sed -E -n 's/^Task ([1-9][0-9]*): complete \(commits [0-9a-f]{7}\.\.[0-9a-f]{7}, (review clean|[1-9][0-9]* parked)\)$/\1/p'
}

validate_projection_completions() {
  local ledger="$1" projection="$2" line number seen='|'
  while IFS= read -r line; do
    case "$line" in
      Task\ *:\ complete*)
        number="$(completion_number "$line")"
        [ -n "$number" ] || return 1
        [ "$(grep -c "^### Task $number: T[0-9][0-9][0-9] " "$projection" || true)" -eq 1 ] || return 1
        case "$seen" in *"|$number|"*) return 1 ;; esac
        seen="$seen$number|"
        ;;
    esac
  done < "$ledger"
  while IFS= read -r number; do
    case "$seen" in *"|$number|"*) ;; *) return 1 ;; esac
  done < <(sed -n 's/^### Task \([1-9][0-9]*\): T[0-9][0-9][0-9] .*/\1/p' "$projection")
}

TASKS_ARG='' RECEIPT=''
while [ $# -gt 0 ]; do
  case "$1" in
    --tasks) [ $# -ge 2 ] || quiet_fail 'missing tasks'; TASKS_ARG="$2"; shift 2 ;;
    --receipt) [ $# -ge 2 ] || quiet_fail 'missing receipt'; RECEIPT="$2"; shift 2 ;;
    *) quiet_fail "unknown argument: $1" ;;
  esac
done
[ -n "$TASKS_ARG" ] && [ -n "$RECEIPT" ] || quiet_fail 'both arguments are required'
TASKS_ARG="$(canonical_file "$TASKS_ARG")" || quiet_fail 'tasks is missing, symlinked, or noncanonical'
PENDING="$(validate_tasks "$TASKS_ARG")" || quiet_fail 'tasks grammar is invalid'
if [ "$PENDING" -gt 0 ]; then
  echo 'BLOCKED_PENDING_TASKS'
  exit 0
fi

RECEIPT="$(canonical_file "$RECEIPT")" || quiet_fail 'receipt is missing, symlinked, or noncanonical'
exact_receipt_fields "$RECEIPT" || quiet_fail 'receipt envelope fields are not exact'
[ "$(field "$RECEIPT" receipt_contract)" = maxi-sdd-terminal-v1 ] || quiet_fail 'unknown receipt contract'
[ "$(field "$RECEIPT" outcome)" = finish ] || quiet_fail 'receipt did not reach Finish boundary'

WORKTREE="$(field "$RECEIPT" worktree)"
[ -d "$WORKTREE" ] && [ ! -L "$WORKTREE" ] || quiet_fail 'receipt worktree is invalid'
PHYSICAL_ROOT="$(cd -P "$WORKTREE" && pwd)"
[ "$WORKTREE" = "$PHYSICAL_ROOT" ] || quiet_fail 'receipt worktree is not canonical'
[ "$(git -C "$PHYSICAL_ROOT" rev-parse --show-toplevel 2>/dev/null)" = "$PHYSICAL_ROOT" ] || quiet_fail 'receipt worktree is not a Git root'

PROJECTION="$(field "$RECEIPT" projection)"
LEDGER="$(field "$RECEIPT" ledger)"
FINAL_REVIEW="$(field "$RECEIPT" final_review)"
REVIEWER_IDENTITY="$(field "$RECEIPT" reviewer_dispatch_identity)"
FULL_PACKAGE="$(field "$RECEIPT" full_review_package)"
FIX_PACKAGE="$(field "$RECEIPT" fix_review_package)"
SPEC="$(field "$RECEIPT" spec)"
TASKS="$(field "$RECEIPT" tasks)"
for path in "$PROJECTION" "$LEDGER" "$FINAL_REVIEW" "$REVIEWER_IDENTITY" "$FULL_PACKAGE" "$SPEC" "$TASKS"; do
  canonical_file "$path" >/dev/null || quiet_fail "receipt path is missing, symlinked, or noncanonical: $path"
  under "$path" "$PHYSICAL_ROOT" || quiet_fail "receipt path escapes worktree: $path"
done
[ "$FIX_PACKAGE" = null ] || { canonical_file "$FIX_PACKAGE" >/dev/null && under "$FIX_PACKAGE" "$PHYSICAL_ROOT"; } || quiet_fail 'fix package path is invalid'
[ "$TASKS" = "$TASKS_ARG" ] || quiet_fail 'receipt tasks path mismatch'
[ "$(dirname "$RECEIPT")" = "$(dirname "$LEDGER")" ] || quiet_fail 'receipt is not beside its ledger'

[ "$(field "$RECEIPT" projection_sha256)" = "$(sha "$PROJECTION")" ] || quiet_fail 'projection hash mismatch'
[ "$(field "$RECEIPT" ledger_sha256)" = "$(sha "$LEDGER")" ] || quiet_fail 'ledger hash mismatch'
[ "$(field "$RECEIPT" final_review_sha256)" = "$(sha "$FINAL_REVIEW")" ] || quiet_fail 'final review hash mismatch'
[ "$(field "$RECEIPT" reviewer_dispatch_identity_sha256)" = "$(sha "$REVIEWER_IDENTITY")" ] || quiet_fail 'reviewer dispatch identity hash mismatch'
[ "$REVIEWER_IDENTITY" = "$(dirname "$LEDGER")/final-reviewer-dispatch.identity" ] || quiet_fail 'reviewer dispatch identity is not beside current ledger'
[ "$(wc -l < "$REVIEWER_IDENTITY" | tr -d ' ')" -eq 1 ] || quiet_fail 'reviewer dispatch identity must contain one line'
IFS= read -r identity_line < "$REVIEWER_IDENTITY" || quiet_fail 'empty reviewer dispatch identity'
case "$identity_line" in reviewer_context:\ *) DISPATCH_CONTEXT="${identity_line#reviewer_context: }" ;; *) quiet_fail 'reviewer dispatch identity is malformed' ;; esac
valid_context "$DISPATCH_CONTEXT" || quiet_fail 'invalid persisted reviewer dispatch context'
[ "$(field "$RECEIPT" reviewer_context)" = "$DISPATCH_CONTEXT" ] || quiet_fail 'receipt reviewer context differs from dispatch identity'
[ "$(field "$RECEIPT" full_review_package_sha256)" = "$(sha "$FULL_PACKAGE")" ] || quiet_fail 'full package hash mismatch'
[ "$(field "$RECEIPT" spec_sha256)" = "$(sha "$SPEC")" ] || quiet_fail 'spec hash mismatch'
[ "$(field "$RECEIPT" tasks_sha256)" = "$(sha "$TASKS")" ] || quiet_fail 'tasks hash mismatch'
if [ "$FIX_PACKAGE" = null ]; then
  [ "$(field "$RECEIPT" fix_review_package_sha256)" = null ] || quiet_fail 'null fix package hash mismatch'
else
  [ "$(field "$RECEIPT" fix_review_package_sha256)" = "$(sha "$FIX_PACKAGE")" ] || quiet_fail 'fix package hash mismatch'
fi

SLUG="$(field "$SPEC" slug 2>/dev/null)" || quiet_fail 'spec slug is invalid'
PLAN="$(field "$PROJECTION" source_plan 2>/dev/null)" || quiet_fail 'projection source plan is missing'
PLAN="$(canonical_file "$PLAN")" || quiet_fail 'projection source plan is missing, symlinked, or noncanonical'
[ "$(dirname "$PLAN")" = "$(dirname "$SPEC")" ] || quiet_fail 'projection source plan is outside the spec root'
STATE_FILE="$PHYSICAL_ROOT/.superpowers/sdd/active-$SLUG"
[ -f "$STATE_FILE" ] && [ ! -L "$STATE_FILE" ] || quiet_fail 'active projection pointer is missing or symlinked'
[ "$(wc -l < "$STATE_FILE" | tr -d ' ')" -eq 1 ] || quiet_fail 'active projection pointer is malformed'
IFS= read -r active_projection < "$STATE_FILE" || quiet_fail 'active projection pointer is empty'
[ "$active_projection" = "$PROJECTION" ] || quiet_fail 'receipt projection is not active'
verified_projection="$(cd "$PHYSICAL_ROOT" && bash "$PROJECT_HELPER" --spec "$SPEC" --plan "$PLAN" --tasks "$TASKS" --output "$PROJECTION" --state-file "$STATE_FILE" --verify-only)" || quiet_fail 'projection cannot be reconstructed from canonical sources and lineage'
[ "$verified_projection" = "$PROJECTION" ] || quiet_fail 'projection reconstruction returned another identity'

TMP="$(mktemp -d "$(dirname "$RECEIPT")/.result.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
awk '
  NR == 1 && $0 == "---" { fm = 1; next }
  fm && $0 == "---" { fm = 0; next }
  fm { next }
  /^$/ { next }
  $0 == "## Working tree paths" { section = "working"; next }
  $0 == "## Projection lineage" { section = "lineage"; next }
  $0 == "## Rulings" { section = "rulings"; next }
  section == "working" && /^WORKING_TREE_PATH: / { next }
  section == "lineage" && (/^LINEAGE: / || /^LINEAGE_PROJECTION_SHA256: / || /^LINEAGE_LEDGER: / || /^LINEAGE_LEDGER_SHA256: /) { next }
  section == "rulings" && index($0, "Ruling:") > 0 { next }
  { exit 2 }
' "$RECEIPT" || quiet_fail 'receipt body contains unknown records'
grep '^WORKING_TREE_PATH: ' "$RECEIPT" | sed 's/^WORKING_TREE_PATH: //' > "$TMP/working.receipt" || true
grep '^LINEAGE: ' "$RECEIPT" | sed 's/^LINEAGE: //' > "$TMP/projections" || true
grep '^LINEAGE_PROJECTION_SHA256: ' "$RECEIPT" | sed 's/^LINEAGE_PROJECTION_SHA256: //' > "$TMP/projection-hashes" || true
grep '^LINEAGE_LEDGER: ' "$RECEIPT" | sed 's/^LINEAGE_LEDGER: //' > "$TMP/ledgers" || true
grep '^LINEAGE_LEDGER_SHA256: ' "$RECEIPT" | sed 's/^LINEAGE_LEDGER_SHA256: //' > "$TMP/ledger-hashes" || true
awk '$0 == "## Rulings" { rulings = 1; next } rulings && $0 != "" { print }' "$RECEIPT" > "$TMP/rulings.receipt"
lineage_count="$(wc -l < "$TMP/projections" | tr -d ' ')"
[ "$lineage_count" -gt 0 ] || quiet_fail 'receipt lineage is empty'
for file in projection-hashes ledgers ledger-hashes; do [ "$(wc -l < "$TMP/$file" | tr -d ' ')" -eq "$lineage_count" ] || quiet_fail 'receipt lineage record counts differ'; done
paste -d'|' "$TMP/projections" "$TMP/projection-hashes" "$TMP/ledgers" "$TMP/ledger-hashes" > "$TMP/lineage"
[ "$(field "$RECEIPT" lineage_sha256)" = "$(sha "$TMP/lineage")" ] || quiet_fail 'lineage payload hash mismatch'
[ "$(field "$RECEIPT" rulings_sha256)" = "$(sha "$TMP/rulings.receipt")" ] || quiet_fail 'ruling payload hash mismatch'
[ "$(field "$RECEIPT" working_tree_paths_sha256)" = "$(sha "$TMP/working.receipt")" ] || quiet_fail 'working path payload hash mismatch'

previous=null
: > "$TMP/rulings.current"
i=0
while IFS='|' read -r lineage_projection projection_hash lineage_ledger ledger_hash; do
  i=$((i + 1))
  canonical_file "$lineage_projection" >/dev/null || quiet_fail 'lineage projection is invalid'
  canonical_file "$lineage_ledger" >/dev/null || quiet_fail 'lineage ledger is invalid'
  under "$lineage_projection" "$PHYSICAL_ROOT/.superpowers/sdd" || quiet_fail 'lineage projection escapes workspace'
  [ "$projection_hash" = "$(sha "$lineage_projection")" ] || quiet_fail 'lineage projection hash mismatch'
  [ "$ledger_hash" = "$(sha "$lineage_ledger")" ] || quiet_fail 'lineage ledger hash mismatch'
  [ "$(field "$lineage_projection" sdd_projection 2>/dev/null)" = maxi-v1 ] || quiet_fail 'lineage projection contract mismatch'
  [ "$(field "$lineage_projection" slug 2>/dev/null)" = "$SLUG" ] || quiet_fail 'lineage slug mismatch'
  [ "$(field "$lineage_projection" source_spec 2>/dev/null)" = "$SPEC" ] || quiet_fail 'lineage spec-root mismatch'
  [ "$(field "$lineage_projection" predecessor_projection 2>/dev/null)" = "$previous" ] || quiet_fail 'lineage predecessor mismatch'
  [ "$(field "$lineage_projection" projection_body_sha256 2>/dev/null)" = "$(projection_body_sha "$lineage_projection")" ] || quiet_fail 'lineage projection body mismatch'
  expected_ledger="$PHYSICAL_ROOT/.superpowers/sdd/$(basename "$lineage_projection" .md)/progress.md"
  [ "$lineage_ledger" = "$expected_ledger" ] || quiet_fail 'lineage ledger workspace mismatch'
  IFS= read -r first < "$lineage_ledger" || quiet_fail 'empty lineage ledger'
  [ "$first" = "# SDD ledger — plan: $lineage_projection" ] || quiet_fail 'lineage ledger identity mismatch'
  grep -F 'Ruling:' "$lineage_ledger" >> "$TMP/rulings.current" || true
  previous="$lineage_projection"
done < "$TMP/lineage"
[ "$previous" = "$PROJECTION" ] || quiet_fail 'current projection is not lineage terminal'
[ "$(tail -1 "$TMP/ledgers")" = "$LEDGER" ] || quiet_fail 'current ledger is not lineage terminal'
cmp -s "$TMP/rulings.current" "$TMP/rulings.receipt" || quiet_fail 'ruling set changed'
validate_projection_completions "$LEDGER" "$PROJECTION" || quiet_fail 'current ledger completion records are incomplete, malformed, duplicated, or unknown'

exact_final_review_fields "$FINAL_REVIEW" || quiet_fail 'final review envelope is invalid'
MERGE_BASE="$(field "$RECEIPT" merge_base)"
REVIEWED_HEAD="$(field "$RECEIPT" reviewed_head)"
REVIEWED_TREE="$(field "$RECEIPT" reviewed_tree)"
[ "$(field "$FINAL_REVIEW" worktree)" = "$PHYSICAL_ROOT" ] || quiet_fail 'final review worktree mismatch'
[ "$(field "$FINAL_REVIEW" merge_base)" = "$MERGE_BASE" ] || quiet_fail 'final review merge base mismatch'
[ "$(field "$FINAL_REVIEW" reviewed_head)" = "$REVIEWED_HEAD" ] || quiet_fail 'final review HEAD mismatch'
[ "$(field "$FINAL_REVIEW" reviewed_tree)" = "$REVIEWED_TREE" ] || quiet_fail 'final review tree mismatch'
[ "$(field "$FINAL_REVIEW" projection)" = "$PROJECTION" ] && [ "$(field "$FINAL_REVIEW" projection_sha256)" = "$(sha "$PROJECTION")" ] || quiet_fail 'final review projection mismatch'
[ "$(field "$FINAL_REVIEW" spec)" = "$SPEC" ] && [ "$(field "$FINAL_REVIEW" spec_sha256)" = "$(sha "$SPEC")" ] || quiet_fail 'final review spec mismatch'
[ "$(field "$FINAL_REVIEW" tasks)" = "$TASKS" ] && [ "$(field "$FINAL_REVIEW" tasks_sha256)" = "$(sha "$TASKS")" ] || quiet_fail 'final review tasks mismatch'
[ "$(field "$FINAL_REVIEW" full_review_package)" = "$FULL_PACKAGE" ] || quiet_fail 'final review full package mismatch'
[ "$(field "$FINAL_REVIEW" full_review_package_sha256)" = "$(sha "$FULL_PACKAGE")" ] || quiet_fail 'final review full package hash mismatch'
[ "$(field "$FINAL_REVIEW" fix_review_package)" = "$FIX_PACKAGE" ] || quiet_fail 'final review fix package mismatch'
[ "$(field "$FINAL_REVIEW" fix_review_package_sha256)" = "$(field "$RECEIPT" fix_review_package_sha256)" ] || quiet_fail 'final review fix package hash mismatch'
[ "$(field "$FINAL_REVIEW" outcome)" = finish ] && validate_review_conclusion "$FINAL_REVIEW" "$FIX_PACKAGE" || quiet_fail 'final review conclusion does not match its review-package path'
FINAL_REVIEW_CONTEXT="$(field "$FINAL_REVIEW" reviewer_context)"
valid_context "$FINAL_REVIEW_CONTEXT" || quiet_fail 'final reviewer context is invalid'
[ "$FINAL_REVIEW_CONTEXT" = "$DISPATCH_CONTEXT" ] || quiet_fail 'final reviewer differs from persisted dispatch identity'

[ "$(git -C "$PHYSICAL_ROOT" rev-parse HEAD)" = "$REVIEWED_HEAD" ] || quiet_fail 'HEAD changed after review'
[ "$(git -C "$PHYSICAL_ROOT" rev-parse HEAD^{tree})" = "$REVIEWED_TREE" ] || quiet_fail 'tree changed after review'
git -C "$PHYSICAL_ROOT" merge-base --is-ancestor "$MERGE_BASE" "$REVIEWED_HEAD" || quiet_fail 'review range is discontinuous'
git -C "$PHYSICAL_ROOT" diff --cached --quiet -- || quiet_fail 'staged state changed after review'
full_range="$(package_range "$FULL_PACKAGE")"
[ "${full_range%%|*}" = "$MERGE_BASE" ] || quiet_fail 'full review package starts at wrong commit'
initial_head="${full_range#*|}"
verify_package_bytes "$PHYSICAL_ROOT" "$PROJECTION" "$MERGE_BASE" "$initial_head" "$FULL_PACKAGE" "$TMP/expected-full-review.diff" || quiet_fail 'full review package bytes do not match the Git range'
if [ "$FIX_PACKAGE" = null ]; then
  [ "$initial_head" = "$REVIEWED_HEAD" ] || quiet_fail 'full review package ends at wrong commit'
else
  [ "$(package_range "$FIX_PACKAGE")" = "$initial_head|$REVIEWED_HEAD" ] || quiet_fail 'fix review package range is discontinuous'
  verify_package_bytes "$PHYSICAL_ROOT" "$PROJECTION" "$initial_head" "$REVIEWED_HEAD" "$FIX_PACKAGE" "$TMP/expected-fix-review.diff" || quiet_fail 'fix review package bytes do not match the Git range'
fi

git -C "$PHYSICAL_ROOT" status --porcelain --untracked-files=all | awk '{ print substr($0, 4) }' | sort > "$TMP/working.current"
cmp -s "$TMP/working.current" "$TMP/working.receipt" || quiet_fail 'working-tree path set changed after review'
SPEC_REL="${SPEC#$PHYSICAL_ROOT/}"; TASKS_REL="${TASKS#$PHYSICAL_ROOT/}"
while IFS= read -r dirty; do [ -z "$dirty" ] || [ "$dirty" = "$SPEC_REL" ] || [ "$dirty" = "$TASKS_REL" ] || quiet_fail "unreviewed working path: $dirty"; done < "$TMP/working.current"
[ "$(field "$PROJECTION" source_spec 2>/dev/null)" = "$SPEC" ] || quiet_fail 'projection source spec mismatch'
[ "$(field "$PROJECTION" tasks_structural_sha256 2>/dev/null)" = "$(tasks_structural_sha "$TASKS")" ] || quiet_fail 'projection tasks identity changed'

sed 's/^/LINEAGE: /' "$TMP/projections"
cat "$TMP/rulings.current"
echo 'READY_TO_FINISH'
