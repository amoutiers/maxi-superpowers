---
slug: 0019-artifact-analysis-convergence
spec_slug: 0019-artifact-analysis-convergence
created: 2026-08-01
updated: 2026-08-01
---

# Tasks: Artifact Revisions and Bounded Analysis Convergence

**Input**: Design documents from `docs/maxi/specs/0019-artifact-analysis-convergence/`
**Prerequisites**: [plan](plan.md), [spec](spec.md), [research](research.md), [data-model](data-model.md), [analysis-report](contracts/analysis-report.md), [artifact-metadata](contracts/artifact-metadata.md), [validator-cli](contracts/validator-cli.md), [quickstart](quickstart.md)

**Tests**: Every behavior change follows `superpowers:test-driven-development`. Focused checks must fail before implementation and pass afterward. `bash tests/run-all.sh` is the mandatory final deterministic gate; integration scenarios remain opt-in.

**Commit strategy**: Phases 1 through 8 are review checkpoints without commits. After Mandatory Sync 5, full verification, and independent review, Phase 9 creates one explicit-path implementation commit with fresh user consent.

**Organization**: Shared validator, metadata, and workflow foundations precede five user-story phases. Every task ends with deterministic FR/SC coverage evidence.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Safe to execute in parallel because the task writes different files and has no dependency on another parallel task in the same phase.
- **[Story]**: User story implemented by the task.
- Every task names exact files and ends with `(covers: ...)`.

## Phase 1: Setup (Test Scaffolding)

**Purpose**: Establish independent RED fixture surfaces before shared implementation begins.

- [ ] T001 [P] Create the artifact-graph fixture layout in `tests/fixtures/artifact-graph/` and the failing runner `tests/check-artifact-graph.sh`, including exact exit-code and sorted-output assertions (covers: FR-033, FR-053, SC-002)
- [ ] T002 [P] Create analysis and convergence RED fixture layouts in `tests/fixtures/artifact-graph/analysis-gates/`, `tests/check-analysis-convergence.sh`, and `tests/check-convergence-coordinator.sh` without registering them in `tests/run-all.sh` (covers: FR-037, FR-041, FR-048, SC-001, SC-004, SC-005)

**Checkpoint**: Focused runners fail for missing implementation, and the existing fast tier remains green.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Implement the shared graph, metadata, revision, and workflow transaction contracts required by every user story.

**CRITICAL**: No user-story phase begins until this foundation is green.

