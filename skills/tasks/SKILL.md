---
name: tasks
description: Use when the user invokes /maxi:tasks or wants to extract a structured task list from an existing plan.md — spec must be at status "planned"
---

# tasks

Extract or explicitly correct a structured `tasks.md` from an existing `plan.md`. Pure extraction, no delegation. Produces checkbox tasks with parallel markers, story labels, and phase checkpoints.

## Prereqs

- `docs/maxi/constitution.md` must exist — hard stop if missing
- For a marked root, normal initial extraction is legal only at status `planned`, with plan revision `1` and no `replay_continuation` marker. An unmarked revision-bearing spec, including pre-mechanism 0019, uses ordinary legacy initial extraction at `planned` with any plan revision: no review record, `x-review` handoff, review provenance, review reporting, replay continuation, or planner. Other statuses:
  - `drafting` / `specified` / `clarified`: stop — *"Spec must reach `planned` status first. Run `/maxi:plan`."*
  - `tasked` or later, without an explicit structural correction request: stop — *"Tasks already extracted. Proceed to `/maxi:analyze` or `/maxi:implement`."*
- An explicit structural tasks correction is a separate owner mode. It accepts only `tasked`, `analyzed`, or `implementing`; `parked`, `cancelled`, and `done` remain blocked. Never infer correction mode from an ordinary `/maxi:tasks` invocation.
- At `planned`, only an exact `replay_contract: bounded-v1` root marker may make `replay_continuation: tasks@<current-plan-revision>` a pending continuation. Use the no-write resume presenter below only for that marked root.
- At `planned`, only a marked root with a plan revision greater than `1` and a missing or malformed marker fails closed before task extraction, any artifact write, status transition, or review mutation. It never falls through to normal initial extraction.

## Process

1. **Read inputs** — load `plan.md` as primary source; also load `spec.md`, `research.md`, `data-model.md`, and `contracts/` if they exist alongside it in `docs/maxi/specs/NNNN-slug/`. For a marked root, also load the current approved `reviews/plan-review.md`. For an unmarked root, read `plan.md`, optional ordinary inputs, and `spec.md`; do not read a review or invoke `x-review`.
2. **Validate the plan review** — only when the root carries the exact `replay_contract: bounded-v1` marker, apply the complete independent-review gate below before extracting any task.
3. **Map tasks to user stories** — for each user story in `spec.md`, collect the tasks from `plan.md` that implement it. Tag each task with `[US1]`, `[US2]`, etc.
4. **Identify parallel tasks** — mark with `[P]` any task that touches different files from all other tasks in the same phase (no shared-file writes, no dependency on concurrent tasks)
5. **Assign sequential IDs and source mappings** — number all tasks `T001`, `T002`, ... in phase order. Preserve exactly one terminal `(plan Task <positive integer>)` mapping on every extracted item, naming the source `plan.md` `Task N` heading. Require a bijection between `plan.md` executable `Task N` headings and those mappings. No letters, no "Task N" IDs, and no "Step N" IDs.
6. **Structure into phases** — verify `tasks-template.md` exists (Read tool) before proceeding; if missing, stop: *"Cannot proceed — `tasks-template.md` is missing. Please reinstall the maxi plugin."* Then follow the template:
   - Phase 1: Setup (project init, no deps)
   - Phase 2: Foundational (blocks all user stories — CRITICAL warning)
   - Phase 3+: One phase per user story
   - Final phase: Polish & Cross-Cutting Concerns
   - A **Checkpoint** line after each phase
7. **Write `tasks.md`** — output to `docs/maxi/specs/NNNN-slug/tasks.md` following the template schema and forward provenance contract below. Include Dependencies & Execution Order section.
8. **Transition status** — update spec.md frontmatter `status: planned → tasked`; also set `updated: [today's ISO date]` on spec.md and on tasks.md. When creating tasks.md, set its frontmatter: `slug` and `spec_slug` from spec, `created` and `updated` to today's ISO date. Status and timestamp changes are non-structural and do not change either document's revision, writer context, or structural contributors.
9. **Report** — for a marked root: *"Tasks written to `docs/maxi/specs/NNNN-slug/tasks.md` (status: `tasked`). Next: a fresh independent `/maxi:analyze`; implementation remains blocked until its current passing evidence is persisted."* For an unmarked root, use the ordinary legacy analysis report with no review reporting.

## Pending Plan Continuation Presenter

