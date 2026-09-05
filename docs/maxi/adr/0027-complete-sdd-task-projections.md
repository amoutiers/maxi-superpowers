---
adr: 0027
slug: 0027-complete-sdd-task-projections
spec: 0023-sdd-handoff-remediation
status: accepted
created: 2026-09-05
updated: 2026-09-05
decider: "Antoine Moutiers"
supersedes: null
superseded_by: null
---

# ADR-0027: Complete SDD Task Projections

## Context

The current adapter omits plan task bodies and fails when the SDD base is absent. This decision complements [0021-align-superpowers-v6-3-model](0021-align-superpowers-v6-3-model.md), preserving upstream execution and review ownership.

## Decision Drivers

- Deliver complete reviewed instructions (FR-002, FR-003).
- Preserve immutable execution history (FR-004, FR-005).
- Retain upstream ownership and native boundaries (Constitution II, FR-008).

## Considered Options

- **A: Complete, versioned native projections.** ✅ Satisfies complete delivery and immutable history.
- **B: Rewrite existing projections.** ❌ Violates immutable history.
- **C: Modify upstream task extraction.** ❌ Violates the native boundary and strict vendoring.

## Decision

Choose A. Initialize missing canonical SDD directories safely. Emit `maxi-v2` projections containing complete mapped task bodies, with compatible fence delimiters. Reject ambiguous mappings and unsupported payloads.

Preserve v1 files and ledgers as immutable predecessors. Carry forward only validated completions. Require final review even when an upgrade leaves no pending tasks. Verification performs no migration or writes.

## Consequences

- **Good:** Implementers receive the complete reviewed task.
- **Good:** Existing execution history remains auditable.
- **Bad:** Native validators must support both historical formats.
- **Bad:** Ambiguous legacy mappings require correction before resuming.

## Confirmation

Adapter tests cover fresh startup, complete upstream briefs, partial and complete v1 upgrades, unchanged predecessor hashes, invalid-input rejection and verification without writes. Full fast tests and Mandatory Sync 5 must pass.
