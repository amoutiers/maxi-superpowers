---
name: review
description: Use when the user invokes /maxi:review or a newly completed plan reaches the design-review boundary before task extraction
---

# review

Persist one independent design review of the exact current `spec.md` and
`plan.md` pair. The review is current only while both files have exactly the
same SHA-256 values recorded in `reviews/design-review.md`.

**REQUIRED SUB-SKILL:** Use `superpowers:requesting-code-review` for the
independent review delegation.

## Invocation Boundary

- The normal first `plan` completion invokes this skill once after writing the
  current `spec.md` and `plan.md` pair.
- After any correction, do not invoke a review automatically. This public
  command is the only re-review entry point, and it runs only when the user
  explicitly requests `/maxi:review`.

## Process

1. Read the complete current `spec.md` and `plan.md`. Stop if either is
   missing; do not reconstruct either artifact from Git history.
2. Compute each file's SHA-256 from its exact current bytes, for example with
   `shasum -a 256`.
3. Dispatch one fresh reviewer through `superpowers:requesting-code-review`.
   Provide both complete artifacts, their paths and SHA-256 values, and the
   applicable constitution and specification requirements. The reviewer is
   read-only and must return complete findings plus exactly `approved` or
   `rejected`.
4. Before writing, reread both files and recompute both hashes. If either
   changed, discard the review result and write nothing.
5. Write only `reviews/design-review.md` using `review-template.md`, recording
   the two verified hashes, complete findings, verification, and returned
   verdict. `approved` allows `/maxi:tasks`; `rejected` reports the findings
   and stops. A rejection never starts a correction or replacement review.

## Hard Boundaries

- This skill may write only `reviews/design-review.md`. It never changes a
  status or mutates `spec.md`, `plan.md`, `tasks.md`, or a descendant artifact.
- A changed spec or plan merely makes the persisted record stale. It has no
  side effect and does not dispatch another review.
- It never executes a successor phase, creates `workflow.md`, or writes
  `.maxi-ops`.

## Red Flags

- Hashing a structural projection instead of the exact file bytes
- Reusing a stale review after either artifact changed
- Starting a correction after a rejected review
- Re-running a review without an explicit `/maxi:review` request
