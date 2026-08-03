---
slug: 0019-artifact-analysis-convergence
spec_slug: 0019-artifact-analysis-convergence
created: 2026-08-03
updated: 2026-08-03
---

# Tasks: Bounded Minimal Replay

**Input**: [plan](plan.md), [spec](spec.md), and the accepted ADRs under [../../adr/](../../adr/)
**Prerequisites**: `plan.md` and `spec.md`; pre-existing `research.md`, `data-model.md`, and `contracts/` describe the superseded scope and are not inputs to this extraction.

**Tests**: Every implementation task starts with RED coverage and proves GREEN with the exact commands in [plan](plan.md). All `SKILL.md` changes use `superpowers:writing-skills`.

**Organization**: Tasks follow plan order because they share fixture and skill surfaces. Each completed task requires a fresh implementer, independent review, a fresh corrector for each finding batch, and re-review before it is checked.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the deterministic fixture boundary.

- [x] T001 Create `tests/check-bounded-replay.sh` and `tests/fixtures/bounded-replay/` with RED forward, review, legacy, malformed, cycle, and escape fixtures. (plan Task 1, Steps 1-3; covers US1, US2, US3, US4)

**Checkpoint**: Fixture runner fails because `skills/revise/replay-plan.sh` and `skills/x-review/` do not exist, while source fixtures remain unchanged after every attempted planner call.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Register the shared deterministic runner before later tasks depend on it.

**⚠️ CRITICAL**: No user-story implementation begins until this phase is complete.

- [x] T002 Register `tests/check-bounded-replay.sh` in `tests/run-all.sh` as deterministic fast-tier coverage, without an agentic integration scenario. (plan Task 2, Step 1; depends on T001)

**Checkpoint**: The RED runner is registered and remains the shared deterministic prerequisite for every user story.

---

## Phase 3: User Story 1 - See Current Document Versions (Priority: P1) 🎯 MVP

**Goal**: New forward-pipeline documents expose current revisions, authorship provenance, and direct input revisions without touching historical or migrated specs.

**Independent Test**: Create a forward fixture, verify revision 1 plus direct inputs on every owned document, structurally change one document, and verify only its revision changes while descendants become stale.

- [x] T003 [US1] Through `superpowers:writing-skills`, update `skills/specify/{SKILL.md,spec-template.md}`, `skills/plan/{SKILL.md,plan-template.md}`, `skills/tasks/{SKILL.md,tasks-template.md}`, and `skills/analyze/SKILL.md` so future forward-pipeline documents write revision, writer context, structural contributors, and exact direct inputs; extend `tests/check-templates.sh` and `tests/check-bounded-replay.sh`, preserving migration and reverse-engineering behavior. (plan Task 3; depends on T001, T002)

**Checkpoint**: `bash tests/check-templates.sh && bash tests/check-migrate-from-speckit.sh && bash tests/check-migrate-from-brownfield.sh` passes.

---

## Phase 4: User Story 4 - Require Independent Reviews at Handoffs (Priority: P1)

**Goal**: Persist external review evidence that is bound to the exact reviewed artifact and a harness-issued independent reviewer context.

**Independent Test**: Reject a self-review, unknown context, stale revision, or SHA-256 mismatch; accept only an approved matching external review record.

- [x] T004 [US4] Through `superpowers:writing-skills`, create `skills/x-review/{SKILL.md,review-template.md}` as the sole writer of versioned spec and plan review records; bind the vendored review checklist to an exact current-artifact envelope and harness-issued reviewer context; create `tests/check-x-review.sh`, then register the skill in `tests/check-skills-present.sh` and extend `tests/check-templates.sh` plus `tests/check-bounded-replay.sh`. (plan Task 4; depends on T001, T002, T003)

**Checkpoint**: `bash tests/check-x-review.sh && bash tests/check-skills-present.sh && bash tests/check-frontmatter.sh` passes, including envelope, SHA-256, context-binding, verdict, and review-record contributor checks. `tests/check-bounded-replay.sh` remains RED until T005 creates the planner.

---

## Phase 5: User Story 2 - Propose the Smallest Safe Replay (Priority: P1)

