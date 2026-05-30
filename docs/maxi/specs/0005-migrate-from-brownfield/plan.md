---
slug: 0005-migrate-from-brownfield
spec_slug: 0005-migrate-from-brownfield
created: 2026-05-30
updated: 2026-05-30
---

# Implementation Plan: migrate-from-brownfield

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. The `SKILL.md` and subagent-brief tasks delegate to `superpowers:writing-skills` per the project's Contributor Workflow — do NOT hand-write `SKILL.md`.

**Goal:** Add a user-invocable maxi skill, `/maxi:migrate-from-brownfield`, that reverse-engineers an existing codebase into faithful, traceable `spec.md` baselines at `status: done`.

**Architecture:** A thin interactive coordinator (`SKILL.md`) orchestrates parallel non-interactive subagents (multi-modal discovery → per-boundary draft → adversarial verify) and owns the boundary-map review, per-spec consent gate, and serial writes. A deterministic helper script (`brownfield.sh`) provides the scriptable, fast-tier-testable surface: guards, exclusion-set matching, and spec-file writing.

**Tech Stack:** Bash (helper script + tests, mirroring `migrate-from-speckit/migrate.sh`), Markdown skill + subagent briefs (mirroring `migrate-adr`), `git rev-parse HEAD` for provenance SHA. No new runtime dependencies.

---

## Summary

Spec 0005 requires reverse-engineering brownfield code into `spec.md` baselines so a project can adopt SDD. The work splits into a **deterministic core** (guards, exclusion matching, spec writing — fully unit-testable in the fast tier) and an **agent-driven core** (discovery, drafting, adversarial verification — validated in the integration tier). The done-on-creation behavior is sanctioned by constitution v1.4.0's ingress clause and ADR-0011.

## Technical Context

**Language/Version**: Bash (POSIX-ish, `set -euo pipefail`), Markdown skills — matches existing maxi tooling
**Primary Dependencies**: `git` (SHA resolution), `jq` (already required by `tests/run-all.sh`); subagent dispatch via `maxi:dispatching-parallel-agents`
**Storage**: Filesystem — `docs/maxi/specs/NNNN-slug/spec.md` per the artifact convention
**Testing**: Bash assertions via `tests/lib/test-helpers.sh` (fast tier); naive-prompt skill-trigger (integration tier)
**Target Platform**: Claude Code + OpenCode dual-harness (skill is harness-agnostic; no hook changes)
**Project Type**: maxi-native skill (single project, `skills/<name>/`)
**Performance Goals**: N/A (interactive, human-paced); discovery/draft/verify fan out in parallel for large-repo tractability
**Constraints**: Non-destructive (never delete/move code or specs); no write without explicit consent; single-responsibility (Principle VI)
**Scale/Scope**: One new skill, one helper script (3 subcommands), three subagent briefs, one fast-tier test + fixture, one integration prompt, four mandatory-sync doc updates

## Constitution Check

*GATE: passed pre-planning (see ADR-0011). Re-checked post-design below.*

| Principle | Pass / Fail | Notes |
|-----------|-------------|-------|
| I. Mandatory Spec-Driven Pipeline | ✓ | This feature itself went specify→clarify→plan; the skill it builds is governed by the v1.4.0 ingress clause |
| II. Delegate to Superpowers, Never Duplicate | ✓ | Reuses `dispatching-parallel-agents`, `writing-skills`; reuses `migrate-adr`'s token-set matcher; no duplication |
| III. Strict Pipeline — No Skipping | ✓ | Done-on-creation is the sanctioned **ingress** path (v1.4.0 clause + ADR-0011), scoped to reverse-engineering, with `origin:` provenance |
| IV. ADR for Non-Trivial Decisions | ✓ | ADR-0011 records the ingress decision; this plan's ADR scan checks for further architectural choices |
| V. Artifacts Over Chat | ✓ | Produces `spec.md` files; provenance + Migration Notes persisted |
| VI. Single Responsibility per Skill | ✓ | Skill only reverse-engineers specs (FR-015 forbids constitution/ADR/plan/tasks side-effects) |

## Project Structure

### Documentation (this feature)

```text
docs/maxi/specs/0005-migrate-from-brownfield/
├── spec.md          # status: clarified (input)
├── plan.md          # This file
└── tasks.md         # Phase 2 output (/maxi:tasks — NOT created here)
```

### Source Code (repository root)

