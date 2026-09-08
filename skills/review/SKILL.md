---
name: review
description: Use when the user invokes /maxi:review or a newly completed plan reaches the design-review boundary before task extraction
---

# review

Persist one independent design review of the exact current `spec.md` and
`plan.md` pair and its decision inputs. A current `maxi-design-review-v1` approval binds exact artifact hashes and `review_inputs_sha256`: the constitution and every direct ADR Markdown file except generated README.md, regardless of status.

The independent reviewer uses the dedicated `design-reviewer.md` brief in this
directory. That brief reviews artifacts as a design; completed-code review
remains owned by upstream Superpowers at the implementation boundary.

## Invocation Boundary

Direct `/maxi:review` and standalone initial-plan review run in `report-only` mode for one pass and never correct artifacts. Specify/revise coordinators use `coordinated` mode with the same report-only owner for at most two passes under `design-operation.md`. The coordinator owns corrections; review returns its result after its own write.

## Process

1. Bind the explicit physical `project_root` and canonical artifact paths. Take the exact loaded `review/SKILL.md` path from the skill loader, canonicalize its directory with `cd -P`, and resolve adjacent `design-contract.sh` as `design_contract` and `review-inputs.sh` as `review_inputs`. Require readable regular, non-symlink helpers and support files `design-operation.md`, `design-reviewer.md`, `review-template.md`; no client-project lookup or fallback. Read design-operation.md for destination and continuity rules.
2. Before reading reviewed content, capture the ORIGINAL exact spec/plan SHA-256 values (`shasum -a 256 < "$spec_path"`, likewise plan) and `original_inputs="$(bash "$review_inputs" hash "$project_root")"`. Stop on any failure. Read the complete current `spec.md`, `plan.md`, constitution and all digest-bound ADR bytes. Never reconstruct missing artifacts from Git history. Resolve every `related_adrs` entry in `spec.md` to one accepted `docs/maxi/adr/NNNN-*.md` file. Missing, ambiguous or non-accepted references stop without writing. Inline prose mentions do not select ADR inputs. They also do not narrow the full digest-bound ADR snapshot.
3. Establish the actual initiating user order, exact request hash and operation ID as specified in design-operation.md. Prefer native message/session identity; the documented local discriminator is available only for an established new order, never to reset a resume. On resume inspect the existing report with:
   ```bash
   bash "$design_contract" operation "$review_path" "$spec_path" "$plan_path" "$project_root" "$operation_id"
   ```
   A reserved pass only recovers the recorded reviewer's result; no redispatch. Missing/malformed continuation evidence stops. A fresh operation requires a real fresh request; it cannot replace an active operation automatically.
4. Allocate a fresh independent read-only reviewer for pass one using an identity-only handshake. Save its harness-returned identity. For pass two reuse that reviewer, or allocate a replacement only after a completed first rejection when the original is unavailable. Read the complete design-reviewer.md brief and fill every placeholder with complete artifacts, ORIGINAL hashes, constitution, full ADR snapshot and accepted index; use `none` for empty slots. Include all prior findings for pass two. Confirm no placeholder remains. Do not send the review payload yet.
5. Create the real `reviews/` directory if absent. Hash the existing report exactly, or use literal `absent` only for a missing fresh-operation report. Reserve before dispatch:
   ```bash
   bash "$design_contract" reserve "$review_path" "$spec_path" "$plan_path" "$project_root" \
     "$operation_id" "$request_sha256" "$mode" "$reviewer" "$expected_report_sha"
   ```
   Require exit 0 and `DESIGN_REVIEW_RESERVED operation_id=<hash> pass=<N> report_sha256=<hash>`. Retain the returned report hash for publication; verify reservation hashes equal the ORIGINAL values before sending the payload. Only this successful reservation permits one review dispatch, sent by follow-up to the recorded reviewer. A mismatch stops the operation without dispatch.
6. Accept the response only when it contains exactly one terminal verdict line, that line is the final non-empty line, and it is exactly `VERDICT: approved` or `VERDICT: rejected`. If absent, malformed, duplicated, contradictory, or nonterminal, discard the response and write nothing as reviewed evidence. Never infer or repair a verdict. Ask the helper to stop the pending operation, preserving history. Compare current exact spec/plan hashes and dependency digest to ORIGINAL values before publication; freshness failure stops without an approval.
7. Create a separate private sibling candidate and cleanup trap:
   ```bash
   review_candidate="$(mktemp "$(dirname "$review_path")/.design-candidate.XXXXXX")"
   trap 'rm -f -- "$review_candidate"' EXIT
   ```
   Copy the reserved report body exactly, changing only the leading operation block's `phase: reserved` to the supplied verdict. Retain the entire byte-length-framed history section byte-for-byte. Append the complete independent output ending with its exact terminal VERDICT; reject reserved operation/history markers in reviewer output. The template's approval envelope documents stamper output and is not part of the candidate. Publish through:
   ```bash
   bash "$design_contract" stamp-operation "$review_candidate" "$review_path" \
     "$spec_path" "$plan_path" "$verdict" "$project_root" "$original_inputs" \
     "$operation_id" "$expected_report_sha"
   ```
   Use the reservation's returned report hash as `expected_report_sha`. Failed publication preserves prior evidence; do not retry with newly substituted originals. For approval require exit 0 and exactly `DESIGN_REVIEW_VERIFIED` from:
   ```bash
   bash "$design_contract" verify "$review_path" "$spec_path" "$plan_path" "$project_root"
   ```
8. Return the complete findings, operation identity, consumed pass and verdict to the coordinator; direct invocation stops here. Rejected pass one in coordinated mode remains available for one owner correction. Rejected pass two, report-only rejection, malformed output, unrecoverable reviewer or freshness failure ends continuation. Use the current exact report hash with:
   ```bash
   bash "$design_contract" stop-operation "$review_path" "$spec_path" "$plan_path" \
     "$project_root" "$operation_id" "$expected_report_sha"
   ```
   If inputs are unsafe or unreadable leave the report unchanged and report the stop. Never delete a lock left by another writer. Legacy `stamp` is not a fallback for managed reports.

## Hard Boundaries

- The only persistent artifact this skill may write is `reviews/design-review.md`; its private candidate is temporary. It never changes a
  status or mutates `spec.md`, `plan.md`, `tasks.md`, or a descendant artifact.
- A changed spec, plan, constitution or digest-bound ADR makes the persisted record stale. It has no
  side effect and does not dispatch another review.
- It never executes a successor phase, creates `workflow.md`, or writes
  `.maxi-ops`.

## Red Flags

- Hashing a structural projection instead of the exact file bytes
- Accepting an absent, malformed, duplicate, contradictory, or nonterminal verdict
- Reusing a stale review after either artifact changed
- Starting a correction after a rejected review
- Redispatching a reserved pass or resetting its allowance without a fresh user request
