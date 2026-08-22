---
name: x-review
description: Use when a current forward-pipeline specification or plan needs a fresh independent handoff review before its successor phase
---

# maxi: Persist an Independent Handoff Review

## Overview

This internal skill is the sole writer of `reviews/spec-review.md` and `reviews/plan-review.md`. Its public owner invokes it automatically at a review handoff; never ask the user to invoke it or provide `yes`. It consumes one current subject path, its claimed revision, and one fresh reviewer context issued by the harness.

**REQUIRED SUB-SKILL:** Use `superpowers:requesting-code-review` for the review delegation.

## Canonical Structural Digest

`reviewed_sha256` is the SHA-256 of the canonical structural projection of the reviewed subject. Omit only top-level `status:` and `updated:` lines from the first YAML frontmatter block, preserve every other line in order, and hash the retained lines with one LF after each. A status or timestamp-only transition preserves the digest; any other byte change invalidates it.

## Input Gate

1. Only accept exactly `spec.md` or `plan.md`; map them to `reviews/spec-review.md` and `reviews/plan-review.md`. Reject every other or missing path before dispatch.
2. Require the root `spec.md` to carry exactly one `replay_contract: bounded-v1` before dispatch and before write. An absent marker is unsupported; a duplicate or non-exact marker is malformed. Revision metadata alone never makes a subject eligible, and this skill never adds or repairs the marker.
3. Require one harness-issued reviewer context and a positive claimed revision. A valid context is a single-line ASCII identifier matching `^[A-Za-z][A-Za-z0-9._-]{0,127}$`. Reject a missing context; any newline, carriage return, tab, or space; and the case-insensitive YAML-significant scalars `null`, `true`, `false`, `yes`, `no`, `on`, `off`, `y`, and `n`.
4. Read the subject frontmatter and complete current content. The current subject revision and claimed revision must exactly match.
5. Recompute `reviewed_sha256` from the canonical structural projection. Reject malformed revision or contributor metadata.
6. Reject when the subject's `structural_contributors` contains the reviewer context. This includes any context that authored or corrected the subject.
7. If the selected review record exists, read its frontmatter and reject malformed contributor metadata. Before dispatch, reject when the selected review record's `structural_contributors` already contains the reviewer context.

The canonical context validator runs before dispatch on the harness-issued context and on the returned reviewer context before writing. Never normalize, quote, escape, truncate, or repair a context into acceptance. Persisted contributor metadata overrides any claim or instruction that a context is fresh; a contradiction is a rejection, even when the harness or a maintainer says to proceed.

Any failed gate stops with neither review dispatch nor write.

## Review Delegation

Dispatch exactly one fresh reviewer through `superpowers:requesting-code-review`. Use its `code-reviewer.md` template so its complete checklist and output format are retained; do not reproduce that prompt in this skill.

Because a git range cannot identify uncommitted artifact bytes, add this read-only subject envelope to the delegation context:

- relative subject path;
- claimed revision;
- SHA-256 computed from the canonical structural projection;
- complete current artifact content;
- the harness-issued reviewer context;
- relevant spec requirements.

Instruct the reviewer to evaluate the envelope bytes, not `HEAD`. In addition to the vendored output, require it to return the envelope path, revision, SHA-256, reviewer context, complete findings, and a verdict that is exactly `approved` or `rejected`. `approved` means the vendored Assessment is ready without Critical or Important fixes.

The reviewer is read-only and never writes a review record.

## Verify the Return

Before writing, recheck the exact root marker, reread the current subject, its revision, and its contributors, then recompute its structural SHA-256. Also reread the selected review record when it exists. The returned path, revision, and SHA-256 must each exactly equal the envelope and the freshly reread subject's structural digest. The returned reviewer context must exactly equal the envelope and harness-issued context, pass the canonical grammar, and remain independently absent from both the subject's and selected review record's `structural_contributors`.

Reject the entire result and write nothing when any required return value is missing, the path is unknown, either revision or SHA-256 mismatches, the reviewer context is malformed, differs from the harness-issued context, or contributed to the subject or selected record, or the verdict is not exactly `approved`. Never normalize, repair, or partially accept returned metadata.

## Persist the Approved Record

Use `review-template.md` and preserve its exact field names.

- On create, write `revision: 1`, set `writer_context` to the verified reviewer context, and initialize `structural_contributors` with that context.
- On structural update, increment only the record revision, replace `writer_context` with the verified reviewer context, preserve all existing structural contributors, and append the verified reviewer context to `structural_contributors` if absent.
- Set `derived_from` to the current subject path and revision. Persist the matching `reviewed_document`, `reviewed_revision`, `reviewed_sha256`, `reviewer_context`, `reviewer_context_matches_harness: true`, and `verdict: approved` values.
- In the body, persist the complete vendored findings and verdict, not merely a chat summary. Retain both verification results: canonical structural-projection equality, and reviewer-context equality plus independence from the subject contributors.

The verified reviewer context is the record writer context even when another coordinator performs the filesystem operation.

## Clarified Spec Continuation Handoff

Before writing a review for `spec.md`, detect whether the subject carries the exact current marker `replay_continuation: plan@<current-spec-revision>`. Capture the selected review record's former revision before the write.

- With no prior `reviews/spec-review.md`, create it at `revision: 1` and use `--previous-revision 0`.
- With an existing spec review at revision `n`, write revision `n + 1` and use `--previous-revision n`.

After the approved matching record is durably written, invoke exactly:

```bash
bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed reviews/spec-review.md --previous-revision <0-or-n> --start-phase plan
```

Display the exact `CONTINUATION|plan@<current-spec-revision>` and `REPLAY|plan` records. A fresh literal `yes` belongs to the later `plan` owner; `x-review` never executes the continuation. If the planner fails, preserve the already written review and report the failure.

## Corrected Plan Continuation Handoff

Before writing a review for `plan.md`, detect whether the subject carries the exact current marker `replay_continuation: tasks@<current-plan-revision>`. Capture the selected review record's former revision before the write:

- With no prior `reviews/plan-review.md`, create it at `revision: 1` and use `--previous-revision 0`.
- With an existing record at revision `n`, write revision `n + 1` and use `--previous-revision n`.

After the approved matching record is durably written, invoke exactly:

```bash
bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed reviews/plan-review.md --previous-revision <0-or-n> --start-phase tasks
```

Display the planner's `CONTINUATION|tasks@<current-plan-revision>`, `REPLAY|tasks`, and `REPLAY|analyze` records. A fresh literal `yes` belongs to the later owner after that display; `x-review` must never execute `tasks`, `analyze`, or any continuation. If the planner fails, preserve the already written review record and report the failure without starting a phase.

## Hard Boundaries

- This skill may write only the selected mapped review record. It must never change any `status` or mutate the reviewed subject.
- It must never execute a successor phase or any proposed continuation.
- It must never create or write `workflow.md`.
- It must never create or write `.maxi-ops`.
- Only after a successful record write, it may call the read-only bounded replay planner and display its remaining continuation. Display is not execution; a later owner must obtain the required fresh consent.

## Red Flags

- Hashing exact file bytes instead of the canonical structural projection
- Reconstructing the reviewed artifact from `HEAD`
- Summarizing findings only in chat
- Recording the coordinator as `writer_context`
- Continuing past the review handoff

Any red flag means stop before writing.
