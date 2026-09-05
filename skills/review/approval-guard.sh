#!/usr/bin/env bash
# Shared path, alias and decision-input checks for approval envelopes.

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
