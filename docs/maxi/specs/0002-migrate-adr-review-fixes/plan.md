---
slug: 0002-migrate-adr-review-fixes
spec_slug: 0002-migrate-adr-review-fixes
created: 2026-05-29
updated: 2026-05-29
---

# Implementation Plan: migrate-adr Review Fixes

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **All `SKILL.md` edits MUST be authored via `superpowers:writing-skills`** (project rule: do not hand-write SKILL.md). The target text in each task is the behavioral spec to feed writing-skills; the `check-migrate-adr.sh` assertions are the GREEN gate.

**Goal:** Remediate 11 review findings in `migrate-adr` plus a shared significance rubric, a CLAUDE.md authoring-flow correction, and a one-way constitution decoupling — all verified by a new fast-tier check script.

**Architecture:** The work is documentation/skill editing, not application code. Each behavioral change to a `SKILL.md` is paired with one or more `grep`-based assertions in a new `tests/check-migrate-adr.sh`, following the repo's existing `assert_grep`/`assert_not_grep` helper pattern. TDD here means: add the assertion (RED, fails against current skill text) → make the edit via writing-skills (GREEN) → commit. The constitution amendment is captured as an ADR via `/maxi:adr`.

**Tech Stack:** Markdown SKILL.md files, Bash test scripts (`tests/lib/test-helpers.sh`), `jq`, git.

> **⚠️ Commit Discipline (applies to EVERY commit step in this plan — fixes analysis finding D1):** The constitution mandates *"`bash tests/run-all.sh` must pass before any commit."* Therefore, before **every** `git commit` below you MUST run `bash tests/run-all.sh` and confirm it prints `All fast checks passed.` The per-task `verify GREEN` lines run the targeted `check-migrate-adr.sh` for fast inner-loop feedback, but the **commit gate is the full fast tier** — every commit block is shown with that suite run prepended. Never commit on a red (or un-run) full suite.

---

## Summary

Primary requirement: make `migrate-adr`'s consent gate and exclusion matching correct and unsurprising (the two P1 stories), then close the medium/low findings, add a significance rubric shared with `adr`, fix the CLAUDE.md authoring flow, and decouple the constitution from CLAUDE.md (one-way dependency) with a formal amendment ADR. Technical approach: paired assertion + writing-skills edit per finding, gated by a new fast-tier test.

## Technical Context

**Language/Version**: Bash (test scripts), Markdown (skills/docs) — N/A runtime
**Primary Dependencies**: `tests/lib/test-helpers.sh`, `jq`, git
**Storage**: Files only (`skills/`, `docs/maxi/`, `CLAUDE.md`, `tests/`)
**Testing**: `bash tests/run-all.sh` (fast tier); `--integration` opt-in
**Target Platform**: Claude Code + OpenCode plugin
**Project Type**: Dual-harness skills plugin
**Performance Goals**: N/A
**Constraints**: SKILL.md edits via writing-skills only; fast tier must stay green; English only
**Scale/Scope**: 2 skill files, 2 doc files, 1 new test, 1 ADR

## Constitution Check

*GATE: Passed pre-flight in `/maxi:plan`. Re-checked after planning — still passes.*

| Principle | Pass / Fail | Notes |
|-----------|-------------|-------|
| I. Mandatory Spec-Driven Pipeline | ✓ | Following specify→clarify→plan |
| II. Delegate to Superpowers, Never Duplicate | ✓ | SKILL.md edits via writing-skills; no capability duplicated |
| III. Strict Pipeline — No Skipping | ✓ | No phases skipped |
| IV. ADR for Every Non-Trivial Decision | ✓ | Task 10 proposes the constitution-amendment ADR (FR-025) |
| V. Artifacts Over Chat | ✓ | All changes land in files |
| Strict vendoring (byte-identical) | ✓ | `migrate-adr`/`adr` are maxi-native, not vendored — `check-sync-invariant.sh` unaffected |
| Fast-tier tests mandatory | ✓ | Commit Discipline rule (above): `bash tests/run-all.sh` must pass before **every** commit (fixes analysis finding D1); Task 1 adds `check-migrate-adr.sh` |
| English only | ✓ | All edits in English |

