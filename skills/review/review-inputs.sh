#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

die() {
  echo "review-inputs: $*" >&2
  exit 2
}

sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

reject_symlinked_components() {
  local supplied="$1" current part old_ifs
  if [[ "$supplied" = /* ]]; then
    current=/
  else
    current="$PWD"
  fi

  old_ifs="$IFS"
  IFS=/
  set -f
  for part in $supplied; do
    [ -n "$part" ] || continue
    case "$part" in
      .) continue ;;
      ..) current="$(cd "$current/.." 2>/dev/null && pwd -P)" || return 1; continue ;;
    esac
    [ ! -L "$current/$part" ] || return 1
    current="$current/$part"
  done
  set +f
  IFS="$old_ifs"
}

[ "$#" -eq 2 ] && [ "$1" = hash ] || die 'usage: review-inputs.sh hash PROJECT_ROOT'
supplied_root="$2"
[ -n "$supplied_root" ] || die 'project root is required'
reject_symlinked_components "$supplied_root" || die 'project root contains a symlinked component'
[ -d "$supplied_root" ] || die 'project root is not a directory'
project_root="$(cd "$supplied_root" 2>/dev/null && pwd -P)" || die 'project root cannot be resolved'

docs="$project_root/docs"
maxi="$docs/maxi"
constitution="$maxi/constitution.md"
[ ! -L "$docs" ] && [ -d "$docs" ] || die 'docs is missing, symlinked, or not a directory'
[ ! -L "$maxi" ] && [ -d "$maxi" ] || die 'docs/maxi is missing, symlinked, or not a directory'
[ ! -L "$constitution" ] && [ -f "$constitution" ] && [ -r "$constitution" ] \
  || die 'constitution.md is missing, unreadable, symlinked, or nonregular'

scratch="$(mktemp -d)" || die 'cannot create temporary directory'
trap 'rm -rf "$scratch"' EXIT
manifest="$scratch/manifest"
sorted_manifest="$scratch/manifest.sorted"
: > "$manifest"

constitution_hash="$(sha256 "$constitution")" || die 'cannot hash constitution.md'
printf '%s\t%s\n' 'docs/maxi/constitution.md' "$constitution_hash" >> "$manifest" \
  || die 'cannot write temporary manifest'

adr="$maxi/adr"
if [ -e "$adr" ] || [ -L "$adr" ]; then
  [ ! -L "$adr" ] && [ -d "$adr" ] && [ -r "$adr" ] && [ -x "$adr" ] \
    || die 'ADR path is unreadable, symlinked, or not a directory'
  shopt -s nullglob dotglob
  for entry in "$adr"/*; do
    name="${entry##*/}"
    clean_name="$(printf '%s' "$name" | tr -d '[:cntrl:]')"
    if [ "$name" != "$clean_name" ]; then
      die 'ADR entry name contains a control character'
    fi
    [ ! -L "$entry" ] || die "ADR entry is symlinked: $name"
    [ -f "$entry" ] || die "ADR entry is nonregular: $name"
    case "$name" in
      README.md|*.md) ;;
      *) continue ;;
    esac
    [ "$name" != README.md ] || continue
    entry_hash="$(sha256 "$entry")" || die "cannot hash ADR entry: $name"
    printf '%s\t%s\n' "docs/maxi/adr/$name" "$entry_hash" >> "$manifest" \
      || die 'cannot write temporary manifest'
  done
  shopt -u nullglob dotglob
fi

sort "$manifest" > "$sorted_manifest" || die 'cannot sort temporary manifest'
digest="$(sha256 "$sorted_manifest")" || die 'cannot hash temporary manifest'
printf '%s\n' "$digest"
