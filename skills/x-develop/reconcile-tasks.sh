#!/usr/bin/env bash
# Reconcile completed upstream SDD tasks back to Maxi checkbox state.
set -euo pipefail

LC_ALL=C
export LC_ALL

die() { echo "ERROR: $*" >&2; exit 2; }
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
[ "$(field "$PROJECTION" sdd_projection 2>/dev/null)" = maxi-v1 ] || die 'invalid projection contract'
SPEC="$(field "$PROJECTION" source_spec 2>/dev/null)" || die 'projection has no source spec'
SPEC="$(canonical_file "$SPEC")" || die 'projection source spec is missing or noncanonical'
ROOT="$(git -C "$(dirname "$SPEC")" rev-parse --show-toplevel 2>/dev/null)" || die 'projection source spec is outside Git'
ROOT="$(cd -P "$ROOT" && pwd)"
under "$PROJECTION" "$ROOT/.superpowers/sdd" || die 'projection escapes the bound SDD workspace'
under "$TASKS" "$ROOT" || die 'tasks escape the bound worktree'
expected_ledger="$ROOT/.superpowers/sdd/$(basename "$PROJECTION" .md)/progress.md"
[ "$LEDGER" = "$expected_ledger" ] || die 'ledger is outside the projection workspace'
[ "$(dirname "$SPEC")" = "$(dirname "$TASKS")" ] || die 'tasks do not belong to projection spec root'
[ "$(field "$PROJECTION" tasks_structural_sha256 2>/dev/null)" = "$(tasks_structural_sha "$TASKS")" ] || die 'tasks structural identity mismatch'
stored_body="$(field "$PROJECTION" projection_body_sha256 2>/dev/null)" || die 'projection body hash missing'
actual_body="$(awk 'NR == 1 && $0 == "---" { fm = 1; next } fm && $0 == "---" { fm = 0; next } !fm { print }' "$PROJECTION" | shasum -a 256 | awk '{print $1}')"
[ "$stored_body" = "$actual_body" ] || die 'projection body hash mismatch'

TMP="$(mktemp -d "$(dirname "$TASKS")/.reconcile.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
MAP="$TMP/map"
sed -n 's/^### Task \([1-9][0-9]*\): \(T[0-9][0-9][0-9]\) .*/\1|\2/p' "$PROJECTION" > "$MAP"
map_count="$(wc -l < "$MAP" | tr -d ' ')"
[ "$(cut -d'|' -f1 "$MAP" | sort -u | wc -l | tr -d ' ')" -eq "$map_count" ] || die 'duplicate projected task number'
[ "$(cut -d'|' -f2 "$MAP" | sort -u | wc -l | tr -d ' ')" -eq "$map_count" ] || die 'duplicate projected Maxi id'

expected=1
while IFS='|' read -r number id; do
  [ "$number" -eq "$expected" ] || die 'projected task numbers are not sequential'
  expected=$((expected + 1))
done < "$MAP"

COMPLETED="$TMP/completed"
: > "$COMPLETED"
while IFS= read -r line; do
  case "$line" in
    Task\ *:\ complete)
      number="${line#Task }"; number="${number%: complete}"
      case "$number" in ''|*[!0-9]*|0) die 'malformed completed ledger entry' ;; esac
      id="$(awk -F'|' -v number="$number" '$1 == number { print $2 }' "$MAP")"
      [ -n "$id" ] || die "ledger completes unknown Task $number"
      grep -Fqx "$id" "$COMPLETED" || printf '%s\n' "$id" >> "$COMPLETED"
      ;;
  esac
done < "$LEDGER"

awk -v completed="$COMPLETED" '
  BEGIN { while ((getline id < completed) > 0) done[id] = 1 }
  /^- \[[^]]*\] T/ && $0 !~ /^- \[[ xX]\] T[0-9][0-9][0-9] .+/ { bad = 1 }
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
