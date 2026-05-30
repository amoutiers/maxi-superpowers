---
slug: 0009-using-maxi
created: 2026-05-30
updated: 2026-05-30
status: done
origin: reverse-engineered
source_sha: 7f945f8a8548bf1b4b123d28cc097e2cca897c68
parked_from: null
---

# Feature Specification: maxi Session Introduction (using-maxi)

The `using-maxi` skill is a session-scoped onboarding document injected at session start. It orients Claude (or the user) to the maxi spec-driven pipeline by asserting the phase sequence, the per-feature artifact layout, the spec status state machine, the phase-gating rules for every forward and lifecycle skill, getting-started entry points (including the three migration utilities), and a set of inviolable key rules. Its only behavioral element is a `<SUBAGENT-STOP>` guard instructing dispatched subagents to skip the skill; everything else is reference guidance whose correctness is the requirement.

## User Scenarios & Testing

### User Story 1 - Session-start orientation to the pipeline (Priority: P1)

At the start of a maxi session, Claude reads `using-maxi` and learns the ordered pipeline of commands and the status each produces.

**Why this priority**: This is the skill's primary purpose — without an accurate pipeline map at turn 0, Claude misroutes the user through phases. Stale content here was the root cause of the 2026-05-24 design-review defect, making accuracy of this content the highest-value property.

**Independent Test**: Open `skills/using-maxi/SKILL.md` and confirm it lists each pipeline command with the status it produces (constitution → specify/specified → clarify/clarified → plan/planned → tasks/tasked → analyze/analyzed → implement/implementing→done) and that ADRs are captured automatically during plan and implement.

**Acceptance Scenarios**:
1. **Given** a fresh session, **When** Claude reads the skill, **Then** it finds `/maxi:constitution` documented as REQUIRED FIRST.
2. **Given** the pipeline block, **When** Claude reads each line, **Then** every forward command names the status it produces.
3. **Given** the pipeline block, **When** Claude reads the ADR note, **Then** it states ADRs are captured automatically during `/maxi:plan` and `/maxi:implement` with consent before writing.

### User Story 2 - Knowing where artifacts live (Priority: P1)

Claude needs to locate per-project artifacts to read and write them in the correct places.

**Why this priority**: Incorrect artifact paths cause skills to read/write the wrong locations, breaking the whole pipeline; the layout must be stated authoritatively.

**Independent Test**: Confirm the Artifact Locations tree shows `docs/maxi/constitution.md`, `docs/maxi/adr/` (with README index and `NNNN-slug.md`), and `docs/maxi/specs/NNNN-feature-slug/` containing spec.md, plan.md, tasks.md, analysis.md, research.md, data-model.md and a contracts/ dir.

**Acceptance Scenarios**:
1. **Given** the Artifact Locations section, **When** Claude reads it, **Then** the constitution path is `docs/maxi/constitution.md` and is marked mandatory before any spec work.
2. **Given** the specs subtree, **When** Claude reads it, **Then** `spec.md` is noted as carrying status/updated/slug in YAML frontmatter.
3. **Given** the adr subtree, **When** Claude reads it, **Then** `analysis.md` is described as a read-only audit written by `/maxi:analyze`.

### User Story 3 - Enforcing phase gating and the status machine (Priority: P1)

Claude must know the required input status and produced status for each skill so it can gate phases and explain ordering.

**Why this priority**: The phase-gating table is the operational contract for ordering; if it is wrong, skills run out of order. The CLAUDE.md sync mandate exists specifically to keep this table accurate.

**Independent Test**: Confirm the Status State Machine string and the two gating tables (forward + lifecycle) are present and internally consistent with the pipeline block.

**Acceptance Scenarios**:
1. **Given** the Status State Machine, **When** Claude reads it, **Then** it is `drafting → specified → clarified → planned → tasked → analyzed → implementing → done`.
2. **Given** the forward gating table, **When** Claude reads `/maxi:analyze`, **Then** required status is `tasked`+ with re-run tolerance on `analyzed`/`implementing`/`done`.
3. **Given** the lifecycle table, **When** Claude reads `/maxi:revise`, **Then** it accepts `clarified` through `implementing` and rolls back to `clarified`/`planned`/`tasked`/`analyzed`.
4. **Given** the gating preamble, **When** Claude reads it, **Then** constitution is stated mandatory and all workflow skills except `constitution` refuse to run when `docs/maxi/constitution.md` is missing.

