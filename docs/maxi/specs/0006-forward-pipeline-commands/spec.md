---
slug: 0006-forward-pipeline-commands
created: 2026-05-30
updated: 2026-05-30
status: done
origin: reverse-engineered
source_sha: 7f945f8a8548bf1b4b123d28cc097e2cca897c68
parked_from: null
---

# Feature Specification: Forward-Pipeline Commands

Six phase-gated command skills (`specify` → `clarify` → `plan` → `tasks` → `analyze` → `implement`) that drive a feature spec through the maxi spec-driven pipeline, each enforcing a required entry status, performing its phase work, and atomically transitioning the spec's `status:` frontmatter to the next phase.

## User Scenarios & Testing

### User Story 1 - Create a feature specification (Priority: P1)

A developer in a maxi-managed project wants to turn a feature idea into a structured `spec.md` at `docs/maxi/specs/NNNN-slug/`.

**Why this priority**: `specify` is the pipeline entry point — every other forward command depends on a spec existing, and it is the only command that creates one. Without it the pipeline cannot start.

**Independent Test**: In a project with `docs/maxi/constitution.md` present, invoke specify with a feature description; verify a new `docs/maxi/specs/NNNN-slug/spec.md` is created from the template with `status: specified` and sequential `FR-001`/`SC-001`/`User Story N` schema.

**Acceptance Scenarios**:
- Given `docs/maxi/constitution.md` exists and `docs/maxi/specs/` has `0001-auth` and `0002-export`, When specify runs, Then a new directory `0003-<slug>/` is created (highest NNNN + 1).
- Given no specs directory exists, When specify runs, Then the first feature is numbered `0001`.
- Given a feature description "build a CSV to JSON converter", When the slug is derived, Then it is kebab-cased, stop-words dropped, max 5 words (`csv-json-converter`).
- Given the spec is created, When content is written, Then `/maxi:brainstorming` is invoked first and brainstorming output is mapped into the spec-kit schema (user stories with priority/Independent Test/Acceptance Scenarios, `FR-NNN`, `SC-NNN`).
- Given spec.md is fully written and verified, When status is set, Then frontmatter transitions `drafting` → `specified`.

### User Story 2 - Resolve open questions (Priority: P1)

A developer wants to resolve ambiguities in an existing `specified` spec without rewriting it.

**Why this priority**: clarify is the mandatory second gate; `plan` refuses to run until status is `clarified`, so this command unblocks the rest of the pipeline.

**Independent Test**: Given a spec at `status: specified` containing a `[NEEDS CLARIFICATION]` marker, invoke clarify; verify questions are asked one at a time, the marker is replaced in place, a `## Clarifications` section is appended, and status becomes `clarified`.

**Acceptance Scenarios**:
- Given a `specified` spec, When clarify runs, Then it scans for `[NEEDS CLARIFICATION]` markers, FR questions, vague adjectives, and missing acceptance criteria before asking anything.
- Given multiple ambiguities, When clarify asks, Then it asks one question at a time and waits for the answer before the next.
- Given answers are recorded, When spec.md is updated, Then markers are replaced in place, a `## Clarifications` Q&A section is appended, and `updated:` is set — in the same write.
- Given all open questions resolved, When status is set, Then frontmatter transitions `specified` → `clarified`.

### User Story 3 - Produce an implementation plan (Priority: P1)

A developer wants a technical plan for a `clarified` spec, written to `plan.md`.

**Why this priority**: plan converts requirements into an architecture and is the prerequisite for `tasks`. It also runs the constitution-alignment gate that protects downstream phases.

**Independent Test**: Given a spec at `status: clarified`, invoke plan; verify a constitution check runs, `/maxi:writing-plans` is invoked, `plan.md` is written from `plan-template.md`, and status becomes `planned`.

**Acceptance Scenarios**:
- Given a `clarified` spec, When plan runs, Then it loads spec.md and constitution.md and checks each constitution principle against the spec, flagging violations before proceeding.
- Given the constitution check passes, When planning runs, Then `/maxi:writing-plans` is invoked as a required sub-skill and its output is post-formatted into `plan-template.md` structure at `docs/maxi/specs/NNNN-slug/plan.md`.
- Given plan.md is written, When the ADR scan runs, Then non-obvious architectural choices trigger `/maxi:x-adr` (opt-out, not mandatory).
- Given all artifacts are on disk, When status is set, Then spec.md transitions `clarified` → `planned` and both spec.md and plan.md get `updated:` set.

