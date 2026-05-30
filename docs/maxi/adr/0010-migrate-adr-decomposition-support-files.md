---
adr: 0010
slug: 0010-migrate-adr-decomposition-support-files
status: accepted
created: 2026-05-30
updated: 2026-05-30
decider: "Antoine Moutiers (project lead)"
related_specs: [0004-single-responsibility-migrate-adr-split]
related_principles: ["VI. Single Responsibility per Skill"]
related_requirements: [FR-005, FR-006, FR-007, FR-008]
supersedes: null
superseded_by: null
---

# ADR-0010: Decompose migrate-adr via per-source support files

## Context
`migrate-adr` (342 lines) fuses the Importer brief, the Discoverer brief, and the
orchestration in one file. Spec 0004 requires SRP compliance while keeping a single
user command and cross-source deduplication.

## Decision Drivers
- Principle VI (single responsibility per skill).
- Preserve UX: one command + cross-source dedup (don't fragment into separate commands).
- Match the existing supporting-file pattern (`x-adr/adr-template.md`, `x-develop/integration-reviewer-prompt.md`).
- Avoid skill-count change (no FSM / mandatory-sync-doc churn).

## Considered Options
- **Option A: Per-source support files** — `import-subagent.md` + `discover-subagent.md` behind the orchestrator.
  - ✅ Satisfies driver: module-level SRP (each volatile handler in its own file)
  - ✅ Satisfies driver: one command + dedup preserved; matches existing pattern; no skill-count change
  - ❌ Orchestrator stays ~245 lines (the coordination is the genuine bulk)
- **Option B: Two internal `x-` sub-skills** — `x-adr-import` + `x-adr-discover` invoked by the orchestrator.
  - ✅ First-class, independently testable skills
  - ❌ Violates driver: skill count 17→19; mandatory-sync doc churn; heavier dispatch
- **Option C: In-file reorganization only** —
  - ✅ Minimal churn
  - ❌ Violates driver: no real module-level SRP; the file stays one unit doing two things

## Decision
Chose **Option A**. The orchestrator keeps one coordinated responsibility (dispatch →
dedup → consent → index); each source-handler lives in its own brief.

## Consequences
- **Good:** import and discover logic edited independently; behavior preserved; boundary test-enforced.
- **Good:** no skill-count, FSM, or pipeline-doc impact.
- **Bad:** orchestrator remains moderately large (~245 lines); test assertions repointed across files.

## Confirmation
`tests/check-migrate-adr.sh` boundary assertions (each brief's signature content present in
its file AND absent from `SKILL.md`); full fast-tier suite green; behavior verified by the
repointed invariant suite.
