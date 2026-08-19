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
  local projection="$1" root="$2" ledger expected anchored
  ledger="$root/.superpowers/sdd/$(basename "$projection" .md)/progress.md"
  [ -f "$ledger" ] && [ ! -L "$ledger" ] || return 1
  IFS= read -r expected < "$ledger" || return 1
  [ "$expected" = "# SDD ledger — plan: $projection" ] || return 1
  anchored="$TMPDIR_LOCAL/ledger-completion-anchor"
  validate_selection_anchor "$projection" "$root" "$anchored" || return 1
  while IFS= read -r number; do
    [ -n "$number" ] || continue
    grep -Fqx -- "$number" "${anchored}.completions" || return 1
  done < <(sed -n 's/^### Task \([1-9][0-9]*\): T[0-9][0-9][0-9] .*/\1/p' "$projection")
}

lineage_completed_ids() {
  local current="$1" root="$2" output="$3" ledger first map number id anchor
  : > "$output"
  while [ "$current" != null ]; do
    ledger="$root/.superpowers/sdd/$(basename "$current" .md)/progress.md"
    [ -f "$ledger" ] && [ ! -L "$ledger" ] || return 1
    IFS= read -r first < "$ledger" || return 1
    [ "$first" = "# SDD ledger — plan: $current" ] || return 1
    anchor="${output}.anchor"
    validate_selection_anchor "$current" "$root" "$anchor" || return 1
    number=0
    while IFS= read -r id; do
      number=$((number + 1))
      if grep -Fqx -- "$number" "${anchor}.completions" && ! grep -Fqx -- "$id" "$output"; then
        printf '%s\n' "$id" >> "$output"
      fi
    done < "$anchor"
    current="$(projection_field "$current" predecessor_projection 2>/dev/null)" || return 1
  done
}

validate_selection_anchor() {
  local projection="$1" root="$2" output="$3" ledger line anchor_count anchor_like headings numbers
  ledger="$root/.superpowers/sdd/$(basename "$projection" .md)/progress.md"
  [ -f "$ledger" ] && [ ! -L "$ledger" ] || return 1
  IFS= read -r line < "$ledger" || return 1
  [ "$line" = "# SDD ledger — plan: $projection" ] || return 1
  anchor_count="$(grep -c '^Maxi selection:' "$ledger" || true)"
  anchor_like="$(grep -c '^Maxi selection' "$ledger" || true)"
  [ "$anchor_count" -eq 1 ] && [ "$anchor_like" -eq 1 ] || return 1
  line="$(grep '^Maxi selection:' "$ledger")"
  : > "$output"
  if [ "$line" != 'Maxi selection: none' ]; then
    printf '%s\n' "$line" | grep -Eq '^Maxi selection: T[0-9][0-9][0-9]( T[0-9][0-9][0-9])*$' || return 1
    printf '%s\n' "${line#Maxi selection: }" | tr ' ' '\n' > "$output"
    [ "$(sort -u "$output" | wc -l | tr -d ' ')" -eq "$(wc -l < "$output" | tr -d ' ')" ] || return 1
  fi
  headings="${output}.headings"
  sed -n 's/^### Task [1-9][0-9]*: \(T[0-9][0-9][0-9]\) .*/\1/p' "$projection" > "$headings"
  cmp -s "$output" "$headings" || return 1
  numbers="${output}.numbers"
  sed -n 's/^### Task \([1-9][0-9]*\): T[0-9][0-9][0-9] .*/\1/p' "$projection" > "$numbers"
  validate_ledger_completions "$ledger" "$numbers" "${output}.completions"
}

write_selection_ledger() {
  local projection="$1" selected="$2" output="$3" anchor
  if [ -s "$selected" ]; then
    anchor="$(awk 'BEGIN { printf "Maxi selection:" } { printf " %s", $0 } END { print "" }' "$selected")"
  else
    anchor='Maxi selection: none'
  fi
  {
    printf '# SDD ledger — plan: %s\n' "$projection"
    printf '%s\n' "$anchor"
  } > "$output"
}

