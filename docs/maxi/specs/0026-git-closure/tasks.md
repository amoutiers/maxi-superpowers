---
spec_slug: 0026-git-closure
created: 2026-09-26
updated: 2026-09-26
---

# Tasks: Explicit Git Closure

**Input:** [0026-git-closure/spec](spec.md) and [0026-git-closure/plan](plan.md).
**Prerequisites:** Current approved [design-review](reviews/design-review.md).
**Tests:** Test-first behavior and oracle checks, then the existing fast tier and installed-plugin cases.
**Organization:** Two deliverables cover the five user stories together. The plan does not prescribe independent production implementations per story.

## Format: `[ID] [Story] Description (plan Task N)`

Canonical items retain a bijective source-plan mapping. No parallel marker applies: the skill changes consume the baseline evidence from the harness task.

## Path Conventions

All implementation paths are relative to the repository root. Canonical design artifacts stay in this feature directory; runtime evidence stays in the existing ignored SDD workspace.

## Phase 1: Setup

Existing plugin, test tooling and isolated Git workspace supply setup. No additional task is extracted.

**Checkpoint:** Existing tooling and the initial fast-tier baseline are available.

## Phase 2: Foundational (Blocking Prerequisites)

This phase blocks the user-story behavior changes because their baseline and independent oracle must exist first.

- [x] T001 [US1] Add tests/integration/run-codex-git-closure-test.sh and tests/integration/git-closure-cases/, register in tests/integration/run-all.sh, validate the checker and record the unchanged-skill baseline for US1 through US5 and C1 through C5 (FR-009, SC-001 through SC-006) (plan Task 1)

**Checkpoint:** The isolated installed-plugin runner verifies skill-read evidence and actual Git effects; baseline failures are recorded separately from candidate acceptance.

## Phase 3: User Stories 1 through 5 (Priority: P1, P2)

**Goal:** Provide explicit Git closure through the plugin, preserving authority, gates, owner and work.
**Independent Test:** Run the installed Git-closure suite across all C1 through C5 variants and inspect candidate evidence.

- [ ] T002 [US1] Add the closure trigger to skills/using-maxi/SKILL.md and required outcome to skills/implement/SKILL.md, extend tests/check-implement-handoff.sh, synchronize Mandatory Sync 5 and verify all five stories (depends on T001; FR-001 through FR-010, SC-001 through SC-006) (plan Task 2)

**Checkpoint:** MVP and all authority, blocking, resume and preservation scenarios pass with the candidate plugin.

## Phase 4: Polish & Cross-Cutting Concerns

Documentation synchronization, doc-consistency, full validation, review and coherent commits are part of T002's deliverable rather than duplicate task entries.

**Checkpoint:** Fast-tier and behavioral evidence are complete; the existing implementation owner can consume a valid terminal receipt.

## Dependencies & Execution Order

- T001 precedes T002 because skill authoring uses its measured baseline and runner.
- US1 supplies the common trigger/report path; US2 through US5 constrain that same path and are covered by T002 and their own fixture cases in T001.
- No implementation tasks run concurrently. Installed fixture executions may run independently in separate repositories and runtime homes.
- Checkpoint validation does not imply permission to merge, push or publish.

## Implementation Strategy

Use x-develop's immutable projection and upstream task reviews. Keep the design, readiness and final implementation gates. A completed task is recorded through the validated upstream ledger before Maxi checkbox reconciliation.

## Notes

The design review's Codex discovery observation is an implementation consideration within T002's trigger responsibility and T001's neutral prompt coverage; no requirement or task decomposition changes.
