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

1. **Read artifacts** — load `spec.md` (FRs, SCs, user stories) and `constitution.md` (principles, constraints)
2. **Constitution check** — before planning: does anything in the spec contradict constitution principles? Flag violations to the user before proceeding. (Do NOT silently discard violating requirements — surface them.)
3. **Invoke /maxi:writing-plans** — **REQUIRED SUB-SKILL.** Pass the spec and constitution as context. Let writing-plans run its full planning process including file structure decisions and task decomposition.
4. **Post-format into plan schema** — write output to `docs/maxi/specs/NNNN-slug/plan.md` following `plan-template.md` structure. Set plan.md frontmatter: `slug` and `spec_slug` from spec, `created` and `updated` to today's ISO date. Additionally create any of these if writing-plans produced them: `research.md`, `data-model.md`, `contracts/` directory
5. **ADR scan (post-planning)** — scan the just-written `plan.md` for non-obvious architectural choices. Look for: Tech Stack sections, storage/database/runtime/framework picks, phrases like "we chose X over Y because" or "considered A, B, chose C". For each detected choice, invoke `/maxi:adr` — it will draft the ADR, show it to the user, and write it only if the user consents. If the user declines all ADR proposals, the plan is still complete; ADR capture is opt-out, not mandatory. Do not invoke `/maxi:adr` for trivial choices (e.g., variable naming conventions, test library defaults).
6. **Transition status** — update spec.md frontmatter `status → planned`; also set `updated: [today's ISO date]` on spec.md and on plan.md
7. **Report** — *"Plan written to `docs/maxi/specs/NNNN-slug/plan.md` (status: `planned`). Next: `/maxi:tasks`."*

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
- Writing ADR files directly without invoking `/maxi:adr` → delegate to `/maxi:adr`, which handles consent, numbering, and index updates
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
