---
slug: 0024-decision-input-freshness
spec_slug: 0024-decision-input-freshness
created: 2026-09-05
updated: 2026-09-05
---

# Tasks: Decision Input Freshness

**Input**: [plan](plan.md) and [spec](spec.md).
**Prerequisites**: Current approved [design-review](reviews/design-review.md).
**Tests**: RED before implementation, focused GREEN and full fast tier; installed readiness integration after the committed gate change.
**Organization**: Shared digest foundation, then both user stories sharing the approval contract.

## Phase 1: Setup

Reuse existing native scripts and test harnesses. No setup-only task.

**Checkpoint**: No additional dependency or framework.

## Phase 2: Foundational (blocks both stories)

- [x] T001 [US1] [US2] Implement canonical decision-input digest in skills/review/review-inputs.sh with tests/check-review-boundaries.sh, tests/check-skills-present.sh and docs/architecture.md coverage (plan Task 1)

**Checkpoint**: Deterministic input identity and fail-closed validation are independently tested.

## Phase 3: User Stories 1 and 2 - Current approvals (Priority: P1)

**Goal**: Bind both gates to reviewed decision inputs.
**Independent Test**: Mutation, candidate publication, legacy, progress and installed readiness cases.

- [ ] T002 [US1] [US2] Bind candidate-based design and readiness envelopes and installed consumers in skills/review/design-contract.sh, skills/analyze/readiness-contract.sh and native skills, with tests, readiness integration and Mandatory Sync 5 (depends on T001) (plan Task 2)

**Checkpoint**: Both boundaries reject stale inputs without replacing historical evidence.

## Phase 4: Polish and Cross-Cutting Concerns

Guidance, documentation synchronization and qualification are included in T002.

**Checkpoint**: Independent task reviews, one final branch review and valid terminal receipt precede done.

## Dependencies & Execution Order

T001 precedes T002. No parallel marker: both tasks touch review tests, inventory and architecture documentation. T001 covers FR-001–FR-003; T002 covers FR-004–FR-010 and SC-001–SC-004, with T001 providing the input identity used by their mutation tests.
