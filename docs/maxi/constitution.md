---
version: "1.2.0"
ratified: 2026-05-24
last_amended: 2026-05-29
---

# maxi-superpowers Constitution

## Core Principles

### I. Mandatory Spec-Driven Pipeline

Maxi bridges the gap between idea and implementation. Every feature goes through the full pipeline: `specify → clarify → plan → tasks → analyze → implement`. Design discipline (spec-kit) and ADR capture are the core value of maxi — without them, maxi is just a superpowers alias.

### II. Delegate to Superpowers, Never Duplicate

Maxi relies on superpowers as its implementation engine. If superpowers provides a capability (`writing-plans`, `executing-plans`, `test-driven-development`…), maxi delegates — it may wrap (constitution check, ADR scan) but never rewrites. Any duplication of a superpowers capability is a design defect.

### III. Strict Pipeline — No Skipping

Each pipeline phase exists because its responsibility deserves to be enforced. Bypassing a phase removes that responsibility entirely — it does not shorten it. The pipeline is non-negotiable: there are no shortcuts, even for a simple feature, even with the promise that "it'll be quick."

### IV. ADR for Every Non-Trivial Architectural Decision

Every structural choice (stack, pattern, dependency, pipeline deviation) generates an ADR — proposed automatically by the pipeline during `/maxi:plan` and `/maxi:implement`, written only with explicit consent, append-only after creation. Any revision goes through a supersede chain, never direct editing.

### V. Artifacts Over Chat

Every design decision must persist in a file. `spec.md`, `plan.md`, `tasks.md`, `analysis.md`, ADR — what lives only in chat does not exist. Chat is ephemeral; files are authoritative.

## Constraints

- **Constitution required first**: no pipeline skill can run without `docs/maxi/constitution.md`. The constitution is the reference baseline for `/maxi:analyze` (passes D and G).
- **Status managed by the pipeline only**: the `status:` field in `spec.md` must never be edited by hand — the pipeline advances it after completing its phase.
- **Strict vendoring**: superpowers skills vendored in `skills/` are byte-identical to `vendor/superpowers/skills/`. Any modification goes through `scripts/bump-superpowers.sh`, never direct editing.
- **Fast-tier tests mandatory**: `bash tests/run-all.sh` must pass before any commit. Integration (`--integration`) is optional but recommended for skill changes.
- **English only**: all project artifacts (specs, plans, ADRs, skills, documentation, code comments) must be written in English. This applies to all contributors and all AI agents working in this repository.

## Contributor Workflow

- Every new maxi-native skill is authored via `superpowers:writing-skills`. The constitution defines this requirement; harness docs and skills reference the constitution, never the reverse.
- Bugs and design flaws in the pipeline itself follow the maxi pipeline: spec → clarify → plan → tasks → analyze → implement.
- An ADR is required for any change that modifies a gating rule, adds a status to the FSM, or changes the maxi ↔ superpowers relationship.

## Governance

The constitution takes precedence over any other practice documented in this repo. In case of conflict between a skill and the constitution, the constitution wins — the skill must be updated. Any amendment to the constitution bumps `version` (semver), updates `last_amended`, and generates an ADR.

**Version**: 1.2.0 | **Ratified**: 2026-05-24 | **Last Amended**: 2026-05-29
