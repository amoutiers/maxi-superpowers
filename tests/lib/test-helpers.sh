# test-helpers.sh — sourced by every check script.
# Requires the caller to declare: failures=0

repo_root() {
  git rev-parse --show-toplevel
}

assert_file_exists() {
  local path="$1" label="$2"
  if [ ! -f "$path" ]; then
    echo "FAIL [$label]: file not found: $path" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

assert_starts_with_yaml_frontmatter() {
  local file="$1" label="$2"
  local first_line
  first_line=$(head -1 "$file")
  if [ "$first_line" != "---" ]; then
    echo "FAIL [$label]: does not start with YAML frontmatter (---)" >&2
    failures=$((failures + 1))
  fi
}

assert_grep() {
  local file="$1" pattern="$2" label="$3"
  if ! grep -q "$pattern" "$file"; then
    echo "FAIL [$label]: missing pattern: $pattern" >&2
    failures=$((failures + 1))
  fi
}

assert_not_grep() {
  local file="$1" pattern="$2" label="$3"
  if grep -q "$pattern" "$file"; then
    echo "FAIL [$label]: unexpected pattern found: $pattern" >&2
    failures=$((failures + 1))
  fi
}

assert_json_valid() {
  local file="$1" label="$2"
  if ! jq empty < "$file" 2>/dev/null; then
    echo "FAIL [$label]: invalid JSON: $file" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]: valid JSON"
  fi
}

assert_jq() {
  local file="$1" expr="$2" expected="$3" label="$4"
  local actual
  actual=$(jq -r "$expr" < "$file" 2>/dev/null)
  if [ "$actual" != "$expected" ]; then
    echo "FAIL [$label]: expected '$expected', got '$actual' (expr: $expr)" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]"
  fi
}

assert_executable() {
  local path="$1" label="$2"
  if [ ! -x "$path" ]; then
    echo "FAIL [$label]: not executable: $path" >&2
    failures=$((failures + 1))
  else
    echo "OK  [$label]: executable"
  fi
}

summary_and_exit() {
  local subject="${1:-checks}"
  if [ "$failures" -gt 0 ]; then
    echo ""
    echo "FAILED: $failures $subject failed" >&2
    exit 1
  fi
  echo ""
  echo "All $subject passed."
}
