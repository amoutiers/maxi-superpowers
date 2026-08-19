---
slug: NNNN-feature-slug
spec_slug: NNNN-feature-slug
created: YYYY-MM-DD
updated: YYYY-MM-DD
revision: 1
writer_context: <unique-writer-context>
structural_contributors:
  - <unique-writer-context>
derived_from:
  - <direct-input-path>@<exact-revision>
# Replace the writer-context placeholders with one new context unique across this
# spec's pipeline-owned documents. Replace the derived input placeholder with every
# direct document input required by the forward provenance contract in SKILL.md.
---

# Tasks: [feature-name]

> **Filled in by `/maxi:tasks`.** See `SKILL.md` in this directory for the workflow.

**Input**: Design documents from `docs/maxi/specs/[###-feature-name]/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Test tasks are mandatory by default per `superpowers:test-driven-development`. Write tests first; ensure they FAIL before implementation. A feature may opt out only if its spec explicitly says so AND the project constitution permits it.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description (plan Task N)`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions
- End every task with its unique source-plan mapping: `(plan Task N)`

## Path Conventions

- **Single project**: `src/`, `tests/` at repository root
- **Web app**: `backend/src/`, `frontend/src/`
- **Mobile**: `api/src/`, `ios/src/` or `android/src/`
- Paths shown below assume single project - adjust based on plan.md structure

<!--
  ACTION REQUIRED: The tasks below are SAMPLE TASKS for illustration only.
  The /maxi:tasks command MUST replace these with actual tasks based on:
  - User stories from spec.md (with their priorities P1, P2, P3...)
  - Feature requirements from plan.md
  - Entities from data-model.md
  - Endpoints from contracts/

  Tasks MUST be organized by user story so each story can be:
  - Implemented independently
  - Tested independently
  - Delivered as an MVP increment

  DO NOT keep these sample tasks in the generated tasks.md file.
-->

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create project structure per implementation plan (plan Task 1)
- [ ] T002 Initialize [language] project with [framework] dependencies (plan Task 2)
- [ ] T003 [P] Configure linting and formatting tools (plan Task 3)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

Examples of foundational tasks (adjust based on your project):

- [ ] T004 Setup database schema and migrations framework (plan Task 4)
- [ ] T005 [P] Implement authentication/authorization framework (plan Task 5)
- [ ] T006 [P] Setup API routing and middleware structure (plan Task 6)
- [ ] T007 Create base models/entities that all stories depend on (plan Task 7)
- [ ] T008 Configure error handling and logging infrastructure (plan Task 8)
- [ ] T009 Setup environment configuration management (plan Task 9)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - [Title] (Priority: P1) 🎯 MVP

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T010 [P] [US1] Contract test for [endpoint] in tests/contract/test_[name].<ext> (plan Task 10)
- [ ] T011 [P] [US1] Integration test for [user journey] in tests/integration/test_[name].<ext> (plan Task 11)

### Implementation for User Story 1

- [ ] T012 [P] [US1] Create [Entity1] model in <src>/models/[entity1].<ext> (plan Task 12)
- [ ] T013 [P] [US1] Create [Entity2] model in <src>/models/[entity2].<ext> (plan Task 13)
- [ ] T014 [US1] Implement [Service] in <src>/services/[service].<ext> (depends on T012, T013) (plan Task 14)
- [ ] T015 [US1] Implement [endpoint/feature] in <src>/[location]/[file].<ext> (plan Task 15)
- [ ] T016 [US1] Add validation and error handling (plan Task 16)
- [ ] T017 [US1] Add logging for user story 1 operations (plan Task 17)

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 2

- [ ] T018 [P] [US2] Contract test for [endpoint] in tests/contract/test_[name].<ext> (plan Task 18)
- [ ] T019 [P] [US2] Integration test for [user journey] in tests/integration/test_[name].<ext> (plan Task 19)

### Implementation for User Story 2

- [ ] T020 [P] [US2] Create [Entity] model in <src>/models/[entity].<ext> (plan Task 20)
- [ ] T021 [US2] Implement [Service] in <src>/services/[service].<ext> (plan Task 21)
- [ ] T022 [US2] Implement [endpoint/feature] in <src>/[location]/[file].<ext> (plan Task 22)
- [ ] T023 [US2] Integrate with User Story 1 components (if needed) (plan Task 23)

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - [Title] (Priority: P3)

**Goal**: [Brief description of what this story delivers]

**Independent Test**: [How to verify this story works on its own]

### Tests for User Story 3

- [ ] T024 [P] [US3] Contract test for [endpoint] in tests/contract/test_[name].<ext> (plan Task 24)
- [ ] T025 [P] [US3] Integration test for [user journey] in tests/integration/test_[name].<ext> (plan Task 25)

### Implementation for User Story 3

- [ ] T026 [P] [US3] Create [Entity] model in <src>/models/[entity].<ext> (plan Task 26)
- [ ] T027 [US3] Implement [Service] in <src>/services/[service].<ext> (plan Task 27)
- [ ] T028 [US3] Implement [endpoint/feature] in <src>/[location]/[file].<ext> (plan Task 28)

**Checkpoint**: All user stories should now be independently functional

---

[Add more user story phases as needed, following the same pattern]

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] TXXX [P] Documentation updates in docs/ (plan Task 29)
- [ ] TXXX Code cleanup and refactoring (plan Task 30)
- [ ] TXXX Performance optimization across all stories (plan Task 31)
- [ ] TXXX [P] Additional unit tests (if requested) in tests/unit/ (plan Task 32)
- [ ] TXXX Security hardening (plan Task 33)
- [ ] TXXX Run quickstart.md validation (plan Task 34)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Final Phase)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - May integrate with US1 but should be independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - May integrate with US1/US2 but should be independently testable

### Within Each User Story

- Tests (if included) MUST be written and FAIL before implementation
- Models before services
- Services before endpoints
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel (within Phase 2)
- Once Foundational phase completes, all user stories can start in parallel (if team capacity allows)
- All tests for a user story marked [P] can run in parallel
- Models within a story marked [P] can run in parallel
- Different user stories can be worked on in parallel by different team members

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together:
Task: "Contract test for [endpoint] in tests/contract/test_[name].<ext>"
Task: "Integration test for [user journey] in tests/integration/test_[name].<ext>"

# Launch all models for User Story 1 together:
Task: "Create [Entity1] model in <src>/models/[entity1].<ext>"
Task: "Create [Entity2] model in <src>/models/[entity2].<ext>"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo
4. Add User Story 3 → Test independently → Deploy/Demo
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1
   - Developer B: User Story 2
   - Developer C: User Story 3
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
