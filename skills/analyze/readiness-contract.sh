#!/usr/bin/env bash
# Stamp and verify hash-bound readiness evidence.
set -Eeuo pipefail

LC_ALL=C
export LC_ALL

TEMP_FILE=''
trap 'exit 2' ERR
trap '[ -z "$TEMP_FILE" ] || rm -f -- "$TEMP_FILE"' EXIT

die() {
  echo "ERROR: $*" >&2
  exit 2
}

sha_file() {
  shasum -a 256 < "$1" | awk '{print $1}'
}

spec_structural_sha() {
  awk '
    NR == 1 {
      if ($0 != "---") exit 2
      fm = 1
      print
      next
    }
    fm && $0 == "---" {
      fm = 0
      closed = 1
      print
      next
    }
    fm && $0 != "" && $0 !~ /^[[:space:]]/ && $0 !~ /^#/ && $0 !~ /^[a-z_][a-z0-9_]*:/ {
      invalid = 1
    }
    fm && /^status:/ {
      status_count++
      if ($0 !~ /^status: (drafting|specified|clarified|planned|tasked|analyzed|implementing|done|parked|cancelled)$/) invalid = 1
      next
    }
    fm && /^updated:/ {
      updated_count++
      if ($0 !~ /^updated: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) invalid = 1
      next
    }
    { print }
    END {
      if (!closed || status_count != 1 || updated_count != 1 || invalid) exit 2
    }
  ' "$1" | shasum -a 256 | awk '{print $1}'
}

tasks_structural_sha() {
  awk '
    NR == 1 {
      if ($0 != "---") exit 2
      fm = 1
      print
      next
    }
    fm && $0 == "---" {
      fm = 0
      closed = 1
      print
      next
    }
    fm && $0 != "" && $0 !~ /^[[:space:]]/ && $0 !~ /^#/ && $0 !~ /^[a-z_][a-z0-9_]*:/ {
      invalid = 1
    }
    fm && /^updated:/ {
      updated_count++
      if ($0 !~ /^updated: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) invalid = 1
      next
    }
    /^- \[[ xX]\] T[0-9][0-9][0-9] / { sub(/^- \[[ xX]\]/, "- [ ]") }
    { print }
    END { if (!closed || updated_count != 1 || invalid) exit 2 }
  ' "$1" | shasum -a 256 | awk '{print $1}'
}

# Reject symlink components before physical resolution, including lexical .. paths.
physical_path() {
  local path="$1" current part rest parent
  [ -n "$path" ] || return 1
  case "$path" in /*) current=/; rest="${path#/}" ;; *) current="$PWD"; rest="$path" ;; esac
  while [ -n "$rest" ]; do
    part="${rest%%/*}"
    if [ "$rest" = "$part" ]; then rest=''; else rest="${rest#*/}"; fi
    case "$part" in
      ''|.) continue ;;
      ..) current="$(cd "$current/.." && pwd -P)" || return 1; continue ;;
    esac
    [ ! -L "$current/$part" ] || return 1
    current="$current/$part"
  done
  parent="$(cd "$(dirname "$path")" 2>/dev/null && pwd -P)" || return 1
  printf '%s/%s\n' "$parent" "$(basename "$path")"
}

