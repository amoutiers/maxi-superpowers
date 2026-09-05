# Delegation Map

This table shows which maxi pipeline skill delegates to which sub-skill, what status the spec must be in before the skill runs, and what status it transitions to on success.

## Pipeline Delegation Table

### Forward Pipeline

| maxi skill | Required status | Delegates to | Status transition |
|---|---|---|---|
| `constitution` | — (always runs) | (none — writes `docs/maxi/constitution.md` directly) | — |
| `specify` | constitution exists (no spec status required) | `/maxi:brainstorming` | `drafting → specified` |
| `clarify` | `specified` | (none — interactive Q&A dialogue) | `specified → clarified` |
| `plan` | `clarified` | `/maxi:writing-plans`, then one design review | `clarified → planned` |
| `review` | current `spec.md` and `plan.md`; explicit re-review request | dedicated `skills/review/design-reviewer.md` brief with accepted `related_adrs` and one exact terminal verdict | none; writes `reviews/design-review.md` |
| `tasks` | `planned`; current approved `reviews/design-review.md` | (none — extraction from plan.md) | `planned → tasked` |
| `analyze` | `tasked`, `analyzed`, `implementing`, or `done` | (none — reads artifacts, writes and stamps `analysis.md`) | `tasked → analyzed` (once; reruns don't change status) |
| `implement` | `analyzed` or `implementing` (resume), with a current `maxi-readiness-v1` contract | `/maxi:x-develop` | `analyzed → implementing`; `READY_TO_FINISH` receipt gate; then `implementing → done` |

Every newly written `plan.md` carries exactly one `Global Constraints` section containing only applicable durable cross-task constraints from the spec and constitution; transient execution state and individual mutation authority are excluded, while a durable rule requiring fresh authorization is allowed.

Internal `x-adr` records every new ADR's creating spec through a direct `spec` link, or `spec: null` for a standalone ADR. During an initial active lifecycle that lacks the monotone `reopened_from: done` watermark, a detected change to an accepted ADR linked to the current spec delegates to an agent-proposed active-spec amendment: `x-adr` shows the full amended ADR and exact diff and writes only after explicit approval, with no status transition. Missing or null links, `done`, `parked`, or `cancelled` specs, and reopened specs marked `reopened_from: done` delegate to closed-spec supersession instead.

The 19 Maxi-native skills: 13 user-facing, 2 internal, 1 session, and 3 migration skills. The 10-state FSM remains unchanged. `/maxi:x-develop` maps canonical Maxi `TNNN` tasks to an immutable SDD `Task N` projection. Upstream SDD owns task review, fix rounds, and the final implementation review. `/maxi:x-develop` is the sole incremental Maxi checkbox owner; `/maxi:implement` validates that every task is checked and alone persists `implementing → done`. Branch finishing starts only after Maxi has recorded `done`.

Upstream SDD owns the only whole-branch review. Before final-review work, `/maxi:x-develop` persists the immutable initial task-selection anchor in the ordinary SDD ledger. On Codex it allocates a fresh reviewer for an identity handshake, persists the harness-returned canonical task path, then sends the review through a follow-up to that reviewer. It binds that identity, regenerates each review package from the recorded Git range, and returns `READY_TO_FINISH` only after its hash-bound terminal receipt validates. `/maxi:implement` owns the sole `done` transition and never dispatches a duplicate review.

Current execution uses complete-body `maxi-v2` projections; immutable `maxi-v1` files remain verifiable historical predecessors. New projections retain the preamble and render each selected TNNN heading, canonical checkbox line, and complete mapped plan-task body in tasks-file order. Every canonical task, including checked tasks, requires exactly one terminal `(plan Task N)` mapping, bijective with the positive executable plan headings; missing, duplicate, non-positive, unknown, or unmapped entries require owner correction before publication. Plans must end with LF so extraction preserves the final payload line. Closed three-character backtick or tilde fences, optionally indented, normalize to column-zero triple backticks in the preamble and task bodies while preserving payload bytes. Longer or unclosed delimiters and payload lines that would toggle upstream fence state reject; fenced Task-like headings never enter native selection or completion maps. A validated active v1 projection upgrades only through an ordinary projection call to a new `<slug>-v2-p-<plan12>-t-<tasks12>-sdd.md` successor; its file and ledger remain unchanged. `--verify-only` requires an existing current v2 identity and never creates project directories, evidence, or upgrades. Only an unchanged-source v1 upgrade completed by validated ledgers may create an empty successor, which still requires a fresh final review; all-completed structural changes reject.

Only canonical annotated upstream completion records acquit tasks; bare or malformed completion lines fail closed. The accepted annotations are `review clean` or a positive `K parked`, with exactly two seven-hex commit IDs.

A null fix package requires exactly `**Ready to merge?** Yes`; a non-null byte-exact fix package requires the initial `**Ready to merge?** With fixes` plus exactly `**Fix round:** All findings addressed, no new Critical/Important breakage`.

Every projection's exact distributed bytes are SHA-256-bound by its ordinary SDD ledger; missing, duplicate, malformed, or mismatched projection-byte anchors fail closed across the current and predecessor lineage.

Removing an anchored incomplete `TNNN` during structural correction fails before successor creation and leaves the active-projection pointer unchanged.

Complete ledger lines containing `Ruling:` are preserved byte-for-byte in lineage order and hash-bound by the terminal receipt.

A passing readiness review is valid only when `analysis.md` carries `maxi-readiness-v1` and its recorded structural spec/tasks hashes and exact plan hash match the current artifacts; `/maxi:implement` verifies this before every new or resumed dispatch and otherwise stops for `/maxi:analyze`.

### Fixed Review Boundaries

| Boundary | Successor gate | Owner | Status effect |
|---|---|---|---|
| Design review of current `spec.md` and `plan.md` | Before `tasks` | `plan` invokes the initial review; public `/maxi:review` is explicit re-review | none |
| readiness review of the current design and tasks | Before implementation | `/maxi:analyze` | `tasked → analyzed` |
| Final implementation review | Before branch finishing | Upstream SDD through `/maxi:x-develop` | `implementing → done` only after `READY_TO_FINISH` |

The design review is bound to the complete exact current `spec.md` and `plan.md` pair; a missing or stale approval stops task extraction without a write. Its dedicated artifact brief treats task `Files` lists as expected primary edits, not implementation allowlists. Mechanical callers, declarations, registrations, fixtures, manifests, generated metadata, and lockfiles are nonblocking unless they expose a requirement, feasibility, architecture, contract, decomposition, ordering, safety, or verification defect that requires the reviewed design to change. A correction stops after its owner write and never starts a review or successor phase. Re-review is only the explicit `/maxi:review` command. These boundaries are gates, not statuses or automatic phase transitions.

### Lifecycle Skills

| maxi skill | Required status | Delegates to | Status transition |
|---|---|---|---|
| `board` | any (read-only) | (none — terminal output only) | — |
| `park` | any active status (not `parked`, `cancelled`, `done`) | (none — writes spec.md only) | `<any> → parked` (stores `parked_from:`) |
| `resume` | `parked` | (none — reads `parked_from:`, writes spec.md) | `parked → <parked_from>` (clears `parked_from:`) |
| `cancel` | any active status (not `parked`, `cancelled`, `done`) | (none — writes spec.md only) | `<any> → cancelled` (terminal) |
| `revise` | `clarified` through `implementing`, or `done` | (none — writes spec.md only) | `<any> → <rollback_target>` (A+ picker: `clarified`/`planned`/`tasked`/`analyzed`; exceptional `specified` rollback for a source-spec gap; `done` writes the monotone `reopened_from: done` watermark) |

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
- `/maxi:revise` is the **only skill that makes `status:` go backwards**. It is consent-gated and leaves downstream artefacts in place; a confirmed rollback from `done` writes the monotone `reopened_from: done` watermark.
- The exceptional `specified` rollback is offered only for a demonstrated missing or ambiguous requirement in the source spec; it resumes at `clarify` and never reruns `specify`.
- `/maxi:resume` restores the exact status stored in `parked_from:` — it never asks the user what status to restore to (unless `parked_from:` is missing).
- `/maxi:cancel` is **terminal** — there is no un-cancel path in the pipeline.

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
