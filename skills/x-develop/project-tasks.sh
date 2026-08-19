#!/usr/bin/env bash
# Build or verify one immutable Maxi-to-SDD task projection.
set -euo pipefail

LC_ALL=C
export LC_ALL

die() { echo "ERROR: $*" >&2; exit 2; }
sha() { shasum -a 256 "$1" | awk '{print $1}'; }

resolve_file() {
  local candidate="$1" link parent hops=0
  while [ -L "$candidate" ]; do
    hops=$((hops + 1)); [ "$hops" -le 40 ] || return 1
    link="$(readlink "$candidate")" || return 1
    case "$link" in /*) candidate="$link" ;; *) candidate="$(dirname "$candidate")/$link" ;; esac
  done
  [ -f "$candidate" ] || return 1
  parent="$(cd -P "$(dirname "$candidate")" 2>/dev/null && pwd)" || return 1
  printf '%s/%s\n' "$parent" "$(basename "$candidate")"
}

canonical_root() {
  local path="$1" root
  root="$(git -C "$(dirname "$path")" rev-parse --show-toplevel 2>/dev/null)" || return 1
  (cd -P "$root" && pwd)
}

under() { case "$1" in "$2"|"$2"/*) return 0 ;; *) return 1 ;; esac; }

frontmatter_value() {
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 { if ($0 == "---") fm = 1; next }
    fm && $0 == "---" { exit }
    fm && index($0, key ": ") == 1 { count++; value = substr($0, length(key) + 3) }
    END { if (count == 1) print value; else exit 1 }
  ' "$file"
}

marker_mode() {
  awk '
    NR == 1 { if ($0 != "---") exit 2; fm = 1; next }
    fm && $0 == "---" { fm = 0; closed = 1; next }
    fm && /^replay_contract:/ { count++; if ($0 == "replay_contract: bounded-v1") exact++ }
    END {
      if (!closed) exit 2
      if (count == 0) exit 4
      if (count == 1 && exact == 1) exit 0
      exit 2
    }
  ' "$1"
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

projection_field() {
  frontmatter_value "$1" "$2"
}

projection_body_sha() {
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { fm = 0; next }
    !fm { print }
  ' "$1" | shasum -a 256 | awk '{print $1}'
}

canonical_projection() {
  local input="$1" parent physical
  [ ! -L "$input" ] || return 1
  [ -f "$input" ] || return 1
  parent="$(cd -P "$(dirname "$input")" 2>/dev/null && pwd)" || return 1
  physical="$parent/$(basename "$input")"
  [ "$input" = "$physical" ] || return 1
  printf '%s\n' "$physical"
}

verify_projection() {
  local file="$1" expected_slug="$2" stored_body actual_body mode plan_hash tasks_hash
  local plan_revision tasks_revision expected_basename execution_mode task_sections
  canonical_projection "$file" >/dev/null || return 1
  [ "$(projection_field "$file" sdd_projection 2>/dev/null)" = maxi-v1 ] || return 1
  [ "$(projection_field "$file" slug 2>/dev/null)" = "$expected_slug" ] || return 1
  mode="$(projection_field "$file" mode 2>/dev/null)" || return 1
  plan_hash="$(projection_field "$file" source_plan_sha256 2>/dev/null)" || return 1
  tasks_hash="$(projection_field "$file" tasks_structural_sha256 2>/dev/null)" || return 1
  plan_revision="$(projection_field "$file" plan_revision 2>/dev/null)" || return 1
  tasks_revision="$(projection_field "$file" tasks_revision 2>/dev/null)" || return 1
  case "$plan_hash:$tasks_hash" in *[!0-9a-f:]*|*:|:*) return 1 ;; esac
  [ "${#plan_hash}" -eq 64 ] && [ "${#tasks_hash}" -eq 64 ] || return 1
  case "$mode" in
    marker-bound)
      case "$plan_revision:$tasks_revision" in *[!0-9:]*|0:*|*:0|'':*|*:'') return 1 ;; esac
      expected_basename="$expected_slug-p-r$plan_revision-$(printf '%s' "$plan_hash" | cut -c1-12)-t-r$tasks_revision-$(printf '%s' "$tasks_hash" | cut -c1-12)-sdd.md"
      ;;
    legacy)
      [ "$plan_revision" = legacy ] && [ "$tasks_revision" = legacy ] || return 1
      expected_basename="$expected_slug-p-legacy-$(printf '%s' "$plan_hash" | cut -c1-12)-t-legacy-$(printf '%s' "$tasks_hash" | cut -c1-12)-sdd.md"
      ;;
    *) return 1 ;;
  esac
  [ "$(basename "$file")" = "$expected_basename" ] || return 1
  execution_mode="$(projection_field "$file" execution_mode 2>/dev/null)" || return 1
  task_sections="$(grep -c '^### Task [1-9][0-9]*: T[0-9][0-9][0-9] ' "$file" || true)"
  case "$execution_mode" in
    ordinary) [ "$task_sections" -gt 0 ] || return 1 ;;
    final-review-only) [ "$task_sections" -eq 0 ] || return 1 ;;
    *) return 1 ;;
  esac
  stored_body="$(projection_field "$file" projection_body_sha256 2>/dev/null)" || return 1
  case "$stored_body" in *[!0-9a-f]*|'') return 1 ;; esac
  [ "${#stored_body}" -eq 64 ] || return 1
  actual_body="$(projection_body_sha "$file")"
  [ "$stored_body" = "$actual_body" ]
}

validate_lineage() {
  local current="$1" expected_slug="$2" expected_spec="$3" expected_root="$4" seen='|' predecessor source_plan
  while [ "$current" != null ]; do
    verify_projection "$current" "$expected_slug" || return 1
    under "$current" "$expected_root/.superpowers/sdd" || return 1
    [ "$(projection_field "$current" source_spec 2>/dev/null)" = "$expected_spec" ] || return 1
    source_plan="$(projection_field "$current" source_plan 2>/dev/null)" || return 1
    [ "$(resolve_file "$source_plan" 2>/dev/null)" = "$source_plan" ] || return 1
    [ "$(dirname "$source_plan")" = "$(dirname "$expected_spec")" ] || return 1
    case "$seen" in *"|$current|"*) return 1 ;; esac
    seen="$seen$current|"
    predecessor="$(projection_field "$current" predecessor_projection 2>/dev/null)" || return 1
    if [ "$predecessor" != null ]; then
      canonical_projection "$predecessor" >/dev/null || return 1
    fi
    current="$predecessor"
  done
}

ledger_completes_projection() {
  local projection="$1" root="$2" ledger expected completed
  ledger="$root/.superpowers/sdd/$(basename "$projection" .md)/progress.md"
  [ -f "$ledger" ] && [ ! -L "$ledger" ] || return 1
  IFS= read -r expected < "$ledger" || return 1
  [ "$expected" = "# SDD ledger — plan: $projection" ] || return 1
  while IFS= read -r number; do
    [ -n "$number" ] || continue
    completed="$(grep -c "^Task $number: complete$" "$ledger" || true)"
    [ "$completed" -eq 1 ] || return 1
  done < <(sed -n 's/^### Task \([1-9][0-9]*\): T[0-9][0-9][0-9] .*/\1/p' "$projection")
}

