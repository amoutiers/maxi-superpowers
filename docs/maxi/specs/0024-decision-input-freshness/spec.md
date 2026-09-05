---
slug: 0024-decision-input-freshness
created: 2026-09-05
updated: 2026-09-05
status: done
parked_from: null
related_adrs: [0028-decision-input-freshness]
---

# Feature Specification: Decision Input Freshness

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Extract tasks only from a current design approval (Priority: P1)

An operator changes the constitution or ADR log after design review and requests task extraction.

**Why this priority**: An approved design must reflect the decision inputs currently governing implementation.
**Independent Test**: Stamp an approved design, change one decision input, then verify rejection before task extraction writes anything.
**Acceptance Scenarios**:

1. **Given** unchanged reviewed inputs, **When** extraction verifies approval, **Then** verification succeeds.
2. **Given** a constitution or ADR content, name, membership or status change, **When** extraction verifies approval, **Then** it rejects without changing artifacts.
3. **Given** a decision-input mutation during review, **When** stamping compares against the original digest, **Then** it refuses to publish an approval.

### User Story 2 - Start and resume only with current readiness (Priority: P1)

An operator starts or resumes implementation after project decisions have changed.

**Why this priority**: Existing readiness v1 still passes after constitution-only mutation.
**Independent Test**: Stamp readiness, independently mutate decision inputs, and run the installed verifier before any dispatch.
**Acceptance Scenarios**:

1. **Given** stale decision inputs, **When** implementation starts or resumes, **Then** verification rejects before status, checkbox, pointer or dispatch changes.
2. **Given** only ordinary status/date or canonical checkbox progress, **When** readiness is verified, **Then** it remains valid.
3. **Given** legacy readiness v1 or an unstamped design approval, **When** a new consumer verifies it, **Then** it requires an actual new analysis or review without silently upgrading evidence.

### Edge Cases

- Missing constitution; absent versus empty ADR directory; generated ADR README changes.
- ADR add/remove/rename/content/status changes, including superseded and deprecated records.
- Symlinked components or files, unreadable files, nonregular Markdown entries and control characters in names.
- Malformed, duplicate, unknown or missing envelope fields; blocked outcomes and malformed hashes.
- Mutation during review, unchanged relocation, exact plan edits, structural artifact changes and allowed progress-only changes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST bind both design approval and readiness to the exact constitution bytes and the names and exact bytes of every direct ADR Markdown file except generated README.md, regardless of ADR status.
- **FR-002**: System MUST compute a deterministic project-relative digest, sorted under LC_ALL=C. Absent and empty ADR directories are equivalent; moving an unchanged project does not change this digest.
- **FR-003**: System MUST reject missing, unreadable, symlinked or nonregular required inputs, symlinked path components, unsupported ADR entries and control characters in manifest names without emitting a digest or publishing evidence.
- **FR-004**: System MUST emit maxi-design-review-v1 with exact spec/plan hashes, decision-input digest and the actual independent verdict; only approved current evidence permits task extraction.
- **FR-005**: System MUST emit maxi-readiness-v2 with the decision-input digest and preserve existing structural spec/tasks projections, exact plan hash, outcome and critical-issue checks. Success remains exactly READINESS_VERIFIED.
- **FR-006**: System MUST capture hashes before reading and reviewing their inputs, supply the corresponding content to the reviewer, and compare before/after hashes before source/status changes. Stampers MUST compare the original supplied decision-input digest with current inputs before publishing.
- **FR-007**: System MUST reject legacy readiness v1 and unstamped design approvals without rewriting them; regenerate evidence only through the existing review or analyze owner.
- **FR-008**: System MUST resolve verification helpers from loaded installed skill locations, never a client repository fallback. All artifacts MUST be physical regular files inside the explicit project root; readiness artifacts remain colocated.
- **FR-009**: System MUST preserve explicit re-review, terminal corrections, phase owners, 19 native skills, ten FSM states and the three fixed review boundaries.
- **FR-010**: System MUST preserve existing malformed-metadata, hash, symlink and non-structural-progress regressions and synchronize the five pipeline documents with changed contracts.

### Key Entities *(include if feature involves data)*

- **Decision-input digest**: SHA-256 of an unambiguous sorted manifest of project-relative input names and exact file hashes.
- **Approval envelope**: Versioned metadata binding the reviewed artifacts and decision inputs to the owner-produced review result.

## Clarifications

The approved F3 scope and roadmap resolve the input set, conservative invalidation, legacy rejection and phase ownership. No additional user question was required.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Constitution and each ADR mutation category reject both formerly passing approval gates.
- **SC-002**: Changed-during-review inputs reject stamping without changing existing evidence; failed verification changes no source artifact or execution pointer.
- **SC-003**: Unchanged inputs, allowed readiness progress and unchanged project relocation verify successfully; malformed and legacy evidence fail.
- **SC-004**: Focused tests and the full fast suite pass, and the installed readiness integration verifies the new explicit-root command and matching helper snapshot.

## Assumptions

- This lot covers audit F3 only. Client migrations, host behavior and complete interrupted real-agent implementation qualification remain later roadmap lots.
- Hashing every ADR may require a new review after an unrelated ADR change. Selective dependency tracking is excluded.
- Use existing Bash 3.2-compatible scripts, standard tools and test harnesses. Add no runtime dependency or generalized parser framework.
- Keep vendored skills byte-identical. Author artifacts and code comments in English.
- Local verified commits are allowed; push, merge and PR actions still require explicit authorization.