- [ ] T003 Author `skills/x-artifact-graph/SKILL.md` through `superpowers:writing-skills`, defining adjacent-resource lookup, explicit project root, read-only responsibility, supported gates, candidate modes, overlay input, and fail-closed invocation (depends on T001) (covers: FR-003, FR-033, FR-034, FR-053)
- [ ] T004 Implement schema, path confinement, canonical dependency parsing, revision-0 compatibility, direct/transitive freshness, cycle detection, SHA-256 fallback, and deterministic owner-ranked output in `skills/x-artifact-graph/artifact-graph.sh` (depends on T003) (covers: FR-007, FR-008, FR-010, FR-011, FR-012, FR-013, FR-014, FR-015, FR-016, FR-017, FR-033, FR-053, SC-002, SC-007)
- [ ] T005 Extend `skills/x-artifact-graph/artifact-graph.sh` and `tests/check-artifact-graph.sh` with constitution markers, immutable ADR validation, explicit FR/SC coverage, candidate-plan/tasks/analysis modes, canonical staged overlays, overlay security, and exact exit codes 0/2/3/4/5/6/7/8/9 (depends on T004) (covers: FR-018, FR-019, FR-020, FR-021, FR-022, FR-033, FR-034, FR-035, FR-036, FR-053, FR-061, SC-008, SC-011)
- [ ] T006 Register `x-artifact-graph` in `tests/check-skills-present.sh`, run `bash -n skills/x-artifact-graph/artifact-graph.sh`, and make `tests/check-artifact-graph.sh` green without updating prose counts or `tests/run-all.sh` (depends on T005) (covers: FR-033, FR-054, FR-055, SC-010)
- [ ] T007 [P] Extend `tests/check-templates.sh` with RED assertions for revision metadata, exact dependencies, spec/plan ADR fields, analysis/workflow templates, and complete absence of revision metadata from ADR templates and fixtures (covers: FR-007, FR-008, FR-010, FR-018, FR-019, FR-056, FR-058, SC-008)
- [ ] T008 Update `skills/constitution/constitution-template.md`, `skills/specify/spec-template.md`, `skills/plan/plan-template.md`, `skills/tasks/tasks-template.md`, create `skills/analyze/analysis-template.md` and `skills/revise/workflow-template.md`, then make `tests/check-templates.sh` green (depends on T007) (covers: FR-007, FR-008, FR-010, FR-016, FR-018, FR-019, FR-056, FR-058)
- [ ] T009 [P] Create RED owner-contract assertions in `tests/check-revision-producers.sh` for new revision 1, legacy 0 to 1, exactly one structural increment, the closed exemption set, and revision-free ADRs (covers: FR-007, FR-008, FR-009, FR-013, FR-014, FR-015, FR-018, SC-007, SC-008)
- [ ] T010 Update `skills/constitution/SKILL.md`, `skills/specify/SKILL.md`, `skills/clarify/SKILL.md`, `skills/plan/SKILL.md`, `skills/tasks/SKILL.md`, `skills/analyze/SKILL.md`, `skills/x-adr/SKILL.md`, and `skills/using-maxi/SKILL.md` through `superpowers:writing-skills` so every mutable owner applies the canonical revision/dependency rule; make `tests/check-revision-producers.sh` green (depends on T009) (covers: FR-001, FR-002, FR-007, FR-008, FR-009, FR-010, FR-013, FR-014, FR-015, FR-016, FR-017, FR-018, FR-019, FR-032, FR-055, FR-058, SC-007)
- [ ] T011 [P] Create RED lifecycle, rollback, idempotency-key, `.maxi-ops`, and interruption fixtures in `tests/fixtures/artifact-graph/workflow/` plus `tests/check-workflow-ledger.sh` (covers: FR-029, FR-030, FR-056, FR-057, FR-058, FR-061, SC-006, SC-011)
- [ ] T012 Implement idempotent ledger initialization, semantic event writes, staged manifests, atomic replacement, recovery, and lifecycle delegation in `skills/revise/workflow-ledger.sh`, `skills/revise/SKILL.md`, `skills/specify/SKILL.md`, `skills/park/SKILL.md`, `skills/resume/SKILL.md`, and `skills/cancel/SKILL.md` through `superpowers:writing-skills`; make `tests/check-workflow-ledger.sh` green (depends on T011) (covers: FR-025, FR-029, FR-030, FR-031, FR-032, FR-056, FR-057, FR-058, FR-061, SC-003, SC-006, SC-011)

**Checkpoint**: Validator, templates, revision producers, and workflow transaction checks pass. No user-story behavior depends on chat-only state.

---

## Phase 3: User Story 1 - Block Invalid Implementation Entry (Priority: P1) MVP

**Goal**: Permit `analyzed` and implementation only from a current independent passing report.

**Independent Test**: Run analysis against blocking, clean, self-review, not-run, stale, bad-hash, and forged-status fixtures; only the current independent passing fixture reaches `analyzed` and implementation.

### Tests for User Story 1

- [ ] T013 [US1] Complete RED report fixtures in `tests/fixtures/artifact-graph/analysis-gates/` and `tests/check-analysis-convergence.sh` for deterministic stop, exact TSV bytes, review modes, dispositions, pass results, candidate validation, and forged `analyzed` status (depends on T002, T006) (covers: FR-004, FR-005, FR-006, FR-037, FR-040, FR-044, FR-045, FR-046, FR-047, FR-052, FR-060, SC-001, SC-009)

### Implementation for User Story 1