SPEC='' PLAN='' TASKS='' OUTPUT='' STATE=''
while [ $# -gt 0 ]; do
  case "$1" in
    --spec) [ $# -ge 2 ] || die 'missing --spec value'; SPEC="$2"; shift 2 ;;
    --plan) [ $# -ge 2 ] || die 'missing --plan value'; PLAN="$2"; shift 2 ;;
    --tasks) [ $# -ge 2 ] || die 'missing --tasks value'; TASKS="$2"; shift 2 ;;
    --output) [ $# -ge 2 ] || die 'missing --output value'; OUTPUT="$2"; shift 2 ;;
    --state-file) [ $# -ge 2 ] || die 'missing --state-file value'; STATE="$2"; shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done
[ -n "$SPEC" ] && [ -n "$PLAN" ] && [ -n "$TASKS" ] && [ -n "$OUTPUT" ] && [ -n "$STATE" ] || die 'all arguments are required'

SPEC="$(resolve_file "$SPEC")" || die 'spec.md is missing'
PLAN="$(resolve_file "$PLAN")" || die 'plan.md is missing'
TASKS="$(resolve_file "$TASKS")" || die 'tasks.md is missing'
[ "$(dirname "$SPEC")" = "$(dirname "$PLAN")" ] && [ "$(dirname "$SPEC")" = "$(dirname "$TASKS")" ] || die 'spec, plan, and tasks must be colocated'
ROOT="$(canonical_root "$SPEC")" || die 'spec is not in a Git worktree'
[ "$(canonical_root "$PLAN")" = "$ROOT" ] && [ "$(canonical_root "$TASKS")" = "$ROOT" ] || die 'source artifacts cross worktrees'
under "$SPEC" "$ROOT" && under "$PLAN" "$ROOT" && under "$TASKS" "$ROOT" || die 'source artifact escapes worktree'

SLUG="$(frontmatter_value "$SPEC" slug 2>/dev/null)" || die 'spec slug is missing or duplicated'
case "$SLUG" in ''|*[!A-Za-z0-9._-]*|.|..) die 'invalid spec slug' ;; esac
if marker_mode "$SPEC"; then MODE=marker-bound; else
  marker_status=$?
  [ "$marker_status" -eq 4 ] || die 'malformed replay_contract marker'
  MODE=legacy
