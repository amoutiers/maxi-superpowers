---
name: plan
description: Use when the user invokes /maxi:plan or wants to create a technical implementation plan for a clarified feature — spec must be at status "clarified"
---

# plan

Create or explicitly correct a technical implementation plan for an existing spec. Delegates every structural plan write to `/maxi:writing-plans` and writes only `docs/maxi/specs/NNNN-slug/plan.md` plus its optional planning support artifacts.

## Prereqs

- `docs/maxi/constitution.md` must exist — hard stop if missing: *"No constitution found. Run `/maxi:constitution` first."*
- For normal plan creation, locate the spec in `docs/maxi/specs/` at status `clarified`
  - If status is `drafting`: stop — *"Spec is still `drafting`. Run `/maxi:specify` first."*
  - If status is `specified`: stop — *"Spec must be `clarified` before planning. Run `/maxi:clarify` first. If the spec has no ambiguities, `/maxi:clarify` will complete in seconds and confirm this."*
  - If status is `planned` or later and the user did not explicitly request a structural `plan.md` correction: stop — *"Spec is already `planned`. Proceed to `/maxi:tasks`."*
- An explicit structural plan correction is a separate owner mode. It accepts only `planned`, `tasked`, `analyzed`, or `implementing`; `parked`, `cancelled`, and `done` remain blocked. Never infer correction mode from an ordinary `/maxi:plan` invocation.

## Process

1. **Read artifacts** — before normal planning, record whether `plan.md` already exists; then load `spec.md` (FRs, SCs, user stories) and `constitution.md` (principles, constraints).
2. **Constitution check** — before planning: does anything in the spec contradict constitution principles? Flag violations to the user before proceeding. (Do NOT silently discard violating requirements — surface them.)
3. **Invoke /maxi:writing-plans** — **REQUIRED SUB-SKILL.** Pass the spec and constitution as context. Let writing-plans run its full planning process including file structure decisions and task decomposition.
4. **Post-format into plan schema** — write output to `docs/maxi/specs/NNNN-slug/plan.md` following `plan-template.md` structure and the Global Constraints Protocol below. Set plan.md frontmatter: `slug` and `spec_slug` from spec, `created` and `updated` to today's ISO date. Additionally create any of these if writing-plans produced them: `research.md`, `data-model.md`, `contracts/` directory
5. **ADR scan (post-planning)** — scan the just-written `plan.md` for non-obvious architectural choices. Look for: Tech Stack sections, storage/database/runtime/framework picks, phrases like "we chose X over Y because" or "considered A, B, chose C". For each detected choice, invoke `/maxi:x-adr` — it will draft the ADR, show it to the user, and write it only if the user consents. If the user declines all ADR proposals, the plan is still complete; ADR capture is opt-out, not mandatory. Do not invoke `/maxi:x-adr` for trivial choices (e.g., variable naming conventions, test library defaults).
6. **Transition status** — update spec.md frontmatter `status → planned`; also set `updated: [today's ISO date]` on spec.md and on plan.md.
7. **Initial design review** — only when `plan.md` did not exist before normal planning, Invoke `/maxi:review` exactly once for one design review after both current `spec.md` and `plan.md` files are written. Do not ask the user to invoke it. If it is rejected, report its findings and stop; do not start a correction, replacement review, or successor phase.
8. **Replanning boundary** — when a pre-existing `plan.md` was rewritten after `/maxi:revise` and `/maxi:clarify`, preserve the new plan and stop with zero automatic design-review dispatches. Direct the user to `/maxi:review`; do not start a replacement review or successor phase.
9. **Report** — after an approved initial review: *"Plan written to `docs/maxi/specs/NNNN-slug/plan.md` (status: `planned`). Design review approved. Next: `/maxi:tasks`."* For replanning: *"Plan updated (status: `planned`). No review or successor phase was started. Request `/maxi:review` when you want a new design review."*

## Explicit Structural Plan Correction

Use this owner mode only when the user explicitly requests a structural correction to the existing `plan.md` and the spec status is `planned`, `tasked`, `analyzed`, or `implementing`. `parked`, `cancelled`, and `done` are blocked, and a normal invocation never becomes a correction implicitly.

1. Read the current `plan.md` before any write.
2. Invoke `superpowers:writing-plans` for the correction.
3. Post-format the corrected plan using the Global Constraints Protocol below.
4. Return the spec status to `planned`.
5. Report: *"Correction recorded. No review or successor phase was started. Request `/maxi:review` when you want a new design review."*

This correction never invokes `review`, `specify`, `clarify`, `tasks`, or `analyze` and never edits `tasks.md` or `analysis.md`.

## Global Constraints Protocol

Apply this protocol to normal creation, replanning, and explicit structural plan correction after mandatory delegation to `superpowers:writing-plans`. Classify only applicable durable cross-task constraints from the current spec and constitution: scope boundaries, protected artifacts or data, required verification evidence, compatibility or integration handoffs, and completion or reporting expectations.

Post-format every newly written or structurally corrected plan with exactly one `Global Constraints` section and no second delivery-contract section. Use simple applicable-only bullets with no fixed category labels or per-category None entries. When none apply, write exactly:

- No additional global constraints apply.

Exclude current worktree, HEAD, selected tasks, and stop point. Do not persist individual authorization for Git-history, remote-repository, deployment/infrastructure, data-publication, or secret-access mutations. A durable rule requiring fresh authorization is allowed, but an earlier authorization never carries forward.

Do not add a reviewer predicate, artifact, status, ledger record, automatic dispatch, or any other execution mechanism for this protocol. Existing historical plans remain byte-unchanged unless an owning Maxi workflow explicitly rewrites them.

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

`quickstart.md` remains an optional planning output.

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
