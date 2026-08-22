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

1. **Validate readiness review** — `analysis.md` is the required readiness review of the current design and tasks before code begins. Stop before any write or `/maxi:x-develop` dispatch if it is missing or reports CRITICAL findings.
2. **Bind artifacts** — load the selected root's canonical `spec.md`, `plan.md`, and `tasks.md`. Identify `- [ ]` (pending) and `- [x]` (complete) tasks. Pass the exact canonical `spec.md`, `plan.md`, and `tasks.md` paths to `/maxi:x-develop`.
3. **Transition to implementing** — update spec.md frontmatter `status: → implementing`; also set `updated: [today's ISO date]` on spec.md. Do this before first task begins.
4. **Delegate to /maxi:x-develop** — **REQUIRED SUB-SKILL.** Pass those three paths. Do NOT implement tasks directly in this session. `x-develop` owns projection, incremental reconciliation, upstream SDD, and the whole-branch review.
5. **Consume the result** — Do not tick task checkboxes in this skill; `x-develop` is the one incremental checkbox owner. Do not dispatch another code review; upstream SDD already owns the final review. Accept only the exact `READY_TO_FINISH` token together with its projection lineage and aggregated `Ruling:` lines. Any other result leaves the spec at `implementing` and stops without branch finishing.
6. **ADR nudge on rulings** — for a returned `Ruling:` that records an architectural choice absent from `plan.md`, invoke `/maxi:x-adr`. The ADR skill drafts and requests its own consent. Do not rewrite the ruling or its SDD evidence.
7. **Transition to done** — after `READY_TO_FINISH`, reread `tasks.md` and require every canonical task to be checked. Count remaining `- [ ]` items. If any remain, stop. Otherwise persist `status: implementing → done` and today's `updated:` value.
8. **Finish the branch** — retain the returned projection lineage and aggregated `Ruling:` lines until branch/worktree completion, and invoke `superpowers:finishing-a-development-branch` only after the `done` write is persisted.
9. **Report** — *"Implementation complete. All tasks done. Status: `done`."* Include the retained lineage and rulings in the finishing handoff.

## Critical Rules

- **x-develop delegation is mandatory.** Do NOT implement tasks inline. Implementing tasks directly in this session is a violation — the full x-develop workflow (TDD, subagents, verification) is required. There is no "faster path".
- **One checkbox owner.** `x-develop` reconciles tasks.md incrementally from the upstream ledger. Do not tick task checkboxes in this skill.
- **Both statuses required.** `implementing` during work; `done` only when ALL `- [ ]` items become `- [x]`.
- **Verify all tasks before done.** Count remaining `- [ ]` items before transitioning to `done`. If any remain, do not set done.
- **One final review owner.** Upstream SDD runs the mandatory whole-branch review. Never dispatch a duplicate review from `implement`.
- **Receipt result is mandatory.** Only exact `READY_TO_FINISH` authorizes `implementing → done`.
- **Finish after done.** Branch/worktree finishing is unreachable until `done` is persisted.
- **Readiness analysis is a pre-write gate.** Status alone is not evidence. Validate the current passing analysis before every new or resumed implementation.

## Resuming Interrupted Implementation

If status is already `implementing`:
- Re-run the readiness analysis check against the current artifacts; stop if it no longer passes
- Read tasks.md to find the first `- [ ]` (unchecked) task
- Resume from there — skip all `- [x]` tasks
- Pass the exact artifact paths to `x-develop`, then complete the receipt-gated process normally

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
- Dispatching another review after x-develop returns → do not duplicate upstream's final review
- Not transitioning to `implementing` before first task → set it immediately before any code is written

## Rationalization Counters

| Rationalization | Counter |
|---|---|
| "I know this code works, we can skip the review" | Upstream SDD's whole-branch review and hash-bound receipt are mandatory. No chat assertion replaces them. |
| "x-develop is too slow / heavyweight for this task" | There is no lightweight path. x-develop is the only acceptable delegation. Inline implementation is a violation. |
| "The user told me all tasks are done, I'll just set status to done" | You must count `- [ ]` items in tasks.md yourself. User assertion is not sufficient. If count > 0, do not transition. |
| "I'll tick tasks here too for safety" | Two checkbox owners race. Only x-develop reconciles upstream ledger completion into tasks.md. |
| "Status is already implementing, I'll restart from T001 to be safe" | Resuming means starting from the first `- [ ]` task. Do NOT redo completed (`- [x]`) tasks. |
| "The user says analyze would find nothing, so I can skip it" | User predictions don't replace the analysis phase. `/maxi:analyze` is fast and non-destructive — run it. The pipeline is strict precisely to prevent this class of shortcut. |
| "The plan looks solid, analyze is just ceremony here" | If a phase has its own skill, it has its own responsibility. The plan looking solid is not a substitute for the audit. |
