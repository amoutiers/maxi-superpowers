---
slug: 0020-active-spec-adr-amendment
created: 2026-08-23
updated: 2026-08-23
status: done
parked_from: null
related_adrs:
  - 0024-active-spec-adr-amendment
---

# Feature Specification: Active-spec ADR amendment

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Refine a decision while implementing its spec (Priority: P1)

An agent detecting that an architectural decision has changed while its creating spec is active proposes an amendment of the ADR whose `spec` frontmatter value identifies that spec. The maintainer then sees the exact change and explicitly approves or rejects it.

**Why this priority**: The ADR should track the decision that is actually developed without forcing a replacement record for a still-active feature.

**Independent Test**: Read `x-adr` and the active-spec session workflow and verify that an eligible detected change produces a consent-gated amendment while preserving ADR identity.

**Acceptance Scenarios**:

1. **Given** an accepted ADR has a `spec` value equal to the current active spec slug, **When** an agent detects that its decision has changed and the maintainer explicitly approves the shown diff, **Then** its body and `updated` date are changed while `adr`, `slug`, `spec`, and `created` are preserved.
2. **Given** an amendment is proposed, **When** the maintainer declines or gives an ambiguous answer twice, **Then** the ADR remains unchanged.

---

### User Story 2 - Preserve shipped-decision history (Priority: P1)

A maintainer changing a decision after the linked spec is complete receives the existing supersession flow rather than an in-place amendment.

**Why this priority**: Delivered architecture must retain an append-only, auditable record.

**Independent Test**: Read `x-adr` and verify that completed, parked, cancelled, or unlinked ADRs are ineligible for amendment and use supersession instead.

**Acceptance Scenarios**:

1. **Given** the linked spec has status `done`, **When** a maintainer wants to change its ADR, **Then** the skill offers a new superseding ADR instead of editing the existing one.
2. **Given** an ADR has `spec: null`, **When** a maintainer requests an amendment, **Then** the skill rejects the request and offers supersession instead.

### Edge Cases

- An ADR records exactly one creating spec through `spec: <full-spec-slug>`, or `spec: null` when it is created without an active spec.
- Existing ADRs are not migrated to add `spec`; a missing field is treated as ineligible for amendment.
- An ADR is amendable only while its creating spec has status `drafting`, `specified`, `clarified`, `planned`, `tasked`, `analyzed`, or `implementing`.
- `done`, `parked`, and `cancelled` specs never make an ADR eligible for amendment.
- An amendment never creates a new ADR, changes an ADR number or slug, or changes a supersession link.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: At every active spec status, the system MUST have the agent propose an amendment when it detects that an accepted ADR whose `spec` field equals the current spec slug has changed; active statuses are `drafting`, `specified`, `clarified`, `planned`, `tasked`, `analyzed`, and `implementing`.
- **FR-002**: Before an eligible amendment, the system MUST show the full amended ADR and an exact diff, then require explicit approval; `yes` authorizes the change and `no` or two ambiguous replies leave the ADR unchanged.
- **FR-003**: An approved amendment MUST preserve `adr`, `slug`, `spec`, `created`, `status`, `supersedes`, and `superseded_by`; it MAY update body sections and MUST refresh `updated`.
- **FR-004**: An ineligible requested amendment MUST retain the existing append-only policy and direct the maintainer to the supersession workflow.
- **FR-005**: The ADR template, migration guidance, Constitution, pipeline documentation, session guidance, architecture documentation, and contributor guidance MUST state the same direct-link, active-spec exception, and post-`done` append-only policy.
- **FR-006**: The fast tier MUST fail if `x-adr` loses the explicit approval, eligibility, identity-preservation, or supersession fallback rules.

## Clarifications

**Q: How long is an ADR linked to its creating spec amendable?**
A: Until that spec reaches `done`, including `implementing`.

**Q: What authorizes an amendment?**
A: The maintainer must see the change and explicitly approve it.

**Q: How is the creating spec recorded, including for standalone ADRs?**
A: Each new ADR uses one `spec` frontmatter value containing the creating spec
slug, or `null` when it has no creating spec. Existing ADRs are not migrated.

**Q: Which lifecycle states allow an amendment request?**
A: Every active status from `drafting` through `implementing`. `done`, `parked`,
and `cancelled` are closed and do not allow an amendment.

**Q: Who initiates an eligible amendment?**
A: The agent proposes it when it detects a decision change. The user only
approves or rejects the displayed amendment.

**Revised (2026-08-23):** Rolled back from `planned` to `clarified`. Change:
each ADR must carry a direct link to the spec that created it. The existing
`plan.md` and `reviews/design-review.md` are stale and must be regenerated.

**Revised (2026-08-23):** Rolled back from `clarified` to `specified`. Change:
the source specification omitted the direct ADR-to-creating-spec relationship;
the current requirements need clarification before they can be replanned.

**Revised (2026-08-23):** Rolled back from `planned` to `specified`. Change:
the source specification incorrectly requires a user-requested amendment path;
the intended agent-proposed model needs clarification before replanning.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every eligible amendment path in `x-adr` requires explicit approval and states the preserved identity fields.
- **SC-002**: Every ineligible amendment path states supersession as the only revision mechanism.
- **SC-003**: The fast tier passes after the skill and all six governance documents are synchronized.

## Assumptions

- Git history is sufficient revision history for an ADR while its recorded spec is active.
- The scalar `spec` frontmatter field is the source of amendment eligibility;
  `related_adrs` remains the spec-side index for review and analysis.
