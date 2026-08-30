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
for field in revision writer_context structural_contributors derived_from; do
  assert_not_grep "$spec1" "^${field}:" "001 spec.md has no forward ${field} metadata"
done

# plan.md: frontmatter added
plan1="$TMP/docs/maxi/specs/001-shipped-feature/plan.md"
assert_file_exists "$plan1" "001 plan.md created"
assert_starts_with_yaml_frontmatter "$plan1" "001 plan.md has YAML frontmatter"
assert_grep "$plan1" "^slug: 001-shipped-feature$" "001 plan.md slug set"
for field in revision writer_context structural_contributors derived_from; do
  assert_not_grep "$plan1" "^${field}:" "001 plan.md has no forward ${field} metadata"
done

# tasks.md: frontmatter added
tasks1="$TMP/docs/maxi/specs/001-shipped-feature/tasks.md"
assert_file_exists "$tasks1" "001 tasks.md created"
assert_starts_with_yaml_frontmatter "$tasks1" "001 tasks.md has YAML frontmatter"
assert_grep "$tasks1" "^slug: 001-shipped-feature$" "001 tasks.md slug set"
for field in revision writer_context structural_contributors derived_from; do
  assert_not_grep "$tasks1" "^${field}:" "001 tasks.md has no forward ${field} metadata"
done

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
for field in revision writer_context structural_contributors derived_from; do
  assert_not_grep "$spec2" "^${field}:" "002 spec.md has no forward ${field} metadata"
done

# ---------------------------------------------------------------------------
# Constitution
# ---------------------------------------------------------------------------
assert_file_exists "$TMP/docs/maxi/constitution.md" "constitution copied"
assert_grep "$TMP/docs/maxi/constitution.md" "Test Project Constitution" "constitution content correct"

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

# ---------------------------------------------------------------------------
# YAML descriptions quote arbitrary feature headings safely
# ---------------------------------------------------------------------------
quote_case="$TMP/quote-case"
mkdir -p "$quote_case"
cp -r "$FIXTURE/." "$quote_case/"
sed -i.bak 's|^# Feature Specification:.*$|# Feature "alpha" and O'"'"'Brien|' \
  "$quote_case/specs/001-shipped-feature/spec.md"
rm "$quote_case/specs/001-shipped-feature/spec.md.bak"
(cd "$quote_case" && bash "$SCRIPT" --apply --yes >/dev/null)
assert_grep \
  "$quote_case/docs/maxi/specs/001-shipped-feature/tasks.md" \
  "^description: 'Tasks: Feature \"alpha\" and O''Brien'$" \
  "tasks description is a valid escaped YAML scalar"

# ---------------------------------------------------------------------------
# Invalid source metadata must fail in both modes before creating docs/
# ---------------------------------------------------------------------------
bad_slug_case="$TMP/bad-slug-case"
cp -r "$FIXTURE/." "$bad_slug_case/"
mv "$bad_slug_case/specs/002-draft-feature" "$bad_slug_case/specs/003-bad_slug"
for mode in --preview --apply; do
  if (cd "$bad_slug_case" && bash "$SCRIPT" "$mode" --yes >/dev/null 2>&1); then
    echo "FAIL [invalid slug: $mode should fail]" >&2
    failures=$((failures + 1))
  else
    echo "OK  [invalid slug: $mode refused before mutation]"
  fi
done
if [[ -e "$bad_slug_case/docs" ]]; then
  echo "FAIL [invalid slug: docs/ must not be created]" >&2
  failures=$((failures + 1))
else
  echo "OK  [invalid slug: docs/ absent]"
fi

bad_date_case="$TMP/bad-date-case"
cp -r "$FIXTURE/." "$bad_date_case/"
sed -i.bak 's|^\*\*Created\*\*:.*$|**Created**: 2026-08-30: injected|' \
  "$bad_date_case/specs/001-shipped-feature/spec.md"
rm "$bad_date_case/specs/001-shipped-feature/spec.md.bak"
for mode in --preview --apply; do
  if (cd "$bad_date_case" && bash "$SCRIPT" "$mode" --yes >/dev/null 2>&1); then
    echo "FAIL [invalid Created date: $mode should fail]" >&2
    failures=$((failures + 1))
  else
    echo "OK  [invalid Created date: $mode refused before mutation]"
  fi
done
if [[ -e "$bad_date_case/docs" ]]; then
  echo "FAIL [invalid Created date: docs/ must not be created]" >&2
  failures=$((failures + 1))
