---
name: implement
description: Use when the user invokes /maxi:implement or wants to start coding from an existing tasks.md — spec must be at status "analyzed"
---

# implement

Execute the implementation plan from `tasks.md`. Delegates to `maxi:executing-plans`. Transitions spec through `implementing` to `done`.

## Prereqs

- `docs/constitution.md` must exist — hard stop
- Locate spec in `docs/maxi/specs/`. Status rules:
  - `drafting` / `specified` / `clarified` / `planned` / `tasked`: stop — *"Cannot implement — spec must reach `analyzed` status first. Run `/maxi:analyze`. If the spec has no issues, analysis completes quickly and confirms this."*
  - `analyzed`: proceed without warning
  - `implementing`: resume from last incomplete task in `tasks.md`
  - `done`: stop — *"Implementation complete. All tasks are done."*

## Process

1. **Read tasks.md** — load all tasks from `docs/maxi/specs/NNN-slug/tasks.md`. Identify which are `- [ ]` (pending) vs `- [x]` (complete). If resuming, start from first pending task.
2. **Transition to implementing** — update spec.md frontmatter `status: → implementing`; also set `updated: [today's ISO date]` on spec.md. Do this before first task begins.
3. **Delegate to maxi:executing-plans** — **REQUIRED SUB-SKILL.** Pass the full tasks.md content and the spec context (feature slug, plan.md overview). Do NOT implement tasks directly in this session.
4. **Track task completion** — as each task completes, tick it in tasks.md: `- [ ] T001` → `- [x] T001`.
5. **ADR nudge on unplanned forks** — if `maxi:executing-plans` (via subagents) surfaces a decision that wasn't in plan.md — the subagent reports "had to choose between X and Y" or "plan didn't specify Z so I chose W" — invoke `maxi:adr` with the choice details. The ADR skill will draft, show, and wait for user consent. Implementation continues regardless of whether the user accepts or declines the ADR. Do not block task completion on ADR capture.
6. **Run code review** — after all tasks complete, invoke `maxi:requesting-code-review`. **This step is mandatory and cannot be skipped.**
7. **Transition to done** — verify ALL tasks in tasks.md are ticked (`- [x]`). Count remaining `- [ ]` items. If count > 0, do not transition — report which tasks remain. Only when count is 0: update spec.md frontmatter `status: implementing → done` and set `updated: [today's ISO date]`.
8. **Report** — *"Implementation complete. All tasks done. Status: `done`."*

## Critical Rules

- **executing-plans delegation is mandatory.** Do NOT implement tasks inline. Implementing tasks directly in this session is a violation — the full executing-plans workflow (TDD, subagents, verification) is required. There is no "faster path".
- **Update tasks.md incrementally.** Tick each task as it completes — not in a batch at the end.
- **Both statuses required.** `implementing` during work; `done` only when ALL `- [ ]` items become `- [x]`.
- **Verify all tasks before done.** Count remaining `- [ ]` items before transitioning to `done`. If any remain, do not set done.
- **Code review is not optional.** The user cannot waive `maxi:requesting-code-review`. If they say "skip the review", explain it is required and run it anyway.

## Resuming Interrupted Implementation

If status is already `implementing`:
- Read tasks.md to find the first `- [ ]` (unchecked) task
- Resume from there — skip all `- [x]` tasks
- Complete the process through step 7 normally

## Red Flags

- Starting implementation without checking for `- [ ]` vs `- [x]` → read tasks.md first
- Implementing tasks directly instead of invoking `maxi:executing-plans` → delegate; never inline
- Setting `status: done` before counting `- [ ]` items → count first, transition only if count is 0
- Skipping `requesting-code-review` → always run it; user cannot waive it
- Not transitioning to `implementing` before first task → set it immediately before any code is written

## Rationalization Counters

| Rationalization | Counter |
|---|---|
| "I know this code works, we can skip the review" | Code review is mandatory. User assertion of working code does not waive it. Run `maxi:requesting-code-review` regardless. |
| "executing-plans is too slow / heavyweight for this task" | There is no lightweight path. executing-plans is the only acceptable delegation. Inline implementation is a violation. |
| "The user told me all tasks are done, I'll just set status to done" | You must count `- [ ]` items in tasks.md yourself. User assertion is not sufficient. If count > 0, do not transition. |
| "I'll tick all tasks at the end for efficiency" | Tasks must be ticked incrementally as each one completes. Batch-ticking at the end is not acceptable. |
| "Status is already implementing, I'll restart from T001 to be safe" | Resuming means starting from the first `- [ ]` task. Do NOT redo completed (`- [x]`) tasks. |
| "The user says analyze would find nothing, so I can skip it" | User predictions don't replace the analysis phase. `/maxi:analyze` is fast and non-destructive — run it. The pipeline is strict precisely to prevent this class of shortcut. |
| "The plan looks solid, analyze is just ceremony here" | If a phase has its own skill, it has its own responsibility. The plan looking solid is not a substitute for the audit. |
