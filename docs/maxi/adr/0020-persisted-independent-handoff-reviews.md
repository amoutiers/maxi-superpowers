---
adr: 0020
slug: 0020-persisted-independent-handoff-reviews
status: superseded
created: 2026-08-03
updated: 2026-08-03
decider: "Antoine Moutiers"
supersedes: 0018
superseded_by: 0022
---

# ADR-0020: Persisted Independent Reviews at Pipeline Handoffs

## Context

ADR-0018 coupled independent final analysis with a convergence coordinator,
workflow ledger, and crash-recovery protocol. The replacement 0019
specification requires a simpler, durable independent review before planning,
before task extraction, and before implementation.

Review evidence must not live only in chat. The existing FSM must remain
unchanged, and a reviewer must be demonstrably separate from contexts that
structurally contributed to the reviewed artifact.

## Decision Drivers

- FR-017 through FR-023 require persisted contributor provenance, independent
  review records, verified reviewer contexts, and replay pauses at reviews.
- SC-007 through SC-009 require blocked successor phases without matching
  independent evidence.
- Constitution Principles II, III, V, and VI require delegation to the vendored
  review capability, strict gates, persisted decisions, and a dedicated owner.

## Considered Options

- **Option A: Versioned handoff review records with the existing FSM, selected**
  - ✅ Satisfies driver: persists review evidence and preserves the FSM.
  - ✅ Satisfies driver: validates reviewer context against contributors.
  - ✅ Satisfies driver: delegates review to `superpowers:requesting-code-review`.

- **Option B: Chat-only external reviews**
  - ❌ Violates driver: verdict and independence evidence are ephemeral.

- **Option C: Add review statuses to the FSM**
  - ❌ Violates driver: expands state without improving review evidence.

## Decision

Choose Option A. `x-review` is the sole writer of `reviews/spec-review.md`
and `reviews/plan-review.md`. It binds an approved review to the exact current
artifact path, revision, SHA-256, and harness-issued reviewer context. `plan`
and `tasks` validate their corresponding review record before any write or
status transition. `analyze` remains the independent final gate.

## Consequences

- **Good:** A single author cannot silently advance an artifact through all
  downstream phases.
- **Good:** Review records become stale when their reviewed artifact changes.
- **Bad:** Each review handoff requires a separate external reviewer context.
- **Bad:** A replay requires a new explicit confirmation after each handoff.

## Confirmation

Deterministic fixtures will reject self-review, stale reviews, context mismatch,
and content-hash mismatch; they will prove that review records resume only the
remaining minimal continuation.