else
  echo "OK  [invalid Created date: docs/ absent]"
fi

# ---------------------------------------------------------------------------
# Existing destination safety and symlink rejection
# ---------------------------------------------------------------------------
symlink_case="$TMP/symlink-case"
outside="$TMP/outside-sentinel"
cp -r "$FIXTURE/." "$symlink_case/"
mkdir "$outside"
ln -s "$outside" "$symlink_case/docs"
if (cd "$symlink_case" && bash "$SCRIPT" --apply --yes >/dev/null 2>&1); then
  echo "FAIL [symlinked docs: apply should fail]" >&2
  failures=$((failures + 1))
else
  echo "OK  [symlinked docs: apply refused]"
fi
if [[ -e "$outside/maxi" ]]; then
  echo "FAIL [symlinked docs: outside sentinel was modified]" >&2
  failures=$((failures + 1))
else
  echo "OK  [symlinked docs: outside sentinel untouched]"
fi

constitution_symlink_case="$TMP/constitution-symlink-case"
outside_constitution="$TMP/outside-constitution.md"
cp -r "$FIXTURE/." "$constitution_symlink_case/"
mkdir -p "$constitution_symlink_case/docs/maxi"
ln -s "$outside_constitution" "$constitution_symlink_case/docs/maxi/constitution.md"
if (cd "$constitution_symlink_case" && bash "$SCRIPT" --apply --yes >/dev/null 2>&1); then
  echo "FAIL [symlinked constitution: apply should fail]" >&2
  failures=$((failures + 1))
else
  echo "OK  [symlinked constitution: apply refused]"
fi
if [[ -e "$outside_constitution" ]]; then
  echo "FAIL [symlinked constitution: outside file was written]" >&2
  failures=$((failures + 1))
else
  echo "OK  [symlinked constitution: outside file absent]"
fi
if [[ -e "$constitution_symlink_case/docs/maxi/specs" ]]; then
  echo "FAIL [symlinked constitution: specs were installed]" >&2
  failures=$((failures + 1))
else
  echo "OK  [symlinked constitution: specs absent]"
fi

constitution_directory_case="$TMP/constitution-directory-case"
cp -r "$FIXTURE/." "$constitution_directory_case/"
mkdir -p "$constitution_directory_case/docs/maxi/constitution.md"
printf 'keep\n' > "$constitution_directory_case/docs/maxi/constitution.md/sentinel"
if (cd "$constitution_directory_case" && bash "$SCRIPT" --apply --yes >/dev/null 2>&1); then
  echo "FAIL [constitution directory: apply should fail]" >&2
  failures=$((failures + 1))
else
  echo "OK  [constitution directory: apply refused]"
fi
assert_grep "$constitution_directory_case/docs/maxi/constitution.md/sentinel" '^keep$' \
  "constitution directory is unchanged"
if [[ -e "$constitution_directory_case/docs/maxi/constitution.md/constitution.md" ]]; then
  echo "FAIL [constitution directory: source was copied inside destination]" >&2
  failures=$((failures + 1))
else
  echo "OK  [constitution directory: no nested copy]"
fi
if [[ -e "$constitution_directory_case/docs/maxi/specs" ]]; then
  echo "FAIL [constitution directory: specs were installed]" >&2
  failures=$((failures + 1))
else
  echo "OK  [constitution directory: specs absent]"
fi

constitution_source_absent_case="$TMP/constitution-source-absent-case"
cp -r "$FIXTURE/." "$constitution_source_absent_case/"
rm "$constitution_source_absent_case/.specify/memory/constitution.md"
(cd "$constitution_source_absent_case" && bash "$SCRIPT" --apply --yes >/dev/null)
assert_file_exists "$constitution_source_absent_case/docs/maxi/specs/001-shipped-feature/spec.md" \
  "missing constitution source: specs are installed"
if [[ -e "$constitution_source_absent_case/docs/maxi/constitution.md" ]]; then
  echo "FAIL [missing constitution source: no destination should be created]" >&2
  failures=$((failures + 1))
else
  echo "OK  [missing constitution source: no destination created]"
fi

