---
name: clarify
description: Use when the user invokes /maxi:clarify or when a spec.md has open questions, [NEEDS CLARIFICATION] markers, or ambiguous FRs — status must be "specified"
---

# clarify

Resolve open questions in an existing spec without rewriting it. Appends a `## Clarifications` section and updates FRs in place.

## Prereqs

- `docs/maxi/constitution.md` must exist — if missing, stop: *"No constitution found. Run `/maxi:constitution` first."*
- Locate the in-flight spec in `docs/maxi/specs/`. Find `spec.md` with `status: specified`.
  - If multiple specs at `status: specified`: ask user which one to clarify.
  - If none at `status: specified`: stop with *"No spec at status `specified` found. Run `/maxi:specify` to create one, or check that the target spec is in the right phase."*
  - If spec is `drafting`: stop with *"Spec is still `drafting` — run `/maxi:specify` to complete it first."*
  - If spec is `clarified` or later: stop with *"Spec is already `clarified`. No further clarification needed; proceed to `/maxi:plan`."*

## Process

Before Step 1, only a spec carrying the exact `replay_contract: bounded-v1` root marker and `replay_continuation: clarify@<current-spec-revision>` enters the Pending Source Continuation Presenter below. An unmarked revision-bearing spec, including pre-mechanism 0019, keeps ordinary legacy clarification: no provenance, no replay continuation, and no planner.

1. **Read spec.md** — scan for: `[NEEDS CLARIFICATION: ...]` markers, questions in FR descriptions, vague adjectives ("fast", "robust", "user-friendly", "simple"), and missing acceptance criteria
2. **Build question list** — collect all ambiguities found; prioritize by impact (blocking FRs first)
3. **Ask one question at a time** — present context, ask one focused question, wait for answer before next
4. **Record each answer** — after each answer, note how it resolves the ambiguity
5. **Update spec.md** — three updates in the same write operation:
   a. In-place: replace `[NEEDS CLARIFICATION: ...]` markers with the resolved text in the relevant FRs
   b. Append: add/update `## Clarifications` section at the end of spec.md with Q&A pairs
   c. Frontmatter: set `updated: [today's ISO date]` (`YYYY-MM-DD`)
   Only the exact `replay_contract: bounded-v1` root marker activates revision, provenance, replay_continuation, and planner behavior. For that eligible spec, capture the previous `revision` before this write. A structural clarification increments only `spec.md`, replaces `writer_context` with this write's new unique context, and appends that context to `structural_contributors`.
6. **Transition and persist the next handoff** — change `status: specified` → `status: clarified`. For every eligible marked spec, including the no-content-change branch, persist `replay_continuation: plan@<current-spec-revision>` in the same owner write that leaves status `clarified`. Replacing the prior marker is structural: if Step 5 changed no content, increment `spec.md` once here, set the fresh writer context, and append it to the contributors; if Step 5 already incremented the revision, bind the marker to that new revision without a second increment.
7. **Prepare the bounded replay handoff** — for a structurally changed eligible marked spec, call the read-only `skills/revise/replay-plan.sh` with `--changed spec.md`, the captured previous revision, and `--start-phase plan`; then follow the replay contract below. A marked clarification that made no structural change still stops for an independent review of the current spec before planning.
8. **Invoke the review handoff** — for a marked root, automatically invoke internal `x-review` for the current `spec.md` revision; never ask the user to invoke it or provide `yes`. It writes the review record and stops before `/maxi:plan`.
9. **Report** — tell user: spec clarified at `docs/maxi/specs/NNNN-slug/spec.md` (status: `clarified`). The independent review runs internally; after approval, `/maxi:plan` presents its own continuation and consent.

## Pending Source Continuation Presenter

At `specified`, only an exact `replay_contract: bounded-v1` root marker may activate this presenter. For that marked root, validate the exact `replay_continuation: clarify@<current-spec-revision>` marker before any question, clarification write, status transition, or other mutation, then invoke exactly:

