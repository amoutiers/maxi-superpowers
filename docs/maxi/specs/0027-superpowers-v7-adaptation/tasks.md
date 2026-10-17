---
spec_slug: 0027-superpowers-v7-adaptation
created: 2026-10-17
updated: 2026-10-17
---

# Tasks: Superpowers v7 Adaptation

**Input**: [0027-superpowers-v7-adaptation/plan](plan.md) and [0027-superpowers-v7-adaptation/spec](spec.md), with the verified [design review](reviews/design-review.md).

**Tests**: Each task retains its complete plan body, interfaces, assertions and verification commands. New behavior follows RED/GREEN before the required full fast tier and local commit.

**Format**: Sequential `TNNN` IDs, story labels and exactly one terminal source-plan mapping. No task is parallel: the tasks share source, documentation or qualification inputs.

## Phase 1: Setup

The isolated worktree, approved adaptation and accepted ADR are preparation inputs already established by their owners. The plan contains no additional setup task to extract.

**Checkpoint**: Preparation artifacts are available; extraction introduces no invented setup work.

## Phase 2: Foundational (Blocking Prerequisites)

The installed owner snapshot and existing bump/sync tooling are available. The import remains part of Task 1 so its adaptation and Mandatory Sync documents form one coherent change.

**Checkpoint**: Existing infrastructure is ready for the sequential story tasks.

## Phase 3: User Story 1: Governed v7 Design Conversation (Priority: P1)

**Goal**: Use upstream v7 intake and its builder prompt through the existing specification owners.

**Independent Test**: Task 1's focused boundary/runtime/sync checks and fresh installed pressure case; Task 4 extends the retained evidence checker.

- [x] T001 [US1] Import exact v7 through scripts/bump-superpowers.sh, adapt skills/specify/SKILL.md and skills/specify/spec-author.md, and synchronize skills/using-maxi/SKILL.md, docs/pipeline-flow.md, docs/delegation-map.md, docs/architecture.md, AGENTS.md and current version references (plan Task 1)

**Checkpoint**: MVP design intake retains canonical ownership, one creation builder check and the existing gates.

## Phase 4: User Story 2: Host Loading (Priority: P1)

**Goal**: Repair root bootstrap reliability and add native Antigravity discovery packaging.

**Independent Test**: Empty-PATH hooks, actual Hermes descriptions in both layouts, native manifest checks and the available Antigravity validator.

- [x] T002 [US2] Port hooks/session-start, hooks/run-hook.cmd and .hermes-plugin/__init__.py fixes with tests/check-hooks.sh, tests/check-hermes-plugin.sh and the affected AGENTS.md coverage description (depends on T001) (plan Task 2)
- [x] T003 [US2] Add .antigravity-plugin/plugin.json, adapt skills/using-maxi/SKILL.md discovery and the Mandatory Sync five, update README.md and both local release skills, and register tests/check-antigravity-plugin.sh (depends on T002) (plan Task 3)

**Checkpoint**: Host package, release inventory and project-aware bootstrap checks agree.

## Phase 5: User Story 3: Installed Upgrade Evidence (Priority: P2)

**Goal**: Extend the existing installed harness to recognize independent v7 builder evidence without weakening design or execution checks.

**Independent Test**: Executable checker regressions and tests/check-integration-harness.sh, including rejection of missing, echoed and unrelated child evidence.

- [x] T004 [US3] Extend tests/integration/design-cases/cases.json, tests/integration/run-codex-design-test.sh and tests/integration/assert-design-events.jq with guarded v7 replay and independent builder accounting; update owning harness regressions and documentation (depends on T003) (plan Task 4)

**Checkpoint**: The committed harness can run actual installed qualification against a clean candidate.

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T005 [US3] Run installed v7, initial/revision design and tests/integration/run-codex-upgrade-test.sh qualification; record native host evidence and source identities in docs/superpowers/qualification/2026-10-17-superpowers-7-adaptation.md, reconcile current claims and run doc-consistency (depends on T004) (plan Task 5)

**Checkpoint**: Qualification, explicit host limits and current documentation are recorded before the sole final implementation review.

## Dependencies & Execution Order

Execute T001 → T002 → T003 → T004 → T005. Shared Mandatory Sync files, hook checks, installed snapshot inputs and clean-source requirements preclude parallel execution. Each task consumes the previous task's verified commit.

The five mappings are bijective with the five executable plan headings. All detailed interfaces, assertions and verification commands remain in their owning [plan](plan.md) task bodies and must survive SDD projection and brief extraction.

## Implementation Strategy

Run the installed implementation owner and x-develop adapter after the readiness review. Follow each task's focused RED/GREEN checks, then the full fast tier before committing. Actual installed qualification follows the committed harness. Only validated SDD completion and final evidence can authorize the implementation owner's `done` transition.
