---
slug: 0004-single-responsibility-migrate-adr-split
spec_slug: 0004-single-responsibility-migrate-adr-split
created: 2026-05-30
updated: 2026-05-30
---

# Implementation Plan: Single-Responsibility principle + migrate-adr decomposition

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Method constraints (from the constitution / CLAUDE.md):**
> - Edits to `skills/migrate-adr/SKILL.md` and creation of the two brief files MUST go through **`superpowers:writing-skills`** (Contributor Workflow).
> - The constitution amendment MUST go through **`/maxi:constitution`**; its ADR through **`/maxi:x-adr`** (Governance).
> - `bash tests/run-all.sh` MUST pass before every commit; commits require explicit user consent (repo rule).

**Goal:** Codify "single responsibility per skill" as a constitution principle, then decompose `migrate-adr` into a slim orchestrator plus two per-source briefs (`import-subagent.md`, `discover-subagent.md`) without changing its behavior, with the SRP boundary enforced by tests.

**Architecture:** Two independent slices. (1) Governance: add Core Principle VI to the constitution (v1.2.0→1.3.0), record an adoption ADR, add a one-line pointer in CLAUDE.md. (2) Refactor: move the Importer and Discoverer subagent briefs out of `migrate-adr/SKILL.md` into their own files, leaving the orchestrator to own only dispatch, the shared return-schema, exclusion matching, dedup, and the consent gate. Each extraction is test-first: repoint the existing grep assertions to the new file (RED), create the brief (GREEN), then remove the inlined copy from `SKILL.md` and assert its absence (boundary GREEN).

**Tech Stack:** Markdown (skills + briefs), Bash + `jq` test harness (`tests/lib/test-helpers.sh` assertions), `tests/check-migrate-adr.sh`, `tests/run-all.sh`.

---

## Summary

`migrate-adr` (342 lines) fuses two concerns with independent reasons to change — importing existing ADR files and discovering decisions from code/git. This plan establishes single-responsibility as a durable constitution principle and brings `migrate-adr` into compliance by extracting the two briefs behind a single orchestrator. The user-facing command, cross-source dedup, single consent gate, and `--import-only` behavior are unchanged; the existing invariant tests are repointed to the new file layout and extended with boundary assertions so the separation can't silently regress.

## Technical Context

**Language/Version**: Markdown (skill + brief docs) + Bash 3.2+ (test scripts)
**Primary Dependencies**: `jq`, `git`, the repo's `tests/lib/test-helpers.sh` (`assert_grep`, `assert_not_grep`, `assert_file_exists`)
**Storage**: Plain files under `skills/migrate-adr/`, `docs/maxi/`
**Testing**: `tests/check-migrate-adr.sh` (invariant greps) + `bash tests/run-all.sh` (fast tier)
**Target Platform**: Claude Code / OpenCode plugin runtime; macOS + Linux CI
**Project Type**: Skills plugin (dual-harness)
**Performance Goals**: N/A (authoring change)
**Constraints**: Behavior-preserving; no skill-count change; English-only; fast tier must stay green
**Scale/Scope**: 1 existing skill refactored, 2 new brief files, 1 constitution principle, 1 ADR, 1 test extended

## Constitution Check

*GATE: passed pre-flight on 2026-05-30. Re-check after Task 4.*

| Principle | Pass / Fail | Notes |
|-----------|-------------|-------|
| I. Mandatory Spec-Driven Pipeline | ✓ | Feature is going through specify→clarify→plan→… |
| II. Delegate to Superpowers, Never Duplicate | ✓ | No superpowers capability duplicated; skill edits delegate to `writing-skills` |
| III. Strict Pipeline — No Skipping | ✓ | No phase skipped |
| IV. ADR for Every Non-Trivial Decision | ✓ | Adoption ADR (FR-003) + decomposition-approach ADR proposed (see Decisions) |
| V. Artifacts Over Chat | ✓ | Principle, ADR, briefs, tests all persist as files |
| Constraint: strict vendoring | ✓ | `migrate-adr` is maxi-native, not vendored — editable |
| Constraint: status managed by pipeline | ✓ | Version bump via `/maxi:constitution`, status via pipeline |
| Constraint: fast-tier tests mandatory | ✓ | FR-012 |
| Contributor Workflow (writing-skills) | ✓ (method) | Encoded as a task-level constraint, not a violation |
| Governance (amendment ⇒ version + ADR) | ✓ | Task 1 |