```text
skills/migrate-from-brownfield/
├── SKILL.md                 # Coordinator workflow (authored via writing-skills)
├── discover-subagent.md     # Multi-modal discovery brief (by-directory / by-entrypoint / by-manifest / by-route)
├── draft-subagent.md        # Reverse-engineer as-built spec brief
├── verify-subagent.md       # Adversarial verification brief
└── brownfield.sh            # Deterministic helpers: guard | exclude | write-spec

tests/
├── check-migrate-from-brownfield.sh     # Fast-tier test
├── fixtures/
│   └── brownfield-project/              # Minimal multi-module fixture repo (+ a pre-existing reverse-engineered spec for exclusion test)
└── integration/prompts/
    └── migrate-from-brownfield.txt       # Naive prompt → skill auto-trigger

# Mandatory-sync touchpoints (CLAUDE.md rule):
docs/pipeline-flow.md         # add ingress note
docs/delegation-map.md        # add skill row
skills/using-maxi/SKILL.md    # mention ingress skill under "Getting Started"
CLAUDE.md                     # skill count 17→18; origin field in artifact convention
tests/check-skills-present.sh # add migrate-from-brownfield to MAXI_SKILLS (array length 18)
tests/run-all.sh              # register check-migrate-from-brownfield.sh
```

**Structure Decision**: Mirrors `migrate-adr` (skill + subagent briefs) for the agent-driven parts and `migrate-from-speckit` (a `*.sh` with a fast-tier test + fixture) for the deterministic parts. Keeps each file single-responsibility: the script never reasons, the briefs never write files, the coordinator never explores code directly.

## Decisions

| ADR | Title | Status |
|-----|-------|--------|
| [0011](../../adr/0011-migration-ingress-terminal-status.md) | Migration / Reverse-Engineering Ingress May Set Terminal Status on Creation | accepted |

> ADR scan (post-planning): the **done-on-creation** decision is already captured by ADR-0011. The **coordinator/subagent split** and **multi-modal discovery** are implementation patterns reused from existing skills (`migrate-adr`, `dispatching-parallel-agents`), not novel contested architecture — no further ADR proposed. If `/maxi:tasks` or implementation surfaces a genuinely contested structural choice, invoke `/maxi:adr` then.

## Agent Return Schemas (shared contract)

These are the JSON shapes subagents return to the coordinator. Define once; referenced by Tasks 5–8.

```text
BoundaryCandidate = {
  name: string,                # human label, e.g. "nmea-parser"
  backing_paths: string[],     # files/dirs that constitute the boundary (evidence)
  evidence: string,            # one-line why these paths form a boundary
  discovery_lens: string       # which modal agent found it: "directory"|"entrypoint"|"manifest"|"route"
}

DraftedSpec = {
  boundary: string,            # BoundaryCandidate.name
  spec_markdown: string,       # full maxi-schema spec body, as-built scenarios, FRs with file:line
  fr_refs: string[]            # every file:line cited, for verify + SC-001 check
}

Verdict = {
  boundary: string,
  issues: { kind: "hallucination"|"omission"|"stale_ref", detail: string }[],
  revised_spec_markdown: string  # the draft after corrections (what the user sees)
}
```

**Multi-modal dedup rule (coordinator-side, after discovery fan-out):** two `BoundaryCandidate`s are the same boundary iff their `backing_paths` sets overlap by ≥50% (Jaccard ≥ 0.5) OR one's path set ⊆ the other's. On merge: union the `backing_paths`, keep the longer `name`, concatenate `evidence`, record all contributing `discovery_lens` values. When overlap is >0 but below the threshold, keep both but mark them as "possibly related" for the boundary-map review.

---

## Phase 1 — Deterministic helper script (TDD, fast tier)

### Task 1: Fixture brownfield project

**Files:**
- Create: `tests/fixtures/brownfield-project/` (a tiny multi-module repo)
- Create: `tests/fixtures/brownfield-project/src/auth/login.js`
- Create: `tests/fixtures/brownfield-project/src/billing/invoice.js`
- Create: `tests/fixtures/brownfield-project/package.json`
- Create: `tests/fixtures/brownfield-project/docs/maxi/constitution.md` (minimal, so guard passes)
- Create: `tests/fixtures/brownfield-project/docs/maxi/specs/0001-auth/spec.md` (a *reverse-engineered* spec with `origin: reverse-engineered` and `file:line` refs into `src/auth/` — feeds the exclusion test)

- [ ] **Step 1: Create the fixture tree** with the files above. `login.js` and `invoice.js` each contain 2–3 trivial exported functions so a `file:line` ref resolves. `0001-auth/spec.md` frontmatter:

```yaml
---
slug: 0001-auth
created: 2026-05-01
updated: 2026-05-01
status: done
origin: reverse-engineered
source_sha: deadbeef
parked_from: null
---
```
with one FR body line: `- **FR-001**: Validates credentials (src/auth/login.js:3)`.

- [ ] **Step 2: Verify the fixture is self-consistent**

