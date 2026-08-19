---
name: using-maxi
description: Use when starting a maxi session, or when the pipeline phases, commands, artifact locations, or status state machine need reference
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

# maxi — Spec-Driven Development Pipeline

maxi grafts a structured spec-driven workflow onto superpowers' implementation engine. Every feature goes through a pipeline of phases, each gated by the previous one.

maxi bundles superpowers skills, available as `maxi:<skill>` (e.g. `/maxi:brainstorming`). The full artifact tree, migration entry points, and vendored-skill notes live in `skills/using-maxi/reference.md` — read it on demand.

## The Pipeline

```
/maxi:constitution  →  establish project principles (REQUIRED FIRST)
/maxi:specify       →  brainstorm & write spec.md (status: specified)
/maxi:clarify       →  answer open questions in spec.md (status: clarified)
/maxi:x-review      →  persist a fresh external reviews/spec-review.md handoff (bounded-v1 roots only; internal; no status change)
/maxi:plan          →  write plan.md + design docs (status: planned)
/maxi:x-review      →  persist a fresh external reviews/plan-review.md handoff (bounded-v1 roots only; internal; no status change)
/maxi:tasks         →  extract tasks.md from plan (status: tasked)
/maxi:analyze       →  7-pass cross-artifact audit → analysis.md (status: analyzed)
/maxi:implement     →  delegate to x-develop; persist done only after READY_TO_FINISH
/maxi:board         →  kanban overview of all specs grouped by status (read-only)
/maxi:migrate-adr   →  import existing ADRs (Nygard/MADR/plain) + discover undocumented decisions from source code

ADRs are captured automatically during /maxi:plan and /maxi:implement — the pipeline proposes ADRs for architectural choices and asks for your consent before writing.
```

## Status State Machine

Every `spec.md` carries `status:` in its YAML frontmatter:

```
drafting → specified → clarified → planned → tasked → analyzed → implementing → done
                                  ↕ parked (resumable from any active status)
                                  ✗ cancelled (terminal)
```

Skills read and enforce this. Running a skill out of order gives a friendly message — not a crash.

The 10-state FSM remains unchanged. The two external review handoffs are gates, not statuses or automatic replay phases.

## Phase Gating

- **Constitution is mandatory.** All workflow skills (except `constitution` itself) will refuse to run if `docs/maxi/constitution.md` is missing.

Each skill enforces the required status strictly:

| Skill | Required status | Tolerance | Produces |
|---|---|---|---|
| `/maxi:constitution` | — | always runs | `docs/maxi/constitution.md` |
| `/maxi:specify` | constitution exists | — | `specified` |
| `/maxi:clarify` | `specified` | none | `clarified` |
| `/maxi:plan` | `clarified`; for marker-bound roots, current approved `reviews/spec-review.md` | none | `planned` |
| `/maxi:tasks` | `planned`; for marker-bound roots, current approved `reviews/plan-review.md` | none | `tasked` |
| `/maxi:analyze` | `tasked`+ | re-run ok on `analyzed`/`implementing`/`done` | `analyzed` |
| `/maxi:implement` | `analyzed` | none | `implementing`; `READY_TO_FINISH` receipt gate; then `done` |

Lifecycle skills act on a spec's status outside the forward flow:

| Skill | Required status | Produces |
|---|---|---|
| `/maxi:board` | any (read-only) | — |
| `/maxi:park` | any active (not `parked`/`cancelled`/`done`) | `parked` |
| `/maxi:resume` | `parked` | restores `parked_from` |
| `/maxi:cancel` | any active (not `parked`/`cancelled`/`done`) | `cancelled` |
| `/maxi:revise` | `clarified` through `implementing` | rolls back to `clarified`/`planned`/`tasked`/`analyzed`; exceptional `specified` rollback for a source-spec gap |

## External Review Handoffs and Replay

Upstream SDD owns the only whole-branch review. Before dispatch, internal `/maxi:x-develop` persists the immutable initial task-selection anchor in the ordinary SDD ledger. It also persists the harness-issued final-reviewer identity before dispatch, regenerates the recorded Git review packages byte-for-byte, and returns `READY_TO_FINISH` only with a valid hash-bound terminal receipt. `/maxi:implement` never dispatches another final review and alone persists `done` after that token.

Only canonical annotated upstream completion records acquit tasks; bare or malformed completion lines fail closed. The accepted annotations are `review clean` or a positive `K parked`, with exactly two seven-hex commit IDs.

