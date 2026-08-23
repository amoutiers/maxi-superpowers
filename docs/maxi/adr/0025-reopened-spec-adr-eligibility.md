---
adr: 0025
slug: 0025-reopened-spec-adr-eligibility
spec: 0021-reopen-done-specs
status: accepted
created: 2026-08-23
updated: 2026-08-23
decider: "Antoine Moutiers"
supersedes: 0024
superseded_by: null
---

# ADR-0025: Reopened-Spec ADR Eligibility

## Context

ADR-0024 permits an accepted ADR to be amended while its creating
specification is active. A specification that has reached `done` can now be
reopened, so its current status alone no longer distinguishes unfinished work
from a later revision of completed work.

Reopening the specification must restore it as the canonical product source
without reopening the accepted ADRs that recorded its completed architectural
decisions. The existing status-only eligibility rule would otherwise permit an
in-place ADR amendment after `done → clarified`.

## Decision Drivers

- Preserve the consent-gated amendment workflow for an active specification
  that has never reached `done` (FR-006).
- Keep accepted ADR bodies immutable after their specification has been
  reopened from `done` (FR-004, FR-005).
- Record the rule in a durable artifact without adding an FSM status
  (FR-002).
- Retain normal supersession for changed architectural decisions.

## Considered Options

- **Option A: Use only the current specification status**
  - ✅ Preserves the existing implementation.
  - ❌ Violates driver: a reopened specification is active again, so this
    permits an amendment after completed work.

- **Option B: Infer prior completion from Git history**
  - ✅ Preserves driver: can identify historical `done` states.
  - ❌ Violates driver: eligibility depends on external history rather than a
    durable canonical artifact field.

- **Option C: Persist `reopened_from: done` on the specification**
  - ✅ Satisfies driver: records the completed-spec boundary in the canonical
    specification.
  - ✅ Satisfies driver: keeps the initial active-spec amendment route.
  - ✅ Satisfies driver: requires no FSM status or new command.

## Decision

Choose Option C. On an explicitly confirmed rollback from `done`,
`/maxi:revise` writes the monotone `reopened_from: done` field. `x-adr` may
use its existing consent-gated amendment procedure only when the linked
specification is active and lacks that field.

An accepted ADR linked to a specification marked `reopened_from: done` is
ineligible for in-place amendment regardless of the specification's current
status. A changed decision uses the normal supersession flow. This ADR
supersedes ADR-0024; ADR-0024's body remains unchanged.

## Consequences

- **Good:** Completed architectural decisions remain auditable after their
  product specification is reopened.
- **Good:** Initial, unfinished specifications retain the current amendment
  workflow.
- **Good:** The rule survives later status transitions without Git-history
  inference.
- **Bad:** `x-adr` must read one optional field from the linked spec.
- **Bad:** A reopened specification cannot amend any accepted ADR linked to it.

## Confirmation

`tests/check-revise.sh` verifies that `/maxi:revise` records the watermark
only after explicit consent. `tests/check-migrate-adr.sh` verifies the two
eligibility paths. `bash tests/run-all.sh` verifies the synchronized policy.
