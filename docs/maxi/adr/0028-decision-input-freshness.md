---
adr: 0028
slug: 0028-decision-input-freshness
spec: 0024-decision-input-freshness
status: accepted
created: 2026-09-05
updated: 2026-09-05
decider: "Antoine Moutiers"
supersedes: 0026
superseded_by: null
---

# ADR-0028: Bind Approvals to Decision Inputs

## Context

Design and readiness approvals can remain valid after constitution or ADR changes. ADR-0026 binds readiness to spec, plan and tasks but omits these governing inputs. Constitution principles III and IV require enforceable gates and an explicit architectural decision.

## Decision Drivers

- Detect changed governing inputs before task extraction or implementation.
- Preserve ordinary readiness progress and existing review ownership.
- Keep validation deterministic without new runtime dependencies.

## Considered Options

- **A. Hash the constitution and complete ADR set.**
  - ✅ Satisfies deterministic detection and dependency constraints.
  - ❌ May invalidate approval after an unrelated ADR change.
- **B. Hash only selectively referenced ADRs.**
  - ✅ Reduces unnecessary invalidation.
  - ❌ Violates complete detection without additional dependency tracking.
- **C. Retain current contracts.**
  - ✅ Requires no migration.
  - ❌ Violates detection of changed governing inputs.

## Decision

Choose A. Compute one SHA-256 digest over a sorted manifest of project-relative names and exact hashes for the constitution and every direct ADR Markdown file except generated README.md, regardless of status.

Reject missing required inputs, symlinks, unsupported entries and ambiguous names. Absent and empty ADR directories are equivalent.

Add this digest to `maxi-readiness-v2` and `maxi-design-review-v1`. Capture reviewed inputs before review, compare them before writes, and require stampers to check the original dependency digest.

Preserve exact design spec/plan hashes and existing readiness structural projections. Verify through installed helpers before extraction and every implementation start or resume. Legacy approvals require an actual new review or analysis; never silently upgrade them.

## Consequences

- **Good:** Changed governing inputs invalidate both approval gates.
- **Good:** Existing phase owners, three review boundaries and ten statuses remain.
- **Bad:** Unrelated ADR changes may require another review.
- **Bad:** Existing readiness v1 and unstamped design approvals must be regenerated.

## Confirmation

Mutation tests cover constitution and ADR content, membership, names and status; interval changes; malformed inputs; legacy rejection; allowed readiness progress; and installed-helper verification. Run focused checks, the full fast suite and installed readiness integration.