No violations → Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
docs/maxi/specs/0004-single-responsibility-migrate-adr-split/
├── spec.md      # status: clarified
├── plan.md      # this file
└── tasks.md     # produced by /maxi:tasks (next phase)
```

### Source Code (repository root)

```text
docs/maxi/
├── constitution.md                 # MODIFY: add Principle VI, bump 1.2.0→1.3.0
└── adr/
    └── NNNN-single-responsibility-per-skill.md   # CREATE via /maxi:x-adr (adoption ADR)

skills/migrate-adr/
├── SKILL.md                        # MODIFY (writing-skills): slim to orchestrator
├── import-subagent.md              # CREATE: Importer brief (format detect + mappings + import frontmatter)
└── discover-subagent.md            # CREATE: Discoverer brief (layers + rubric + linkage + discover frontmatter)

tests/
└── check-migrate-adr.sh            # MODIFY: repoint assertions + add SRP-boundary assertions

CLAUDE.md                           # MODIFY: one-line pointer to Principle VI
```

**Structure Decision**: Approach A (per-source support files). The orchestrator `SKILL.md` keeps one coordinated responsibility; each volatile source-handler gets its own file. Matches the existing supporting-file pattern (`x-adr/adr-template.md`, `x-develop/integration-reviewer-prompt.md`). No new skill → no FSM/gating change → pipeline mandatory-sync docs untouched.

---

## Task 1: Constitution principle + adoption ADR + CLAUDE.md pointer (US1)

**Files:**
- Modify: `docs/maxi/constitution.md` (via `/maxi:constitution`)
- Create: `docs/maxi/adr/NNNN-single-responsibility-per-skill.md` (via `/maxi:x-adr`)
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add Core Principle VI via `/maxi:constitution`**

Invoke `/maxi:constitution` (amend mode). Add this principle after Principle V:

```markdown
### VI. Single Responsibility per Skill

