---
name: cancel
description: Use when the user invokes /maxi:cancel, says a feature is abandoned, dead, or will never ship — requires active spec status, explicit reason, and explicit yes/no confirmation before writing anything.
---

# cancel

Mark a spec as permanently abandoned. Terminal status — cannot be un-cancelled.

## Prereqs

- `docs/maxi/constitution.md` must exist — hard stop if missing: *"No constitution found. Run `/maxi:constitution` first."*
- Locate the target spec in `docs/maxi/specs/`. If multiple specs at an active status, ask which one.
- **Refuse** if spec is already at `status: cancelled` → *"Spec is already cancelled."*
- **Refuse** if spec is at `status: parked` → *"Spec is parked. Run `/maxi:resume` first, then `/maxi:cancel`."*
- **Refuse** if spec is at `status: done` → *"Spec is done (shipped). Cancellation is for in-progress work, not shipped features."*

## Process

1. **Display spec summary**: slug, title, current status, `updated` date.
2. **Ask for reason**: *"Reason for cancellation?"* — require a non-empty answer. Do NOT proceed without one.
3. **Confirm**: *"About to mark `<slug>` as CANCELLED (terminal — cannot be un-cancelled). Reason: `<reason>`. Proceed? (yes/no)"*
4. **On explicit `yes` only**: write `spec.md` —
   - `status: cancelled`
   - `updated: <today's ISO date>`
   - Append to `## Clarifications`: `**Cancelled (YYYY-MM-DD):** <reason>`
5. **Report**: *"Spec `<slug>` cancelled. It will appear in the `cancelled` bucket of `/maxi:board`."*

## Invariants

- **Never write without explicit `yes`.** Ambiguous responses ("ok", "sure", "fine", silence) = `no`. Ask once more, then stop.
- **Terminal**: once cancelled, no `/maxi:resume`. The pipeline has no un-cancel path.
- **Reason is mandatory**: do not cancel without a written reason, even if the user says "obvious" or "you know why".
- **Never modify** `plan.md`, `tasks.md`, `analysis.md`, `constitution.md`, or any ADR file.
- **Only `spec.md` is written** — and only the `status:`, `updated:` fields and `## Clarifications` section.

## Rationalization Counters

| Rationalization | Counter |
|---|---|
| "User said ok / sure / fine" | Not explicit `yes`. Ask one more time. If still ambiguous, stop. |
| "The spec is obviously dead, I'll just cancel it" | Still need reason + explicit `yes`. No exceptions. |
| "User said to cancel without giving a reason" | Ask for the reason before proceeding. Do not skip. |
| "Cancelling is non-destructive, no need for confirmation" | Terminal operations require consent. Always confirm. |
| "I'll update plan.md too since it's stale now" | Only `spec.md`. Touch nothing else. |
