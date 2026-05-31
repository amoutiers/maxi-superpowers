---
slug: 0018-artifact-cross-reference-conventions
spec_slug: 0018-artifact-cross-reference-conventions
created: 2026-05-31
updated: 2026-05-31
---

# Tasks: Artifact cross-reference conventions — direction and link form

> **Filled in by `/maxi:tasks`.** Extracted from `plan.md`.

**Input**: `docs/maxi/specs/0018-artifact-cross-reference-conventions/plan.md` + `spec.md`
**Prerequisites**: plan.md (required), spec.md (required for user stories). No research.md / data-model.md / contracts/.

**Tests**: This is a markdown/bash-instruction change. "Tests" here are the bash fast-tier assertions (`tests/check-templates.sh`, `tests/check-migrate-adr.sh`). Schema tasks follow RED→GREEN: assert the new shape first, watch it fail, then edit the template/fixture to pass.

**⚠️ Authoring constraint**: every task that edits a `SKILL.md` is tagged **[writing-skills]** — it MUST be authored via `superpowers:writing-skills` (its own RED/GREEN/REFACTOR cycle), never hand-edited (CLAUDE.md / Constitution Contributor Workflow). Templates, support briefs, bash tests, ADR/spec markdown, and docs are edited directly.

**Organization**: Tasks grouped by user story. Several tasks edit the same file (`skills/x-adr/SKILL.md` is touched by US1, US2, US4; the link convention re-touches every skill) — those carry no `[P]` and are ordered by the dependency notes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: different files, no dependency → safe to parallelize
- **[Story]**: maps to a spec.md user story (US1–US6)

## Path Conventions

Flat markdown/bash repo. Paths are repo-root-relative (`skills/…`, `tests/…`, `docs/maxi/…`). No `src/`.

---

## Phase 1: Setup

**Purpose**: Establish a green baseline so every later RED/GREEN step is meaningful.

- [x] T001 Run `bash tests/run-all.sh` and confirm the fast tier is green before any change.

**Checkpoint**: Baseline green — foundational phase can begin.

---

## Phase 2: Foundational ⚠️ BLOCKS ALL USER STORIES

**Purpose**: The ADR + spec schema and their test guards. Every producer, the read side, and the data migration depend on the schema being settled first.

**⚠️ CRITICAL**: No user-story work begins until both schema changes are in and tests are green.

- [x] T002 ADR schema loses the three cross-ref fields (plan Task 1). In `tests/check-templates.sh` remove `related_specs:`/`related_principles:`/`related_requirements:` from the `adr-template.md` and `fixtures/sample-adr.md` field lists and add `assert_not_grep` absence assertions for all three on both files (RED); run `bash tests/check-templates.sh` to see it fail; then delete those three lines from `skills/x-adr/adr-template.md` and `tests/fixtures/sample-adr.md` (GREEN). Files: `tests/check-templates.sh`, `skills/x-adr/adr-template.md`, `tests/fixtures/sample-adr.md`.
- [x] T003 Spec schema gains `related_adrs` (plan Task 2). Add `"related_adrs:"` to the `spec-template` field list in `tests/check-templates.sh` (RED, direct); run it to fail; add `related_adrs: []` to `skills/specify/spec-template.md` frontmatter (direct edit — template, not SKILL.md) and to the `/maxi:specify` Step-5 frontmatter block in `skills/specify/SKILL.md` **[writing-skills]** (GREEN). Files: `tests/check-templates.sh`, `skills/specify/spec-template.md`, `skills/specify/SKILL.md`. (Shares `check-templates.sh` with T002 → run after T002.)

**Checkpoint**: Both schemas settled, `tests/check-templates.sh` green — user stories can begin.

---

## Phase 3: User Story 1 - ADR is a self-contained record (Priority: P1) 🎯 MVP

**Goal**: The ADR carries only genre-native metadata; `x-adr` no longer writes the three fields.

**Independent Test**: A newly drafted ADR's frontmatter has no `related_*` fields; `tests/check-templates.sh` passes.

- [x] T004 [US1] **[writing-skills]** `x-adr` stops writing the three fields (plan Task 3): in `skills/x-adr/SKILL.md` Step 3 delete the three field-fill bullets; reword the Decision Drivers derivation to cite principles/requirements as inline prose without the field names; remove the three fields from the append-only list (line ~172). File: `skills/x-adr/SKILL.md`.

**Checkpoint** 🎯 MVP: ADR schema is self-contained and its sole writer (`x-adr`) is aligned — independently testable.

---

## Phase 4: User Story 2 - Traceability lives on the spec (Priority: P1)

**Goal**: `x-adr` records the spec→ADR link in the spec's `related_adrs` on acceptance.

**Independent Test**: Accepting an ADR while a spec is active appends its slug to that spec's `related_adrs` and bumps `updated:`.

