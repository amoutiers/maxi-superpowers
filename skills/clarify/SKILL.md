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

1. **Read spec.md** — scan for: `[NEEDS CLARIFICATION: ...]` markers, questions in FR descriptions, vague adjectives ("fast", "robust", "user-friendly", "simple"), and missing acceptance criteria
2. **Build question list** — collect all ambiguities found; prioritize by impact (blocking FRs first)
3. **Ask one question at a time** — present context, ask one focused question, wait for answer before next
4. **Record each answer** — after each answer, note how it resolves the ambiguity
5. **Update spec.md** — three updates in the same write operation:
   a. In-place: replace `[NEEDS CLARIFICATION: ...]` markers with the resolved text in the relevant FRs
   b. Append: add/update `## Clarifications` section at the end of spec.md with Q&A pairs
   c. Frontmatter: set `updated: [today's ISO date]` (`YYYY-MM-DD`)
   For a structurally changed forward-pipeline spec, capture the previous `revision` before this write, increment only `spec.md`, replace `writer_context` with this write's new unique context, and append that context to `structural_contributors`. A status, timestamp, or `related_adrs` change alone is non-structural and does not increment the revision.
6. **Transition status** — change `status: specified` → `status: clarified` in spec.md frontmatter
7. **Prepare the bounded replay handoff** — for a structurally changed forward-pipeline spec, call the read-only `skills/revise/replay-plan.sh` with `--changed spec.md`, the captured previous revision, and `--start-phase plan`; then follow the replay contract below. A clarification that made no structural change still stops for an external review of the current spec before planning.
8. **Report** — tell user: spec clarified at `docs/maxi/specs/NNNN-slug/spec.md` (status: `clarified`). The next handoff is an external `/maxi:x-review` of the current spec revision, not `/maxi:plan`.

## Bounded Replay Contract

This contract applies only to forward-pipeline specs carrying the revision metadata. `spec.md` remains this skill's only artifact write. `x-review` is the sole writer of review records, and the replay planner is read-only: it never writes an artifact and never invokes a phase.

1. Parse only the planner's `CHANGED`, `STALE`, `REPLAY`, and `REVIEW_REQUIRED` records. Before any phase invocation, display the previous revision, current revision, stale paths, executable sequence, and review handoff. Preserve the emitted phase order and explicitly say when the executable sequence is empty.
2. One displayed executable segment ends at its first review boundary. Stop at every `REVIEW_REQUIRED` record; invoke no phase after that review handoff and do not create, approve, or write its review record.
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
- **Review before planning.** Completion stops at the spec-review handoff. Planning cannot start until a matching approved external review exists and the remaining displayed segment receives its own literal `yes`.
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