fi

PLAN_HASH="$(sha "$PLAN")"
TASKS_HASH="$(tasks_structural_sha "$TASKS")"
PLAN12="$(printf '%s' "$PLAN_HASH" | cut -c1-12)"
TASKS12="$(printf '%s' "$TASKS_HASH" | cut -c1-12)"
if [ "$MODE" = marker-bound ]; then
  PLAN_REV="$(frontmatter_value "$PLAN" revision 2>/dev/null)" || die 'marker-bound plan revision is missing or duplicated'
  TASKS_REV="$(frontmatter_value "$TASKS" revision 2>/dev/null)" || die 'marker-bound tasks revision is missing or duplicated'
  case "$PLAN_REV:$TASKS_REV" in *[!0-9:]*|0:*|*:0|'':*|*:'') die 'marker-bound revisions must be positive integers' ;; esac
  BASENAME="$SLUG-p-r$PLAN_REV-$PLAN12-t-r$TASKS_REV-$TASKS12-sdd.md"
else
  PLAN_REV=legacy
  TASKS_REV=legacy
  BASENAME="$SLUG-p-legacy-$PLAN12-t-legacy-$TASKS12-sdd.md"
fi

[ ! -L "$OUTPUT" ] || die 'output final component is a symlink'
OUT_PARENT="$(cd -P "$(dirname "$OUTPUT")" 2>/dev/null && pwd)" || die 'output parent is missing'
under "$OUT_PARENT" "$ROOT/.superpowers/sdd" || die 'output must stay below .superpowers/sdd'
FINAL="$OUT_PARENT/$BASENAME"
[ ! -L "$FINAL" ] || die 'projection final component is a symlink'

[ ! -L "$STATE" ] || die 'state file is a symlink'
STATE_PARENT="$(cd -P "$(dirname "$STATE")" 2>/dev/null && pwd)" || die 'state parent is missing'
STATE="$STATE_PARENT/$(basename "$STATE")"
under "$STATE" "$ROOT/.superpowers/sdd" || die 'state file must stay below .superpowers/sdd'

PREDECESSOR=null
if [ -e "$STATE" ]; then
  [ -f "$STATE" ] || die 'state file is not regular'
  state_lines="$(wc -l < "$STATE" | tr -d ' ')"
  [ "$state_lines" -eq 1 ] || die 'state file must contain one line'
  IFS= read -r PREDECESSOR < "$STATE" || die 'cannot read state file'
  [ -n "$PREDECESSOR" ] || die 'empty active projection'
  canonical_projection "$PREDECESSOR" >/dev/null || die 'active projection is not canonical'
  validate_lineage "$PREDECESSOR" "$SLUG" "$SPEC" "$ROOT" || die 'active projection lineage is invalid'
fi

TMPDIR_LOCAL="$(mktemp -d "$OUT_PARENT/.project-tasks.XXXXXX")"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT
TASK_META="$TMPDIR_LOCAL/tasks.meta"

