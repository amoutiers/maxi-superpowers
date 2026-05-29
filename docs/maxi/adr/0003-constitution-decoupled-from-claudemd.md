---
adr: 0003
slug: 0003-constitution-decoupled-from-claudemd
status: accepted
date: 2026-05-29
updated: 2026-05-29
decider: "Antoine Moutiers"
related_specs: ["0002-migrate-adr-review-fixes"]
related_principles: ["Governance — amendments require an ADR"]
related_requirements: ["FR-024", "FR-025"]
supersedes: null
superseded_by: null
---

# ADR-0003: Constitution decoupled from CLAUDE.md — one-way dependency direction

## Context

The constitution's Contributor Workflow stated that new skills are authored
"via `superpowers:writing-skills` (RED/GREEN/REFACTOR cycle documented in
`CLAUDE.md`)". This created a circular documentation dependency: the
constitution (the authoritative baseline) pointed *down* at CLAUDE.md (a
harness convenience doc), while CLAUDE.md and the skills already point *up*
at the constitution. During spec 0002, FR-022 rewrote CLAUDE.md's authoring
flow (brainstorm → spec → plan → writing-skills), which made the
constitution's reference stale and surfaced the circularity. Per the
constitution's own Governance clause, any amendment requires a version bump
and an ADR.

## Decision Drivers

- **Governance clause**: "Any amendment to the constitution bumps `version`
  (semver), updates `last_amended`, and generates an ADR." (related_requirements: FR-025)
- **Single source of truth**: the constitution must be the authoritative
  baseline, not a document that depends on a lower-tier file.
- **No circular doc dependencies**: a reference cycle makes either document
  unsafe to edit without touching the other.

## Considered Options

- **Option A: Remove the CLAUDE.md reference; one-way dependency (constitution ← docs/skills)** — the constitution states the requirement; harness docs reference it, never the reverse.
  - ✅ Satisfies driver: single source of truth
  - ✅ Satisfies driver: no circular doc dependencies
  - ❌ The RED/GREEN/REFACTOR detail now lives only inside the writing-skills skill, not cross-linked from the constitution
- **Option B: Keep the reference, update it to match the new CLAUDE.md flow** — re-point the parenthetical at the new four-step flow.
  - ✅ Preserves the cross-link
  - ❌ Violates driver: no circular doc dependencies (cycle persists)
  - ❌ Violates driver: single source of truth (constitution still depends on CLAUDE.md)
- **Option C: Move the authoring cycle entirely into the constitution** — inline the full RED/GREEN/REFACTOR detail into the constitution.
  - ✅ No external reference
  - ❌ Bloats the constitution with harness-level procedure that belongs in the skill

## Decision

Chose **Option A**. The constitution's Contributor Workflow now reads:
"Every new maxi-native skill is authored via `superpowers:writing-skills`.
The constitution defines this requirement; harness docs and skills reference
the constitution, never the reverse." Version bumped 1.1.0 → 1.2.0,
`last_amended` set to 2026-05-29.

## Consequences

- **Good:** The dependency direction is now strictly one-way; either document can be edited without creating staleness in the other.
- **Good:** The constitution is unambiguously the source of truth.
- **Bad:** The RED/GREEN/REFACTOR procedure is no longer cross-referenced from the constitution; a reader must open the writing-skills skill to find it.

## Confirmation

`tests/check-migrate-adr.sh` asserts the constitution contains no `CLAUDE.md`
or `RED/GREEN/REFACTOR` reference and is past version 1.1.0 (FR-024/025).
Future constitution amendments continue to require a version bump + ADR per
Governance.