input_file() {
  local path expected="$2"
  path="$(physical_path "$1")" || return 1
  [ "${path##*/}" = "$expected" ] && [ -f "$path" ] && [ -r "$path" ] || return 1
  case "$path" in "$PROJECT_ROOT"/*) ;; *) return 1 ;; esac
  printf '%s\n' "$path"
}

resolve_root() {
  physical_path "$1/." >/dev/null || die 'project root contains symlinked components'
  PROJECT_ROOT="$(cd "$1" 2>/dev/null && pwd -P)" || die 'invalid project root'
  CURRENT_INPUTS="$(bash "$REVIEW_INPUTS" hash "$PROJECT_ROOT")" || die 'invalid decision inputs'
}

resolve_destination() {
  local supplied="$1" canonical="$2" mode="$3"
  DESTINATION="$(physical_path "$supplied")" || die 'invalid evidence path'
  [ "$DESTINATION" = "$canonical" ] || die 'evidence must have its canonical name and parent'
  if [ -e "$DESTINATION" ]; then
    [ -f "$DESTINATION" ] && [ -r "$DESTINATION" ] || die 'evidence is not a readable regular file'
    reject_input_alias "$DESTINATION"
  else
    [ "$mode" = stamp ] || die 'evidence is missing'
  fi
}

reject_input_alias() {
  local file="$1" input
  for input in "$SPEC" "$PLAN" "${TASKS:-$(dirname "$SPEC")/tasks.md}" "$PROJECT_ROOT/docs/maxi/constitution.md" "$PROJECT_ROOT/docs/maxi/adr/"*.md "$PROJECT_ROOT/docs/maxi/adr/".*.md; do
    [ -e "$input" ] || continue
    [ ! "$file" -ef "$input" ] || die 'evidence or candidate aliases a reviewed input'
  done
}

resolve_candidate() {
  CANDIDATE="$(physical_path "$1")" || die 'candidate has symlinked components or missing parent'
  [ -f "$CANDIDATE" ] && [ -r "$CANDIDATE" ] || die 'candidate is not a readable regular file'
  [ "$(dirname "$CANDIDATE")" = "$(dirname "$DESTINATION")" ] || die 'candidate must be beside destination'
  [ "$CANDIDATE" != "$DESTINATION" ] && [ ! "$CANDIDATE" -ef "$DESTINATION" ] || die 'candidate aliases destination'
  reject_input_alias "$CANDIDATE"
  [ "$(head -n 1 "$CANDIDATE")" != --- ] || die 'candidate must be an unstamped report body'
}

check_expected_inputs() {
  valid_hash "$1" || die 'malformed expected decision-input digest'
  CURRENT_INPUTS="$(bash "$REVIEW_INPUTS" hash "$PROJECT_ROOT")" || die 'invalid decision inputs'
  [ "$1" = "$CURRENT_INPUTS" ] || die 'decision inputs changed during review'
}

resolve_inputs() {
  local analysis="$1" spec="$2" plan="$3" tasks="$4" root="$5" mode="$6" directory
  resolve_root "$root"
  SPEC="$(input_file "$spec" spec.md)" || die 'spec.md is missing, symlinked, outside root, or misnamed'
  PLAN="$(input_file "$plan" plan.md)" || die 'plan.md is missing, symlinked, outside root, or misnamed'
  TASKS="$(input_file "$tasks" tasks.md)" || die 'tasks.md is missing, symlinked, outside root, or misnamed'
  directory="$(dirname "$SPEC")"
  [ "$(dirname "$PLAN")" = "$directory" ] && [ "$(dirname "$TASKS")" = "$directory" ] || die 'readiness artifacts are not in one physical directory'
  case "$directory" in "$PROJECT_ROOT"/docs/maxi/specs/*) [ "${directory#"$PROJECT_ROOT"/docs/maxi/specs/}" = "${directory##*/}" ] || die 'invalid spec directory' ;; *) die 'invalid spec directory' ;; esac
  resolve_destination "$analysis" "$directory/analysis.md" "$mode"
  ANALYSIS="$DESTINATION"
}

field() {
  local file="$1" key="$2"
  awk -v key="$key" '
    NR == 1 { if ($0 != "---") exit 2; fm = 1; next }
    fm && $0 == "---" { exit }
    fm && index($0, key ": ") == 1 {
      count++
      value = substr($0, length(key) + 3)
    }
    END { if (count == 1) print value; else exit 2 }
  ' "$file"
}

exact_fields() {
  local actual expected
  actual="$(awk '
    NR == 1 { if ($0 != "---") exit 2; fm = 1; next }
    fm && $0 == "---" { closed = 1; exit }
    fm {
      if ($0 !~ /^[a-z_][a-z0-9_]*: [^[:space:]].*$/) exit 2
      key = $0
      sub(/: .*/, "", key)
      print key
    }
    END { if (!closed) exit 2 }
  ' "$1" | sort)" || return 1
  expected="$(printf '%s\n' \
    critical_issues outcome plan_sha256 readiness_contract \
    spec_structural_sha256 tasks_structural_sha256 review_inputs_sha256 | sort)"
  [ "$actual" = "$expected" ]
}

valid_hash() {
  case "$1" in
    ''|*[!0-9a-f]*) return 1 ;;
  esac
  [ "${#1}" -eq 64 ]
}

