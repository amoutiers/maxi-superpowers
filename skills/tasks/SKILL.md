---
name: tasks
description: Use when the user invokes /maxi:tasks or wants to extract a structured task list from an existing plan.md — spec must be at status "planned"
---

# tasks

Extract a structured `tasks.md` from an existing `plan.md`. Pure extraction — no delegation. Produces checkbox tasks with parallel markers, story labels, and phase checkpoints.

## Prereqs

- `docs/maxi/constitution.md` must exist — hard stop if missing
- Spec status must be `planned`. Other statuses:
  - `drafting` / `specified` / `clarified`: stop — *"Spec must reach `planned` status first. Run `/maxi:plan`."*
  - `tasked` or later: stop — *"Tasks already extracted. Proceed to `/maxi:analyze` or `/maxi:implement`."*

## Process

1. **Read inputs** — load `plan.md` as primary source; also load `spec.md`, `research.md`, `data-model.md`, `contracts/` if they exist alongside it in `docs/maxi/specs/NNNN-slug/`, plus the current approved `reviews/plan-review.md`
2. **Validate the plan review** — for a forward-pipeline spec carrying revision metadata, apply the complete independent-review gate below before extracting any task.
3. **Map tasks to user stories** — for each user story in `spec.md`, collect the tasks from `plan.md` that implement it. Tag each task with `[US1]`, `[US2]`, etc.
4. **Identify parallel tasks** — mark with `[P]` any task that touches different files from all other tasks in the same phase (no shared-file writes, no dependency on concurrent tasks)
5. **Assign sequential IDs** — number all tasks `T001`, `T002`, ... in phase order. No letters, no "Task N", no "Step N".
6. **Structure into phases** — verify `tasks-template.md` exists (Read tool) before proceeding; if missing, stop: *"Cannot proceed — `tasks-template.md` is missing. Please reinstall the maxi plugin."* Then follow the template:
   - Phase 1: Setup (project init, no deps)
   - Phase 2: Foundational (blocks all user stories — CRITICAL warning)
   - Phase 3+: One phase per user story
   - Final phase: Polish & Cross-Cutting Concerns
   - A **Checkpoint** line after each phase
7. **Write `tasks.md`** — output to `docs/maxi/specs/NNNN-slug/tasks.md` following the template schema and forward provenance contract below. Include Dependencies & Execution Order section.
8. **Transition status** — update spec.md frontmatter `status: planned → tasked`; also set `updated: [today's ISO date]` on spec.md and on tasks.md. When creating tasks.md, set its frontmatter: `slug` and `spec_slug` from spec, `created` and `updated` to today's ISO date. Status and timestamp changes are non-structural and do not change either document's revision, writer context, or structural contributors.
9. **Report** — *"Tasks written to `docs/maxi/specs/NNNN-slug/tasks.md` (status: `tasked`). Next: a fresh independent `/maxi:analyze`; implementation remains blocked until its current passing evidence is persisted."*

## Independent Plan Review Gate

For a forward-pipeline spec, read `reviews/plan-review.md`, the exact current bytes of `plan.md`, and both frontmatter blocks. Validate all of these as one fail-closed gate:

- the record metadata is well formed, its own `revision` is positive, and its exact `derived_from` input is the current `plan.md` revision;
- `verdict: approved`, `reviewed_document: plan.md`, and `reviewed_revision` equals the current plan revision;
- `reviewed_sha256` equals SHA-256 recomputed from the exact current bytes of `plan.md`;
- `reviewer_context_matches_harness: true`, and the exact `reviewer_context` is absent from the current plan's `structural_contributors`.

A missing, rejected, malformed, stale, or self-reviewed record fails this gate. Stop before task extraction, before any artifact write, and before any status or timestamp transition; leave every artifact unchanged. Never infer, repair, or accept partial evidence.

`x-review` is the sole writer of review records; `tasks` only validates them and never creates, edits, or approves a review record. The read-only replay planner only calculates and displays a continuation. Neither mechanism authorizes `tasks` to create or write `workflow.md` or `.maxi-ops`.

## Forward Provenance Contract

Apply this contract only when creating `tasks.md` for a spec created through the normal forward pipeline. Do not add or infer this metadata on existing, migrated, or reverse-engineered specs.

```yaml
revision: 1
writer_context: <new non-empty context unique across this spec's pipeline-owned documents>
structural_contributors:
  - <the exact writer_context above>
derived_from:
  - <direct-input-path>@<exact-revision-read>
```

Populate `derived_from` with every document read to produce `tasks.md`, including `spec.md`, `plan.md`, every support artifact read, and the current approved `reviews/plan-review.md`. The approval is a direct provenance dependency even when its findings do not contribute task text.

On a later structural owner write, increment only `tasks.md`, replace its `writer_context` with the new unique context, and append that context to `structural_contributors`. Status, timestamps, task-completion checkboxes, and `related_adrs` are non-structural: they never increment revisions or append contributors.

## Task Format

```
- [ ] T001 [P] [US1] Create [Entity] model in src/models/entity.py
- [ ] T002 [US1] Implement [Service] in src/services/service.py (depends on T001)
- [ ] T003 [P] [US2] Create [OtherEntity] model in src/models/other.py
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
- **Parallel markers require no shared files.** If two tasks touch the same file, neither gets `[P]`.
- **MVP Checkpoint after Phase 3 (US1).** Always mark the P1 user story checkpoint as the MVP.
- **Phase structure is required even for single-story features.** One user story = at minimum: Setup → Foundational → Phase 3 (US1) → Polish. A flat list with no phases is never acceptable.
- **Template schema required.** Follow `tasks-template.md` structure. Include Dependencies section.
- **Exact direct inputs.** `tasks.md` derives from every document read, including the current plan and approved plan review, at their exact revisions.
- **No metadata retrofit.** Existing, migrated, and reverse-engineered specs and their artifacts remain unchanged.

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
