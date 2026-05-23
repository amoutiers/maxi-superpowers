---
adr: NNNN
slug: NNNN-[short-decision-slug]
status: proposed
# Note: transitions to "accepted" when user confirms the ADR
date: YYYY-MM-DD
updated: YYYY-MM-DD
decider: "[name-or-role]"
related_specs: []
related_principles: []
related_requirements: []
supersedes: null
superseded_by: null
---

# ADR-NNNN: [Short Title — One Line]

## Context

<!--
  What forces, constraints, or events led to this decision?
  What problem were we solving? What was the pressure?
-->

[Describe the situation that made a decision necessary. Include any
constraints (time, budget, team skill, existing infrastructure) and
the goals the decision must serve.]

## Decision Drivers

<!--
  What criteria determined the choice? Derive from: constitution principles
  (related_principles), spec requirements (FR-###, SC-###), and explicit
  constraints from the plan. Minimum 1, usually 2–4.
-->

- [criterion — e.g., no external server dependency]
- [criterion — e.g., aligns with principle "II. Simplicity Over Cleverness"]
- [criterion — e.g., SQL query capability required]

## Considered Options

<!--
  List every meaningful option that was on the table, including the
  status quo if "do nothing" was a live option.
  For each option, add ✅/❌ lines referencing a driver above.
-->

- **Option A: [Name]** — [one-sentence description]
  - ✅ Satisfies driver: [criterion]
  - ❌ [trade-off or limitation]
- **Option B: [Name]** — [one-sentence description]
  - ✅ [pro]
  - ❌ Violates driver: [criterion]
- **Option C: [Name]** — [one-sentence description]
  - ✅ [pro]
  - ❌ [con]

## Decision

Chose **Option A**, because [concise rationale tied to the context and
any principles listed in related_principles].

## Consequences

- **Good:** [positive outcome 1]
- **Good:** [positive outcome 2]
- **Bad:** [accepted trade-off 1]
- **Bad:** [accepted trade-off 2]

## Confirmation

[Describe how this decision will be verified or enforced over time.
Examples: "No direct import of <library> outside src/adapter/",
"Architecture review required before adding a second database",
"Performance benchmark must stay below 200 ms on CI".]
