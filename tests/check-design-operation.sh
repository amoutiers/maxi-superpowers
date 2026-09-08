#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
source "$ROOT/tests/lib/test-helpers.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fixture="$(cd "$tmp" && pwd -P)"
dir="$fixture/docs/maxi/specs/0001-operation"
mkdir -p "$dir/reviews" "$fixture/docs/maxi/adr"
printf '# Constitution\n' > "$fixture/docs/maxi/constitution.md"
printf '# Spec\n' > "$dir/spec.md"
printf '# Plan\n' > "$dir/plan.md"
spec="$dir/spec.md"; plan="$dir/plan.md"; report="$dir/reviews/design-review.md"
contract="$ROOT/skills/review/design-contract.sh"
sha() { shasum -a 256 < "$1" | awk '{print $1}'; }
op="$(sha "$spec")"; request="$(sha "$plan")"; report_sha=absent
bash "$contract" reserve "$report" "$spec" "$plan" "$fixture" "$op" "$request" coordinated unavailable "$report_sha"
if bash "$contract" verify "$report" "$spec" "$plan" "$fixture" > "$tmp/rejected.out" 2>&1; then exit 1; fi
before="$(sha "$report")"
if bash "$contract" reserve "$report" "$spec" "$plan" "$fixture" "$op" "$request" coordinated unavailable "$before" > "$tmp/rejected.out" 2>&1; then exit 1; fi
[ "$before" = "$(sha "$report")" ]
assert_grep "$report" '^phase: reserved$' 'fresh reservation'

reject() {
  local label="$1" status=0; shift
  "$@" > "$tmp/rejected.out" 2>&1 || status=$?
  if [ "$status" -ne 2 ]; then
    echo "FAIL [$label]: expected exit 2, got $status" >&2; exit 1
  fi
  echo "OK  [$label]"
}
reserve() { bash "$contract" reserve "$report" "$spec" "$plan" "$fixture" "$op" "$request" "${mode:-coordinated}" "${reviewer:-unavailable}" "$(sha "$report")"; }
operation() { bash "$contract" operation "$report" "$spec" "$plan" "$fixture" "$op"; }
stop() { bash "$contract" stop-operation "$report" "$spec" "$plan" "$fixture" "$op" "$(sha "$report")"; }
make_candidate() {
  awk -v verdict="$1" '!changed && $0 == "phase: reserved" { $0="phase: " verdict; changed=1 } {print}' "$report" > "$dir/reviews/.candidate"
  printf '\nFinding: retain this correction evidence.\nVERDICT: %s\n' "$1" >> "$dir/reviews/.candidate"
}
publish() {
  bash "$contract" stamp-operation "$dir/reviews/.candidate" "$report" "$spec" "$plan" "$1" "$fixture" "$inputs" "$op" "${expected:-$(sha "$report")}"
}
inputs="$(bash "$ROOT/skills/review/review-inputs.sh" hash "$fixture")"
operation
# Count only dispatches authorized by a successful reservation, including resume.
printf '1\n' > "$tmp/dispatches"
if reserve > /dev/null 2>&1; then printf 'dispatch\n' >> "$tmp/dispatches"; fi
[ "$(wc -l < "$tmp/dispatches" | tr -d ' ')" = 1 ]
assert_grep "$tmp/dispatches" '^1$' 'interrupted reservation cannot redispatch'
other="$(sha "$fixture/docs/maxi/constitution.md")"
reject 'operation identity mismatch' bash "$contract" operation "$report" "$spec" "$plan" "$fixture" "$other"
reject 'active operation cannot be replaced' bash "$contract" reserve "$report" "$spec" "$plan" "$fixture" "$other" "$request" coordinated unavailable "$(sha "$report")"
make_candidate rejected
expected="$other"; reject 'stale publication hash' publish rejected; unset expected
cp "$report" "$tmp/pending"
for field in spec plan adr; do
  case "$field" in spec) file="$spec";; plan) file="$plan";; adr) file="$fixture/docs/maxi/adr/0001-new.md";; esac
  [ ! -f "$file" ] || cp "$file" "$tmp/original"
  printf '\nChanged\n' >> "$file"
  reject "edited $field rejects publication" publish rejected
  assert_files_equal "$report" "$tmp/pending" 'freshness failure preserves report'
  if [ "$field" = adr ]; then rm "$file"; else mv "$tmp/original" "$file"; fi
done
cp "$dir/reviews/.candidate" "$tmp/valid-candidate"
for corruption in duplicate invalid reserved-marker verdict; do
  cp "$tmp/valid-candidate" "$dir/reviews/.candidate"
  case "$corruption" in
    duplicate) sed 's/^passes: 1$/passes: 1\npasses: 1/' "$tmp/valid-candidate" > "$dir/reviews/.candidate";;
    invalid) sed 's/^passes: 1$/passes: 3/' "$tmp/valid-candidate" > "$dir/reviews/.candidate";;
    reserved-marker) printf '<!-- maxi-design-operation-v1\n' >> "$dir/reviews/.candidate";;
    verdict) printf 'VERDICT: rejected\n' >> "$dir/reviews/.candidate";;
  esac
  reject "$corruption candidate" publish rejected
  assert_files_equal "$report" "$tmp/pending" 'invalid candidate preserves report'
