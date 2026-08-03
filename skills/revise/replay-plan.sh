#!/usr/bin/env bash
# Calculate a confined, read-only replay proposal for versioned forward artifacts.
set -u
set -o pipefail

LC_ALL=C
export LC_ALL

fail() {
  local status="$1"
  shift
  printf 'ERROR|%s\n' "$*" >&2
  exit "$status"
}

valid_previous_revision() {
  local value="$1" max='9223372036854775806'

  case "$value" in
    0) ;;
    [1-9]*)
      case "$value" in *[!0-9]*) return 1 ;; esac
      ;;
    *) return 1 ;;
  esac

  [ "${#value}" -lt "${#max}" ] ||
    { [ "${#value}" -eq "${#max}" ] && { [ "$value" = "$max" ] || [[ "$value" < "$max" ]]; }; }
}

decimal_successor() {
  awk -v value="$1" 'BEGIN {
    carry = 1
    result = ""
    for (i = length(value); i > 0; i--) {
      digit = substr(value, i, 1)
      if (carry) {
        if (digit == "9") digit = "0"
        else { digit = digit + 1; carry = 0 }
      }
      result = digit result
    }
    if (carry) result = "1" result
    print result
  }'
}

supported_path() {
  local path="$1" name

  case "$path" in
    spec.md|research.md|data-model.md|plan.md|tasks.md|analysis.md|reviews/spec-review.md|reviews/plan-review.md)
      return 0
      ;;
    contracts/*.md)
      name="${path#contracts/}"
      case "$name" in
        ''|*/*|*'|'*|*'@'*) return 1 ;;
      esac
      case "$name" in
        *[[:space:]]*) return 1 ;;
      esac
      return 0
      ;;
  esac
  return 1
}

