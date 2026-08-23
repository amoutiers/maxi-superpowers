---
name: review
description: Use when the user invokes /maxi:review or a newly completed plan reaches the design-review boundary before task extraction
---

# review

Persist one independent design review of the exact current `spec.md` and
`plan.md` pair. The review is current only while both files have exactly the
same SHA-256 values recorded in `reviews/design-review.md`.

The independent reviewer uses the dedicated `design-reviewer.md` brief in this
directory. That brief reviews artifacts as a design; completed-code review
remains owned by upstream Superpowers at the implementation boundary.

## Invocation Boundary

- The normal first `plan` completion invokes this skill once after writing the
  current `spec.md` and `plan.md` pair.
- After any correction, do not invoke a review automatically. This public
  command is the only re-review entry point, and it runs only when the user
  explicitly requests `/maxi:review`.

## Process

1. Read the complete current `spec.md` and `plan.md`. Stop if either is
   missing; do not reconstruct either artifact from Git history. Resolve every
   `related_adrs` entry in `spec.md` to one accepted
   `docs/maxi/adr/NNNN-*.md` file. Read each referenced ADR's complete current
   bytes. If a reference is missing, ambiguous, or not accepted, stop and write
   nothing. Inline prose mentions do not select ADR inputs.
2. Compute each file's SHA-256 from its exact current bytes, for example with
   `shasum -a 256`.
3. Read the complete `design-reviewer.md` brief. Fill every placeholder with
   both complete artifacts, their paths and SHA-256 values, and the applicable
   constitution requirements, plus the paths and complete bytes of every
   referenced accepted ADR. Use `none` when no ADR is referenced. Verify that
   no placeholder remains, then dispatch exactly one fresh independent reviewer
   with that rendered brief. The reviewer is read-only and returns complete
   findings followed by exactly `VERDICT: approved` or `VERDICT: rejected`.
4. Accept the response only when it contains exactly one terminal verdict line,
   that line is the final non-empty line, and it is exactly
   `VERDICT: approved` or `VERDICT: rejected`. If the verdict is absent,
   malformed, duplicated, contradictory, or nonterminal, discard the response
   and write nothing. Never infer or repair a verdict.
5. Before writing, reread both files and recompute both hashes. If either
   changed, discard the review result and write nothing.
6. Write only `reviews/design-review.md` using `review-template.md`, recording
   the two verified hashes, complete findings, verification, and the returned
   verdict without its `VERDICT:` prefix. `approved` allows `/maxi:tasks`;
   `rejected` reports the findings and stops. A rejection never starts a
   correction or replacement review.

## Hard Boundaries

- This skill may write only `reviews/design-review.md`. It never changes a
  status or mutates `spec.md`, `plan.md`, `tasks.md`, or a descendant artifact.
- A changed spec or plan merely makes the persisted record stale. It has no
  side effect and does not dispatch another review.
- It never executes a successor phase, creates `workflow.md`, or writes
  `.maxi-ops`.

## Red Flags

- Hashing a structural projection instead of the exact file bytes
- Accepting an absent, malformed, duplicate, contradictory, or nonterminal verdict
- Reusing a stale review after either artifact changed
- Starting a correction after a rejected review
- Re-running a review without an explicit `/maxi:review` request