## Project Structure

```text
docs/maxi/specs/0002-migrate-adr-review-fixes/
├── spec.md              # status: clarified (input)
├── plan.md              # This file
└── tasks.md             # /maxi:tasks output (not created here)

Files touched by this plan:
skills/migrate-adr/SKILL.md   # Tasks 2–8 (most FRs)
skills/adr/SKILL.md           # Task 7 (FR-018 rubric in description)
CLAUDE.md                     # Task 9 (FR-022 authoring flow)
docs/maxi/constitution.md     # Task 10 (FR-024/025 amendment)
docs/maxi/adr/NNNN-*.md       # Task 10 (amendment ADR, via /maxi:adr)
tests/check-migrate-adr.sh    # Task 1 (new fast-tier check; the GREEN gate)
tests/run-all.sh              # Task 1 (register new check)
```

**Structure Decision**: No new source directories. One new test script registered in the existing fast tier. SKILL.md edits are surgical section replacements authored through writing-skills.

## Decisions

> Auto-populated when architectural choices are recorded as ADRs.

| ADR | Title | Status |
|-----|-------|--------|
| (pending Task 10) | Constitution decoupled from CLAUDE.md (one-way dependency) | proposed at Task 10 |

## Complexity Tracking

No constitution violations. Section intentionally empty.

---

## Tasks

### Task 1: Bootstrap fast-tier check + register it

**Files:**
- Create: `tests/check-migrate-adr.sh`
- Modify: `tests/run-all.sh`

- [ ] **Step 1: Create the check script skeleton**

```bash
#!/usr/bin/env bash
# Check migrate-adr (and adr) SKILL.md invariants from spec 0002.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
source "$ROOT/tests/lib/test-helpers.sh"

MIGRATE="$ROOT/skills/migrate-adr/SKILL.md"
ADR="$ROOT/skills/adr/SKILL.md"
CLAUDEMD="$ROOT/CLAUDE.md"
CONSTITUTION="$ROOT/docs/maxi/constitution.md"
failures=0

assert_file_exists "$MIGRATE" "migrate-adr SKILL.md"

# --- assertions added incrementally by later tasks ---

summary_and_exit "migrate-adr invariant checks"
```

- [ ] **Step 2: Make it executable**

Run: `chmod +x tests/check-migrate-adr.sh`

- [ ] **Step 3: Register in run-all.sh**

Add after the `check-skills-present.sh` line in `tests/run-all.sh`:

```bash
run_check "$TESTS_DIR/check-migrate-adr.sh"     "migrate-adr invariant checks"
```

- [ ] **Step 4: Run full fast tier to confirm green skeleton**

Run: `bash tests/run-all.sh`
Expected: PASS (skeleton only asserts the file exists)

- [ ] **Step 5: Commit**

```bash
bash tests/run-all.sh   # D1 gate: must print "All fast checks passed." before committing
git add tests/check-migrate-adr.sh tests/run-all.sh
git commit -m "test(migrate-adr): add fast-tier check skeleton for spec 0002"
```

---

### Task 2: Consent gate — explicit verbs (FR-001..005, US1)

**Files:**
- Modify: `tests/check-migrate-adr.sh`
- Modify: `skills/migrate-adr/SKILL.md` (Step 6 consent gate)

- [ ] **Step 1: Add assertions (RED)**

Insert before the `summary_and_exit` line in `check-migrate-adr.sh`:

```bash
# FR-001: imported prompt offers four explicit verbs
assert_grep "$MIGRATE" "accept / skip / deprecate / edit" "FR-001 imported verbs"
# FR-004: discovered prompt offers accept/skip/edit
assert_grep "$MIGRATE" "accept / skip / edit" "FR-004 discovered verbs"
# FR-002/003: skip writes nothing; deprecate writes deprecated
assert_grep "$MIGRATE" "skip.*no file written" "FR-002 skip = no file"
assert_grep "$MIGRATE" "deprecate.*status: deprecated" "FR-003 deprecate writes deprecated"
# FR-005: ambiguous defaults to skip
assert_grep "$MIGRATE" "second ambiguous.*skip" "FR-005 ambiguous defaults to skip"
# the old binary "no = import as deprecated" wording must be gone
assert_not_grep "$MIGRATE" "no = import as deprecated" "FR-001 old binary prompt removed"
```

