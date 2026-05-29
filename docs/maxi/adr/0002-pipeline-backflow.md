---
adr: 0002
slug: 0002-pipeline-backflow
status: accepted
created: 2026-05-24
updated: 2026-05-24
decider: "Antoine Moutiers"
related_specs: ["0001-design-review-fixes"]
related_principles: ["III. Strict Pipeline — No Skipping", "IV. ADR for Every Non-Trivial Architectural Decision", "V. Artifacts Over Chat"]
related_requirements: ["FR-005"]
supersedes: null
superseded_by: null
---

# ADR-0002: Pipeline Backflow — /maxi:revise

## Context

The maxi pipeline is strictly forward-only: `specified → clarified → planned → … → done`. Once a spec reaches `planned` or beyond, the existing skills (`clarify`, `analyze`) refuse to run on it (by design). Yet real projects change: requirements clarify late, scope shifts after planning, a stakeholder adds a constraint post-task extraction.

Before this ADR, the only escape was to hand-edit `status:` — which `using-maxi/SKILL.md` explicitly forbids ("Never hand-edit the `status:` frontmatter"). Users were forced to choose between violating the constitution or creating a brand-new spec (losing all prior context). The 2026-05-24 design review (spec 0001, F4) identified this as a structural gap that would drive pipeline bypass in any active project.

## Decision Drivers

- **Principle III — Strict Pipeline, No Skipping**: The pipeline's non-negotiable rule includes the reverse direction — there must be a sanctioned path for rolling back, not just advancing.
- **Principle V — Artifacts Over Chat**: A requirements change must be recorded with its reason, date, and affected status in the spec artifact.
- **No magic inference**: Rollback target must be transparent and correctable. Silent inference of the target status would create invisible decisions — violating the spirit of Principle IV.
- **Artefact preservation**: Downstream artefacts (plan.md, tasks.md, analysis.md) represent work that took effort. Deleting them on rollback loses context useful for re-planning. They should remain on disk, flagged as stale.

## Considered Options

- **Option A: `/maxi:revise` with A+ picker (suggested default + override)**
  Skill reads description of change → infers a suggested rollback target with a one-sentence justification → user confirms or overrides from `[clarified | planned | tasked | analyzed]` → writes `status:` rollback + `## Clarifications` entry → downstream artefacts left in place.
  - ✅ Satisfies driver: transparent inference (A+ picker shows reasoning before applying)
  - ✅ Satisfies driver: Principle V — change recorded with reason, date, rollback target
  - ✅ Satisfies driver: artefacts preserved (left on disk, flagged stale in Clarifications)
  - ❌ Inferred target may be wrong; user must actively verify the suggestion

- **Option B: Always roll back to `clarified`**
  Simplest rule: every revision resets to `clarified`, forcing all phases to re-run.
  - ✅ No inference needed — deterministic
  - ❌ Over-rolls-back for plan-level changes (plan change → re-runs clarify unnecessarily)
  - ❌ Violates driver: wastes pipeline phases for no reason; contradicts "phases are cheap but bounded"

- **Option C: `--rerun` flag on existing skills (clarify, plan, etc.)**
  Existing skills accept a `--rerun` flag that overrides the status gate and rolls back.
  - ✅ No new skill needed
  - ❌ Violates driver: inline flag is less discoverable than a dedicated skill
  - ❌ Makes status management a side-effect of phase skills, not an explicit lifecycle operation

## Decision

Chose **Option A** — `/maxi:revise` with the A+ picker pattern. A dedicated skill is more discoverable than a flag; the picker makes inference visible and correctable; artefact preservation maintains planning context.

## Consequences

- **Good:** Requirements changes have a sanctioned, recorded path — no hand-edits needed.
- **Good:** A+ picker is transparent: the inferred target and its justification are shown before any write happens.
- **Good:** Downstream artefacts (plan.md, tasks.md) remain on disk after rollback, preserving context for re-planning.
- **Bad:** `/maxi:revise` is the first skill that makes `status:` go backwards — a conceptually new operation for the pipeline. Documentation and `using-maxi` must explicitly describe this.
- **Bad:** Stale artefacts have no mechanical enforcement (only a `## Clarifications` flag). Future F8 PreToolUse hook (out of scope for spec 0001) is the long-term solution.

## Confirmation

- `/maxi:revise` is invokable on specs at status `clarified` through `implementing`.
- After `/maxi:revise`, `status:` matches the chosen rollback target; `## Clarifications` contains a timestamped entry with reason and prior status.
- plan.md, tasks.md, analysis.md are present and unmodified after rollback (staleness flagged only in Clarifications).
- `/maxi:revise` is refused on specs at `drafting`, `specified`, `parked`, `cancelled`, `done`.
- Integration test (`tests/integration/prompts/revise.txt`) triggers the skill automatically.
