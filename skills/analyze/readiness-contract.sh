#!/usr/bin/env bash
# Stamp and verify hash-bound readiness evidence.
set -euo pipefail

LC_ALL=C
export LC_ALL

TEMP_FILE=''
trap '[ -z "$TEMP_FILE" ] || rm -f -- "$TEMP_FILE"' EXIT

die() {
  echo "ERROR: $*" >&2
  exit 2
}

sha_file() {
  shasum -a 256 "$1" | awk '{print $1}'
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

physical_file() {
  local path="$1" expected="$2" parent
  [ "$(basename "$path")" = "$expected" ] || return 1
  [ -f "$path" ] && [ ! -L "$path" ] || return 1
  parent="$(cd -P "$(dirname "$path")" 2>/dev/null && pwd)" || return 1
  [ -f "$parent/$expected" ] && [ ! -L "$parent/$expected" ] || return 1
  printf '%s/%s\n' "$parent" "$expected"
}

resolve_inputs() {
  local analysis="$1" spec="$2" plan="$3" tasks="$4" directory
  ANALYSIS="$(physical_file "$analysis" analysis.md)" || die 'analysis.md is missing, symlinked, or misnamed'
  SPEC="$(physical_file "$spec" spec.md)" || die 'spec.md is missing, symlinked, or misnamed'
  PLAN="$(physical_file "$plan" plan.md)" || die 'plan.md is missing, symlinked, or misnamed'
  TASKS="$(physical_file "$tasks" tasks.md)" || die 'tasks.md is missing, symlinked, or misnamed'
  directory="$(dirname "$ANALYSIS")"
  [ "$(dirname "$SPEC")" = "$directory" ] &&
    [ "$(dirname "$PLAN")" = "$directory" ] &&
    [ "$(dirname "$TASKS")" = "$directory" ] || die 'readiness artifacts are not in one physical directory'
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
    spec_structural_sha256 tasks_structural_sha256 | sort)"
  [ "$actual" = "$expected" ]
}

valid_hash() {
  case "$1" in
    ''|*[!0-9a-f]*) return 1 ;;
  esac
  [ "${#1}" -eq 64 ]
}

stamp() {
  local analysis="$1" spec="$2" plan="$3" tasks="$4" outcome="$5" critical_count="$6"
  local spec_hash plan_hash tasks_hash analysis_dir

  case "$critical_count" in
    ''|*[!0-9]*) die 'critical count must be a decimal integer' ;;
  esac
  case "$outcome:$critical_count" in
    pass:0) ;;
    blocked:*) [ "$critical_count" -gt 0 ] || die 'blocked requires a positive critical count' ;;
    *) die 'pass requires zero critical issues' ;;
  esac

  resolve_inputs "$analysis" "$spec" "$plan" "$tasks"
  spec_hash="$(spec_structural_sha "$SPEC")" || die 'invalid spec frontmatter'
  plan_hash="$(sha_file "$PLAN")"
  tasks_hash="$(tasks_structural_sha "$TASKS")" || die 'invalid tasks frontmatter'
  analysis_dir="$(dirname "$ANALYSIS")"
  TEMP_FILE="$(mktemp "$analysis_dir/.analysis.XXXXXX")"
  {
    printf '%s\n' '---'
    printf '%s\n' 'readiness_contract: maxi-readiness-v1'
    printf 'outcome: %s\n' "$outcome"
    printf 'critical_issues: %s\n' "$critical_count"
    printf 'spec_structural_sha256: %s\n' "$spec_hash"
    printf 'plan_sha256: %s\n' "$plan_hash"
    printf 'tasks_structural_sha256: %s\n' "$tasks_hash"
    printf '%s\n' '---'
    cat "$ANALYSIS"
  } > "$TEMP_FILE"
  mv "$TEMP_FILE" "$ANALYSIS"
  TEMP_FILE=''
}

verify() {
  local analysis="$1" spec="$2" plan="$3" tasks="$4"
  local contract outcome critical_count spec_hash plan_hash tasks_hash
  local current_spec_hash current_tasks_hash

  resolve_inputs "$analysis" "$spec" "$plan" "$tasks"
  exact_fields "$ANALYSIS" || die 'readiness contract fields are not exact'
  contract="$(field "$ANALYSIS" readiness_contract)" || die 'invalid readiness_contract field'
  outcome="$(field "$ANALYSIS" outcome)" || die 'invalid outcome field'
  critical_count="$(field "$ANALYSIS" critical_issues)" || die 'invalid critical_issues field'
  spec_hash="$(field "$ANALYSIS" spec_structural_sha256)" || die 'invalid spec hash field'
  plan_hash="$(field "$ANALYSIS" plan_sha256)" || die 'invalid plan hash field'
  tasks_hash="$(field "$ANALYSIS" tasks_structural_sha256)" || die 'invalid tasks hash field'

  [ "$contract" = maxi-readiness-v1 ] || die 'unsupported readiness contract'
  [ "$outcome" = pass ] || die 'readiness outcome is not pass'
  [ "$critical_count" = 0 ] || die 'critical issues remain'
  valid_hash "$spec_hash" && valid_hash "$plan_hash" && valid_hash "$tasks_hash" || die 'malformed readiness hash'
  current_spec_hash="$(spec_structural_sha "$SPEC")" || die 'invalid spec frontmatter'
  current_tasks_hash="$(tasks_structural_sha "$TASKS")" || die 'invalid tasks frontmatter'
  [ "$spec_hash" = "$current_spec_hash" ] || die 'spec structural hash mismatch'
  [ "$plan_hash" = "$(sha_file "$PLAN")" ] || die 'plan hash mismatch'
  [ "$tasks_hash" = "$current_tasks_hash" ] || die 'tasks structural hash mismatch'
  echo READINESS_VERIFIED
}

case "${1:-}" in
  stamp)
    [ "$#" -eq 7 ] || die "usage: $0 stamp ANALYSIS SPEC PLAN TASKS OUTCOME CRITICAL_COUNT"
    shift
    stamp "$@"
    ;;
  verify)
    [ "$#" -eq 5 ] || die "usage: $0 verify ANALYSIS SPEC PLAN TASKS"
    shift
    verify "$@"
    ;;
  *)
    die "expected stamp or verify"
    ;;
esac