- [ ] **Step 2: Run to verify RED**

Run: `bash tests/check-migrate-adr.sh`
Expected: FAIL on the FR-001..005 assertions (skill still has the binary prompt)

- [ ] **Step 3: Edit the skill via writing-skills**

Behavioral spec to feed `superpowers:writing-skills` — replace the Step 6 "Consent Gate" prompts and tables. Target content:

> **Imported prompt:** `Import this as ADR-NNNN? (accept / skip / deprecate / edit)`
>
> | Response | Action |
> |----------|--------|
> | `accept` | Write with `status: accepted` |
> | `skip` | No file written |
> | `deprecate` | Write with `status: deprecated` (preserve history without adopting) |
> | `edit` | Accept amendments inline, write with `status: accepted` |
>
> **Discovered prompt:** `Record this as ADR-NNNN? (accept / skip / edit)`
>
> | Response | Action |
> |----------|--------|
> | `accept` | Write with `status: accepted` |
> | `skip` | Discard — no file written |
> | `edit` | Accept amendments inline, write with `status: accepted` |
>
> **Ambiguous response** ("ok", "sure", "looks good", "yes", "no", silence): re-ask once naming the explicit verbs for that case (imported: `accept / skip / deprecate`; discovered: `accept / skip`). A **second ambiguous** response defaults to `skip` (no file written).

Also update the Process digraph labels and the "Common Mistakes" row that referenced the old yes/no flow so they use the new verbs.

- [ ] **Step 4: Run to verify GREEN**

Run: `bash tests/check-migrate-adr.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
bash tests/run-all.sh   # D1 gate: must print "All fast checks passed." before committing
git add skills/migrate-adr/SKILL.md tests/check-migrate-adr.sh
git commit -m "fix(migrate-adr): explicit consent verbs, skip never writes (FR-001..005)"
```

---

### Task 3: Exclusion matching — proper-noun set (FR-006..008, FR-013, US2)

**Files:**
- Modify: `tests/check-migrate-adr.sh`
- Modify: `skills/migrate-adr/SKILL.md` (Step 2 exclusion context)

- [ ] **Step 1: Add assertions (RED)**

```bash
# FR-006: stopword stripping documented
assert_grep "$MIGRATE" "strip stopwords" "FR-006 stopword strip"
# FR-007: set-based proper-noun matching, exclude on equality, flag on partial overlap
assert_grep "$MIGRATE" "proper-noun" "FR-007 proper-noun set"
assert_grep "$MIGRATE" "partial.*overlap.*flag" "FR-007 partial overlap flags"
# FR-008: short/none -> flag, not exclude
assert_grep "$MIGRATE" "shorter than 3 characters" "FR-008 short token flagged"
# the old symmetric substring rule must be gone
assert_not_grep "$MIGRATE" "either contains the other" "FR-006 old substring rule removed"
```

- [ ] **Step 2: Run to verify RED**

Run: `bash tests/check-migrate-adr.sh`
Expected: FAIL on FR-006..008 assertions

- [ ] **Step 3: Edit the skill via writing-skills**

Replace the Step 2 "Matching is case-insensitive substring…" paragraph with:

> **Matching rule.** Normalize each label: lowercase, strip stopwords (`use`, `for`, `the`, `a`, `as`, `with`, `to`). Build the **set of proper-noun (capitalized) tokens**; if a label has none, its longest remaining token (3+ characters) forms a single-element set.
> - **Equal sets** → exclude (already covered).
> - **Partial overlap** (share ≥1 token but not equal) → **flag for the user, do not auto-exclude**.
> - **No overlap** → keep.
> - **No qualifying token** (all stopwords, or every candidate shorter than 3 characters) → flag for the user, never auto-exclude.

Add a note to Step 2 that `.rejected` labels (Task 5) are normalized the same way before matching (FR-013).

- [ ] **Step 4: Run to verify GREEN**

Run: `bash tests/check-migrate-adr.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
bash tests/run-all.sh   # D1 gate: must print "All fast checks passed." before committing
git add skills/migrate-adr/SKILL.md tests/check-migrate-adr.sh
git commit -m "fix(migrate-adr): set-based exclusion matching, flag don't drop (FR-006..008,013)"
```