- [ ] T014 [US1] Author the read-only independent reviewer contract in `skills/analyze/reviewer-prompt.md` and finalize `skills/analyze/analysis-template.md` through `superpowers:writing-skills`, including exact reviewed-set serialization and evidence sections (depends on T013) (covers: FR-038, FR-039, FR-040, FR-042, FR-044, FR-045, FR-046, FR-059, FR-060)
- [ ] T015 [US1] Rewrite `skills/analyze/SKILL.md` through `superpowers:writing-skills` as the sole report writer with deterministic preflight, honest isolated/self/not-run modes, read-only separate-session handoff, dispositions, result calculation, and no transition on failure; make those assertions green in `tests/check-analysis-convergence.sh` (depends on T014) (covers: FR-004, FR-005, FR-023, FR-028, FR-037, FR-038, FR-039, FR-040, FR-042, FR-044, FR-045, FR-046, FR-047, FR-059, FR-060, SC-001, SC-003)
- [ ] T016 [US1] Implement and test the two-operation final analysis transition, unconditional constitution alignment, candidate overlay validation at `tasked`, projected implement validation at `analyzed`, and journal-only technical completion in `skills/analyze/SKILL.md`, `tests/check-analysis-convergence.sh`, and `tests/check-artifact-graph.sh` (depends on T015) (covers: FR-003, FR-004, FR-005, FR-006, FR-033, FR-034, FR-047, FR-052, FR-061, SC-001, SC-009, SC-011)
- [ ] T017 [US1] Update `skills/implement/SKILL.md` through `superpowers:writing-skills` to run the complete implement preflight before first or resumed work and make every invalid analysis fixture refuse in `tests/check-analysis-convergence.sh` (depends on T016) (covers: FR-006, FR-012, FR-020, FR-021, FR-022, FR-034, FR-047, FR-052, FR-054, SC-008, SC-009)

**Checkpoint**: User Story 1 is independently testable and forms the MVP. Failed, stale, provisional, or forged analysis cannot open implementation.

---

## Phase 4: User Story 2 - Detect Stale Artifacts and Replay Minimally (Priority: P1)

**Goal**: Detect exact stale descendants and replay only the producer chain required by the earliest owner.

**Independent Test**: Mutate spec, plan, and tasks fixtures independently; verify owner-ranked failures, expected stale descendants, and task-only replay without unnecessary plan or clarification work.

### Tests and Implementation for User Story 2

- [ ] T018 [US2] Complete fresh, stale-spec, stale-plan, task-only, cycle, multi-owner, constitution, and canonical-path fixtures under `tests/fixtures/artifact-graph/`, asserting exact dependency paths and owner-ranked output in `tests/check-artifact-graph.sh` (depends on T006) (covers: FR-007, FR-010, FR-011, FR-012, FR-023, FR-025, FR-031, FR-033, FR-053, SC-002, SC-003)
- [ ] T019 [US2] Add RED and GREEN pre-write/post-write plan/tasks gate coverage in `tests/check-artifact-graph.sh`, `skills/plan/SKILL.md`, `skills/tasks/SKILL.md`, and `skills/tasks/tasks-template.md` through `superpowers:writing-skills`, including candidate modes, exact `(covers: ...)` syntax, and unconditional constitution alignment (depends on T018) (covers: FR-001, FR-002, FR-003, FR-024, FR-033, FR-034, FR-035, FR-036, FR-053, SC-002, SC-003)
- [ ] T020 [US2] Author `skills/x-converge/SKILL.md` through `superpowers:writing-skills` with the persisted state machine, earliest-owner replay chains, one confirmation, revise delegation, dependency-order execution, and minimal descendant replay; register it in `tests/check-skills-present.sh` and make replay assertions green in `tests/check-convergence-coordinator.sh` and `tests/check-analysis-convergence.sh` (depends on T012, T016, T019) (covers: FR-023, FR-025, FR-028, FR-029, FR-030, FR-031, FR-032, FR-048, SC-003, SC-005, SC-006)

**Checkpoint**: User Story 2 is independently testable. Spec, plan, and task changes produce exact stale sets and bounded minimal replay chains.

---

## Phase 5: User Story 3 - Repair Original Specification Gaps (Priority: P1)

