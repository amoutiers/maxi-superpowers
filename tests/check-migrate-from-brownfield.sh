#!/usr/bin/env bash
# Tests skills/migrate-from-brownfield/brownfield.sh deterministic surface
# (guard | write-spec | exclude). The skill (SKILL.md) orchestrates agents and
# consent; this script does file-ops only, so only the deterministic parts are
# unit-tested here. Agent-driven discovery/draft/verify is covered by the
# integration tier.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"
SCRIPT="$ROOT/skills/migrate-from-brownfield/brownfield.sh"
FIXTURE="$ROOT/tests/fixtures/brownfield-project"
failures=0

assert_executable "$SCRIPT" "brownfield.sh is executable"

# ---------------------------------------------------------------------------
# guard
# ---------------------------------------------------------------------------
# passes when constitution + code present
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cp -r "$FIXTURE/." "$TMP/"
if (cd "$TMP" && bash "$SCRIPT" guard >/dev/null 2>&1); then
  echo "OK  [guard: passes with constitution + code]"
else
  echo "FAIL [guard: should pass with constitution + code]" >&2; failures=$((failures+1))
fi

# fails (exit 2) when constitution missing, message points to /maxi:constitution
TMP2=$(mktemp -d)
cp -r "$FIXTURE/." "$TMP2/"; rm -f "$TMP2/docs/maxi/constitution.md"
out=$(cd "$TMP2" && bash "$SCRIPT" guard 2>&1 || true)
rc=$(cd "$TMP2" && { bash "$SCRIPT" guard >/dev/null 2>&1; echo $?; })
rm -rf "$TMP2"
if [[ "$rc" == "2" ]] && echo "$out" | grep -q "maxi:constitution"; then
  echo "OK  [guard: no constitution -> exit 2 + pointer]"
else
  echo "FAIL [guard: expected exit 2 and /maxi:constitution pointer, got rc=$rc]" >&2; failures=$((failures+1))
fi

# fails (exit 3) when no recognized code files
TMP3=$(mktemp -d)
mkdir -p "$TMP3/docs/maxi"; cp "$FIXTURE/docs/maxi/constitution.md" "$TMP3/docs/maxi/"
rc3=$(cd "$TMP3" && { bash "$SCRIPT" guard >/dev/null 2>&1; echo $?; })
rm -rf "$TMP3"
if [[ "$rc3" == "3" ]]; then
  echo "OK  [guard: no code -> exit 3]"
else
  echo "FAIL [guard: expected exit 3 with no code, got rc=$rc3]" >&2; failures=$((failures+1))
fi

# passes on a LARGE nested tree — regression for the grep -q + pipefail SIGPIPE
# false-negative: when find's output exceeds the pipe buffer, grep -q closes the
# pipe on its first match, find dies with SIGPIPE, and pipefail surfaces that as a
# (false) "no code" => exit 3. The 6-file fixture is far too small to trigger it;
# this builds a deep tree whose find output is well over any pipe buffer, with an
# early .rs match so grep -q would close while find is still streaming.
TMP_BIG=$(mktemp -d)
mkdir -p "$TMP_BIG/docs/maxi" "$TMP_BIG/src/a"
cp "$FIXTURE/docs/maxi/constitution.md" "$TMP_BIG/docs/maxi/"
: > "$TMP_BIG/src/a/early.rs"                      # early match for grep -q to latch onto
for d in $(seq 1 50); do
  dir="$TMP_BIG/src/dir_with_a_deliberately_long_name_$d/nested_subdir_with_a_long_name_$d"
  mkdir -p "$dir"
  for f in $(seq 1 60); do : > "$dir/a_reasonably_long_source_file_name_$f.txt"; done
done
rc_big=$(cd "$TMP_BIG" && { bash "$SCRIPT" guard >/dev/null 2>&1; echo $?; })
rm -rf "$TMP_BIG"
if [[ "$rc_big" == "0" ]]; then
  echo "OK  [guard: passes on large nested tree (no SIGPIPE false-negative)]"
else
  echo "FAIL [guard: large tree expected exit 0, got $rc_big]" >&2; failures=$((failures+1))
fi

# ---------------------------------------------------------------------------
# write-spec
# ---------------------------------------------------------------------------
# writes spec with ingress frontmatter, NNNN at write time, Migration Notes
TMP4=$(mktemp -d)
cp -r "$FIXTURE/." "$TMP4/"
printf '# Feature Specification: Billing\n\n- **FR-001**: Issues invoices (src/billing/invoice.js:2)\n' > "$TMP4/body.md"
(cd "$TMP4" && bash "$SCRIPT" write-spec --slug billing --body body.md --sha cafef00d >/dev/null)
new="$TMP4/docs/maxi/specs/0003-billing/spec.md"   # fixture has 0001+0002 -> next is 0003
assert_file_exists "$new" "write-spec: spec written at next NNNN (0003)"
assert_grep "$new" "^status: done$"               "write-spec: status done"
assert_grep "$new" "^origin: reverse-engineered$" "write-spec: origin marker"
assert_grep "$new" "^source_sha: cafef00d$"       "write-spec: source sha recorded"
assert_grep "$new" "^slug: 0003-billing$"         "write-spec: slug set"
assert_grep "$new" "## Migration Notes"           "write-spec: Migration Notes present"
assert_grep "$new" "plan/tasks/analyze/implement" "write-spec: notes phases not run"
for field in revision writer_context structural_contributors derived_from; do
  assert_not_grep "$new" "^${field}:" "write-spec: no forward ${field} metadata"
