---
slug: 0023-sdd-handoff-remediation
created: 2026-09-05
updated: 2026-09-05
status: done
parked_from: null
related_adrs: [0027-complete-sdd-task-projections]
---

# Feature Specification: Complete SDD Task Handoff

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start a fresh implementation (Priority: P1)

An operator starts implementation in a project that has no SDD workspace.

**Why this priority**: The documented first invocation currently cannot initialize itself.
**Independent Test**: Invoke the projection helper in a temporary Git project with canonical source artifacts and no `.superpowers` directory.
**Acceptance Scenarios**:

1. **Given** no SDD base, **When** projection runs, **Then** its canonical directories, projection, ledger and active pointer are created.
2. **Given** a file or symlink at a required base component, **When** projection runs, **Then** it rejects without writing through that component.

### User Story 2 - Implement the complete reviewed task (Priority: P1)

An implementer receives all instructions for the selected plan task through the existing upstream brief helper.

**Why this priority**: A task label omits files, implementation details and acceptance checks.
**Independent Test**: Project the existing reordered fixture and extract each task with upstream `task-brief`; assert each mapped body and fence-adjacent text is present.
**Acceptance Scenarios**:

1. **Given** tasks ordered T003, T001, T002, **When** briefs are extracted, **Then** they contain complete source Task 3, Task 1 and Task 2 respectively.
2. **Given** fenced task-like headings, **When** a brief is extracted, **Then** those headings remain content and do not truncate the body.
3. **Given** ambiguous mappings or an unrepresentable fence payload, **When** projection runs, **Then** it rejects without publishing successor evidence or changing the pointer.

### User Story 3 - Resume without rewriting history (Priority: P1)

An operator resumes an existing v1 execution with the repaired adapter.

**Why this priority**: Existing immutable evidence must remain usable and auditable.
**Independent Test**: Seed authentic v1 evidence with partial or full completion, upgrade, and compare predecessor bytes and selected successor tasks.
**Acceptance Scenarios**:

1. **Given** partial validated v1 completion, **When** execution resumes, **Then** a distinct v2 successor includes only unfinished tasks and preserves v1 bytes.
2. **Given** all v1 tasks completed, **When** execution resumes, **Then** a final-review-only v2 successor still requires the existing final review.
3. **Given** altered predecessor evidence, **When** upgrade is attempted, **Then** it rejects and preserves the active pointer.

### Edge Cases

- Missing, duplicate, zero, unknown or nonterminal plan mappings; duplicate source headings; nonsequential source task numbers.
- Indented backtick fences, tilde fences, unclosed fences and payload lines that would toggle the upstream fence parser.
- Existing, external and dangling base symlinks; ordinary files in place of directories; orphan evidence with either versioned filename.
- Checked tasks without completion evidence; omitted anchored pending tasks; unchanged repeated v2 execution.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST initialize missing canonical SDD base directories from the physical Git root and reject symlinked or nondirectory components.
- **FR-002**: System MUST preserve canonical task order and map every TNNN bijectively to one executable source Task N via its terminal `(plan Task N)` annotation.
- **FR-003**: System MUST deliver the full mapped task body, including file paths, code and verification instructions, through unmodified upstream task-brief; normalize fence delimiters only and reject unrepresentable input.
- **FR-004**: New execution MUST use a distinct maxi-v2 projection identity; existing v1 projection and ledger bytes MUST remain immutable historical evidence.
- **FR-005**: Successor selection MUST use validated lineage completions, preserve unfinished anchored tasks, and require final review even when no task remains.
- **FR-006**: Invalid mappings, unsupported payloads and corrupt lineage MUST reject before publishing a successor or changing the active pointer. Verification MUST never create an upgrade or other evidence.
- **FR-007**: Unchanged v2 execution MUST reuse identical projection bytes and preserve selection anchors, completion syntax, reviewer identity, review packages, receipts and complete ruling records.
- **FR-008**: Changes MUST stay in native adapters, existing tests and authored docs, preserving upstream ownership, 19 native skills, ten statuses and three review boundaries.

### Key Entities

- **Projection**: Immutable, versioned task content linked to canonical source hashes and its predecessor.
- **Selection ledger**: Existing upstream ledger with exact projection-byte and TNNN selection anchors.

## Clarifications

The clarification scan found no unresolved requirement. The approved first-lot scope retains v1 history and introduces complete v2 execution; no additional user answer was required.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A first invocation without any SDD base succeeds; file and symlink base cases reject without external writes.
- **SC-002**: All three reordered upstream briefs contain their mapped fixture bodies, including text after fences and at EOF.
- **SC-003**: Partial and complete v1 upgrade cases preserve predecessor hashes and select exactly the pending tasks or final-review-only mode.
- **SC-004**: Mapping, fence, lineage and verification-only negative cases publish no successor or pointer change.
- **SC-005**: Adapter, handoff and full fast checks pass, with vendored byte identity preserved and Mandatory Sync 5 aligned.

## Assumptions

- This is the first remediation lot, covering audit findings F1 and F2. Approval freshness, migration, host and full real-agent lifecycle qualification remain separate roadmap lots.
- Bash 3.2, awk, Git and shasum remain the runtime; no dependency or generic Markdown parser is added.
- Existing v1 evidence is preserved, never repaired by rewriting anchors to match altered bytes.
- Project artifacts and code comments are English. Commits require explicit user consent.
