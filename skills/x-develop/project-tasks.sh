#!/usr/bin/env bash
# Build or verify one immutable Maxi-to-SDD task projection.
set -euo pipefail

LC_ALL=C
export LC_ALL

SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd)"
projection_headings() { awk -f "$SCRIPT_DIR/projection-headings.awk" "$1"; }

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
  local file="$1" expected_slug="$2" stored_body actual_body plan_hash tasks_hash
  local expected_basename execution_mode task_sections version version_suffix
  canonical_projection "$file" >/dev/null || return 1
  version="$(projection_field "$file" sdd_projection 2>/dev/null)" || return 1
  case "$version" in maxi-v1) version_suffix='' ;; maxi-v2) version_suffix=-v2 ;; *) return 1 ;; esac
  [ "$(projection_field "$file" slug 2>/dev/null)" = "$expected_slug" ] || return 1
  plan_hash="$(projection_field "$file" source_plan_sha256 2>/dev/null)" || return 1
  tasks_hash="$(projection_field "$file" tasks_structural_sha256 2>/dev/null)" || return 1
  case "$plan_hash:$tasks_hash" in *[!0-9a-f:]*|*:|:*) return 1 ;; esac
  [ "${#plan_hash}" -eq 64 ] && [ "${#tasks_hash}" -eq 64 ] || return 1
  expected_basename="$expected_slug$version_suffix-p-$(printf '%s' "$plan_hash" | cut -c1-12)-t-$(printf '%s' "$tasks_hash" | cut -c1-12)-sdd.md"
  [ "$(basename "$file")" = "$expected_basename" ] || return 1
  execution_mode="$(projection_field "$file" execution_mode 2>/dev/null)" || return 1
  task_sections="$(projection_headings "$file" | wc -l | tr -d ' ')"
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
    validate_projection_anchor "$current" "$expected_root" || return 1
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

validate_projection_anchor() {
  local projection="$1" root="$2" ledger count like line
  ledger="$root/.superpowers/sdd/$(basename "$projection" .md)/progress.md"
  [ -f "$ledger" ] && [ ! -L "$ledger" ] || return 1
  count="$(grep -c '^Maxi projection SHA256:' "$ledger" || true)"
  like="$(grep -c '^Maxi projection SHA256' "$ledger" || true)"
  [ "$count" -eq 1 ] && [ "$like" -eq 1 ] || return 1
  line="$(grep '^Maxi projection SHA256:' "$ledger")"
  printf '%s\n' "$line" | grep -Eq '^Maxi projection SHA256: [0-9a-f]{64}$' || return 1
  [ "$line" = "Maxi projection SHA256: $(sha "$projection")" ]
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
  done < <(projection_headings "$projection" | cut -d'|' -f1)
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
  validate_projection_anchor "$projection" "$root" || return 1
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
  projection_headings "$projection" | cut -d'|' -f2 > "$headings"
  cmp -s "$output" "$headings" || return 1
  numbers="${output}.numbers"
  projection_headings "$projection" | cut -d'|' -f1 > "$numbers"
  validate_ledger_completions "$ledger" "$numbers" "${output}.completions"
}

