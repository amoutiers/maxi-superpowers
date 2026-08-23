---
version: "1.4.2"
created: 2026-05-24
updated: 2026-08-23
---

# maxi-superpowers Constitution

## Core Principles

### I. Mandatory Spec-Driven Pipeline

Maxi bridges the gap between idea and implementation. Every feature goes through the full pipeline: `specify → clarify → plan → tasks → analyze → implement`. Design discipline (spec-kit) and ADR capture are the core value of maxi — without them, maxi is just a superpowers alias.

### II. Delegate to Superpowers, Never Duplicate

Maxi relies on superpowers as its implementation engine. If superpowers provides a capability (`writing-plans`, `executing-plans`, `test-driven-development`…), maxi delegates — it may wrap (constitution check, ADR scan) but never rewrites. Any duplication of a superpowers capability is a design defect.

### III. Strict Pipeline — No Skipping

Each pipeline phase exists because its responsibility deserves to be enforced. Bypassing a phase removes that responsibility entirely — it does not shorten it. The pipeline is non-negotiable: there are no shortcuts, even for a simple feature, even with the promise that "it'll be quick."

**Ingress exception (migration / reverse-engineering).** Principle III governs *forward development* — there are no shortcuts to ship new work faster. Documenting already-implemented code is not forward development. Skills that ingest pre-existing implementations (migration or reverse-engineering — e.g. `migrate-from-speckit`, `migrate-from-brownfield`) MAY set an appropriate terminal status on spec creation, because the implementation already exists outside maxi. Such skills MUST (1) make the spec's provenance explicit — reverse-engineering skills (e.g. `migrate-from-brownfield`) via an `origin:` frontmatter field; status-inferring migrations (e.g. `migrate-from-speckit`) via the inferred status plus a `## Migration Notes` section — and (2) never alter the gating of forward-development specs.

### IV. ADR for Every Non-Trivial Architectural Decision

Every structural choice (stack, pattern, dependency, pipeline deviation) generates an ADR, proposed automatically by the pipeline and written only with explicit consent. Every new ADR records its creating spec through a direct `spec` link containing the full spec slug, or `spec: null` when it is standalone; existing ADRs are not migrated. That link enables the sole exception to append-only bodies: at `drafting`, `specified`, `clarified`, `planned`, `tasked`, `analyzed`, or `implementing`, an agent-proposed active-spec amendment may update an accepted ADR whose `spec` matches the current spec only after the full amended ADR and exact diff are shown and explicitly approved. Missing or null links and specs at `done`, `parked`, or `cancelled` are ineligible and use closed-spec supersession instead.

### V. Artifacts Over Chat

Every design decision must persist in a file. `spec.md`, `plan.md`, `tasks.md`, `analysis.md`, ADR — what lives only in chat does not exist. Chat is ephemeral; files are authoritative.

### VI. Single Responsibility per Skill

Every skill owns exactly one responsibility — one phase transition, one report, one managed document, or one coordinated goal. When a skill fuses concerns with independent reasons to change, extract them into separate units (support files or sub-skills) behind a single coordinator. Litmus: if two parts of a skill would change for unrelated reasons, they are separate responsibilities.

## Constraints

- **Constitution required first**: no pipeline skill can run without `docs/maxi/constitution.md`. The constitution is the reference baseline for `/maxi:analyze` (passes D and G).
- **Status managed by the pipeline only**: the `status:` field in `spec.md` must never be edited by hand — the pipeline advances it after completing its phase. Exception: migration / reverse-engineering ingress skills may set a status on creation per Principle III's ingress clause, provided they mark provenance (an `origin:` field for reverse-engineering, or inferred status plus Migration Notes for status-inferring migrations).
- **Strict vendoring**: superpowers skills vendored in `skills/` are byte-identical to `vendor/superpowers/skills/`. Any modification goes through `scripts/bump-superpowers.sh`, never direct editing.
- **Fast-tier tests mandatory**: `bash tests/run-all.sh` must pass before any commit. Integration (`--integration`) is optional but recommended for skill changes.
- **English only**: all project artifacts (specs, plans, ADRs, skills, documentation, code comments) must be written in English. This applies to all contributors and all AI agents working in this repository.

## Contributor Workflow

- Every new maxi-native skill is authored via `superpowers:writing-skills`. The constitution defines this requirement; harness docs and skills reference the constitution, never the reverse.
- Bugs and design flaws in the pipeline itself follow the maxi pipeline: spec → clarify → plan → tasks → analyze → implement.
- An ADR is required for any change that modifies a gating rule, adds a status to the FSM, or changes the maxi ↔ superpowers relationship.

## Governance

The constitution takes precedence over any other practice documented in this repo. In case of conflict between a skill and the constitution, the constitution wins — the skill must be updated. Any amendment to the constitution bumps `version` (semver), refreshes the `updated` date, and generates an ADR.

**Version**: 1.4.2 | **Created**: 2026-05-24 | **Updated**: 2026-08-23