**Goal**: Route missing normative behavior to `spec.md`, then clarify only the identified gap before replaying descendants.

**Independent Test**: Inject a missing public behavior into a plan or analysis fixture, verify `spec.md` ownership and rollback to `specified`, then confirm targeted clarification preserves unrelated prior decisions.

### Tests and Implementation for User Story 3

- [ ] T021 [US3] Add RED spec-gap, absent normative behavior, earliest-owner, targeted-clarification, and no-batch-broadening fixtures to `tests/check-artifact-graph.sh`, `tests/check-workflow-ledger.sh`, and `tests/check-convergence-coordinator.sh` (depends on T019, T020) (covers: FR-001, FR-002, FR-023, FR-024, FR-025, FR-026, FR-027, FR-028, FR-032, SC-003)
- [ ] T022 [US3] Update `skills/revise/SKILL.md` and `skills/clarify/SKILL.md` through `superpowers:writing-skills` for exceptional rollback to `specified`, exact finding-batch consent, targeted clarification, preservation of unrelated Q&A, and replay through plan/tasks/analyze; make T021 fixtures green (depends on T021) (covers: FR-023, FR-024, FR-025, FR-026, FR-027, FR-028, FR-029, FR-030, FR-031, FR-032, SC-003, SC-006)

**Checkpoint**: User Story 3 is independently testable. A real hole in the original specification is repaired at its source without reopening unrelated decisions.

---

## Phase 6: User Story 4 - Converge with Stable Findings (Priority: P2)

**Goal**: Preserve finding identities and deltas while limiting each user authorization to one correction and complete re-analysis cycle.

**Independent Test**: Run two independent analyses around one correction; verify stable IDs, exact deltas, classification disagreements, idempotent resume, and a hard stop after the second failure.

### Tests and Implementation for User Story 4

- [ ] T023 [US4] Extend `tests/check-analysis-convergence.sh` with RED stable-fingerprint, semantic-equivalence, non-recycled-ID, original-unresolved, newly-discovered, classification-disagreement, and valid-disposition cases (depends on T013) (covers: FR-041, FR-042, FR-043, FR-044, FR-045, FR-046, FR-050, FR-060, SC-004)
- [ ] T024 [US4] Implement registry reconciliation, delta calculation, exact finding-set hash verification, second-failure grouping, and correction proposals in `skills/analyze/SKILL.md` and `skills/analyze/analysis-template.md` through `superpowers:writing-skills`; make T023 fixtures green (depends on T023) (covers: FR-023, FR-028, FR-041, FR-042, FR-043, FR-044, FR-045, FR-046, FR-048, FR-049, FR-050, FR-060, SC-003, SC-004, SC-005)
- [ ] T025 [US4] Complete cycle authorization, interruption resume, same-reviewer preference, correction-stop, and one-new-decision-per-cycle behavior in `skills/x-converge/SKILL.md`, `skills/analyze/SKILL.md`, `tests/check-convergence-coordinator.sh`, `tests/check-analysis-convergence.sh`, and `tests/check-workflow-ledger.sh` through `superpowers:writing-skills` (depends on T020, T024) (covers: FR-029, FR-030, FR-039, FR-048, FR-049, FR-050, FR-051, FR-056, FR-057, FR-059, FR-061, SC-004, SC-005, SC-006, SC-011)

**Checkpoint**: User Story 4 is independently testable. Findings retain identity and automatic correction always stops after one consumed cycle.

---

## Phase 7: User Story 5 - Preserve Legacy and ADR Semantics (Priority: P2)

**Goal**: Adopt revision metadata incrementally, preserve historical specs, keep ADRs immutable, and force replanning for post-plan architectural decisions.

**Independent Test**: Validate legacy revision-0, done/cancelled, current/superseded/deprecated ADR, migration, and post-plan ADR-parity fixtures; only the governed owner write adopts revision 1.

### Tests and Implementation for User Story 5

