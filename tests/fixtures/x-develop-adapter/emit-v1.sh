#!/usr/bin/env bash
# Test-only baseline v1 emitter: exact original preamble, heading bug and anchors.
set -euo pipefail
repo="$1"
dir="$repo/docs/maxi/specs/adapter-sample"
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
plan_hash="$(sha "$dir/plan.md")"
tasks_hash="$(awk '
  NR == 1 && $0 == "---" { fm = 1 }
  fm && /^updated:/ { next }
  /^- \[[ xX]\] T[0-9][0-9][0-9] / { sub(/^- \[[ xX]\]/, "- [ ]") }
  { print }
  fm && NR > 1 && $0 == "---" { fm = 0 }
' "$dir/tasks.md" | shasum -a 256 | awk '{print $1}')"
projection="$repo/.superpowers/sdd/projections/adapter-sample-p-${plan_hash:0:12}-t-${tasks_hash:0:12}-sdd.md"
[ ! -e "$projection" ]
body="$(mktemp)"
trap 'rm -f "$body"' EXIT
awk '
  /^[[:space:]]*```/ { if (fence == "") fence = "backtick"; else if (fence == "backtick") fence = "" }
  /^[[:space:]]*~~~/ { if (fence == "") fence = "tilde"; else if (fence == "tilde") fence = "" }
  fence == "" && /^#+[[:space:]]+Task[[:space:]]+[1-9][0-9]*([^0-9]|$)/ { exit }
  { print }
' "$dir/plan.md" > "$body"
awk '/^- \[ \] T[0-9][0-9][0-9] / {
  printf "\n### Task %d: %s %s\n\n%s\n", ++n, substr($0, 7, 4), $0, $0
}' "$dir/tasks.md" >> "$body"
mode=ordinary
if ! grep -q '^- \[ \] T[0-9][0-9][0-9] ' "$dir/tasks.md"; then mode=final-review-only; fi
mkdir -p "$(dirname "$projection")" "$repo/.superpowers/sdd/$(basename "$projection" .md)"
{
  printf '%s\n' '---' 'sdd_projection: maxi-v1' 'slug: adapter-sample' "execution_mode: $mode" "source_spec: $dir/spec.md" "source_plan: $dir/plan.md" "source_plan_sha256: $plan_hash" "tasks_structural_sha256: $tasks_hash" 'predecessor_projection: null' "projection_body_sha256: $(sha "$body")" '---'
  cat "$body"
} > "$projection"
{
  printf '# SDD ledger — plan: %s\n' "$projection"
  awk '/^- \[ \] T[0-9][0-9][0-9] / { ids = ids " " substr($0, 7, 4) } END { print "Maxi selection:" (ids == "" ? " none" : ids) }' "$dir/tasks.md"
  printf 'Maxi projection SHA256: %s\n' "$(sha "$projection")"
} > "$repo/.superpowers/sdd/$(basename "$projection" .md)/progress.md"
printf '%s\n' "$projection" > "$repo/.superpowers/sdd/active-adapter-sample"
printf '%s\n' "$projection"
