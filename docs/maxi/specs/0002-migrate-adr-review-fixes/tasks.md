---
slug: 0002-migrate-adr-review-fixes
spec_slug: 0002-migrate-adr-review-fixes
created: 2026-05-29
updated: 2026-05-29
---

# Tasks: migrate-adr Review Fixes

**Input**: Design documents from `docs/maxi/specs/0002-migrate-adr-review-fixes/`
**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Tests**: TDD per `superpowers:test-driven-development`. Here "tests" are `grep`-based assertions added to `tests/check-migrate-adr.sh`; each must FAIL (RED) before the matching SKILL.md/doc edit, then PASS (GREEN). SKILL.md edits are authored via `superpowers:writing-skills`.

> **⚠️ Commit Discipline (D1):** Per the constitution, `bash tests/run-all.sh` MUST pass (`All fast checks passed.`) before **every** `git commit`. Every task that ends in "commit" below includes this full-suite gate — the per-task `check-migrate-adr.sh` run is fast inner-loop feedback only, not the commit gate.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (US1–US8)
- Exact file paths included

> **Shared-file note (why so few [P]):** All test tasks append to the single file `tests/check-migrate-adr.sh`, so no two test tasks are parallel. Impl tasks for US1–US7 all edit `skills/migrate-adr/SKILL.md`, so they are not parallel with each other. Only the US8 impl edits (CLAUDE.md, constitution.md) touch unique files and carry `[P]`.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Stand up the fast-tier check harness that every story extends.

- [x] T001 Create `tests/check-migrate-adr.sh` skeleton (shebang, `set -euo pipefail`, source `tests/lib/test-helpers.sh`, define `MIGRATE`/`ADR`/`CLAUDEMD`/`CONSTITUTION` vars, single `assert_file_exists` on the skill, `summary_and_exit`) — plan Task 1 Step 1
- [x] T002 `chmod +x tests/check-migrate-adr.sh` — plan Task 1 Step 2

**Checkpoint**: Check script exists and is executable.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Register the check in the fast tier so every story's RED/GREEN gate runs.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete — every story adds assertions to this registered script.

- [x] T003 Register `check-migrate-adr.sh` in `tests/run-all.sh` (add `run_check` line after `check-skills-present.sh`) — plan Task 1 Step 3
- [x] T004 Run `bash tests/run-all.sh`, confirm green skeleton, then commit (`test(migrate-adr): add fast-tier check skeleton`) — full-suite gate (D1) before commit — plan Task 1 Steps 4–5

**Checkpoint**: Foundation ready — user story phases can begin.

---

## Phase 3: User Story 1 - Saying "no" never writes a file unexpectedly (Priority: P1) 🎯 MVP

**Goal**: Imported-proposal consent gate uses explicit verbs; `skip` never writes; ambiguity defaults to `skip`.
**Independent Test**: Reply `skip` to an imported proposal → no file; reply `deprecate` → file with `status: deprecated`.

### Tests for User Story 1

- [x] T005 [US1] Add FR-001..005 assertions to `tests/check-migrate-adr.sh` (4 verbs, `skip`=no file, `deprecate`=deprecated, ambiguous→skip, old `no = import as deprecated` gone); run and verify RED — plan Task 2 Steps 1–2

### Implementation for User Story 1

- [x] T006 [US1] Via `superpowers:writing-skills`, rewrite Step 6 consent gate in `skills/migrate-adr/SKILL.md` (imported `accept/skip/deprecate/edit`, discovered `accept/skip/edit`, re-ask + default-skip; update digraph + Common Mistakes); verify GREEN; **full-suite gate (D1)**; commit — plan Task 2 Steps 3–5

**Checkpoint**: US1 complete and independently testable. **This is the MVP** (US2 is also P1 — see Phase 4).

---

## Phase 4: User Story 2 - Exclusion matching does not silently drop decisions (Priority: P1)

**Goal**: Set-based proper-noun matching; exclude on set equality, flag on partial overlap, never auto-exclude short/empty.
**Independent Test**: "Use Postgres as primary store" not excluded by "Use Tokio for async runtime"; a `go`-only label is flagged.

### Tests for User Story 2

- [x] T007 [US2] Add FR-006..008/013 assertions to `tests/check-migrate-adr.sh` (stopword strip, proper-noun set, partial-overlap→flag, <3-char→flag, old "either contains the other" gone); verify RED — plan Task 3 Steps 1–2

### Implementation for User Story 2

- [x] T008 [US2] Via `superpowers:writing-skills`, replace the Step 2 matching rule in `skills/migrate-adr/SKILL.md` (set-based; equal→exclude, partial→flag, none→keep; note `.rejected` normalization); verify GREEN; **full-suite gate (D1)**; commit — plan Task 3 Steps 3–5

