#!/usr/bin/env bash
# Exercise the versioned readiness evidence contract against real files.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
CONTRACT="$ROOT/skills/analyze/readiness-contract.sh"
source "$ROOT/tests/lib/test-helpers.sh"

failures=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BASE="$TMP/base"
mkdir -p "$BASE"

cat > "$BASE/spec.md" <<'EOF'
---
slug: 0001-readiness-fixture
created: 2026-08-30
updated: 2026-08-30
status: tasked
---

# Fixture spec

Requirement A.
EOF

cat > "$BASE/plan.md" <<'EOF'
---
slug: 0001-readiness-fixture
spec_slug: 0001-readiness-fixture
created: 2026-08-30
updated: 2026-08-30
---

# Plan

Implement requirement A.
EOF

cat > "$BASE/tasks.md" <<'EOF'
---
description: Fixture tasks
slug: 0001-readiness-fixture
spec_slug: 0001-readiness-fixture
created: 2026-08-30
updated: 2026-08-30
---

- [ ] T001 Implement requirement A
EOF

cat > "$BASE/analysis.md" <<'EOF'
# Readiness analysis

No critical issues.
EOF

ok() {
  echo "OK  [$1]"
}

fail() {
  echo "FAIL [$1]: ${2:-contract mismatch}" >&2
  failures=$((failures + 1))
}