- [ ] T026 [P] [US5] Update `skills/migrate-from-speckit/SKILL.md`, `skills/migrate-from-brownfield/SKILL.md`, `tests/check-migrate-from-speckit.sh`, and `tests/check-migrate-from-brownfield.sh` through `superpowers:writing-skills` for historical ingress, virtual revision 0, omission of workflow metadata, and task-only coverage rollback (depends on T010) (covers: FR-007, FR-013, FR-014, FR-016, FR-017, FR-058, SC-007)
- [ ] T027 [P] [US5] Add ADR-currentness and post-plan parity fixtures to `tests/check-artifact-graph.sh` and `tests/check-analysis-convergence.sh`, then update `skills/x-adr/SKILL.md` and `skills/implement/SKILL.md` through `superpowers:writing-skills` to return `ADR_REPLAN_REQUIRED` and stop before further implementation writes (depends on T017) (covers: FR-018, FR-019, FR-020, FR-021, FR-022, FR-052, FR-062, SC-008, SC-009, SC-012)
- [ ] T028 [US5] Make all legacy, terminal, migration, ADR-status, ADR-parity, and revision-adoption fixtures green in `tests/check-artifact-graph.sh`, `tests/check-revision-producers.sh`, `tests/check-migrate-from-speckit.sh`, and `tests/check-migrate-from-brownfield.sh` (depends on T026, T027) (covers: FR-012, FR-013, FR-014, FR-018, FR-019, FR-020, FR-021, FR-022, FR-062, SC-007, SC-008, SC-012)

**Checkpoint**: User Story 5 is independently testable. Historical artifacts remain valid records, active legacy work adopts metadata incrementally, and new ADRs cannot bypass replanning.

---

## Phase 8: Polish and Cross-Cutting Consistency

**Purpose**: Add agentic evidence, synchronize every pipeline description, and close all coverage and portability gaps.

- [ ] T029 [P] Create `tests/integration/run-agentic-scenarios.sh` and the four scenarios `tests/integration/scenarios/deterministic-stop.txt`, `tests/integration/scenarios/self-review-handoff.txt`, `tests/integration/scenarios/independent-pass.txt`, and `tests/integration/scenarios/correction-limit.txt`; update `tests/integration/run-all.sh` and `tests/check-integration-harness.sh` with temp-directory, timeout, and unsupported-isolation safeguards (depends on T017, T025) (covers: FR-004, FR-005, FR-037, FR-039, FR-040, FR-047, FR-049, FR-052, FR-059, SC-001, SC-005, SC-009)
- [ ] T030 [P] Synchronize `docs/pipeline-flow.md`, `docs/delegation-map.md`, `skills/using-maxi/SKILL.md`, `AGENTS.md`, `docs/architecture.md`, and `README.md`; update `tests/check-skill-count.sh`, `tests/check-status-consistency.sh`, `tests/check-skills-present.sh`, and register each new focused check exactly once in `tests/run-all.sh` (depends on T006, T008, T012, T019, T025, T028) (covers: FR-054, FR-055, SC-010)
- [ ] T031 Run `maxi:doc-consistency`, fix confirmed Mandatory Sync 5 or README drift in `docs/pipeline-flow.md`, `docs/delegation-map.md`, `skills/using-maxi/SKILL.md`, `AGENTS.md`, `docs/architecture.md`, and `README.md`, then rerun deterministic consistency checks (depends on T030) (covers: FR-054, FR-055, SC-010)
- [ ] T032 Update `docs/maxi/specs/0019-artifact-analysis-convergence/quickstart.md`, build the complete FR-001..FR-062 and SC-001..SC-012 coverage matrix, audit every failure path from the plan, run `git diff --check`, `bash tests/run-all.sh`, and optional `bash tests/run-all.sh --integration`, then obtain independent code/spec review with zero open CRITICAL/HIGH and valid dispositions for MEDIUM/LOW findings (depends on T029, T031) (covers: FR-001, FR-002, FR-003, FR-033, FR-034, FR-035, FR-036, FR-054, FR-055, FR-061, FR-062, SC-001, SC-002, SC-003, SC-004, SC-005, SC-006, SC-007, SC-008, SC-009, SC-010, SC-011, SC-012)

