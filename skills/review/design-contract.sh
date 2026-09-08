#!/usr/bin/env bash
# Publish and verify exact design approval evidence.
set -Eeuo pipefail
export LC_ALL=C
TEMP_FILE=''
trap 'exit 2' ERR
LOCK_DIR=''
cleanup() {
  local status=$?
  trap - EXIT
  [ -z "$TEMP_FILE" ] || rm -f -- "$TEMP_FILE" || :
  [ -z "$LOCK_DIR" ] || rmdir -- "$LOCK_DIR" || :
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
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

# One lock for all writers. Never adopt or remove a lock we did not create.
lock_report() {
  mkdir -- "$DESTINATION.lock" 2>/dev/null || die 'report mutation lock already exists'
  LOCK_DIR="$DESTINATION.lock"
}
report_hash() {
  if [ -e "$DESTINATION" ]; then sha_file "$DESTINATION"; else printf 'absent\n'; fi
}
expect_report() {
  [ "$1" = "$(report_hash)" ] || die 'report changed during operation'
}

# Parse only the leading current block. Byte-framed history is opaque payload.
# Output is nine fixed metadata values followed by current (non-historical) text.
parse_operation() {
  awk -v output="${2:-metadata}" -v bytes="$(wc -c < "$1" | tr -d ' ')" '
    { text = text $0 "\n" }
    END {
      if (!index(text,"maxi-design-operation-v1") && !index(text,"maxi-design-history-v1")) exit 3
      if (length(text) != bytes) exit 2
      if (substr(text,1,4) == "---\n") {
        end=index(substr(text,5),"\n---\n")
        if (!end) exit 2
        text=substr(text,end+9)
      }
      marker="<!-- maxi-design-history-v1 bytes: "
      start=index(text,marker)
      if (start) {
        rest=substr(text,start+length(marker)); line=index(rest,"\n")
        if (!line) exit 2
        size=substr(rest,1,line-1)
        if (size !~ /^(0|[1-9][0-9]*) -->$/) exit 2
        sub(/ -->$/, "", size)
        rest=substr(rest,line+1)
        ending="\n<!-- /maxi-design-history-v1 -->\n"
        if (substr(rest,size+1,length(ending)) != ending) exit 2
        historical=substr(text,start,length(text)-length(rest)+size+length(ending)-start+1)
        text=substr(text,1,start-1) substr(rest,size+length(ending)+1)
      }
      if (index(text,"maxi-design-history-v1")) exit 2
      if (!index(text,"maxi-design-operation-v1")) exit 2
      count=split(text,lines,"\n")
      if (lines[1] != "# Design Review" || lines[2] != "<!-- maxi-design-operation-v1" || lines[12] != "-->") exit 2
      split("operation_id request_sha256 mode phase passes reviewer spec_sha256 plan_sha256 inputs_sha256",keys," ")
      for (i=1;i<=9;i++) {
        prefix=keys[i] ": "
        if (index(lines[i+2],prefix)!=1) exit 2
        values[i]=substr(lines[i+2],length(prefix)+1)
      }
      for (i=1;i<=9;i++) {
        if (i==1 || i==2 || i>=7) {
          if (length(values[i])!=64 || values[i] ~ /[^0-9a-f]/) exit 2
        }
      }
      if (values[3]!="coordinated" && values[3]!="report-only") exit 2
      if (values[4]!="reserved" && values[4]!="rejected" && values[4]!="approved" && values[4]!="stopped") exit 2
      if (values[5]!="1" && !(values[5]=="2" && values[3]=="coordinated")) exit 2
      if (values[6]=="" || values[6] ~ /[[:cntrl:]]/) exit 2
      payload=""
      for (i=13;i<count;i++) payload=payload lines[i] "\n"
      if (index(payload,"maxi-design-operation-v1")) exit 2
      if (output=="history") { printf "%s",historical; exit }
      for (i=1;i<=9;i++) print values[i]
      printf "%s",payload
    }
  ' "$1"
}
load_operation() {
  local parsed
  parsed="$(parse_operation "$1")" || die 'missing or malformed design operation'
  OP_ID="$(printf '%s\n' "$parsed" | sed -n '1p')"
  OP_REQUEST="$(printf '%s\n' "$parsed" | sed -n '2p')"
  OP_MODE="$(printf '%s\n' "$parsed" | sed -n '3p')"
  OP_PHASE="$(printf '%s\n' "$parsed" | sed -n '4p')"
  OP_PASSES="$(printf '%s\n' "$parsed" | sed -n '5p')"
  OP_REVIEWER="$(printf '%s\n' "$parsed" | sed -n '6p')"
  OP_SPEC="$(printf '%s\n' "$parsed" | sed -n '7p')"
  OP_PLAN="$(printf '%s\n' "$parsed" | sed -n '8p')"
  OP_INPUTS="$(printf '%s\n' "$parsed" | sed -n '9p')"
  OP_PAYLOAD="$(printf '%s\n' "$parsed" | tail -n +10)"
}
legacy_only() {
  local status=0
  [ -e "$1" ] || return 0
  parse_operation "$1" > /dev/null || status=$?
  [ "$status" = 3 ] || die 'legacy stamp cannot replace managed or malformed operation state'
}
operation_block() {
  printf '%s\n' '# Design Review' '<!-- maxi-design-operation-v1'
  printf 'operation_id: %s\nrequest_sha256: %s\nmode: %s\nphase: %s\npasses: %s\nreviewer: %s\nspec_sha256: %s\nplan_sha256: %s\ninputs_sha256: %s\n-->\n' \
    "$OP_ID" "$OP_REQUEST" "$OP_MODE" "$OP_PHASE" "$OP_PASSES" "$OP_REVIEWER" "$OP_SPEC" "$OP_PLAN" "$OP_INPUTS"
}
history() {
  [ -e "$DESTINATION" ] || return 0
  printf '\n<!-- maxi-design-history-v1 bytes: %s -->\n' "$(wc -c < "$DESTINATION" | tr -d ' ')"
  cat "$DESTINATION"
  printf '\n<!-- /maxi-design-history-v1 -->\n'
}
check_snapshot() {
  [ "$OP_SPEC" = "$(sha_file "$SPEC")" ] && [ "$OP_PLAN" = "$(sha_file "$PLAN")" ] || die 'reservation artifact hash mismatch'
  check_expected_inputs "$OP_INPUTS"
}
new_output() {
  TEMP_FILE="$(mktemp "$(dirname "$DESTINATION")/.design-review.XXXXXX")" || die 'cannot create private output'
}
operation() {
  resolve_inputs "$1" "$2" "$3" "$4" verify
  load_operation "$DESTINATION"
  [ "$OP_ID" = "$5" ] || die 'operation identity mismatch'
  printf 'operation_id: %s\nphase: %s\npasses: %s\nreviewer: %s\nreport_sha256: %s\n' "$OP_ID" "$OP_PHASE" "$OP_PASSES" "$OP_REVIEWER" "$(report_hash)"
}
reserve() {
  local report="$1" spec="$2" plan="$3" root="$4" id="$5" request="$6" mode="$7" reviewer="$8" expected="$9" passes=1 status=0
  valid_hash "$id" && valid_hash "$request" || die 'invalid operation identity'
  case "$mode" in coordinated|report-only) ;; *) die 'invalid operation mode';; esac
  [ -n "$reviewer" ] && ! printf '%s' "$reviewer" | LC_ALL=C grep -q '[[:cntrl:]]' || die 'invalid reviewer identity'
  # grep operates on lines, so reject LF separately.
  case "$reviewer" in *$'\n'*) die 'invalid reviewer identity';; esac
  resolve_inputs "$report" "$spec" "$plan" "$root" stamp
  lock_report
  expect_report "$expected"
  if [ -e "$DESTINATION" ]; then
    parse_operation "$DESTINATION" > /dev/null || status=$?
    case "$status" in
      0)
        load_operation "$DESTINATION"
        if [ "$OP_ID" = "$id" ]; then
          [ "$OP_REQUEST" = "$request" ] && [ "$OP_MODE" = "$mode" ] || die 'operation context mismatch'
          case "$OP_PHASE:$OP_PASSES:$OP_MODE" in rejected:1:coordinated) passes=2;; *) die 'no unused review pass is available';; esac
        else
          case "$OP_PHASE:$OP_PASSES:$OP_MODE" in
            approved:*|stopped:*|rejected:2:coordinated|rejected:1:report-only) ;;
            *) die 'active operation cannot be replaced';;
          esac
        fi;;
      3) ;; # Unmanaged historical report.
      *) die 'malformed operation continuity';;
    esac
  else
    [ "$expected" = absent ] || die 'missing operation continuity'
  fi
  OP_ID="$id"; OP_REQUEST="$request"; OP_MODE="$mode"; OP_PHASE=reserved; OP_PASSES="$passes"; OP_REVIEWER="$reviewer"
  OP_SPEC="$(sha_file "$SPEC")"; OP_PLAN="$(sha_file "$PLAN")"; OP_INPUTS="$CURRENT_INPUTS"
  new_output
  { operation_block; history; } > "$TEMP_FILE"
  resolve_inputs "$report" "$spec" "$plan" "$root" stamp
  check_snapshot
  expect_report "$expected"
  mv -f -- "$TEMP_FILE" "$DESTINATION" || die 'cannot publish reservation'
  TEMP_FILE=''
  printf 'DESIGN_REVIEW_RESERVED operation_id=%s pass=%s report_sha256=%s\n' "$OP_ID" "$OP_PASSES" "$(report_hash)"
}
stop_operation() {
  local report="$1" spec="$2" plan="$3" root="$4" id="$5" expected="$6"
  resolve_inputs "$report" "$spec" "$plan" "$root" verify
  lock_report
  expect_report "$expected"
  load_operation "$DESTINATION"
  [ "$OP_ID" = "$id" ] || die 'operation identity mismatch'
  OP_PHASE=stopped
  new_output
  { operation_block; history; } > "$TEMP_FILE"
  resolve_inputs "$report" "$spec" "$plan" "$root" verify
  expect_report "$expected"
  mv -f -- "$TEMP_FILE" "$DESTINATION" || die 'cannot publish stopped operation'
  TEMP_FILE=''
}
stamp_operation() {
  local candidate="$1" report="$2" spec="$3" plan="$4" verdict="$5" root="$6" inputs="$7" id="$8" expected="$9" block candidate_hash
  case "$verdict" in approved|rejected) ;; *) die 'invalid design verdict';; esac
  resolve_inputs "$report" "$spec" "$plan" "$root" verify
  lock_report
  expect_report "$expected"
  load_operation "$DESTINATION"
  [ "$OP_ID" = "$id" ] && [ "$OP_PHASE" = reserved ] || die 'operation is not the matching reserved pass'
  [ "$OP_INPUTS" = "$inputs" ] || die 'reservation decision digest mismatch'
  check_snapshot
  OP_PHASE="$verdict"; block="$(operation_block)"
  resolve_candidate "$candidate"
  candidate_hash="$(sha_file "$CANDIDATE")"
  load_operation "$CANDIDATE"
  [ "$block" = "$(operation_block)" ] || die 'candidate operation block differs from reservation'
  [ "$(parse_operation "$DESTINATION" history | shasum -a 256)" = "$(parse_operation "$CANDIDATE" history | shasum -a 256)" ] || die 'candidate must preserve reservation history'
  printf '%s\n' "$OP_PAYLOAD" | awk -v verdict="$verdict" '
    /VERDICT:/ { count++; if ($0 != "VERDICT: " verdict) bad=1 }
    /[^[:space:]]/ { last=$0 }
    END { exit !(count==1 && !bad && last=="VERDICT: " verdict) }
  ' || die 'candidate must contain one exact terminal reviewer verdict'
  stamp_body "$candidate" "$report" "$spec" "$plan" "$verdict" "$root" "$inputs" "$expected" "$candidate_hash"
  if [ "$verdict" = approved ]; then verify "$report" "$spec" "$plan" "$root"; fi
}

