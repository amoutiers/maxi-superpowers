---
name: revise
description: Use when the user invokes /maxi:revise, says requirements changed, the spec needs updating, or the plan needs to change — accepts a spec at clarified or later, including done, and coordinates an authorized design revision.
---

# revise

Roll back a spec to an earlier pipeline phase when requirements or design change. The first skill that makes `status:` go backwards.

## Prereqs

- `docs/maxi/constitution.md` must exist — hard stop if missing.
- Use the explicit canonical target when supplied. Ask which spec only when the target remains ambiguous.
- **Refuse** if `status: drafting` or `specified` → *"Spec is at `<status>` — use `/maxi:clarify` or `/maxi:specify` instead."*
- **Refuse** if `status: parked` → *"Spec is parked. Run `/maxi:resume` first, then `/maxi:revise`."*
- **Refuse** if `status: cancelled` → *"Spec is cancelled. Cannot revise."*
- Valid for: `clarified`, `planned`, `tasked`, `analyzed`, `implementing`, `done`.

## Process

1. Reuse the change already supplied in the actual initiating user request. Ask for a description only when none is available. Read the target and constitution; a genuine conflict requires the user's decision before writing.
2. Select the smallest affected rollback: demonstrated missing/ambiguous source requirement → `specified`; requirements/user story/scope change → `clarified`; plan/architecture change → `planned`; extraction-only → `tasked`; analysis-only → `analyzed`. Explain the selected target briefly. Reuse explicit authorization already supplied for this change and associated continuation. Ask only when target, scope, destination or mutation authority remains materially unclear. Do not repeat the description, A+ picker or exact-yes confirmation for an already authorized change. An unresolved authorization question writes nothing.
3. Load `/maxi:review` by registered skill name for support discovery without executing public review. Canonicalize the exact loaded `review/SKILL.md` directory with `cd -P`; require readable regular, non-symlink `design-operation.md` and read it fully. Load `/maxi:specify` for its adjacent `spec-author.md` using the same checks. Missing or unsafe installed support stops before any write; never fall back to client-project skills.
4. For the authorized rollback, write `spec.md`: `status: <target>`, `updated: <today>`. If the source is `done`, write `reopened_from: done`; otherwise retain an existing `reopened_from: done`; never clear `reopened_from`. Append to `## Clarifications`: `**Revised (YYYY-MM-DD):** Rolled back from \`<current>\` to \`<target>\`. Change: <description>. Note: artefacts from phases after \`<target>\` (if any) are stale.`
5. For draft/edit/phase-only requests invoke only the requested owner and stop. For a requirements revision run the existing-spec author, then the actual clarify scan: if gaps require `specified`, record that authorized rollback and invoke clarify; a clean `clarified` source needs no fabricated questions or extra status hop. For the demonstrated source-gap path invoke clarify at `specified`. For design revision continue with owner-only plan and the bounded review round. Extraction/analysis-only requests stop at their explicit destination; this operation never invokes tasks, analyze or implement.
6. Return the actual destination, canonical artifact and current verdict or precise unresolved blocker. Owners return after their own writes; the coordinator owns continuation and never writes the review report itself.

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.

## Invariants

- `parked` requires resume; `cancelled` cannot be revised. Existing completion lineage is preserved.
- Only `spec.md` is written by the rollback owner: status, updated, monotone watermark and revision note. Delegated author, clarify, plan and review retain their separate artifact ownership.
- Never delete or rename downstream `plan.md`, `tasks.md`, or `analysis.md`; stale files remain until their proper owners regenerate them. Never edit tasks or analysis in this design operation.
- Never modify constitution or ADR files. ADR changes keep their separate explicit approval through x-adr.
- A resumed initiating request retains its operation identity and consumed review allowance; elapsed time and interruptions never authorize another pass.
