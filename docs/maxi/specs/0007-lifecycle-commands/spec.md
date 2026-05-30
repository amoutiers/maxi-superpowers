---
slug: 0007-lifecycle-commands
created: 2026-05-30
updated: 2026-05-30
status: done
origin: reverse-engineered
source_sha: 7f945f8a8548bf1b4b123d28cc097e2cca897c68
parked_from: null
---

# Feature Specification: Spec Lifecycle Commands

Five maxi commands manage a spec's lifecycle outside the linear forward flow (specify → clarify → plan → tasks → analyze → implement): `board` provides a read-only kanban overview of every spec grouped by pipeline status; `park` freezes an active spec without losing progress and records where it was frozen; `resume` restores a parked spec to its prior status; `cancel` permanently and terminally abandons an in-progress spec; and `revise` rolls a spec's status backward to an earlier phase when requirements or design change. All four mutating commands (`park`, `resume`, `cancel`, `revise`) write only `spec.md` — never `plan.md`, `tasks.md`, `analysis.md`, `constitution.md`, or any ADR — and gate every write behind an explicit `yes` confirmation. `board` writes nothing at all.

## User Scenarios & Testing

### User Story 1 - View pipeline status of all specs (Priority: P1)

A user runs `/maxi:board` to see, at a glance, every spec in the project bucketed by its pipeline status, with stale work surfaced first.

**Why this priority**: Read-only visibility is the entry point to the whole lifecycle — a user must see where specs sit before deciding to park, resume, cancel, or revise any of them. It has no preconditions and writes nothing, so it is the safest and most foundational command.

**Independent Test**: With one or more `docs/maxi/specs/*/spec.md` files present, run `/maxi:board` and confirm it prints all ten status headings (including empty ones marked `_empty_`) plus a footer summary, and writes no file.

**Acceptance Scenarios**:

1. **Given** `docs/maxi/specs/` is absent or empty, **When** the user runs board, **Then** it prints "No specs found at docs/maxi/specs/. Run /maxi:specify to create your first spec." and stops.
2. **Given** specs exist at various statuses, **When** the user runs board, **Then** each spec is bucketed under its frontmatter `status`, buckets are rendered in canonical order, empty buckets show `_empty_`, and the heading for each is always printed.
3. **Given** a spec whose `updated` date is more than 30 calendar days before today, **When** board renders it (in any non-cancelled bucket), **Then** the entry is suffixed with `, stale Nd`.
4. **Given** a spec at `cancelled` status, **When** board renders it, **Then** no staleness suffix is appended.
5. **Given** many `done` specs, **When** board renders the `done` bucket, **Then** the heading shows `## done (total) — showing K from last 30d` and only entries updated within the last 30 days are listed (oldest first), or `_empty_` if none.
6. **Given** a spec with a missing or unrecognized `status`, **When** board renders, **Then** it is placed in a trailing `unknown` bucket and flagged (e.g. `(no status field)`), never inferred.
7. **Given** any spec set, **When** board finishes, **Then** it prints a footer `N specs across M non-empty statuses · K stale (>30d)`, omitting `· K stale` when K = 0.

### User Story 2 - Freeze and later resume a spec (Priority: P1)

A user pauses an active spec with `/maxi:park` (recording why and where it was frozen) and later restores it with `/maxi:resume` to exactly the status it held before parking.

**Why this priority**: Park/resume is the core non-terminal lifecycle capability — it lets in-flight work be set aside and reliably picked back up. The `parked_from` round-trip is the load-bearing mechanism; without it resume cannot restore the correct status.

**Independent Test**: Take a spec at `planned`, run `/maxi:park` (supply a reason, answer `yes`), confirm `status: parked` and `parked_from: planned`; then run `/maxi:resume`, answer `yes`, and confirm `status: planned`, `parked_from: null`.

**Acceptance Scenarios**:

1. **Given** an active spec and a user request to park, **When** the user supplies a non-empty reason and answers `yes`, **Then** park writes `status: parked`, `parked_from: <prior status>`, `updated: <today>`, and appends `**Parked (YYYY-MM-DD):** <reason> (was: <status>)` to `## Clarifications`.
2. **Given** a park request, **When** the user gives an empty reason, **Then** park requires a non-empty answer before proceeding.
3. **Given** a park confirmation prompt, **When** the user responds with anything other than explicit `yes` (e.g. "ok", "sure"), **Then** park does not write.
4. **Given** a spec at `status: parked` with `parked_from: <X>`, **When** the user resumes and answers `yes`, **Then** resume writes `status: <X>`, `parked_from: null`, `updated: <today>`, and appends `**Resumed (YYYY-MM-DD):** returning to \`<X>\`` to `## Clarifications`.
5. **Given** a resumed spec, **When** resume reports completion, **Then** it names the correct next forward skill (`clarified`→`/maxi:plan`, `planned`→`/maxi:tasks`, `tasked`→`/maxi:analyze`, `analyzed`→`/maxi:implement`, `implementing`→`/maxi:implement`).
6. **Given** a parked spec whose `parked_from` is missing or `null`, **When** the user resumes, **Then** resume refuses to guess, asks the user which status to restore to, and waits for input before writing.

