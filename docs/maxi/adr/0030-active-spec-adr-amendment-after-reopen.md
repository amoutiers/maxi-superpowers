---
adr: 0030
slug: 0030-active-spec-adr-amendment-after-reopen
spec: null
design_cycle: 0
status: accepted
created: 2026-09-10
updated: 2026-09-11
decider: "Antoine Moutiers"
supersedes: 0025
superseded_by: null
---

# ADR-0030: Active-Spec ADR Amendment After Reopen

## Context

ADR-0025 treats every specification reopened from `done` as ineligible to
amend an accepted ADR. A simple reversal of that rule would be too broad: it
would also reopen ADRs from a prior conception of the same feature. A reopened
specification re-enters design work, where a decision created in that new
conception may need correction before delivery.

## Decision Drivers

- Allow an active design to correct only its current linked decision record.
- Keep ADRs from prior conceptions, and all closed, unlinked, and standalone
  ADRs immutable.
- Preserve a compact, durable boundary when a completed feature re-enters
  design.

## Considered Options

- **Option A: Keep a boolean reopening marker**
  - ❌ Cannot distinguish the ADRs created before and after one or more
    reopenings.

- **Option B: Use active-spec activity only**
  - ❌ Makes every historical ADR linked to a reopened spec amendable.

- **Option C: Record a design-cycle number on both specs and ADRs**
  - ✅ Identifies the ADRs created during the current conception.
  - ✅ Keeps supersession for historical, closed, missing, or unlinked ADRs.

## Decision

New specs start with `design_cycle: 0`. On every authorized `done` rollback,
`/maxi:revise` increments that integer; other rollbacks retain it. New ADRs
record the creating spec's cycle. Missing cycle values on historical artifacts
mean `0`.

An accepted ADR may be amended only when its direct `spec:` link equals the
current active spec and both records have the same `design_cycle`, including
after a rollback from `done`. An ADR linked to a different cycle, a missing or
null spec, or a parked, cancelled, or done spec remains immutable and is
revised only by supersession.

## Consequences

- **Good:** Current design corrections do not generate needless ADRs.
- **Good:** Historical ADRs remain a durable record of earlier conceptions.
- **Bad:** Specs and ADRs gain one small provenance field.

## Confirmation

The focused revision and ADR-routing tests cover amendments in the current
cycle and supersession for earlier, closed, or unlinked ADRs.
