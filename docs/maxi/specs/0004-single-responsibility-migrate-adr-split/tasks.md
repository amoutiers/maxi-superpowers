---
slug: 0004-single-responsibility-migrate-adr-split
spec_slug: 0004-single-responsibility-migrate-adr-split
created: 2026-05-30
updated: 2026-05-30
---

# Tasks: Single-Responsibility principle + migrate-adr decomposition

**Input**: Design documents from `docs/maxi/specs/0004-single-responsibility-migrate-adr-split/`
**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Tests**: Test-first per `superpowers:test-driven-development`. The migrate-adr invariant suite (`tests/check-migrate-adr.sh`) is the safety net — repoint assertions to the new file (RED) before moving content (GREEN).

**Method constraints (from plan.md header):** skill/brief edits via `superpowers:writing-skills`; the constitution amendment via `/maxi:constitution`; its ADR via `/maxi:x-adr`; `bash tests/run-all.sh` green before every commit; commits consent-gated.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: `US1` (principle) · `US2` (decomposition) · `US3` (boundary enforcement)

---

## Phase 1: Setup

**Purpose**: Establish a clean, green starting point.

- [x] T001 Confirm a clean baseline: on a feature branch, run `bash tests/run-all.sh` and verify all 14 fast checks pass before any change.

**Checkpoint**: Baseline green — foundational phase can begin.

---

## Phase 2: Foundational ⚠️ BLOCKS ALL USER STORIES

**Purpose**: Isolated workspace so all story commits land cleanly.

**⚠️ CRITICAL**: No user-story work commits until this is done.

- [x] T002 Create a working branch for spec 0004 off `master` (e.g., `git switch -c fix/0004-srp-migrate-adr`).

**Checkpoint**: Branch ready — user-story phases can begin.

---

## Phase 3: User Story 1 - Codify single-responsibility as a project principle (Priority: P1) 🎯 MVP

**Goal**: A durable constitution principle that every skill owns one responsibility, recorded as an amendment ADR, with CLAUDE.md pointing to it (no duplication).

**Independent Test**: Read `docs/maxi/constitution.md` — Principle VI present with litmus, `version` is 1.3.0; an adoption ADR exists under `docs/maxi/adr/`; `CLAUDE.md` references the principle.

### Implementation for User Story 1

- [x] T003 [US1] Add Core Principle VI ("Single Responsibility per Skill" + litmus) to `docs/maxi/constitution.md` via `/maxi:constitution`; in the same write bump `version: "1.2.0"`→`"1.3.0"`, set `updated: 2026-05-30`, and update the footer line. (plan Task 1, Steps 1–2)
- [x] T004 [US1] Record the adoption ADR "Adopt Single-Responsibility principle for skills" via `/maxi:x-adr` → `docs/maxi/adr/NNNN-single-responsibility-per-skill.md` (drivers: governance, prevent concern-fusion, testability-in-isolation). On consent it also records the deferred decomposition-approach ADR. (plan Task 1, Step 3 + plan Decisions)
- [x] T005 [P] [US1] Add a one-line pointer to Principle VI in the **Developing New Skills** section of `CLAUDE.md` — pointer only, no duplicated principle text. (plan Task 1, Step 4)
- [x] T006 [US1] Verify US1: `grep "Single Responsibility per Skill" docs/maxi/constitution.md`, `grep '^version: "1.3.0"'`, ADR file exists, `grep "Principle VI" CLAUDE.md`; run `bash tests/run-all.sh` (existing `version: "1.1.0"` absence check still passes at 1.3.0). (plan Task 1, Steps 2,5)

**Checkpoint**: 🎯 MVP — single-responsibility is now a project principle, independently verifiable.

---

## Phase 4: User Story 2 - Decompose migrate-adr into orchestrator + per-source briefs (Priority: P1)

**Goal**: Move the Importer and Discoverer briefs out of `SKILL.md` into their own files; `SKILL.md` keeps only orchestration. Behavior-preserving.

