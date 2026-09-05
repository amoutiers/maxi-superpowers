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

- The normal first `plan` completion invokes this skill once after writing the
  current `spec.md` and `plan.md` pair.
- After any correction, do not invoke a review automatically. This public
  command is the only re-review entry point, and it runs only when the user
  explicitly requests `/maxi:review`.

## Process

1. Bind the explicit physical `project_root` and canonical artifact paths. Take the exact loaded `review/SKILL.md` path from the skill loader, canonicalize its directory, and resolve adjacent `design-contract.sh` as `design_contract` and `review-inputs.sh` as `review_inputs`. Require regular, non-symlink helpers; no client-project lookup or fallback.
2. Before reading reviewed content, capture the ORIGINAL exact spec/plan SHA-256 values (`shasum -a 256 < "$spec_path"`, likewise plan) and `original_inputs="$(bash "$review_inputs" hash "$project_root")"`. Stop on any failure. Read the complete current `spec.md`, `plan.md`, constitution and all digest-bound ADR bytes. Never reconstruct missing artifacts from Git history. Resolve every `related_adrs` entry in `spec.md` to one accepted `docs/maxi/adr/NNNN-*.md` file. Missing, ambiguous or non-accepted references stop without writing. Inline prose mentions do not select ADR inputs. They also do not narrow the full digest-bound ADR snapshot.
3. Read the complete `design-reviewer.md` brief. Fill every placeholder with the complete artifacts, exact paths and ORIGINAL hashes, the complete constitution, decision-input digest, all ADR paths/bytes and the applicable accepted ADR index. Use `none` for empty ADR slots. Distinguish historical contextual records from applicable accepted decisions. Verify no placeholder remains, then dispatch exactly one fresh independent read-only reviewer with that rendered brief.
4. Accept the response only when it contains exactly one terminal verdict line, that line is the final non-empty line, and it is exactly `VERDICT: approved` or `VERDICT: rejected`. If absent, malformed, duplicated, contradictory, or nonterminal, discard the response and write nothing. Never infer or repair a verdict.
5. Before any report write, compare current exact spec/plan hashes and the dependency digest to the ORIGINAL values. If any changed, discard the review result and write nothing. A new actual review is required; never replace the original digest with a later one and label it reviewed.
6. Create the real `reviews/` directory if absent. Create a separate candidate beside the canonical destination and retain an owner cleanup trap, including on failure:
   ```bash
   review_candidate="$(mktemp "$(dirname "$review_path")/.design-candidate.XXXXXX")"
   trap 'rm -f -- "$review_candidate"' EXIT
   ```
   Write the complete unstamped body from `review-template.md` to that candidate, never to `review_path`. The template's envelope documents the stamper output and is not part of the candidate. Invoke:
   ```bash
   bash "$design_contract" stamp "$review_candidate" "$review_path" \
     "$spec_path" "$plan_path" "$verdict" "$project_root" "$original_inputs"
   ```
   The stamper validates and atomically publishes only current evidence. Failed stamping preserves prior evidence and yields no success. For `approved`, run:
   ```bash
   bash "$design_contract" verify "$review_path" "$spec_path" "$plan_path" "$project_root"
   ```
   Require exit 0 and exactly `DESIGN_REVIEW_VERIFIED` before reporting approval. `rejected` may be stamped, but never verifies as approved; report findings and stop without correction or replacement review.

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
- Re-running a review without an explicit `/maxi:review` request