### User Story 3 - Terminally cancel an abandoned spec (Priority: P2)

A user marks an in-progress spec as permanently abandoned with `/maxi:cancel`, recording the reason; the spec moves to a terminal `cancelled` status that has no un-cancel path.

**Why this priority**: Cancellation is a deliberate terminal action used less frequently than park/board, but it requires the strictest consent guarantees because it is irreversible within the pipeline.

**Independent Test**: Take a spec at an active status, run `/maxi:cancel`, supply a reason, answer `yes`, and confirm `status: cancelled` with a `**Cancelled (...)**` clarification line and no path to un-cancel.

**Acceptance Scenarios**:

1. **Given** an active spec, **When** the user supplies a non-empty reason and answers `yes`, **Then** cancel writes `status: cancelled`, `updated: <today>`, and appends `**Cancelled (YYYY-MM-DD):** <reason>` to `## Clarifications`.
2. **Given** a cancel request with no reason, **When** the user declines to give one ("obvious", "you know why"), **Then** cancel still requires a written reason before proceeding.
3. **Given** a cancel confirmation prompt, **When** the user answers ambiguously ("ok", "sure", "fine", silence), **Then** cancel treats it as `no` and does not write.

### User Story 4 - Roll a spec back to an earlier phase (Priority: P2)

A user whose requirements or design changed runs `/maxi:revise`; the command infers a suggested rollback target with justification (A+ picker), checks the constitution, and on consent moves `status:` backward to an earlier phase, leaving downstream artefacts on disk flagged stale.

**Why this priority**: Revise is the only command that moves status backward and the most decision-heavy (target inference, constitution scan, stale-artefact handling). It is needed when the forward flow must be partially redone.

**Independent Test**: Take a spec at `analyzed`, run `/maxi:revise`, describe a requirements change, confirm the suggested target is `clarified` with reasoning and the full picker list is offered, answer `yes`, and verify `status: clarified` with a `**Revised (...)**` clarification line while `plan.md`/`tasks.md`/`analysis.md` remain untouched on disk.

**Acceptance Scenarios**:

1. **Given** a revise request and a description of the change, **When** revise infers a target, **Then** it always shows the suggested target with one sentence of reasoning AND offers the full picker list `[clarified | planned | tasked | analyzed]` before applying.
2. **Given** the described change maps to a category, **When** revise picks a target, **Then** requirements/FR/scope/user-story changes suggest `clarified`, plan/architecture/component changes suggest `planned`, task-extraction errors suggest `tasked`, and analysis findings suggest `analyzed`.
3. **Given** a described change that would violate a constitution principle, **When** revise runs the constitution check before confirmation, **Then** it flags the conflicting principle and asks whether to proceed anyway rather than silently continuing.
4. **Given** confirmation and an explicit `yes`, **When** revise writes, **Then** it sets `status: <target>`, `updated: <today>`, and appends a `**Revised (YYYY-MM-DD):**` clarification noting the rollback and that post-target artefacts are stale — without deleting, renaming, or editing those artefacts.

### Edge Cases

- **Park on a non-active status**: park refuses when already `parked` ("Spec is already parked. Use `/maxi:resume`..."), when `cancelled` ("Cannot park a cancelled spec."), and when `done` ("No need to park.").
- **Resume a non-parked spec**: resume refuses when no spec is `parked`, when the spec is `cancelled` (terminal, cannot resume), and when the spec is at any active non-parked status ("Spec is at `<status>`, not parked. Nothing to resume.").
- **Resume with missing `parked_from`**: resume does not guess; it asks the user for the restore status and waits.
- **Cancel on a non-active status**: cancel refuses when already `cancelled`, when `parked` ("Run `/maxi:resume` first, then `/maxi:cancel`."), and when `done` ("Cancellation is for in-progress work...").
- **Revise below `clarified`**: revise refuses at `drafting`/`specified` (directs to `/maxi:clarify` or `/maxi:specify`), refuses when `parked` (resume first), `cancelled`, or `done` (create a new spec instead); it never rolls back below `clarified`.
- **Ambiguous confirmation across all mutating commands**: any response other than explicit `yes` is treated as `no`; the command asks once more then stops without writing.
- **Missing constitution**: park, resume, cancel, and revise all hard-stop if `docs/maxi/constitution.md` does not exist.
- **Multiple candidate specs**: park, cancel, and revise ask which active spec to act on when more than one is in flight; resume lists parked specs and asks which one.
- **Board on a spec missing `status` or `updated`**: board tolerates gracefully — unknown bucket for missing/unrecognized status, no staleness suffix for missing `updated`.

