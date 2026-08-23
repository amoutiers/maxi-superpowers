# Specification Analysis Report

Generated: 2026-08-23
Spec: `docs/maxi/specs/0021-reopen-done-specs/spec.md` (status: tasked)

## Findings

No issues found.

| Pass | Result | Evidence |
|------|--------|----------|
| A. Duplication | None | FR-001 through FR-008 have distinct lifecycle, eligibility, documentation, and ADR responsibilities. |
| B. Ambiguity | None | The eligibility condition, `reopened_from: done` value, consent boundary, and supersession outcome are explicit. |
| C. Underspecification | None | Both user stories have acceptance scenarios and independent tests; every requirement names its owning behavior. |
| D. Constitution Alignment | None | The plan preserves the ten-state FSM, consent gates, skill ownership, and ADR recording requirement. |
| E. Coverage | None | Every FR and SC maps to at least one extracted task. |
| F. Inconsistency | None | Spec, plan, and tasks use the same `reopened_from: done`, initial-lifecycle amendment, and post-reopening supersession terminology. |
| G. ADR Alignment | None | ADR-0025 is accepted and linked from the spec. References to superseded ADR-0024 are explicit historical supersession checks, not current-policy references. No missing consequential ADR, ADR-constitution conflict, stale current reference, or cyclic supersession chain was found. |

## Coverage Summary

| Requirement | Has Task? | Task IDs | Notes |
|-------------|-----------|----------|-------|
| FR-001 | Yes | T002 | Allows `done` as a revision source. |
| FR-002 | Yes | T002 | Writes and preserves the reopening watermark. |
| FR-003 | Yes | T002 | Removes the shipped inference. |
| FR-004 | Yes | T002 | Checks the watermark before amendment eligibility. |
| FR-005 | Yes | T002, T003 | Preserves normal supersession and verifies it. |
| FR-006 | Yes | T002 | Retains the initial-lifecycle amendment path. |
| FR-007 | Yes | T003 | Synchronizes governance and deterministic checks. |
| FR-008 | Yes | T003 | Verifies the accepted ADR-0025 supersession. |
| SC-001 | Yes | T001, T002 | Deterministic rollback coverage. |
| SC-002 | Yes | T001, T002 | Deterministic reopened-spec eligibility coverage. |
| SC-003 | Yes | T001, T002 | Deterministic initial-lifecycle eligibility coverage. |
| SC-004 | Yes | T004 | Full fast-tier verification. |

## Constitution Alignment Issues

None found.

## ADR Alignment Issues

None found.

## Unmapped Tasks

None found. T001 is foundational and T004 is cross-cutting verification; T002
and T003 are labelled for both user stories because they implement one shared
lifecycle boundary.

## Metrics

- Total Requirements (FR + SC): 12
- Total Tasks: 4
- Coverage: 100%
- Ambiguity Count: 0
- Duplication Count: 0
- Critical Issues Count: 0
- ADRs Recorded: 25 total, 1 applicable accepted ADR

## Next Actions

The readiness review is complete. The specification may proceed to
`/maxi:implement`.