### User Story 4 - Getting started and migration entry points (Priority: P2)

A newcomer or a brownfield/spec-kit adopter needs to know which command to run first.

**Why this priority**: Correct onboarding routing matters but is secondary to the core pipeline/gating accuracy; misrouting here is recoverable.

**Independent Test**: Confirm Getting Started names `/maxi:migrate-from-speckit`, `/maxi:migrate-from-brownfield` (spec at `status: done`, `origin: reverse-engineered`), and `/maxi:migrate-adr`, then the numbered constitution → specify → follow-pipeline steps.

**Acceptance Scenarios**:
1. **Given** a spec-kit project, **When** Claude reads Getting Started, **Then** it is told to run `/maxi:migrate-from-speckit` first, non-destructively.
2. **Given** a brownfield codebase with no specs, **When** Claude reads Getting Started, **Then** it is told to run `/maxi:migrate-from-brownfield` to produce baselines at `status: done` marked `origin: reverse-engineered`.
3. **Given** a fresh project, **When** Claude reads the numbered steps, **Then** step 1 is `/maxi:constitution` and step 2 is `/maxi:specify`.

### User Story 5 - Honoring the key rules (Priority: P1)

Claude must obey the invariants that protect artifact integrity (status frontmatter, updated field, analyze read-only, ADR append-only).

**Why this priority**: These rules prevent corruption of pipeline state and ADR history; violating them silently breaks gating and provenance.

**Independent Test**: Confirm the Key Rules list enumerates: never skip constitution; never hand-edit status; bump `updated:` to today's ISO date in the same write; analyze is read-only; analyze requires constitution; ADRs append-only via superseding; tolerate absent optional fields.

**Acceptance Scenarios**:
1. **Given** the Key Rules, **When** Claude considers editing frontmatter, **Then** it is told never to hand-edit `status:` and to let skills manage it.
2. **Given** the `updated:` invariant, **When** any maxi artifact is written, **Then** the `updated:` field must be bumped to today's ISO date in the same operation, never separately.
3. **Given** the analyze rules, **When** Claude reads them, **Then** analyze is read-only (writes only `analysis.md`) and requires the constitution for 2 of 7 audit passes.
4. **Given** the ADR rule, **When** a past decision must change, **Then** a new superseding ADR is created (append-only).

### Edge Cases

- **Dispatched as a subagent**: The `<SUBAGENT-STOP>` guard instructs any agent dispatched as a subagent to execute a specific task to skip this skill entirely, so session-intro guidance is not injected into focused subagent contexts.
- **Spec predates optional fields**: Specs lacking `updated:`, `spec_slug:`, or `decider:` are expected; skills should tolerate absent optional fields rather than fail.
- **Skill run out of order**: Running a skill out of order yields a friendly message rather than a crash.
- **Skill with nothing to do**: `/maxi:clarify` completes in seconds with no ambiguities; `/maxi:analyze` produces a clean report instantly with no issues — the discipline cost is bounded.

## Requirements

### Functional Requirements