Run: `test -f tests/fixtures/brownfield-project/src/auth/login.js && grep -n . tests/fixtures/brownfield-project/src/auth/login.js`
Expected: prints numbered lines; line 3 exists.

- [ ] **Step 3: Commit**

```bash
git add tests/fixtures/brownfield-project
git commit -m "test(brownfield): add fixture brownfield repo for migrate-from-brownfield"
```

### Task 2: `brownfield.sh guard` subcommand

**Files:**
- Create: `skills/migrate-from-brownfield/brownfield.sh`
- Test: `tests/check-migrate-from-brownfield.sh`

- [ ] **Step 1: Write the failing test** (create `tests/check-migrate-from-brownfield.sh`)

```bash
#!/usr/bin/env bash
# Tests skills/migrate-from-brownfield/brownfield.sh deterministic surface.
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"
SCRIPT="$ROOT/skills/migrate-from-brownfield/brownfield.sh"
FIXTURE="$ROOT/tests/fixtures/brownfield-project"
failures=0

assert_executable "$SCRIPT" "brownfield.sh is executable"

# guard: passes when constitution + code present
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cp -r "$FIXTURE/." "$TMP/"
if (cd "$TMP" && bash "$SCRIPT" guard >/dev/null 2>&1); then
  echo "OK  [guard: passes with constitution + code]"
else
  echo "FAIL [guard: should pass with constitution + code]" >&2; failures=$((failures+1))
fi

# guard: fails (exit 2) when constitution missing, message points to /maxi:constitution
TMP2=$(mktemp -d)
cp -r "$FIXTURE/." "$TMP2/"; rm -f "$TMP2/docs/maxi/constitution.md"
out=$(cd "$TMP2" && bash "$SCRIPT" guard 2>&1 || true)
rc=$(cd "$TMP2" && bash "$SCRIPT" guard >/dev/null 2>&1; echo $?)
rm -rf "$TMP2"
if [[ "$rc" == "2" ]] && echo "$out" | grep -q "maxi:constitution"; then
  echo "OK  [guard: no constitution → exit 2 + pointer]"
else
  echo "FAIL [guard: expected exit 2 and /maxi:constitution pointer]" >&2; failures=$((failures+1))
fi

# guard: fails (exit 3) when no recognized code files
TMP3=$(mktemp -d)
mkdir -p "$TMP3/docs/maxi"; cp "$FIXTURE/docs/maxi/constitution.md" "$TMP3/docs/maxi/"
rc3=$(cd "$TMP3" && bash "$SCRIPT" guard >/dev/null 2>&1; echo $?)
rm -rf "$TMP3"
if [[ "$rc3" == "3" ]]; then
  echo "OK  [guard: no code → exit 3]"
else
  echo "FAIL [guard: expected exit 3 with no code]" >&2; failures=$((failures+1))
fi

summary_and_exit "migrate-from-brownfield checks"
```

- [ ] **Step 2: Run it — expect failure** (script missing)

Run: `bash tests/check-migrate-from-brownfield.sh`
Expected: FAIL — `brownfield.sh` does not exist / not executable.

- [ ] **Step 3: Implement `brownfield.sh` with the `guard` subcommand**

```bash
#!/usr/bin/env bash
# Deterministic helpers for /maxi:migrate-from-brownfield.
# Subcommands: guard | exclude | write-spec
# The skill (SKILL.md) orchestrates agents and consent; this script does file-ops only.
set -euo pipefail
die() { echo "ERROR: $*" >&2; exit 1; }

CODE_EXT_RE='\.(js|ts|jsx|tsx|py|rb|go|rs|java|kt|c|h|cc|cpp|cs|php|swift|scala|sh)$'

cmd_guard() {
  if [[ ! -f docs/maxi/constitution.md ]]; then
    echo "No constitution found. Run /maxi:constitution first (and /maxi:migrate-adr separately for ADRs)." >&2
    exit 2
  fi
  # recognized code files anywhere except docs/ and .git/
  if ! find . -type f -not -path './.git/*' -not -path './docs/*' 2>/dev/null \
        | grep -Eq "$CODE_EXT_RE"; then
    echo "No recognized source code found. Nothing to reverse-engineer." >&2
    exit 3
  fi
  echo "guard: ok"
}

case "${1:-}" in
  guard)     shift; cmd_guard "$@" ;;
  exclude)   shift; cmd_exclude "$@" ;;   # Task 4
  write-spec) shift; cmd_write_spec "$@" ;; # Task 3
  *) die "Usage: brownfield.sh {guard|exclude|write-spec} ..." ;;
esac
```

(Define `cmd_exclude`/`cmd_write_spec` in Tasks 3–4; until then the `case` references are fine because only `guard` is exercised.)

