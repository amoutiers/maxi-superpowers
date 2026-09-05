# Real publication and dependency mutation cases shared by the two gates.
approval_fixture() {
  case_root="$APPROVAL_TMP/$1"
  case_dir="$case_root/docs/maxi/specs/0001-approval"
  mkdir -p "$case_dir/reviews" "$case_root/docs/maxi/adr"
  printf '# Constitution\nStable rule.\n' > "$case_root/docs/maxi/constitution.md"
  printf 'status: accepted\nDecision.\n' > "$case_root/docs/maxi/adr/0001-choice.md"
  printf 'status: superseded\nHistorical.\n' > "$case_root/docs/maxi/adr/0002-history.md"
  printf '%s\n' '---' 'status: tasked' 'updated: 2026-09-05' '---' '# Spec' > "$case_dir/spec.md"
  printf '# Plan\n' > "$case_dir/plan.md"
  printf '%s\n' '---' 'updated: 2026-09-05' '---' '- [ ] T001 Work' > "$case_dir/tasks.md"
  if [ "$GATE" = readiness ]; then
    evidence="$case_dir/analysis.md"
  else
    evidence="$case_dir/reviews/design-review.md"
  fi
  candidate="$(dirname "$evidence")/.candidate"
  printf '# New report\nComplete findings.\n' > "$candidate"
  original_inputs="$(bash "$INPUTS" hash "$case_root")"
}
approval_stamp() {
  if [ "$GATE" = readiness ]; then
    bash "$GATE_CONTRACT" stamp "$candidate" "$evidence" "$case_dir/spec.md" "$case_dir/plan.md" "$case_dir/tasks.md" pass 0 "$case_root" "$original_inputs"
  else
    bash "$GATE_CONTRACT" stamp "$candidate" "$evidence" "$case_dir/spec.md" "$case_dir/plan.md" approved "$case_root" "$original_inputs"
  fi
}
approval_verify() {
  if [ "$GATE" = readiness ]; then
    bash "$GATE_CONTRACT" verify "$evidence" "$case_dir/spec.md" "$case_dir/plan.md" "$case_dir/tasks.md" "$case_root"
  else
    bash "$GATE_CONTRACT" verify "$evidence" "$case_dir/spec.md" "$case_dir/plan.md" "$case_root"
  fi
}
approval_ok() {
  echo "OK  [$GATE: $1]"
}
approval_fail() {
  echo "FAIL [$GATE: $1]" >&2
  failures=$((failures + 1))
}
approval_reject() {
  local label="$1" output status
  shift
  if output="$("$@" 2>&1)"; then status=0; else status=$?; fi
  if [ "$status" -eq 2 ] && ! printf '%s' "$output" | grep -Eq 'READINESS_VERIFIED|DESIGN_REVIEW_VERIFIED'; then
    approval_ok "$label"
  else
    approval_fail "$label (exit $status)"
  fi
}
APPROVAL_TMP_RAW="$(mktemp -d)"
APPROVAL_TMP="$(cd "$APPROVAL_TMP_RAW" && pwd -P)"
if [ "$GATE" = readiness ]; then
  GATE_CONTRACT="$ROOT/skills/analyze/readiness-contract.sh"
  success=READINESS_VERIFIED
else
  GATE_CONTRACT="$ROOT/skills/review/design-contract.sh"
  success=DESIGN_REVIEW_VERIFIED
fi
for mutation in constitution add remove rename status content historical; do
  approval_fixture "$mutation"
  approval_stamp
  [ "$(approval_verify)" = "$success" ] && approval_ok 'fresh approval verifies' || approval_fail 'fresh approval verifies'
  case "$mutation" in
    constitution) printf '\nChanged rule.\n' >> "$case_root/docs/maxi/constitution.md" ;;
    add) printf 'status: deprecated\n' > "$case_root/docs/maxi/adr/0003-new.md" ;;
    remove) rm "$case_root/docs/maxi/adr/0001-choice.md" ;;
    rename) mv "$case_root/docs/maxi/adr/0001-choice.md" "$case_root/docs/maxi/adr/0001-renamed.md" ;;
    status) printf 'status: deprecated\nDecision.\n' > "$case_root/docs/maxi/adr/0001-choice.md" ;;
    content) printf '\nChanged decision.\n' >> "$case_root/docs/maxi/adr/0001-choice.md" ;;
    historical) printf '\nChanged history.\n' >> "$case_root/docs/maxi/adr/0002-history.md" ;;
  esac
  cp "$evidence" "$case_dir/snapshot"
  approval_reject "$mutation invalidates approval" approval_verify
  cmp -s "$evidence" "$case_dir/snapshot" && approval_ok 'verify preserves evidence' || approval_fail 'verify preserves evidence'
