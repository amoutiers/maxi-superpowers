---
name: revise
description: Use when the user invokes /maxi:revise, says requirements changed, the spec needs updating, or the plan needs to change — requires spec at clarified or later, rolls back status with A+ picker and consent.
---

# revise

Roll back a spec to an earlier pipeline phase when requirements or design change. The first skill that makes `status:` go backwards.

## Prereqs

- `docs/maxi/constitution.md` must exist — hard stop if missing.
- Locate target spec. If multiple in-flight specs, ask which one.
- **Refuse** if `status: drafting` or `specified` → *"Spec is at `<status>` — use `/maxi:clarify` or `/maxi:specify` instead."*
- **Refuse** if `status: parked` → *"Spec is parked. Run `/maxi:resume` first, then `/maxi:revise`."*
- **Refuse** if `status: cancelled` → *"Spec is cancelled. Cannot revise."*
- **Refuse** if `status: done` → *"Spec is done (shipped). To revise, create a new spec with `/maxi:specify`."*
- Valid for: `clarified`, `planned`, `tasked`, `analyzed`, `implementing`.

## Process

1. **Ask**: *"Describe the change that requires revision."* — require a non-empty answer.

2. **A+ picker — infer suggested rollback target with justification**:
   - A real missing or ambiguous requirement in the current source `spec.md` that must be resolved by clarification → suggest the exceptional rollback target `specified`
   - Requirements change / new FR / dropped FR / user story change / scope change → suggest `clarified`
   - Plan change / architecture change / technical decision / new component → suggest `planned`
   - Task extraction error / missing tasks / wrong phasing → suggest `tasked`
   - Analysis finding needs revisiting → suggest `analyzed`

   **Always show the suggestion with one sentence of reasoning before offering the full list:**
   > *"Based on your description, I suggest rolling back to `<target>` — <one-sentence justification>. This means re-running: <list of phases that follow>. Accept this, or choose a different target: `[clarified | planned | tasked | analyzed]`. The exceptional `specified` target is offered only for a demonstrated source-spec gap."*

3. **Constitution check**: before asking for confirmation, scan constitution.md. If the described change would violate a principle, flag it now: *"Note: `<principle>` may conflict with this change — `<brief reason>`. Do you want to proceed anyway?"* Do not silently proceed past a potential violation.

4. **Confirm**:
   > *"About to roll back `<slug>` from `<current>` to `<target>`. Downstream artefacts (plan.md, tasks.md, analysis.md as applicable) will stay on disk but are stale — the next pipeline skill will regenerate them. Proceed? (yes/no)"*

5. **On explicit `yes` only**: capture the current `spec.md` revision, then write `spec.md` —
   - `status: <target>`
   - `updated: <today's ISO date>`
   - Append to `## Clarifications`:
     `**Revised (YYYY-MM-DD):** Rolled back from \`<current>\` to \`<target>\`. Change: <description>. Note: artefacts from phases after \`<target>\` (if any) are stale.`
   - Only the exact `replay_contract: bounded-v1` root marker activates revision, provenance, replay_continuation, and planner behavior. For that marked spec, increment only `spec.md`, replace `writer_context` with this write's new unique context, and append that context to `structural_contributors`. The status and timestamp are non-structural; the persisted revision note is the structural owner change. An unmarked revision-bearing spec, including pre-mechanism 0019, follows legacy revise: no provenance, no replay continuation, and no planner.
   - For a marked exceptional `specified` target, persist `replay_continuation: clarify@<new-spec-revision>` in the same structural `spec.md` write. The marker binds only the newly written spec revision and survives a rejected, ambiguous, or interrupted replay proposal.

6. **Calculate and display replay**: only for a marked spec, call the read-only `skills/revise/replay-plan.sh` with `--changed spec.md`, the captured previous revision, and the next valid producer as `--start-phase`. A `specified` rollback starts at `clarify`; never rerun or replay `specify`. Follow the bounded replay contract below.

7. **Report**: *"Spec `<slug>` is now at `<target>`. The displayed replay remains pending its own consent or external review handoff."*

## Bounded Replay Contract

This contract applies only to the exact `replay_contract: bounded-v1` root marker; revision metadata alone never activates it. `revise` owns only the `spec.md` write above. `x-review` is the sole writer of review records, and the replay planner is read-only: it never writes an artifact and never invokes a phase.

1. Parse only the planner's `CHANGED`, `STALE`, `CONTINUATION`, `REPLAY`, and `REVIEW_REQUIRED` records. Before any phase invocation, display the previous revision, current revision, persisted continuation, stale paths, executable sequence, and review handoff. Preserve the emitted phase order and explicitly say when the executable sequence is empty.
2. One displayed executable segment ends at its first review boundary. Stop at every `REVIEW_REQUIRED` record; invoke no phase after that review handoff and do not create, approve, or write its review record.
3. Ask separately whether to run exactly the displayed executable segment. Approval exists only when the entire response is exactly the lowercase literal `yes`; do not trim whitespace or reuse the rollback answer. Silence, `ok`, prior consent, and every other response authorize no phase invocation. A rollback `yes` authorizes only Step 5, never replay.
4. On approval, invoke only the displayed phases, once each, in order, and stop when that segment completes. After a matching external review exists, display the remaining executable segment and obtain a new literal `yes` before invoking any of it. The review itself is never consent for the continuation.
5. A failed analysis requires a new explicit user decision; start no correction and no replay. Never infer another correction from the earlier rollback or replay consent.
6. Never create or write `workflow.md` or `.maxi-ops`; neither is part of this contract.

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.

## Invariants

- **Always show the A+ suggestion before applying.** Never silently roll back to the inferred target.
- **Never roll back below `clarified` by default.** The sole exception is `specified` for a real missing or ambiguous requirement in the source spec; that path replays `clarify` and must never replay `specify`.
- **Never delete, rename, or modify** `plan.md`, `tasks.md`, `analysis.md` — they stay on disk, flagged stale in `## Clarifications`.
- **Never modify** `constitution.md` or any ADR file.
- **Only `spec.md`** is written: owner provenance, `status:`, `updated:`, and the `## Clarifications` revision note. Successor phases keep ownership of their own artifacts.
- **Two separate consent boundaries.** The rollback write and each displayed replay segment require their own exact `yes`; ambiguous responses and prior consent authorize no replay.

## Rationalization Counters

| Rationalization | Counter |
|---|---|
| "User said 'go back to planned', skip the picker" | Still show A+ suggestion + confirmation. User can confirm the suggested target. |
| "The change is small, no need to roll back" | If it touches requirements or design, roll back to the right phase. That's what the picker is for. |
| "Artefacts are stale, let me clean them up" | Never delete or rename downstream artefacts. Flag as stale in `## Clarifications` only. |
| "The constitution check is slow, I'll skip it" | Always scan constitution.md before confirm. One sentence is enough if no conflict found. |
| "User said the inferred target is wrong, I'll just pick another" | Show the full list `[clarified | planned | tasked | analyzed]` and let the user pick. |