**Checkpoint**: Both P1 stories complete — correctness core of the skill is fixed.

---

## Phase 5: User Story 3 - Importer imports only real ADRs, with provenance (Priority: P2)

**Goal**: Filename blocklist + `source:` provenance field.
**Independent Test**: `README.md` in a scan dir is not imported; imported ADRs carry `source:`.

### Tests for User Story 3

- [x] T009 [US3] Add FR-009/010 assertions to `tests/check-migrate-adr.sh` (blocklist `README.md`/`CONTRIBUTING.md`, `source:` field); verify RED — plan Task 4 Steps 1–2

### Implementation for User Story 3

- [x] T010 [US3] Via `superpowers:writing-skills`, add the blocklist to Subagent A and `source:` to the imported-ADR frontmatter invariants in `skills/migrate-adr/SKILL.md`; verify GREEN; **full-suite gate (D1)**; commit — plan Task 4 Steps 3–5

**Checkpoint**: US3 complete and independently testable.

---

## Phase 6: User Story 4 - Discarded discoveries are not re-proposed on re-run (Priority: P2)

**Goal**: `.rejected` log for skipped discoveries; read into exclusion context; imported skips not logged.
**Independent Test**: Skip a discovered proposal, re-run discovery → it is not re-proposed.

### Tests for User Story 4

- [x] T011 [US4] Add FR-011/014 assertions to `tests/check-migrate-adr.sh` (`.rejected` path present, `bookkeeping` exemption noted); verify RED — plan Task 5 Steps 1–2

### Implementation for User Story 4

- [x] T012 [US4] Via `superpowers:writing-skills`, add discovered-skip→`.rejected` append (FR-011), imported-skip exclusion (FR-012), Iron-Rule exemption (FR-014) in Step 6, and `.rejected` read in Step 2 (FR-013) of `skills/migrate-adr/SKILL.md`; verify GREEN; **full-suite gate (D1)**; commit — plan Task 5 Steps 3–5

**Checkpoint**: US4 complete and independently testable.

---

## Phase 7: User Story 5 - Subagents return a defined contract informed by the constitution (Priority: P2)

**Goal**: Explicit return schema; constitution principles passed to Discoverer; `related_principles` populated.
**Independent Test**: Dispatch instructions show the schema; a constitution-related discovery populates `related_principles`.

### Tests for User Story 5

- [x] T013 [US5] Add FR-015/016 assertions to `tests/check-migrate-adr.sh` (`domain_label`, `source_path`, `related_principles`); verify RED — plan Task 6 Steps 1–2

### Implementation for User Story 5

- [x] T014 [US5] Via `superpowers:writing-skills`, add the return-schema block to Step 3 and constitution-principle passing + `related_principles` logic to Subagent B in `skills/migrate-adr/SKILL.md`; verify GREEN; **full-suite gate (D1)**; commit — plan Task 6 Steps 3–5

**Checkpoint**: US5 complete and independently testable.

---

## Phase 8: User Story 6 - Only significant decisions are proposed (Priority: P2)

**Goal**: Significance rubric in the Discoverer and in the `adr` skill description.
**Independent Test**: A formatter dependency is not proposed; a database decision is.

### Tests for User Story 6

- [x] T015 [US6] Add FR-017/018 assertions to `tests/check-migrate-adr.sh` (`costly to reverse` in both `migrate-adr` and `adr` SKILL.md); verify RED — plan Task 7 Steps 1–2

### Implementation for User Story 6

- [x] T016 [US6] Via `superpowers:writing-skills`, add the rubric to Subagent B in `skills/migrate-adr/SKILL.md` and rewrite the `description:` in `skills/adr/SKILL.md`; verify GREEN (incl. `check-frontmatter.sh`); **full-suite gate (D1)**; commit — plan Task 7 Steps 3–5

**Checkpoint**: US6 complete; `adr` frontmatter still valid.

---

## Phase 9: User Story 7 - Polish: git flag, honest table, single README regen (Priority: P3)

**Goal**: `git log -n 200`; row-index summary table; one README regen at loop end.
**Independent Test**: Skill text shows `git log -n 200`, no `(t)` tentative numbers, single regen.

### Tests for User Story 7

- [ ] T017 [US7] Add FR-019..021 assertions to `tests/check-migrate-adr.sh` (`git log -n 200` present + old flag gone, `(t) = tentative` gone + write-time note, "regenerate … once"); verify RED — plan Task 8 Steps 1–2

### Implementation for User Story 7

