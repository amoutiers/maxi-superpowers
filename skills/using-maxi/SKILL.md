---
name: using-maxi
description: Use when starting a maxi session, or when the pipeline phases, commands, artifact locations, or status state machine need reference
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

# maxi — Spec-Driven Development Pipeline

maxi adds a strict spec-driven pipeline to superpowers. The 19 Maxi-native skills: 13 user-facing, 2 internal, 1 session, and 3 migration skills.

## The Pipeline

```
/maxi:constitution  → establish project principles
/maxi:specify       → write spec.md (specified)
/maxi:clarify       → resolve open questions (clarified)
/maxi:plan          → write plan.md (planned), then one design review
/maxi:tasks         → extract tasks.md after a current design review (tasked)
/maxi:analyze       → stamped readiness review before implementation (analyzed)
/maxi:implement     → require current readiness contract; delegate to x-develop
```

Every newly written `plan.md` carries exactly one `Global Constraints` section containing only applicable durable cross-task constraints from the spec and constitution; transient execution state and individual mutation authority are excluded, while a durable rule requiring fresh authorization is allowed.

Every new ADR records its creating spec through a direct `spec` link as `spec: <full-spec-slug>`, or `spec: null` when standalone. For an initial active lifecycle that lacks `reopened_from: done`, an agent detecting a change to an accepted ADR whose `spec` equals the current spec slug invokes internal `x-adr` for an agent-proposed active-spec amendment: it shows the full amended ADR and exact diff, then writes only after explicit approval. `reopened_from: done` is a monotone lifecycle watermark: a spec reopened with `/maxi:revise` uses supersession for accepted linked ADRs even while its status is active. Unlinked, closed-spec, or reopened-spec ADRs use closed-spec supersession instead.

## Status State Machine

```
drafting → specified → clarified → planned → tasked → analyzed → implementing → done
                                  ↕ parked (resumable from any active status)
                                  ✗ cancelled (terminal)
```

The 10-state FSM remains unchanged. The three fixed review boundaries are design review after the normal plan write, readiness review in `/maxi:analyze` before implementation, and the upstream SDD final implementation review. They are gates, not statuses or automatic phase transitions.

## Phase Gating

| Skill | Required status | Produces |
|---|---|---|
| `/maxi:constitution` | — | `docs/maxi/constitution.md` |
| `/maxi:specify` | constitution exists | `specified` |
| `/maxi:clarify` | `specified` | `clarified` |
| `/maxi:plan` | `clarified` | `planned`, then one design review |
| `/maxi:review` | current `spec.md` and `plan.md`; explicit re-review request | `reviews/design-review.md` |
| `/maxi:tasks` | `planned` plus current approved `reviews/design-review.md` | `tasked` |
| `/maxi:analyze` | `tasked`+ | `analyzed` plus stamped `maxi-readiness-v1` report |
| `/maxi:implement` | `analyzed` or `implementing`; current `maxi-readiness-v1` contract | `done` after `READY_TO_FINISH` |

The design review uses `skills/review/design-reviewer.md` and supplies the complete current `spec.md`, `plan.md`, and accepted ADRs named by `spec.md`'s `related_adrs`. It records SHA-256 values for the spec/plan pair and writes only after one exact terminal verdict. Task `Files` lists identify expected primary edits, not implementation allowlists. Mechanical callers, module declarations, registrations, fixtures, manifests, generated metadata, and lockfiles are nonblocking when they only implement the reviewed owning task without changing requirements, behavior beyond that task, feasibility, architecture, public contracts, task decomposition, dependency order, safety, or verification. A missing or stale approval stops `/maxi:tasks` before any write. Corrections stop after their owner write and never start a review or successor phase; request `/maxi:review` when a re-review is wanted.

A passing readiness review is valid only when `analysis.md` carries `maxi-readiness-v1` and its recorded structural spec/tasks hashes and exact plan hash match the current artifacts; `/maxi:implement` verifies this before every new or resumed dispatch and otherwise stops for `/maxi:analyze`.

## SDD Final Review

`/maxi:x-develop` maps canonical Maxi `TNNN` tasks to an immutable SDD `Task N` projection. Upstream SDD owns task review, fix rounds, and the final implementation review. `/maxi:x-develop` is the sole incremental Maxi checkbox owner; `/maxi:implement` validates that every task is checked and alone persists `implementing → done`. Branch finishing starts only after Maxi has recorded `done`.

Upstream SDD owns the only whole-branch review. Before final-review work, internal `x-develop` persists the immutable initial task-selection anchor in the ordinary SDD ledger. On Codex it allocates a fresh reviewer for an identity handshake, persists the harness-returned canonical task path, then sends the review through a follow-up to that reviewer. It also owns immutable task projection, ledger reconciliation, byte-exact Git review packages, and the hash-bound terminal receipt. It returns `READY_TO_FINISH` only when all evidence validates. `implement` owns the sole `implementing → done` transition and never dispatches a duplicate final review.

Only canonical annotated upstream completion records acquit tasks; bare or malformed completion lines fail closed. The accepted annotations are `review clean` or a positive `K parked`, with exactly two seven-hex commit IDs.

A null fix package requires exactly `**Ready to merge?** Yes`; a non-null byte-exact fix package requires the initial `**Ready to merge?** With fixes` plus exactly `**Fix round:** All findings addressed, no new Critical/Important breakage`.

Every projection's exact distributed bytes are SHA-256-bound by its ordinary SDD ledger; missing, duplicate, malformed, or mismatched projection-byte anchors fail closed across the current and predecessor lineage.

Removing an anchored incomplete `TNNN` during structural correction fails before successor creation and leaves the active-projection pointer unchanged.

Complete ledger lines containing `Ruling:` are preserved byte-for-byte in lineage order and hash-bound by the terminal receipt.

## Key Rules

- Never skip the constitution step.
- Never hand-edit `status:` frontmatter.
- ADRs are append-only after their creating spec closes. An agent-proposed, explicitly approved `x-adr` amendment is permitted only during its linked spec's initial active lifecycle; `reopened_from: done` requires supersession.