# ---------------------------------------------------------------------------
# Constitution copy must not follow a destination created after classification
# ---------------------------------------------------------------------------
constitution_race_case="$TMP/constitution-race-case"
constitution_race_wrapper="$TMP/constitution-race-wrapper"
constitution_race_capture="$TMP/constitution-race-capture"
constitution_race_reader_pid="$TMP/constitution-race-reader.pid"
constitution_race_marker="$TMP/constitution-race-marker"
cp -r "$FIXTURE/." "$constitution_race_case/"
mkdir "$constitution_race_wrapper"
RACE_REAL_CP=$(command -v cp)
export RACE_REAL_CP
export RACE_CONST_DST="docs/maxi/constitution.md"
export RACE_CAPTURE="$constitution_race_capture"
export RACE_READER_PID="$constitution_race_reader_pid"
export RACE_MARKER="$constitution_race_marker"
cat > "$constitution_race_wrapper/cp" <<'EOF'
#!/usr/bin/env bash
if [ ! -e "$RACE_MARKER" ]; then
  : > "$RACE_MARKER"
  mkfifo "$RACE_CONST_DST"
  cat "$RACE_CONST_DST" > "$RACE_CAPTURE" &
  printf '%s\n' "$!" > "$RACE_READER_PID"
fi
exec "$RACE_REAL_CP" "$@"
EOF
chmod +x "$constitution_race_wrapper/cp"
if (cd "$constitution_race_case" && PATH="$constitution_race_wrapper:$PATH" bash "$SCRIPT" --apply --yes >/dev/null 2>&1); then
  echo "FAIL [constitution FIFO race: apply should fail]" >&2
  failures=$((failures + 1))
else
  echo "OK  [constitution FIFO race: apply refused]"
fi
if [[ -f "$constitution_race_reader_pid" ]]; then
  constitution_reader_pid=$(sed -n '1p' "$constitution_race_reader_pid")
  kill "$constitution_reader_pid" 2>/dev/null || true
fi
if [[ -e "$constitution_race_case/docs/maxi/specs" ]]; then
  echo "FAIL [constitution FIFO race: specs were installed]" >&2
  failures=$((failures + 1))
else
  echo "OK  [constitution FIFO race: specs absent]"
fi
if find "$constitution_race_case/docs/maxi" -maxdepth 1 -name '.specs-migration.*' -print | grep -q .; then
  echo "FAIL [constitution FIFO race: staging directory was not cleaned]" >&2
  failures=$((failures + 1))
else
  echo "OK  [constitution FIFO race: staging directory cleaned]"
fi

# ---------------------------------------------------------------------------
# A pre-existing cooperative lock blocks installation without nested specs/
# ---------------------------------------------------------------------------
lock_case="$TMP/lock-case"
cp -r "$FIXTURE/." "$lock_case/"
mkdir -p "$lock_case/docs/maxi"
mkdir "$lock_case/docs/maxi/.specs-migration.lock"
if (cd "$lock_case" && bash "$SCRIPT" --apply --yes >/dev/null 2>&1); then
  echo "FAIL [migration lock: apply should fail]" >&2
  failures=$((failures + 1))
else
  echo "OK  [migration lock: apply refused]"
fi
if [[ -e "$lock_case/docs/maxi/specs" ]]; then
  echo "FAIL [migration lock: specs were installed]" >&2
  failures=$((failures + 1))
else
  echo "OK  [migration lock: specs absent]"
fi
if [[ -e "$lock_case/docs/maxi/specs/specs" ]]; then
  echo "FAIL [migration lock: nested specs were installed]" >&2
  failures=$((failures + 1))
else
  echo "OK  [migration lock: no nested specs]"
fi
rmdir "$lock_case/docs/maxi/.specs-migration.lock"
if (cd "$lock_case" && bash "$SCRIPT" --apply --yes >/dev/null); then
  echo "OK  [migration lock: rerun succeeds after release]"
else
  echo "FAIL [migration lock: rerun should succeed after release]" >&2
  failures=$((failures + 1))
fi
assert_file_exists "$lock_case/docs/maxi/specs/001-shipped-feature/spec.md" \
  "migration lock: successful rerun installs specs"
if [[ -e "$lock_case/docs/maxi/.specs-migration.lock" ]]; then
  echo "FAIL [migration lock: successful rerun releases lock]" >&2
  failures=$((failures + 1))
else
  echo "OK  [migration lock: successful rerun releases lock]"
fi

nonempty_case="$TMP/nonempty-case"
cp -r "$FIXTURE/." "$nonempty_case/"
mkdir -p "$nonempty_case/docs/maxi/specs"
printf 'keep\n' > "$nonempty_case/docs/maxi/specs/sentinel"
if (cd "$nonempty_case" && bash "$SCRIPT" --apply --yes >/dev/null 2>&1); then
  echo "FAIL [non-empty destination: apply should fail]" >&2
  failures=$((failures + 1))