awk -v mode="$MODE" '
  function invalid(message) { print message > "/dev/stderr"; bad = 1 }
  /^- \[[^]]*\] T/ && $0 !~ /^- \[[ xX]\] T[0-9][0-9][0-9] .+/ { invalid("malformed task line: " $0); next }
  /^- \[[ xX]\] T[0-9][0-9][0-9] .+/ {
    state = substr($0, 4, 1)
    id = substr($0, 7, 4)
    if (seen[id]++) invalid("duplicate task id: " id)
    line = $0
    mapping = ""
    if (mode == "marker-bound") {
      copy = line
      if (copy !~ / \(plan Task [1-9][0-9]*\)$/) invalid("missing terminal plan mapping: " line)
      else {
        mapping = copy
        sub(/^.* \(plan Task /, "", mapping)
        sub(/\)$/, "", mapping)
        sub(/ \(plan Task [1-9][0-9]*\)$/, "", copy)
        if (copy ~ /\(plan Task /) invalid("duplicate plan mapping: " line)
      }
      line = copy
    }
    print state "\t" id "\t" mapping "\t" line
    count++
  }
  END { if (count == 0) invalid("no canonical tasks"); if (bad) exit 2 }
' "$TASKS" > "$TASK_META" || die 'invalid tasks.md'

task_count="$(wc -l < "$TASK_META" | tr -d ' ')"
sorted_ids="$(cut -f2 "$TASK_META" | sort)"
i=1
while [ "$i" -le "$task_count" ]; do
  expected="$(printf 'T%03d' "$i")"
  printf '%s\n' "$sorted_ids" | grep -Fqx "$expected" || die "missing sequential task id: $expected"
  i=$((i + 1))
done

PLAN_PARTS="$TMPDIR_LOCAL/plan"
mkdir "$PLAN_PARTS"
awk -v dir="$PLAN_PARTS" '
  function fence_kind(line) {
    if (line ~ /^[[:space:]]*```/) return "backtick"
    if (line ~ /^[[:space:]]*~~~/) return "tilde"
    return ""
  }
  function task_number(line, value) {
    value = line
    sub(/^#+[[:space:]]+Task[[:space:]]+/, "", value)
    sub(/[^0-9].*$/, "", value)
    return value
  }
  {
    kind = fence_kind($0)
    if (kind != "") {
      if (fence == "") fence = kind
      else if (fence == kind) fence = ""
    }
    if (fence == "" && $0 ~ /^#+[[:space:]]+Task[[:space:]]+[1-9][0-9]*([^0-9]|$)/) {
      section++
      number = task_number($0)
      print number > (dir "/order")
      print $0 > (dir "/heading-" section)
      next
    }
    if (section == 0) print > (dir "/preamble")
    else print > (dir "/body-" section)
  }
  END { if (section == 0) exit 2 }
' "$PLAN" || die 'plan has no executable Task heading'

if [ "$MODE" = marker-bound ]; then
  plan_count="$(wc -l < "$PLAN_PARTS/order" | tr -d ' ')"
  [ "$plan_count" -eq "$task_count" ] || die 'plan/task mapping is not bijective'
  [ "$(sort -u "$PLAN_PARTS/order" | wc -l | tr -d ' ')" -eq "$plan_count" ] || die 'duplicate source plan task number'
  while IFS= read -r mapping; do
    [ -n "$mapping" ] || die 'missing mapping'
    [ "$(cut -f3 "$TASK_META" | grep -cx "$mapping" || true)" -eq 1 ] || die "mapping is not bijective: Task $mapping"
  done < "$PLAN_PARTS/order"
fi

unchecked="$(awk -F '\t' '$1 == " " { count++ } END { print count + 0 }' "$TASK_META")"
EXECUTION_MODE=ordinary
if [ "$unchecked" -eq 0 ]; then
  if [ "$PREDECESSOR" != null ]; then
    [ "$PREDECESSOR" = "$FINAL" ] || die 'all-checked structural correction cannot skip review evidence'
    ledger_completes_projection "$PREDECESSOR" "$ROOT" || die 'active ledger does not complete the projection'
  elif [ -e "$FINAL" ]; then
    verify_projection "$FINAL" "$SLUG" || die 'existing projection is invalid'
    ledger_completes_projection "$FINAL" "$ROOT" || die 'existing ledger does not complete the projection'
  else
    EXECUTION_MODE=final-review-only
  fi
fi

if [ -e "$FINAL" ]; then
  [ -f "$FINAL" ] || die 'projection path is not regular'
  verify_projection "$FINAL" "$SLUG" || die 'existing projection failed integrity validation'
  validate_lineage "$FINAL" "$SLUG" "$SPEC" "$ROOT" || die 'existing projection lineage is invalid'
  [ "$(projection_field "$FINAL" source_spec)" = "$SPEC" ] || die 'existing projection spec mismatch'
  [ "$(projection_field "$FINAL" source_plan)" = "$PLAN" ] || die 'existing projection plan mismatch'
  [ "$(projection_field "$FINAL" source_plan_sha256)" = "$PLAN_HASH" ] || die 'existing projection plan hash mismatch'
  [ "$(projection_field "$FINAL" tasks_structural_sha256)" = "$TASKS_HASH" ] || die 'existing projection tasks hash mismatch'
  [ "$(projection_field "$FINAL" mode)" = "$MODE" ] || die 'existing projection mode mismatch'
  if [ "$PREDECESSOR" != null ] && [ "$PREDECESSOR" != "$FINAL" ]; then
    die 'active projection disagrees with existing current identity'
  fi
else
  [ "$unchecked" -gt 0 ] || [ "$EXECUTION_MODE" = final-review-only ] || die 'cannot create an all-checked successor'
  BODY="$TMPDIR_LOCAL/body"
  : > "$BODY"
  cat "$PLAN_PARTS/preamble" >> "$BODY"
  if [ "$MODE" = marker-bound ]; then
    projected=0
    section=0
    while IFS= read -r source_number; do
      section=$((section + 1))
      row="$(awk -F '\t' -v number="$source_number" '$3 == number { print; exit }' "$TASK_META")"
      [ -n "$row" ] || die "unmapped source Task $source_number"
      state="$(printf '%s\n' "$row" | cut -f1)"
      [ "$state" = ' ' ] || continue
      id="$(printf '%s\n' "$row" | cut -f2)"
      line="$(printf '%s\n' "$row" | cut -f4-)"
      description="${line#- [ ] $id }"
      projected=$((projected + 1))
      body_file="$PLAN_PARTS/body-$section"
      backticks="$(grep -c '^[[:space:]]*```' "$body_file" 2>/dev/null || true)"
      tildes="$(grep -c '^[[:space:]]*~~~' "$body_file" 2>/dev/null || true)"
      [ "$backticks" -eq 0 ] || [ "$tildes" -eq 0 ] || die "ambiguous fence collision in source Task $source_number"
      printf '\n### Task %s: %s %s\n' "$projected" "$id" "$description" >> "$BODY"
      sed -E 's/^[[:space:]]*~~~+/```/' "$body_file" >> "$BODY"
    done < "$PLAN_PARTS/order"
  else
    projected=0
    while IFS=$'\t' read -r state id mapping line; do
      [ "$state" = ' ' ] || continue
      projected=$((projected + 1))
      description="${line#- [ ] $id }"
      printf '\n### Task %s: %s %s\n\n%s\n' "$projected" "$id" "$description" "$line" >> "$BODY"
    done < "$TASK_META"
  fi
  BODY_HASH="$(sha "$BODY")"
  TEMP_PROJECTION="$(mktemp "$OUT_PARENT/.projection.XXXXXX")"
  {
    echo '---'
    echo 'sdd_projection: maxi-v1'
    echo "slug: $SLUG"
    echo "mode: $MODE"
    echo "execution_mode: $EXECUTION_MODE"
    echo "source_spec: $SPEC"
    echo "source_plan: $PLAN"
    echo "source_plan_sha256: $PLAN_HASH"
    echo "tasks_structural_sha256: $TASKS_HASH"
    echo "plan_revision: $PLAN_REV"
    echo "tasks_revision: $TASKS_REV"
    echo "predecessor_projection: $PREDECESSOR"
    echo "projection_body_sha256: $BODY_HASH"
    echo '---'
    cat "$BODY"
  } > "$TEMP_PROJECTION"
  mv "$TEMP_PROJECTION" "$FINAL"
  verify_projection "$FINAL" "$SLUG" || die 'new projection failed integrity validation'
fi

STATE_TEMP="$(mktemp "$STATE_PARENT/.active-projection.XXXXXX")"
printf '%s\n' "$FINAL" > "$STATE_TEMP"
mv "$STATE_TEMP" "$STATE"
printf '%s\n' "$FINAL"