done
cp "$tmp/valid-candidate" "$dir/reviews/.candidate"
publish rejected
assert_grep "$report" '^phase: rejected$' 'rejected first pass published'
printf 'Corrected\n' >> "$plan"
reserve
assert_grep "$report" '^passes: 2$' 'corrected second pass reserved'
assert_grep "$report" 'Finding: retain this correction evidence' 'prior findings retained'
before="$(sha "$report")"
reject 'second reserved pass cannot dispatch again' reserve
[ "$before" = "$(sha "$report")" ]
make_candidate approved
cp "$dir/reviews/.candidate" "$tmp/complete-candidate"
# Dropping the framed previous findings must not publish a clean-looking pass two.
awk 'NR<=12 {print} END {print "VERDICT: approved"}' "$tmp/complete-candidate" > "$dir/reviews/.candidate"
reject 'candidate cannot discard previous findings' publish approved
cp "$tmp/complete-candidate" "$dir/reviews/.candidate"
publish approved
bash "$contract" verify "$report" "$spec" "$plan" "$fixture"
reject 'approved operation cannot consume third pass' reserve
printf '# Legacy body\n' > "$dir/reviews/.legacy"
reject 'legacy stamp cannot erase managed guard' bash "$contract" stamp "$dir/reviews/.legacy" "$report" "$spec" "$plan" approved "$fixture" "$inputs"
cp "$report" "$tmp/approved"
# A fresh identity after a terminal operation retains the prior managed report as opaque history.
op="$other"; mode=report-only
reserve
make_candidate rejected
publish rejected
reject 'report-only rejection has no correction slot' reserve
stop
assert_grep "$report" '^phase: stopped$' 'stop retains consumed pass'
reject 'stopped report never approves' bash "$contract" verify "$report" "$spec" "$plan" "$fixture"
op="$request"; mode=coordinated
reserve
stop
assert_grep "$report" '^phase: stopped$' 'lost reviewer result stops operation'
# Read-only missing continuity never reconstructs it.
mv "$report" "$tmp/saved"
reject 'missing operation continuity' operation
[ ! -e "$report" ]
mv "$tmp/saved" "$report"
cp "$report" "$tmp/snapshot"
reviewer=$'bad\nidentity'; reject 'newline reviewer rejected' reserve; unset reviewer
mkdir "$report.lock"
reject 'competing lock fails closed' reserve
[ -d "$report.lock" ]
assert_files_equal "$report" "$tmp/snapshot" 'foreign lock and report preserved'
rmdir "$report.lock"
ln -s "$report" "$dir/reviews/alias.md"
reject 'symlink report alias' bash "$contract" reserve "$dir/reviews/alias.md" "$spec" "$plan" "$fixture" "$other" "$request" coordinated unavailable "$(sha "$report")"
ln "$spec" "$dir/reviews/.input-alias"
reject 'candidate input hardlink alias' bash "$contract" stamp-operation "$dir/reviews/.input-alias" "$report" "$spec" "$plan" approved "$fixture" "$inputs" "$op" "$(sha "$report")"
# Legacy evidence still verifies, but cannot be resumed as a managed operation.
rm "$report"
bash "$contract" stamp "$dir/reviews/.legacy" "$report" "$spec" "$plan" approved "$fixture" "$inputs"
bash "$contract" verify "$report" "$spec" "$plan" "$fixture"
reject 'legacy evidence has no operation continuity' operation
[ ! -e "$report.lock" ]
# Unmanaged legacy bytes need not end in LF.
rm "$report"
printf '# Legacy body without LF' > "$dir/reviews/.legacy"
bash "$contract" stamp "$dir/reviews/.legacy" "$report" "$spec" "$plan" approved "$fixture" "$inputs"
bash "$contract" verify "$report" "$spec" "$plan" "$fixture"
# Fresh reservation protects the exact prior legacy bytes, including no final LF.
mode=coordinated; op="$other"
cp "$report" "$tmp/snapshot"
reject 'stale fresh reservation hash' bash "$contract" reserve "$report" "$spec" "$plan" "$fixture" "$op" "$request" coordinated unavailable "$request"
assert_files_equal "$report" "$tmp/snapshot" 'stale fresh reservation preserves bytes'
[ ! -e "$report.lock" ]
reserve
make_candidate rejected
publish rejected
reserve
make_candidate rejected
publish rejected
reject 'rejected second pass has no third slot' reserve
cp "$report" "$tmp/snapshot"
# Losing the leading block cannot turn framed managed continuity into legacy evidence.
awk 'NR>19 {print}' "$tmp/snapshot" > "$report"
reject 'missing leading operation block cannot reset allowance' bash "$contract" reserve "$report" "$spec" "$plan" "$fixture" "$request" "$request" coordinated unavailable "$(sha "$report")"
cp "$tmp/snapshot" "$report"
# Frame corruption is rejected without interpreting nested historical operation markers.
sed 's/maxi-design-history-v1 bytes: [0-9][0-9]*/maxi-design-history-v1 bytes: 1/' "$tmp/snapshot" > "$report"
cp "$report" "$tmp/malformed"
reject 'invalid history byte framing' operation
reject 'malformed continuity cannot be replaced' bash "$contract" reserve "$report" "$spec" "$plan" "$fixture" "$request" "$request" coordinated unavailable "$(sha "$report")"
assert_files_equal "$report" "$tmp/malformed" 'malformed continuity preserved'
mv "$tmp/snapshot" "$report"
# Unsafe decision inputs prevent even a diagnostic stop from overwriting evidence.
mv "$fixture/docs/maxi/constitution.md" "$tmp/constitution"
reject 'unsafe inputs prevent stopped publication' stop
mv "$tmp/constitution" "$fixture/docs/maxi/constitution.md"
# The shared lock protects legacy writers too and never removes someone elses lock.
rm "$report"
mkdir "$report.lock"
reject 'legacy writer respects mutation lock' bash "$contract" stamp "$dir/reviews/.legacy" "$report" "$spec" "$plan" approved "$fixture" "$inputs"
[ -d "$report.lock" ] && [ ! -e "$report" ]
rmdir "$report.lock"
# Real competing writers: hold the first at rename after it owns the lock.
mkdir "$tmp/bin"
cat > "$tmp/bin/mv" <<'WRAPPER'
#!/usr/bin/env bash
: > "$MUTATION_READY"
while [ ! -e "$MUTATION_RELEASE" ]; do sleep 0.02; done
exec /bin/mv "$@"
WRAPPER
chmod +x "$tmp/bin/mv"
PATH="$tmp/bin:$PATH" MUTATION_READY="$tmp/ready" MUTATION_RELEASE="$tmp/release" \
  bash "$contract" reserve "$report" "$spec" "$plan" "$fixture" "$op" "$request" coordinated unavailable absent > "$tmp/writer.out" 2>&1 &