**Independent Test**: `skills/migrate-adr/` has `SKILL.md` (orchestration only), `import-subagent.md`, `discover-subagent.md`; `/maxi:migrate-adr` produces identical proposals/dedup/consent/writes.

### Importer extraction (TDD)

- [x] T007 [US2] In `tests/check-migrate-adr.sh`, add `IMPORT="$ROOT/skills/migrate-adr/import-subagent.md"` and repoint the importer-content assertions (`blocklist`, `CONTRIBUTING.md`, `source:`, `Nygard`) from `$MIGRATE` to `$IMPORT`; run the check and confirm it FAILS (file missing). (plan Task 2, Steps 1–2 — RED)
- [x] T008 [US2] Create `skills/migrate-adr/import-subagent.md` via `superpowers:writing-skills`: move `SKILL.md` lines 132–200 (`### Subagent A — Importer` → frontmatter-invariants block) verbatim, with a brief header. Preserve strings: `blocklist`, `CONTRIBUTING.md`, `source:`, `Nygard`, `**Nygard → maxi mapping:**`. Re-run check: `$IMPORT` greps PASS. (plan Task 2, Steps 3–4 — GREEN part 1)
- [x] T009 [US2] Via `superpowers:writing-skills`, replace the inlined `### Subagent A — Importer` section in `SKILL.md` Step 3 with a one-line reference to `import-subagent.md` (keep the Return schema + exclusion wiring + `Subagent A` label). Run `bash tests/check-migrate-adr.sh && bash tests/run-all.sh` → green. (plan Task 2, Steps 5–6 — GREEN part 2)

### Discoverer extraction (TDD)

- [x] T010 [US2] In `tests/check-migrate-adr.sh`, add `DISCOVER="$ROOT/skills/migrate-adr/discover-subagent.md"` and repoint the discoverer-content assertions (`costly to reverse`, `git log -n 200`, and the `git log -200` removal check) from `$MIGRATE` to `$DISCOVER` (leave the `$ADR` "costly to reverse" check untouched). Run check → FAILS (file missing). (plan Task 3, Steps 1–2 — RED)
- [x] T011 [US2] Create `skills/migrate-adr/discover-subagent.md` via `superpowers:writing-skills`: move `SKILL.md` lines 202–232 (`### Subagent B — Discoverer` → default-frontmatter block) verbatim, with a brief header. Preserve `costly to reverse`, `Significance rubric`, `git log -n 200`; do not reintroduce `git log -200`. Re-run check: `$DISCOVER` greps PASS. (plan Task 3, Steps 3–4 — GREEN part 1)
- [x] T012 [US2] Via `superpowers:writing-skills`, replace the inlined `### Subagent B — Discoverer` section in `SKILL.md` Step 3 with a one-line reference to `discover-subagent.md` (still passing exclusion context + constitution principles). Run `bash tests/check-migrate-adr.sh && bash tests/run-all.sh` → green. (plan Task 3, Steps 5–6 — GREEN part 2)

### Finalize orchestrator

- [x] T013 [US2] Confirm `SKILL.md` now holds only coordination (Iron Rule, exclusion matching, dispatch+Return schema, dedup, summary, consent gate, guards); behavior-preservation diff review (`git diff` of `skills/migrate-adr/`) — no change to consent verbs, dedup rule, exclusion algorithm, `--import-only`, NNNN-at-write-time, or single README regen. (plan Task 4, Steps 1–2)

**Checkpoint**: User Story 2 complete — `migrate-adr` decomposed, behavior identical.

---

## Phase 5: User Story 3 - Enforce the single-responsibility boundary in tests (Priority: P2)

**Goal**: Machine-enforce the boundary so a future edit can't silently re-inline a brief into `SKILL.md`.

**Independent Test**: `tests/check-migrate-adr.sh` fails if importer/discoverer signature content returns to `SKILL.md`; passes when each lives only in its brief.

### Implementation for User Story 3

