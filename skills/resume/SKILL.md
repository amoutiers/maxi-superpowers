---
name: resume
description: Use when the user invokes /maxi:resume, wants to unpause a spec, or asks to pick up a parked feature — requires a spec at status parked, reads parked_from to restore the prior status.
---

# resume

Restore a parked spec to its previous active status.

## Prereqs

- `docs/maxi/constitution.md` must exist — hard stop if missing.
- Locate target spec at `status: parked`. If multiple parked specs, list them and ask which one.
- **Refuse** if no spec at `status: parked` → *"No parked spec found. Use `/maxi:board` to see current statuses."*
- **Refuse** if spec is `status: cancelled` → *"Spec is cancelled (terminal). It cannot be resumed."*
- **Refuse** if spec is at any non-parked active status → *"Spec is at `<status>`, not parked. Nothing to resume."*

## Process

1. **Read `parked_from:`** from spec.md frontmatter. This is the status to restore.
   - If `parked_from:` is missing or `null`: warn — *"The `parked_from:` field is missing on this spec. I can't determine what status to restore. Please tell me which status to restore to (`clarified`, `planned`, `tasked`, `analyzed`, or `implementing`), and I will set it."* Wait for user input before proceeding.
2. **Confirm**: *"Resume `<slug>`? It will return to `status: <parked_from>`. (yes/no)"*
3. **On explicit `yes` only**: write `spec.md` —
   - `status: <parked_from>`
   - `parked_from: null`
   - `updated: <today's ISO date>`
   - Append to `## Clarifications`: `**Resumed (YYYY-MM-DD):** returning to \`<parked_from>\``
4. **Report**: *"`<slug>` resumed at `<parked_from>`. Next: `/maxi:<next-skill>`."*
   - `clarified` → next is `/maxi:plan`
   - `planned` → next is `/maxi:tasks`
   - `tasked` → next is `/maxi:analyze`
   - `analyzed` → next is `/maxi:implement`
   - `implementing` → next is `/maxi:implement` (resume from first unchecked task)
   - Other → list available pipeline skills

## Invariants

- **`parked_from:` is the single source of truth** for restore target. Do NOT ask the user what status to restore to unless `parked_from:` is missing.
- **Clear `parked_from: null` on resume** — failure to clear it leaves stale data that confuses future park/resume cycles.
- **Never write without explicit `yes`.**
- **Never modify** `plan.md`, `tasks.md`, `analysis.md`, `constitution.md`, or any ADR file.

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.

## Rationalization Counters

| Rationalization | Counter |
|---|---|
| "I'll restore to `clarified` since that's the safest default" | Read `parked_from:`. That is the only valid restore target. |
| "parked_from is null but I know it was implementing" | Ask the user explicitly. Do not guess. |
| "I'll leave parked_from as-is after resume" | `parked_from:` must be cleared to `null`. Stale field breaks future park cycles. |