- [ ] T018 [US7] Via `superpowers:writing-skills`, fix the git command, Step 5 table/legend, and Step 6 README-regen wording in `skills/migrate-adr/SKILL.md`; verify GREEN; **full-suite gate (D1)**; commit — plan Task 8 Steps 3–5

**Checkpoint**: US7 complete and independently testable.

---

## Phase 10: User Story 8 - Docs: authoring flow + constitution decoupling (Priority: P3)

**Goal**: CLAUDE.md documents brainstorm→spec→plan→writing-skills; constitution no longer references CLAUDE.md (v1.2.0 + amendment ADR).
**Independent Test**: CLAUDE.md shows the 4-step flow; constitution has no CLAUDE.md/RGR reference and version > 1.1.0; an amendment ADR exists.

### Tests for User Story 8

- [ ] T019 [US8] Add FR-022 assertions to `tests/check-migrate-adr.sh` (CLAUDE.md has `brainstorm`+`writing-skills`, old `RED: run pressure scenario WITHOUT skill` gone); verify RED — plan Task 9 Steps 1–2
- [ ] T020 [US8] Add FR-024/025 assertions to `tests/check-migrate-adr.sh` (constitution: no `RED/GREEN/REFACTOR`, no `CLAUDE.md`, not `version: "1.1.0"`); verify RED — plan Task 10 Steps 1–2

### Implementation for User Story 8

- [ ] T021 [P] [US8] Edit `CLAUDE.md` "Developing New Skills" section to the 4-step flow (FR-022); verify GREEN; **full-suite gate (D1)**; commit — plan Task 9 Steps 3–5
- [ ] T022 [P] [US8] Edit `docs/maxi/constitution.md` Contributor Workflow (drop CLAUDE.md/RGR ref, FR-024) + bump `version`→1.2.0 / `last_amended`→2026-05-29 (FR-025); invoke `/maxi:adr` for "Constitution decoupled from CLAUDE.md (one-way dependency)"; verify GREEN; **full-suite gate (D1)**; commit — plan Task 10 Steps 3–7

**Checkpoint**: US8 complete; constitution amended with consenting ADR.

---

## Phase 11: Polish & Cross-Cutting Concerns

**Purpose**: Preservation guarantee and full-suite verification across all stories.

- [ ] T023 Add FR-023 preservation assertions to `tests/check-migrate-adr.sh` (Subagent A, Subagent B, Nygard tables still present); run and verify PASS — plan Task 11 Step 1
- [ ] T024 Run `bash tests/run-all.sh`; confirm `All fast checks passed.` incl. `check-frontmatter.sh`, `check-skills-present.sh`, `check-sync-invariant.sh` (SC-005) — plan Task 11 Step 2
- [ ] T025 Run `bash tests/run-all.sh --integration`; if migrate-adr behavior is uncovered, log it (do not silently skip) — plan Task 11 Step 3
- [ ] T026 Spec-coverage sanity pass (SC-001..004 mapped to assertions; note any manual-verification items); final commit if fixups — **full-suite gate (D1)** before commit — plan Task 11 Steps 4–5

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories (every story extends the registered check).
- **User Stories (Phases 3–10)**: All depend on Phase 2. They share `tests/check-migrate-adr.sh` and (US1–US7) `skills/migrate-adr/SKILL.md`, so they run **sequentially in priority order** (P1 → P1 → P2… → P3).
- **Polish (Phase 11)**: Depends on all stories complete.

### Within Each User Story

- The assertion task (RED) MUST be written and fail before the implementation task.
- Implementation makes assertions GREEN; then the **full fast tier must pass (D1)**; then commit.

### Parallel Opportunities

- **T021** (CLAUDE.md) and **T022** (constitution.md) touch unique files and carry `[P]` — once their assertion tasks (T019, T020) are committed, the two edits can proceed independently of each other.
- No other `[P]`: test tasks all write `tests/check-migrate-adr.sh`; US1–US7 impl tasks all write `skills/migrate-adr/SKILL.md`.

### Commit Ordering & D1

- At each commit, `tests/check-migrate-adr.sh` contains assertions only for work already implemented (assertions are added per-task immediately before their implementation), so the full `bash tests/run-all.sh` is green at every commit. No future-assertion failures.

### Implementation Strategy

- **MVP**: Phases 1–3 (US1). But US2 is also P1 — ship both P1 stories (Phases 3–4) before declaring the correctness fix done.
- **Incremental**: each subsequent story (P2, then P3) adds value and is independently testable at its checkpoint.

---

## Notes

- `[P]` = different files, no dependencies (only T021/T022 here).
- `[USN]` maps each task to a spec user story for traceability.
- Verify RED before each edit; run the full fast tier green (D1); commit after each story.
- The constitution-amendment ADR (T022) is written only with user consent via `/maxi:adr`.