## Requirements

### Functional Requirements

- **FR-001**: System MUST locate specs by scanning `docs/maxi/specs/*/spec.md` and, if that directory is absent or empty, print the "No specs found" message and stop (skills/board/SKILL.md:14).
- **FR-002**: System MUST parse each spec's frontmatter for `slug`, `status`, and `updated`, and derive the title from the body's first `# ` H1, applying documented fallbacks (skills/board/SKILL.md:22).
- **FR-003**: System MUST bucket specs into the canonical ordered status list `drafting → specified → clarified → planned → tasked → analyzed → implementing → parked → done → cancelled` (skills/board/SKILL.md:33).
- **FR-004**: System MUST place specs with missing or unrecognized `status` into a trailing `unknown` bucket and never infer a status (skills/board/SKILL.md:36).
- **FR-005**: System MUST sort each bucket by `updated` ascending so the oldest (stalest) work surfaces first (skills/board/SKILL.md:42).
- **FR-006**: System MUST compute staleness as today minus `updated` in calendar days and append `, stale Nd` when greater than 30 days, skipping entries with no `updated` and skipping `cancelled` specs (skills/board/SKILL.md:46).
- **FR-007**: System MUST print every status heading including empty ones (rendered `_empty_`) so the pipeline shape stays visible (skills/board/SKILL.md:87).
- **FR-008**: System MUST render the `done` heading as `## done (total) — showing K from last 30d` and list only entries updated within the last 30 days, oldest first (skills/board/SKILL.md:88).
- **FR-009**: System MUST print a footer `N specs across M non-empty statuses · K stale (>30d)`, omitting the stale clause when K = 0 (skills/board/SKILL.md:99).
- **FR-010**: Board MUST NOT write or modify any file — it is pure terminal output (skills/board/SKILL.md:106).
- **FR-011**: Park, resume, cancel, and revise MUST hard-stop if `docs/maxi/constitution.md` is missing (skills/park/SKILL.md:12).
- **FR-012**: Park MUST refuse to act when the spec is already `parked`, or is `cancelled`, or is `done`, returning the corresponding message (skills/park/SKILL.md:14).
- **FR-013**: Park MUST require a non-empty reason before proceeding (skills/park/SKILL.md:21).
- **FR-014**: Park MUST present a confirmation prompt and write only on explicit `yes` (skills/park/SKILL.md:22).
- **FR-015**: Park MUST set `parked_from:` to the current status before writing, alongside `status: parked` and `updated: <today>` (skills/park/SKILL.md:32).
- **FR-016**: Park MUST append `**Parked (YYYY-MM-DD):** <reason> (was: <current_status>)` to the `## Clarifications` section (skills/park/SKILL.md:27).
- **FR-017**: Resume MUST locate a spec at `status: parked` and refuse when none exists, when the spec is `cancelled`, or when it is at any non-parked active status (skills/resume/SKILL.md:13).
- **FR-018**: Resume MUST read `parked_from:` as the single source of truth for the restore target and, when it is missing or `null`, ask the user which status to restore and wait rather than guessing (skills/resume/SKILL.md:20).
- **FR-019**: Resume MUST, on explicit `yes`, write `status: <parked_from>`, set `parked_from: null`, set `updated: <today>`, and append `**Resumed (YYYY-MM-DD):** returning to \`<parked_from>\`` to `## Clarifications` (skills/resume/SKILL.md:23).
- **FR-020**: Resume MUST report the correct next forward skill for the restored status per its mapping table (skills/resume/SKILL.md:28).
- **FR-021**: Cancel MUST refuse when the spec is already `cancelled`, when it is `parked` (resume first), or when it is `done` (skills/cancel/SKILL.md:14).
- **FR-022**: Cancel MUST require a non-empty written reason and MUST NOT proceed without one (skills/cancel/SKILL.md:21).
- **FR-023**: Cancel MUST write only on explicit `yes`, treating ambiguous responses ("ok", "sure", "fine", silence) as `no` (skills/cancel/SKILL.md:31).
- **FR-024**: Cancel MUST, on `yes`, set `status: cancelled`, `updated: <today>`, and append `**Cancelled (YYYY-MM-DD):** <reason>` to `## Clarifications`; cancellation is terminal with no resume path (skills/cancel/SKILL.md:23).
- **FR-025**: Revise MUST refuse when status is `drafting`/`specified` (use clarify/specify), `parked` (resume first), `cancelled`, or `done`, and is valid only for `clarified`, `planned`, `tasked`, `analyzed`, `implementing` (skills/revise/SKILL.md:14).
- **FR-026**: Revise MUST require a non-empty description of the change before proceeding (skills/revise/SKILL.md:22).
- **FR-027**: Revise MUST infer a suggested rollback target by change category (requirements→`clarified`, plan→`planned`, task-extraction→`tasked`, analysis→`analyzed`) and always show the suggestion with one-sentence reasoning plus the full picker list before applying (skills/revise/SKILL.md:24).
- **FR-028**: Revise MUST scan the constitution before confirmation and flag any principle the change may violate, asking whether to proceed rather than silently continuing (skills/revise/SKILL.md:33).
- **FR-029**: Revise MUST, on explicit `yes`, set `status: <target>`, `updated: <today>`, and append a `**Revised (YYYY-MM-DD):**` clarification recording the rollback and noting post-target artefacts are stale (skills/revise/SKILL.md:38).
- **FR-030**: Revise MUST NOT roll back below `clarified` (skills/revise/SKILL.md:49).
- **FR-031**: Revise MUST NOT delete, rename, or modify `plan.md`, `tasks.md`, or `analysis.md`; downstream artefacts stay on disk flagged stale in `## Clarifications` only (skills/revise/SKILL.md:50).
- **FR-032**: Park, resume, cancel, and revise MUST write only `spec.md` and MUST NOT modify `plan.md`, `tasks.md`, `analysis.md`, `constitution.md`, or any ADR file (skills/park/SKILL.md:34).

