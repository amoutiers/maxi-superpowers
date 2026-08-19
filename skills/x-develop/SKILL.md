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
2. Strict plan-task bijection applies only when the physically bound `spec.md` carries exactly one `replay_contract: bounded-v1` marker.
3. For every unmarked root, ignore historical plan annotations and project each canonical `TNNN` task line once in tasks-file order.
4. Create an immutable projection once, or verify and reuse it when its plan
   and tasks structural identity is unchanged. An owner-managed structural
   correction starts a successor projection and workspace. Link that
   successor to the prior projection. Recover a predecessor only from the validated active-projection pointer.

Never infer a predecessor from chat, directory order, a historical annotation,
or an arbitrary ledger.

## Execute through upstream SDD

Change directory to the bound physical Git worktree before every upstream SDD helper call. Pass the printed canonical absolute projection path verbatim to every upstream SDD helper.

- Reconcile the existing ledger before any resumed dispatch.
- Invoke and follow `superpowers:subagent-driven-development` with the
  projection as its plan. Use upstream SDD without fix-loop overrides.
- After upstream records each `Task N: complete`, run `reconcile-tasks.sh`.
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
   the current ledger.
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