SPEC='' PLAN='' TASKS='' OUTPUT='' STATE='' VERIFY_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --spec) [ $# -ge 2 ] || die 'missing --spec value'; SPEC="$2"; shift 2 ;;
    --plan) [ $# -ge 2 ] || die 'missing --plan value'; PLAN="$2"; shift 2 ;;
    --tasks) [ $# -ge 2 ] || die 'missing --tasks value'; TASKS="$2"; shift 2 ;;
    --output) [ $# -ge 2 ] || die 'missing --output value'; OUTPUT="$2"; shift 2 ;;
    --state-file) [ $# -ge 2 ] || die 'missing --state-file value'; STATE="$2"; shift 2 ;;
    --verify-only) VERIFY_ONLY=1; shift ;;
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
    sub(/^- \[[ xX]\]/, "- [ ]", line)
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

render_body() {
  local selected="$1" output="$2" projected=0 section=0 source_number row id line description body_file backticks tildes state mapping
  : > "$output"
  cat "$PLAN_PARTS/preamble" >> "$output"
  if [ "$MODE" = marker-bound ]; then
    while IFS= read -r source_number; do
      section=$((section + 1))
      row="$(awk -F '\t' -v number="$source_number" '$3 == number { print; exit }' "$TASK_META")"
      [ -n "$row" ] || die "unmapped source Task $source_number"
      id="$(printf '%s\n' "$row" | cut -f2)"
      grep -Fqx -- "$id" "$selected" || continue
      line="$(printf '%s\n' "$row" | cut -f4-)"
      description="${line#- [ ] $id }"
      projected=$((projected + 1))
      body_file="$PLAN_PARTS/body-$section"
      backticks="$(grep -c '^[[:space:]]*```' "$body_file" 2>/dev/null || true)"
      tildes="$(grep -c '^[[:space:]]*~~~' "$body_file" 2>/dev/null || true)"
      [ "$backticks" -eq 0 ] || [ "$tildes" -eq 0 ] || die "ambiguous fence collision in source Task $source_number"
      printf '\n### Task %s: %s %s\n' "$projected" "$id" "$description" >> "$output"
      sed -E -e 's/^[[:space:]]*```+/```/' -e 's/^[[:space:]]*~~~+/```/' "$body_file" >> "$output"
    done < "$PLAN_PARTS/order"
  else
    while IFS=$'\t' read -r state id mapping line; do
      grep -Fqx -- "$id" "$selected" || continue
      projected=$((projected + 1))
      description="${line#- [ ] $id }"
      printf '\n### Task %s: %s %s\n\n%s\n' "$projected" "$id" "$description" "$line" >> "$output"
    done < "$TASK_META"
  fi
}

write_expected_projection() {
  local output="$1" body="$2" execution_mode="$3" predecessor="$4" body_hash
  body_hash="$(sha "$body")"
  {
    echo '---'
    echo 'sdd_projection: maxi-v1'
    echo "slug: $SLUG"
    echo "mode: $MODE"
    echo "execution_mode: $execution_mode"
    echo "source_spec: $SPEC"
    echo "source_plan: $PLAN"
    echo "source_plan_sha256: $PLAN_HASH"
    echo "tasks_structural_sha256: $TASKS_HASH"
    echo "plan_revision: $PLAN_REV"
    echo "tasks_revision: $TASKS_REV"
    echo "predecessor_projection: $predecessor"
    echo "projection_body_sha256: $body_hash"
    echo '---'
    cat "$body"
  } > "$output"
}

unchecked="$(awk -F '\t' '$1 == " " { count++ } END { print count + 0 }' "$TASK_META")"
SELECTED_IDS="$TMPDIR_LOCAL/selected"
ANCHORED_IDS="$TMPDIR_LOCAL/anchored"
COMPLETED_IDS="$TMPDIR_LOCAL/predecessor-completed"
: > "$SELECTED_IDS"
: > "$ANCHORED_IDS"
: > "$COMPLETED_IDS"