stamp() {
  resolve_inputs "$2" "$3" "$4" "$6" stamp
  lock_report
  legacy_only "$DESTINATION"
  legacy_only "$1"
  stamp_body "$@" "$(report_hash)" "$(sha_file "$1")"
}

stamp_body() {
  local candidate="$1" report="$2" spec="$3" plan="$4" verdict="$5" root="$6" expected_inputs="$7" expected_report="$8" candidate_hash="$9" spec_hash plan_hash
  case "$verdict" in approved|rejected) ;; *) die 'invalid design verdict' ;; esac
  resolve_inputs "$report" "$spec" "$plan" "$root" stamp
  resolve_candidate "$candidate"
  check_expected_inputs "$expected_inputs"
  # Managed publication stays bound to the reservation, including the interval
  # between candidate validation and envelope construction.
  spec_hash="${OP_SPEC:-$(sha_file "$SPEC")}" || die 'cannot hash spec'
  plan_hash="${OP_PLAN:-$(sha_file "$PLAN")}" || die 'cannot hash plan'
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
  [ "$candidate_hash" = "$(sha_file "$CANDIDATE")" ] || die 'candidate changed during stamping'
  expect_report "$expected_report"
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
  local operation_status=0
  parse_operation "$DESTINATION" > /dev/null || operation_status=$?
  case "$operation_status" in
    0)
      load_operation "$DESTINATION"
      [ "$OP_PHASE" = approved ] || die 'managed operation is not approved'
      [ "$OP_SPEC" = "$spec_hash" ] && [ "$OP_PLAN" = "$plan_hash" ] && [ "$OP_INPUTS" = "$(field "$DESTINATION" review_inputs_sha256)" ] || die 'operation and approval envelope disagree'
      ;;
    3) ;;
    *) die 'malformed managed approval';;
  esac
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
  reserve) [ "$#" -eq 10 ] || die 'usage: reserve REVIEW SPEC PLAN ROOT OPERATION_ID REQUEST_SHA MODE REVIEWER EXPECTED_REPORT_SHA'; shift; reserve "$@" ;;
  operation) [ "$#" -eq 6 ] || die 'usage: operation REVIEW SPEC PLAN ROOT OPERATION_ID'; shift; operation "$@" ;;
  stamp-operation) [ "$#" -eq 10 ] || die 'usage: stamp-operation CANDIDATE REVIEW SPEC PLAN VERDICT ROOT ORIGINAL_INPUTS OPERATION_ID EXPECTED_REPORT_SHA'; shift; stamp_operation "$@" ;;
  stop-operation) [ "$#" -eq 7 ] || die 'usage: stop-operation REVIEW SPEC PLAN ROOT OPERATION_ID EXPECTED_REPORT_SHA'; shift; stop_operation "$@" ;;
  *) die 'expected stamp, verify, reserve, operation, stamp-operation or stop-operation' ;;
esac
