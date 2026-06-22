---
name: x-develop
description: Use when /maxi:implement delegates execution, or when executing a maxi plan via subagent-driven development
---

## maxi develop — subagent-driven implementation

Patch directives for `superpowers:subagent-driven-development`. These take precedence where
they conflict with the vanilla skill content. The vanilla skill now handles implementer status
codes (`DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, `BLOCKED`), BASE-commit capture + `review-package`,
the durable progress ledger, and the final whole-branch review natively — follow it for those.
The patches below are the gaps it still leaves.

**Announce at start:** "I'm using Subagent-Driven Development to execute this plan."

**Fresh subagent per dispatch:** Always dispatch a fresh implementer subagent — for initial
tasks and for fix iterations. A fix subagent never inherits the prior run's context; pass
everything it needs explicitly in the dispatch (the task brief, the reviewer's findings, the
report file).

**Review loop cap:** After 3 consecutive fix-review cycles on the same task without the task
reviewer approving, stop and escalate to the human. Persistent disagreement signals a spec gap,
not a fixable implementation error. The vanilla skill has no cap — this is a maxi addition.

**Task completion gate:** Mark a task `complete` — in both the todo list and the progress
ledger — only after its task review passes (spec compliance AND code quality). Trust the ledger
across compaction: a task it lists as complete is done; never re-dispatch it.

**Final whole-branch review — cross-task emphasis:** The vanilla skill runs the final review
once, after all tasks, via `superpowers:requesting-code-review`'s `code-reviewer.md`. Use that
template as-is. In the constraints block you hand it, add a cross-task emphasis so the reviewer
also covers what only a whole-branch view catches: cross-task naming and pattern consistency,
interface fit between separately-built components, gaps that fall between tasks, and regressions
where a later task broke an earlier one's work. This is additive emphasis, not suppression — do
not tell the reviewer what *not* to flag.

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.

---

Load and follow `superpowers:subagent-driven-development` using the Skill tool.
The patches above take precedence where they conflict with the vanilla content.
