---
slug: 0003-constitution-adr-boundary-guard
spec_slug: 0003-constitution-adr-boundary-guard
created: 2026-05-29
updated: 2026-05-29
---

# Tasks: Constitution/ADR Boundary Guard

**Input**: Design documents from `docs/maxi/specs/0003-constitution-adr-boundary-guard/`
**Prerequisites**: plan.md (required), spec.md (required for user stories)

**Tests**: This feature is a Markdown / skill-prose change — no application code, so per-task unit tests do not apply. Per the spec's verification model (plan.md "Verification note") the applicable test gate is the constitution's **"Fast-tier tests mandatory"** constraint: the existing `tests/run-all.sh` fast tier acts as the regression guard (FR-008/SC-003), complemented by a content checklist against the spec's Acceptance Scenarios (SC-001/SC-002). Both live in the final phase.

**Organization**: Tasks are grouped by user story (US1/US2/US3 from spec.md) to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- This feature touches exactly two repository-root files: `skills/constitution/SKILL.md` and `templates/constitution-template.md`. No `src/` or `tests/` code paths.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish working context before editing.

- [x] T001 Read the two target files to anchor edit locations: `skills/constitution/SKILL.md` (note the `## Critical Rules`, `## Red Flags`, and `## Elicitation Protocol` sections) and `templates/constitution-template.md` (note the versioning example comment at line 35 and the constraints-section example comment at line 41).

**Checkpoint**: Edit locations confirmed — foundational phase can begin.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish the mandatory authoring channel for all `skills/constitution/SKILL.md` edits.

**⚠️ CRITICAL**: US1 and US3 both edit `skills/constitution/SKILL.md` and MUST be authored through `superpowers:writing-skills` (project CLAUDE.md + constitution Contributor Workflow line 41). No SKILL.md user-story work may begin until this channel is established. US2 (template only) does not depend on this.

- [x] T002 Enter a `superpowers:writing-skills` authoring session targeting `skills/constitution/SKILL.md` — the channel through which T003, T004, and T008 are applied. Do NOT hand-edit the SKILL.md.

**Checkpoint**: Authoring channel ready — SKILL.md user-story phases can begin.

---

## Phase 3: User Story 1 - Decisions redirected to ADR during authoring (Priority: P1) 🎯 MVP

**Goal**: The `constitution` skill explicitly tells authors that concrete, contestable, reversible technology choices belong in an ADR (`/maxi:adr`), not in Core Principles — with a litmus test, a matching red flag, and the constraint carve-out.

**Independent Test**: Read `skills/constitution/SKILL.md` and confirm a Critical Rule states the litmus test + ADR redirect, and a Red Flag mirrors it with a corrective action; classify the canonical pair ("storage must be justified" = principle; "we use PostgreSQL" = ADR) unambiguously.

### Implementation for User Story 1

- [x] T003 [US1] Via the `writing-skills` session, insert the **"Principles, not decisions."** Critical Rule into the `## Critical Rules` list of `skills/constitution/SKILL.md`, immediately after the existing "Keep categories separate." bullet. Content: the litmus test (specific technology / contestable / reversible → decision → `/maxi:adr`; durable cross-cutting invariant → principle), the contrasting example pair ("Every storage choice must be justified against data-durability needs" vs "We use PostgreSQL"), and the constraint carve-out (externally-imposed, non-contestable requirement stays as a Constitution Constraint). Exact text per plan.md Task 1 Step 2. (FR-001, FR-002, FR-004)
- [x] T004 [US1] Via the `writing-skills` session, add the matching Red Flag to the `## Red Flags` list of `skills/constitution/SKILL.md`, after the "Mixing … convention … constraint" bullet: a concrete tech/tool choice written as a Core Principle → that's a decision; record the invariant and propose the choice via `/maxi:adr`. Exact text per plan.md Task 2 Step 1. (FR-003, FR-004) — *no [P]: same file as T003.*

**Checkpoint**: User Story 1 complete and independently testable — MVP. The decisions-belong-in-ADR guidance is now discoverable in the skill (SC-001).

---

## Phase 4: User Story 2 - Template stops modeling decisions as principles (Priority: P2)

**Goal**: `templates/constitution-template.md` example comments illustrate principles/constraints, not concrete technology decisions.

**Independent Test**: Read the template and confirm the versioning example no longer contains a concrete format (`MAJOR.MINOR.BUILD`), and the constraints-section example presents constraint-shaped content with an ADR redirect note — while all section headers remain unchanged.

### Implementation for User Story 2

