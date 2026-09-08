---
slug: 0025-convergent-design-workflow
spec_slug: 0025-convergent-design-workflow
created: 2026-09-08
updated: 2026-09-08
---

# Tasks: Convergent Initial Specs and Revisions

**Input**: [0025-convergent-design-workflow/plan](plan.md), [0025-convergent-design-workflow/spec](spec.md), and the approved [0025-convergent-design-workflow/design-review](reviews/design-review.md).

**Prerequisites**: The installed design verifier returned DESIGN_REVIEW_VERIFIED against the exact current inputs before extraction. Optional research, data-model, and contracts artifacts are absent and are not needed by the approved plan.

**Tests**: Each task includes its complete tests-first cycle from the mapped plan task. Native skill edits use superpowers:writing-skills and its RED/GREEN/REFACTOR process. A task is not complete merely because its instruction text was written.

**Organization**: Exactly three canonical tasks preserve the approved plan's deliverables. Shared story coverage is described below without duplicating tasks or inventing setup work.

## Format: `[ID] [P?] [Story] Description (plan Task N)`

- T001 through T003 identify the three executable deliverables.
- Each terminal mapping names exactly one complete source-plan task.
- Story labels identify primary ownership; shared acceptance coverage remains binding.
- No task is parallel: each depends on the preceding deliverable, and later tasks also share documentation and test files.

## Path Conventions

All implementation paths are relative to the repository root. The complete Files, Interfaces, implementation steps, and checks remain in the mapped plan task. File lists are primary edits, not allowlists.

## Phase 1: Setup (Shared Infrastructure)

The existing repository, shell test helpers, approval guards, and Codex integration infrastructure are reused. The plan defines no independent setup deliverable or new dependency.

**Checkpoint**: Existing infrastructure is identified; no additional canonical task is introduced.

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish report-local continuation and fail-closed reservation/publication before activating coordinated workflows. This implements the safety foundation of US3 and is inert until T002 uses it.

- [ ] T001 [US3] Guard review reservations and publication in skills/review/design-contract.sh with executable lifecycle, interruption, freshness, legacy-compatibility, alias, and locking scenarios in tests/check-design-operation.sh (plan Task 1)

**Checkpoint**: The new lifecycle scenarios and existing review/readiness contract checks pass. Do not activate coordination or commit a partial gating change before T002's synchronized update.

## Phase 3: User Story 1 - Revise Without Relaying Commands (Priority: P1)

**Goal**: Coordinate actual owner corrections and bounded design review; the same shared deliverable also implements US2 initial creation and US3 scope/lifecycle safeguards.

**Independent Test**: Run the mapped writing-skills pressure scenarios for clear revision, complete initial design, unresolved choices, and review-only scope. Verify owner writes and question/dispatch behavior, then run the fast suite and doc-consistency review.

- [ ] T002 [US1] Coordinate initial specs and revisions through skills/specify/SKILL.md, skills/clarify/SKILL.md, skills/revise/SKILL.md, skills/plan/SKILL.md, and skills/review/SKILL.md; add skills/specify/spec-author.md and skills/review/design-operation.md, update the reviewer/template and affected checks, and synchronize all five pipeline documents plus README.md (depends on T001) (plan Task 2)

**Checkpoint (MVP)**: Coordinated owner flows and bounded review behavior pass their pressure scenarios. T001, T002, and mandatory document synchronization form the coherent activation change; installed end-to-end proof remains T003.

## Phase 4: User Story 2 - Create a Spec Without Duplicate Elicitation (Priority: P1)

**Goal**: Reuse settled answers and design approval, produce one canonical clarified spec, and include planning only for the broader authorized destination.

US2 implementation is already owned by T002. Do not duplicate that source-plan mapping. T003 supplies installed-plugin coverage for spec-only creation, design validation, grouped independent questions, dependent follow-up, and duplicate-artifact exclusion.

**Checkpoint**: T002's initial-spec pressure cases pass; final runtime proof remains required before claiming the full feature works.

## Phase 5: User Story 3 - Preserve Scope, Evidence, and Lifecycle Safety (Priority: P1)

**Goal**: Prove the installed workflow respects destinations and preserves valid evidence; verify initial creation and revision behavior together.

**Independent Test**: Run deterministic transcript-checker negative cases and the authenticated initial, revision, and boundaries case groups, followed by the existing integration suite from a clean isolated implementation checkout.

- [ ] T003 [US3] Prove initial and revision behavior using tests/integration/run-codex-design-test.sh, tests/integration/assert-design-events.jq, and minimal tests/integration/design-cases fixtures; wire tests/integration/run-all.sh and tests/check-integration-harness.sh, update README.md and AGENTS.md integration guidance, and report baseline-versus-result measurements (depends on T001, T002) (plan Task 3)

**Checkpoint**: Runtime evidence covers US1, US2, and US3. Missing authentication, unknown event shapes, deadlines, or unverified reports are incomplete/failing evidence, never success.

## Phase 6: Polish & Cross-Cutting Concerns

Documentation synchronization and static checks belong to T002. Integration documentation, final checks, and measured reporting belong to T003. The approved plan defines no separate polish deliverable.

**Checkpoint**: All three tasks include their full verification; no deferred documentation or testing task is hidden outside the canonical list.

## Dependencies & Execution Order

- Execute T001, then T002, then T003.
- T001 supplies the guarded helper interfaces used by T002.
- T002 activates owner coordination and all mandatory documentation together; its pressure runs establish the behavioral baseline for T003.
- T003 consumes the changed installed skill snapshot and completes independent transcript/fixture verification for all stories.
- T002 and T003 share AGENTS.md and README.md. Dependencies also preclude parallel execution, so no [P] marker is appropriate.

## Implementation Strategy

1. Implement and test the report guard without activating it.
2. Apply native owner coordination, skill pressure testing, and mandatory document synchronization as one coherent activation change with the guard.
3. Verify the installed plugin and report user turns, review dispatches, duplicate artifacts, elapsed time, and unresolved blockers against the recorded baselines.

## Notes

- Completing extraction changes the spec to tasked; it does not claim implementation or authorize publication.
- Readiness analysis remains the next gate before implementation.
- Review evidence is consumed before this normal status transition. Do not restamp it or launch a redundant design review merely because extraction advanced the spec status.