### Key Entities

- **spec.md frontmatter `status`**: the pipeline phase of a spec; the field every lifecycle command reads (for gating) and four of them write. Canonical values span `drafting` through terminal `cancelled`, with `parked` as a non-terminal frozen state (skills/board/SKILL.md:33).
- **spec.md frontmatter `parked_from`**: records the status a spec held at the moment it was parked; set by park, read by resume to restore, and cleared to `null` on resume (skills/park/SKILL.md:32, skills/resume/SKILL.md:39).
- **spec.md frontmatter `updated`**: the ISO date last touched; stamped by every mutating command and used by board for ordering and staleness (skills/park/SKILL.md:26, skills/board/SKILL.md:46).
- **spec.md `## Clarifications` section**: the append-only audit log where park/resume/cancel/revise record dated lifecycle events (skills/cancel/SKILL.md:26).

## Success Criteria

### Measurable Outcomes

- **SC-001**: A user can see the pipeline status of every spec in the project, including empty stages, in a single read-only board invocation that modifies no files.
- **SC-002**: A spec parked from any active status and then resumed returns to exactly that prior status, with `parked_from` cleared, in 100% of park/resume round-trips where `parked_from` was set.
- **SC-003**: No mutating lifecycle command (park, resume, cancel, revise) writes to `spec.md` without an explicit `yes` from the user.
- **SC-004**: Cancellation is irreversible: once a spec reaches `cancelled`, no lifecycle command can move it to another status.
- **SC-005**: Revise never lands a spec below `clarified`, and downstream artefacts (`plan.md`, `tasks.md`, `analysis.md`) remain on disk after every revise.
- **SC-006**: Every mutating command touches only `spec.md`; `plan.md`, `tasks.md`, `analysis.md`, `constitution.md`, and ADR files are never modified by these commands.

## Assumptions

- Specs live at `docs/maxi/specs/*/spec.md` with YAML frontmatter containing at least `status`, and typically `slug` and `updated`.
- A project constitution at `docs/maxi/constitution.md` is the precondition for all mutating commands; board does not require it.
- The canonical status set and its ordering are authoritative as defined in `skills/specify/SKILL.md` and `skills/using-maxi/SKILL.md`; this boundary consumes that definition rather than owning it (skills/board/SKILL.md:38).
- "Explicit `yes`" means the literal affirmative; common soft affirmations ("ok", "sure", "fine") and silence are treated as `no`.
- Dates are handled as ISO calendar dates; staleness is measured in whole calendar days against today's date.
- These five commands operate outside the linear forward pipeline and do not themselves advance a spec forward (resume and revise only restore or roll back status, never advance past the prior phase).

## Migration Notes

- Reverse-engineered from commit `7f945f8a8548bf1b4b123d28cc097e2cca897c68`.
- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).
- Verified against code by an adversarial pass before acceptance.