- **FR-001**: System MUST instruct any agent dispatched as a subagent for a specific task to skip this skill, via the `<SUBAGENT-STOP>` guard. (skills/using-maxi/SKILL.md:6)
- **FR-002**: System MUST document `/maxi:constitution` as the required-first step that establishes project principles. (skills/using-maxi/SKILL.md:17)
- **FR-003**: System MUST present the forward pipeline of commands, each annotated with the status it produces (specified, clarified, planned, tasked, analyzed, implementing→done). (skills/using-maxi/SKILL.md:18)
- **FR-004**: System MUST document `/maxi:board` as a read-only kanban overview grouped by status. (skills/using-maxi/SKILL.md:24)
- **FR-005**: System MUST document `/maxi:migrate-adr` as importing existing ADRs and discovering undocumented decisions from source. (skills/using-maxi/SKILL.md:25)
- **FR-006**: System MUST state that ADRs are captured automatically during `/maxi:plan` and `/maxi:implement`, with the pipeline asking consent before writing. (skills/using-maxi/SKILL.md:27)
- **FR-007**: System MUST define the per-project artifact layout rooted at `docs/maxi/`. (skills/using-maxi/SKILL.md:34)
- **FR-008**: System MUST state that `docs/maxi/constitution.md` holds project principles and is mandatory before any spec work. (skills/using-maxi/SKILL.md:38)
- **FR-009**: System MUST locate ADRs under `docs/maxi/adr/` with an auto-maintained `README.md` index and `NNNN-slug.md` files. (skills/using-maxi/SKILL.md:39)
- **FR-010**: System MUST locate per-feature specs under `docs/maxi/specs/NNNN-feature-slug/` containing spec.md, plan.md, tasks.md, analysis.md, research.md, data-model.md, and contracts/. (skills/using-maxi/SKILL.md:42)
- **FR-011**: System MUST state that `spec.md` carries status/updated/slug in YAML frontmatter. (skills/using-maxi/SKILL.md:44)
- **FR-012**: System MUST describe `analysis.md` as written by `/maxi:analyze` as a read-only audit. (skills/using-maxi/SKILL.md:46)
- **FR-013**: System MUST declare the status state machine as `drafting → specified → clarified → planned → tasked → analyzed → implementing → done`. (skills/using-maxi/SKILL.md:57)
- **FR-014**: System MUST state that skills read and enforce status, and that running a skill out of order gives a friendly message rather than a crash. (skills/using-maxi/SKILL.md:60)
- **FR-015**: System MUST state that the constitution is mandatory and all workflow skills except `constitution` refuse to run if `docs/maxi/constitution.md` is missing. (skills/using-maxi/SKILL.md:64)
- **FR-016**: System MUST provide a forward phase-gating table giving each forward skill its required status, tolerance, and produced status. (skills/using-maxi/SKILL.md:68)
- **FR-017**: System MUST specify `/maxi:analyze` requires status `tasked`+ and tolerates re-run on `analyzed`/`implementing`/`done`. (skills/using-maxi/SKILL.md:74)
- **FR-018**: System MUST specify `/maxi:implement` requires status `analyzed` and transitions `implementing → done`. (skills/using-maxi/SKILL.md:75)
- **FR-019**: System MUST provide a lifecycle gating table for `board`, `park`, `resume`, `cancel`, and `revise` with their required statuses and effects. (skills/using-maxi/SKILL.md:79)
- **FR-020**: System MUST specify `/maxi:park` and `/maxi:cancel` require any active status (not `parked`/`cancelled`/`done`), producing `parked`/`cancelled`. (skills/using-maxi/SKILL.md:82)
- **FR-021**: System MUST specify `/maxi:resume` requires `parked` and restores `parked_from`. (skills/using-maxi/SKILL.md:83)
- **FR-022**: System MUST specify `/maxi:revise` accepts `clarified` through `implementing` and rolls back to `clarified`/`planned`/`tasked`/`analyzed`. (skills/using-maxi/SKILL.md:85)
- **FR-023**: System MUST note skills are cheap when there is nothing to do (clarify completes in seconds with no ambiguities; analyze produces a clean report instantly). (skills/using-maxi/SKILL.md:87)
- **FR-024**: System MUST state that vendored superpowers skills are available as `maxi:<skill>` and that no separate superpowers installation is needed. (skills/using-maxi/SKILL.md:91)
- **FR-025**: System MUST direct github-spec-kit adopters to run `/maxi:migrate-from-speckit` first, non-destructively. (skills/using-maxi/SKILL.md:95)
- **FR-026**: System MUST direct brownfield adopters to run `/maxi:migrate-from-brownfield`, producing baselines at `status: done` marked `origin: reverse-engineered`. (skills/using-maxi/SKILL.md:96)
- **FR-027**: System MUST direct ADR bootstrapping to `/maxi:migrate-adr`. (skills/using-maxi/SKILL.md:97)
- **FR-028**: System MUST provide numbered getting-started steps beginning with `/maxi:constitution` then `/maxi:specify`. (skills/using-maxi/SKILL.md:99)
- **FR-029**: System MUST state the rule to never skip the constitution step. (skills/using-maxi/SKILL.md:105)
- **FR-030**: System MUST state the rule to never hand-edit `status:` frontmatter and to let skills manage it. (skills/using-maxi/SKILL.md:106)
- **FR-031**: System MUST state the `updated:` invariant — every write to a maxi artifact bumps `updated:` to today's ISO date in the same operation, never separately. (skills/using-maxi/SKILL.md:107)
- **FR-032**: System MUST state `/maxi:analyze` is read-only — it writes `analysis.md` but never modifies source artifacts. (skills/using-maxi/SKILL.md:108)
- **FR-033**: System MUST state analyze requires the constitution because constitution principles inform 2 of the 7 audit passes. (skills/using-maxi/SKILL.md:109)
- **FR-034**: System MUST state ADRs are append-only and revisions are made via a new superseding ADR. (skills/using-maxi/SKILL.md:110)
- **FR-035**: System MUST state that skills tolerate absent optional fields (`updated:`, `spec_slug:`, `decider:`) on specs that predate them, rather than failing. (skills/using-maxi/SKILL.md:111)
- **FR-036**: System MUST carry frontmatter `name: using-maxi` and a description framing it as session-start pipeline orientation. (skills/using-maxi/SKILL.md:2)