- [x] T005 [US2] **[writing-skills]** `x-adr` writes the spec back-link on acceptance (plan Task 4): in `skills/x-adr/SKILL.md` Step 6 (`yes` handling, both normal + supersede cases) add a sub-step appending the ADR's full slug to the active spec's `related_adrs` and bumping the spec's `updated:`; add the no-active-spec skip and a Common-Mistakes row. File: `skills/x-adr/SKILL.md`. (Shares file with T004 → run after T004.)

**Checkpoint**: Spec-side traceability is written automatically — US1 + US2 both functional.

---

## Phase 5: User Story 3 - Analyze reads the corrected direction (Priority: P1)

**Goal**: `analyze` Pass G builds its registry from `related_adrs`, not `ADR.related_specs`.

**Independent Test**: G1 fires on a tech choice with no spec-referenced ADR; G3 fires on a superseded-ADR reference — both spec-side.

- [x] T006 [P] [US3] **[writing-skills]** Re-point `analyze` Pass G (plan Task 7): in `skills/analyze/SKILL.md` edit Step 2 (drop `related_specs, related_principles` from the ADR load), Step 3 (build the spec↔ADR map from `related_adrs` + inline `ADR-NNNN`, never reading `related_specs`), and G1 (reformulate as "spec references no accepted ADR for the choice"). File: `skills/analyze/SKILL.md`.

**Checkpoint**: The only machine consumer reads the spec side — audit capability preserved.

---

## Phase 6: User Story 4 - Existing ADRs and specs migrated (Priority: P2)

**Goal**: Strip the three fields from the existing ADR corpus; preserve the prior links spec-side; rebuild the index.

**Independent Test**: `grep` over `docs/maxi/adr/` returns zero removed-field frontmatter; the 6 specs list their ADR slugs; the README index column matches.

