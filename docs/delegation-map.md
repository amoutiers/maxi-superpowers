# Delegation Map

This table shows which maxi pipeline skill delegates to which sub-skill, what status the spec must be in before the skill runs, and what status it transitions to on success.

## Pipeline Delegation Table

### Forward Pipeline

| maxi skill | Required status | Delegates to | Status transition |
|---|---|---|---|
| `constitution` | — (always runs) | (none — writes `docs/maxi/constitution.md` directly) | — |
| `specify` | constitution exists (no spec status required) | `/maxi:brainstorming` | `drafting → specified` |
| `clarify` | `specified` | (none — interactive Q&A dialogue) | `specified → clarified` |
| `plan` | `clarified`; for marker-bound roots, current approved `reviews/spec-review.md` | `/maxi:writing-plans` | `clarified → planned` |
| `tasks` | `planned`; for marker-bound roots, current approved `reviews/plan-review.md` | (none — extraction from plan.md) | `planned → tasked` |
| `analyze` | `tasked`, `analyzed`, `implementing`, or `done` | (none — reads artifacts, writes analysis.md) | `tasked → analyzed` (once; reruns don't change status) |
| `implement` | `analyzed` | `/maxi:x-develop` | `analyzed → implementing`; `READY_TO_FINISH` receipt gate; then `implementing → done` |

Upstream SDD owns the only whole-branch review. Before dispatch, `/maxi:x-develop` persists the immutable initial task-selection anchor in the ordinary SDD ledger. It also binds its harness-issued reviewer identity, regenerates each review package from the recorded Git range, and returns `READY_TO_FINISH` only after its hash-bound terminal receipt validates. `/maxi:implement` owns the sole `done` transition and never dispatches a duplicate review.

### External Review Handoffs

| Handoff | Successor gate | Record owner | Status effect |
|---|---|---|---|
| Review current `spec.md` (marker-bound root) | Before `plan` | `/maxi:x-review` writes `reviews/spec-review.md` after a fresh independent review | none |
| Review current `plan.md` (marker-bound root) | Before `tasks` | `/maxi:x-review` writes `reviews/plan-review.md` after a fresh independent review | none |

The review records are persisted and versioned. These handoffs are gates, not statuses or automatic replay phases. The 10-state FSM remains unchanged.

`skills/revise/replay-plan.sh` is the read-only bounded replay planner used by artifact owners. It calculates the shortest stale-descendant continuation, stops before the first required external review handoff, and never writes artifacts, creates or approves review records, or executes phases.

Bounded replay is future-only. Eligible roots carry exactly one `replay_contract: bounded-v1`; only `/maxi:specify` writes this marker, during normal forward-spec creation. An unmarked existing, migrated, or reverse-engineered spec returns `UNSUPPORTED_LEGACY`; revision metadata alone never opts it in.

For a marker-bound root, `reviewed_sha256` hashes the canonical structural projection, which omits only root-frontmatter `status:` and `updated:`, preserves every other line in order, and hashes one LF after each retained line. The exact ten-field review envelope is `revision`, `writer_context`, `structural_contributors`, `derived_from`, `reviewed_document`, `reviewed_revision`, `reviewed_sha256`, `reviewer_context`, `reviewer_context_matches_harness`, and `verdict`. Before delegation, artifact write, or status/timestamp change, `plan` and `tasks` require positive record and reviewed revisions, exactly one mapped direct input, the exact current subject/revision/digest, canonical unique contributors and contexts, writer equals reviewer and appears in contributors, harness equality exactly `true`, verdict exactly `approved`, and reviewer independence from the subject contributors.

The persisted continuation is `replay_continuation: clarify@<current-spec-revision>` after the exceptional source rollback; `/maxi:clarify` can re-present it with `--resume-current-source` after rejection, ambiguity, or interruption. `--resume-current-source` is legal only for `spec.md`, start phase `clarify`, and that matching current marker. Clarification replaces it with `replay_continuation: plan@<current-spec-revision>`. After `x-review` writes the matching spec review, `/maxi:plan` can re-present the spec review continuation with `--resume-current-review`; a consented plan write persists `replay_continuation: tasks@<current-plan-revision>`. After the matching plan review, `/maxi:tasks` can re-present the plan review continuation with `--resume-current-review`. `--resume-current-review` accepts exactly two combinations: `reviews/spec-review.md` with `plan`, or `reviews/plan-review.md` with `tasks`; both require the current subject and review plus every transitive `derived_from` ancestor. Each displayed executable segment requires its own fresh literal `yes`.

Before plan resume, a stale `spec.md`, support artifact, or specification review is rejected before any continuation output or write, even when `plan.md` and its plan review still match.

### Owner-Managed Corrections

| Entry point | Accepted status when explicitly requested | Predecessor gate | Canonical return |
|---|---|---|---|
| Owner-managed plan correction | `planned`, `tasked`, `analyzed`, or `implementing` | current approved `reviews/spec-review.md` | returns only to `planned` |
| owner-managed tasks correction | `tasked`, `analyzed`, or `implementing` | current approved `reviews/plan-review.md` | returns only to `tasked` |

The owner-managed plan correction writes `replay_continuation: tasks@<current-plan-revision>` with the corrected plan before it stops for a fresh plan review. After `x-review` writes a marker-bound approved plan review, it immediately invokes the read-only planner with the predecessor review revision and displays the current approved `tasks -> analyze` continuation. `x-review` never executes a phase or obtains consent. `/maxi:tasks` is only the later no-write resume presenter: it invokes the read-only planner with `--resume-current-review`, redisplays that continuation, and requires a fresh literal `yes` before extraction. Rejection, ambiguity, or session interruption changes nothing and the same current review can be presented again. Neither correction is a new phase or status.

Only new specs created through the normal forward pipeline receive this revision and replay behavior; existing, migrated, and reverse-engineered specs remain untouched. For an unmarked root, plan and tasks use the ordinary pipeline: no review record, x-review handoff, review provenance, review reporting, or replay planner is required. This mechanism never creates or writes `workflow.md` or `.maxi-ops`.

### Lifecycle Skills

| maxi skill | Required status | Delegates to | Status transition |
|---|---|---|---|
| `board` | any (read-only) | (none — terminal output only) | — |
| `park` | any active status (not `parked`, `cancelled`, `done`) | (none — writes spec.md only) | `<any> → parked` (stores `parked_from:`) |
| `resume` | `parked` | (none — reads `parked_from:`, writes spec.md) | `parked → <parked_from>` (clears `parked_from:`) |
| `cancel` | any active status (not `parked`, `cancelled`, `done`) | (none — writes spec.md only) | `<any> → cancelled` (terminal) |
| `revise` | `clarified` through `implementing` | (none — writes spec.md only) | `<any> → <rollback_target>` (A+ picker: `clarified`/`planned`/`tasked`/`analyzed`; exceptional `specified` rollback for a source-spec gap) |

### Ingress / Migration Skills

These skills ingest *already-implemented* work, so they may set a terminal/advanced status on spec creation (constitution v1.4.0 ingress clause, [ADR-0011](maxi/adr/0011-migration-ingress-terminal-status.md)). They mark provenance and never alter forward-spec gating.

| maxi skill | Required status | Delegates to | Status transition |
|---|---|---|---|
| `migrate-from-speckit` | — (standalone) | (none — runs `migrate.sh`) | creates specs at inferred status (`specified`/`planned`/`tasked`/`done`) |
| `migrate-from-brownfield` | — (standalone) | `/maxi:dispatching-parallel-agents`, `brownfield.sh` | creates specs at `done` with `origin: reverse-engineered` + `source_sha` |
| `migrate-adr` | — (standalone) | `/maxi:dispatching-parallel-agents` | (no spec status — bootstraps `docs/maxi/adr/`) |

### Notes

- `/maxi:analyze` can be rerun at any status from `tasked` onward — it is non-destructive and never modifies source artifacts. Status does not change on subsequent runs.
- `/maxi:implement` resumes from `implementing` if an earlier run was interrupted — it starts from the first unchecked `- [ ]` task.
- `/maxi:revise` is the **only skill that makes `status:` go backwards**. It is consent-gated and leaves downstream artefacts in place (flagged stale in `## Clarifications`).
- The exceptional `specified` rollback is offered only for a demonstrated missing or ambiguous requirement in the source spec; its replay starts at `clarify` and never replays `specify`.
- `/maxi:resume` restores the exact status stored in `parked_from:` — it never asks the user what status to restore to (unless `parked_from:` is missing).
- `/maxi:cancel` is **terminal** — there is no un-cancel path in the pipeline.
- A replay proposal never crosses a review handoff automatically. After `/maxi:x-review` persists a matching approval, the owner displays the remaining continuation and requires a new literal `yes` before execution.

## Accessing Superpowers Skills Directly

All vendored superpowers skills are available to Claude under the `maxi:` namespace. You do not need to invoke them manually — the pipeline skills call them automatically — but you can invoke them directly when needed:

| Skill | What it does |
|---|---|
| `/maxi:brainstorming` | Guided design dialogue to explore requirements and constraints |
| `/maxi:writing-plans` | Structured technical planning with file layout and task decomposition |
| `/maxi:executing-plans` | Step-by-step plan execution with checkpoints (available directly; no longer the pipeline delegate — see `/maxi:x-develop`) |
| `/maxi:writing-skills` | Author new SKILL.md files using TDD (required for all new maxi skills) |
| `/maxi:systematic-debugging` | Root-cause analysis before proposing fixes |
| `/maxi:test-driven-development` | Red-green-refactor cycle before writing implementation code |
| `/maxi:verification-before-completion` | Run verification commands before claiming work is done |
| `/maxi:finishing-a-development-branch` | Structured options for merge, PR, or cleanup |
| `/maxi:using-git-worktrees` | Isolated workspace setup for feature work |
| `/maxi:dispatching-parallel-agents` | Spawn independent sub-agents for parallel tasks |
| `/maxi:subagent-driven-development` | Dispatch fresh subagents per task with two-stage review |
| `/maxi:requesting-code-review` | Verify work meets requirements before merging |
| `/maxi:receiving-code-review` | Process review feedback with technical rigor |

These skills are vendored from [superpowers v6.3.0](https://github.com/obra/superpowers). Do not hand-edit them — run `scripts/sync-superpowers.sh` after any version bump.
