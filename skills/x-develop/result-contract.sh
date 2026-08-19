#!/usr/bin/env bash
# Validate the complete terminal receipt and classify Maxi completion.
set -euo pipefail

LC_ALL=C
export LC_ALL

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
  expected="$(printf '%s\n' final_review final_review_sha256 fix_review_package fix_review_package_sha256 full_review_package full_review_package_sha256 ledger ledger_sha256 lineage_sha256 merge_base outcome projection projection_sha256 receipt_contract reviewed_head reviewed_tree rulings_sha256 spec spec_sha256 tasks tasks_sha256 working_tree_paths_sha256 worktree | sort)"
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
FULL_PACKAGE="$(field "$RECEIPT" full_review_package)"
FIX_PACKAGE="$(field "$RECEIPT" fix_review_package)"
SPEC="$(field "$RECEIPT" spec)"
TASKS="$(field "$RECEIPT" tasks)"
for path in "$PROJECTION" "$LEDGER" "$FINAL_REVIEW" "$FULL_PACKAGE" "$SPEC" "$TASKS"; do
  canonical_file "$path" >/dev/null || quiet_fail "receipt path is missing, symlinked, or noncanonical: $path"
  under "$path" "$PHYSICAL_ROOT" || quiet_fail "receipt path escapes worktree: $path"
done
[ "$FIX_PACKAGE" = null ] || { canonical_file "$FIX_PACKAGE" >/dev/null && under "$FIX_PACKAGE" "$PHYSICAL_ROOT"; } || quiet_fail 'fix package path is invalid'
[ "$TASKS" = "$TASKS_ARG" ] || quiet_fail 'receipt tasks path mismatch'
[ "$(dirname "$RECEIPT")" = "$(dirname "$LEDGER")" ] || quiet_fail 'receipt is not beside its ledger'

[ "$(field "$RECEIPT" projection_sha256)" = "$(sha "$PROJECTION")" ] || quiet_fail 'projection hash mismatch'
[ "$(field "$RECEIPT" ledger_sha256)" = "$(sha "$LEDGER")" ] || quiet_fail 'ledger hash mismatch'
[ "$(field "$RECEIPT" final_review_sha256)" = "$(sha "$FINAL_REVIEW")" ] || quiet_fail 'final review hash mismatch'
[ "$(field "$RECEIPT" full_review_package_sha256)" = "$(sha "$FULL_PACKAGE")" ] || quiet_fail 'full package hash mismatch'
[ "$(field "$RECEIPT" spec_sha256)" = "$(sha "$SPEC")" ] || quiet_fail 'spec hash mismatch'
[ "$(field "$RECEIPT" tasks_sha256)" = "$(sha "$TASKS")" ] || quiet_fail 'tasks hash mismatch'
if [ "$FIX_PACKAGE" = null ]; then
  [ "$(field "$RECEIPT" fix_review_package_sha256)" = null ] || quiet_fail 'null fix package hash mismatch'
else
  [ "$(field "$RECEIPT" fix_review_package_sha256)" = "$(sha "$FIX_PACKAGE")" ] || quiet_fail 'fix package hash mismatch'
fi

TMP="$(mktemp -d "$(dirname "$RECEIPT")/.result.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
awk '
  NR == 1 && $0 == "---" { fm = 1; next }
  fm && $0 == "---" { fm = 0; next }
  fm { next }
  /^$/ || /^## (Working tree paths|Projection lineage|Rulings)$/ || /^WORKING_TREE_PATH: / || /^LINEAGE: / || /^LINEAGE_PROJECTION_SHA256: / || /^LINEAGE_LEDGER: / || /^LINEAGE_LEDGER_SHA256: / || /^Ruling:/ { next }
  { exit 2 }