resolve_file() {
  local candidate="$1" link parent physical hops=0

  while [ -L "$candidate" ]; do
    hops=$((hops + 1))
    [ "$hops" -le 40 ] || return 1
    link="$(readlink "$candidate")" || return 1
    case "$link" in
      /*) candidate="$link" ;;
      *) candidate="$(dirname "$candidate")/$link" ;;
    esac
  done

  [ -f "$candidate" ] || return 1
  parent="$(cd -P "$(dirname "$candidate")" 2>/dev/null && pwd)" || return 1
  physical="$parent/$(basename "$candidate")"
  [ -f "$physical" ] || return 1
  printf '%s\n' "$physical"
}

parse_document() {
  awk '
    function invalid() { bad = 1 }
    NR == 1 {
      if ($0 != "---") invalid()
      else frontmatter = 1
      next
    }
    frontmatter && $0 == "---" {
      frontmatter = 0
      closed = 1
      next
    }
    !frontmatter { next }
    list == "contributors" && /^  - / {
      value = substr($0, 5)
      if (value == "" || value ~ /[|]/) invalid()
      else {
        print "contributor|" value
        contributor_count++
      }
      next
    }
    list == "derived" && /^  - / {
      value = substr($0, 5)
      if (value == "" || value ~ /[|]/) invalid()
      else {
        print "derived|" value
        derived_count++
      }
      next
    }
    {
      list = ""
      if ($0 ~ /^revision:/) {
        if (seen_revision++ || $0 !~ /^revision: [1-9][0-9]*$/) invalid()
        else { sub(/^revision: /, ""); print "revision|" $0 }
        next
      }
      if ($0 ~ /^writer_context:/) {
        if (seen_writer++ || $0 !~ /^writer_context: [^[:space:]][^|]*$/) invalid()
        else { sub(/^writer_context: /, ""); print "writer|" $0 }
        next
      }
      if ($0 ~ /^structural_contributors:/) {
        if (seen_contributors++ || $0 != "structural_contributors:") invalid()
        else list = "contributors"
        next
      }
      if ($0 ~ /^derived_from:/) {
        if (seen_derived++) invalid()
        else if ($0 == "derived_from: []") empty_derived = 1
        else if ($0 == "derived_from:") list = "derived"
        else invalid()
        next
      }
      if ($0 ~ /^reviewed_document:/) {
        if (seen_reviewed_document++ || $0 !~ /^reviewed_document: [^[:space:]][^|]*$/) invalid()
        else { sub(/^reviewed_document: /, ""); print "reviewed_document|" $0 }
        next
      }
      if ($0 ~ /^reviewed_revision:/) {
        if (seen_reviewed_revision++ || $0 !~ /^reviewed_revision: [1-9][0-9]*$/) invalid()
        else { sub(/^reviewed_revision: /, ""); print "reviewed_revision|" $0 }
        next
      }
      if ($0 ~ /^reviewer_context:/) {
        if (seen_reviewer++ || $0 !~ /^reviewer_context: [^[:space:]][^|]*$/) invalid()
        else { sub(/^reviewer_context: /, ""); print "reviewer|" $0 }
        next
      }
      if ($0 ~ /^verdict:/) {
        if (seen_verdict++ || $0 !~ /^verdict: (approved|rejected)$/) invalid()
        else { sub(/^verdict: /, ""); print "verdict|" $0 }
        next
      }
    }
    END {
      if (!closed || seen_revision != 1 || seen_writer != 1 ||
          seen_contributors != 1 || contributor_count < 1 || seen_derived != 1 || bad) exit 2
    }
  ' "$1"
}

lookup_revision() {
  local path="$1"
  printf '%s\n' "$REVISIONS" | awk -F '|' -v path="$path" '$1 == path { print $2; exit }'
}

review_field() {
  local path="$1" field="$2"
  printf '%s\n' "$REVIEWS" | awk -F '|' -v path="$path" -v field="$field" '
    $1 == path {
      if (field == "subject") print $2
      else if (field == "revision") print $3
      else if (field == "reviewer") print $4
      else if (field == "verdict") print $5
      exit
    }
  '
}

review_is_current() {
  local review="$1" subject subject_revision reviewed_revision verdict

  subject="$(review_field "$review" subject)"
  reviewed_revision="$(review_field "$review" revision)"
  verdict="$(review_field "$review" verdict)"
  [ -n "$subject" ] || return 1
  subject_revision="$(lookup_revision "$subject")"
  [ "$verdict" = approved ] && [ "$reviewed_revision" = "$subject_revision" ]
}

SPEC_DIR=''
CHANGED=''
PREVIOUS=''
START_PHASE=''

while [ "$#" -gt 0 ]; do
  case "$1" in
    --spec-dir|--changed|--previous-revision|--start-phase)
      [ "$#" -ge 2 ] || fail 2 "missing value for $1"
      value="$2"
      case "$1" in
        --spec-dir) [ -z "$SPEC_DIR" ] || fail 2 'duplicate --spec-dir'; SPEC_DIR="$value" ;;
        --changed) [ -z "$CHANGED" ] || fail 2 'duplicate --changed'; CHANGED="$value" ;;
        --previous-revision) [ -z "$PREVIOUS" ] || fail 2 'duplicate --previous-revision'; PREVIOUS="$value" ;;
        --start-phase) [ -z "$START_PHASE" ] || fail 2 'duplicate --start-phase'; START_PHASE="$value" ;;
      esac
      shift 2
      ;;
    *) fail 2 "unknown argument $1" ;;
  esac
done

[ -n "$SPEC_DIR" ] && [ -n "$CHANGED" ] && [ -n "$PREVIOUS" ] && [ -n "$START_PHASE" ] || fail 2 'all arguments are required'
valid_previous_revision "$PREVIOUS" || fail 2 'previous revision must be a canonical bounded non-negative integer'
supported_path "$CHANGED" || fail 2 'unsupported changed path'
case "$START_PHASE" in clarify|plan|tasks|analyze) ;; *) fail 2 'unsupported start phase' ;; esac

SPEC_ROOT="$(cd -P "$SPEC_DIR" 2>/dev/null && pwd)" || fail 3 'selected spec directory is missing'
case "$SPEC_ROOT" in *'|'*|*$'\n'*) fail 2 'selected spec directory has an unsupported name' ;; esac

DOCUMENTS=''
for path in spec.md research.md data-model.md plan.md tasks.md analysis.md reviews/spec-review.md reviews/plan-review.md; do
  if [ -e "$SPEC_ROOT/$path" ] || [ -L "$SPEC_ROOT/$path" ]; then
    DOCUMENTS="$DOCUMENTS
$path"
  fi
done
for candidate in "$SPEC_ROOT"/contracts/*.md; do
  if [ -e "$candidate" ] || [ -L "$candidate" ]; then
    path="contracts/$(basename "$candidate")"
    supported_path "$path" || fail 2 'unsupported contract path'
    DOCUMENTS="$DOCUMENTS
$path"
  fi
done
DOCUMENTS="$(printf '%s\n' "$DOCUMENTS" | sed '/^$/d' | sort -u)"

# All remaining word splitting is record-oriented. Metadata values are literal
# strings and must never be reinterpreted as pathname patterns.
set -f

printf '%s\n' "$DOCUMENTS" | grep -Fqx 'spec.md' || fail 3 'spec.md is missing'
printf '%s\n' "$DOCUMENTS" | grep -Fqx "$CHANGED" || fail 3 'changed document is missing'

PHYSICALS=''
old_ifs="$IFS"
IFS='
'
for path in $DOCUMENTS; do
  physical="$(resolve_file "$SPEC_ROOT/$path")" || fail 3 "missing or unresolvable path $path"
  case "$physical" in "$SPEC_ROOT"/*) ;; *) fail 3 "physical path escapes selected spec directory: $path" ;; esac
  if printf '%s\n' "$PHYSICALS" | awk -F '|' -v physical="$physical" '$2 == physical { found = 1 } END { exit !found }'; then
    fail 3 "multiple documents resolve to one physical path: $path"
  fi
  PHYSICALS="$PHYSICALS
$path|$physical"
done

SPEC_FILE="$(printf '%s\n' "$PHYSICALS" | awk -F '|' '$1 == "spec.md" { print $2; exit }')"
if ! grep -q '^revision:' "$SPEC_FILE" &&
   ! grep -q '^structural_contributors:' "$SPEC_FILE" &&
   ! grep -q '^derived_from:' "$SPEC_FILE"; then
  printf 'UNSUPPORTED_LEGACY\n'
  exit 4
fi

REVISIONS=''
CONTRIBUTORS=''
EDGES=''
REVIEWS=''

for path in $DOCUMENTS; do
  physical="$(printf '%s\n' "$PHYSICALS" | awk -F '|' -v path="$path" '$1 == path { print $2; exit }')"
  metadata="$(parse_document "$physical")"
  parse_status=$?
  [ "$parse_status" -eq 0 ] || fail 2 "malformed metadata in $path"

  revision=''
  writer=''
  contributors=''
  derived=''
  reviewed_document=''
  reviewed_revision=''
  reviewer=''
  verdict=''
  for record in $metadata; do
    kind="${record%%|*}"
    data="${record#*|}"
    case "$kind" in
      revision) revision="$data" ;;
      writer) writer="$data" ;;
      contributor) contributors="$contributors
$data" ;;
      derived) derived="$derived
$data" ;;
      reviewed_document) reviewed_document="$data" ;;
      reviewed_revision) reviewed_revision="$data" ;;
      reviewer) reviewer="$data" ;;
      verdict) verdict="$data" ;;
    esac
  done

  printf '%s\n' "$contributors" | sed '/^$/d' | grep -Fqx "$writer" || fail 2 "writer context is not a structural contributor in $path"
  REVISIONS="$REVISIONS
$path|$revision"
  for contributor in $contributors; do
    [ -n "$contributor" ] || continue
    CONTRIBUTORS="$CONTRIBUTORS
$path|$contributor"
  done
  for input in $derived; do
    [ -n "$input" ] || continue
    case "$input" in *@*) ;;
      *) fail 2 "malformed direct input in $path" ;;
    esac
    input_path="${input%@*}"
    input_revision="${input##*@}"
    case "$input_path" in /*|..|../*|*/../*|*/..) fail 3 "direct input escapes selected spec directory in $path" ;; esac
    [ -n "$input_path" ] && supported_path "$input_path" || fail 2 "unsupported direct input in $path"
    printf '%s\n' "$input_revision" | grep -Eq '^[1-9][0-9]*$' || fail 2 "malformed direct input revision in $path"
    [ "$input" = "$input_path@$input_revision" ] || fail 2 "malformed direct input in $path"
    EDGES="$EDGES