```bash
bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed spec.md --previous-revision <current-spec-revision> --start-phase clarify --resume-current-source
```

Display the exact `CONTINUATION|clarify@<current-spec-revision>` and `REPLAY|clarify` records, then require a fresh literal `yes`; immediately before clarification, revalidate the same current marker. A rejection, ambiguous response, or session interruption changes no byte; a later `/maxi:clarify` repeats this no-write presentation. Any other marker, revision, path, phase, or planner failure stops before work.

## Bounded Replay Contract

This contract applies only to specs carrying the exact `replay_contract: bounded-v1` root marker; revision metadata alone never activates it. `spec.md` remains this skill's only artifact write. `x-review` is the sole writer of review records, and the replay planner is read-only: it never writes an artifact and never invokes a phase.

1. Parse only the planner's `CHANGED`, `STALE`, `CONTINUATION`, `REPLAY`, and `REVIEW_REQUIRED` records. Before any phase invocation, display the previous revision, current revision, persisted continuation, stale paths, executable sequence, and review handoff. Preserve the emitted phase order and explicitly say when the executable sequence is empty.
2. One displayed executable segment ends at its first review boundary. Stop every public phase at `REVIEW_REQUIRED`, automatically invoke internal `x-review` for the current subject, and never ask the user to invoke it or provide `yes`. Invoke no public phase after that review handoff; `x-review` alone writes its review record.
3. If the displayed segment contains `REPLAY` records, ask for consent to run exactly that sequence. Approval exists only when the entire response is exactly the lowercase literal `yes`; do not trim whitespace or reuse another answer. Silence, `ok`, prior consent, and every other response authorize no phase invocation.
4. On approval, invoke only the displayed phases, once each, in order, and stop when that segment completes. After a matching external review exists, display the remaining executable segment and obtain a new literal `yes` before invoking any of it. The review itself is never consent for the continuation.
5. Never create or write `workflow.md` or `.maxi-ops`; neither is part of this contract.

## Clarifications Section Format

```markdown
## Clarifications

**Q: [question asked]**
A: [user's answer — verbatim or paraphrased accurately]

**Q: [next question]**
A: [answer]
```

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.

## Critical Rules

- **Read before asking.** Identify ALL ambiguities first; then ask questions in priority order.
- **One question at a time.** Never dump a list of questions. Ask → wait → record → ask next.
- **Narrow scope.** Only resolve existing open questions. Do NOT add new requirements, expand scope, or introduce new user stories. If the user's answer suggests a scope change, note it as a potential follow-up spec.
- **No rewriting.** Do not rewrite sections for polish, style, or clarity. Only touch text that directly resolves an open question.
- **Update spec in place.** Remove `[NEEDS CLARIFICATION: ...]` markers when resolved. Don't leave them as-is.
- **Status: clarified only when complete.** Transition status only after all identified open questions are resolved or explicitly deferred.
- **Owner-only writes.** This skill writes only `spec.md`; it never writes review records or replay-generated successor artifacts.
- **Review before planning.** For a marked root, completion stops at the spec-review handoff. Planning cannot start until a matching approved external review exists and the remaining displayed segment receives its own literal `yes`.
- **User says "no open questions"?** You still MUST scan spec.md yourself before accepting this. If you find ambiguities after scanning, ask about them. If the spec is genuinely clean after your own review, you may set status: clarified and report this to the user.

## Red Flags

- No questions asked; skill just rewrites sections → narrow scope, resolve open Qs only
- Asking 5+ questions in one message → one at a time, always
- `[NEEDS CLARIFICATION: ...]` markers still in spec.md after clarification → must update in place
- Running on a spec with `status: planned` or later → wrong phase, stop immediately
- Adding new FR-### items not in the original spec → scope creep, defer to new `/maxi:specify`
- "Cleaning up" or "polishing" prose that isn't tied to an open question → out of scope
- User suggests a new feature mid-Q&A → note it as a follow-up spec, do NOT add to current spec
- Skipping self-scan because user says spec is fine → always scan yourself first