### Key Entities

- **Status values**: `drafting`, `specified`, `clarified`, `planned`, `tasked`, `analyzed`, `implementing`, `done`, plus lifecycle terminals `parked`, `cancelled`. (skills/using-maxi/SKILL.md:57, 82)
- **Forward phase-gating table**: rows for specify (constitution exists → specified), clarify (specified → clarified), plan (clarified → planned), tasks (planned → tasked), analyze (tasked+, re-run tolerant → analyzed), implement (analyzed → implementing→done). (skills/using-maxi/SKILL.md:68-75)
- **Lifecycle gating table**: board (any, read-only), park (any active → parked), resume (parked → restores parked_from), cancel (any active → cancelled), revise (clarified..implementing → rollback). (skills/using-maxi/SKILL.md:79-85)
- **Artifact tree**: `docs/maxi/{constitution.md, adr/{README.md, NNNN-slug.md}, specs/NNNN-feature-slug/{spec.md, plan.md, tasks.md, analysis.md, research.md, data-model.md, contracts/}}`. (skills/using-maxi/SKILL.md:34-50)
- **SUBAGENT-STOP guard**: a directive block telling dispatched subagents to skip the skill. (skills/using-maxi/SKILL.md:6-8)

## Success Criteria

### Measurable Outcomes

- **SC-001**: The pipeline block, status state machine, and both gating tables are mutually consistent — every forward command's produced status matches its row in the state machine and gating table.
- **SC-002**: Every forward and lifecycle maxi skill named in the pipeline appears in exactly one gating table with a required status and produced/effect column.
- **SC-003**: All artifact paths referenced elsewhere in the project (constitution at `docs/maxi/constitution.md`, specs at `docs/maxi/specs/NNNN-slug/`) match the layout asserted here.
- **SC-004**: A subagent dispatched for a specific task does not inject the session-intro content (the SUBAGENT-STOP guard is honored).
- **SC-005**: The key-rules list is complete enough that a reader never hand-edits status, always bumps `updated:` in-write, treats analyze as read-only, and treats ADRs as append-only.

## Assumptions

- The skill is injected at session start by the harness (session-start hook / OpenCode plugin); the SKILL.md itself only declares the guidance and the SUBAGENT-STOP guard, not the injection mechanism.
- "Friendly message rather than crash" on out-of-order invocation is enforced by the individual phase skills, not by this document; using-maxi only asserts the behavior.
- The accuracy of the gating table and status machine is maintained by the CLAUDE.md mandatory-sync rule; this spec captures the content as currently asserted, not the sync process.
- Optional-field tolerance (`updated:`/`spec_slug:`/`decider:`) is implemented by the consuming skills; using-maxi only documents the expectation.

## Migration Notes

- Reverse-engineered from commit `7f945f8a8548bf1b4b123d28cc097e2cca897c68`.
- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).
- Verified against code by an adversarial pass before acceptance.
