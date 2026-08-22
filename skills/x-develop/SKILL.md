---
name: x-develop
description: Use when /maxi:implement delegates execution, or when executing a maxi plan via subagent-driven development
---

## maxi develop - SDD adapter

Adapt Maxi's canonical `TNNN` task artifacts to
`superpowers:subagent-driven-development`. Upstream SDD owns task dispatch,
task review, fix rounds, its durable ledger, and the whole-branch review.
This skill owns projection, checkbox reconciliation, terminal evidence, and
the return boundary to `/maxi:implement`.

**Announce at start:** "I'm using Subagent-Driven Development to execute this plan."

## Inputs and projection

Receive the exact canonical `spec.md`, `plan.md`, and `tasks.md` paths from
`/maxi:implement`. Before any SDD dispatch:

1. Run `project-tasks.sh` with those exact paths, an output below
   `.superpowers/sdd/projections/`, and the selected spec's one
   `.superpowers/sdd/active-<slug>` pointer. Use only the canonical absolute
   projection path printed by the command.
2. Project each canonical `TNNN` once in tasks-file order for every root, ignoring replay metadata and historical plan annotations.
3. Create an immutable projection once, or verify and reuse it when its plan
   and tasks structural identity is unchanged. An owner-managed structural
   correction starts a successor projection and workspace. Link that
   successor to the prior projection. Recover a predecessor only from the validated active-projection pointer.

Before any task dispatch, persist the exact initial selected-TNNN set in the ordinary SDD ledger as the immutable initial task-selection anchor. Write that anchor once from the source selection; do not create a sidecar. Every projection's exact distributed bytes are SHA-256-bound by its ordinary SDD ledger; missing, duplicate, malformed, or mismatched projection-byte anchors fail closed across the current and predecessor lineage. On every projection reuse and reconciliation, combine both anchors with the bound sources and validated lineage to distinguish tasks that were initially pre-checked from tasks completed later. A missing, malformed, duplicate, or mismatched selection anchor fails closed.

Reconstruct the canonical projection bytes from the bound spec, plan, tasks, and validated selection/lineage ledgers whenever an existing projection is reused. Compare those reconstructed bytes exactly; the projection's stored body hash can detect damage but can never attest its own rewritten content. While projecting task bodies, normalize every accepted backtick fence delimiter to column zero so upstream `task-brief` retains the complete body.

Only canonical annotated upstream completion records acquit tasks; bare or malformed completion lines fail closed. The two accepted forms are exactly `Task N: complete (commits <7hex>..<7hex>, review clean)` and `Task N: complete (commits <7hex>..<7hex>, <positive K> parked)`. Reject duplicate records, unknown or non-positive task numbers, non-lowercase or non-seven-hex commit IDs, zero parked findings, free-form annotations, and suffixes.

For a successor, only one such record in the validated predecessor ledger acquits the corresponding `TNNN`. A checkbox alone never acquits a lineage task. Project every other `TNNN`, including an item whose Maxi checkbox is already checked.

Never infer a predecessor from chat, directory order, a historical annotation,
or an arbitrary ledger.

## Execute through upstream SDD

Change directory to the bound physical Git worktree before every upstream SDD helper call. Pass the printed canonical absolute projection path verbatim to every upstream SDD helper.

- Reconcile the existing ledger before any resumed dispatch.
- Invoke and follow `superpowers:subagent-driven-development` with the
  projection as its plan. Use upstream SDD without fix-loop overrides.
- After upstream records each canonical annotated task completion, run `reconcile-tasks.sh`.
  It checks only the `TNNN` retained in that projected heading. This skill is
  the sole incremental Maxi checkbox owner.
- If the projection has `execution_mode: final-review-only`, skip task
  dispatch and still run upstream's whole-branch review.
- If an interruption happened after the last reconciliation, reuse the
  complete ordinary ledger and run only the whole-branch review.

Do not copy or restate upstream's implementer, reviewer, fix-loop, breaker, or
final-review instructions here. Upstream SDD remains authoritative for them.

## Intercept the Finish boundary

Use upstream's final review exactly once. Intercept immediately before upstream workspace deletion and `superpowers:finishing-a-development-branch`. Do not delete any workspace and do not finish the branch in this skill.

Before dispatching the final reviewer, persist the harness-issued reviewer context as the sole `reviewer_context: <context>` line in `final-reviewer-dispatch.identity` beside the current ledger. Use the same canonical context grammar as the independent-review gate, and require the final reviewer to return that exact context. If the harness exposes no verifiable reviewer context, stop without a success token. Never invent, infer, or repair an identity.

Regenerate each review package with upstream's `review-package` helper from its recorded Git range and require byte-for-byte equality with the persisted package. A range header and matching self-hash are not review evidence. A null fix package requires exactly `**Ready to merge?** Yes`; a non-null byte-exact fix package requires the initial `**Ready to merge?** With fixes` plus exactly `**Fix round:** All findings addressed, no new Critical/Important breakage`. Reject `No`, a second Ready verdict after fixes, altered conclusions, duplicate or reordered conclusions, and every locally invented verdict.

Every TNNN in a predecessor selection anchor must remain in corrected source artifacts unless the validated lineage contains its canonical annotated completion. Removing an anchored incomplete `TNNN` during structural correction fails before successor creation and leaves the active-projection pointer unchanged. Complete ledger lines containing `Ruling:` are preserved byte-for-byte in lineage order and hash-bound by the terminal receipt. Collect and return them, including upstream parked and adjudication records whose line does not begin with `Ruling:`.

Persist the complete final review, fix wave, re-review, and adjudication output
as `maxi-final-review.md` beside the current ledger. Its frontmatter is exactly:

```yaml
worktree: <canonical physical Git worktree root>
merge_base: <full 40-hex commit>
reviewed_head: <full 40-hex commit>
reviewed_tree: <full 40-hex tree>
projection: <canonical absolute projection path>
projection_sha256: <64 lowercase hex>
full_review_package: <canonical absolute merge-base..initial-review-head package path>
full_review_package_sha256: <64 lowercase hex>
fix_review_package: <canonical absolute initial-review-head..reviewed-head package path or null>
fix_review_package_sha256: <64 lowercase hex or null>
spec: <canonical absolute spec.md path>
spec_sha256: <64 lowercase hex>
tasks: <canonical absolute tasks.md path>
tasks_sha256: <64 lowercase hex>
reviewer_context: <non-empty harness-issued context>
outcome: finish
```

Then:

1. Run `record-terminal.sh` with the bound worktree, merge base, projection,
   ledger, persisted final review, exact spec/tasks paths, and a receipt beside
   the current ledger. The receipt binds the persisted reviewer-dispatch file,
   its SHA-256, and the exact returned reviewer context.
2. Run `result-contract.sh` with the exact tasks path and terminal receipt.
3. Return the projection lineage and aggregated `Ruling:` lines only together with `READY_TO_FINISH`.

If upstream SDD blocks, final evidence cannot be persisted, or receipt
validation fails, return without a success token. Never translate a `Ruling:`
line into a Maxi status or silently drop it.

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.

---

Load and follow `superpowers:subagent-driven-development` using the Skill tool.
This adapter changes only the Maxi artifact and terminal handoff boundaries
named above.
