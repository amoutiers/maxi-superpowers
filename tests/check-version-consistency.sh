#!/usr/bin/env bash
# Verifies superpowers version citations in authored docs match the pin in VENDORED.md.
# Ground truth: VENDORED.md "- **Pinned version**: vX.Y.Z".
# Guards the drift class where bump-superpowers.sh updates VENDORED.md but leaves
# README.md / docs/architecture.md / docs/delegation-map.md citing the old version.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

VER="$(grep -E 'Pinned version' "$ROOT/VENDORED.md" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
if [ -z "$VER" ]; then
  echo "FAIL [version-ground-truth]: could not parse pinned version from VENDORED.md" >&2
  failures=$((failures + 1))
  summary_and_exit "version consistency checks"
fi
echo "OK  [ground truth: VENDORED.md pins superpowers $VER]"

# Authored docs that cite a superpowers version. (specs/ and adr/ intentionally drift — excluded.)
DOCS=(README.md docs/architecture.md docs/delegation-map.md)

for rel in "${DOCS[@]}"; do
  f="$ROOT/$rel"
  if [ ! -f "$f" ]; then
    echo "FAIL [$rel]: file not found" >&2
    failures=$((failures + 1))
    continue
  fi
  bad=0
  # Any version token on a line that mentions superpowers must equal VER.
  while IFS= read -r tok; do
    if [ "$tok" != "$VER" ]; then
      echo "FAIL [$rel]: cites superpowers $tok but VENDORED.md pins $VER" >&2
      failures=$((failures + 1))
      bad=1
    fi
  done < <(grep -iE 'superpowers' "$f" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' || true)
  [ "$bad" -eq 0 ] && echo "OK  [$rel: superpowers version citations match $VER]"
done

summary_and_exit "version consistency checks"
