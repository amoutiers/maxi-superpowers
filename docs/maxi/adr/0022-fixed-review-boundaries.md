---
adr: 0022
slug: 0022-fixed-review-boundaries
status: accepted
created: 2026-08-22
updated: 2026-08-22
decider: "Antoine Moutiers"
supersedes:
  - 0019
  - 0020
superseded_by: null
---

# ADR-0022: Fixed Review Boundaries

## Context

ADR-0019 introduced forward-only replay and ADR-0020 added independent review
records at successive handoffs. Together, those mechanisms can automatically
invalidate descendants and repeatedly return work to review after a correction.
The current pipeline needs strict review gates without an automatic review or
continuation loop.

The ten-state FSM and the upstream SDD terminal review remain established
constraints. Constitution Principles II, III, V, and VI require delegation to
Superpowers, strict phase discipline, durable artifacts, and a single owner per
responsibility.

## Decision Drivers

- Keep the ten-state FSM while retaining meaningful review gates.
- Make a correction terminate at its owning artifact write unless the user
  explicitly requests another review.
- Keep upstream SDD as the sole owner of task review, fix rounds, and the
  final implementation review.
- Persist only the design-review evidence required to gate task extraction.

## Considered Options

- **Option A: Three fixed review boundaries, selected**
  - ✅ Satisfies driver: keeps review at design, readiness, and final
    implementation boundaries.
  - ✅ Satisfies driver: corrections cannot automatically dispatch another
    review or successor phase.
  - ✅ Satisfies driver: preserves upstream SDD final-review ownership.

- **Option B: Retain automatic replay with versioned handoff reviews**
  - ✅ Preserves the prior stale-descendant model.
  - ❌ Violates driver: a correction can automatically re-enter review and
    later phases.

- **Option C: Add review statuses to the FSM**
  - ❌ Violates driver: expands the fixed FSM without adding a necessary
    transition.

## Decision

Choose Option A. The public `/maxi:review` skill explicitly writes
`reviews/design-review.md` for the exact current `spec.md` and `plan.md`;
`/maxi:tasks` requires that approved record. `/maxi:analyze` remains the
readiness review before implementation, and upstream SDD retains the final
implementation review. Corrections stop after their owner write. Re-review is
only an explicit `/maxi:review` request.

## Consequences

- **Good:** Review happens at three stable, understandable boundaries.
- **Good:** Corrections have one owner and do not trigger hidden pipeline work.
- **Good:** SDD keeps its existing task-review, fix-round, and final-review
  protocol.
- **Bad:** A user must explicitly request a fresh design review after changing
  a reviewed spec or plan.
- **Bad:** Existing replay metadata is no longer interpreted as an execution
  contract.

## Confirmation

`tests/check-review-boundaries.sh` verifies one normal design-review entry
point, terminal corrections, stale-review task blocking, explicit re-review,
retained readiness review, and retained SDD final-review ownership.
`tests/check-skill-count.sh` verifies the fixed-boundary documentation across
the Mandatory Sync 5 documents and README.
