#!/usr/bin/env bash
# Publish and verify exact design approval evidence.
set -Eeuo pipefail
export LC_ALL=C
TEMP_FILE=''
trap 'exit 2' ERR
trap '[ -z "$TEMP_FILE" ] || rm -f -- "$TEMP_FILE"' EXIT
die() { echo "ERROR: $*" >&2; exit 2; }
sha_file() { shasum -a 256 < "$1" | awk '{print $1}'; }
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
    design_review_contract reviewed_spec_sha256 reviewed_plan_sha256 review_inputs_sha256 verdict | sort)"
  [ "$actual" = "$expected" ]
}

valid_hash() {
  case "$1" in
    ''|*[!0-9a-f]*) return 1 ;;
  esac
  [ "${#1}" -eq 64 ]
}

resolve_inputs() {
  local report="$1" root="$4" mode="$5" directory
  resolve_root "$root"
  SPEC="$(input_file "$2" spec.md)" || die 'invalid spec.md input'
  PLAN="$(input_file "$3" plan.md)" || die 'invalid plan.md input'
  directory="$(dirname "$SPEC")"
  [ "$(dirname "$PLAN")" = "$directory" ] || die 'spec and plan must be colocated'
  case "$directory" in "$PROJECT_ROOT"/docs/maxi/specs/*) [ "${directory#"$PROJECT_ROOT"/docs/maxi/specs/}" = "${directory##*/}" ] || die 'invalid spec directory' ;; *) die 'invalid spec directory' ;; esac
  resolve_destination "$report" "$directory/reviews/design-review.md" "$mode"
}

stamp() {
  local candidate="$1" report="$2" spec="$3" plan="$4" verdict="$5" root="$6" expected_inputs="$7" spec_hash plan_hash
  case "$verdict" in approved|rejected) ;; *) die 'invalid design verdict' ;; esac
  resolve_inputs "$report" "$spec" "$plan" "$root" stamp
  resolve_candidate "$candidate"
  check_expected_inputs "$expected_inputs"
  spec_hash="$(sha_file "$SPEC")" || die 'cannot hash spec'
  plan_hash="$(sha_file "$PLAN")" || die 'cannot hash plan'
  TEMP_FILE="$(mktemp "$(dirname "$DESTINATION")/.design-review.XXXXXX")" || die 'cannot create private output'
  {
    printf '%s\n' '---' 'design_review_contract: maxi-design-review-v1'
    printf 'reviewed_spec_sha256: %s\n' "$spec_hash"
    printf 'reviewed_plan_sha256: %s\n' "$plan_hash"
    printf 'review_inputs_sha256: %s\n' "$expected_inputs"
    printf 'verdict: %s\n' "$verdict"
    printf '%s\n' '---'
    cat "$CANDIDATE" || die 'cannot read candidate'
  } > "$TEMP_FILE"
  resolve_inputs "$report" "$spec" "$plan" "$root" stamp
  resolve_candidate "$candidate"
  check_expected_inputs "$expected_inputs"
  [ "$spec_hash" = "$(sha_file "$SPEC")" ] && [ "$plan_hash" = "$(sha_file "$PLAN")" ] || die 'artifacts changed during stamping'
  mv -f -- "$TEMP_FILE" "$DESTINATION" || die 'cannot publish evidence'
  TEMP_FILE=''
}

verify() {
  local contract spec_hash plan_hash
  resolve_inputs "$1" "$2" "$3" "$4" verify
  exact_fields "$DESTINATION" || die 'design contract fields are not exact'
  contract="$(field "$DESTINATION" design_review_contract)" || die 'invalid contract field'
  [ "$contract" = maxi-design-review-v1 ] || die 'unsupported design contract'
  [ "$(field "$DESTINATION" verdict)" = approved ] || die 'design verdict is not approved'
  spec_hash="$(field "$DESTINATION" reviewed_spec_sha256)" || die 'invalid spec hash field'
  plan_hash="$(field "$DESTINATION" reviewed_plan_sha256)" || die 'invalid plan hash field'
  valid_hash "$spec_hash" && valid_hash "$plan_hash" || die 'malformed design hash'
  [ "$spec_hash" = "$(sha_file "$SPEC")" ] && [ "$plan_hash" = "$(sha_file "$PLAN")" ] || die 'design artifact hash mismatch'
  check_expected_inputs "$(field "$DESTINATION" review_inputs_sha256)"
  echo DESIGN_REVIEW_VERIFIED
}

LOADED_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || die 'cannot resolve installed review directory'
REVIEW_INPUTS="$LOADED_DIR/review-inputs.sh"
[ -f "$REVIEW_INPUTS" ] && [ ! -L "$REVIEW_INPUTS" ] || die 'installed decision-input helper missing or symlinked'
APPROVAL_GUARD="$LOADED_DIR/approval-guard.sh"
[ -f "$APPROVAL_GUARD" ] && [ ! -L "$APPROVAL_GUARD" ] || die 'installed approval guard missing or symlinked'
source "$APPROVAL_GUARD"
case "${1:-}" in
  stamp) [ "$#" -eq 8 ] || die 'usage: design-contract.sh stamp CANDIDATE REVIEW SPEC PLAN VERDICT PROJECT_ROOT EXPECTED_INPUTS_SHA256'; shift; stamp "$@" ;;
  verify) [ "$#" -eq 5 ] || die 'usage: design-contract.sh verify REVIEW SPEC PLAN PROJECT_ROOT'; shift; verify "$@" ;;
  *) die 'expected stamp or verify' ;;
esac
