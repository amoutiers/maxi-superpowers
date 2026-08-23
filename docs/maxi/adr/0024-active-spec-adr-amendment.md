---
adr: 0024
slug: 0024-active-spec-adr-amendment
status: superseded
created: 2026-08-23
updated: 2026-08-23
decider: "Antoine Moutiers"
spec: 0020-active-spec-adr-amendment
supersedes: 0012
superseded_by: 0025
---

# ADR-0024: Active-Spec ADR Amendments with Direct Spec Links

## Context

An architectural decision can evolve while the spec that introduced it remains
active. A superseding ADR for each implementation-driven refinement creates
history without improving the record of the unfinished feature.

This ADR originally used the reverse `related_adrs` lookup to identify that
spec. The active [0020-active-spec-adr-amendment/spec](../specs/0020-active-spec-adr-amendment/spec.md)
now requires the ADR itself to identify its creating spec. The scalar `spec`
field gives an unambiguous owner without adding a lifecycle status or a
parallel record.

This supersedes
[0012-traceability-direction-spec-to-adr](0012-traceability-direction-spec-to-adr.md):
the direct, singular creating-spec link is needed for amendment eligibility.
`related_adrs` remains the existing spec-side index for review and analysis.

## Decision Drivers

- Require explicit approval for every ADR write.
- Identify an ADR's creating spec without an ambiguous reverse lookup.
- Keep delivered, parked, and cancelled decisions append-only.
- Avoid a new FSM status, command, dependency, or migration of existing ADRs.

## Considered Options

- **Option A: Keep spec-to-ADR links only**
  - ✅ Preserves the former one-way traceability rule.
  - ❌ Violates driver: cannot identify the creating spec for an amendment.

- **Option B: Create a new ADR for this refinement**
  - ✅ Preserves the former immutable-body rule.
  - ❌ Violates driver: replaces the current decision while its creating spec is
    still active.

- **Option C: Amend this ADR and add one direct creating-spec link**
  - ✅ Satisfies driver: gives the existing active ADR an exact owner.
  - ✅ Satisfies driver: preserves an append-only record after the spec closes.
  - ✅ Satisfies driver: adds no new state, command, or historical migration.

## Decision

Choose Option C. Every newly written ADR carries `spec: <full-spec-slug>` when
created in an active spec, or `spec: null` when it is standalone. Existing ADRs
are unchanged; a missing or `null` value is ineligible for amendment.

While the recorded spec has status `drafting`, `specified`, `clarified`,
`planned`, `tasked`, `analyzed`, or `implementing`, an agent that detects an
architectural change to the accepted ADR proposes an amendment through internal
`x-adr`. It shows the full amended ADR and its exact diff, and writes only after
explicit `yes`.

An amendment preserves `adr`, `slug`, `spec`, `created`, `status`,
`supersedes`, and `superseded_by`, and refreshes `updated`. When the recorded
spec is `done`, `parked`, or `cancelled`, or the link is absent or `null`, the
existing supersession flow is the only revision path. `related_adrs` continues
to be updated for active-spec ADR creation and remains the spec-side index.

## Consequences

- **Good:** The agent can identify the ADR's owner directly at every active
  status.
- **Good:** ADR-0024 evolves with its unfinished spec rather than creating a
  replacement decision.
- **Good:** Historical ADRs retain their current bytes.
- **Bad:** The direct creating-spec relation supersedes the former
  spec-to-ADR-only rule.
- **Bad:** The agent must treat absent or standalone links as ineligible.

## Confirmation

`tests/check-templates.sh` verifies `spec:` in new ADR templates and fixtures.
`tests/check-migrate-adr.sh` verifies direct-link eligibility, explicit consent,
identity preservation, closed-spec supersession, and standalone migration
behavior. `bash tests/run-all.sh` must pass.