done
for previous in present absent; do
  approval_fixture "publish-$previous"
  approval_stamp
  if [ "$previous" = present ]; then cp "$evidence" "$case_dir/snapshot"; else rm "$evidence"; fi
  printf '# Fresh distinct report\n' > "$candidate"
  printf '\nChanged during review.\n' >> "$case_root/docs/maxi/constitution.md"
  approval_reject "stale candidate with $previous evidence" approval_stamp
  if [ "$previous" = present ]; then
    cmp -s "$evidence" "$case_dir/snapshot" && approval_ok 'failed stamp preserves bytes' || approval_fail 'failed stamp preserves bytes'
  else
    [ ! -e "$evidence" ] && approval_ok 'failed stamp leaves destination absent' || approval_fail 'failed stamp leaves destination absent'
  fi
done
approval_fixture positive
approval_stamp
printf '# Replacement body\nAll new findings.\n' > "$candidate"
approval_stamp
if grep -q 'All new findings.' "$evidence" && ! grep -q 'Complete findings.' "$evidence" && [ "$(approval_verify)" = "$success" ]; then approval_ok 'replacement has complete new body and valid envelope'; else approval_fail 'replacement body'; fi
for unsafe in missing outside symlink component equal hardlink spec plan tasks constitution adr destination-alias destination-symlink envelope; do
  approval_fixture "unsafe-$unsafe"
  approval_stamp
  case "$unsafe" in
    missing) rm "$candidate" ;;
    outside) mv "$candidate" "$case_root/outside"; candidate="$case_root/outside" ;;
    symlink) mv "$candidate" "$candidate.target"; ln -s "$candidate.target" "$candidate" ;;
    component) ln -s "$(dirname "$candidate")" "$case_root/link"; candidate="$case_root/link/.candidate" ;;
    equal) candidate="$evidence" ;;
    hardlink) rm "$candidate"; ln "$evidence" "$candidate" ;;
    spec|plan|tasks) rm "$candidate"; ln "$case_dir/$unsafe.md" "$candidate" ;;
    constitution) rm "$candidate"; ln "$case_root/docs/maxi/constitution.md" "$candidate" ;;
    adr) rm "$candidate"; ln "$case_root/docs/maxi/adr/0001-choice.md" "$candidate" ;;
    destination-alias) rm "$evidence"; ln "$case_dir/spec.md" "$evidence" ;;
    destination-symlink) rm "$evidence"; ln -s "$case_dir/spec.md" "$evidence" ;;
    envelope) cp "$evidence" "$candidate" ;;
  esac
  cp "$evidence" "$case_dir/snapshot"
  inputs_before="$(bash "$INPUTS" hash "$case_root")"
  source_before="$(cat "$case_dir/spec.md" "$case_dir/plan.md" "$case_dir/tasks.md" | shasum -a 256)"
  approval_reject "unsafe $unsafe candidate/destination" approval_stamp
  if cmp -s "$evidence" "$case_dir/snapshot" && [ "$inputs_before" = "$(bash "$INPUTS" hash "$case_root")" ] && [ "$source_before" = "$(cat "$case_dir/spec.md" "$case_dir/plan.md" "$case_dir/tasks.md" | shasum -a 256)" ]; then approval_ok 'rejection preserves reviewed inputs and evidence'; else approval_fail 'unsafe publication changed inputs'; fi
