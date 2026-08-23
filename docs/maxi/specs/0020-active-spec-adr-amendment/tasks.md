---
slug: 0020-active-spec-adr-amendment
spec: docs/maxi/specs/0020-active-spec-adr-amendment/spec.md
plan: docs/maxi/specs/0020-active-spec-adr-amendment/plan.md
created: 2026-08-23
updated: 2026-08-23
---

# Tasks: Active-Spec ADR Amendment

**Input**: Design documents from `docs/maxi/specs/0020-active-spec-adr-amendment/`
**Prerequisites**: `spec.md`, `plan.md`, and approved `reviews/design-review.md`

## Phase 1: Setup

**Purpose**: No separate setup work is required by the approved plan.

---

## Phase 2: Foundational

**Purpose**: Lock the contract before changing the skills that enforce it.

- [x] T001 Update the ADR fixture and deterministic checks for the direct `spec:` link, `spec: null` migration, active-spec amendment policy, and the Constitution/Mandatory Sync 5 contract in `tests/check-templates.sh`, `tests/check-migrate-adr.sh`, `tests/check-skill-count.sh`, and `tests/fixtures/sample-adr.md` (plan Task 1)

**Checkpoint**: The acceptance contract fails closed before workflow changes are made.

---

## Phase 3: User Story 1 - Amend an active-spec ADR (Priority: P1)

**Goal**: Let the agent propose, and the user approve, an amendment to the ADR created by an active spec.

- [x] T002 [US1] [US2] Update `x-adr`, its template, `using-maxi`, and ADR migration guidance so every new ADR has `spec: <full slug>` or `spec: null`, detected decision changes during any active status produce a full amended ADR plus exact diff for consent, and closed or unlinked ADRs use the existing supersession fallback in `skills/x-adr/SKILL.md`, `skills/x-adr/adr-template.md`, `skills/using-maxi/SKILL.md`, `skills/migrate-adr/SKILL.md`, and its import/discovery briefs (plan Task 2)

**Checkpoint**: An approved amendment updates the existing eligible ADR; an ineligible ADR results in a new superseding ADR.

---

## Phase 4: User Story 2 - Preserve closed ADR history (Priority: P1)

**Goal**: Keep ADRs tied to done, parked, or cancelled specs immutable while preserving the normal supersession path.

- [x] T003 [US2] Synchronize the Constitution, pipeline flow, delegation map, contributor guidance, and architecture documentation with the agent-proposed amendment flow, closed-spec fallback, direct ADR-to-spec link, and Constitution 1.4.2 in `docs/maxi/constitution.md`, `docs/pipeline-flow.md`, `docs/delegation-map.md`, `AGENTS.md`, and `docs/architecture.md` (plan Task 3)

**Checkpoint**: The documented pipeline matches the enforced closed-spec behavior.

---

## Phase 5: Polish and Verification

**Purpose**: Verify the complete change and prepare it for explicit commit approval.

- [x] T004 Run the targeted deterministic checks and `bash tests/run-all.sh`, inspect the complete diff, then stage only this feature's files and present the cached diff for explicit commit consent (plan Task 4)

**Checkpoint**: The verified, scoped change is staged but not committed.

---

## Dependencies and Execution Order

- T001 blocks T002: the test contract is established before the workflow changes.
- T002 blocks T003: the documentation describes the implemented workflow.
- T003 blocks T004: verification covers the fully synchronized change.

## Implementation Strategy

1. Complete T001 to establish the direct-link and amendment contract.
2. Complete T002 to implement both active-spec amendment and closed-spec fallback behavior.
3. Complete T003 to keep the Mandatory Sync 5 documents and Constitution aligned.
4. Complete T004 and wait for explicit consent before committing.