' "$RECEIPT" || quiet_fail 'receipt body contains unknown records'
grep '^WORKING_TREE_PATH: ' "$RECEIPT" | sed 's/^WORKING_TREE_PATH: //' > "$TMP/working.receipt" || true
grep '^LINEAGE: ' "$RECEIPT" | sed 's/^LINEAGE: //' > "$TMP/projections" || true
grep '^LINEAGE_PROJECTION_SHA256: ' "$RECEIPT" | sed 's/^LINEAGE_PROJECTION_SHA256: //' > "$TMP/projection-hashes" || true
grep '^LINEAGE_LEDGER: ' "$RECEIPT" | sed 's/^LINEAGE_LEDGER: //' > "$TMP/ledgers" || true
grep '^LINEAGE_LEDGER_SHA256: ' "$RECEIPT" | sed 's/^LINEAGE_LEDGER_SHA256: //' > "$TMP/ledger-hashes" || true
grep '^Ruling:' "$RECEIPT" > "$TMP/rulings.receipt" || true
lineage_count="$(wc -l < "$TMP/projections" | tr -d ' ')"
[ "$lineage_count" -gt 0 ] || quiet_fail 'receipt lineage is empty'
for file in projection-hashes ledgers ledger-hashes; do [ "$(wc -l < "$TMP/$file" | tr -d ' ')" -eq "$lineage_count" ] || quiet_fail 'receipt lineage record counts differ'; done
paste -d'|' "$TMP/projections" "$TMP/projection-hashes" "$TMP/ledgers" "$TMP/ledger-hashes" > "$TMP/lineage"
[ "$(field "$RECEIPT" lineage_sha256)" = "$(sha "$TMP/lineage")" ] || quiet_fail 'lineage payload hash mismatch'
[ "$(field "$RECEIPT" rulings_sha256)" = "$(sha "$TMP/rulings.receipt")" ] || quiet_fail 'ruling payload hash mismatch'
[ "$(field "$RECEIPT" working_tree_paths_sha256)" = "$(sha "$TMP/working.receipt")" ] || quiet_fail 'working path payload hash mismatch'

SLUG="$(field "$SPEC" slug 2>/dev/null)" || quiet_fail 'spec slug is invalid'
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
  grep '^Ruling:' "$lineage_ledger" >> "$TMP/rulings.current" || true
  previous="$lineage_projection"
done < "$TMP/lineage"
[ "$previous" = "$PROJECTION" ] || quiet_fail 'current projection is not lineage terminal'
[ "$(tail -1 "$TMP/ledgers")" = "$LEDGER" ] || quiet_fail 'current ledger is not lineage terminal'
cmp -s "$TMP/rulings.current" "$TMP/rulings.receipt" || quiet_fail 'ruling set changed'
while IFS= read -r number; do
  [ "$(grep -c "^Task $number: complete$" "$LEDGER" || true)" -eq 1 ] || quiet_fail "current ledger does not complete Task $number"
done < <(sed -n 's/^### Task \([1-9][0-9]*\): T[0-9][0-9][0-9] .*/\1/p' "$PROJECTION")

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
[ "$(field "$FINAL_REVIEW" outcome)" = finish ] && [ "$(grep -c '^Verdict: approved$' "$FINAL_REVIEW" || true)" -eq 1 ] || quiet_fail 'final review did not approve Finish'
valid_context "$(field "$FINAL_REVIEW" reviewer_context)" || quiet_fail 'final reviewer context is invalid'

[ "$(git -C "$PHYSICAL_ROOT" rev-parse HEAD)" = "$REVIEWED_HEAD" ] || quiet_fail 'HEAD changed after review'
[ "$(git -C "$PHYSICAL_ROOT" rev-parse HEAD^{tree})" = "$REVIEWED_TREE" ] || quiet_fail 'tree changed after review'
git -C "$PHYSICAL_ROOT" merge-base --is-ancestor "$MERGE_BASE" "$REVIEWED_HEAD" || quiet_fail 'review range is discontinuous'
git -C "$PHYSICAL_ROOT" diff --cached --quiet -- || quiet_fail 'staged state changed after review'
full_range="$(package_range "$FULL_PACKAGE")"
[ "${full_range%%|*}" = "$MERGE_BASE" ] || quiet_fail 'full review package starts at wrong commit'
initial_head="${full_range#*|}"
if [ "$FIX_PACKAGE" = null ]; then
  [ "$initial_head" = "$REVIEWED_HEAD" ] || quiet_fail 'full review package ends at wrong commit'
else
  [ "$(package_range "$FIX_PACKAGE")" = "$initial_head|$REVIEWED_HEAD" ] || quiet_fail 'fix review package range is discontinuous'
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