### User Story 4 - Extract a structured task list (Priority: P1)

A developer wants a checkbox `tasks.md` derived from `plan.md`.

**Why this priority**: tasks is the bridge between plan and execution; `implement` consumes the checkbox list it produces.

**Independent Test**: Given a spec at `status: planned`, invoke tasks; verify `tasks.md` is written with `T001`-style IDs, `[P]`/`[USN]` markers, phase grouping, Checkpoints, and status becomes `tasked`.

**Acceptance Scenarios**:
- Given a `planned` spec, When tasks runs, Then it reads plan.md (plus research.md/data-model.md/contracts/ if present) as the only task source — no invented tasks.
- Given user stories in spec.md, When tasks are mapped, Then each implementation task is tagged `[US1]`/`[US2]`/etc. matching a story.
- Given tasks touch distinct files with no concurrent dependency, When markers are applied, Then those tasks get `[P]`; tasks sharing files do not.
- Given tasks are structured, When the file is written, Then it follows Phase 1 Setup → Phase 2 Foundational → Phase 3+ per user story → Polish, with a Checkpoint after each phase, even for single-story features.
- Given tasks.md is written, When status is set, Then spec.md transitions `planned` → `tasked`.

### User Story 5 - Audit artifacts (read-only) (Priority: P1)

A developer wants a cross-artifact quality audit before implementing.

**Why this priority**: analyze is the last gate before code is written and is the only command that can be re-run idempotently; it catches coverage gaps and constitution violations that would otherwise reach implementation.

**Independent Test**: Given a spec at `status: tasked`, invoke analyze; verify a 7-pass audit writes `analysis.md`, no source artifact is modified, and status becomes `analyzed`.

**Acceptance Scenarios**:
- Given a spec at `tasked` or later, When analyze runs, Then it loads spec.md/plan.md/tasks.md/constitution.md (and ADRs if present) and runs all 7 passes (A Duplication, B Ambiguity, C Underspecification, D Constitution Alignment, E Coverage Gaps, F Inconsistency, G ADR Alignment).
- Given findings, When severity is assigned, Then constitution MUST violations are always CRITICAL.
- Given the audit completes, When output is written, Then `analysis.md` is the only file written and source artifacts are never modified.
- Given current status was `tasked`, When status is set, Then it transitions `tasked` → `analyzed`; on rerun at `analyzed`/`implementing`/`done` the status is left unchanged.

### User Story 6 - Execute the plan (Priority: P1)

A developer wants to implement the feature from `tasks.md`.

**Why this priority**: implement is the terminal forward phase that produces working code and drives the spec to `done`.

**Independent Test**: Given a spec at `status: analyzed`, invoke implement; verify status moves to `implementing`, `/maxi:x-develop` is delegated to, tasks are ticked incrementally, code review runs, and status becomes `done` only when all tasks are `- [x]`.

**Acceptance Scenarios**:
- Given an `analyzed` spec, When implement runs, Then it reads tasks.md, sets `status: implementing` before the first task, and delegates execution to `/maxi:x-develop` (never inline).
- Given tasks complete, When progress is tracked, Then each task is ticked `- [ ]` → `- [x]` incrementally as it finishes.
- Given an unplanned fork surfaces during execution, When a subagent reports a choice not in plan.md, Then `/maxi:x-adr` is invoked (non-blocking).
- Given all tasks finish, When completion is checked, Then `/maxi:requesting-code-review` is run (cannot be waived) and status transitions to `done` only when the count of remaining `- [ ]` items is 0.
- Given status is already `implementing`, When implement is re-invoked, Then it resumes from the first `- [ ]` task and skips completed ones.

### Edge Cases