**Goal**: Detect only stale descendants and display the shortest executable continuation, stopping at a review handoff.

**Independent Test**: Mutate plan-only, tasks-only, support-document, and review-record fixtures; verify exact stale records, review boundaries, and no unaffected ancestors.

- [x] T005 [US2] Implement the read-only Bash 3.2 planner in `skills/revise/replay-plan.sh`; validate the confined supported graph, malformed metadata, disconnected cycles, and physical escapes; emit `CHANGED`, lexical `STALE`, `REVIEW_REQUIRED`, and dependency-ordered `REPLAY` records for producers and approved review records; make `tests/check-bounded-replay.sh` GREEN with source-digest no-write checks. (plan Task 5; depends on T001 through T004)

**Checkpoint**: `bash tests/check-bounded-replay.sh` exits 0 and prints `All bounded replay checks passed.`

---

## Phase 6: User Story 3 - Keep Replay Under User Control (Priority: P1)

**Goal**: Require literal consent for each executable replay segment and prevent automatic continuation through review handoffs.

**Independent Test**: Reject missing, stale, rejected, malformed, and self-reviewed evidence; confirm only literal `yes` runs the displayed segment and a matching review causes the remaining segment to be displayed before another consent.

- [x] T006 [US3] [US4] Through `superpowers:writing-skills`, update `skills/{clarify,plan,tasks,analyze,implement,revise}/SKILL.md` and `tests/check-bounded-replay.sh` so plan and tasks gate before any write, analyze records verified independence, implement rejects invalid analysis, replay pauses then asks for a new literal `yes` after each independent-review handoff, and one failed analysis after an approved replay starts no further correction or replay without a new explicit decision. Preserve the exceptional `specified` rollback, the unchanged FSM, and the prohibition on creating or writing `workflow.md` plus `.maxi-ops`. (plan Task 6; depends on T004, T005)

**Checkpoint**: `bash tests/check-bounded-replay.sh && bash tests/check-frontmatter.sh` passes.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Synchronize public pipeline guidance and complete deterministic verification.

- [ ] T007 Update `docs/pipeline-flow.md`, `docs/delegation-map.md`, `skills/using-maxi/SKILL.md`, `AGENTS.md`, `docs/architecture.md`, `README.md`, `tests/check-skill-count.sh`, `tests/check-skills-present.sh`, and `tests/run-all.sh` for the two review gates, unchanged FSM, read-only planner, `x-review`, `check-x-review.sh`, and skill count; run Mandatory Sync 5, `maxi:doc-consistency`, the deterministic suite, and a fresh independent whole-diff review; prepare only an explicit staging manifest. (plan Task 7; depends on T006)

**Checkpoint**: All commands from plan Task 7, Step 4 pass with terminal evidence, `maxi:doc-consistency` and the fresh independent whole-diff review are complete, findings are resolved and re-reviewed, and no file is staged or committed without fresh authorization.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1**: Starts immediately and creates the RED evidence used by all following phases.
- **Phase 2**: Depends on T001 and blocks every later task because it installs the shared fast-tier entry point.
- **Phase 3**: Depends on T001 and T002 because all later records consume the common metadata contract.
- **Phase 4**: Depends on T001 through T003 because review records require document provenance.
- **Phase 5**: Depends on T001 through T004 because the planner reads produced documents and review records.
- **Phase 6**: Depends on T004 and T005 because owners validate implemented review records and planner results.
- **Phase 7**: Depends on T006 because documentation must describe the completed gate behavior.

### User Story Coverage

- **US1**: T001, T003.
- **US2**: T001, T005.
- **US3**: T001, T006.
- **US4**: T001, T004, T006.

### Parallel Opportunities

None. T001 through T006 share `tests/check-bounded-replay.sh`, forward skill contracts, and the mandatory pipeline documentation. They require sequential implementation and independent review checkpoints.

## Implementation Strategy

1. Complete T001 and T002, then prove RED before creating any feature behavior.
2. Complete T003 through T006 one at a time with the assigned review and correction cycle.
3. Complete T007 only after all behavior is green, then run the documented deterministic suite and independent whole-diff review.
4. Request fresh staging and commit authorization only after T007.
