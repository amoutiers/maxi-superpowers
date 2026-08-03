---
name: implement
description: Use when the user invokes /maxi:implement or wants to start coding from an existing tasks.md — spec must be at status "analyzed"
---

# implement

Execute the implementation plan from `tasks.md`. Delegates to `/maxi:x-develop`. Transitions spec through `implementing` to `done`.

## Prereqs

- `docs/maxi/constitution.md` must exist — hard stop
- Locate spec in `docs/maxi/specs/`. Status rules:
  - `drafting` / `specified` / `clarified` / `planned` / `tasked`: stop — *"Cannot implement — spec must reach `analyzed` status first. Run `/maxi:analyze`. If the spec has no issues, analysis completes quickly and confirms this."*
  - `analyzed`: proceed without warning
  - `implementing`: resume from last incomplete task in `tasks.md`
  - `done`: stop — *"Implementation complete. All tasks are done."*

## Process

1. **Validate independent analysis** — for a forward-pipeline spec carrying revision metadata, apply the complete gate below. Run it on every invocation, including a resume from `implementing`.
2. **Read tasks.md** — load all tasks from `docs/maxi/specs/NNNN-slug/tasks.md`. Identify which are `- [ ]` (pending) vs `- [x]` (complete). If resuming, start from first pending task.
3. **Transition to implementing** — update spec.md frontmatter `status: → implementing`; also set `updated: [today's ISO date]` on spec.md. Do this before first task begins.
4. **Delegate to /maxi:x-develop** — **REQUIRED SUB-SKILL.** Pass the full tasks.md content and the spec context (feature slug, plan.md overview). Do NOT implement tasks directly in this session.
5. **Track task completion** — as each task completes, tick it in tasks.md: `- [ ] T001` → `- [x] T001`.
6. **ADR nudge on unplanned forks** — if `/maxi:x-develop` (via subagents) surfaces a decision that wasn't in plan.md — the subagent reports "had to choose between X and Y" or "plan didn't specify Z so I chose W" — invoke `/maxi:x-adr` with the choice details. The ADR skill will draft, show, and wait for user consent. Implementation continues regardless of whether the user accepts or declines the ADR. Do not block task completion on ADR capture.
7. **Run code review** — after all tasks complete, invoke `/maxi:requesting-code-review`. **This step is mandatory and cannot be skipped.**
8. **Transition to done** — verify ALL tasks in tasks.md are ticked (`- [x]`). Count remaining `- [ ]` items. If count > 0, do not transition — report which tasks remain. Only when count is 0: update spec.md frontmatter `status: implementing → done` and set `updated: [today's ISO date]`.
9. **Report** — *"Implementation complete. All tasks done. Status: `done`."*

## Independent Analysis Gate

Read the complete current `analysis.md`, `spec.md`, `plan.md`, `tasks.md`, and present support artifacts. For a forward-pipeline spec, accept the analysis only when all of these are true:

- `analysis.md` metadata is well formed, has a positive revision, and its `derived_from` entries name the exact current revisions of `spec.md`, `plan.md`, `tasks.md`, and every support artifact it reviewed;
- `reviewer_context_matches_harness: true`, `independence_verified: true`, and `analysis_result: passed` are present exactly;
- `writer_context` equals `reviewer_context`, that context is a contributor to `analysis.md`, and the reviewer_context remains absent from the current `spec.md`, `plan.md`, and `tasks.md` `structural_contributors` lists.

An absent, malformed, stale, failed, or non-independent analysis fails closed. Stop before any status or timestamp change, before any task checkbox write, and before any `x-develop` dispatch; leave all artifacts and implementation files unchanged. Do not infer, repair, or substitute chat-only evidence. A failed gate requests a new user decision but starts no correction or replay.

## Critical Rules

- **x-develop delegation is mandatory.** Do NOT implement tasks inline. Implementing tasks directly in this session is a violation — the full x-develop workflow (TDD, subagents, verification) is required. There is no "faster path".
- **Update tasks.md incrementally.** Tick each task as it completes — not in a batch at the end.
- **Both statuses required.** `implementing` during work; `done` only when ALL `- [ ]` items become `- [x]`.
- **Verify all tasks before done.** Count remaining `- [ ]` items before transitioning to `done`. If any remain, do not set done.
- **Code review is not optional.** The user cannot waive `/maxi:requesting-code-review`. If they say "skip the review", explain it is required and run it anyway.
- **Independent analysis is a pre-write gate.** Status alone is not evidence. Validate the persisted current passing analysis before every new or resumed implementation.

## Resuming Interrupted Implementation

If status is already `implementing`:
- Re-run the independent analysis gate against the current artifacts; stop if it no longer passes
- Read tasks.md to find the first `- [ ]` (unchecked) task
- Resume from there — skip all `- [x]` tasks
- Complete the process through step 8 normally

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.

## Red Flags

- Starting implementation without checking for `- [ ]` vs `- [x]` → read tasks.md first
- Implementing tasks directly instead of invoking `/maxi:x-develop` → delegate; never inline
- Setting `status: done` before counting `- [ ]` items → count first, transition only if count is 0
- Skipping `requesting-code-review` → always run it; user cannot waive it
- Not transitioning to `implementing` before first task → set it immediately before any code is written

## Rationalization Counters

| Rationalization | Counter |
|---|---|
| "I know this code works, we can skip the review" | Code review is mandatory. User assertion of working code does not waive it. Run `/maxi:requesting-code-review` regardless. |
| "x-develop is too slow / heavyweight for this task" | There is no lightweight path. x-develop is the only acceptable delegation. Inline implementation is a violation. |
| "The user told me all tasks are done, I'll just set status to done" | You must count `- [ ]` items in tasks.md yourself. User assertion is not sufficient. If count > 0, do not transition. |
| "I'll tick all tasks at the end for efficiency" | Tasks must be ticked incrementally as each one completes. Batch-ticking at the end is not acceptable. |
| "Status is already implementing, I'll restart from T001 to be safe" | Resuming means starting from the first `- [ ]` task. Do NOT redo completed (`- [x]`) tasks. |
| "The user says analyze would find nothing, so I can skip it" | User predictions don't replace the analysis phase. `/maxi:analyze` is fast and non-destructive — run it. The pipeline is strict precisely to prevent this class of shortcut. |
| "The plan looks solid, analyze is just ceremony here" | If a phase has its own skill, it has its own responsibility. The plan looking solid is not a substitute for the audit. |