- **Missing constitution**: every command hard-stops if `docs/maxi/constitution.md` is absent. specify/clarify/plan say "No constitution found. Run `/maxi:constitution` first"; analyze says passes D and F cannot run meaningfully.
- **Wrong entry status** (gating): clarify rejects `drafting` ("run `/maxi:specify` first"), rejects `clarified`+ ("already clarified"); plan rejects `drafting`/`specified`, rejects `planned`+; tasks rejects below `planned`, rejects `tasked`+; analyze rejects below `tasked`; implement rejects below `analyzed` and rejects `done` ("Implementation complete").
- **Multiple in-flight specs**: clarify and analyze ask the user which spec to act on when more than one matches.
- **Slug collision**: specify stops and asks for a disambiguating suffix (suggests `<suffix>-v2`) on exact suffix match.
- **Missing template**: specify/plan/tasks stop with "Please reinstall the maxi plugin" if their template file is absent.
- **User asserts a shortcut**: skills refuse to skip phases on user assertion ("spec is fine", "skip clarify", "skip the review", "all tasks done") — gates and sub-skill delegations are unconditional.
- **Incomplete tasks at done**: implement refuses to set `done` while any `- [ ]` remains and reports which tasks are outstanding.
- **Idempotent analyze rerun**: re-running analyze on `analyzed`/`implementing`/`done` leaves status unchanged.

## Requirements

### Functional Requirements

