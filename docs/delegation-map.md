# Delegation Map

This table shows which maxi pipeline skill delegates to which superpowers sub-skill, what status the spec must be in before the skill runs, and what status it transitions to on success.

## Pipeline Delegation Table

| maxi skill | Required status | Delegates to | Status transition |
|---|---|---|---|
| `constitution` | — (always runs) | (none — writes `docs/constitution.md` directly) | — |
| `specify` | constitution exists (no spec status required) | `maxi:brainstorming` | `drafting → specified` |
| `clarify` | `specified` | (none — interactive Q&A dialogue) | `specified → clarified` |
| `plan` | `clarified` | `maxi:writing-plans` | `clarified → planned` |
| `tasks` | `planned` | (none — extraction from plan.md) | `planned → tasked` |
| `analyze` | `tasked`, `analyzed`, `implementing`, or `done` | (none — reads artifacts, writes analysis.md) | `tasked → analyzed` (once; reruns don't change status) |
| `implement` | `analyzed` | `maxi:executing-plans`, then `maxi:requesting-code-review` | `analyzed → implementing → done` |

### Notes

- `/maxi:analyze` can be rerun at any status from `tasked` onward — it is non-destructive and never modifies source artifacts. Status does not change on subsequent runs.
- `/maxi:implement` resumes from `implementing` if an earlier run was interrupted — it starts from the first unchecked `- [ ]` task.

## Accessing Superpowers Skills Directly

All vendored superpowers skills are available to Claude under the `maxi:` namespace. You do not need to invoke them manually — the pipeline skills call them automatically — but you can invoke them directly when needed:

| Skill | What it does |
|---|---|
| `maxi:brainstorming` | Guided design dialogue to explore requirements and constraints |
| `maxi:writing-plans` | Structured technical planning with file layout and task decomposition |
| `maxi:executing-plans` | Step-by-step plan execution with checkpoints |
| `maxi:writing-skills` | Author new SKILL.md files using TDD (required for all new maxi skills) |
| `maxi:systematic-debugging` | Root-cause analysis before proposing fixes |
| `maxi:test-driven-development` | Red-green-refactor cycle before writing implementation code |
| `maxi:verification-before-completion` | Run verification commands before claiming work is done |
| `maxi:finishing-a-development-branch` | Structured options for merge, PR, or cleanup |
| `maxi:using-git-worktrees` | Isolated workspace setup for feature work |
| `maxi:dispatching-parallel-agents` | Spawn independent sub-agents for parallel tasks |
| `maxi:subagent-driven-development` | Execute parallel independent tasks in the current session |
| `maxi:requesting-code-review` | Verify work meets requirements before merging |
| `maxi:receiving-code-review` | Process review feedback with technical rigor |

These skills are vendored from [superpowers v5.1.0](https://github.com/obra/superpowers). Do not hand-edit them — run `scripts/sync-superpowers.sh` after any version bump.
