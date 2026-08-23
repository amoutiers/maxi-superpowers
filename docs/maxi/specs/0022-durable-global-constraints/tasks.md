---
slug: 0022-durable-global-constraints
spec_slug: 0022-durable-global-constraints
created: 2026-08-23
updated: 2026-08-23
---

# Tasks: Durable Global Constraints

> **Filled in by `/maxi:tasks`.** The reviewed implementation unit is atomic
> because the plan contract and Mandatory Sync 5 documentation must change
> together.

**Input**: [0022-durable-global-constraints/plan](plan.md),
[0022-durable-global-constraints/spec](spec.md),
[design-review](reviews/design-review.md), and
[constitution](../../constitution.md)

**Prerequisites**: The exact current spec-plan pair has an approved design
review. No research, data model, or contracts artifact exists for this feature.

**Tests**: Follow the RED/GREEN order in the plan. The focused fixture oracle
must fail against the current coordinator before the skill and template change,
then the focused checks and complete fast tier must pass.

**Organization**: The reviewed plan contains one executable task that covers
all three user stories. It is extracted once to preserve the required
plan-task bijection; the story phases are independent validation checkpoints,
not duplicate implementation tasks.

## Format: `[ID] [P?] [Story] Description (plan Task N)`

- **[P]**: Omitted because the sole implementation task is atomic.
- **[Story]**: `T001` covers US1, US2, and US3.
- Every executable item ends with its unique source-plan mapping.

## Phase 1: Setup

**Purpose**: Confirm the existing repository, planning surfaces, test helpers,
and Mandatory Sync 5 files named by the reviewed plan.

No separate setup task is extracted; setup is part of the sole atomic plan
task.

**Checkpoint**: Existing project structure is ready for the atomic task.

---

## Phase 2: Foundational ⚠️ BLOCKS ALL USER STORIES

**Purpose**: Deliver the complete reviewed contract as one indivisible change.

**⚠️ CRITICAL**: Do not split this task across commits or parallel workers.

- [x] T001 [US1] [US2] [US3] Implement the reviewed atomic durable `Global Constraints` contract by adding the fixture-first oracle and its seven cases in `tests/check-global-constraints.sh`, `tests/fixtures/global-constraints/complete-spec.md`, `tests/fixtures/global-constraints/complete-plan.md`, `tests/fixtures/global-constraints/none-spec.md`, `tests/fixtures/global-constraints/none-plan.md`, `tests/fixtures/global-constraints/omitted-plan.md`, `tests/fixtures/global-constraints/duplicate-plan.md`, and `tests/fixtures/global-constraints/stale-authority-plan.md`; extend `tests/check-templates.sh`, `tests/check-skill-count.sh`, and `tests/run-all.sh`; update the Maxi-owned planning contract in `skills/plan/plan-template.md` and `skills/plan/SKILL.md` via `superpowers:writing-skills`; synchronize `docs/pipeline-flow.md`, `docs/delegation-map.md`, `skills/using-maxi/SKILL.md`, `AGENTS.md`, and `docs/architecture.md`; leave `tests/check-review-boundaries.sh`, `tests/check-sync-invariant.sh`, and vendored Superpowers bytes unchanged; run every focused check, `maxi:doc-consistency`, `bash tests/run-all.sh`, and Git whitespace/status verification; then stage only the reviewed files, show the exact cached diff, and stop for fresh commit authorization (plan Task 1)

**Checkpoint**: The atomic implementation is complete and all three user-story
outcomes are ready for independent validation.

---

## Phase 3: User Story 1 - Preserve Durable Delivery Constraints (Priority: P1) 🎯 MVP

**Goal**: Newly written plans preserve every applicable durable cross-task
constraint in exactly one `Global Constraints` section.

**Independent Test**: Verify the complete and no-additional fixture pairs,
including all five durable categories and the exact no-additional bullet.

No additional executable task is extracted; US1 is implemented by `T001`.

**Checkpoint**: User Story 1 is independently validated as the MVP.

---

## Phase 4: User Story 2 - Keep Temporary Authority Out of Durable Artifacts (Priority: P1)

**Goal**: Transient execution state and individual mutation permissions never
enter the durable plan contract, while a durable fresh-authorization rule may
remain.

**Independent Test**: Verify that the complete fixture excludes its worktree,
HEAD, selected task, stop point, and prior permission, and that the
stale-authority fixture is rejected.

No additional executable task is extracted; US2 is implemented by `T001`.

**Checkpoint**: User Story 2 is independently validated.

---

## Phase 5: User Story 3 - Reject an Incomplete Durable Contract Before Tasks (Priority: P2)

**Goal**: Deterministic checks and the unchanged reviewer contract reject
omitted, duplicate, contradictory, or authority-carrying plan content.

**Independent Test**: Verify the complete case is approved and the omitted,
second-contract, and stale-authority cases are rejected without adding a new
review predicate or verdict.

No additional executable task is extracted; US3 is implemented by `T001`.

**Checkpoint**: User Story 3 is independently validated.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Confirm documentation consistency, complete fast-tier coverage,
the unchanged vendored-skill invariant, and the exact staged boundary.

No additional executable task is extracted; these checks and the commit stop
point are included in `T001`.

**Checkpoint**: All planned verification is complete and the exact staged diff
is ready for explicit commit authorization.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No executable task; confirm the existing surfaces first.
- **Foundational (Phase 2)**: Execute `T001` after Setup. It blocks every story
  checkpoint and must remain atomic.
- **User Stories (Phases 3-5)**: Validate in priority order after `T001`; no
  additional implementation task is extracted.
- **Polish (Phase 6)**: Confirm the verification and staged boundary already
  performed by `T001` after all story checkpoints.

### User Story Dependencies

- **User Story 1 (P1)**: Delivered by `T001` and validated first as the MVP.
- **User Story 2 (P1)**: Delivered by the same atomic task and independently
  validated after US1.
- **User Story 3 (P2)**: Delivered by the same atomic task and independently
  validated after US2.

The stories are independently testable but not independently executable because
the reviewed plan deliberately uses one atomic implementation task.

### Within T001

1. Add the focused fixture oracle and observe the required RED result.
2. Add the template and Mandatory Sync 5 checks and observe their RED results.
3. Update the Maxi-owned plan template and coordinator via
   `superpowers:writing-skills`.
4. Synchronize all five mandatory documents in the same change.
5. Run the focused checks and unchanged review/sync guards.
6. Run `maxi:doc-consistency`, the complete fast tier, status, and whitespace
   checks.
7. Stage only the reviewed files, show the exact cached diff, and stop for
   explicit commit authorization.

### Parallel Opportunities

None. `T001` touches shared skill, test, documentation, and commit-boundary
surfaces and is intentionally indivisible.

---

## Implementation Strategy

### Atomic MVP

1. Complete the Setup checkpoint.
2. Execute `T001` sequentially through its RED/GREEN and verification steps.
3. Validate US1 as the MVP, then validate US2 and US3 independently.
4. Confirm the final staged boundary and wait for explicit commit consent.

Splitting the implementation would violate the reviewed plan-task bijection and
the Mandatory Sync 5 same-change constraint.

---

## Notes

- `T001` is the only executable task because [0022-durable-global-constraints/plan](plan.md)
  contains exactly one executable `Task 1` heading.
- No `[P]` marker is valid for a single atomic task.
- Do not edit vendored Superpowers skills, reviewer predicates, FSM states,
  projection bytes, ledger bytes, or receipt formats.
- Do not commit, push, publish, deploy, retrieve secrets, or publish data
  without the fresh authorization required for that specific action.
