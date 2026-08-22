---
name: tasks
description: Use when the user invokes /maxi:tasks or wants to extract a structured task list from an existing plan.md — spec must be at status "planned"
---

# tasks

Extract or explicitly correct a structured `tasks.md` from an existing `plan.md`. Pure extraction, no delegation. Produces checkbox tasks with parallel markers, story labels, and phase checkpoints.

## Prereqs

- `docs/maxi/constitution.md` must exist — hard stop if missing
- Normal initial extraction is legal only at status `planned`. Other statuses:
  - `drafting` / `specified` / `clarified`: stop — *"Spec must reach `planned` status first. Run `/maxi:plan`."*
  - `tasked` or later, without an explicit structural correction request: stop — *"Tasks already extracted. Proceed to `/maxi:analyze` or `/maxi:implement`."*
- An explicit structural tasks correction is a separate owner mode. It accepts only `tasked`, `analyzed`, or `implementing`; `parked`, `cancelled`, and `done` remain blocked. Never infer correction mode from an ordinary `/maxi:tasks` invocation.

## Process

1. **Read inputs and gate extraction** — load `plan.md` as primary source; also load `spec.md`, `research.md`, `data-model.md`, and `contracts/` if they exist alongside it in `docs/maxi/specs/NNNN-slug/`. Compute SHA-256 for the exact current bytes of `spec.md` and `plan.md`, then read `reviews/design-review.md`. Accept only `verdict: approved` with both `reviewed_spec_sha256` and `reviewed_plan_sha256` equal to those current hashes. On a missing or stale design review, stop with no write and direct the user to `/maxi:review`; never invoke that skill itself.
2. **Map tasks to user stories** — for each user story in `spec.md`, collect the tasks from `plan.md` that implement it. Tag each task with `[US1]`, `[US2]`, etc.
3. **Identify parallel tasks** — mark with `[P]` any task that touches different files from all other tasks in the same phase (no shared-file writes, no dependency on concurrent tasks)
4. **Assign sequential IDs and source mappings** — number all tasks `T001`, `T002`, ... in phase order. Preserve exactly one terminal `(plan Task <positive integer>)` mapping on every extracted item, naming the source `plan.md` `Task N` heading. Require a bijection between `plan.md` executable `Task N` headings and those mappings. No letters, no "Task N" IDs, and no "Step N" IDs.
5. **Structure into phases** — verify `tasks-template.md` exists (Read tool) before proceeding; if missing, stop: *"Cannot proceed — `tasks-template.md` is missing. Please reinstall the maxi plugin."* Then follow the template:
   - Phase 1: Setup (project init, no deps)
   - Phase 2: Foundational (blocks all user stories — CRITICAL warning)
   - Phase 3+: One phase per user story
   - Final phase: Polish & Cross-Cutting Concerns
   - A **Checkpoint** line after each phase
6. **Write `tasks.md`** — output to `docs/maxi/specs/NNNN-slug/tasks.md` following the template schema. Include Dependencies & Execution Order section.
7. **Transition status** — update spec.md frontmatter `status: planned → tasked`; also set `updated: [today's ISO date]` on spec.md and on tasks.md. When creating tasks.md, set its frontmatter: `slug` and `spec_slug` from spec, `created` and `updated` to today's ISO date.
8. **Report** — *"Tasks written to `docs/maxi/specs/NNNN-slug/tasks.md` (status: `tasked`). Next: `/maxi:analyze`."*

## Explicit Structural Tasks Correction

Use this owner mode only when the user explicitly requests a structural correction to `tasks.md` and status is `tasked`, `analyzed`, or `implementing`. `parked`, `cancelled`, and `done` are blocked.

1. Read `tasks.md` before any write.
2. Perform the requested pure extraction correction.
3. Return the spec status to `tasked`.
4. Report: *"Correction recorded. No review or successor phase was started. Request `/maxi:review` when you want a new design review."*

This correction never invokes `specify`, `clarify`, `plan`, or `analyze`, and never edits `plan.md` or `analysis.md`.

## Task Format