- **FR-001**: specify MUST hard-stop when `docs/maxi/constitution.md` is missing and instruct the user to run `/maxi:constitution` first (skills/specify/SKILL.md:50).
- **FR-002**: specify MUST compute the next feature number by scanning `docs/maxi/specs/` for `NNNN-*` directories and using highest+1, defaulting to `0001` when none exist (skills/specify/SKILL.md:58).
- **FR-003**: specify MUST derive a kebab-case slug of at most 5 words with stop words dropped and lowercased (skills/specify/SKILL.md:67).
- **FR-004**: specify MUST stop on an exact slug-suffix collision and ask the user for a disambiguating suffix (skills/specify/SKILL.md:74).
- **FR-005**: specify MUST copy `spec-template.md` as the base for spec.md and never write it from scratch (skills/specify/SKILL.md:86).
- **FR-006**: specify MUST set initial frontmatter to `status: drafting` with slug, created, and updated dates on creation (skills/specify/SKILL.md:97).
- **FR-007**: specify MUST invoke `/maxi:brainstorming` and wait for it to complete before writing any FR/SC/user-story content (skills/specify/SKILL.md:108).
- **FR-008**: specify MUST map brainstorming output into the spec-kit schema (user stories with priority + Independent Test + Acceptance Scenarios, sequential `FR-001`, sequential `SC-001`) (skills/specify/SKILL.md:116).
- **FR-009**: specify MUST set `status: specified` only after spec.md is fully written and verified (skills/specify/SKILL.md:140).
- **FR-010**: clarify MUST locate a spec at `status: specified`, ask which one if multiple match, and stop if none match or if status is `drafting`/`clarified`-or-later (skills/clarify/SKILL.md:13).
- **FR-011**: clarify MUST scan spec.md for `[NEEDS CLARIFICATION]` markers, FR questions, vague adjectives, and missing acceptance criteria before asking (skills/clarify/SKILL.md:21).
- **FR-012**: clarify MUST ask one question at a time and wait for the answer before the next (skills/clarify/SKILL.md:23).
- **FR-013**: clarify MUST replace `[NEEDS CLARIFICATION]` markers in place, append a `## Clarifications` Q&A section, and set `updated:` in the same write operation (skills/clarify/SKILL.md:25).
- **FR-014**: clarify MUST not add new requirements, expand scope, or rewrite sections for polish — only resolve existing open questions (skills/clarify/SKILL.md:48).
- **FR-015**: clarify MUST transition `status: specified` → `clarified` only after all open questions are resolved or deferred (skills/clarify/SKILL.md:29).
- **FR-016**: plan MUST hard-stop when constitution is missing and gate on `status: clarified`, rejecting `drafting`/`specified` and `planned`-or-later with phase-specific messages (skills/plan/SKILL.md:13).
- **FR-017**: plan MUST run a constitution-alignment check against every principle before planning and surface violations to the user rather than silently discarding requirements (skills/plan/SKILL.md:21).
- **FR-018**: plan MUST invoke `/maxi:writing-plans` as a required sub-skill rather than writing plan.md content directly (skills/plan/SKILL.md:22).
- **FR-019**: plan MUST write plan.md to `docs/maxi/specs/NNNN-slug/plan.md` following `plan-template.md`, setting slug/spec_slug/created/updated frontmatter, plus optional research.md/data-model.md/contracts/ if produced (skills/plan/SKILL.md:23).
- **FR-020**: plan MUST scan the written plan.md for non-obvious architectural choices and invoke `/maxi:x-adr` for each (opt-out, not mandatory) (skills/plan/SKILL.md:24).
- **FR-021**: plan MUST transition spec.md `status → planned` and set `updated:` on both spec.md and plan.md after all artifacts are written (skills/plan/SKILL.md:25).
- **FR-022**: tasks MUST gate on `status: planned`, stopping below `planned` and stopping at `tasked`-or-later (skills/tasks/SKILL.md:13).
- **FR-023**: tasks MUST read plan.md (and research.md/data-model.md/contracts/ if present) as the only task source and never invent tasks not traceable to plan.md (skills/tasks/SKILL.md:19).
- **FR-024**: tasks MUST tag each implementation task with a `[USN]` label matching a user story from spec.md (skills/tasks/SKILL.md:20).
- **FR-025**: tasks MUST mark `[P]` only on tasks touching files distinct from all other tasks in the same phase with no concurrent dependency (skills/tasks/SKILL.md:21).
- **FR-026**: tasks MUST assign sequential numeric IDs in `T001` format (no letters, no "Task N"/"Step N") (skills/tasks/SKILL.md:22).
- **FR-027**: tasks MUST structure output into Phase 1 Setup → Phase 2 Foundational → Phase 3+ per user story → Polish with a Checkpoint after each phase, following `tasks-template.md`, even for single-story features (skills/tasks/SKILL.md:23).
- **FR-028**: tasks MUST transition spec.md `status: planned → tasked` and set `updated:` plus tasks.md frontmatter (slug/spec_slug/created/updated) (skills/tasks/SKILL.md:30).
- **FR-029**: analyze MUST hard-stop when constitution is missing and gate on status being `tasked`/`analyzed`/`implementing`/`done`, stopping if earlier than `tasked` (skills/analyze/SKILL.md:12).
- **FR-030**: analyze MUST run seven detection passes A–G (Duplication, Ambiguity, Underspecification, Constitution Alignment, Coverage Gaps, Inconsistency, ADR Alignment) (skills/analyze/SKILL.md:48).
- **FR-031**: analyze MUST skip Pass G entirely and note "no ADRs recorded" when `docs/maxi/adr/` is empty or missing (skills/analyze/SKILL.md:79).
- **FR-032**: analyze MUST assign CRITICAL severity to every constitution MUST violation with no exceptions (skills/analyze/SKILL.md:97).
- **FR-033**: analyze MUST write findings only to `docs/maxi/specs/NNNN-slug/analysis.md` and never modify spec.md, plan.md, tasks.md, constitution.md, or any ADR (skills/analyze/SKILL.md:161).
- **FR-034**: analyze MUST transition `tasked → analyzed` only when entry status was `tasked`, and leave status unchanged on rerun at `analyzed`/`implementing`/`done` (skills/analyze/SKILL.md:150).
- **FR-035**: analyze MUST cap findings at 50 total and aggregate the remainder in an Overflow Summary (skills/analyze/SKILL.md:86).
- **FR-036**: implement MUST hard-stop when constitution is missing and gate on `status: analyzed`, rejecting earlier statuses, resuming on `implementing`, and stopping on `done` (skills/implement/SKILL.md:13).
- **FR-037**: implement MUST set `status: implementing` before the first task begins (skills/implement/SKILL.md:22).
- **FR-038**: implement MUST delegate execution to `/maxi:x-develop` and never implement tasks inline (skills/implement/SKILL.md:23).
- **FR-039**: implement MUST tick each task `- [ ]` → `- [x]` incrementally as it completes, not batched at the end (skills/implement/SKILL.md:24).
- **FR-040**: implement MUST invoke `/maxi:x-adr` when a subagent surfaces a decision not in plan.md, without blocking task completion (skills/implement/SKILL.md:25).
- **FR-041**: implement MUST run `/maxi:requesting-code-review` after all tasks complete and cannot let the user waive it (skills/implement/SKILL.md:26).
- **FR-042**: implement MUST count remaining `- [ ]` items and transition `implementing → done` only when that count is 0 (skills/implement/SKILL.md:27).
- **FR-043**: implement MUST resume from the first `- [ ]` task and skip `- [x]` tasks when re-invoked at `status: implementing` (skills/implement/SKILL.md:40).
- **FR-044**: Each forward command MUST end by reporting the new status and recommending the next pipeline command (skills/specify/SKILL.md:146).