- [ ] **Step 4: Make executable and run the test**

Run: `chmod +x skills/migrate-from-brownfield/brownfield.sh && bash tests/check-migrate-from-brownfield.sh`
Expected: the three `guard` assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/migrate-from-brownfield/brownfield.sh tests/check-migrate-from-brownfield.sh
git commit -m "feat(brownfield): add guard subcommand + fast-tier test scaffold"
```

### Task 3: `brownfield.sh write-spec` subcommand

**Files:**
- Modify: `skills/migrate-from-brownfield/brownfield.sh`
- Test: `tests/check-migrate-from-brownfield.sh`

Writes a vetted spec body to `docs/maxi/specs/NNNN-slug/spec.md` with the ingress frontmatter and Migration Notes. NNNN computed from current max at write time (mirrors `/maxi:specify`).

- [ ] **Step 1: Append failing assertions to the test**

```bash
# write-spec: writes spec with ingress frontmatter, NNNN at write time, Migration Notes
TMP4=$(mktemp -d)
cp -r "$FIXTURE/." "$TMP4/"
printf '# Feature Specification: Billing\n\n- **FR-001**: Issues invoices (src/billing/invoice.js:2)\n' > "$TMP4/body.md"
(cd "$TMP4" && bash "$SCRIPT" write-spec --slug billing --body body.md --sha cafef00d >/dev/null)
new="$TMP4/docs/maxi/specs/0002-billing/spec.md"   # 0001-auth exists in fixture → next is 0002
rm_guard=0
assert_file_exists "$new" "write-spec: spec written at next NNNN (0002)" || rm_guard=1
assert_grep "$new" "^status: done$"                  "write-spec: status done"
assert_grep "$new" "^origin: reverse-engineered$"    "write-spec: origin marker"
assert_grep "$new" "^source_sha: cafef00d$"          "write-spec: source sha recorded"
assert_grep "$new" "^slug: 0002-billing$"            "write-spec: slug set"
assert_grep "$new" "## Migration Notes"              "write-spec: Migration Notes present"
assert_grep "$new" "plan/tasks/analyze/implement"    "write-spec: notes phases not run"
rm -rf "$TMP4"
```

- [ ] **Step 2: Run — expect failure** (`write-spec` not implemented)

Run: `bash tests/check-migrate-from-brownfield.sh`
Expected: FAIL on the write-spec assertions.

- [ ] **Step 3: Implement `cmd_write_spec`** (add to `brownfield.sh` above the `case`)

```bash
cmd_write_spec() {
  local slug="" body="" sha=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --slug) slug="$2"; shift 2 ;;
      --body) body="$2"; shift 2 ;;
      --sha)  sha="$2";  shift 2 ;;
      *) die "write-spec: unknown arg $1" ;;
    esac
  done
  [[ -n "$slug" && -n "$body" && -n "$sha" ]] || die "write-spec: --slug, --body, --sha required"
  [[ -f "$body" ]] || die "write-spec: body file not found: $body"

  # NNNN = max existing + 1 (max-based, survives gaps), zero-padded to 4
  local max=0 n
  shopt -s nullglob
  for d in docs/maxi/specs/[0-9][0-9][0-9][0-9]-*/; do
    n=$(basename "$d" | cut -d- -f1); n=$((10#$n))
    (( n > max )) && max=$n
  done
  shopt -u nullglob
  local nnnn; nnnn=$(printf '%04d' $((max + 1)))
  local dir="docs/maxi/specs/${nnnn}-${slug}"
  [[ -e "$dir" ]] && die "write-spec: $dir already exists"
  mkdir -p "$dir"
  local today; today=$(date +%Y-%m-%d)

  {
    printf -- '---\n'
    printf 'slug: %s-%s\n' "$nnnn" "$slug"
    printf 'created: %s\n' "$today"
    printf 'updated: %s\n' "$today"
    printf 'status: done\n'
    printf 'origin: reverse-engineered\n'
    printf 'source_sha: %s\n' "$sha"
    printf 'parked_from: null\n'
    printf -- '---\n\n'
    cat "$body"
    printf '\n\n## Migration Notes\n\n'
    printf -- '- Reverse-engineered from commit `%s`.\n' "$sha"
    printf -- '- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).\n'
    printf -- '- Verified against code by an adversarial pass before acceptance.\n'
  } > "$dir/spec.md"

  echo "$dir/spec.md"
}
```

- [ ] **Step 4: Run the test**

Run: `bash tests/check-migrate-from-brownfield.sh`
Expected: write-spec assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/migrate-from-brownfield/brownfield.sh tests/check-migrate-from-brownfield.sh
git commit -m "feat(brownfield): write-spec writes ingress frontmatter + Migration Notes at next NNNN"
```

### Task 4: `brownfield.sh exclude` subcommand (idempotency)

**Files:**
- Modify: `skills/migrate-from-brownfield/brownfield.sh`
- Test: `tests/check-migrate-from-brownfield.sh`

Given a candidate's backing paths and `name`, decide `exclude` / `flag` / `keep` against existing reverse-engineered specs. Path-overlap primary; name token-set fallback (the migrate-adr "label" rule, applied to the candidate `name`); partial overlap → `flag`.

- [ ] **Step 1: Append failing assertions**

```bash
# exclude: candidate fully covered by existing 0001-auth (src/auth/login.js) → exclude
v=$(cd "$FIXTURE" && bash "$SCRIPT" exclude --name "auth" --paths "src/auth/login.js")
[[ "$v" == "exclude" ]] && echo "OK  [exclude: covered candidate excluded]" \
  || { echo "FAIL [exclude: expected 'exclude', got '$v']" >&2; failures=$((failures+1)); }

# exclude: brand-new boundary (billing) → keep
v=$(cd "$FIXTURE" && bash "$SCRIPT" exclude --name "billing" --paths "src/billing/invoice.js")
[[ "$v" == "keep" ]] && echo "OK  [exclude: new candidate kept]" \
  || { echo "FAIL [exclude: expected 'keep', got '$v']" >&2; failures=$((failures+1)); }

# exclude: partial path overlap → flag (candidate spans auth + billing)
v=$(cd "$FIXTURE" && bash "$SCRIPT" exclude --name "auth-and-billing" --paths "src/auth/login.js,src/billing/invoice.js")
[[ "$v" == "flag" ]] && echo "OK  [exclude: partial overlap flagged]" \
  || { echo "FAIL [exclude: expected 'flag', got '$v']" >&2; failures=$((failures+1)); }
```

- [ ] **Step 2: Run — expect failure**

Run: `bash tests/check-migrate-from-brownfield.sh`
Expected: FAIL on exclude assertions.

- [ ] **Step 3: Implement `cmd_exclude`**

```bash
cmd_exclude() {
  local name="" paths=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)  name="$2";  shift 2 ;;
      --paths) paths="$2"; shift 2 ;;   # comma-separated
      *) die "exclude: unknown arg $1" ;;
    esac
  done
  [[ -n "$paths" ]] || die "exclude: --paths required"

  # Collect covered paths from existing reverse-engineered specs (file:line refs).
  local covered; covered=$(mktemp)
  shopt -s nullglob
  for s in docs/maxi/specs/[0-9][0-9][0-9][0-9]-*/spec.md; do
    grep -q '^origin: reverse-engineered$' "$s" || continue
    # extract file paths from "(path:line)" refs
    grep -oE '\(([^():]+):[0-9]+\)' "$s" | sed -E 's/^\(//; s/:[0-9]+\)$//' >> "$covered" || true
  done
  shopt -u nullglob
  sort -u "$covered" -o "$covered"

  # Path-overlap: count candidate paths already covered.
  local total=0 hit=0 p
  IFS=',' read -ra cand <<< "$paths"
  for p in "${cand[@]}"; do
    total=$((total+1))
    grep -qxF "$p" "$covered" && hit=$((hit+1))
  done
  rm -f "$covered"

  if (( total > 0 && hit == total )); then echo "exclude"; return; fi
  if (( hit > 0 ));                    then echo "flag";    return; fi
  # No path overlap → label token-set fallback would run here against ref-less specs.
  # (Token-set reuse of migrate-adr's rule; for ref-less specs only. Default keep.)
  echo "keep"
}
```

> Note: the label token-set fallback is only consulted for specs **without** `file:line` refs (forward-pipeline specs). The fixture has none, so the script returns `keep`; the coordinator (SKILL.md) invokes the shared matcher for that case. Document this boundary in the SKILL.

- [ ] **Step 4: Run the test**

Run: `bash tests/check-migrate-from-brownfield.sh`
Expected: all guard + write-spec + exclude assertions PASS.

- [ ] **Step 5: Commit**

```bash
git add skills/migrate-from-brownfield/brownfield.sh tests/check-migrate-from-brownfield.sh
git commit -m "feat(brownfield): exclude subcommand — path-overlap idempotency with partial-overlap flagging"
```

---

## Phase 2 — Subagent briefs (authored via writing-skills patterns)

Each brief is a Markdown file the coordinator passes to a dispatched subagent. They mirror `skills/migrate-adr/{import,discover}-subagent.md`. No code; the deliverable is a precise brief that makes the agent return the schema from "Agent Return Schemas" above.

### Task 5: `discover-subagent.md` (multi-modal discovery)

**Files:**
- Create: `skills/migrate-from-brownfield/discover-subagent.md`

- [ ] **Step 1: Author the brief.** It MUST specify:
  - The agent receives one `discovery_lens` of: `directory` | `entrypoint` | `manifest` | `route`, and explores ONLY that way.
  - `directory`: cluster by top-level/source subdirectories. `entrypoint`: trace from `main`/`index`/CLI/bin entry files. `manifest`: read `package.json`/`Cargo.toml`/`pyproject.toml`/`go.mod` workspaces & deps. `route`: find HTTP routes / exported public API surfaces.
  - Output: a list of `BoundaryCandidate` objects (schema above), each with `backing_paths` and one-line `evidence`, `discovery_lens` set.
  - MUST NOT write files, MUST NOT propose specs — discovery only.
  - Receives the **exclusion set** (already-documented boundaries) and must not re-emit excluded boundaries.

- [ ] **Step 2: Verify frontmatter/shape** (the brief is plain Markdown; ensure it has a clear "Return" section naming the schema).

Run: `grep -q "BoundaryCandidate" skills/migrate-from-brownfield/discover-subagent.md && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add skills/migrate-from-brownfield/discover-subagent.md
git commit -m "feat(brownfield): multi-modal discovery subagent brief"
```

### Task 6: `draft-subagent.md` (reverse-engineer as-built spec)

**Files:**
- Create: `skills/migrate-from-brownfield/draft-subagent.md`

- [ ] **Step 1: Author the brief.** It MUST specify:
  - Input: one `BoundaryCandidate` (name + backing_paths).
  - Produce a `spec.md` body conforming to the **full maxi spec-template schema** (User Story with priority, Independent Test, Acceptance Scenarios, FRs, Success Criteria, Key Entities, Assumptions).
  - **As-built adaptations** (FR-007): acceptance scenarios phrased `Given <current state>, When <real input>, Then <observed output>`; every FR ends with a `(path:line)` reference into `backing_paths`. Default one P1 story; split only for genuinely separable sub-features.
  - Return `DraftedSpec` (schema above), populating `fr_refs` with every cited `path:line`.
  - MUST NOT write files; returns markdown to the coordinator.

- [ ] **Step 2: Verify shape**

Run: `grep -q "DraftedSpec" skills/migrate-from-brownfield/draft-subagent.md && grep -q "as-built" skills/migrate-from-brownfield/draft-subagent.md && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add skills/migrate-from-brownfield/draft-subagent.md
git commit -m "feat(brownfield): as-built spec drafting subagent brief"
```

### Task 7: `verify-subagent.md` (adversarial verification)

**Files:**
- Create: `skills/migrate-from-brownfield/verify-subagent.md`

- [ ] **Step 1: Author the brief.** It MUST specify:
  - Input: a `DraftedSpec` + the boundary's `backing_paths`. The verifier is a DIFFERENT agent instance than the drafter (independence — spec assumption).
  - Check each FR/scenario against real code for: (a) **hallucination** (FR unsupported by code), (b) **omission** (behavior in code absent from draft), (c) **stale_ref** (wrong/nonexistent `path:line`).
  - On irreconcilable disagreement: DROP the unverifiable requirement and note the omission (spec edge case) rather than shipping an unsupported claim.
  - Return `Verdict` (schema above) including `revised_spec_markdown` — the corrected draft the user will see.
  - MUST NOT write files.

- [ ] **Step 2: Verify shape**

Run: `grep -q "Verdict" skills/migrate-from-brownfield/verify-subagent.md && grep -Eq "hallucination|stale_ref" skills/migrate-from-brownfield/verify-subagent.md && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add skills/migrate-from-brownfield/verify-subagent.md
git commit -m "feat(brownfield): adversarial verification subagent brief"
```

---

## Phase 3 — Coordinator SKILL.md (REQUIRED SUB-SKILL: writing-skills)

### Task 8: Author `SKILL.md` via `superpowers:writing-skills`

**Files:**
- Create: `skills/migrate-from-brownfield/SKILL.md`

> Per CLAUDE.md, do NOT hand-write SKILL.md. Invoke `superpowers:writing-skills` with the design brief below; it runs its own RED/GREEN/REFACTOR.

- [ ] **Step 1: Invoke `superpowers:writing-skills`** with this brief. The SKILL.md MUST contain:
  - **Frontmatter:** `name: migrate-from-brownfield`, a `description` matching the spec's trigger (`/maxi:migrate-from-brownfield` or "reverse-engineer brownfield code into spec baselines"), `user-invocable: true`.
  - **Iron Rule** (consent): never write a spec without explicit `accept`/`edit`; mirror `migrate-adr`'s rationalization table.
  - **Workflow** (dot-graph) implementing the coordinator: `guard (brownfield.sh guard) → resolve SHA (git rev-parse HEAD) → build exclusion set → dispatch multi-modal discovery (maxi:dispatching-parallel-agents) → dedup (Jaccard ≥ 0.5 rule) → boundary-map edit/select review → per selected boundary: draft-agent → verify-agent → consent gate (accept/skip/edit) → on accept/edit: brownfield.sh write-spec → report`.
  - **Guards** (spec edge cases): no constitution → stop (point to `/maxi:constitution`, suggest `/maxi:migrate-adr` separately); no code → stop cleanly; structureless repo → single whole-project boundary floor; slug collision → `/maxi:specify` disambiguation; all boundaries already documented → report nothing-new, exit.
  - **Consent gate semantics:** `accept`/`skip`/`edit` (edit = accept-with-changes, write immediately); ambiguous → re-ask once naming verbs → default `skip`. **No write without an explicit `accept` OR `edit`** (FR-010 as clarified — both write). Writes are serial; NNNN computed at write time by `brownfield.sh write-spec`.
  - **Exclusion fallback note:** label token-set matching (reuse migrate-adr's rule) only for ref-less specs; path-overlap (via `brownfield.sh exclude`) is primary; partial overlap is surfaced, never auto-excluded.
  - **Out of scope** (FR-015): no constitution bootstrapping, no ADRs, no plan/tasks fabrication, never delete/move code or specs.
  - References the three subagent briefs and `brownfield.sh`.

- [ ] **Step 2: Validate frontmatter** (fast-tier `check-frontmatter.sh` covers all skills)

Run: `bash tests/check-frontmatter.sh`
Expected: PASS (includes the new skill).

- [ ] **Step 3: Commit**

```bash
git add skills/migrate-from-brownfield/SKILL.md
git commit -m "feat(brownfield): coordinator SKILL.md (authored via writing-skills)"
```

---

## Phase 4 — Registration & mandatory documentation sync

### Task 9: Register the skill in tests & manifest

**Files:**
- Modify: `tests/check-skills-present.sh` (add `migrate-from-brownfield`; comment "17"→"18")
- Modify: `tests/run-all.sh` (register `check-migrate-from-brownfield.sh`)
- Modify: `.claude-plugin/plugin.json` if it enumerates skills (verify first)

- [ ] **Step 1: Add to `MAXI_SKILLS` array** in `tests/check-skills-present.sh` and update the header comment to `18`.

- [ ] **Step 2: Register the fast-tier test** — add to `tests/run-all.sh`:

```bash
run_check "$TESTS_DIR/check-migrate-from-brownfield.sh" "migrate-from-brownfield script behavior"
```

- [ ] **Step 3: Check the plugin manifest** — if `.claude-plugin/plugin.json` lists skills explicitly, add it; otherwise no change.

Run: `grep -l migrate-from-speckit .claude-plugin/plugin.json || echo "no explicit skill list"`

- [ ] **Step 4: Run full fast tier**

Run: `bash tests/run-all.sh`
Expected: all checks PASS, including `check-skills-present.sh` (18) and the new test.

- [ ] **Step 5: Commit**

```bash
git add tests/check-skills-present.sh tests/run-all.sh .claude-plugin/plugin.json
git commit -m "test(brownfield): register skill (17→18) and fast-tier test"
```

### Task 10: Mandatory pipeline-doc sync (CLAUDE.md rule — all in one commit)

**Files:**
- Modify: `docs/pipeline-flow.md`
- Modify: `docs/delegation-map.md`
- Modify: `skills/using-maxi/SKILL.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: `docs/pipeline-flow.md`** — add a note that ingress skills (`migrate-from-speckit`, `migrate-from-brownfield`) land specs at terminal status with `origin:` provenance (per v1.4.0 ingress clause); no new FSM status.

- [ ] **Step 2: `docs/delegation-map.md`** — add a row for `migrate-from-brownfield` (required status: none/standalone; delegates to: `dispatching-parallel-agents`, `writing-skills`, `brownfield.sh`; status transition: writes `done` on creation, ingress).

- [ ] **Step 3: `skills/using-maxi/SKILL.md`** — under "Getting Started", add a line pointing brownfield projects to `/maxi:migrate-from-brownfield` (parallel to the existing migrate-from-speckit/migrate-adr pointers). Do NOT add it to the forward phase-gating table (it's ingress, not a forward phase).

- [ ] **Step 4: `CLAUDE.md`** — Overview: skill count 17→18 and add `migrate-from-brownfield` to the migration-utilities list; Artifact Convention: note the optional `origin: reverse-engineered` + `source_sha` frontmatter on reverse-engineered specs; Testing fast-tier list: add `check-migrate-from-brownfield.sh`.

- [ ] **Step 5: Verify docs consistency** (project has a doc-consistency skill)

Run: `bash tests/run-all.sh`
Expected: PASS. (Optionally run the `doc-consistency` review before committing.)

- [ ] **Step 6: Commit (atomic — all four docs together)**

```bash
git add docs/pipeline-flow.md docs/delegation-map.md skills/using-maxi/SKILL.md CLAUDE.md
git commit -m "docs(brownfield): mandatory pipeline-doc sync for migrate-from-brownfield (skill 18)"
```

### Task 11: Integration prompt

**Files:**
- Create: `tests/integration/prompts/migrate-from-brownfield.txt`

- [ ] **Step 1: Write a naive prompt** that should auto-trigger the skill, e.g.:

```text
I have an existing project with code but no specs. I want to start using spec-driven development on it — can you reverse-engineer the existing code into spec baselines?
```

- [ ] **Step 2: Confirm the integration harness picks it up** (it globs `prompts/*.txt`).

Run: `ls tests/integration/prompts/migrate-from-brownfield.txt`
Expected: file exists.

- [ ] **Step 3: Commit**

```bash
git add tests/integration/prompts/migrate-from-brownfield.txt
git commit -m "test(brownfield): integration prompt for skill auto-trigger"
```

---

## Phase 5 — Verification

### Task 12: Full verification pass

- [ ] **Step 1: Fast tier**

Run: `bash tests/run-all.sh`
Expected: `All fast checks passed.`

- [ ] **Step 2: Integration tier (opt-in, requires `claude` CLI)**

Run: `bash tests/run-all.sh --integration`
Expected: `migrate-from-brownfield` prompt triggers `/maxi:migrate-from-brownfield` via the Skill tool.

- [ ] **Step 3: Manual smoke** (optional) — run `/maxi:migrate-from-brownfield` against `tests/fixtures/brownfield-project`, confirm: discovery proposes `auth`+`billing`, `0001-auth` is excluded on a second pass, a vetted draft requires explicit accept, the written spec has `origin: reverse-engineered` + Migration Notes.

- [ ] **Step 4: Stage for review** (do NOT commit without user consent — project rule)

Run: `git status && git log --oneline -12`
Then request review via `superpowers:requesting-code-review` before any merge.

---

## Self-Review (writing-plans)

**Spec coverage:**
- FR-001 (no constitution → stop) → Task 2 guard (exit 2). FR-002 (no code → stop; messy → degrade) → Task 2 guard (exit 3) + Task 8 structureless floor. FR-003 (SHA) → Task 8 `git rev-parse HEAD` + Task 3 `source_sha`. FR-004 (discovery + paths; floor) → Tasks 5, 8. FR-005 (exclusion) → Task 4 + Task 8 label fallback. FR-006 (boundary-map review) → Task 8. FR-007 (as-built full schema + file:line) → Task 6. FR-008 (adversarial verify) → Task 7. FR-009 (consent verbs/edit) → Task 8. FR-010 (no write without accept) → Task 8 + Iron Rule. FR-011 (write done, NNNN at write time) → Task 3. FR-012 (origin + sha, no new FSM status) → Task 3 + ADR-0011. FR-013 (Migration Notes) → Task 3. FR-014 (parallel) → Tasks 5–8 fan-out. FR-015 (out of scope) → Task 8 Out-of-scope + Constitution Check VI. FR-016 (user-invocable) → Task 8 frontmatter.
- SC-001 (file:line resolves) → Task 6 fr_refs + Task 7 stale_ref check. SC-002 (no write without consent) → Task 8. SC-003 (0 duplicate proposals) → Task 4. SC-004 (distinguishable by frontmatter) → Task 3 origin. SC-005 (0 new FSM status) → Task 3 + ADR-0011.
- All three user stories covered: US1 (P1) → Tasks 6,7,8,3; US2 (P2) → Tasks 5,4,8; US3 (P3) → Task 3.

**Placeholder scan:** Script and test steps contain complete bash. SKILL.md and subagent briefs are authored via `writing-skills` with explicit required-content checklists (the correct granularity for prose skills in this repo) — not code placeholders.

**Type/name consistency:** `brownfield.sh` subcommands (`guard`/`exclude`/`write-spec`), flags (`--slug`/`--body`/`--sha`/`--label`/`--paths`), frontmatter keys (`status`/`origin`/`source_sha`/`slug`), and the three return schemas (`BoundaryCandidate`/`DraftedSpec`/`Verdict`) are used identically across all tasks.