writer=$!
for attempt in {1..250}; do [ ! -e "$tmp/ready" ] || break; sleep 0.02; done
[ -e "$tmp/ready" ]
reject 'competing real writer cannot acquire held lock' bash "$contract" reserve "$report" "$spec" "$plan" "$fixture" "$op" "$request" coordinated unavailable absent
[ -d "$report.lock" ] && [ ! -e "$report" ]
: > "$tmp/release"
wait "$writer"
[ ! -e "$report.lock" ]
assert_grep "$report" '^passes: 1$' 'one competing writer consumes one pass'
# TERM after lock acquisition preserves status 143, old bytes, and removes own lock/temp.
cp "$report" "$tmp/snapshot"
cat > "$tmp/bin/mv" <<'WRAPPER'
#!/usr/bin/env bash
kill -TERM "$PPID"
exit 0
WRAPPER
signal_status=0
PATH="$tmp/bin:$PATH" bash "$contract" stop-operation "$report" "$spec" "$plan" "$fixture" "$op" "$(sha "$report")" > "$tmp/signal.out" 2>&1 || signal_status=$?
[ "$signal_status" -eq 143 ] && [ ! -e "$report.lock" ]
assert_files_equal "$report" "$tmp/snapshot" 'interrupted publication preserves original report'
for candidate_temp in "$dir/reviews/".design-review.*; do [ ! -e "$candidate_temp" ]; done
# Change a reviewed artifact between managed validation and envelope construction.
rm "$tmp/bin/mv"
make_candidate approved
cp "$spec" "$tmp/original-spec"
cat > "$tmp/bin/shasum" <<'WRAPPER'
#!/usr/bin/env bash
input="$(mktemp)"
trap 'rm -f "$input"' EXIT
cat > "$input"
/usr/bin/shasum "$@" < "$input"
if [ ! -e "$MUTATION_ONCE" ] && cmp -s "$input" "$MUTATION_CANDIDATE"; then
  : > "$MUTATION_ONCE"
  printf '\nChanged during candidate validation\n' >> "$MUTATION_SPEC"
fi
WRAPPER
chmod +x "$tmp/bin/shasum"
reject 'mid-publication artifact change fails closed' env PATH="$tmp/bin:$PATH" MUTATION_ONCE="$tmp/mutated" MUTATION_CANDIDATE="$dir/reviews/.candidate" MUTATION_SPEC="$spec" \
  bash "$contract" stamp-operation "$dir/reviews/.candidate" "$report" "$spec" "$plan" approved "$fixture" "$inputs" "$op" "$(sha "$report")"
assert_files_equal "$report" "$tmp/snapshot" 'mid-publication artifact change preserves report'
mv "$tmp/original-spec" "$spec"
summary_and_exit 'design operation checks'