### Key Entities

- **spec.md frontmatter**: `slug` (`NNNN-slug`), `created` (ISO date), `updated` (ISO date), `status` (one of `drafting|specified|clarified|planned|tasked|analyzed|implementing|done|parked|cancelled`), `parked_from` (null or pre-park status). The `status` field is the shared state machine the six commands read for gating and write to transition (skills/specify/SKILL.md:99, skills/specify/spec-template.md:1).
- **plan.md frontmatter**: `slug`, `spec_slug`, `created`, `updated` (skills/plan/plan-template.md:1).
- **tasks.md frontmatter**: `slug`, `spec_slug`, `created`, `updated`; body uses `T001`-style checkbox tasks with `[P]` and `[USN]` markers and phase Checkpoints (skills/tasks/tasks-template.md:1, skills/tasks/SKILL.md:34).
- **analysis.md**: read-only audit report — Findings table, Coverage Summary, Constitution/ADR Alignment Issues, Metrics, Next Actions (skills/analyze/SKILL.md:101).
- **Artifact directory**: all per-feature artifacts live under `docs/maxi/specs/NNNN-slug/`; constitution at `docs/maxi/constitution.md`; ADRs at `docs/maxi/adr/` (skills/specify/SKILL.md:156).

## Success Criteria

### Measurable Outcomes

- **SC-001**: A feature can be advanced from idea to `done` purely through the six commands, with each command transitioning status by exactly one forward step (specify→specified, clarify→clarified, plan→planned, tasks→tasked, analyze→analyzed, implement→implementing→done) (skills/specify/SKILL.md:140, skills/implement/SKILL.md:27).
- **SC-002**: Invoking any forward command at the wrong entry status produces a phase-specific stop message and makes no file changes (skills/clarify/SKILL.md:13, skills/plan/SKILL.md:13, skills/tasks/SKILL.md:13).
- **SC-003**: No forward command produces its phase artifact when `docs/maxi/constitution.md` is missing (skills/specify/SKILL.md:50).
- **SC-004**: 100% of tasks in tasks.md trace to a step in plan.md and carry an ID, a phase, and (for implementation tasks) a `[USN]` label (skills/tasks/SKILL.md:81).
- **SC-005**: analyze never alters any source artifact — `analysis.md` is the only file written per run (skills/analyze/SKILL.md:163).
- **SC-006**: implement reaches `status: done` only when zero `- [ ]` task items remain in tasks.md (skills/implement/SKILL.md:27).
- **SC-007**: specify, plan, and implement each invoke their required sub-skill (`/maxi:brainstorming`, `/maxi:writing-plans`, `/maxi:x-develop`) on every run, with no complexity-based exemption (skills/specify/SKILL.md:108, skills/plan/SKILL.md:59, skills/implement/SKILL.md:32).

## Assumptions

- The pipeline is strict and linear: gating messages assume the canonical order specify → clarify → plan → tasks → analyze → implement, with no skip path (inferred from the consistent wrong-status messages and rationalization counters across all six skills).
- "Atomic" status transitions mean the status frontmatter is only advanced after the phase artifact is written and verified on disk; partial writes do not advance status (inferred from the repeated "only when written/verified" rules).
- Status reads/writes operate on YAML frontmatter in spec.md; the skills describe the behavior but the actual file mutation is performed by the agent's generic file tools (no dedicated script exists in these directories).
- ADR capture (`/maxi:x-adr`) in plan and implement is opt-out: declining does not block the phase from completing (stated for plan, mirrored for implement).

## Migration Notes

- Reverse-engineered from commit `7f945f8a8548bf1b4b123d28cc097e2cca897c68`.
- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).
- Verified against code by an adversarial pass before acceptance.
