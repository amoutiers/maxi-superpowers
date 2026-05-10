#!/usr/bin/env bash
# Tests skills/migrate-from-speckit/migrate.sh against a minimal spec-kit fixture.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

SCRIPT="$ROOT/skills/migrate-from-speckit/migrate.sh"
FIXTURE="$ROOT/tests/fixtures/speckit-project"

failures=0

# ---------------------------------------------------------------------------
# Setup: copy fixture to a temp dir so the script can write into it
# ---------------------------------------------------------------------------
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cp -r "$FIXTURE/." "$TMP/"

# ---------------------------------------------------------------------------
# Sanity: script is executable
# ---------------------------------------------------------------------------
assert_executable "$SCRIPT" "migrate.sh is executable"

# ---------------------------------------------------------------------------
# Preview mode: exits 0, writes nothing
# ---------------------------------------------------------------------------
(cd "$TMP" && bash "$SCRIPT" --preview > /dev/null)
echo "OK  [preview: exits 0]"

if [[ -d "$TMP/docs/maxi/specs" ]]; then
  echo "FAIL [preview: must not write docs/maxi/specs/]" >&2
  failures=$((failures + 1))
else
  echo "OK  [preview: no files written]"
fi

# ---------------------------------------------------------------------------
# Preview manifest content
# ---------------------------------------------------------------------------
preview_out=$(cd "$TMP" && bash "$SCRIPT" --preview 2>&1)

if echo "$preview_out" | grep -q "001-shipped-feature.*status=done"; then
  echo "OK  [preview: 001 inferred as done]"
else
  echo "FAIL [preview: expected 001-shipped-feature to be status=done]" >&2
  echo "     Output was: $(echo "$preview_out" | grep '001-shipped' || echo '<no match>')" >&2
  failures=$((failures + 1))
fi

if echo "$preview_out" | grep -q "002-draft-feature.*status=specified"; then
  echo "OK  [preview: 002 inferred as specified]"
else
  echo "FAIL [preview: expected 002-draft-feature to be status=specified]" >&2
  echo "     Output was: $(echo "$preview_out" | grep '002-draft' || echo '<no match>')" >&2
  failures=$((failures + 1))
fi

if echo "$preview_out" | grep -q "constitution"; then
  echo "OK  [preview: constitution mentioned]"
else
  echo "FAIL [preview: constitution not mentioned in preview output]" >&2
  failures=$((failures + 1))
fi

# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------
(cd "$TMP" && bash "$SCRIPT" --apply --yes > /dev/null)
echo "OK  [apply: exits 0]"

# ---------------------------------------------------------------------------
# Shipped spec: status=done, YAML frontmatter, aux files preserved
# ---------------------------------------------------------------------------
spec1="$TMP/docs/maxi/specs/001-shipped-feature/spec.md"
assert_file_exists "$spec1" "001 spec.md created"
assert_starts_with_yaml_frontmatter "$spec1" "001 spec.md has YAML frontmatter"
assert_grep "$spec1" "^status: done$" "001 spec.md status=done"
assert_grep "$spec1" "^slug: 001-shipped-feature$" "001 spec.md slug set"
assert_grep "$spec1" "^created: 2026-01-15$" "001 spec.md created date parsed"
assert_grep "$spec1" "^# Feature Specification: Shipped Feature$" "001 spec.md H1 preserved"
assert_not_grep "$spec1" "^\*\*Status\*\*:" "001 spec.md inline Status stripped"
assert_not_grep "$spec1" "^\*\*Created\*\*:" "001 spec.md inline Created stripped"
assert_not_grep "$spec1" "^\*\*Feature Branch\*\*:" "001 spec.md inline Feature Branch stripped"
assert_not_grep "$spec1" "^\*\*Input\*\*:" "001 spec.md inline Input stripped"

# plan.md: frontmatter added
plan1="$TMP/docs/maxi/specs/001-shipped-feature/plan.md"
assert_file_exists "$plan1" "001 plan.md created"
assert_starts_with_yaml_frontmatter "$plan1" "001 plan.md has YAML frontmatter"
assert_grep "$plan1" "^slug: 001-shipped-feature$" "001 plan.md slug set"

# tasks.md: frontmatter added
tasks1="$TMP/docs/maxi/specs/001-shipped-feature/tasks.md"
assert_file_exists "$tasks1" "001 tasks.md created"
assert_starts_with_yaml_frontmatter "$tasks1" "001 tasks.md has YAML frontmatter"
assert_grep "$tasks1" "^slug: 001-shipped-feature$" "001 tasks.md slug set"

# Aux files
assert_file_exists "$TMP/docs/maxi/specs/001-shipped-feature/retrospective.md" "001 retrospective.md preserved"
assert_file_exists "$TMP/docs/maxi/specs/001-shipped-feature/research.md"      "001 research.md preserved"

# ---------------------------------------------------------------------------
# Draft spec: status=specified, YAML frontmatter
# ---------------------------------------------------------------------------
spec2="$TMP/docs/maxi/specs/002-draft-feature/spec.md"
assert_file_exists "$spec2" "002 spec.md created"
assert_starts_with_yaml_frontmatter "$spec2" "002 spec.md has YAML frontmatter"
assert_grep "$spec2" "^status: specified$" "002 spec.md status=specified"
assert_grep "$spec2" "^slug: 002-draft-feature$" "002 spec.md slug set"
assert_grep "$spec2" "^created: 2026-03-01$" "002 spec.md created date parsed"

# ---------------------------------------------------------------------------
# Constitution
# ---------------------------------------------------------------------------
assert_file_exists "$TMP/docs/constitution.md" "constitution copied"
assert_grep "$TMP/docs/constitution.md" "Test Project Constitution" "constitution content correct"

# ---------------------------------------------------------------------------
# Originals untouched
# ---------------------------------------------------------------------------
assert_file_exists "$TMP/specs/001-shipped-feature/spec.md" "original spec/001 preserved"
assert_file_exists "$TMP/specs/002-draft-feature/spec.md"   "original spec/002 preserved"
assert_file_exists "$TMP/.specify/memory/constitution.md"   "original .specify/ preserved"

# ---------------------------------------------------------------------------
# Idempotency guard: re-running --apply must fail
# ---------------------------------------------------------------------------
if (cd "$TMP" && bash "$SCRIPT" --apply --yes 2>/dev/null); then
  echo "FAIL [idempotency: second apply should have failed]" >&2
  failures=$((failures + 1))
else
  echo "OK  [idempotency: second apply correctly refused]"
fi

summary_and_exit "migrate-from-speckit checks"