done
approval_fixture relocation
approval_stamp
cp -R "$case_root" "$APPROVAL_TMP/relocated\\literal"
case_root="$APPROVAL_TMP/relocated\\literal"
case_dir="$case_root/docs/maxi/specs/0001-approval"
if [ "$GATE" = readiness ]; then evidence="$case_dir/analysis.md"; else evidence="$case_dir/reviews/design-review.md"; fi
[ "$(approval_verify)" = "$success" ] && approval_ok 'unchanged relocation with backslash verifies' || approval_fail 'relocation'
approval_fixture no-adr
rm -rf "$case_root/docs/maxi/adr"
original_inputs="$(bash "$INPUTS" hash "$case_root")"
approval_stamp
mkdir "$case_root/docs/maxi/adr"
printf 'Generated index\n' > "$case_root/docs/maxi/adr/README.md"
[ "$(approval_verify)" = "$success" ] && approval_ok 'absent/empty ADR and README preserve approval' || approval_fail 'no ADR'
for corrupt in body-only legacy duplicate unknown missing malformed-hash malformed-input-hash unclosed verdict; do
  approval_fixture "metadata-$corrupt"
  approval_stamp
  case "$corrupt" in
    body-only) cp "$candidate" "$evidence" ;;
    legacy)
      if [ "$GATE" = readiness ]; then
        sed 's/maxi-readiness-v2/maxi-readiness-v1/' "$evidence" > "$case_dir/edited"
      else
        sed '/^design_review_contract:/d; /^review_inputs_sha256:/d' "$evidence" > "$case_dir/edited"
      fi
      mv "$case_dir/edited" "$evidence" ;;
    duplicate) awk '{print; if ($0 ~ /^review_inputs_sha256:/) print}' "$evidence" > "$case_dir/edited"; mv "$case_dir/edited" "$evidence" ;;
    unknown) awk '{print; if (NR == 1) print "extra: field"}' "$evidence" > "$case_dir/edited"; mv "$case_dir/edited" "$evidence" ;;
    missing) sed '/^review_inputs_sha256:/d' "$evidence" > "$case_dir/edited"; mv "$case_dir/edited" "$evidence" ;;
    malformed-hash) awk '/^(reviewed_plan_sha256|plan_sha256):/ { print $1 " ABC"; next } { print }' "$evidence" > "$case_dir/edited"; mv "$case_dir/edited" "$evidence" ;;
    malformed-input-hash) sed 's/^review_inputs_sha256:.*/review_inputs_sha256: abc/' "$evidence" > "$case_dir/edited"; mv "$case_dir/edited" "$evidence" ;;
    unclosed) sed '1!{/^---$/d;}' "$evidence" > "$case_dir/edited"; mv "$case_dir/edited" "$evidence" ;;
    verdict) sed 's/^verdict:.*/verdict: unknown/; s/^outcome:.*/outcome: unknown/' "$evidence" > "$case_dir/edited"; mv "$case_dir/edited" "$evidence" ;;
  esac
  cp "$evidence" "$case_dir/snapshot"
  approval_reject "reject $corrupt metadata" approval_verify
  cmp -s "$evidence" "$case_dir/snapshot" && approval_ok 'malformed evidence preserved' || approval_fail 'malformed evidence changed'
done
if [ "$GATE" = design ]; then
  approval_fixture rejected
  bash "$GATE_CONTRACT" stamp "$candidate" "$evidence" "$case_dir/spec.md" "$case_dir/plan.md" rejected "$case_root" "$original_inputs"
  approval_reject 'rejected design can publish but cannot approve' approval_verify
  for artifact in spec plan; do
    approval_fixture "artifact-$artifact"
    approval_stamp
    printf '\nChanged artifact.\n' >> "$case_dir/$artifact.md"
    approval_reject "$artifact byte changes invalidate design" approval_verify
  done
fi
for unsafe in spec-symlink directory-symlink outside-root missing-destination missing-parent nonregular-destination; do
  approval_fixture "path-$unsafe"
  approval_stamp
  case "$unsafe" in
    spec-symlink) mv "$case_dir/spec.md" "$case_dir/spec-target"; ln -s spec-target "$case_dir/spec.md" ;;
    directory-symlink) mv "$case_dir" "$case_dir.real"; ln -s "$case_dir.real" "$case_dir" ;;
    outside-root) mkdir -p "$case_root/other/docs/maxi"; cp "$case_root/docs/maxi/constitution.md" "$case_root/other/docs/maxi/constitution.md"; case_root="$case_root/other" ;;
    missing-destination) rm "$evidence" ;;
    missing-parent) rm -rf "$(dirname "$evidence")" ;;
    nonregular-destination) rm "$evidence"; mkdir "$evidence" ;;
  esac
  approval_reject "verify rejects $unsafe" approval_verify
  if [ "$unsafe" = missing-parent ]; then [ ! -e "$(dirname "$evidence")" ] && approval_ok 'verifier creates no directory' || approval_fail 'verifier created directory'; fi
done
approval_fixture installed
mkdir -p "$APPROVAL_TMP/plugin/skills/analyze" "$APPROVAL_TMP/plugin/skills/review"
cp "$ROOT/skills/analyze/readiness-contract.sh" "$APPROVAL_TMP/plugin/skills/analyze/"
cp "$ROOT/skills/review/"*.sh "$APPROVAL_TMP/plugin/skills/review/"
if [ "$GATE" = readiness ]; then GATE_CONTRACT="$APPROVAL_TMP/plugin/skills/analyze/readiness-contract.sh"; else GATE_CONTRACT="$APPROVAL_TMP/plugin/skills/review/design-contract.sh"; fi
approval_stamp
[ ! -e "$case_root/skills" ] && [ "$(approval_verify)" = "$success" ] && approval_ok 'installed gate works without client skills' || approval_fail 'installed gate'
mv "$APPROVAL_TMP/plugin/skills/review/review-inputs.sh" "$APPROVAL_TMP/saved-helper"
approval_reject 'missing installed helper fails closed' approval_verify
ln -s "$APPROVAL_TMP/saved-helper" "$APPROVAL_TMP/plugin/skills/review/review-inputs.sh"
approval_reject 'symlinked installed helper fails closed' approval_verify
rm -rf "$APPROVAL_TMP"