else
  echo "OK  [non-empty destination: apply refused]"
fi
assert_grep "$nonempty_case/docs/maxi/specs/sentinel" '^keep$' \
  "non-empty destination is unchanged"

# ---------------------------------------------------------------------------
# Failed copies leave no installed specs or staging directory, and rerun works
# ---------------------------------------------------------------------------
cp_case="$TMP/cp-failure-case"
cp_wrapper="$TMP/cp-wrapper"
cp_count="$TMP/cp-count"
cp -r "$FIXTURE/." "$cp_case/"
mkdir "$cp_wrapper"
REAL_CP=$(command -v cp)
export REAL_CP
export CP_COUNT_FILE="$cp_count"
cat > "$cp_wrapper/cp" <<'EOF'
#!/usr/bin/env bash
count=$(sed -n '1p' "$CP_COUNT_FILE" 2>/dev/null || true)
count=${count:-0}
count=$((count + 1))
printf '%s\n' "$count" > "$CP_COUNT_FILE"
[ "$count" -ne 2 ] || exit 77
exec "$REAL_CP" "$@"
EOF
chmod +x "$cp_wrapper/cp"
if (cd "$cp_case" && PATH="$cp_wrapper:$PATH" bash "$SCRIPT" --apply --yes >/dev/null 2>&1); then
  echo "FAIL [copy failure: apply should fail]" >&2
  failures=$((failures + 1))
else
  echo "OK  [copy failure: apply failed]"
fi
if [[ -e "$cp_case/docs/maxi/specs" ]]; then
  echo "FAIL [copy failure: final specs directory must not exist]" >&2
  failures=$((failures + 1))
else
  echo "OK  [copy failure: final specs directory absent]"
fi
if find "$cp_case/docs/maxi" -maxdepth 1 -name '.specs-migration.*' -print | grep -q .; then
  echo "FAIL [copy failure: staging directory was not cleaned]" >&2
  failures=$((failures + 1))
else
  echo "OK  [copy failure: staging directory cleaned]"
fi
(cd "$cp_case" && bash "$SCRIPT" --apply --yes >/dev/null)
assert_file_exists "$cp_case/docs/maxi/specs/001-shipped-feature/spec.md" \
  "copy failure: normal rerun succeeds"

# ---------------------------------------------------------------------------
# A failed staging cleanup must not prevent owned-lock cleanup
# ---------------------------------------------------------------------------
cleanup_case="$TMP/cleanup-failure-case"
cleanup_wrapper="$TMP/cleanup-wrapper"
cleanup_count="$TMP/cleanup-cp-count"
cp -r "$FIXTURE/." "$cleanup_case/"
mkdir "$cleanup_wrapper"
CLEANUP_REAL_CP=$(command -v cp)
CLEANUP_REAL_RM=$(command -v rm)
export CLEANUP_REAL_CP CLEANUP_REAL_RM
export CLEANUP_CP_COUNT_FILE="$cleanup_count"
cat > "$cleanup_wrapper/cp" <<'EOF'
#!/usr/bin/env bash
count=$(sed -n '1p' "$CLEANUP_CP_COUNT_FILE" 2>/dev/null || true)
count=${count:-0}
count=$((count + 1))
printf '%s\n' "$count" > "$CLEANUP_CP_COUNT_FILE"
[ "$count" -ne 2 ] || exit 77
exec "$CLEANUP_REAL_CP" "$@"
EOF
cat > "$cleanup_wrapper/rm" <<'EOF'
#!/usr/bin/env bash
[ "$1" != "-rf" ] || exit 88
exec "$CLEANUP_REAL_RM" "$@"
EOF
chmod +x "$cleanup_wrapper/cp" "$cleanup_wrapper/rm"
if (cd "$cleanup_case" && PATH="$cleanup_wrapper:$PATH" bash "$SCRIPT" --apply --yes >/dev/null 2>&1); then
  echo "FAIL [cleanup failure: apply should fail]" >&2
  failures=$((failures + 1))
else
  echo "OK  [cleanup failure: apply failed]"
fi
if [[ -e "$cleanup_case/docs/maxi/.specs-migration.lock" ]]; then
  echo "FAIL [cleanup failure: owned lock was not released]" >&2
  failures=$((failures + 1))
else
  echo "OK  [cleanup failure: owned lock released]"
fi

summary_and_exit "migrate-from-speckit checks"
