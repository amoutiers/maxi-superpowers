---
adr: 0029
slug: 0029-convergent-design-workflow
spec: 0025-convergent-design-workflow
status: accepted
created: 2026-09-08
updated: 2026-09-08
decider: Antoine Moutiers
supersedes: 0022
superseded_by: null
---

# ADR-0029: Convergent Initial Specs and Revisions

## Context

Terminal corrections prevent automatic replay but force users to coordinate repeated edits and reviews. Initial specification also repeats elicitation and approval. Preserve constitution principles II, III, V, and VI while implementing spec requirements FR-001 through FR-019.

## Decision Drivers

- Remove redundant questions and manual command relays.
- Bound review repetition without forcing approval.
- Preserve artifact ownership, phase responsibilities, and evidence integrity.

## Considered Options

- **A: Keep terminal corrections.** Preserves boundaries but fails the command-relay reduction objective.
- **B: Restore unlimited automatic replay.** Removes relays but fails the bounded-review objective.
- **C: Coordinate bounded design operations.** Satisfies all three drivers; requires durable continuation within the existing report.

## Decision

Choose C.

Existing native entry points coordinate the requested goal through existing owners. Spec-only requests end after actual clarification; explicit design-validation requests include planning and review. Reuse supplied answers and approval of the exact design. Produce one canonical spec through native adaptations of delegated Superpowers skills.

Allow at most two independent review dispatches per operation, with one consolidated correction between them. Preserve continuity across interruption. Exhaustion or missing continuity stops with a concrete diagnosis, never fabricated approval or an automatic allowance reset.

Retain report-only reviews, explicit narrower stop points, separate ADR approval, lifecycle safeguards, the ten-state FSM, and all three review boundaries. Preserve exact hashes, full decision-input digests, atomic publication, and installed verifiers.

This supersedes ADR-0022. It refines ADR-0023’s explicit re-review clause and ADR-0025’s rollback confirmation wording to reuse explicit authorization; their remaining safeguards stay effective.

## Consequences

- Fewer redundant user turns and repeated design changes.
- Genuine unresolved defects still block completion.
- Some operations require a user decision after two passes.

## Confirmation

Behavioral scenarios verify initial creation, revision, scope limits, interruption, stale inputs, and dispatch counts. Run the fast suite and synchronize the five pipeline documents.