if [ -e "$FINAL" ]; then
  [ -f "$FINAL" ] || die 'projection path is not regular'
  verify_projection "$FINAL" "$SLUG" || die 'existing projection failed integrity validation'
  validate_lineage "$FINAL" "$SLUG" "$SPEC" "$ROOT" || die 'existing projection lineage is invalid'
  if [ "$PREDECESSOR" != null ] && [ "$PREDECESSOR" != "$FINAL" ]; then
    die 'active projection disagrees with existing current identity'
  fi
  PROJECT_PREDECESSOR="$(projection_field "$FINAL" predecessor_projection)" || die 'existing predecessor is missing'
  EXECUTION_MODE="$(projection_field "$FINAL" execution_mode)" || die 'existing execution mode is missing'
  validate_selection_anchor "$FINAL" "$ROOT" "$ANCHORED_IDS" || die 'current ledger selection anchor is missing, malformed, duplicated, or mismatched'
  if [ "$PROJECT_PREDECESSOR" != null ]; then
    lineage_completed_ids "$PROJECT_PREDECESSOR" "$ROOT" "$COMPLETED_IDS" || die 'predecessor ledger lineage is invalid'
    while IFS=$'\t' read -r state id mapping line; do
      grep -Fqx -- "$id" "$COMPLETED_IDS" || printf '%s\n' "$id" >> "$SELECTED_IDS"
    done < "$TASK_META"
  else
    cp "$ANCHORED_IDS" "$SELECTED_IDS"
  fi
  [ "$(sort -u "$SELECTED_IDS" | wc -l | tr -d ' ')" -eq "$(wc -l < "$SELECTED_IDS" | tr -d ' ')" ] || die 'existing projection repeats a Maxi task'
  while IFS= read -r id; do
    [ "$(cut -f2 "$TASK_META" | grep -Fcx -- "$id" || true)" -eq 1 ] || die "existing projection names unknown task: $id"
  done < "$SELECTED_IDS"
  if [ "$PROJECT_PREDECESSOR" != null ]; then
    while IFS=$'\t' read -r state id mapping line; do
      if grep -Fqx -- "$id" "$COMPLETED_IDS"; then
        ! grep -Fqx -- "$id" "$SELECTED_IDS" || die "successor reprojects completed task: $id"
      else
        grep -Fqx -- "$id" "$SELECTED_IDS" || die "successor omits uncompleted task: $id"
      fi
    done < "$TASK_META"
  else
    while IFS=$'\t' read -r state id mapping line; do
      [ "$state" != ' ' ] || grep -Fqx -- "$id" "$SELECTED_IDS" || die "initial projection omits pending task: $id"
    done < "$TASK_META"
  fi
  selected_count="$(wc -l < "$SELECTED_IDS" | tr -d ' ')"
  case "$EXECUTION_MODE" in
    ordinary) [ "$selected_count" -gt 0 ] || die 'ordinary projection has no tasks' ;;
    final-review-only) [ "$selected_count" -eq 0 ] || die 'final-review-only projection has tasks' ;;
    *) die 'unknown existing execution mode' ;;
  esac
  [ "$unchecked" -gt 0 ] || [ "$EXECUTION_MODE" = final-review-only ] || ledger_completes_projection "$FINAL" "$ROOT" || die 'existing ledger does not complete the projection'