---

### Task 4: Importer hardening — blocklist + provenance (FR-009, FR-010, US3)

**Files:**
- Modify: `tests/check-migrate-adr.sh`
- Modify: `skills/migrate-adr/SKILL.md` (Subagent A — Importer)

- [ ] **Step 1: Add assertions (RED)**

```bash
# FR-009: filename blocklist
assert_grep "$MIGRATE" "README.md" "FR-009 blocklist README"
assert_grep "$MIGRATE" "CONTRIBUTING.md" "FR-009 blocklist CONTRIBUTING"
# FR-010: source provenance field
assert_grep "$MIGRATE" "source:" "FR-010 source provenance field"
```

- [ ] **Step 2: Run to verify RED**

Run: `bash tests/check-migrate-adr.sh`
Expected: FAIL on FR-009/010

- [ ] **Step 3: Edit the skill via writing-skills**

In Subagent A, after the scan-directories line add:

> **Skip a fixed, case-insensitive filename blocklist before format detection:** `README.md`, `index.md`, `template.md`, `CONTRIBUTING.md`. No subjective "does the H1 look like a decision" heuristic — the blocklist plus format detection is the filter.

Add to the "Frontmatter invariants for all imported ADRs" block:

```yaml
source: [original file path, or "[unknown]" if undeterminable]
```

- [ ] **Step 4: Run to verify GREEN**

Run: `bash tests/check-migrate-adr.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
bash tests/run-all.sh   # D1 gate: must print "All fast checks passed." before committing
git add skills/migrate-adr/SKILL.md tests/check-migrate-adr.sh
git commit -m "fix(migrate-adr): importer blocklist + source provenance (FR-009,010)"
```

---

### Task 5: Rejection log (FR-011, FR-012, FR-014, US4)

**Files:**
- Modify: `tests/check-migrate-adr.sh`
- Modify: `skills/migrate-adr/SKILL.md` (Step 2 read + Step 6 skip handling)

- [ ] **Step 1: Add assertions (RED)**

```bash
# FR-011: discovered skip appends to .rejected
assert_grep "$MIGRATE" ".rejected" "FR-011 rejected log path"
# FR-014: .rejected exempt from Iron Rule
assert_grep "$MIGRATE" "bookkeeping" "FR-014 rejected is bookkeeping"
```

- [ ] **Step 2: Run to verify RED**

Run: `bash tests/check-migrate-adr.sh`
Expected: FAIL on FR-011/014

- [ ] **Step 3: Edit the skill via writing-skills**

In Step 6, under the discovered-`skip` action, add:

> On `skip` of a **discovered** proposal, append its domain label to `docs/maxi/adr/.rejected` (one label per line; create the file with a `#`-comment header on first write). On `skip` of an **imported** proposal, do **not** write to `.rejected` — the source file on disk is already the record. Writing to `.rejected` is internal **bookkeeping**, not an ADR, and is exempt from the consent gate / Iron Rule.

In Step 2, extend exclusion-context construction to also read `docs/maxi/adr/.rejected` (treat missing as empty) and feed its labels — normalized per Task 3 — into the exclusion list.

- [ ] **Step 4: Run to verify GREEN**

Run: `bash tests/check-migrate-adr.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
bash tests/run-all.sh   # D1 gate: must print "All fast checks passed." before committing
git add skills/migrate-adr/SKILL.md tests/check-migrate-adr.sh
git commit -m "feat(migrate-adr): rejection log for skipped discoveries (FR-011,012,014)"
```

---

### Task 6: Subagent return contract + constitution use (FR-015, FR-016, US5)

**Files:**
- Modify: `tests/check-migrate-adr.sh`
- Modify: `skills/migrate-adr/SKILL.md` (Step 3 dispatch + Subagent B)

- [ ] **Step 1: Add assertions (RED)**

```bash
# FR-015: explicit return schema fields
assert_grep "$MIGRATE" "domain_label" "FR-015 return schema domain_label"
assert_grep "$MIGRATE" "source_path" "FR-015 return schema source_path"
# FR-016: constitution principles passed to Discoverer
assert_grep "$MIGRATE" "related_principles" "FR-016 related_principles populated"
```