- Internal `/maxi:x-review` is the sole writer of `reviews/spec-review.md` and `reviews/plan-review.md`. It delegates a fresh independent review through `superpowers:requesting-code-review`; approved records are persisted and versioned.
- For a marker-bound root, `reviews/spec-review.md` must approve the current `spec.md` revision before `/maxi:plan` writes or changes status. Its `reviews/plan-review.md` must approve the current `plan.md` revision before `/maxi:tasks` writes or changes status.
- A missing, stale, malformed, rejected, or non-independent record blocks only its successor before any write or status transition.
- `skills/revise/replay-plan.sh` is a read-only bounded replay planner. It calculates stale descendants and the shortest executable continuation, stops at the first required review handoff, and never writes artifacts, creates or approves review records, or executes phases.
- A replay never crosses a review handoff automatically. After a matching approval is persisted, the artifact owner displays the remaining continuation and requires a new literal `yes` before executing it.
- `/maxi:revise` offers the exceptional `specified` rollback only for a demonstrated missing or ambiguous requirement in the source spec. That replay begins at `clarify` and never invokes `specify`.
- Bounded replay is future-only. Eligible roots carry exactly one `replay_contract: bounded-v1`; only `/maxi:specify` writes this marker, during normal forward-spec creation. An unmarked existing, migrated, or reverse-engineered spec returns `UNSUPPORTED_LEGACY`; revision metadata alone never opts it in.
- For a marker-bound root, `reviewed_sha256` hashes the canonical structural projection, which omits only root-frontmatter `status:` and `updated:`, preserves every other line in order, and hashes one LF after each retained line. The exact ten-field review envelope is `revision`, `writer_context`, `structural_contributors`, `derived_from`, `reviewed_document`, `reviewed_revision`, `reviewed_sha256`, `reviewer_context`, `reviewer_context_matches_harness`, and `verdict`. Before delegation, artifact write, or status/timestamp change, `plan` and `tasks` require positive record and reviewed revisions, exactly one mapped direct input, the exact current subject/revision/digest, canonical unique contributors and contexts, writer equals reviewer and appears in contributors, harness equality exactly `true`, verdict exactly `approved`, and reviewer independence from the subject contributors.
- The persisted continuation is `replay_continuation: clarify@<current-spec-revision>` after the exceptional source rollback; `/maxi:clarify` can re-present it with `--resume-current-source` after rejection, ambiguity, or interruption. `--resume-current-source` is legal only for `spec.md`, start phase `clarify`, and that matching current marker. Clarification replaces it with `replay_continuation: plan@<current-spec-revision>`. After `x-review` writes the matching spec review, `/maxi:plan` can re-present the spec review continuation with `--resume-current-review`; a consented plan write persists `replay_continuation: tasks@<current-plan-revision>`. After the matching plan review, `/maxi:tasks` can re-present the plan review continuation with `--resume-current-review`. `--resume-current-review` accepts exactly two combinations: `reviews/spec-review.md` with `plan`, or `reviews/plan-review.md` with `tasks`; both require the current subject and review plus every transitive `derived_from` ancestor. Each displayed executable segment requires its own fresh literal `yes`.
- Before plan resume, a stale `spec.md`, support artifact, or specification review is rejected before any continuation output or write, even when `plan.md` and its plan review still match.

Explicit structural corrections are separate owner modes, never implicit re-runs:

| Entry point | Accepted status when explicitly requested | Predecessor gate | Canonical return |
|---|---|---|---|
| Owner-managed plan correction | `planned`, `tasked`, `analyzed`, or `implementing` | current approved `reviews/spec-review.md` | returns only to `planned` |
| owner-managed tasks correction | `tasked`, `analyzed`, or `implementing` | current approved `reviews/plan-review.md` | returns only to `tasked` |

The owner-managed plan correction writes `replay_continuation: tasks@<current-plan-revision>` with the corrected plan before it stops for a fresh plan review. After `x-review` writes a marker-bound approved plan review, it immediately invokes the read-only planner with the predecessor review revision and displays the current approved `tasks -> analyze` continuation. `x-review` never executes a phase or obtains consent. `/maxi:tasks` is only the later no-write resume presenter: it invokes the read-only planner with `--resume-current-review`, redisplays that continuation, and requires a fresh literal `yes` before extraction. Rejection, ambiguity, or session interruption changes nothing and the same current review can be presented again.

Only new specs created through the normal forward pipeline receive this revision and replay behavior; existing, migrated, and reverse-engineered specs remain untouched. For an unmarked root, plan and tasks use the ordinary pipeline: no review record, x-review handoff, review provenance, review reporting, or replay planner is required. This mechanism never creates or writes `workflow.md` or `.maxi-ops`.

> **Note:** Skills are designed to be cheap when there is nothing to do. `/maxi:clarify` completes in seconds if the spec has no ambiguities. `/maxi:analyze` produces a clean report instantly if there are no issues. The discipline cost is bounded; the value is not.

## Getting Started

1. Run `/maxi:constitution` to establish your project's principles.
2. Run `/maxi:specify "your feature description"` to start a new spec.
3. Follow the pipeline from there. Each skill tells you what comes next.

Adopting maxi on an existing project (github-spec-kit, a brownfield codebase, or existing ADRs)? See the migration entry points in `skills/using-maxi/reference.md`.

## Key Rules

- Never skip the constitution step.
- Never hand-edit the `status:` frontmatter — let skills manage it.
- **Invariant — `updated:` field:** Every write to a maxi artifact (`spec.md`, `plan.md`, `tasks.md`, ADR file) must include bumping its `updated:` frontmatter field to today's ISO date (`YYYY-MM-DD`) in the same operation. Never bump in a separate step.
- `/maxi:analyze` is read-only. It writes `analysis.md` but never modifies source artifacts.
- The `analyze` skill requires constitution to be present — constitution principles inform 2 of the 7 audit passes.
- ADRs are append-only. To revise a past decision, create a new ADR that supersedes the old one.
- Existing specs that predate the `updated:`, `spec_slug:`, or `decider:` fields will not have them — skills should tolerate absent optional fields rather than failing.

## Platform Adaptation

If your harness appears here, read its reference file for special instructions (they live with the vendored `using-superpowers` skill at `skills/using-superpowers/references/`):

- Codex: `skills/using-superpowers/references/codex-tools.md`
- Pi: `skills/using-superpowers/references/pi-tools.md`
- Antigravity: `skills/using-superpowers/references/antigravity-tools.md`