else
  PROJECT_PREDECESSOR="$PREDECESSOR"
  if [ "$PROJECT_PREDECESSOR" != null ]; then
    lineage_completed_ids "$PROJECT_PREDECESSOR" "$ROOT" "$COMPLETED_IDS" || die 'predecessor ledger lineage is invalid'
  fi
  while IFS=$'\t' read -r state id mapping line; do
    if [ "$PROJECT_PREDECESSOR" != null ]; then
      grep -Fqx -- "$id" "$COMPLETED_IDS" || printf '%s\n' "$id" >> "$SELECTED_IDS"
    elif [ "$state" = ' ' ]; then
      printf '%s\n' "$id" >> "$SELECTED_IDS"
    fi
  done < "$TASK_META"
  selected_count="$(wc -l < "$SELECTED_IDS" | tr -d ' ')"
  if [ "$selected_count" -eq 0 ]; then
    [ "$PROJECT_PREDECESSOR" = null ] || die 'all-checked structural correction cannot skip review evidence'
    EXECUTION_MODE=final-review-only
  else
    EXECUTION_MODE=ordinary
  fi
fi

UNORDERED_IDS="$TMPDIR_LOCAL/selected-unordered"
cp "$SELECTED_IDS" "$UNORDERED_IDS"
: > "$SELECTED_IDS"
if [ "$MODE" = marker-bound ]; then
  while IFS= read -r source_number; do
    id="$(awk -F '\t' -v number="$source_number" '$3 == number { print $2; exit }' "$TASK_META")"
    grep -Fqx -- "$id" "$UNORDERED_IDS" && printf '%s\n' "$id" >> "$SELECTED_IDS"
  done < "$PLAN_PARTS/order"
else
  while IFS=$'\t' read -r state id mapping line; do
    grep -Fqx -- "$id" "$UNORDERED_IDS" && printf '%s\n' "$id" >> "$SELECTED_IDS"
  done < "$TASK_META"
fi
if [ -e "$FINAL" ] && [ "$PROJECT_PREDECESSOR" != null ]; then
  cmp -s "$SELECTED_IDS" "$ANCHORED_IDS" || die 'successor selection anchor disagrees with predecessor completion lineage'
fi

BODY="$TMPDIR_LOCAL/body"
EXPECTED_PROJECTION="$TMPDIR_LOCAL/expected-projection"
render_body "$SELECTED_IDS" "$BODY"
write_expected_projection "$EXPECTED_PROJECTION" "$BODY" "$EXECUTION_MODE" "$PROJECT_PREDECESSOR"

if [ -e "$FINAL" ]; then
  cmp -s "$EXPECTED_PROJECTION" "$FINAL" || die 'existing projection differs from canonical source reconstruction'
else
  WORKSPACE="$ROOT/.superpowers/sdd/$(basename "$FINAL" .md)"
  [ ! -L "$WORKSPACE" ] || die 'projection workspace is a symlink'
  mkdir -p "$WORKSPACE"
  LEDGER="$WORKSPACE/progress.md"
  [ ! -e "$LEDGER" ] && [ ! -L "$LEDGER" ] || die 'fresh projection workspace already has a ledger'
  TEMP_LEDGER="$(mktemp "$WORKSPACE/.progress.XXXXXX")"
  write_selection_ledger "$FINAL" "$SELECTED_IDS" "$TEMP_LEDGER"
  TEMP_PROJECTION="$(mktemp "$OUT_PARENT/.projection.XXXXXX")"
  cp "$EXPECTED_PROJECTION" "$TEMP_PROJECTION"
  mv "$TEMP_PROJECTION" "$FINAL"
  mv "$TEMP_LEDGER" "$LEDGER"
  verify_projection "$FINAL" "$SLUG" || die 'new projection failed integrity validation'
  validate_selection_anchor "$FINAL" "$ROOT" "$ANCHORED_IDS" || die 'new projection selection anchor failed validation'
fi

if [ "$VERIFY_ONLY" -eq 0 ]; then
  STATE_TEMP="$(mktemp "$STATE_PARENT/.active-projection.XXXXXX")"
  printf '%s\n' "$FINAL" > "$STATE_TEMP"
  mv "$STATE_TEMP" "$STATE"
fi
printf '%s\n' "$FINAL"