```
- [ ] T001 [P] [US1] Create [Entity] model in src/models/entity.py (plan Task 1)
- [ ] T002 [US1] Implement [Service] in src/services/service.py (depends on T001) (plan Task 2)
- [ ] T003 [P] [US2] Create [OtherEntity] model in src/models/other.py (plan Task 3)
```

Rules:
- `[P]` = safe to run in parallel (different files, no dependency)
- `[USN]` = which user story (must match a story from spec.md)
- No `[P]` on tasks that share files or have dependencies within the same phase
- Include exact file paths in descriptions

## Phase Structure

```markdown
## Phase 1: Setup

- [ ] T001 ...
- [ ] T002 [P] ...

**Checkpoint**: Setup complete — foundational phase can begin.

---

## Phase 2: Foundational ⚠️ BLOCKS ALL USER STORIES

- [ ] T003 ...

**Checkpoint**: Foundation ready — user story phases can begin.

---

## Phase 3: User Story 1 - [Title] (Priority: P1) 🎯 MVP

**Goal**: ...
**Independent Test**: ...

- [ ] T010 [P] [US1] ...
- [ ] T011 [US1] ...

**Checkpoint**: User Story 1 complete and independently testable.
```

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.

## Critical Rules

- **Read plan.md before writing anything.** All tasks must be traceable to plan.md content.
- **Pure extraction only.** Do NOT invent tasks that are not in plan.md. "Being thorough" is not a justification for adding tasks. Every task must trace to a step in plan.md.
- **Apply [P] and [USN] markers even if plan.md already has checkboxes.** If plan.md has flat task items, you MUST restructure them: add phase grouping, add `[USN]` labels, identify `[P]` markers. Copying plan.md verbatim is NOT acceptable — it will be missing structure.
- **Every task needs a story label.** If a task doesn't belong to a user story (Setup/Foundational/Polish), omit `[USN]` label. All implementation tasks for a user story MUST have one.
- **IDs are sequential and numeric.** T001–T999. Never T1, Task 1, Step A.
- **Source mappings are terminal and bijective.** Every task ends with exactly one `(plan Task N)` mapping, and every executable `plan.md` `Task N` heading is mapped exactly once.
- **Parallel markers require no shared files.** If two tasks touch the same file, neither gets `[P]`.
- **MVP Checkpoint after Phase 3 (US1).** Always mark the P1 user story checkpoint as the MVP.
- **Phase structure is required even for single-story features.** One user story = at minimum: Setup → Foundational → Phase 3 (US1) → Polish. A flat list with no phases is never acceptable.
- **Template schema required.** Follow `tasks-template.md` structure. Include Dependencies section.

## Red Flags

- Flat list of tasks with no phases → structure into phases even for single-story features
- No `[P]` markers anywhere → identify parallel opportunities
- No `[USN]` labels → map every implementation task to a story
- IDs like "Task 1", "Step A", or "T1" → use T001 format
- No Checkpoint lines → add between every phase
- tasks.md written to wrong directory → only `docs/maxi/specs/NNNN-slug/tasks.md`
- tasks.md looks identical to plan.md (no added markers or structure) → extraction not done
- Extra tasks not found in plan.md → remove invented tasks, only extract what plan.md contains

## Rationalization Counters

| Rationalization | Counter |
|---|---|
| "plan.md already has checkbox tasks, I'll just copy them" | plan.md tasks are unstructured. You MUST add [P] markers, [USN] labels, phase grouping, and Checkpoints. Copy is never acceptable. |
| "I'll add a few extra tasks to be thorough" | Pure extraction only. Every task traces to plan.md. No invented tasks. |
| "This feature only has one user story, phases are overkill" | Phase structure is required regardless of story count: Setup → Foundational → US1 phase → Polish. |
| "I don't see a foundational phase in plan.md" | Every tasks.md has a Phase 2: Foundational, even if minimal (e.g., one task: "Configure project dependencies"). |
| "Tasks marked [P] in plan.md might have hidden dependencies" | Re-evaluate based on file-level analysis. If plan.md marks something parallel but they share a file, remove the [P] marker. |
