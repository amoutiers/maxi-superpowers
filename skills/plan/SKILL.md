---
name: plan
description: Use when the user invokes /maxi:plan or wants to create a technical implementation plan for a clarified feature — spec must be at status "clarified"
---

# plan

Create a technical implementation plan for an existing spec. Delegates to `/maxi:writing-plans` and writes output to `docs/maxi/specs/NNNN-slug/plan.md`.

## Prereqs

- `docs/maxi/constitution.md` must exist — hard stop if missing: *"No constitution found. Run `/maxi:constitution` first."*
- Locate spec in `docs/maxi/specs/` at status `clarified`
  - If status is `drafting`: stop — *"Spec is still `drafting`. Run `/maxi:specify` first."*
  - If status is `specified`: stop — *"Spec must be `clarified` before planning. Run `/maxi:clarify` first. If the spec has no ambiguities, `/maxi:clarify` will complete in seconds and confirm this."*
  - If status is `planned` or later: stop — *"Spec is already `planned`. Proceed to `/maxi:tasks`."*

## Process

1. **Read artifacts** — load `spec.md` (FRs, SCs, user stories), `constitution.md` (principles, constraints), and `reviews/spec-review.md` (approval evidence and its own exact revision)
2. **Validate the spec review** — for a forward-pipeline spec carrying revision metadata, apply the complete independent-review gate below. This gate runs before the constitution check, planning delegation, or any output.
3. **Constitution check** — before planning: does anything in the spec contradict constitution principles? Flag violations to the user before proceeding. (Do NOT silently discard violating requirements — surface them.)
4. **Invoke /maxi:writing-plans** — **REQUIRED SUB-SKILL.** Pass the spec and constitution as context. Let writing-plans run its full planning process including file structure decisions and task decomposition.
5. **Post-format into plan schema** — write output to `docs/maxi/specs/NNNN-slug/plan.md` following `plan-template.md` structure and the forward provenance contract below. Set plan.md frontmatter: `slug` and `spec_slug` from spec, `created` and `updated` to today's ISO date. Additionally create any of these if writing-plans produced them: `research.md`, `data-model.md`, `contracts/` directory
6. **ADR scan (post-planning)** — scan the just-written `plan.md` for non-obvious architectural choices. Look for: Tech Stack sections, storage/database/runtime/framework picks, phrases like "we chose X over Y because" or "considered A, B, chose C". For each detected choice, invoke `/maxi:x-adr` — it will draft the ADR, show it to the user, and write it only if the user consents. If the user declines all ADR proposals, the plan is still complete; ADR capture is opt-out, not mandatory. Do not invoke `/maxi:x-adr` for trivial choices (e.g., variable naming conventions, test library defaults).
7. **Transition status** — update spec.md frontmatter `status → planned`; also set `updated: [today's ISO date]` on spec.md and on plan.md. Status and timestamp changes are non-structural and do not change either document's revision, writer context, or structural contributors.
8. **Stop at the plan-review handoff** — report the current `plan.md` revision that requires external review. Do not invoke `/maxi:tasks`; `/maxi:x-review` must independently create the matching approval first.
9. **Report** — *"Plan written to `docs/maxi/specs/NNNN-slug/plan.md` (status: `planned`). Next: an external `/maxi:x-review` of the current plan revision; after approval, display the remaining continuation and obtain its own consent before `/maxi:tasks`."*

## Independent Spec Review Gate

For a forward-pipeline spec, read `reviews/spec-review.md`, the exact current bytes of `spec.md`, and both frontmatter blocks. Validate all of these as one fail-closed gate:

- the record metadata is well formed, its own `revision` is positive, and its exact `derived_from` input is the current `spec.md` revision;
- `verdict: approved`, `reviewed_document: spec.md`, and `reviewed_revision` equals the current spec revision;
- `reviewed_sha256` equals SHA-256 recomputed from the exact current bytes of `spec.md`;
- `reviewer_context_matches_harness: true`, and the exact `reviewer_context` is absent from the current spec's `structural_contributors`.

A missing, rejected, malformed, stale, or self-reviewed record fails this gate. Stop before invoking `writing-plans`, before any artifact write, and before any status or timestamp transition; leave every artifact unchanged. Never infer, repair, or accept partial evidence.

In particular, stop when the record is missing, does not have `verdict: approved`, does not target `spec.md`, or its `reviewed_revision` does not equal the current spec revision. Those are invalid evidence, not reasons to create a replacement.

`x-review` is the sole writer of review records; `plan` only validates them and never creates, edits, or approves a review record. The read-only replay planner only calculates and displays a continuation. Neither mechanism authorizes `plan` to create or write `workflow.md` or `.maxi-ops`.

## Constitution Check Protocol

Before delegating to `/maxi:writing-plans`, run this check:

For each constitution principle, ask: "Does the spec require something that contradicts this principle?"

Examples:
- Constitution says "no third-party auth providers" → spec requires OAuth → FLAG
- Constitution says "API-first design" → spec describes GUI-only feature → FLAG

If violations found: present them to the user. Options: (a) amend constitution, (b) amend spec, (c) note as exception. Do NOT proceed to planning until user decides.

