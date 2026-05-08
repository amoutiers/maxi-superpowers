#!/usr/bin/env bash
# Updates VENDORED.md with a new pinned version and sync date.
# Usage: bash scripts/_update-vendored-md.sh <tag> <date>
# Example: bash scripts/_update-vendored-md.sh v6.0.0 2026-05-08
set -euo pipefail

TAG="${1:?usage: _update-vendored-md.sh <tag> <date>}"
DATE="${2:?usage: _update-vendored-md.sh <tag> <date>}"
ROOT="$(git rev-parse --show-toplevel)"
VENDORED="$ROOT/VENDORED.md"

if [ ! -f "$VENDORED" ]; then
  echo "ERROR: $VENDORED not found" >&2
  exit 1
fi

sed -i.bak "s/\*\*Pinned version\*\*:.*/\*\*Pinned version\*\*: $TAG/" "$VENDORED"
sed -i.bak "s/\*\*Last synced\*\*:.*/\*\*Last synced\*\*: $DATE/" "$VENDORED"
rm -f "$VENDORED.bak"

echo "Updated VENDORED.md: version=$TAG date=$DATE"
