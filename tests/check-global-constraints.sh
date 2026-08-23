#!/usr/bin/env bash
# Validates the durable Global Constraints plan contract against fixtures.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

FIXTURES="$ROOT/tests/fixtures/global-constraints"

expected_bullets() {
  awk '
    /^## Expected Global Constraints$/ { in_section=1; next }
    /^## / { if (in_section) exit }
    in_section && /^- / { print }
  ' "$1"
}

plan_bullets() {
  awk '
    /^## Global Constraints$/ { in_section=1; next }
    /^## / { if (in_section) exit }
    in_section && /^- / { print }
  ' "$1"
}

plan_section() {
  awk '
    /^## Global Constraints$/ { in_section=1; next }
    /^## / { if (in_section) exit }
    in_section { print }
  ' "$1"
}

check_case() {
  local expected="$1" spec="$FIXTURES/$2" plan="$FIXTURES/$3"
  local actual="approved"
  local expected_list plan_list plan_text

  if [ "$(grep -c '^## Global Constraints$' "$plan")" -ne 1 ] ||
    grep -Eq '^##+ Delivery Contract$' "$plan"; then
    actual="rejected"
  fi

  expected_list="$(expected_bullets "$spec")"
  plan_list="$(plan_bullets "$plan")"
  plan_text="$(plan_section "$plan")"
  if [ "$expected_list" != "$plan_list" ]; then
    actual="rejected"
  fi

  if printf '%s\n' "$plan_text" | grep -Eqi '(permission|authorization).*(remains authorized|continues to apply|still applies|carries forward|carried forward)|(remains authorized|continues to apply|still applies|carries forward|carried forward).*(permission|authorization)' ||
    { printf '%s\n' "$plan_text" | grep -Eqi 'authorization|authorized' &&
      ! printf '%s\n' "$plan_text" | grep -Eqi 'fresh authorization'; }; then
    actual="rejected"
  fi

  if printf '%s\n' "$plan_text" | grep -Eqi '^[[:space:]]*(-[[:space:]]*)?(current[[:space:]]+)?(worktree|HEAD|selected[[:space:]]+tasks?|task[[:space:]]+selection|stop[[:space:]]+point):[[:space:]]*'; then
    actual="rejected"
  fi

  if [ "$actual" != "$expected" ]; then
    echo "FAIL [$2 + $3]: expected $expected, got $actual" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$2 + $3]: $actual"
  fi
}

check_case approved complete-spec.md complete-plan.md
check_case approved none-spec.md none-plan.md
check_case rejected complete-spec.md omitted-plan.md
check_case rejected complete-spec.md duplicate-plan.md
check_case rejected complete-spec.md stale-authority-plan.md
check_case rejected complete-spec.md transient-continuation-plan.md

assert_grep "$ROOT/skills/plan/SKILL.md" 'scope boundaries.*protected artifacts.*verification evidence.*compatibility.*completion or reporting' "plan: five durable categories"
assert_grep "$ROOT/skills/plan/SKILL.md" 'Git-history.*remote-repository.*deployment/infrastructure.*data-publication.*secret-access' "plan: five authority categories"
assert_grep "$ROOT/skills/plan/SKILL.md" 'exactly one `Global Constraints` section.*delivery-contract' "plan: one canonical section"
assert_grep "$ROOT/skills/plan/SKILL.md" 'simple.*applicable.*bullets' "plan: applicable-only bullets"
assert_grep "$ROOT/skills/plan/SKILL.md" 'No additional global constraints apply.' "plan: explicit none bullet"
assert_grep "$ROOT/skills/plan/SKILL.md" 'worktree.*HEAD.*selected tasks.*stop point' "plan: transient values excluded"
assert_grep "$ROOT/skills/plan/SKILL.md" 'fresh authorization' "plan: fresh authorization allowed"

summary_and_exit "global constraints checks"
