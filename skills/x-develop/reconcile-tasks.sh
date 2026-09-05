#!/usr/bin/env bash
# Reconcile completed upstream SDD tasks back to Maxi checkbox state.
set -euo pipefail

LC_ALL=C
export LC_ALL

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
PROJECT_HELPER="$SCRIPT_DIR/project-tasks.sh"
projection_headings() { awk -f "$SCRIPT_DIR/projection-headings.awk" "$1"; }
[ -f "$PROJECT_HELPER" ] || { echo 'ERROR: projection helper is missing' >&2; exit 2; }

die() { echo "ERROR: $*" >&2; exit 2; }
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
under() { case "$1" in "$2"|"$2"/*) return 0 ;; *) return 1 ;; esac; }

canonical_file() {
  local path="$1" parent physical
  [ -f "$path" ] && [ ! -L "$path" ] || return 1
  parent="$(cd -P "$(dirname "$path")" 2>/dev/null && pwd)" || return 1
  physical="$parent/$(basename "$path")"
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

tasks_structural_sha() {
  awk '
    NR == 1 && $0 == "---" { fm = 1 }
    fm && /^updated:/ { next }
    /^- \[[ xX]\] T[0-9][0-9][0-9] / { sub(/^- \[[ xX]\]/, "- [ ]") }
    { print }
    fm && NR > 1 && $0 == "---" { fm = 0 }
  ' "$1" | shasum -a 256 | awk '{print $1}'
}

completion_number() {
  printf '%s\n' "$1" | sed -E -n 's/^Task ([1-9][0-9]*): complete \(commits [0-9a-f]{7}\.\.[0-9a-f]{7}, (review clean|[1-9][0-9]* parked)\)$/\1/p'
}

validate_ledger_completions() {
  local ledger="$1" allowed="$2" output="$3" line number
  : > "$output"
  while IFS= read -r line; do
    case "$line" in
      Task\ *:\ complete*)
        number="$(completion_number "$line")"
        [ -n "$number" ] || return 1
        grep -Fqx -- "$number" "$allowed" || return 1
        ! grep -Fqx -- "$number" "$output" || return 1
        printf '%s\n' "$number" >> "$output"
        ;;
    esac
  done < "$ledger"
}

PROJECTION='' LEDGER='' TASKS=''
while [ $# -gt 0 ]; do
  case "$1" in
    --projection) [ $# -ge 2 ] || die 'missing projection'; PROJECTION="$2"; shift 2 ;;
    --ledger) [ $# -ge 2 ] || die 'missing ledger'; LEDGER="$2"; shift 2 ;;
    --tasks) [ $# -ge 2 ] || die 'missing tasks'; TASKS="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$PROJECTION" ] && [ -n "$LEDGER" ] && [ -n "$TASKS" ] || die 'all arguments are required'
PROJECTION="$(canonical_file "$PROJECTION")" || die 'projection is missing or symlinked'
LEDGER="$(canonical_file "$LEDGER")" || die 'ledger is missing or symlinked'
TASKS="$(canonical_file "$TASKS")" || die 'tasks is missing or symlinked'

IFS= read -r first < "$LEDGER" || die 'empty ledger'
[ "$first" = "# SDD ledger — plan: $PROJECTION" ] || die 'ledger projection identity mismatch'
[ "$(field "$PROJECTION" sdd_projection 2>/dev/null)" = maxi-v2 ] || die 'current execution requires v2; run ordinary projection to upgrade v1'
SPEC="$(field "$PROJECTION" source_spec 2>/dev/null)" || die 'projection has no source spec'
SPEC="$(canonical_file "$SPEC")" || die 'projection source spec is missing or noncanonical'
PLAN="$(field "$PROJECTION" source_plan 2>/dev/null)" || die 'projection has no source plan'
PLAN="$(canonical_file "$PLAN")" || die 'projection source plan is missing or noncanonical'
ROOT="$(git -C "$(dirname "$SPEC")" rev-parse --show-toplevel 2>/dev/null)" || die 'projection source spec is outside Git'
ROOT="$(cd -P "$ROOT" && pwd)"
under "$PROJECTION" "$ROOT/.superpowers/sdd" || die 'projection escapes the bound SDD workspace'
under "$TASKS" "$ROOT" || die 'tasks escape the bound worktree'
[ "$(dirname "$SPEC")" = "$(dirname "$PLAN")" ] || die 'projection source plan is outside the spec root'
expected_ledger="$ROOT/.superpowers/sdd/$(basename "$PROJECTION" .md)/progress.md"
[ "$LEDGER" = "$expected_ledger" ] || die 'ledger is outside the projection workspace'
projection_anchor_count="$(grep -c '^Maxi projection SHA256:' "$LEDGER" || true)"
projection_anchor_like="$(grep -c '^Maxi projection SHA256' "$LEDGER" || true)"
[ "$projection_anchor_count" -eq 1 ] && [ "$projection_anchor_like" -eq 1 ] || die 'ledger projection-byte anchor is missing or duplicated'
[ "$(grep '^Maxi projection SHA256:' "$LEDGER")" = "Maxi projection SHA256: $(sha "$PROJECTION")" ] || die 'ledger projection-byte anchor is malformed or mismatched'
[ "$(dirname "$SPEC")" = "$(dirname "$TASKS")" ] || die 'tasks do not belong to projection spec root'
[ "$(field "$PROJECTION" tasks_structural_sha256 2>/dev/null)" = "$(tasks_structural_sha "$TASKS")" ] || die 'tasks structural identity mismatch'
stored_body="$(field "$PROJECTION" projection_body_sha256 2>/dev/null)" || die 'projection body hash missing'
actual_body="$(awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm { print }' "$PROJECTION" | shasum -a 256 | awk '{print $1}')"
[ "$stored_body" = "$actual_body" ] || die 'projection body hash mismatch'
SLUG="$(field "$PROJECTION" slug 2>/dev/null)" || die 'projection slug is missing or duplicated'
STATE_FILE="$ROOT/.superpowers/sdd/active-$SLUG"
[ -f "$STATE_FILE" ] && [ ! -L "$STATE_FILE" ] || die 'active projection pointer is missing or symlinked'
[ "$(wc -l < "$STATE_FILE" | tr -d ' ')" -eq 1 ] || die 'active projection pointer is malformed'
IFS= read -r active_projection < "$STATE_FILE" || die 'active projection pointer is empty'
[ "$active_projection" = "$PROJECTION" ] || die 'reconciled projection is not active'
verified_projection="$(cd "$ROOT" && bash "$PROJECT_HELPER" --spec "$SPEC" --plan "$PLAN" --tasks "$TASKS" --output "$PROJECTION" --state-file "$STATE_FILE" --verify-only)" || die 'projection cannot be reconstructed from canonical sources and lineage'
[ "$verified_projection" = "$PROJECTION" ] || die 'projection reconstruction returned another identity'

TMP="$(mktemp -d "$(dirname "$TASKS")/.reconcile.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
MAP="$TMP/map"
projection_headings "$PROJECTION" > "$MAP"
map_count="$(wc -l < "$MAP" | tr -d ' ')"
[ "$(cut -d'|' -f1 "$MAP" | sort -u | wc -l | tr -d ' ')" -eq "$map_count" ] || die 'duplicate projected task number'
[ "$(cut -d'|' -f2 "$MAP" | sort -u | wc -l | tr -d ' ')" -eq "$map_count" ] || die 'duplicate projected Maxi id'

expected=1
while IFS='|' read -r number id; do
  [ "$number" -eq "$expected" ] || die 'projected task numbers are not sequential'
  expected=$((expected + 1))
done < "$MAP"

anchor_count="$(grep -c '^Maxi selection:' "$LEDGER" || true)"
anchor_like="$(grep -c '^Maxi selection' "$LEDGER" || true)"
[ "$anchor_count" -eq 1 ] && [ "$anchor_like" -eq 1 ] || die 'ledger selection anchor is missing or duplicated'
if [ "$map_count" -eq 0 ]; then
  expected_anchor='Maxi selection: none'
else
  expected_anchor="$(awk -F'|' 'BEGIN { printf "Maxi selection:" } { printf " %s", $2 } END { print "" }' "$MAP")"
fi
[ "$(grep '^Maxi selection:' "$LEDGER")" = "$expected_anchor" ] || die 'ledger selection anchor is malformed or mismatched'

COMPLETED="$TMP/completed"
: > "$COMPLETED"
cut -d'|' -f1 "$MAP" > "$TMP/allowed-numbers"
validate_ledger_completions "$LEDGER" "$TMP/allowed-numbers" "$TMP/completed-numbers" || die 'ledger completion record is malformed, duplicated, or unknown'
while IFS= read -r number; do
  id="$(awk -F'|' -v number="$number" '$1 == number { print $2 }' "$MAP")"
  [ -n "$id" ] || die "ledger completes unknown Task $number"
  printf '%s\n' "$id" >> "$COMPLETED"
done < "$TMP/completed-numbers"

awk -v completed="$COMPLETED" '
  BEGIN { while ((getline id < completed) > 0) done[id] = 1 }
  ($0 ~ /^- \[[^]]*\] T/ || $0 ~ /^[[:space:]]+- \[[^]]*\] T[0-9]/) && $0 !~ /^- \[[ xX]\] T[0-9][0-9][0-9] .+/ { bad = 1 }
  /^- \[[ xX]\] T[0-9][0-9][0-9] .+/ {
    id = substr($0, 7, 4)
    if (seen[id]++) bad = 1
    if (done[id] && substr($0, 1, 5) == "- [ ]") sub(/^- \[ \]/, "- [x]")
  }
  { print }
  END { if (bad) exit 2 }
' "$TASKS" > "$TMP/tasks" || die 'invalid tasks file'
mv "$TMP/tasks" "$TASKS"

pending="$(grep -c '^- \[ \] T[0-9][0-9][0-9] ' "$TASKS" || true)"
printf '%s\n' "$pending"