done
rm -rf "$TMP4"

# ---------------------------------------------------------------------------
# exclude (idempotency)
# ---------------------------------------------------------------------------
# path-overlap: candidate fully covered by existing 0001-auth -> exclude
v=$(cd "$FIXTURE" && bash "$SCRIPT" exclude --name "auth" --paths "src/auth/login.js")
if [[ "$v" == "exclude" ]]; then echo "OK  [exclude: covered candidate excluded]"; \
  else echo "FAIL [exclude: expected 'exclude', got '$v']" >&2; failures=$((failures+1)); fi

# brand-new boundary (billing) -> keep
v=$(cd "$FIXTURE" && bash "$SCRIPT" exclude --name "billing" --paths "src/billing/invoice.js")
if [[ "$v" == "keep" ]]; then echo "OK  [exclude: new candidate kept]"; \
  else echo "FAIL [exclude: expected 'keep', got '$v']" >&2; failures=$((failures+1)); fi

# partial path overlap (auth + billing) -> flag
v=$(cd "$FIXTURE" && bash "$SCRIPT" exclude --name "auth-and-billing" --paths "src/auth/login.js,src/billing/invoice.js")
if [[ "$v" == "flag" ]]; then echo "OK  [exclude: partial overlap flagged]"; \
  else echo "FAIL [exclude: expected 'flag', got '$v']" >&2; failures=$((failures+1)); fi

# E1: name token-set fallback — candidate "reporting" matches the ref-less
# 0002-reporting spec by name (no path overlap) -> exclude
v=$(cd "$FIXTURE" && bash "$SCRIPT" exclude --name "reporting" --paths "src/reporting/report.js")
if [[ "$v" == "exclude" ]]; then echo "OK  [exclude: name token-set fallback excludes ref-less match]"; \
  else echo "FAIL [exclude: expected 'exclude' via name fallback, got '$v']" >&2; failures=$((failures+1)); fi

# whitespace + empty path fields must not demote a fully-covered candidate to flag
v=$(cd "$FIXTURE" && bash "$SCRIPT" exclude --name "auth" --paths "src/auth/login.js, ")
if [[ "$v" == "exclude" ]]; then echo "OK  [exclude: trims whitespace / skips empty path fields]"; \
  else echo "FAIL [exclude: spaced/empty fields expected 'exclude', got '$v']" >&2; failures=$((failures+1)); fi

# directory candidate is covered by file-level refs under it (prefix match)
v=$(cd "$FIXTURE" && bash "$SCRIPT" exclude --name "auth" --paths "src/auth")
if [[ "$v" == "exclude" ]]; then echo "OK  [exclude: directory candidate covered by file refs]"; \
  else echo "FAIL [exclude: dir candidate expected 'exclude', got '$v']" >&2; failures=$((failures+1)); fi

# --- #8: write-spec rejects a non-kebab-case slug (spaces / uppercase) instead of
# creating a malformed NNNN dir + frontmatter that breaks downstream tooling.
TMP_SLUG=$(mktemp -d)
cp -r "$FIXTURE/." "$TMP_SLUG/"
printf '# X\n' > "$TMP_SLUG/body.md"
rc_slug=$(cd "$TMP_SLUG" && { bash "$SCRIPT" write-spec --slug "Bad Slug" --body body.md --sha deadbeef >/dev/null 2>&1; echo $?; })
rm -rf "$TMP_SLUG"
if [[ "$rc_slug" != "0" ]]; then echo "OK  [write-spec: rejects non-kebab-case slug]"; \
  else echo "FAIL [write-spec: should reject slug 'Bad Slug' with nonzero exit, got rc=$rc_slug]" >&2; failures=$((failures+1)); fi

# --- #9: internal spaces in paths are preserved (border-trim only), so a
# spaced-path candidate that exactly matches a spaced-path ref is still excluded
# (idempotency must not silently break on paths that contain spaces).
TMP_SP=$(mktemp -d)
cp -r "$FIXTURE/." "$TMP_SP/"
mkdir -p "$TMP_SP/docs/maxi/specs/0003-spaced"
printf -- '---\nslug: 0003-spaced\norigin: reverse-engineered\n---\n\n- **FR-001**: does X (my dir/page one.js:3)\n' > "$TMP_SP/docs/maxi/specs/0003-spaced/spec.md"
v=$(cd "$TMP_SP" && bash "$SCRIPT" exclude --name "spaced" --paths "my dir/page one.js")
rm -rf "$TMP_SP"
if [[ "$v" == "exclude" ]]; then echo "OK  [exclude: preserves internal spaces (idempotent on spaced paths)]"; \
  else echo "FAIL [exclude: spaced-path candidate expected 'exclude', got '$v']" >&2; failures=$((failures+1)); fi

summary_and_exit "migrate-from-brownfield checks"
