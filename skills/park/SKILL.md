---
name: park
description: Use when the user invokes /maxi:park, wants to pause a spec, put a feature on hold, or says it is blocked — requires active spec status, explicit reason, and yes/no confirmation before writing.
---

# park

Freeze a spec in place without losing progress. Non-terminal — resumable via `/maxi:resume`.

## Prereqs

- `docs/maxi/constitution.md` must exist — hard stop if missing.
- Locate target spec. If multiple active specs, ask which one.
- **Refuse** if already `status: parked` → *"Spec is already parked. Use `/maxi:resume` to pick it back up."*
- **Refuse** if `status: cancelled` → *"Spec is cancelled. Cannot park a cancelled spec."*
- **Refuse** if `status: done` → *"Spec is done (shipped). No need to park."*

## Process

1. **Display spec summary**: slug, title, current status.
2. **Ask for reason**: *"Reason for parking?"* — require a non-empty answer.
3. **Confirm**: *"About to park `<slug>` (currently `<status>`). Reason: `<reason>`. Proceed? (yes/no)"*
4. **On explicit `yes` only**: write `spec.md` —
   - `status: parked`
   - `parked_from: <current_status>` — **must be set before writing**
   - `updated: <today's ISO date>`
   - Append to `## Clarifications`: `**Parked (YYYY-MM-DD):** <reason> (was: <current_status>)`
5. **Report**: *"`<slug>` is now parked. Run `/maxi:resume` to pick it back up."*

## Invariants

- **`parked_from:` MUST be set** to the current status before writing. If you write `status: parked` without setting `parked_from:`, resume has no target to restore to.
- **Never write without explicit `yes`.**
- **Never modify** `plan.md`, `tasks.md`, `analysis.md`, `constitution.md`, or any ADR file.
- Only `spec.md` is written — `status:`, `parked_from:`, `updated:`, and `## Clarifications` section.

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.

## Rationalization Counters

| Rationalization | Counter |
|---|---|
| "User said ok / sure" | Not explicit `yes`. Ask once more, then stop. |
| "I'll just set status: parked, parked_from doesn't matter" | `parked_from:` is mandatory. Without it, resume is broken. |
| "The spec will still be there, no confirmation needed" | Parking freezes the pipeline. Confirm first. |