write_selection_ledger() {
  local projection="$1" selected="$2" output="$3" projection_bytes="$4" anchor
  if [ -s "$selected" ]; then
    anchor="$(awk 'BEGIN { printf "Maxi selection:" } { printf " %s", $0 } END { print "" }' "$selected")"
  else
    anchor='Maxi selection: none'
  fi
  {
    printf '# SDD ledger — plan: %s\n' "$projection"
    printf '%s\n' "$anchor"
    printf 'Maxi projection SHA256: %s\n' "$(sha "$projection_bytes")"
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

[ "$(tail -c 1 "$PLAN" | wc -l | tr -d ' ')" -eq 1 ] || die 'plan.md must end with a newline (LF); add it so task-brief preserves the final payload line'

PLAN_HASH="$(sha "$PLAN")"
TASKS_HASH="$(tasks_structural_sha "$TASKS")"
PLAN12="$(printf '%s' "$PLAN_HASH" | cut -c1-12)"
TASKS12="$(printf '%s' "$TASKS_HASH" | cut -c1-12)"
BASENAME="$SLUG-v2-p-$PLAN12-t-$TASKS12-sdd.md"

for component in "$ROOT/.superpowers" "$ROOT/.superpowers/sdd"; do
  [ ! -L "$component" ] || die 'SDD base component is a symlink'
  [ ! -e "$component" ] || [ -d "$component" ] || die 'SDD base component is not a directory'
  if [ ! -d "$component" ]; then
    [ "$VERIFY_ONLY" -eq 0 ] || die 'verify-only requires existing v2 evidence; run ordinary projection first'
    mkdir "$component" || die 'cannot create SDD base'
  fi
  [ "$(cd -P "$component" && pwd)" = "$component" ] || die 'SDD base escapes physical worktree'
done

[ ! -L "$OUTPUT" ] || die 'output final component is a symlink'
OUTPUT_PARENT_INPUT="$(dirname "$OUTPUT")"
if [ ! -e "$OUTPUT_PARENT_INPUT" ] && [ ! -L "$OUTPUT_PARENT_INPUT" ]; then
  SDD_PARENT="$(cd -P "$ROOT/.superpowers/sdd" 2>/dev/null && pwd)" || die 'output parent is missing'
  [ "$SDD_PARENT" = "$ROOT/.superpowers/sdd" ] || die 'output parent escapes the physical SDD root'
  [ "$OUTPUT_PARENT_INPUT" = "$SDD_PARENT/projections" ] || die 'output parent is missing'
  [ "$VERIFY_ONLY" -eq 0 ] || die 'verify-only requires existing v2 evidence; run ordinary projection first'
  mkdir "$OUTPUT_PARENT_INPUT" || die 'cannot create canonical projections directory'
fi
OUT_PARENT="$(cd -P "$(dirname "$OUTPUT")" 2>/dev/null && pwd)" || die 'output parent is missing'
under "$OUT_PARENT" "$ROOT/.superpowers/sdd" || die 'output must stay below .superpowers/sdd'
PROJECTIONS_PARENT="$(cd -P "$ROOT/.superpowers/sdd/projections" 2>/dev/null && pwd)" || die 'canonical projections directory is missing'
[ "$PROJECTIONS_PARENT" = "$ROOT/.superpowers/sdd/projections" ] || die 'canonical projections directory escapes the physical SDD root'
FINAL="$OUT_PARENT/$BASENAME"
[ ! -L "$FINAL" ] || die 'projection final component is a symlink'

[ ! -L "$STATE" ] || die 'state file is a symlink'
STATE_PARENT="$(cd -P "$(dirname "$STATE")" 2>/dev/null && pwd)" || die 'state parent is missing'
STATE="$STATE_PARENT/$(basename "$STATE")"
under "$STATE" "$ROOT/.superpowers/sdd" || die 'state file must stay below .superpowers/sdd'

WORKSPACE="$ROOT/.superpowers/sdd/$(basename "$FINAL" .md)"
if [ ! -e "$STATE" ]; then
  for orphan in "$PROJECTIONS_PARENT"/*; do
    [ -e "$orphan" ] || [ -L "$orphan" ] || continue
    orphan_name="$(basename "$orphan")"
    case "$orphan_name" in
      "$SLUG"-p-*|"$SLUG"-v2-p-*)
        orphan_identity="${orphan_name#"$SLUG-"}"
        orphan_identity="${orphan_identity#v2-}"
        orphan_identity="${orphan_identity#p-}"
        printf '%s\n' "$orphan_identity" | grep -Eq '^[0-9a-f]{12}-t-[0-9a-f]{12}-sdd\.md$' && die 'orphan projection or workspace exists without active pointer'
        ;;
    esac
  done
  for orphan in "$ROOT/.superpowers/sdd"/*; do
    [ -e "$orphan" ] || [ -L "$orphan" ] || continue
    orphan_name="$(basename "$orphan")"
    case "$orphan_name" in
      "$SLUG"-p-*|"$SLUG"-v2-p-*)
        orphan_identity="${orphan_name#"$SLUG-"}"
        orphan_identity="${orphan_identity#v2-}"
        orphan_identity="${orphan_identity#p-}"
        printf '%s\n' "$orphan_identity" | grep -Eq '^[0-9a-f]{12}-t-[0-9a-f]{12}-sdd$' && die 'orphan projection or workspace exists without active pointer'
        ;;
    esac
  done
fi

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

if [ "$VERIFY_ONLY" -eq 1 ]; then
  [ "$PREDECESSOR" != null ] && [ "$(projection_field "$PREDECESSOR" sdd_projection)" = maxi-v2 ] || die 'verify-only requires current v2 evidence; run ordinary projection to upgrade v1'
  [ "$PREDECESSOR" = "$FINAL" ] && [ -f "$FINAL" ] || die 'verify-only requires the existing current v2 identity; run ordinary projection first'
fi

# Scratch reconstruction is outside the project, including during verification.
TMPDIR_LOCAL="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT
TASK_META="$TMPDIR_LOCAL/tasks.meta"

awk '
  function invalid(message) { print message > "/dev/stderr"; bad = 1 }
  ($0 ~ /^- \[[^]]*\] T/ || $0 ~ /^[[:space:]]+- \[[^]]*\] T[0-9]/) && $0 !~ /^- \[[ xX]\] T[0-9][0-9][0-9] .+/ { invalid("malformed task line: " $0); next }
  /^- \[[ xX]\] T[0-9][0-9][0-9] .+/ {
    state = substr($0, 4, 1)
    id = substr($0, 7, 4)
    if (seen[id]++) invalid("duplicate task id: " id)
    line = $0
    sub(/^- \[[ xX]\]/, "- [ ]", line)
    annotation = line
    occurrences = gsub(/\(plan Task /, "", annotation)
    if (occurrences != 1 || line !~ /\(plan Task [1-9][0-9]*\)$/) invalid("task requires exactly one terminal (plan Task N) mapping: " id)
    mapping = line
    sub(/^.*\(plan Task /, "", mapping)
    sub(/\)$/, "", mapping)
    if (mapped[mapping]++) invalid("duplicate plan task mapping: " mapping)
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
  function invalid(message) { print "plan line " NR ": " message > "/dev/stderr"; bad = 1; exit 2 }
  function emit(line) {
    if (section == 0) {
      print line > (dir "/preamble")
      print $0 > (dir "/preamble-v1")
    }
    else print line > (dir "/body-" section)
  }
  BEGIN { printf "%s", "" > (dir "/preamble"); printf "%s", "" > (dir "/preamble-v1") }
  {
    line = $0
    delimiter = line
    sub(/^[[:space:]]*/, "", delimiter)
    kind = substr(delimiter, 1, 3)
    if (kind == "```" || kind == "~~~") {
      tail = substr(delimiter, 4)
      if (substr(tail, 1, 1) == substr(kind, 1, 1)) invalid("use closed three-character fences, not longer delimiters")
      if (fence == "") {
        if (tail ~ /```/) invalid("fence info cannot contain triple backticks; simplify the payload")
        fence = kind
        emit("```" tail)
        next
      }
      if (fence == kind) {
        if (tail !~ /^[[:space:]]*$/) invalid("closing fence must contain only its delimiter and whitespace")
        fence = ""
        emit("```" tail)
        next
      }
      if (line ~ /^```/) invalid("payload would toggle upstream backtick state; simplify the nested fence")
    }
    if (fence == "" && line ~ /^#+[[:space:]]+Task[[:space:]]+[0-9]+/) {
      number = line
      sub(/^#+[[:space:]]+Task[[:space:]]+/, "", number)
      sub(/[^0-9].*$/, "", number)
      if (number !~ /^[1-9][0-9]*$/) invalid("executable Task headings require positive numbers without leading zeroes")
      if (seen[number]++) invalid("duplicate executable Task " number)
      section++
      print number > (dir "/order")
      printf "%s", "" > (dir "/body-" section)
      next
    }
    emit(line)
  }
  END {
    if (fence != "" && !bad) { print "plan has an unclosed fence; close it before projection" > "/dev/stderr"; bad = 1 }
    if (section == 0 || bad) exit 2
  }
' "$PLAN" || die 'plan cannot be represented for upstream task-brief; correct its Task headings or fences'

while IFS=$'\t' read -r state id mapping line; do
  grep -Fqx -- "$mapping" "$PLAN_PARTS/order" || die "unknown plan Task $mapping mapped by $id; correct tasks.md"
done < "$TASK_META"
while IFS= read -r number; do
  cut -f3 "$TASK_META" | grep -Fqx -- "$number" || die "unmapped executable plan Task $number; correct tasks.md"
done < "$PLAN_PARTS/order"

render_body() {
  local selected="$1" output="$2" projected=0 state id mapping line description prefix section
  local version="${3:-maxi-v2}"
  : > "$output"
  if [ "$version" = maxi-v1 ]; then
    cat "$PLAN_PARTS/preamble-v1" >> "$output"
  else
    cat "$PLAN_PARTS/preamble" >> "$output"
  fi
  while IFS=$'\t' read -r state id mapping line; do
    grep -Fqx -- "$id" "$selected" || continue
    projected=$((projected + 1))
    prefix="- [ ] $id "
    description="${line#"$prefix"}"
    # The historical unquoted prefix pattern left the whole checkbox line.
    [ "$version" != maxi-v1 ] || description="$line"
    printf '\n### Task %s: %s %s\n\n%s\n' "$projected" "$id" "$description" "$line" >> "$output"
    [ "$version" != maxi-v1 ] || continue
    section="$(awk -v task="$mapping" '$0 == task { print NR }' "$PLAN_PARTS/order")"
    [ -n "$section" ] || die 'missing mapped plan section'
    cat "$PLAN_PARTS/body-$section" >> "$output"
  done < "$TASK_META"
}

write_expected_projection() {
  local output="$1" body="$2" execution_mode="$3" predecessor="$4" version="${5:-maxi-v2}" body_hash
  body_hash="$(sha "$body")"
  {
    echo '---'
    echo "sdd_projection: $version"
    echo "slug: $SLUG"
    echo "execution_mode: $execution_mode"
    echo "source_spec: $SPEC"
    echo "source_plan: $PLAN"
    echo "source_plan_sha256: $PLAN_HASH"
    echo "tasks_structural_sha256: $TASKS_HASH"
    echo "predecessor_projection: $predecessor"
    echo "projection_body_sha256: $body_hash"
    echo '---'
    cat "$body"
  } > "$output"
}

# Matching historical sources retain the original v1 canonical-byte check.
# Changed-source predecessors remain validated by their immutable lineage anchors.
legacy_projection="$PREDECESSOR"
while [ "$legacy_projection" != null ]; do
  if [ "$(projection_field "$legacy_projection" sdd_projection)" = maxi-v1 ] &&
    [ "$(projection_field "$legacy_projection" source_plan_sha256)" = "$PLAN_HASH" ] &&
    [ "$(projection_field "$legacy_projection" tasks_structural_sha256)" = "$TASKS_HASH" ]; then
    validate_selection_anchor "$legacy_projection" "$ROOT" "$TMPDIR_LOCAL/v1-selected" || die 'legacy selection anchor is invalid'
    render_body "$TMPDIR_LOCAL/v1-selected" "$TMPDIR_LOCAL/v1-body" maxi-v1
    write_expected_projection "$TMPDIR_LOCAL/v1-expected" "$TMPDIR_LOCAL/v1-body" \
      "$(projection_field "$legacy_projection" execution_mode)" \
      "$(projection_field "$legacy_projection" predecessor_projection)" maxi-v1
    cmp -s "$TMPDIR_LOCAL/v1-expected" "$legacy_projection" || die 'legacy projection differs from canonical v1 source reconstruction'
  fi
  legacy_projection="$(projection_field "$legacy_projection" predecessor_projection)"
done

unchecked="$(awk -F '\t' '$1 == " " { count++ } END { print count + 0 }' "$TASK_META")"
SELECTED_IDS="$TMPDIR_LOCAL/selected"
ANCHORED_IDS="$TMPDIR_LOCAL/anchored"
COMPLETED_IDS="$TMPDIR_LOCAL/predecessor-completed"
PREDECESSOR_ANCHORED_IDS="$TMPDIR_LOCAL/predecessor-anchored"
: > "$SELECTED_IDS"
: > "$ANCHORED_IDS"
: > "$COMPLETED_IDS"
: > "$PREDECESSOR_ANCHORED_IDS"

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
    validate_selection_anchor "$PROJECT_PREDECESSOR" "$ROOT" "$PREDECESSOR_ANCHORED_IDS" || die 'predecessor ledger selection anchor is invalid'
    while IFS= read -r id; do
      if ! grep -Fqx -- "$id" "$COMPLETED_IDS"; then
        [ "$(cut -f2 "$TASK_META" | grep -Fcx -- "$id" || true)" -eq 1 ] || die "structural successor omits anchored uncompleted task: $id"
      fi
    done < "$PREDECESSOR_ANCHORED_IDS"
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
    if [ "$PROJECT_PREDECESSOR" != null ]; then
      [ "$(projection_field "$PROJECT_PREDECESSOR" sdd_projection)" = maxi-v1 ] &&
        [ "$(projection_field "$PROJECT_PREDECESSOR" source_plan_sha256)" = "$PLAN_HASH" ] &&
        [ "$(projection_field "$PROJECT_PREDECESSOR" tasks_structural_sha256)" = "$TASKS_HASH" ] || die 'all-checked structural correction cannot skip review evidence'
    fi
    EXECUTION_MODE=final-review-only
  else
    EXECUTION_MODE=ordinary
  fi
fi

UNORDERED_IDS="$TMPDIR_LOCAL/selected-unordered"
cp "$SELECTED_IDS" "$UNORDERED_IDS"
: > "$SELECTED_IDS"
while IFS=$'\t' read -r state id mapping line; do
  grep -Fqx -- "$id" "$UNORDERED_IDS" && printf '%s\n' "$id" >> "$SELECTED_IDS"
done < "$TASK_META"
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
  [ ! -L "$WORKSPACE" ] || die 'projection workspace is a symlink'
  mkdir -p "$WORKSPACE"
  LEDGER="$WORKSPACE/progress.md"
  [ ! -e "$LEDGER" ] && [ ! -L "$LEDGER" ] || die 'fresh projection workspace already has a ledger'
  TEMP_LEDGER="$(mktemp "$WORKSPACE/.progress.XXXXXX")"
  write_selection_ledger "$FINAL" "$SELECTED_IDS" "$TEMP_LEDGER" "$EXPECTED_PROJECTION"
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