- [x] T014 [US3] Add SRP-boundary assertions to `tests/check-migrate-adr.sh`: `assert_file_exists` for both briefs; `assert_grep "$MIGRATE" "import-subagent.md"` and `"discover-subagent.md"` (orchestrator references both); `assert_not_grep "$MIGRATE" "Nygard → maxi mapping"` and `assert_not_grep "$MIGRATE" "Significance rubric"` (detail not in orchestrator). (plan Task 2 Step 1 / Task 3 Step 1 — boundary lines)
- [x] T015 [US3] Run `bash tests/check-migrate-adr.sh` and confirm the boundary assertions PASS; prove they bite by temporarily re-inlining `**Nygard → maxi mapping:**` into `SKILL.md` (expect FAIL) then reverting; run `bash tests/run-all.sh` → green. (plan Task 4, Step 4 + boundary intent)

**Checkpoint**: User Story 3 complete — SRP boundary regression-proofed.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final gates and branch completion.

- [x] T016 Re-run the Constitution Check gate for Principle VI against `migrate-adr`: three files, one responsibility each, orchestrator coordinates; confirm `check-skills-present.sh` still green (no skill-count change). (plan Task 4, Step 3)
- [x] T017 [P] Run `bash tests/run-all.sh` (14 checks green); optionally `bash tests/run-all.sh --integration` for the skill change. (plan Task 4, Step 4)
- [x] T018 Stage `spec.md`, `plan.md`, `tasks.md`, and all changes; complete the branch via `superpowers:finishing-a-development-branch` (commits/PR are consent-gated). (plan commit steps T1 S6, T2 S7, T3 S7, T4 S5)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: after Setup — blocks committing any story.
- **US1 (Phase 3)** and **US2 (Phase 4)**: both depend only on Phase 2 and touch **disjoint files** (constitution/CLAUDE.md/adr vs SKILL.md/briefs/test) — they may proceed in either order or in parallel sessions.
- **US3 (Phase 5)**: depends on **US2** (the briefs must exist before the boundary can be enforced).
- **Polish (Phase 6)**: after all desired stories.

### Within Each Story

- **US1**: T003 → T004 (ADR references the new principle) ; T005 is parallel-safe ; T006 verifies last.
- **US2 — strictly sequential** (importer and discoverer both edit `SKILL.md` and `check-migrate-adr.sh`, so they cannot run in parallel): T007 → T008 → T009 (importer) → T010 → T011 → T012 (discoverer) → T013 (finalize). Each test repoint (RED) precedes its content move (GREEN).
- **US3**: T014 → T015.

### Parallel Opportunities

- **T005** (CLAUDE.md pointer) is the only intra-phase `[P]` task — it shares no file with T003/T004.
- **Whole-phase parallelism**: US1 (Phase 3) can run concurrently with US2 (Phase 4) in separate sessions (disjoint files); commits still serialize on the branch.
- This feature is otherwise **mostly sequential** by design — the decomposition and its tests repeatedly touch the same `SKILL.md` and `check-migrate-adr.sh`, so `[P]` does not apply within Phases 4–5.

---

## Implementation Strategy

### MVP First (User Story 1)

1. Phase 1 Setup → Phase 2 Foundational → Phase 3 (US1).
2. **STOP and VALIDATE**: principle present, version 1.3.0, ADR written, CLAUDE.md pointer — independently verifiable.

### Incremental Delivery

1. Setup + Foundational → ready.
2. US1 (principle) → validate → MVP.
3. US2 (decomposition) → validate behavior identical.
4. US3 (boundary enforcement) → validate the guard bites.
5. Polish → full suite + branch completion.

## Notes

- `[P]` = different files, no dependencies (only T005 here).
- Each story is independently testable; US3 builds on US2.
- TDD: every test repoint FAILS before the matching content move.
- Commit after each task or logical group (consent-gated).
- Behavior-preservation for `migrate-adr` is verified by the repointed invariant suite, not by re-specifying behavior.
