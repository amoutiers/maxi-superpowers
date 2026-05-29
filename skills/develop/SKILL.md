---
name: develop
description: Use when /maxi:implement delegates execution, or when executing a maxi plan
  via subagent-driven development. Patches known gaps in superpowers:subagent-driven-development.
---

## maxi develop — subagent-driven implementation

Patch directives for `superpowers:subagent-driven-development`. These take precedence where
they conflict with the vanilla skill content.

**Announce at start:** "I'm using Subagent-Driven Development to execute this plan."

**Subagent dispatch:** Always dispatch a fresh implementer subagent — for initial tasks and
fix iterations. Context from previous runs must be passed explicitly in the prompt.

**Review loop cap:** After 3 consecutive fix-review cycles without approval from the same
reviewer, stop and escalate to the human. Persistent disagreement indicates a spec gap,
not a fixable implementation error.

**Task state:** Mark each task `in_progress` in TodoWrite before dispatching its implementer
subagent. Mark it `complete` only after both reviews pass.

**DONE_WITH_CONCERNS:** Before proceeding to the spec reviewer, evaluate the implementer's
concerns. If they touch correctness or scope, address them first; otherwise proceed with a note.

**NEEDS_CONTEXT:** This status is valid mid- or post-task — the implementer attempted work
and hit an information wall. It is not a failure mode; provide the missing context and re-dispatch.

**Integration reviewer:** After all tasks complete, use `./integration-reviewer-prompt.md`
for the whole-implementation review — not `./code-quality-reviewer-prompt.md`.
Capture BASE_SHA (current HEAD) before dispatching the first implementer subagent.

---

Load and follow `superpowers:subagent-driven-development` using the Skill tool.
The patches above take precedence where they conflict with the vanilla content.
