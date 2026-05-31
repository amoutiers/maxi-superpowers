#!/usr/bin/env bash
# Deterministic helpers for /maxi:migrate-from-brownfield.
#
# Subcommands:
#   guard                              Verify prerequisites (constitution + code).
#   write-spec --slug S --body F --sha H   Write a reverse-engineered spec at next NNNN.
#   exclude --name N --paths a,b,c     Decide exclude|flag|keep for a boundary candidate.
#
# The skill (SKILL.md) orchestrates the discovery/draft/verify agents and the
# consent gate; this script does deterministic file-ops only. Run from the
# target project root.
set -euo pipefail
die() { echo "ERROR: $*" >&2; exit 1; }

# Recognized source-code file extensions (guard + future helpers).
CODE_EXT_RE='\.(js|ts|jsx|tsx|py|rb|go|rs|java|kt|c|h|cc|cpp|cs|php|swift|scala|sh)$'

# ---------------------------------------------------------------------------
# guard — prerequisites
# ---------------------------------------------------------------------------
cmd_guard() {
  if [[ ! -f docs/maxi/constitution.md ]]; then
    echo "No constitution found. Run /maxi:constitution first (and /maxi:migrate-adr separately for ADRs)." >&2
    exit 2
  fi
  # docs/ is excluded so docs/maxi/ artifacts never count as "code"; a repo whose
  # only sources live under docs/ would therefore falsely report no code (acceptable trade-off).
  #
  # Use grep -c (consumes ALL of find's output), not grep -q: under `set -o pipefail`,
  # grep -q closes the pipe on first match and find dies with SIGPIPE, which pipefail
  # surfaces as a false failure on any tree large enough that find is still streaming
  # (i.e. most real repos). Counting avoids the early pipe close entirely.
  local code_count
  code_count=$(find . -type f -not -path './.git/*' -not -path './docs/*' 2>/dev/null \
    | grep -cE "$CODE_EXT_RE" || true)
  if [[ "${code_count:-0}" -eq 0 ]]; then
    echo "No recognized source code found. Nothing to reverse-engineer." >&2
    exit 3
  fi
  echo "guard: ok"
}