stamp() {
  local candidate="$1" analysis="$2" spec="$3" plan="$4" tasks="$5" outcome="$6" critical_count="$7" root="$8" expected_inputs="$9"
  local spec_hash plan_hash tasks_hash analysis_dir

  case "$critical_count" in
    ''|*[!0-9]*) die 'critical count must be a decimal integer' ;;
  esac
  case "$outcome:$critical_count" in
    pass:0) ;;
    blocked:*) [ "$critical_count" -gt 0 ] || die 'blocked requires a positive critical count' ;;
    *) die 'pass requires zero critical issues' ;;
  esac

  resolve_inputs "$analysis" "$spec" "$plan" "$tasks" "$root" stamp
  resolve_candidate "$candidate"
  check_expected_inputs "$expected_inputs"
  spec_hash="$(spec_structural_sha "$SPEC")" || die 'invalid spec frontmatter'
  plan_hash="$(sha_file "$PLAN")"
  tasks_hash="$(tasks_structural_sha "$TASKS")" || die 'invalid tasks frontmatter'
  analysis_dir="$(dirname "$ANALYSIS")"
  TEMP_FILE="$(mktemp "$analysis_dir/.analysis.XXXXXX")"
  {
    printf '%s\n' '---'
    printf '%s\n' 'readiness_contract: maxi-readiness-v2'
    printf 'outcome: %s\n' "$outcome"
    printf 'critical_issues: %s\n' "$critical_count"
    printf 'spec_structural_sha256: %s\n' "$spec_hash"
    printf 'plan_sha256: %s\n' "$plan_hash"
    printf 'tasks_structural_sha256: %s\n' "$tasks_hash"
    printf 'review_inputs_sha256: %s\n' "$expected_inputs"
    printf '%s\n' '---'
    cat "$CANDIDATE" || die 'cannot read candidate'
  } > "$TEMP_FILE"
  resolve_inputs "$analysis" "$spec" "$plan" "$tasks" "$root" stamp
  resolve_candidate "$candidate"
  check_expected_inputs "$expected_inputs"
  [ "$spec_hash" = "$(spec_structural_sha "$SPEC")" ] && [ "$plan_hash" = "$(sha_file "$PLAN")" ] && [ "$tasks_hash" = "$(tasks_structural_sha "$TASKS")" ] || die 'artifacts changed during stamping'
  mv -f -- "$TEMP_FILE" "$ANALYSIS" || die 'cannot publish evidence'
  TEMP_FILE=''
}

verify() {
  local analysis="$1" spec="$2" plan="$3" tasks="$4" root="$5"
  local contract outcome critical_count spec_hash plan_hash tasks_hash
  local current_spec_hash current_tasks_hash

  resolve_inputs "$analysis" "$spec" "$plan" "$tasks" "$root" verify
  exact_fields "$ANALYSIS" || die 'readiness contract fields are not exact'
  contract="$(field "$ANALYSIS" readiness_contract)" || die 'invalid readiness_contract field'
  outcome="$(field "$ANALYSIS" outcome)" || die 'invalid outcome field'
  critical_count="$(field "$ANALYSIS" critical_issues)" || die 'invalid critical_issues field'
  spec_hash="$(field "$ANALYSIS" spec_structural_sha256)" || die 'invalid spec hash field'
  plan_hash="$(field "$ANALYSIS" plan_sha256)" || die 'invalid plan hash field'
  tasks_hash="$(field "$ANALYSIS" tasks_structural_sha256)" || die 'invalid tasks hash field'

  [ "$contract" = maxi-readiness-v2 ] || die 'unsupported readiness contract'
  [ "$outcome" = pass ] || die 'readiness outcome is not pass'
  [ "$critical_count" = 0 ] || die 'critical issues remain'
  valid_hash "$spec_hash" && valid_hash "$plan_hash" && valid_hash "$tasks_hash" || die 'malformed readiness hash'
  current_spec_hash="$(spec_structural_sha "$SPEC")" || die 'invalid spec frontmatter'
  current_tasks_hash="$(tasks_structural_sha "$TASKS")" || die 'invalid tasks frontmatter'
  [ "$spec_hash" = "$current_spec_hash" ] || die 'spec structural hash mismatch'
  [ "$plan_hash" = "$(sha_file "$PLAN")" ] || die 'plan hash mismatch'
  [ "$tasks_hash" = "$current_tasks_hash" ] || die 'tasks structural hash mismatch'
  check_expected_inputs "$(field "$ANALYSIS" review_inputs_sha256)"
  echo READINESS_VERIFIED
}

LOADED_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || die 'cannot resolve installed analyze directory'
REVIEW_INPUTS="$(cd "$LOADED_DIR/../review" && pwd -P)/review-inputs.sh" || die 'installed review directory missing'
[ -f "$REVIEW_INPUTS" ] && [ ! -L "$REVIEW_INPUTS" ] || die 'installed decision-input helper missing or symlinked'

case "${1:-}" in
  stamp)
    [ "$#" -eq 10 ] || die "usage: $0 stamp CANDIDATE ANALYSIS SPEC PLAN TASKS OUTCOME CRITICAL_COUNT PROJECT_ROOT EXPECTED_INPUTS_SHA256"
    shift
    stamp "$@"
    ;;
  verify)
    [ "$#" -eq 6 ] || die "usage: $0 verify ANALYSIS SPEC PLAN TASKS PROJECT_ROOT"
    shift
    verify "$@"
    ;;
  *)
    die "expected stamp or verify"
    ;;
esac