copy_fixture() {
  local name="$1" target
  target="$TMP/$name"
  mkdir -p "$target"
  cp "$BASE"/*.md "$target/"
  printf '%s\n' "$target"
}

rewrite() {
  local file="$1" program="$2" tmp
  tmp="$file.tmp"
  awk "$program" "$file" > "$tmp"
  mv "$tmp" "$file"
}

stamp() {
  local dir="$1" outcome="$2" count="$3"
  bash "$CONTRACT" stamp \
    "$dir/analysis.md" "$dir/spec.md" "$dir/plan.md" "$dir/tasks.md" \
    "$outcome" "$count"
}

verify() {
  local dir="$1"
  bash "$CONTRACT" verify \
    "$dir/analysis.md" "$dir/spec.md" "$dir/plan.md" "$dir/tasks.md"
}

expect_verify_success() {
  local label="$1" dir="$2" output status
  set +e
  output="$(verify "$dir" 2>"$dir/verify.err")"
  status=$?
  set -e
  if [ "$status" -eq 0 ] && [ "$output" = READINESS_VERIFIED ] &&
     [ "$(printf '%s\n' "$output" | grep -c '^READINESS_VERIFIED$')" -eq 1 ]; then
    ok "$label"
  else
    fail "$label" "status=$status output='$output'"
  fi
}

expect_verify_failure() {
  local label="$1" dir="$2" output status
  set +e
  output="$(verify "$dir" 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 0 ] && ! printf '%s\n' "$output" | grep -q READINESS_VERIFIED; then
    ok "$label"
  else
    fail "$label" "status=$status output='$output'"
  fi
}

expect_command_failure() {
  local label="$1"
  shift
  local output status
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
  if [ "$status" -ne 0 ] && ! printf '%s\n' "$output" | grep -q READINESS_VERIFIED; then
    ok "$label"
  else
    fail "$label" "status=$status output='$output'"
  fi
}

GOOD="$(copy_fixture good)"
if stamp "$GOOD" pass 0 >/dev/null 2>&1; then
  ok "stamp accepts pass with zero critical issues"
else
  fail "stamp accepts pass with zero critical issues"
fi
expect_verify_success "fresh pass stamp verifies with one exact token" "$GOOD"

awk 'seen { print } $0 == "---" && NR > 1 { seen = 1 }' "$GOOD/analysis.md" > "$GOOD/body"
if cmp -s "$BASE/analysis.md" "$GOOD/body"; then
  ok "stamp preserves the existing report body"
else
  fail "stamp preserves the existing report body"
fi

case "$(sed -n '1,8p' "$GOOD/analysis.md")" in
  $'---\nreadiness_contract: maxi-readiness-v1\noutcome: pass\ncritical_issues: 0\nspec_structural_sha256: '????????????????????????????????????????????????????????????????$'\nplan_sha256: '????????????????????????????????????????????????????????????????$'\ntasks_structural_sha256: '????????????????????????????????????????????????????????????????$'\n---')
    ok "stamp writes the exact six-field envelope" ;;
  *) fail "stamp writes the exact six-field envelope" ;;
esac

case_dir="$(copy_fixture spec-metadata)"
cp "$GOOD/analysis.md" "$case_dir/analysis.md"
rewrite "$case_dir/spec.md" '{ if ($0 == "updated: 2026-08-30") print "updated: 2026-08-31"; else if ($0 == "status: tasked") print "status: analyzed"; else print }'
expect_verify_success "spec status and updated are normalized" "$case_dir"

case_dir="$(copy_fixture tasks-metadata)"
cp "$GOOD/analysis.md" "$case_dir/analysis.md"
rewrite "$case_dir/tasks.md" '{ if ($0 == "updated: 2026-08-30") print "updated: 2026-08-31"; else if ($0 == "- [ ] T001 Implement requirement A") print "- [x] T001 Implement requirement A"; else print }'
expect_verify_success "tasks updated and canonical checkbox state are normalized" "$case_dir"

case_dir="$(copy_fixture spec-body)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; printf '\nRequirement B.\n' >> "$case_dir/spec.md"
expect_verify_failure "spec body changes invalidate readiness" "$case_dir"

case_dir="$(copy_fixture plan-bytes)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; printf '\nExtra plan byte.\n' >> "$case_dir/plan.md"
expect_verify_failure "plan byte changes invalidate readiness" "$case_dir"

case_dir="$(copy_fixture task-text)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; rewrite "$case_dir/tasks.md" '{ sub(/Implement requirement A/, "Implement requirement B"); print }'
expect_verify_failure "task text changes invalidate readiness" "$case_dir"

case_dir="$(copy_fixture task-id)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; rewrite "$case_dir/tasks.md" '{ sub(/T001/, "T002"); print }'
expect_verify_failure "task ID changes invalidate readiness" "$case_dir"

case_dir="$(copy_fixture task-added)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; printf '%s\n' '- [ ] T002 Implement requirement B' >> "$case_dir/tasks.md"
expect_verify_failure "adding a canonical task invalidates readiness" "$case_dir"

case_dir="$(copy_fixture missing-analysis)"; rm "$case_dir/analysis.md"
expect_verify_failure "missing analysis is rejected" "$case_dir"

case_dir="$(copy_fixture body-only-analysis)"
expect_verify_failure "body-only analysis is rejected" "$case_dir"

case_dir="$(copy_fixture duplicate-field)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; rewrite "$case_dir/analysis.md" '{ print; if ($0 == "outcome: pass") print "outcome: pass" }'
expect_verify_failure "duplicate contract field is rejected" "$case_dir"

case_dir="$(copy_fixture unknown-field)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; rewrite "$case_dir/analysis.md" '{ print; if ($0 == "outcome: pass") print "extra: no" }'
expect_verify_failure "unknown contract field is rejected" "$case_dir"

case_dir="$(copy_fixture malformed-hash)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; rewrite "$case_dir/analysis.md" '{ if ($0 ~ /^plan_sha256:/) print "plan_sha256: ABC"; else print }'
expect_verify_failure "malformed hash is rejected" "$case_dir"

case_dir="$(copy_fixture unsupported-version)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; rewrite "$case_dir/analysis.md" '{ if ($0 ~ /^readiness_contract:/) print "readiness_contract: maxi-readiness-v2"; else print }'
expect_verify_failure "unsupported contract version is rejected" "$case_dir"

case_dir="$(copy_fixture blocked-outcome)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; rewrite "$case_dir/analysis.md" '{ if ($0 == "outcome: pass") print "outcome: blocked"; else print }'
expect_verify_failure "blocked outcome is rejected" "$case_dir"

case_dir="$(copy_fixture critical-positive)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; rewrite "$case_dir/analysis.md" '{ if ($0 == "critical_issues: 0") print "critical_issues: 1"; else print }'
expect_verify_failure "positive critical count is rejected" "$case_dir"

case_dir="$(copy_fixture pass-one)"; cp "$case_dir/analysis.md" "$case_dir/before"
expect_command_failure "pass with positive critical count is rejected" stamp "$case_dir" pass 1
cmp -s "$case_dir/before" "$case_dir/analysis.md" && ok "invalid pass leaves report unchanged" || fail "invalid pass leaves report unchanged"

case_dir="$(copy_fixture blocked-zero)"; cp "$case_dir/analysis.md" "$case_dir/before"
expect_command_failure "blocked with zero critical issues is rejected" stamp "$case_dir" blocked 0
cmp -s "$case_dir/before" "$case_dir/analysis.md" && ok "invalid blocked leaves report unchanged" || fail "invalid blocked leaves report unchanged"

case_dir="$(copy_fixture blocked-two)"
if stamp "$case_dir" blocked 2 >/dev/null 2>&1 && grep -q '^outcome: blocked$' "$case_dir/analysis.md" && grep -q '^critical_issues: 2$' "$case_dir/analysis.md"; then
  ok "blocked with positive count writes evidence"
else
  fail "blocked with positive count writes evidence"
fi
expect_verify_failure "blocked stamped evidence cannot verify" "$case_dir"

case_dir="$(copy_fixture symlink-file)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; mv "$case_dir/plan.md" "$case_dir/plan-target"; ln -s plan-target "$case_dir/plan.md"
expect_verify_failure "symlinked input file is rejected" "$case_dir"

case_dir="$(copy_fixture wrong-basename)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; mv "$case_dir/plan.md" "$case_dir/design.md"
expect_command_failure "wrong input basename is rejected" bash "$CONTRACT" verify "$case_dir/analysis.md" "$case_dir/spec.md" "$case_dir/design.md" "$case_dir/tasks.md"

case_dir="$(copy_fixture split-directory)"; cp "$GOOD/analysis.md" "$case_dir/analysis.md"; mkdir "$case_dir/other"; mv "$case_dir/tasks.md" "$case_dir/other/tasks.md"
expect_command_failure "inputs from different physical directories are rejected" bash "$CONTRACT" verify "$case_dir/analysis.md" "$case_dir/spec.md" "$case_dir/plan.md" "$case_dir/other/tasks.md"

expect_command_failure "unknown mode is rejected" bash "$CONTRACT" inspect
expect_command_failure "verify arity is exact" bash "$CONTRACT" verify "$GOOD/analysis.md"

summary_and_exit "readiness contract checks"