Every skill owns exactly one responsibility — one phase transition, one report, one managed document, or one coordinated goal. When a skill fuses concerns with independent reasons to change, extract them into separate units (support files or sub-skills) behind a single coordinator. Litmus: if two parts of a skill would change for unrelated reasons, they are separate responsibilities.
```

In the same write, bump frontmatter `version: "1.2.0"` → `"1.3.0"`, set `updated: 2026-05-30`, and update the footer line to `**Version**: 1.3.0 | **Created**: 2026-05-24 | **Updated**: 2026-05-30`.

- [ ] **Step 2: Verify the amendment**

Run:
```bash
grep -n "Single Responsibility per Skill" docs/maxi/constitution.md
grep -n '^version: "1.3.0"' docs/maxi/constitution.md
```
Expected: principle heading found; version line is `1.3.0`.

- [ ] **Step 3: Record the adoption ADR via `/maxi:x-adr`**

Invoke `/maxi:x-adr` for the decision **"Adopt Single-Responsibility principle for skills."**
Drivers to record: (a) Governance requires an ADR for any constitution amendment; (b) prevent concern-fusion regressions (the `migrate-adr` precedent); (c) keep skills small enough to reason about and test in isolation.
On consent it writes `docs/maxi/adr/NNNN-single-responsibility-per-skill.md` and regenerates the ADR index.

- [ ] **Step 4: Add the one-line pointer in CLAUDE.md**

In `CLAUDE.md`, in the **Developing New Skills** section (just under its heading), add:

```markdown
All skills MUST be single-responsibility — see the project Constitution, Principle VI (*Single Responsibility per Skill*). Do not duplicate the principle text here; the constitution is authoritative.
```

- [ ] **Step 5: Verify US1 end-to-end**

Run:
```bash
grep -n "Principle VI" CLAUDE.md
ls docs/maxi/adr/*single-responsibility* 2>/dev/null
bash tests/run-all.sh
```
Expected: pointer present in CLAUDE.md; an ADR file exists; **all fast checks pass** (the existing `assert_not_grep "$CONSTITUTION" 'version: "1.1.0"'` still passes at 1.3.0).

- [ ] **Step 6: Commit (after user consent)**

```bash
git add docs/maxi/constitution.md docs/maxi/adr/ CLAUDE.md
git commit -m "feat(constitution): add Principle VI single-responsibility per skill (spec 0004 US1)"
```

---

## Task 2: Extract the Importer brief → `import-subagent.md` (US2 / US3)

**Files:**
- Test: `tests/check-migrate-adr.sh`
- Create: `skills/migrate-adr/import-subagent.md` (via `writing-skills`)
- Modify: `skills/migrate-adr/SKILL.md` (via `writing-skills`)

- [ ] **Step 1: Repoint importer assertions + add boundary checks (RED)**

In `tests/check-migrate-adr.sh`, add the variable near the existing ones (after line 8):
```bash
IMPORT="$ROOT/skills/migrate-adr/import-subagent.md"
```
Then **replace** the four importer-content assertions that currently target `$MIGRATE` — the `blocklist` (L32), `CONTRIBUTING.md` (L33), `source:` (L34), and `Nygard` "format-detection tables preserved" (L73) lines — with this block (place it where the L31–34 group is):
```bash
# --- 0004 US2/US3: importer brief extracted to its own file ---
assert_file_exists "$IMPORT" "import-subagent.md exists"
assert_grep "$MIGRATE" "import-subagent.md" "SKILL.md references importer brief"
assert_grep "$IMPORT" "blocklist" "FR-009 filename blocklist (importer brief)"
assert_grep "$IMPORT" "CONTRIBUTING.md" "FR-009 blocklist includes CONTRIBUTING (brief)"
assert_grep "$IMPORT" "source:" "FR-010 source provenance field (brief)"
assert_grep "$IMPORT" "Nygard" "FR-023 format-detection tables preserved (brief)"
assert_grep "$IMPORT" "Nygard → maxi mapping" "importer mapping table in brief"
assert_not_grep "$MIGRATE" "Nygard → maxi mapping" "SRP boundary: importer detail not in orchestrator"
```
Delete the now-duplicated old `Nygard` assertion at L73 (`FR-023 importer preserved` via "Subagent A" and "Subagent B" stay).

- [ ] **Step 2: Run to verify it fails (RED)**

Run: `bash tests/check-migrate-adr.sh`
Expected: FAIL — `import-subagent.md exists` (file missing) and the `$IMPORT` greps fail.

- [ ] **Step 3: Create the importer brief (GREEN part 1)**

Via `superpowers:writing-skills`, create `skills/migrate-adr/import-subagent.md`. Move the content currently in `SKILL.md` from **`### Subagent A — Importer` through the "Frontmatter invariants for all imported ADRs" block** (current lines 132–200) **verbatim**, prefixed with this header:
```markdown
# migrate-adr — Importer brief

> Dispatched by `migrate-adr/SKILL.md` (Step 3). Owns one responsibility: detect and convert
> existing ADR files into maxi format. Receives the exclusion context from the orchestrator;
> returns proposals in the orchestrator's Return schema. No consent/dedup logic here.
```
The move MUST preserve these exact strings (the tests assert them): `blocklist`, `CONTRIBUTING.md`, `source:`, `Nygard`, and the table heading `**Nygard → maxi mapping:**`.

- [ ] **Step 4: Run — importer asserts pass, boundary still fails**

Run: `bash tests/check-migrate-adr.sh`
Expected: the `$IMPORT` greps now PASS; `SRP boundary: importer detail not in orchestrator` still FAILS (content still duplicated in `SKILL.md`).

- [ ] **Step 5: Remove the inlined importer brief from SKILL.md (GREEN part 2)**

Via `superpowers:writing-skills`, in `SKILL.md` Step 3, replace the entire `### Subagent A — Importer` detailed section (lines 132–200) with:
```markdown
### Subagent A — Importer

Dispatch with the brief in [`import-subagent.md`](import-subagent.md). It detects ADR formats,
converts them to maxi format, and returns proposals per the **Return schema** above.
```
Leave the Return schema table (Step 3 header), the exclusion-context wiring, and `Subagent A`/`Subagent B` labels intact.

- [ ] **Step 6: Run check + full suite (GREEN)**

Run: `bash tests/check-migrate-adr.sh && bash tests/run-all.sh`
Expected: all importer + boundary asserts PASS; `All fast checks passed.`

- [ ] **Step 7: Commit (after user consent)**

```bash
git add skills/migrate-adr/import-subagent.md skills/migrate-adr/SKILL.md tests/check-migrate-adr.sh
git commit -m "refactor(migrate-adr): extract Importer brief to import-subagent.md (spec 0004 US2)"
```

---

## Task 3: Extract the Discoverer brief → `discover-subagent.md` (US2 / US3)

**Files:**
- Test: `tests/check-migrate-adr.sh`
- Create: `skills/migrate-adr/discover-subagent.md` (via `writing-skills`)
- Modify: `skills/migrate-adr/SKILL.md` (via `writing-skills`)

- [ ] **Step 1: Repoint discoverer assertions + add boundary checks (RED)**

In `tests/check-migrate-adr.sh`, add the variable after the `IMPORT` line:
```bash
DISCOVER="$ROOT/skills/migrate-adr/discover-subagent.md"
```
**Replace** the discoverer-content assertions currently on `$MIGRATE` — `costly to reverse` (L48), `git log -n 200` (L52), and the `git log -200` removal check (L53) — with:
```bash
# --- 0004 US2/US3: discoverer brief extracted to its own file ---
assert_file_exists "$DISCOVER" "discover-subagent.md exists"
assert_grep "$MIGRATE" "discover-subagent.md" "SKILL.md references discoverer brief"
assert_grep "$DISCOVER" "costly to reverse" "FR-017 significance rubric (discoverer brief)"
assert_grep "$DISCOVER" "Significance rubric" "discoverer rubric heading in brief"
assert_grep "$DISCOVER" "git log -n 200" "FR-019 git log -n 200 (brief)"
assert_not_grep "$DISCOVER" "git log -200" "FR-019 old flag removed (brief)"
assert_not_grep "$MIGRATE" "Significance rubric" "SRP boundary: discoverer detail not in orchestrator"
```
Leave the `$ADR` assertion `assert_grep "$ADR" "costly to reverse"` (L49) untouched — it targets `x-adr/SKILL.md`, unrelated to this move.

- [ ] **Step 2: Run to verify it fails (RED)**

Run: `bash tests/check-migrate-adr.sh`
Expected: FAIL — `discover-subagent.md exists` and the `$DISCOVER` greps fail.

- [ ] **Step 3: Create the discoverer brief (GREEN part 1)**

Via `superpowers:writing-skills`, create `skills/migrate-adr/discover-subagent.md`. Move the content currently in `SKILL.md` from **`### Subagent B — Discoverer` through the discovered-ADR "Default frontmatter" block** (current lines 202–232) **verbatim**, prefixed with:
```markdown
# migrate-adr — Discoverer brief

> Dispatched by `migrate-adr/SKILL.md` (Step 3) unless `--import-only`. Owns one responsibility:
> surface undocumented architectural decisions from manifests, config, structure, and git history.
> Receives the exclusion context and the constitution's principles from the orchestrator; returns
> proposals in the orchestrator's Return schema. No consent/dedup logic here.
```
The move MUST preserve these exact strings: `costly to reverse`, `Significance rubric`, `git log -n 200`. Do **not** reintroduce `git log -200`.

- [ ] **Step 4: Run — discoverer asserts pass, boundary still fails**

Run: `bash tests/check-migrate-adr.sh`
Expected: `$DISCOVER` greps PASS; `SRP boundary: discoverer detail not in orchestrator` still FAILS.

- [ ] **Step 5: Remove the inlined discoverer brief from SKILL.md (GREEN part 2)**

Via `superpowers:writing-skills`, in `SKILL.md` Step 3, replace the entire `### Subagent B — Discoverer` detailed section (lines 202–232) with:
```markdown
### Subagent B — Discoverer (skip if `--import-only`)

Dispatch with the brief in [`discover-subagent.md`](discover-subagent.md), passing the exclusion
context and the constitution's principle names. It returns proposals per the **Return schema** above.
```

- [ ] **Step 6: Run check + full suite (GREEN)**

Run: `bash tests/check-migrate-adr.sh && bash tests/run-all.sh`
Expected: all discoverer + boundary asserts PASS; `All fast checks passed.`

- [ ] **Step 7: Commit (after user consent)**

```bash
git add skills/migrate-adr/discover-subagent.md skills/migrate-adr/SKILL.md tests/check-migrate-adr.sh
git commit -m "refactor(migrate-adr): extract Discoverer brief to discover-subagent.md (spec 0004 US2)"
```

---

## Task 4: Finalize orchestrator + behavior-preservation review (US2)

**Files:**
- Modify: `skills/migrate-adr/SKILL.md` (via `writing-skills`, if any cleanup needed)
- Verify only: `tests/check-migrate-adr.sh`, `tests/run-all.sh`

- [ ] **Step 1: Confirm the orchestrator still owns only coordination**

Read `skills/migrate-adr/SKILL.md` and confirm it now contains, and only contains, orchestration: Overview, Iron Rule, Process digraph, Step 1 prereqs, Step 2 exclusion matching, Step 3 dispatch (two short references + the Return schema), Step 4 dedup, Step 5 summary, Step 6 consent gate, Guards, Out of Scope, Common Mistakes. The two `### Subagent` subsections are now one-line references.

- [ ] **Step 2: Behavior-preservation diff review**

Run:
```bash
git log --oneline -3
git diff --stat HEAD~2 -- skills/migrate-adr/
```
Confirm the only `SKILL.md` deletions are the moved briefs (now living in the two new files), and no orchestration logic (consent verbs, dedup rule, exclusion algorithm, `--import-only`, NNNN-at-write-time, single README regen) was altered. Spot-check that the dispatch step still passes exclusion context to both subagents and constitution principles to Subagent B.

- [ ] **Step 3: Re-run the Constitution Check gate**

Confirm Principle VI now holds for `migrate-adr`: three files, each with one responsibility; orchestrator coordinates. Confirm no new skill was added (skill count unchanged → `check-skills-present.sh` green).

- [ ] **Step 4: Full suite + final verification**

Run: `bash tests/run-all.sh`
Expected: `All fast checks passed.` (14 checks).
Optional but recommended for a skill change: `bash tests/run-all.sh --integration`.

- [ ] **Step 5: Commit any cleanup (after user consent)**

```bash
git add skills/migrate-adr/SKILL.md
git commit -m "refactor(migrate-adr): tidy orchestrator after brief extraction (spec 0004 US2)"
```
(Skip if Step 1 found nothing to change.)

---

## Decisions

> Auto-populated during the `/maxi:plan` ADR scan. Recorded via `/maxi:x-adr` on consent.

| ADR | Title | Status |
|-----|-------|--------|
| (Task 1) | Adopt Single-Responsibility principle for skills | **proposed** — FR-003, written during Task 1 |
| (scan) | `migrate-adr` decomposition via per-source support files (Approach A over internal sub-skills) | **proposed** — offer to record now or at implement |

## Complexity Tracking

> No constitution violations — section intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |
