---
adr: 0009
slug: 0009-single-responsibility-per-skill
status: accepted
created: 2026-05-30
updated: 2026-05-30
decider: "Antoine Moutiers (project lead)"
related_specs: [0004-single-responsibility-migrate-adr-split]
related_principles: ["VI. Single Responsibility per Skill"]
related_requirements: [FR-001, FR-003]
supersedes: null
superseded_by: null
---

# ADR-0009: Adopt Single-Responsibility principle for skills

## Context
maxi has 17 native skills. A 2026-05-30 design review found `migrate-adr` fuses two
concerns (importing existing ADRs + discovering decisions from code) with independent
reasons to change. No written rule required one-responsibility-per-skill, so concern-fusion
could recur unnoticed. Constitution governance also requires an ADR for any amendment.

## Decision Drivers
- Governance: a constitution amendment requires an ADR.
- Maintainability/testability: skills small enough to reason about and test in isolation.
- Prevent concern-fusion regressions (the `migrate-adr` precedent).

## Considered Options
- **Option A: Constitution Core Principle (VI) + CLAUDE.md pointer** — codify SRP as a durable invariant.
  - ✅ Satisfies driver: checkable by `/maxi:analyze` (constitution-alignment passes)
  - ✅ Satisfies driver: durable, authoritative
  - ❌ Adds one more governed principle to honor
- **Option B: CLAUDE.md authoring convention only** — keep it as contributor guidance.
  - ✅ Lighter weight
  - ❌ Violates driver: not checked by `/maxi:analyze`; weaker authority; drifts from the constitution
- **Option C: Do nothing (reviewer judgment)** —
  - ✅ No overhead
  - ❌ Violates driver: concern-fusion recurs (migrate-adr proves it)

## Decision
Chose **Option A** — add Core Principle VI ("Single Responsibility per Skill") to the
constitution, with a one-line pointer from CLAUDE.md (no duplication, preserving the
spec-0002 one-way decoupling).

## Consequences
- **Good:** future skills are checked against SRP; migrate-adr is brought into compliance (spec 0004).
- **Good:** authors get a clear litmus (independent reasons to change ⇒ separate responsibilities).
- **Bad:** one more principle to honor; SRP-driven refactors add upfront work.

## Confirmation
`/maxi:analyze` constitution-alignment surfaces violations; spec 0004 enforces the boundary
for `migrate-adr` via `tests/check-migrate-adr.sh`.
