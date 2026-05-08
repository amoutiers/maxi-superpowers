#!/usr/bin/env bash
# Validates that every skills/*/SKILL.md has required YAML frontmatter (name: and description:)
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
SKILLS_DIR="$ROOT/skills"
failures=0

for skill_dir in "$SKILLS_DIR"/*/; do
  name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"

  if [ ! -f "$skill_file" ]; then
    echo "FAIL [$name]: SKILL.md missing" >&2
    failures=$((failures + 1))
    continue
  fi

  # Check frontmatter exists (file must start with ---)
  first_line=$(head -1 "$skill_file")
  if [ "$first_line" != "---" ]; then
    echo "FAIL [$name]: SKILL.md does not start with YAML frontmatter (---)" >&2
    failures=$((failures + 1))
    continue
  fi

  # Check name: field present
  if ! grep -q "^name:" "$skill_file"; then
    echo "FAIL [$name]: missing 'name:' in frontmatter" >&2
    failures=$((failures + 1))
    continue
  fi

  # Check description: field present
  if ! grep -q "^description:" "$skill_file"; then
    echo "FAIL [$name]: missing 'description:' in frontmatter" >&2
    failures=$((failures + 1))
    continue
  fi

  echo "OK  [$name]"
done

if [ "$failures" -gt 0 ]; then
  echo ""
  echo "FAILED: $failures skill(s) have invalid frontmatter" >&2
  exit 1
fi

echo ""
echo "All skills passed frontmatter check."