$path|$input_path|$input_revision"
  done

  case "$path" in
    reviews/spec-review.md|reviews/plan-review.md)
      [ -n "$reviewed_document" ] && [ -n "$reviewed_revision" ] && [ -n "$reviewer" ] && [ -n "$verdict" ] || fail 2 "incomplete review metadata in $path"
      case "$path|$reviewed_document" in
        'reviews/spec-review.md|spec.md'|'reviews/plan-review.md|plan.md') ;;
        *) fail 2 "review subject does not match $path" ;;
      esac
      review_inputs="$(printf '%s\n' "$derived" | sed '/^$/d')"
      [ "$review_inputs" = "$reviewed_document@$reviewed_revision" ] || fail 2 "review direct input does not match its subject in $path"
      REVIEWS="$REVIEWS
$path|$reviewed_document|$reviewed_revision|$reviewer|$verdict"
      ;;
    *)
      [ -z "$reviewed_document$reviewed_revision$reviewer$verdict" ] || fail 2 "review-only metadata appears in $path"
      ;;
  esac
done
IFS="$old_ifs"

IFS='
'
for edge in $EDGES; do
  [ -n "$edge" ] || continue
  input_path="$(printf '%s\n' "$edge" | awk -F '|' '{ print $2 }')"
  printf '%s\n' "$DOCUMENTS" | grep -Fqx "$input_path" || fail 3 "declared input is missing: $input_path"