**Checkpoint**: All user stories, deterministic checks, documentation, coverage evidence, and supported agentic scenarios are complete and independently reviewed.

---

## Phase 9: Verified Atomic Milestone

**Purpose**: Commit only the reviewed implementation surface after explicit user consent.

- [ ] T033 Build an explicit concrete-path staging manifest from T001-T032, stage only those paths, inspect `git diff --cached --name-status`, `git diff --cached --check`, and the complete cached diff, obtain explicit user consent, then create `feat(0019): enforce bounded artifact analysis convergence` with no push (depends on T032) (covers: FR-055, SC-010)

**Checkpoint**: One verified implementation milestone is committed; publication remains a separate user-authorized action.

---

## Dependencies and Execution Order

### Phase Dependencies

- **Phase 1 Setup**: Starts immediately.
- **Phase 2 Foundational**: Depends on Phase 1 and blocks all user stories.
- **Phase 3 US1**: Depends on the complete foundation.
- **Phase 4 US2**: Depends on US1 analysis transitions plus the foundation.
- **Phase 5 US3**: Depends on US2 gate and convergence ownership.
- **Phase 6 US4**: Depends on US1 report ownership and US2 convergence coordination.
- **Phase 7 US5**: Depends on foundation and US1 implementation refusal; T026 and T027 can run in parallel.
- **Phase 8 Polish**: Depends on every desired user story; T029 and T030 can run in parallel after their listed dependencies.
- **Phase 9 Milestone**: Depends on final verification and review.

### User Story Dependencies

- **US1 (P1)**: Establishes the final analysis and implementation gate used by later stories.
- **US2 (P1)**: Uses US1 candidate transitions and adds exact freshness plus minimal replay.
- **US3 (P1)**: Uses US2 owner selection and replay to repair a source specification gap.
- **US4 (P2)**: Extends US1 analysis and US2 convergence with stable identities and hard cycle limits.
- **US5 (P2)**: Uses the foundation and US1 refusal path; it is otherwise independent of US3 and US4.

### Parallel Opportunities

- T001 and T002 can run in parallel.
- After Setup, T007, T009, and T011 can prepare independent RED checks while T003-T006 build the validator.
- T026 and T027 can run in parallel because they modify separate skill and test groups.
- T029 and T030 can run in parallel after their explicit dependencies are satisfied.
- Tasks editing the same `SKILL.md`, `tests/check-artifact-graph.sh`, `tests/check-analysis-convergence.sh`, or `tests/run-all.sh` remain sequential under one integration owner.

## Plan-to-Task Traceability

| Plan task | Extracted tasks |
|---|---|
| Plan Task 1 | T001, T018 |
| Plan Task 2 | T003-T006 |
| Plan Task 3 | T007-T008 |
| Plan Task 4 | T009-T010, T026 |
| Plan Task 5 | T011-T012, T021-T022 |
| Plan Task 6 | T019, T021 |
| Plan Task 7 | T002, T013-T014, T023 |
| Plan Task 8 | T015-T016, T024-T025 |
| Plan Task 9 | T020, T025 |
| Plan Task 10 | T017, T027-T028 |
| Plan Task 11 | T029 |
| Plan Task 12 | T030-T031 |
| Plan Task 13 | T032-T033 |

## Implementation Strategy

1. Complete Setup and Foundational RED/GREEN work without committing.
2. Deliver and validate US1 as the MVP implementation-entry safety boundary.
3. Add the remaining P1 stories in dependency order: exact minimal replay, then original-spec repair.
4. Add P2 stable convergence and legacy/ADR preservation.
5. Run integration, Mandatory Sync 5, coverage, no-hole, and independent-review gates.
6. Stage exact paths and request final commit consent once.

## Notes

- `[P]` means file-disjoint and dependency-safe only within its phase.
- Every `SKILL.md` edit uses `superpowers:writing-skills`; vendored skills remain untouched.
- Every focused behavior check follows RED before GREEN.
- No intermediate implementation commit is permitted by the governing plan.
- Any newly discovered normative hole returns through `/maxi:revise`; it is never patched only in tasks or implementation.
