---
slug: 0021-reopen-done-specs
spec_slug: 0021-reopen-done-specs
created: 2026-08-23
updated: 2026-08-23
---

# Tasks: Reopen Completed Specs

**Input**: Design documents from `docs/maxi/specs/0021-reopen-done-specs/`
**Prerequisites**: `plan.md`, `spec.md`, and approved `reviews/design-review.md`

## Phase 1: Setup

**Purpose**: No separate setup work is required by the approved plan.

**Checkpoint**: The existing fast-tier test harness is ready for the new
contract assertions.

---

## Phase 2: Foundational ⚠️ BLOCKS ALL USER STORIES

**Purpose**: Lock the contract before changing any lifecycle or ADR skill.

- [x] T001 Add the completed-spec rollback and ADR-eligibility regression
  checks in `tests/check-revise.sh`, `tests/check-migrate-adr.sh`, and
  `tests/run-all.sh`; verify the targeted checks fail before the skill changes
  (plan Task 1)

**Checkpoint**: The fast tier fails if a completed spec cannot reopen or a
reopened spec can amend an accepted ADR.

---

## Phase 3: User Story 1 - Revise a completed specification (Priority: P1) 🎯 MVP

**Goal**: Reopen a completed canonical specification with the existing A+
picker and explicit-consent boundary.

**Independent Test**: Confirm that a `done` spec can move to the selected
earlier phase only after `yes`, and receives a permanent `reopened_from: done`
marker.

- [x] T002 [US1] [US2] Update `skills/revise/SKILL.md`,
  `skills/x-adr/SKILL.md`, and `skills/using-maxi/SKILL.md` so `done` can be
  reopened, the watermark persists, and amendment eligibility checks the
  watermark before active status; run both targeted checks (plan Task 2)

**Checkpoint**: User Story 1 is independently testable and establishes the
shared boundary required by User Story 2.

---

## Phase 4: User Story 2 - Preserve ADR history after reopening (Priority: P1)

**Goal**: Keep accepted ADRs immutable after their linked spec has been
reopened, while preserving the initial-lifecycle amendment path.

**Independent Test**: Confirm that a marked spec routes an ADR change to
supersession and an active spec without the marker still has the consent-gated
amendment route.

- [x] T003 [US1] [US2] Verify accepted
  `docs/maxi/adr/0025-reopened-spec-adr-eligibility.md` supersedes ADR-0024
  without changing ADR-0024's body; synchronize the watermark rule in
  `docs/maxi/constitution.md`, `docs/pipeline-flow.md`,
  `docs/delegation-map.md`, `AGENTS.md`, `docs/architecture.md`, `README.md`,
  and `tests/check-skill-count.sh`, then run the targeted governance checks
  (plan Task 3)

**Checkpoint**: The persistent post-reopening supersession rule is documented
and deterministically guarded.

---

## Phase 5: Polish and Cross-Cutting Verification

**Purpose**: Verify the complete policy change without expanding its scope.

- [x] T004 Inspect the full committed diff and `git diff --check` to confirm
  ADR-0024 changed only in supersession metadata, run `bash tests/run-all.sh`,
  and leave the worktree clean after the owner's explicit commit authorization
  (plan Task 4)

**Checkpoint**: The complete change is verified and committed only under the
owner's explicit authorization.

---

## Dependencies and Execution Order

- T001 blocks T002: the failure contract precedes the workflow change.
- T002 blocks T003: documentation describes the implemented eligibility rule.
- T003 blocks T004: full verification runs against the synchronized policy.
- T002 and T003 each serve both user stories because reopening and ADR
  eligibility are one inseparable lifecycle boundary.

## Implementation Strategy

1. Complete T001 and observe the new checks fail before implementation.
2. Complete T002 to make completed-spec reopening and post-reopening ADR
   eligibility enforceable.
3. Complete T003 to verify the accepted supersession and synchronize policy
   artifacts.
4. Complete T004 with the owner's explicit commit authorization.