- [ ] **Step 2: Run to verify RED**

Run: `bash tests/check-migrate-adr.sh`
Expected: FAIL on FR-015/016

- [ ] **Step 3: Edit the skill via writing-skills**

In Step 3, add a **Return schema** block both subagents must satisfy:

> Each subagent returns a list of proposals. Every proposal object includes: `source` (`import`|`discover`), `domain_label`, `title`, the full draft `body`. Importer proposals additionally include `format` (`nygard`|`madr`|`plain`) and `source_path`.

In Step 3, when dispatching Subagent B, add: pass the constitution's principle names/titles. In Subagent B, add: when a discovered decision relates to a named principle, set `related_principles` to it and note the link in `## Context`; if none relates, leave `related_principles: []` (no fabricated links).

- [ ] **Step 4: Run to verify GREEN**

Run: `bash tests/check-migrate-adr.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
bash tests/run-all.sh   # D1 gate: must print "All fast checks passed." before committing
git add skills/migrate-adr/SKILL.md tests/check-migrate-adr.sh
git commit -m "feat(migrate-adr): subagent return contract + constitution-informed discovery (FR-015,016)"
```

---

### Task 7: Significance rubric — Discoverer + adr description (FR-017, FR-018, US6)

**Files:**
- Modify: `tests/check-migrate-adr.sh`
- Modify: `skills/migrate-adr/SKILL.md` (Subagent B)
- Modify: `skills/adr/SKILL.md` (frontmatter `description`)

- [ ] **Step 1: Add assertions (RED)**

```bash
# FR-017: rubric in migrate-adr Discoverer
assert_grep "$MIGRATE" "costly to reverse" "FR-017 rubric in discoverer"
# FR-018: same rubric in adr description
assert_grep "$ADR" "costly to reverse" "FR-018 rubric in adr description"
```

- [ ] **Step 2: Run to verify RED**

Run: `bash tests/check-migrate-adr.sh`
Expected: FAIL on FR-017/018

- [ ] **Step 3: Edit both skills via writing-skills**

In Subagent B, before the "propose" behavior, add:

> **Significance rubric.** Propose a decision only if it meets at least one of: **costly to reverse**, **constrains future choices**, or **was contested** (a real alternative was weighed). A bare dependency in a manifest or a git-log keyword hit is **not** sufficient on its own — drop easily-reversible, uncontested choices (e.g. a formatter).

In `skills/adr/SKILL.md`, rewrite the `description:` so its parenthetical example list becomes the rubric, e.g.:

> `description: Use when the plan or implement skill has detected an architectural decision worth recording — one that is costly to reverse, constrains future choices, or was contested — that should be captured as an ADR in the current maxi project`

- [ ] **Step 4: Run to verify GREEN + frontmatter still valid**

Run: `bash tests/check-migrate-adr.sh && bash tests/check-frontmatter.sh`
Expected: PASS both (adr description edit must keep valid YAML)

- [ ] **Step 5: Commit**

```bash
bash tests/run-all.sh   # D1 gate: must print "All fast checks passed." before committing
git add skills/migrate-adr/SKILL.md skills/adr/SKILL.md tests/check-migrate-adr.sh
git commit -m "feat(adr,migrate-adr): shared significance rubric (FR-017,018)"
```

---

### Task 8: Polish — git flag, summary table, single README regen (FR-019..021, US7)

**Files:**
- Modify: `tests/check-migrate-adr.sh`
- Modify: `skills/migrate-adr/SKILL.md` (Subagent B git command; Step 5 table; Step 6 README regen)

- [ ] **Step 1: Add assertions (RED)**

```bash
# FR-019: correct git flag
assert_grep "$MIGRATE" "git log -n 200" "FR-019 git log -n 200"
assert_not_grep "$MIGRATE" "git log -200" "FR-019 old flag removed"
# FR-020: no tentative ADR numbers in the table note
assert_not_grep "$MIGRATE" "(t) = tentative" "FR-020 tentative numbers removed"
assert_grep "$MIGRATE" "assigned sequentially at write time" "FR-020 write-time note"
# FR-021: single README regen
assert_grep "$MIGRATE" "regenerate.*README.*once" "FR-021 single regen"
```

