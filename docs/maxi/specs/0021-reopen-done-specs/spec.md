---
slug: 0021-reopen-done-specs
created: 2026-08-23
updated: 2026-08-23
status: implementing
parked_from: null
related_adrs:
  - 0025-reopened-spec-adr-eligibility
---

# Feature Specification: Reopen Completed Specs

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Revise a completed specification (Priority: P1)

A maintainer can revise a specification whose implementation previously reached
`done`, so that the canonical specification again describes the intended
behaviour and the appropriate downstream pipeline work can be regenerated.

**Why this priority**: `done` records completed implementation, not delivery or
permanent immutability of the product specification.

**Independent Test**: Invoke `/maxi:revise` for a `done` specification, accept
the suggested rollback, and inspect its frontmatter and revision note.

**Acceptance Scenarios**:

1. **Given** a specification at `done`, **When** its requirements change and
   the maintainer explicitly confirms the suggested rollback, **Then** the
   specification moves to the appropriate earlier phase and records
   `reopened_from: done` permanently.
2. **Given** a reopened specification, **When** its downstream artefacts belong
   to later phases, **Then** they remain on disk as stale artefacts for their
   owning phases to regenerate.

---

### User Story 2 - Preserve ADR history after reopening (Priority: P1)

A maintainer reopening a completed specification retains an immutable record of
every accepted ADR already associated with that specification.

**Why this priority**: Reopening a product requirement must not rewrite the
architectural decisions that led to a completed implementation.

**Independent Test**: Detect a changed decision for a reopened specification
and verify that `x-adr` proposes a new superseding ADR rather than an amendment.

**Acceptance Scenarios**:

1. **Given** an accepted ADR linked to a specification marked
   `reopened_from: done`, **When** its decision changes, **Then** `x-adr`
   proposes the existing supersession flow and does not edit the ADR body.
2. **Given** an accepted ADR linked to a specification that has never reached
   `done`, **When** its decision changes while the specification is active,
   **Then** the existing consent-gated amendment flow remains available.

### Edge Cases

- `reopened_from: done` is monotone: later rollbacks or resumptions cannot
  remove or weaken it.
- A specification reopened more than once retains the same marker and keeps
  its accepted ADRs ineligible for amendment.
- A missing or `null` ADR creating-spec link continues to use supersession.
- A declined revision or ADR proposal writes no file.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `/maxi:revise` MUST accept a specification at `done` and use its
  existing A+ rollback selection and explicit-consent boundary.
- **FR-002**: A confirmed rollback from `done` MUST set
  `reopened_from: done`, retain it on every later status transition, and append
  a dated revision note.
- **FR-003**: `/maxi:revise` MUST not infer that `done` means shipped.
- **FR-004**: `x-adr` MUST treat every accepted ADR linked to a specification
  marked `reopened_from: done` as ineligible for an in-place amendment,
  regardless of that specification's current status.
- **FR-005**: An ineligible ADR change under FR-004 MUST use the existing
  supersession flow; accepted ADR body content remains unchanged.
- **FR-006**: The consent-gated active-spec amendment flow MUST remain available
  for ADRs linked to active specifications that have never reached `done`.
- **FR-007**: The Constitution, pipeline documentation, session guidance,
  contributor guidance, ADR guidance, and deterministic checks MUST describe
  the same post-reopening eligibility rule.
- **FR-008**: The change MUST create an ADR that supersedes
  `0024-active-spec-adr-amendment` without revising it.

## Clarifications

**Q: Does reopening a completed specification make its ADRs editable again?**
A: No. The `reopened_from: done` marker permanently routes decision changes for
that specification's accepted ADRs to supersession.

**Q: May an ADR be amended before its creating specification first reaches
`done`?**
A: Yes. The existing explicit-consent amendment route remains available while
the specification is active and has never reached `done`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A focused deterministic check proves that `/maxi:revise` can
  reopen a `done` specification only after explicit confirmation.
- **SC-002**: A focused deterministic check proves that an ADR linked to a
  `reopened_from: done` specification always takes the supersession route.
- **SC-003**: A focused deterministic check proves that an otherwise eligible
  ADR for a specification that has never reached `done` can still use the
  amendment route.
- **SC-004**: `bash tests/run-all.sh` passes with the pipeline and governance
  documents synchronized.

## Assumptions

- `reopened_from: done` is an optional specification-frontmatter field written
  only by `/maxi:revise` when reopening a completed specification.
- Existing accepted ADRs retain their current files and identities; only normal
  supersession metadata may be updated by the existing supersession flow.
- This feature changes the Maxi pipeline itself and therefore requires a new
  superseding ADR.
