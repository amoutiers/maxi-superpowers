---
slug: 001-sample-feature
created: "2026-05-08"
updated: "2026-05-08"
status: drafting
---

# Feature Specification: Sample Feature

## User Scenarios & Testing

### User Story 1 - Basic Usage (Priority: P1)

A user can invoke the sample feature and receive a result.

**Why this priority**: Core value delivery.

**Independent Test**: Run the feature with a sample input and verify output.

**Acceptance Scenarios**:

1. **Given** the feature is configured, **When** the user invokes it, **Then** a result is returned.

### Edge Cases

- What happens when no input is provided?

## Requirements

### Functional Requirements

- **FR-001**: System MUST accept a sample input.
- **FR-002**: System MUST return a deterministic result.

### Key Entities

- **SampleInput**: The data provided by the user.

## Clarifications

<!--
  Populated by `/maxi:clarify`. Each entry is a Q/A pair recording how an
  ambiguity in the spec was resolved. Leave empty until `/maxi:clarify` runs.
-->

## Success Criteria

### Measurable Outcomes

- **SC-001**: Feature completes within 1 second for typical inputs.

## Assumptions

- User has already run `/maxi:constitution` to establish project principles.
- A `docs/constitution.md` file exists in the project.