- [x] T005 [P] [US2] In `templates/constitution-template.md` line 35, replace the `MAJOR.MINOR.BUILD format` versioning example with a principle-shaped example ("versions follow a predictable, documented scheme"), leaving the rest of the comment intact. Plain `Edit` (template is not a skill). Exact text per plan.md Task 4 Step 1. (FR-006) — *[P]: this file is independent of all SKILL.md tasks.*
- [x] T006 [US2] In `templates/constitution-template.md` line 41, replace the constraints-section example comment with constraint-shaped examples (forbidden/locked-in dependencies, compliance standards, deployment policies) plus a note that concrete technology *choices* (e.g. "use PostgreSQL") go to `/maxi:adr`, not here. Exact text per plan.md Task 4 Step 2. (FR-007) — *no [P]: same file as T005.*
- [x] T007 [US2] Verify no header changed: `grep -nE '^(#|##) ' templates/constitution-template.md` returns the same header list as before (only HTML-comment lines changed). (FR-008)

**Checkpoint**: User Stories 1 AND 2 both satisfied; template no longer invites decision-shaped principles.

---

## Phase 5: User Story 3 - Guard fires during elicitation (Priority: P3)

**Goal**: The `constitution` skill nudges authors at Q&A time, redirecting technology-specific/reversible answers toward the underlying invariant.

**Independent Test**: Read the `## Elicitation Protocol` section of `skills/constitution/SKILL.md` and confirm a one-line nudge directs technology-specific/reversible answers to an ADR and toward the invariant.

### Implementation for User Story 3

- [x] T008 [US3] Via the `writing-skills` session, add a one-line nudge to the **Core Principles** elicitation block in `## Elicitation Protocol` of `skills/constitution/SKILL.md`, after the existing three question bullets: if an answer names a specific technology or a reversible choice, note it belongs in an ADR (`/maxi:adr`) and steer the principle toward the underlying invariant. Exact text per plan.md Task 3 Step 1. (FR-005) — *no [P]: same file as T003/T004; must run after them.*

**Checkpoint**: All three user stories independently functional.

---

## Phase 6: Polish & Verification (Cross-Cutting)

**Purpose**: Regression guard + content verification against the spec.

- [x] T009 Run the fast-tier test suite: `bash tests/run-all.sh`. Expect all checks pass, including `OK  [constitution-template.md]` and `check-frontmatter.sh`. (SC-003, FR-008)
- [x] T010 Content checklist (read `skills/constitution/SKILL.md`): SC-001 — explicit "decisions belong in ADRs, not principles" statement present; SC-002 — litmus test classifies the canonical pair unambiguously; US1 Acceptance Scenario 3 — constraint carve-out present.
- [x] T011 [P] Blast-radius check: `git diff --name-only master...HEAD` lists only `skills/constitution/SKILL.md`, `templates/constitution-template.md`, and the `docs/maxi/specs/0003-constitution-adr-boundary-guard/` artifacts — nothing else (no `docs/pipeline-flow.md`, `docs/delegation-map.md`, `using-maxi`, `CLAUDE.md`, or other skill). (SC-004, FR-009)

**Checkpoint**: All success criteria verified.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup. Blocks the SKILL.md stories (US1, US3) only.
- **User Stories (Phases 3–5)**: Depend on the relevant prerequisite — see below.
- **Polish/Verification (Phase 6)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: After Foundational (writing-skills channel). No dependency on other stories.
- **US2 (P2)**: After Setup only — **does not** need Foundational (template is not a skill). Independent of US1/US3 (different file), so it may proceed in parallel with them.
- **US3 (P3)**: After Foundational. **Edits the same file as US1** (`skills/constitution/SKILL.md`), so it MUST run after US1 (T003/T004) — they cannot run concurrently.

### Within Each User Story

- T004 after T003 (same file). T006 after T005 (same file). T008 after T003/T004 (same file).
- Commit after each task or logical group.

### Parallel Opportunities

- **US2 (T005→T006→T007)** can run in parallel with the SKILL.md work (US1/US3), since it touches only `templates/constitution-template.md`.
- T011 (read-only git diff) is [P] within Phase 6.
- **Not parallel**: US1 and US3 both write `skills/constitution/SKILL.md` — serialize them (US1 then US3). T003↔T004 and T005↔T006 share files — serialize within each pair.

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup → 2. Phase 2: Foundational (writing-skills channel) → 3. Phase 3: US1 → 4. **STOP and VALIDATE**: the decisions-in-ADR guidance is discoverable in the skill (SC-001). This alone delivers the core value.

### Incremental Delivery

1. Setup + Foundational → ready.
2. US1 → validate → MVP (the guard rule + red flag).
3. US2 (parallelizable) → validate → template tightened.
4. US3 → validate → elicitation nudge.
5. Phase 6 → fast-tier tests + content + blast-radius verification.

---

## Notes

- [P] = different files, no dependencies.
- [Story] label maps each implementation task to a user story for traceability.
- SKILL.md edits (T003, T004, T008) go through `superpowers:writing-skills`; the template edits (T005, T006) are plain `Edit`s.
- No invented tasks — every task traces to a step in plan.md.