done
IFS="$old_ifs"

if ! {
  printf '%s\n' "$DOCUMENTS" | sed '/^$/d;s/^/D|/'
  printf '%s\n' "$EDGES" | sed '/^$/d;s/^/E|/'
} | awk -F '|' '
  $1 == "D" { present[$2] = 1; indegree[$2] = 0; total++; next }
  $1 == "E" { dependent[++edge_count] = $2; dependency[edge_count] = $3; indegree[$2]++; next }
  END {
    while (removed < total) {
      selected = ""
      for (document in present) if (!done[document] && indegree[document] == 0) { selected = document; break }
      if (selected == "") exit 1
      done[selected] = 1
      removed++
      for (i = 1; i <= edge_count; i++) if (dependency[i] == selected) indegree[dependent[i]]--
    }
  }
'; then
  fail 3 'dependency cycle detected'
fi

for review_path in reviews/spec-review.md reviews/plan-review.md; do
  if printf '%s\n' "$DOCUMENTS" | grep -Fqx "$review_path"; then
    subject="$(review_field "$review_path" subject)"
    reviewer="$(review_field "$review_path" reviewer)"
    if printf '%s\n' "$CONTRIBUTORS" | awk -F '|' -v subject="$subject" -v reviewer="$reviewer" '$1 == subject && $2 == reviewer { found = 1 } END { exit !found }'; then
      fail 2 "reviewer is a structural contributor of $subject"
    fi
  fi
done

current_revision="$(lookup_revision "$CHANGED")"
expected_revision="$(decimal_successor "$PREVIOUS")"
[ "$current_revision" = "$expected_revision" ] || fail 2 'changed revision is not the successor of previous revision'

case "$CHANGED|$START_PHASE" in
  'spec.md|clarify'|'spec.md|plan'|'plan.md|tasks'|'reviews/spec-review.md|plan'|'reviews/plan-review.md|tasks'|'tasks.md|analyze'|'analysis.md|analyze') ;;
  research.md\|plan|data-model.md\|plan|contracts/*.md\|plan) ;;
  *) fail 2 'start phase is incompatible with changed document' ;;
esac

STALE="$({
  printf '%s\n' "$REVISIONS" | sed '/^$/d;s/^/R|/'
  printf '%s\n' "$EDGES" | sed '/^$/d;s/^/E|/'
} | awk -F '|' -v changed="$CHANGED" '
  BEGIN { stale[changed] = 1 }
  $1 == "R" { current[$2] = $3; next }
  $1 == "E" {
    dependent[++edge_count] = $2
    dependency[edge_count] = $3
    declared[edge_count] = $4
    next
  }
  END {
    for (i = 1; i <= edge_count; i++) if (current[dependency[i]] != declared[i]) stale[dependent[i]] = 1
    do {
      added = 0
      for (i = 1; i <= edge_count; i++) {
        if (stale[dependency[i]] && !stale[dependent[i]]) { stale[dependent[i]] = 1; added = 1 }
      }
    } while (added)
    for (document in stale) if (stale[document] && document != changed) print document
  }
' | sort)"

printf 'CHANGED|%s|%s|%s\n' "$CHANGED" "$PREVIOUS" "$current_revision"
if [ -n "$STALE" ]; then
  printf '%s\n' "$STALE" | sed 's/^/STALE|/'
fi

case "$CHANGED" in
  spec.md)
    if [ "$START_PHASE" = clarify ]; then
      printf 'REPLAY|clarify\n'
    fi
    printf 'REVIEW_REQUIRED|spec.md|%s\n' "$current_revision"
    ;;
  plan.md)
    printf 'REVIEW_REQUIRED|plan.md|%s\n' "$current_revision"
    ;;
  reviews/spec-review.md)
    if review_is_current reviews/spec-review.md; then
      printf 'REPLAY|plan\n'
    else
      printf 'REVIEW_REQUIRED|spec.md|%s\n' "$(lookup_revision spec.md)"
    fi
    ;;
  reviews/plan-review.md)
    if review_is_current reviews/plan-review.md; then
      printf 'REPLAY|tasks\n'
      printf 'REPLAY|analyze\n'
    else
      printf 'REVIEW_REQUIRED|plan.md|%s\n' "$(lookup_revision plan.md)"
    fi
    ;;
  tasks.md)
    printf 'REPLAY|analyze\n'
    ;;
  analysis.md)
    ;;
  research.md|data-model.md|contracts/*.md)
    if review_is_current reviews/spec-review.md; then
      printf 'REPLAY|plan\n'
    else
      printf 'REVIEW_REQUIRED|spec.md|%s\n' "$(lookup_revision spec.md)"
    fi
    ;;
esac
