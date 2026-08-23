---
title: Fixed review boundaries
status: proposed
created: 2026-08-22
supersedes:
  - 0019-artifact-analysis-convergence
  - 0019-bounded-forward-artifact-replay
  - 0020-persisted-independent-handoff-reviews
---

# Fixed review boundaries

## Problem

The bounded-replay contract treats every structural correction as a new
versioned source. It automatically launches a review at each handoff, then
invalidates all descendants. A reviewer finding can therefore produce an
unbounded sequence of correction, review, task extraction, analysis, and
another correction. This is not a useful safety boundary.

## Decision

Keep the ten-state FSM and remove bounded replay, replay provenance, and
automatic handoff review loops. Reviews occur at three fixed, meaningful
boundaries only:

1. **Design review**: once `spec.md` and `plan.md` are both complete, before
   task extraction. It reviews the pair as one design.
2. **Readiness review**: the existing independent `analyze` phase, before
   implementation. It reviews the current spec, plan, and tasks together.
3. **Final implementation review**: the existing SDD final review after code
   completion. More than one independent reviewer may be used here.

The first arrival at the design-review boundary invokes the review. A later
correction never invokes a review, task extraction, analysis, or another
phase. It stops after the owning artifact write. Re-review is an explicit user
request, and only then may the review run again.

## Artifact and skill changes

- Remove `replay_contract`, `replay_continuation`, structural revision and
  contributor metadata, the replay planner, its fixtures, and the automatic
  review-handoff protocol.
- Replace internal `x-review` with the public `review` skill. It owns the
  single persisted design-review record and a dedicated read-only
  artifact-design reviewer brief. The reviewer receives the complete current
  `spec.md` and `plan.md` bytes, their paths and SHA-256 values, applicable
  constitution requirements, and complete bytes for every accepted ADR named
  by `spec.md`'s `related_adrs`. It returns complete findings plus
  exactly one final `VERDICT: approved` or `VERDICT: rejected` line; any absent,
  malformed, duplicate, contradictory, or nonterminal verdict fails without a
  write.
- A Critical or Important finding blocks only when the reviewed design must
  change because it violates a requirement or success criterion; adds behavior
  beyond the reviewed spec and owning task; is technically infeasible or
  materially incorrect; violates established architecture ownership or
  boundaries; omits or contradicts a required public contract; leaves task
  decomposition or dependency order unable to deliver the spec; weakens a
  safety control; or leaves verification insufficient.
- Task `Files` lists identify expected primary edits, not implementation
  allowlists. Callers, module declarations, registrations, fixtures, manifests,
  generated metadata, and lockfiles are nonblocking mechanical closure when
  they only implement the reviewed owning task without adding behavior beyond
  the reviewed spec and task. This does not excuse an infeasible design.
- Bind a design review to the exact current `spec.md` and `plan.md` bytes. A
  correction makes that record stale, but does nothing else automatically.
- Make `tasks` require a current approved design review. If it is missing or
  stale, report the condition and stop; the user can request `/maxi:review`.
- Retain `analyze` as the readiness review and the existing SDD final review.
  Do not create another review framework for either boundary.

## Non-goals

- No new FSM states.
- No automatic correction, replay, re-review, or descendant regeneration.
- No migration of existing historical specs or review records.
- No duplicate final-review mechanism alongside SDD.

## Acceptance criteria

- A correction to spec, plan, tasks, or analysis performs one owner write and
  stops without dispatching a reviewer or successor phase.
- The normal forward path runs exactly one design review after the plan and
  before tasks.
- A stale or missing design review prevents task extraction with a concise,
  actionable message and no write.
- `analyze` remains the only readiness gate before implementation.
- Existing SDD task and final implementation review behavior remains intact.
- The deterministic suite proves that no automatic sequence can contain two
  review dispatches without a new user request.
- All five mandatory pipeline documents, native-skill inventory, and tests
  describe the same contract.

## Migration

The new behavior applies to future specs. Existing marker-bound specs are
treated as ordinary specs on their next explicit owner action; no historical
artifact is rewritten merely to remove old metadata.