**This check is mandatory even when:**
- The user asserts "I know my spec is aligned" — you still MUST run the check yourself
- The user wrote both the spec and the constitution — alignment must be verified, not assumed
- The spec is simple or small — there is no size threshold below which the check is skipped

## Output Artifacts

All written to `docs/maxi/specs/NNNN-slug/`:

| Artifact | Required | Notes |
|---|---|---|
| `plan.md` | Always | Verify `plan-template.md` exists (Read tool) before writing; if missing, stop: *"Cannot proceed — `plan-template.md` is missing. Please reinstall the maxi plugin."* Then follow the template schema |
| `research.md` | If needed | Technology choices, library comparisons |
| `data-model.md` | If needed | Entities, relationships, schemas |
| `contracts/` | If needed | API endpoint definitions |

## Forward Provenance Contract

Apply this contract only when creating artifacts for a spec created through the normal forward pipeline. Do not add or infer this metadata on existing, migrated, or reverse-engineered specs.

For every new `plan.md` and support artifact (`research.md`, `data-model.md`, `quickstart.md`, and each `contracts/*.md`):

```yaml
revision: 1
writer_context: <new non-empty context unique across this spec's pipeline-owned documents>
structural_contributors:
  - <the exact writer_context above>
```

Each support artifact has exactly the current `spec.md` revision as its direct document input:

```yaml
derived_from:
  - spec.md@<exact-revision-read>
```

`plan.md` records every direct document input, including the current `spec.md`, every support artifact actually read, and the current approved `reviews/spec-review.md`. Approval is a direct provenance dependency even when its findings do not contribute plan body text.

```yaml
derived_from:
  - spec.md@<exact-revision-read>
  - <support-artifact-path>@<exact-revision-read>
  - reviews/spec-review.md@<exact-revision-read>
```

On a later structural owner write, increment only the artifact being written, replace its `writer_context` with the new unique context, and append that context to its `structural_contributors`. Status, timestamps, task-completion checkboxes, and `related_adrs` are non-structural: they never increment revisions or append contributors.

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.

## Critical Rules

- **Constitution check before planning.** Never skip the pre-flight constitution alignment check. Applies regardless of spec size, user assertions, or perceived simplicity.
- **writing-plans delegation is mandatory.** Do NOT write plan.md content directly without invoking `/maxi:writing-plans`. This applies even for "simple" or "small" features — there is no complexity threshold below which direct writing is allowed.
- **Template schema required.** Plan must follow `plan-template.md` structure — not free-form notes. Always copy the template structure first.
- **All artifacts in `docs/maxi/specs/NNNN-slug/`.** Never write to project root, `docs/`, `.specify/`, or the user's current working directory.
- **status: planned only when all artifacts written.** Transition happens after all files are on disk.
- **Exact direct inputs.** `plan.md` derives from the current spec, every support artifact read, and the current approved spec review, all at their exact revisions. A support artifact derives directly from the current spec.
- **No metadata retrofit.** Existing, migrated, and reverse-engineered specs and their artifacts remain unchanged.

## Red Flags

- Writing plan.md without invoking `/maxi:writing-plans` → delegate first
- No constitution check run before planning → always do the pre-flight
- Plan written to wrong directory → only `docs/maxi/specs/NNNN-slug/`
- Planning a `drafting` spec → stop, spec must be `specified` or `clarified`
- Setting `status: planned` before plan.md is verified on disk → atomic transition only
- Skipping the ADR scan after writing plan.md → scan is part of the process, not optional
- Writing ADR files directly without invoking `/maxi:x-adr` → delegate to `/maxi:x-adr`, which handles consent, numbering, and index updates
- "I know the spec is fine" → user assertions don't replace the constitution check — run it anyway
- "This feature is too simple for writing-plans" → no feature is too simple; writing-plans delegation is unconditional
- Writing plan.md in current directory → always use `docs/maxi/specs/NNNN-slug/`, regardless of cwd

## Rationalization Counters

| Rationalization | Counter |
|---|---|
| "I wrote the spec so I know it's aligned with the constitution" | Self-authored specs still get checked. The check exists precisely because authors have blind spots. Run it. |
| "The user says there are no ambiguities, skipping clarify is fine" | User assertions don't replace the clarification phase. `/maxi:clarify` completes in seconds on an unambiguous spec — run it. The pipeline is strict precisely to avoid this class of shortcut. |
| "The spec came from migrate-from-speckit, it's already mature" | Maturity doesn't replace the phase. The pipeline applies equally to migrated specs. Run `/maxi:clarify`. |
| "This is a simple feature, writing-plans is overkill" | Feature complexity does not determine whether the sub-skill is invoked. Invoke writing-plans unconditionally. |
| "I'll write plan.md here since that's where we're working" | The plan lives in `docs/maxi/specs/NNNN-slug/plan.md`. Working directory is irrelevant. |
| "The user says skip the constitution check" | The constitution check is a pipeline gate, not an optional step. It cannot be skipped by user request. |
| "I'll adapt the template from a previous plan" | Always copy `plan-template.md`. Previous plans may have customizations that corrupt the schema. |