At `planned`, only an exact `replay_contract: bounded-v1` root marker may activate this presenter. For that marked root, treat `replay_continuation: tasks@<current-plan-revision>` as a pending continuation, never as normal initial extraction. Before extraction, status transition, review mutation, or any other write, validate the current approved plan review and the exact marker, read the current plan-review revision, and invoke exactly:

```bash
bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed reviews/plan-review.md --previous-revision <current-plan-review-revision> --start-phase tasks --resume-current-review
```

Display the planner's exact `CONTINUATION|tasks@<current-plan-revision>`, `REPLAY|tasks`, and `REPLAY|analyze` records, then wait. Only a fresh literal `yes` immediately after this display authorizes extraction. Immediately before writing, revalidate the marker, complete review envelope, and current ancestry; any intervening change cancels that consent.

Consent binding: require a fresh literal `yes` immediately after the display, then revalidate the marker and review before writing.

A rejection, ambiguous response, or session interruption changes nothing. A later `/maxi:tasks` repeats this no-write presenter path without creating or replacing a review record and without requiring a historical predecessor record. A missing, stale, or malformed marker or review fails closed before displaying the continuation. A first-created plan with no marker stays on the normal extraction path.

## Explicit Structural Tasks Correction

Use this owner mode only when the user explicitly requests a structural correction to `tasks.md` and status is `tasked`, `analyzed`, or `implementing`. `parked`, `cancelled`, and `done` are blocked.

1. For a marked root, apply the Independent Plan Review Gate before any write. A predecessor review failure leaves every artifact and status unchanged. An unmarked root performs the ordinary correction with no review record, `x-review` handoff, review provenance, review reporting, replay continuation, or planner.
2. Read `tasks.md` and capture its previous tasks revision before any write.
3. Perform the requested pure extraction correction, increment only `tasks.md`, replace its active writer context with the fresh correction context, and append that context to its contributors.
4. For a marked root, return the spec status only to `tasked`, display the result of `bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed tasks.md --previous-revision <captured> --start-phase analyze`, and wait. Only a fresh literal `yes` after this newly displayed proposal may invoke `analyze`. For an unmarked root, return only to `tasked` without a continuation, planner, or review report.

This correction never invokes `specify`, `clarify`, or `plan`. A rejected or failed proposal leaves the completed tasks owner write in place, starts no descendant, and never edits `plan.md` or `analysis.md`.

## Independent Plan Review Gate

Apply this gate only when `spec.md` carries the exact `replay_contract: bounded-v1` root marker. Revision metadata alone never activates this review gate; an unmarked existing, migrated, reverse-engineered, or pre-mechanism spec keeps its prior behavior. For an eligible spec, read `reviews/plan-review.md`, the exact current bytes of `plan.md`, and both frontmatter blocks. Validate all of these as one fail-closed gate:

- Require exactly ten top-level fields in this order-independent set: `revision`, `writer_context`, `structural_contributors`, `derived_from`, `reviewed_document`, `reviewed_revision`, `reviewed_sha256`, `reviewer_context`, `reviewer_context_matches_harness`, and `verdict`; reject every missing, extra, or duplicate field.
- Require positive record and reviewed revisions, exactly one mapped direct input `plan.md@<reviewed_revision>`, canonical and unique contributors, canonical `writer_context` and `reviewer_context`, and require that the writer equals reviewer and appears in the record contributors.
- Require `reviewed_document: plan.md`, `reviewed_revision` equal to the current plan revision, and `reviewed_sha256` equal to the current `plan.md` SHA-256 computed from the canonical structural projection that omits only top-level `status:` and `updated:` in the first frontmatter block.
- Require `reviewer_context_matches_harness: true`, `verdict: approved`, and the exact `reviewer_context` absent from the current plan's `structural_contributors`.

A missing, rejected, malformed, stale, or self-reviewed record fails this gate. Stop before task extraction, before any artifact write, and before any status or timestamp transition; leave every artifact unchanged. Never infer, repair, or accept partial evidence.

`x-review` is the sole writer of review records; `tasks` only validates them and never creates, edits, or approves a review record. The read-only replay planner only calculates and displays a continuation. Neither mechanism authorizes `tasks` to create or write `workflow.md` or `.maxi-ops`.

## Forward Provenance Contract

Apply this contract only when the root carries the exact `replay_contract: bounded-v1` marker. Do not add or infer this metadata on an unmarked existing, migrated, reverse-engineered, or revision-bearing pre-mechanism spec.

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
- **Exact direct inputs.** For a marked root, `tasks.md` derives from every document read, including the current plan and approved plan review, at their exact revisions.
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