- [x] T007 [US4] **[writing-skills]** `x-adr` README index by reverse-lookup (plan Task 6, FR-022): rewrite `skills/x-adr/SKILL.md` Step 7 so the "Related Specs" column is built by scanning every `docs/maxi/specs/*/spec.md` `related_adrs` and inverting the map. File: `skills/x-adr/SKILL.md`. (Shares file with T004/T005 → run after them.)
- [x] T008 [P] [US4] Strip the three frontmatter fields from `docs/maxi/adr/0001`–`0011` **and** the correction `0012-traceability-direction-spec-to-adr.md` (plan Task 8); leave all body prose untouched (ADR-0003's `(related_requirements: FR-025)` stays). Files: `docs/maxi/adr/00*.md`.
- [x] T009 [P] [US4] Write `related_adrs` back-links (plan Task 9): add the mapped ADR slugs to `0001-design-review-fixes`, `0002-migrate-adr-review-fixes`, `0004-single-responsibility-migrate-adr-split`, `0005-migrate-from-brownfield`, and add `["0012-traceability-direction-spec-to-adr"]` to this feature's own `0018-artifact-cross-reference-conventions/spec.md`; bump each `updated:`. Files: `docs/maxi/specs/000{1,2,4,5}-*/spec.md`, `docs/maxi/specs/0018-*/spec.md`.
- [x] T010 [US4] Regenerate `docs/maxi/adr/README.md` so the Related Specs column reflects the spec-side reverse-lookup (0001→0001, 0002→0001, 0003→0002, 0009&0010→0004, 0011→0005, 0012→0018, rest `—`) (plan Task 11, FR-022). File: `docs/maxi/adr/README.md`. (Depends on T007 logic + T008 + T009 data.)

**Checkpoint**: Existing corpus migrated, no traceability lost, index consistent.

---

## Phase 7: User Story 5 - Producers stop writing; FR-016/017 reconciled (Priority: P2)

**Goal**: `migrate-adr` stops emitting the fields; the superseded `related_principles` requirement is reconciled and its test guard dropped.

**Independent Test**: No removed-field reference remains in `skills/migrate-adr/`; `tests/check-migrate-adr.sh` passes with no `related_principles`-related assertion.

- [x] T011 [P] [US5] **[writing-skills]** `migrate-adr` stops emitting the fields (plan Task 5): in a single `writing-skills` session for `migrate-adr`, remove the "pass the constitution's principles to the Discoverer" instruction from `skills/migrate-adr/SKILL.md` and (within that session) delete the constitution-linkage paragraph + field lines from the `discover-subagent.md` support brief and the field lines from `import-subagent.md`. Files: `skills/migrate-adr/{SKILL.md,discover-subagent.md,import-subagent.md}`.
- [x] T012 [US5] Linked supersession notes (plan Task 10): add a `> Superseded by [0018-artifact-cross-reference-conventions/spec](…)` note under FR-016 in `docs/maxi/specs/0002-migrate-adr-review-fixes/spec.md` and under FR-017 in `docs/maxi/specs/0016-migrate-adr/spec.md`; bump both `updated:`; do not change `status`. Files: `docs/maxi/specs/0002-migrate-adr-review-fixes/spec.md`, `docs/maxi/specs/0016-migrate-adr/spec.md`. (Shares `0002-…/spec.md` with T009 → run after T009.)
- [x] T013 [P] [US5] Drop the FR-016 guard (plan Task 12): delete the `assert_grep "$MIGRATE" "constitution's principles"` line (≈47) in `tests/check-migrate-adr.sh`; verify no other assertion references a removed field; run `bash tests/check-migrate-adr.sh` green. File: `tests/check-migrate-adr.sh`.

**Checkpoint**: No producer writes a removed field; FR-016/017 reconciled; migrate-adr suite green.

---

## Phase 8: User Story 6 - Artifact references are clickable everywhere (Priority: P2)

**Goal**: Every reference-emitting maxi skill renders relative Markdown links (forward-only).

**Independent Test**: The "Artifact reference links" guidance block is present in all 12 skills.

- [x] T014 [US6] **[writing-skills]** Add the canonical Link rendering convention block (visible text = filename without `.md`; feature-dir-prefixed for generic spec artifacts; data + within-doc IDs exempt; forward-only) to each `SKILL.md` (plan Task 13): `x-adr`, `analyze`, `board`, `plan`, `tasks`, `specify`, `clarify`, `revise`, `migrate-adr`, `migrate-from-speckit`, `migrate-from-brownfield`, `constitution`. Files: `skills/*/SKILL.md` (12). (Re-touches `x-adr`/`analyze`/`migrate-adr`/`specify` SKILL.md edited earlier → run after T004–T011. No `[P]`.)

**Checkpoint**: Link convention live across the skill surface.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Doc-sync and whole-suite verification.

- [x] T015 [P] Doc-sync (plan Task 14): note `related_adrs` + the slimmed ADR schema in `CLAUDE.md` Artifact Convention and in `docs/architecture.md` (ADR section + spec-frontmatter section). Files: `CLAUDE.md`, `docs/architecture.md`. (Five-file rule does not fire — no gating/FSM change; `using-maxi`/`pipeline-flow`/`delegation-map` unaffected.)
- [x] T016 Verification (plan Task 15): `bash tests/run-all.sh` green (SC-004); `grep` confirms zero removed-field ADR frontmatter (SC-001); the 6 prior links present spec-side (SC-002); link block in 12 skills (SC-005). Manually confirm SC-003 (analyze G1/G3 behavior-preserving via the spec-side registry). File: none (verification).

**Checkpoint**: All success criteria green; SC-003 manually confirmed.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (P1)**: none.
- **Foundational (P2)**: after Setup. Blocks all stories. T003 after T002 (shared `check-templates.sh`).
- **US1 (P3)** → **US2 (P4)** → **US4 T007 (P6)**: strictly sequential — all edit `skills/x-adr/SKILL.md`.
- **US3 (P5)**: independent (`analyze/SKILL.md`) — may run in parallel with the x-adr chain.
- **US4 (P6)**: T008/T009 parallel (different files); T010 after T007+T008+T009.
- **US5 (P7)**: T011/T013 parallel; T012 after T009 (shared `0002-…/spec.md`).
- **US6 (P8)**: T014 after every other skill edit (re-touches shared SKILL.md files).
- **Polish (P9)**: T015 anytime after schema; T016 last.

### Within Each User Story

- Schema tasks: assert-then-edit (RED→GREEN). Producers before the data migration that relies on their new behavior. Test guard (T013) dropped only after the behavior it guarded is gone (T011).

### Parallel Opportunities

- `[P]` tasks touch disjoint files: **T006** (analyze) ∥ the x-adr chain; **T008** (adr corpus) ∥ **T009** (specs); **T011** (migrate-adr) ∥ **T013** (migrate-adr test) ∥ **T015** (docs).
- Conflicts (NOT parallel): T002/T003 share `check-templates.sh`; T004/T005/T007/T014 share `x-adr/SKILL.md`; T009/T012 share `0002-…/spec.md`; T014 shares files with T004/T005/T006/T007/T011.

---

## Notes

- `[P]` = different files, no dependency. `[Story]` maps to a spec user story.
- Commit after each task or logical group; keep `bash tests/run-all.sh` green at every commit (constitution: fast-tier mandatory).
- The correction ADR `0012-traceability-direction-spec-to-adr` already exists (captured at plan time under the old schema); T008 strips its three fields and T009 records it in spec 0018's `related_adrs`.
- Two spec gaps surfaced in planning are tasked here: README reverse-lookup (T007/T010, now governed by **FR-022**) and the FR-016 guard being `"constitution's principles"` (T013).
- **[writing-skills] tasks** (T003 partial, T004, T005, T006, T007, T011, T014) edit `SKILL.md` files and MUST be authored via `superpowers:writing-skills`, not hand-edited. T014 spans 12 skills — expect one `writing-skills` session per skill (the link-convention block is identical, but each skill is authored through its own session).