- [ ] **Step 2: Run to verify RED**

Run: `bash tests/check-migrate-adr.sh`
Expected: FAIL on FR-019..021

- [ ] **Step 3: Edit the skill via writing-skills**

- Subagent B git line: change `git log -200 ...` → `git log -n 200 ...`.
- Step 5 table: replace the `Tentative ADR` column and `(t) = tentative number, assigned at write time` legend with a plain `#` row index and the note: *"Final ADR numbers are assigned sequentially at write time, not shown here."*
- Step 6: change "After each write: regenerate README.md" to: *"Regenerate `docs/maxi/adr/README.md` **once** after the consent loop completes (and on early exit, regenerate for whatever was written)."*

- [ ] **Step 4: Run to verify GREEN**

Run: `bash tests/check-migrate-adr.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
bash tests/run-all.sh   # D1 gate: must print "All fast checks passed." before committing
git add skills/migrate-adr/SKILL.md tests/check-migrate-adr.sh
git commit -m "fix(migrate-adr): polish git flag, honest table, single README regen (FR-019..021)"
```

---

### Task 9: CLAUDE.md authoring flow (FR-022, US8)

**Files:**
- Modify: `tests/check-migrate-adr.sh`
- Modify: `CLAUDE.md` ("Developing New Skills" section)

- [ ] **Step 1: Add assertions (RED)**

```bash
# FR-022: new four-step authoring flow documented
assert_grep "$CLAUDEMD" "brainstorm" "FR-022 brainstorm in flow"
assert_grep "$CLAUDEMD" "writing-skills" "FR-022 writing-skills in flow"
assert_not_grep "$CLAUDEMD" "RED: run pressure scenario WITHOUT skill" "FR-022 old TDD cycle removed"
```

- [ ] **Step 2: Run to verify RED**

Run: `bash tests/check-migrate-adr.sh`
Expected: FAIL (old RED/GREEN/REFACTOR text still present)

- [ ] **Step 3: Edit CLAUDE.md (direct edit — not a SKILL.md)**

Replace the "Developing New Skills" TDD-cycle body with:

> All new skills MUST be authored using `superpowers:writing-skills`. Do not hand-write SKILL.md files.
>
> The authoring flow:
> 1. **brainstorm** — explore intent and design (`superpowers:brainstorming`)
> 2. **spec** — write the spec (`/maxi:specify`)
> 3. **plan** — write the implementation plan (`superpowers:writing-plans`)
> 4. **writing-skills** — author/edit the SKILL.md (`superpowers:writing-skills`)

- [ ] **Step 4: Run to verify GREEN**

Run: `bash tests/check-migrate-adr.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
bash tests/run-all.sh   # D1 gate: must print "All fast checks passed." before committing
git add CLAUDE.md tests/check-migrate-adr.sh
git commit -m "docs(CLAUDE): authoring flow brainstorm→spec→plan→writing-skills (FR-022)"
```

---

### Task 10: Constitution decoupling + amendment ADR (FR-024, FR-025, US8)

**Files:**
- Modify: `tests/check-migrate-adr.sh`
- Modify: `docs/maxi/constitution.md` (Contributor Workflow + version/updated)
- Create: `docs/maxi/adr/NNNN-*.md` (via `/maxi:adr`)

- [ ] **Step 1: Add assertions (RED)**

```bash
# FR-024: constitution no longer references CLAUDE.md / RED-GREEN-REFACTOR
assert_not_grep "$CONSTITUTION" "RED/GREEN/REFACTOR" "FR-024 no RGR ref"
assert_not_grep "$CONSTITUTION" "CLAUDE.md" "FR-024 no CLAUDE.md ref"
# FR-025: version bumped past 1.1.0
assert_not_grep "$CONSTITUTION" "version: \"1.1.0\"" "FR-025 version bumped"
```

- [ ] **Step 2: Run to verify RED**

Run: `bash tests/check-migrate-adr.sh`
Expected: FAIL (constitution still references CLAUDE.md and is at 1.1.0)

