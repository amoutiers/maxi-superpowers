---
slug: 0023-sdd-handoff-remediation
spec_slug: 0023-sdd-handoff-remediation
created: 2026-09-05
updated: 2026-09-05
---

# Tasks: Complete SDD Task Handoff

**Input**: [0023-sdd-handoff-remediation/plan](plan.md) and [0023-sdd-handoff-remediation/spec](spec.md).
**Tests**: TDD is required within each implementation task.

## Phase 1: Setup

Use the existing repository and test harness. No separate setup deliverable is required by the plan.

**Checkpoint**: Existing baseline verified before implementation.

## Phase 2: Foundational

Both tasks use the existing native adapter. There is no additional infrastructure task.

**Checkpoint**: Existing native owners identified.

## Phase 3: User Story 1 - Fresh startup (Priority: P1)

**Goal**: Initialize the canonical SDD base safely.
**Independent Test**: Adapter test starts with no `.superpowers` and rejects file/symlink components.

- [ ] T001 [US1] Initialize the canonical SDD base in skills/x-develop/project-tasks.sh with tests/check-x-develop-adapter.sh regressions (plan Task 1)

**Checkpoint**: MVP fresh startup is independently testable.

## Phase 4: User Stories 2 and 3 - Complete delivery and resume (Priority: P1)

**Goal**: Deliver complete bodies through versioned immutable projections and preserve resume history.
**Independent Test**: Upstream briefs and v1-to-v2 partial/full upgrade cases in the adapter suite.

- [ ] T002 [US2] [US3] Deliver complete v2 task bodies and preserve v1 lineage in skills/x-develop/project-tasks.sh, reconcile-tasks.sh, record-terminal.sh and result-contract.sh, with native guidance, tests and Mandatory Sync 5 (depends on T001) (plan Task 2)

**Checkpoint**: Complete task delivery and resume compatibility verified.

## Phase 5: Polish & Cross-Cutting Concerns

Task 2 includes documentation synchronization, skill validation, handoff tests and the fast tier; no additional implementation task is invented.

**Checkpoint**: Validation evidence is ready for review.

## Dependencies & Execution Order

T001 precedes T002 because both modify the same adapter and test file. No parallel implementation opportunities exist. T001 covers FR-001 and SC-001. T002 covers FR-002 through FR-008 and SC-002 through SC-005, retaining T001 behavior.