# ---------------------------------------------------------------------------
# write-spec — write a reverse-engineered spec at the next NNNN
# ---------------------------------------------------------------------------
cmd_write_spec() {
  local slug="" body="" sha=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --slug) slug="$2"; shift 2 ;;
      --body) body="$2"; shift 2 ;;
      --sha)  sha="$2";  shift 2 ;;
      *) die "write-spec: unknown arg $1" ;;
    esac
  done
  [[ -n "$slug" && -n "$body" && -n "$sha" ]] || die "write-spec: --slug, --body, --sha required"
  [[ "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "write-spec: --slug must be kebab-case (lowercase alphanumerics, single hyphens), got: '$slug'"
  [[ -f "$body" ]] || die "write-spec: body file not found: $body"

  # NNNN = max existing + 1 (max-based: survives gaps), zero-padded to 4.
  local max=0 n
  shopt -s nullglob
  for d in docs/maxi/specs/[0-9][0-9][0-9][0-9]-*/; do
    n=$(basename "$d" | cut -d- -f1); n=$((10#$n))
    (( n > max )) && max=$n
  done
  shopt -u nullglob
  local nnnn; nnnn=$(printf '%04d' $((max + 1)))
  local dir="docs/maxi/specs/${nnnn}-${slug}"
  [[ -e "$dir" ]] && die "write-spec: $dir already exists"
  mkdir -p "$dir"
  local today; today=$(date +%Y-%m-%d)

  {
    printf -- '---\n'
    printf 'slug: %s-%s\n' "$nnnn" "$slug"
    printf 'created: %s\n' "$today"
    printf 'updated: %s\n' "$today"
    printf 'status: done\n'
    printf 'origin: reverse-engineered\n'
    printf 'source_sha: %s\n' "$sha"
    printf 'parked_from: null\n'
    printf -- '---\n\n'
    cat "$body"
    printf '\n\n## Migration Notes\n\n'
    printf -- '- Reverse-engineered from commit `%s`.\n' "$sha"
    printf -- '- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).\n'
    printf -- '- Verified against code by an adversarial pass before acceptance.\n'
  } > "$dir/spec.md"

  echo "$dir/spec.md"
}

# ---------------------------------------------------------------------------
# exclude — decide exclude|flag|keep for a boundary candidate (idempotency)
# ---------------------------------------------------------------------------
# Normalize a string to a sorted, unique token set (one token per line).
# Lowercase, split on non-alphanumerics, drop stopwords + tokens shorter than 3.
_tokens() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '\n' \
    | grep -vxE '(use|for|the|a|an|as|with|to|and|of)' \
    | grep -xE '.{3,}' | sort -u || true
}

cmd_exclude() {
  local name="" paths=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)  name="$2";  shift 2 ;;
      --paths) paths="$2"; shift 2 ;;   # comma-separated
      *) die "exclude: unknown arg $1" ;;
    esac
  done
  [[ -n "$paths" ]] || die "exclude: --paths required"

  # --- Primary: path-overlap against reverse-engineered specs' file:line refs.
  local covered; covered=$(mktemp)
  shopt -s nullglob
  for s in docs/maxi/specs/[0-9][0-9][0-9][0-9]-*/spec.md; do
    grep -q '^origin: reverse-engineered$' "$s" || continue
    # Assumes one (path:line) ref per FR (the draft-subagent contract). Multi-ref
    # FRs "(a:2, b:9)" or ranges "(a:2-5)" are not parsed — tighten if that contract loosens.
    grep -oE '\(([^():]+):[0-9]+\)' "$s" | sed -E 's/^\(//; s/:[0-9]+\)$//' >> "$covered" || true
  done
  shopt -u nullglob
  sort -u "$covered" -o "$covered"

  local total=0 hit=0 p c
  IFS=',' read -ra cand <<< "$paths"
  for p in "${cand[@]}"; do
    p="${p#"${p%%[![:space:]]*}"}"; p="${p%"${p##*[![:space:]]}"}"   # border-trim (preserve internal spaces)
    [[ -n "$p" ]] || continue         # skip empty fields (e.g. "a,,b" / "a, b")
    total=$((total + 1))
    local matched=0
    while IFS= read -r c; do
      c="${c#"${c%%[![:space:]]*}"}"; c="${c%"${c##*[![:space:]]}"}"   # border-trim ref too
      [[ -n "$c" ]] || continue
      # exact match, or one path is a directory prefix of the other:
      # a "src/auth" candidate is covered by a "src/auth/login.js" ref, and vice versa.
      if [[ "$p" == "$c" || "$c" == "$p"/* || "$p" == "$c"/* ]]; then matched=1; break; fi
    done < "$covered"
    if (( matched )); then hit=$((hit + 1)); fi
  done
  rm -f "$covered"

  if (( total > 0 && hit == total )); then echo "exclude"; return; fi
  if (( hit > 0 )); then echo "flag"; return; fi

  # --- Fallback: name token-set match against ref-less specs (no file:line refs).
  if [[ -n "$name" ]]; then
    local cset; cset=$(_tokens "$name")
    if [[ -n "$cset" ]]; then
      shopt -s nullglob
      for s in docs/maxi/specs/[0-9][0-9][0-9][0-9]-*/spec.md; do
        if grep -qE '\([^():]+:[0-9]+\)' "$s"; then continue; fi   # has refs -> handled by path phase
        local suffix sset
        suffix=$(basename "$(dirname "$s")" | sed -E 's/^[0-9]+-//')
        sset=$(_tokens "$suffix")
        [[ -n "$sset" ]] || continue
        if [[ "$cset" == "$sset" ]]; then shopt -u nullglob; echo "exclude"; return; fi
        if comm -12 <(printf '%s\n' "$cset") <(printf '%s\n' "$sset") | grep -q .; then
          shopt -u nullglob; echo "flag"; return
        fi
      done
      shopt -u nullglob
    fi
  fi

  echo "keep"
}

case "${1:-}" in
  guard)      shift; cmd_guard "$@" ;;
  write-spec) shift; cmd_write_spec "$@" ;;
  exclude)    shift; cmd_exclude "$@" ;;
  *) die "Usage: brownfield.sh {guard|write-spec|exclude} ..." ;;
esac
