---
adr: 0001
slug: 0001-fsm-status-expansion
status: accepted
created: 2026-05-24
updated: 2026-05-24
decider: "Antoine Moutiers"
related_specs: ["0001-design-review-fixes"]
related_principles: ["III. Strict Pipeline — No Skipping", "V. Artifacts Over Chat"]
related_requirements: ["FR-006", "FR-007", "FR-008"]
supersedes: null
superseded_by: null
---

# ADR-0001: FSM Status Set Expansion — parked + cancelled

## Context

The maxi pipeline FSM originally defined 8 forward-only statuses: `drafting → specified → clarified → planned → tasked → analyzed → implementing → done`. All statuses implied active forward progression. There was no way to represent a spec that was intentionally paused (blocked, de-prioritised) or definitively abandoned — features that any long-lived project will inevitably need.

Without lifecycle statuses, abandoned specs accumulated as `implementing` entries on `/maxi:board` with growing staleness indicators, and users were forced to either delete spec directories (losing history) or hand-edit `status:` (forbidden by constitution). The 2026-05-24 design review (spec 0001) identified this as F5 — a gap that would force workarounds in any real project.

## Decision Drivers

- **Principle III — Strict Pipeline, No Skipping**: No hand-editing of `status:` is permitted. The pipeline must have a sanctioned path for every lifecycle transition, including pausing and abandoning.
- **Principle V — Artifacts Over Chat**: Decisions to pause or cancel a feature must be recorded in the spec artifact with a reason and date — not just acknowledged in conversation.
- **Consistency with consent-gated ADR pattern**: All destructive or lifecycle-altering operations in maxi are consent-gated (see `/maxi:adr`, `/maxi:migrate-from-speckit`). New lifecycle skills must follow the same pattern.
- **Terminal vs. reversible**: A paused spec may be resumed; a cancelled spec is final. The FSM must distinguish these two states to enforce the right constraints.

## Considered Options

- **Option A: Two new statuses — `parked` (non-terminal) + `cancelled` (terminal)**
  New skills `/maxi:park`, `/maxi:resume`, `/maxi:cancel` manage the transitions. `parked_from:` frontmatter field stores the pre-park status for restore. Both statuses are consent-gated.
  - ✅ Satisfies driver: Principle V — decision recorded with reason and date
  - ✅ Satisfies driver: Principle III — no hand-editing needed
  - ✅ Satisfies driver: terminal vs. reversible distinction enforced at the skill level
  - ❌ Adds 2 statuses and 3 skills to the system; increases FSM surface area

- **Option B: Single `inactive` status**
  One status covers both pausing and abandonment. No `parked_from:` field — user must know where to resume from.
  - ✅ Simpler FSM (9 statuses instead of 10)
  - ❌ Violates driver: conflates reversible (parked) and irreversible (cancelled) — resume from wrong status becomes possible
  - ❌ No `parked_from:` field means the pipeline cannot restore the correct prior status

- **Option C: No new statuses — use `done` + convention**
  Mark abandoned specs `done` with a convention note in `## Clarifications`.
  - ❌ Violates driver: `done` means "shipped" — conflating abandoned with done corrupts the board and reporting
  - ❌ Violates driver: Principle V — no sanctioned artifact path for this decision

## Decision

Chose **Option A**. Two statuses (`parked`, `cancelled`) with three consent-gated skills (`/maxi:park`, `/maxi:resume`, `/maxi:cancel`) and a `parked_from:` frontmatter field for non-destructive resume.

## Consequences

- **Good:** Abandoned and paused specs have a sanctioned home in the FSM; no hand-edits needed.
- **Good:** `/maxi:board` shows `parked` and `cancelled` buckets — pipeline shape stays visible even for non-active specs.
- **Good:** `parked_from:` field enables mechanical restore without asking the user what status to return to.
- **Bad:** FSM grows from 8 to 10 statuses; `check-spec-fixture.sh` and `spec-template.md` must be updated.
- **Bad:** Three new skills increase the skills inventory; `CLAUDE.md` and `check-skills-present.sh` must be kept in sync.

## Confirmation

- `tests/check-spec-fixture.sh` validates `parked` and `cancelled` round-trip in the VALID_STATUSES array.
- `templates/spec-template.md` allowed-values comment lists all 10 statuses.
- `/maxi:board` displays `parked` and `cancelled` buckets (even when empty).
- No direct `status:` edit to `parked` or `cancelled` is possible without running `/maxi:park` or `/maxi:cancel` respectively (enforced by convention; future F8 PreToolUse hook will enforce mechanically).
