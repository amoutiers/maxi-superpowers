#!/usr/bin/env bash
# Migrate a github-spec-kit project to maxi conventions.
#
# Usage:
#   bash skills/migrate-from-speckit/migrate.sh [--preview] [--apply] [--yes]
#
#   --preview   Print what would happen. No files written. (default)
#   --apply     Execute the migration.
#   --yes       Skip interactive confirmation (for tests/CI).
#
# Run from the project root (the directory containing .specify/ and specs/).
set -euo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
die() { echo "ERROR: $*" >&2; exit 1; }

TODAY=$(date +%Y-%m-%d)
MODE="preview"
YES=0

for arg in "$@"; do
  case "$arg" in
    --preview) MODE="preview" ;;
    --apply)   MODE="apply" ;;
    --yes)     YES=1 ;;
    *) die "Unknown argument: $arg" ;;
  esac
done

# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------
[[ -d .specify ]] || die "Not a spec-kit project: .specify/ missing. Run from the project root."

shopt -s nullglob
spec_dirs=( specs/[0-9][0-9][0-9]-*/ )
shopt -u nullglob
[[ ${#spec_dirs[@]} -gt 0 ]] || die "No specs/NNN-* directories found."

# ---------------------------------------------------------------------------
# Clobber guard (apply mode only)
# ---------------------------------------------------------------------------
if [[ "$MODE" == "apply" ]]; then
  if [[ -d docs/maxi/specs ]] && [[ -n "$(ls -A docs/maxi/specs 2>/dev/null)" ]]; then
    die "docs/maxi/specs/ already exists and is non-empty. Aborting to avoid overwriting."
  fi
fi

# ---------------------------------------------------------------------------
# Constitution paths
# ---------------------------------------------------------------------------
CONST_SRC=".specify/memory/constitution.md"
CONST_DST="docs/constitution.md"
if [[ -f "$CONST_SRC" ]] && [[ ! -f "$CONST_DST" ]]; then
  const_action="COPY"
elif [[ -f "$CONST_SRC" ]] && [[ -f "$CONST_DST" ]]; then
  const_action="SKIP (target already exists)"
else
  const_action="SKIP (source missing)"
fi

# ---------------------------------------------------------------------------
# Collect migration plan (loop reads each spec once, builds parallel arrays)
# ---------------------------------------------------------------------------
slugs=()
created_dates=()
statuses=()
reasons=()
aux_summaries=()
skipped=()

for raw_dir in "${spec_dirs[@]}"; do
  src_dir="${raw_dir%/}"
  sl=$(basename "$src_dir")

  if [[ ! -f "$src_dir/spec.md" ]]; then
    skipped+=("$src_dir (no spec.md)")
    continue
  fi

  # Parse spec-kit inline fields
  created=$(grep -m1 '^\*\*Created\*\*:' "$src_dir/spec.md" 2>/dev/null \
    | sed 's/^\*\*Created\*\*:[[:space:]]*//' | tr -d '[:space:]' || true)
  [[ -n "$created" ]] || created="$TODAY"

  sk_status=$(grep -m1 '^\*\*Status\*\*:' "$src_dir/spec.md" 2>/dev/null \
    | sed 's/^\*\*Status\*\*:[[:space:]]*//' | awk '{print $1}' || true)

  # Infer maxi status
  has_retro=0; has_tasks=0; has_plan=0
  [[ -f "$src_dir/retrospective.md" ]] && has_retro=1
  [[ -f "$src_dir/tasks.md" ]]        && has_tasks=1
  [[ -f "$src_dir/plan.md" ]]         && has_plan=1

  if [[ "$sk_status" == "Shipped" ]] || [[ "$sk_status" == "Implemented" ]] || [[ "$has_retro" -eq 1 ]]; then
    st="done"
  elif [[ "$has_tasks" -eq 1 ]]; then
    st="tasked"
  elif [[ "$has_plan" -eq 1 ]]; then
    st="planned"
  else
    st="specified"
  fi

  # Human-readable reason
  r=""
  [[ "$sk_status" == "Shipped" || "$sk_status" == "Implemented" ]] && r="Status: $sk_status"
  [[ "$has_retro" -eq 1 ]] && r="${r:+$r + }retrospective.md"
  if [[ -z "$r" ]]; then
    [[ "$has_tasks" -eq 1 ]] && r="tasks.md present"
    [[ "$has_plan"  -eq 1 ]] && r="plan.md present"
    [[ -z "$r" ]]             && r="spec.md only"
  fi

  # Aux files summary
  aux=()
  for f in contracts data-model.md quickstart.md research.md retrospective.md; do
    [[ -e "$src_dir/$f" ]] && aux+=("$f")
  done
  ax="${aux[*]:-none}"

  slugs+=("$sl")
  created_dates+=("$created")
  statuses+=("$st")
  reasons+=("$r")
  aux_summaries+=("$ax")
done

total=${#slugs[@]}

# ---------------------------------------------------------------------------
# Preview
# ---------------------------------------------------------------------------
echo ""
echo "Spec-kit → maxi migration preview"
echo ""
echo "Constitution:"
printf "  %-55s →  %-30s  [%s]\n" "$CONST_SRC" "$CONST_DST" "$const_action"
echo ""
printf "Specs (%d):\n" "$total"
for i in "${!slugs[@]}"; do
  sl="${slugs[$i]}"
  st="${statuses[$i]}"
  r="${reasons[$i]}"
  printf "  specs/%-45s →  docs/maxi/specs/%-45s  status=%-12s (%s)\n" \
    "$sl" "$sl" "$st" "$r"
done
if [[ ${#skipped[@]} -gt 0 ]]; then
  echo ""
  echo "Skipped (no spec.md):"
  for w in "${skipped[@]}"; do echo "  $w"; done
fi
echo ""
echo "Aux files preserved per spec: contracts/, data-model.md, quickstart.md, research.md, retrospective.md"
echo "Untouched: .specify/, specs/ (originals), .claude/skills/speckit-*"
echo ""

[[ "$MODE" == "preview" ]] && exit 0

# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------
if [[ "$YES" -ne 1 ]]; then
  read -rp "Proceed with migration? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]([Ee][Ss])?$ ]] || { echo "Aborted."; exit 0; }
fi

mkdir -p docs/maxi/specs

# Constitution
if [[ "$const_action" == "COPY" ]]; then
  mkdir -p docs
  cp "$CONST_SRC" "$CONST_DST"
  echo "  Copied constitution → $CONST_DST"
fi

# Status counters
cnt_done=0; cnt_tasked=0; cnt_planned=0; cnt_specified=0; cnt_other=0

for i in "${!slugs[@]}"; do
  sl="${slugs[$i]}"
  src="specs/$sl"
  dst="docs/maxi/specs/$sl"
  created="${created_dates[$i]}"
  st="${statuses[$i]}"

  # Copy directory verbatim
  cp -r "$src" "$dst"

  spec_file="$dst/spec.md"
  plan_file="$dst/plan.md"
  tasks_file="$dst/tasks.md"

  # Extract feature name from H1 for tasks.md description
  feature_name=$(grep -m1 '^# ' "$spec_file" | sed 's/^#[[:space:]]*//' || echo "$sl")

  # Rewrite spec.md: prepend YAML frontmatter, strip spec-kit inline header lines
  tmp=$(mktemp)
  {
    printf -- '---\nslug: %s\ncreated: %s\nupdated: %s\nstatus: %s\n---\n\n' \
      "$sl" "$created" "$TODAY" "$st"
    awk '/^\*\*(Feature Branch|Status|Created|Input)\*\*:/ { next } { print }' "$spec_file"
  } > "$tmp"
  mv "$tmp" "$spec_file"

  # Add frontmatter to plan.md if present and not already fronted
  if [[ -f "$plan_file" ]] && ! head -1 "$plan_file" | grep -q '^---'; then
    tmp=$(mktemp)
    {
      printf -- '---\nslug: %s\nspec_slug: %s\ncreated: %s\nupdated: %s\n---\n\n' \
        "$sl" "$sl" "$created" "$TODAY"
      cat "$plan_file"
    } > "$tmp"
    mv "$tmp" "$plan_file"
  fi

  # Add frontmatter to tasks.md if present and not already fronted
  if [[ -f "$tasks_file" ]] && ! head -1 "$tasks_file" | grep -q '^---'; then
    tmp=$(mktemp)
    {
      printf -- '---\ndescription: "Tasks: %s"\nslug: %s\nspec_slug: %s\ncreated: %s\nupdated: %s\n---\n\n' \
        "$feature_name" "$sl" "$sl" "$created" "$TODAY"
      cat "$tasks_file"
    } > "$tmp"
    mv "$tmp" "$tasks_file"
  fi

  # Tally
  case "$st" in
    done)      cnt_done=$((cnt_done + 1)) ;;
    tasked)    cnt_tasked=$((cnt_tasked + 1)) ;;
    planned)   cnt_planned=$((cnt_planned + 1)) ;;
    specified) cnt_specified=$((cnt_specified + 1)) ;;
    *)         cnt_other=$((cnt_other + 1)) ;;
  esac
done

echo ""
echo "Migration complete."
echo ""
printf "Migrated %d specs:\n" "$total"
[[ $cnt_done      -gt 0 ]] && printf "  done:        %d\n" "$cnt_done"
[[ $cnt_tasked    -gt 0 ]] && printf "  tasked:      %d\n" "$cnt_tasked"
[[ $cnt_planned   -gt 0 ]] && printf "  planned:     %d\n" "$cnt_planned"
[[ $cnt_specified -gt 0 ]] && printf "  specified:   %d\n" "$cnt_specified"
[[ $cnt_other     -gt 0 ]] && printf "  other:       %d\n" "$cnt_other"
[[ ${#skipped[@]} -gt 0 ]] && printf "  skipped:     %d (no spec.md)\n" "${#skipped[@]}"
echo ""
[[ "$const_action" == "COPY" ]] && echo "Constitution copied → $CONST_DST"
echo ""
echo "Next: review docs/maxi/specs/, then run /maxi:specify to add new features."
