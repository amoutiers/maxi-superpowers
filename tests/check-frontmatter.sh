#!/usr/bin/env bash
# Validates that every skills/*/SKILL.md has required YAML frontmatter (name: and description:)
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

SKILLS_DIR="$ROOT/skills"
failures=0

for skill_dir in "$SKILLS_DIR"/*/; do
  name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"
  local_failures_before=$failures

  assert_file_exists "$skill_file" "$name: SKILL.md present"
  if [ "$failures" -gt "$local_failures_before" ]; then continue; fi

  assert_starts_with_yaml_frontmatter "$skill_file" "$name"
  assert_grep "$skill_file" "^name:" "$name: name field"
  assert_grep "$skill_file" "^description:" "$name: description field"

  if [ "$failures" -eq "$local_failures_before" ]; then
    echo "OK  [$name]"
  fi
done

summary_and_exit "skill frontmatter checks"
