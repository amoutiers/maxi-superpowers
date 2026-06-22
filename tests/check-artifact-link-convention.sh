#!/usr/bin/env bash
# Every skill that carries the "Artifact reference links" convention must carry it
# byte-identically to the canonical fixture. Single source of truth (Constitution Principle VI).
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

CANON="$ROOT/tests/fixtures/artifact-link-convention.txt"
[ -f "$CANON" ] || { echo "FAIL: canonical fixture missing: $CANON" >&2; exit 1; }

extract() {  # prints the convention block from a SKILL.md, or nothing
  awk '/^## Artifact reference links/{p=1}
       p{print}
       /^- Applies \*\*forward-only\*\*/{if(p)exit}' "$1"
}

REQUIRED_SKILLS=(
  analyze board cancel clarify constitution implement migrate-adr
  migrate-from-brownfield migrate-from-speckit park plan resume revise
  specify tasks x-adr x-develop
)

for name in "${REQUIRED_SKILLS[@]}"; do
  file="$ROOT/skills/$name/SKILL.md"
  assert_file_exists "$file" "$name SKILL.md"
  if [ -f "$file" ]; then
    assert_grep "$file" "^## Artifact reference links" "$name: carries artifact-link convention"
  fi
done

found=0
for d in "$ROOT"/skills/*/; do
  name="$(basename "$d")"
  [ -d "$ROOT/vendor/superpowers/skills/$name" ] && continue   # skip vendored skills
  file="$d/SKILL.md"
  grep -q "^## Artifact reference links" "$file" || continue   # skill doesn't carry it — OK
  found=$((found + 1))
  tmp="$(mktemp)"
  extract "$file" > "$tmp"
  if diff -q "$CANON" "$tmp" >/dev/null 2>&1; then
    echo "OK  [$name]"
  else
    echo "FAIL [$name]: 'Artifact reference links' block diverges from canonical fixture" >&2
    failures=$((failures + 1))
  fi
  rm -f "$tmp"
done

[ "$found" -ge 1 ] || { echo "FAIL: no skill carries the convention block — check the extraction marker" >&2; failures=$((failures + 1)); }

summary_and_exit "artifact-link convention checks"
