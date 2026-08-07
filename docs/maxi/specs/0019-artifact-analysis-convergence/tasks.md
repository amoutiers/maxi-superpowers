---
slug: 0019-artifact-analysis-convergence
spec_slug: 0019-artifact-analysis-convergence
created: 2026-08-03
updated: 2026-08-04
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

## Phase 7: Corrective Replay Contracts

**Purpose**: Close the global-review gaps without reopening completed ancestors.

- [x] T007 [US1] [US2] [US4] Add the exact `replay_contract: bounded-v1` eligibility marker only in future `/maxi:specify`; keep revision-bearing 0019 and all migrated/reverse-engineered specs unmarked and `UNSUPPORTED_LEGACY`. With `superpowers:test-driven-development` and `superpowers:writing-skills`, make `x-review`, `plan`, `tasks`, and `replay-plan.sh` share the canonical structural `reviewed_sha256` that excludes only root-frontmatter `status:`/`updated:`, enforce the exact ten-field x-review envelope in both owner gates, and reject every stray frontmatter list item outside the active contributor/derived block. Add RED first, prove the three checks fail for the intended gaps, implement without an executable review helper, then run every plan Task 7 GREEN command. Submit the Task 7 diff to a fresh read-only reviewer; any finding keeps T007 open, goes to a fresh corrector under the same TDD/writing-skills rules, and requires GREEN plus fresh independent re-review. (plan Task 7; depends on T006; covers FR-001, FR-003-FR-005, FR-012-FR-014, FR-017-FR-019, FR-021-FR-022, SC-001, SC-006-SC-008)

**Checkpoint**: T007 remains unchecked until its RED evidence is captured, all targeted checks plus migration checks, Bash syntax, and `git diff --check` pass, revision-bearing unmarked 0019 exits 4 without writes, canonical non-structural changes preserve review validity, structural changes invalidate it, both owner gates reject every incomplete envelope, stray list entries exit 2, and the independent re-review is clean.

---

## Phase 8: Persisted Spec-to-Tasks Continuation

**Purpose**: Make the full replay survive both review handoffs and reject stale ancestry.

- [x] T008 [US2] [US3] [US4] With `superpowers:test-driven-development` and `superpowers:writing-skills`, persist `clarify@<spec-revision>` on the exceptional source-spec rollback and resume it through the read-only `--resume-current-source` presenter; replace it with `plan@<current-spec-revision>` when `clarify` completes; make `x-review` display the post-spec-review `plan` continuation; and make `/maxi:plan` re-present it through `--resume-current-review` after rejection, ambiguity, or interruption. A consented replay plan write persists `tasks@<new-plan-revision>`, stops for plan review, and continues through `/maxi:tasks` only after a second independent review and fresh literal `yes`. Extend `replay-plan.sh` so only the exact source and review resume combinations are accepted and plan resume rejects a stale spec, support artifact, or spec review before emitting any continuation. Add the exact end-to-end and stale-ancestor RED cases first, prove the intended failures, implement without a new coordinator/helper/status, then run the plan Task 8 GREEN commands. Submit the complete Task 8 diff to a fresh read-only reviewer; route every finding batch to a fresh corrector, rerun GREEN, and obtain fresh independent re-review before checking T008. (plan Task 8; depends on T007; covers FR-003, FR-005-FR-009, FR-011, FR-013-FR-016, FR-018-FR-019, FR-021-FR-023, SC-002-SC-004, SC-007-SC-008)

**Checkpoint**: T008 remains unchecked until the deterministic scenario resumes `clarify` and reaches tasks through `spec review -> plan -> plan review -> tasks`, all three presenter branches survive rejection/non-`yes`/fresh-session interruption without writes, plan resume rejects every stale ancestor, targeted tests and syntax checks pass, `git diff --check` is clean, and independent re-review has no open finding.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Synchronize public pipeline guidance and complete deterministic verification.

- [x] T009 Update Mandatory Sync 5, `README.md`, and deterministic inventories for the exact Task 7/8 contracts: future-only eligibility marker, structural review digest, complete owner envelope, persisted spec-review/plan-review continuation, stale-ancestor rejection, unchanged FSM, read-only planner, and existing correction statuses. Run the plan Task 9 deterministic sequence and `maxi:doc-consistency`, then obtain a fresh whole-feature review against Base `8257869e22edbc0e81dd5aa6cf1d89768b1cf5f7` covering all six findings and the explicit staging manifest. Fix and re-review every finding before checking T009. If integration is attempted again and repeats, record exactly `Passed: 0 / 13` and `--- FAIL: Integration tier`, report failure, and do not retry. Prepare the manifest only; do not stage, commit, or push. (plan Task 9; depends on T008)

**Checkpoint**: All plan Task 9 commands pass with terminal evidence, `maxi:doc-consistency` is clean, the fresh whole-feature reviewer approves all six repairs after any required correction/re-review, integration is reported exactly if attempted, and no file is staged or committed without fresh authorization.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1**: Starts immediately and creates the RED evidence used by all following phases.
- **Phase 2**: Depends on T001 and blocks every later task because it installs the shared fast-tier entry point.
- **Phase 3**: Depends on T001 and T002 because all later records consume the common metadata contract.
- **Phase 4**: Depends on T001 through T003 because review records require document provenance.
- **Phase 5**: Depends on T001 through T004 because the planner reads produced documents and review records.
- **Phase 6**: Depends on T004 and T005 because owners validate implemented review records and planner results.
- **Phase 7**: Depends on T006 and establishes the strict applicability, digest, review-envelope, and parser boundary.
- **Phase 8**: Depends on T007 because persisted replay relies on its marker and full review validation.
- **Phase 9**: Depends on T008 because documentation and whole-feature review must follow completed behavior.

### User Story Coverage

- **US1**: T001, T003.
- **US2**: T001, T005.
- **US3**: T001, T006.
- **US4**: T001, T004, T006.
- **US1/US4 corrections**: T007 closes eligibility, digest, envelope, and parser gaps.
- **US2/US3/US4 corrections**: T008 closes the persisted continuation and stale-ancestor gaps.

### Parallel Opportunities

None. T007 and T008 share the planner, owner skills, and deterministic fixtures; T009 must describe their reviewed final behavior. They require sequential implementation and independent review checkpoints.

## Implementation Strategy

1. Complete T001 and T002, then prove RED before creating any feature behavior.
2. Complete T003 through T006 one at a time with the assigned review and correction cycle.
3. Complete T007 and its independent review before starting the continuation repair.
4. Complete T008 and its independent review before synchronizing documentation.
5. Complete T009, the deterministic suite, doc consistency, and whole-feature review from the pre-T001 base.
6. Treat T007 through T009 as one atomic final change set and request fresh staging and commit authorization only after T009.