- [ ] **Step 3: Reword the Contributor Workflow (direct edit)**

Change `constitution.md:41` from:

> Every new maxi-native skill is authored via `superpowers:writing-skills` (RED/GREEN/REFACTOR cycle documented in `CLAUDE.md`).

to:

> Every new maxi-native skill is authored via `superpowers:writing-skills`. The constitution defines this requirement; harness docs and skills reference the constitution, never the reverse.

- [ ] **Step 4: Bump version + updated (direct edit)**

Frontmatter: `version: "1.1.0"` → `version: "1.2.0"`; `updated: 2026-05-24` → `updated: 2026-05-29`. Update the footer line `**Version**: 1.1.0 ... **Updated**: 2026-05-24` to match.

- [ ] **Step 5: Run to verify GREEN**

Run: `bash tests/check-migrate-adr.sh`
Expected: PASS

- [ ] **Step 6: Propose the amendment ADR**

Invoke `/maxi:adr` for the decision "Constitution decoupled from CLAUDE.md — one-way dependency direction." It drafts, shows, and writes the ADR only on consent (FR-025). Record drivers: Principle governance (amendments need an ADR), avoiding circular doc dependencies.

- [ ] **Step 7: Commit**

```bash
bash tests/run-all.sh   # D1 gate: must print "All fast checks passed." before committing
git add docs/maxi/constitution.md docs/maxi/adr/ tests/check-migrate-adr.sh
git commit -m "docs(constitution): decouple from CLAUDE.md, v1.2.0 + amendment ADR (FR-024,025)"
```

---

### Task 11: Full verification + preservation check (FR-023, all SCs)

**Files:**
- Verify only: all touched files

- [ ] **Step 1: Confirm preserved behavior (FR-023)**

Add assertions confirming the non-defective parts survive:

```bash
assert_grep "$MIGRATE" "Subagent A" "FR-023 importer preserved"
assert_grep "$MIGRATE" "Subagent B" "FR-023 discoverer preserved"
assert_grep "$MIGRATE" "Nygard" "FR-023 format tables preserved"
```

Run: `bash tests/check-migrate-adr.sh`
Expected: PASS

- [ ] **Step 2: Run full fast tier (SC-005)**

Run: `bash tests/run-all.sh`
Expected: `All fast checks passed.` — including `check-frontmatter.sh`, `check-skills-present.sh`, `check-sync-invariant.sh`.

- [ ] **Step 3: Run integration tier (behavioral confidence)**

Run: `bash tests/run-all.sh --integration`
Expected: PASS. If the migrate-adr behavior is not covered by an integration prompt, note it — do not silently skip.

- [ ] **Step 4: Spec-coverage sanity pass**

Confirm SC-001..004 are satisfied by the new assertions (skip=no write, no false exclusions, re-run skips rejected, no non-ADR imports). Note any SC not covered by a check as a known manual-verification item.

- [ ] **Step 5: Final commit (if any verification fixups)**

```bash
bash tests/run-all.sh   # D1 gate: must print "All fast checks passed." before committing
git add -A
git commit -m "test(migrate-adr): preservation + full-suite verification (FR-023, SCs)"
```

---

## Self-Review

**Spec coverage:** FR-001..005 → Task 2; FR-006..008,013 → Task 3; FR-009,010 → Task 4; FR-011,012,014 → Task 5; FR-015,016 → Task 6; FR-017,018 → Task 7; FR-019,020,021 → Task 8; FR-022 → Task 9; FR-024,025 → Task 10; FR-023 → Task 11. SC-001..005 → Task 11 (+ per-task asserts). All 8 user stories mapped. No gaps.

**Placeholder scan:** No TBD/TODO. Each edit task gives concrete target text and concrete assertions. `NNNN-*.md` for the ADR is intentional (number assigned by `/maxi:adr` at write time).

**Type consistency:** Field names (`source`, `domain_label`, `source_path`, `related_principles`, `.rejected`) match the spec's Key Entities and are used consistently across tasks.

**Note on `.rejected` / Artifact Convention:** Per spec Assumptions, `.rejected` is intentionally NOT added to CLAUDE.md's Artifact Convention this pass — not an omission.
