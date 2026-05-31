---
adr: 0011
slug: 0011-migration-ingress-terminal-status
status: accepted
created: 2026-05-30
updated: 2026-05-30
decider: "Antoine Moutiers"
supersedes: null
superseded_by: null
---

# ADR-0011: Migration / Reverse-Engineering Ingress May Set Terminal Status on Creation

## Context

Spec 0005 (`migrate-from-brownfield`) reverse-engineers existing code into `spec.md` baselines written directly at `status: done`. This collided with **Principle III (Strict Pipeline — No Skipping)** and the constraint *"Status managed by the pipeline only — the `status:` field must never be edited by hand."* The existing `migrate-from-speckit` skill already lands migrated specs at terminal/advanced statuses the same way — an undocumented deviation. A decision was needed that resolves both rather than treating each as a one-off.

## Decision Drivers

- **Principle III** governs *forward development* (no shortcuts to ship new work faster) — its purpose is not engaged by documenting already-shipped code.
- **Recurring category, not a one-off**: two skills (speckit, brownfield) share this behavior; a per-skill exception would leave the category unnamed and `migrate-from-speckit` undocumented.
- **No silent pipeline exceptions** — the project's culture (CLAUDE.md mandatory-sync, design-review history) rejects undocumented deviations.
- **Provenance must remain visible** — a reverse-engineered spec must be distinguishable from a pipeline-authored one (spec FR-012, `origin:`).

## Considered Options

- **Option A: Amend the constitution to recognize "migration / reverse-engineering ingress" as a category** — Principle III gains an ingress clause; the status constraint gains an exception; ingress skills may set terminal status on creation if they mark `origin:` provenance and never alter forward-spec gating.
  - ✅ Satisfies driver: names the recurring category; legitimizes both ingress skills at once
  - ✅ Satisfies driver: keeps Principle III strict for forward development
  - ✅ Satisfies driver: provenance requirement baked into the rule
  - ❌ Bumps constitution version (1.3.0 → 1.4.0) and touches a shared artifact

- **Option B: Per-skill exception note in spec 0005** — document the deviation only inside the brownfield skill.
  - ✅ Minimal scope; no constitution edit
  - ❌ Violates driver: treats a category as a one-off; leaves `migrate-from-speckit` deviation undocumented
  - ❌ Exceptions accumulate ad hoc, eroding "strict, no skipping"

- **Option C: Forbid terminal-on-creation; route reverse-engineered specs through the full pipeline**
  - ✅ No constitution change; pipeline stays literally strict
  - ❌ Violates driver: forces clarify/plan/tasks/analyze/implement on already-shipped code — busywork with no consumer
  - ❌ Contradicts the entire purpose of an ingress skill

## Decision

Chose **Option A**. Amended the constitution to v1.4.0: Principle III gains an ingress clause and the status constraint gains a matching exception. Migration / reverse-engineering ingress skills may set an appropriate terminal status on spec creation, provided they (1) mark provenance via `origin:` and (2) never alter forward-development gating.

## Consequences

- **Good:** Both `migrate-from-speckit` and `migrate-from-brownfield` are now principled, not exceptional.
- **Good:** Principle III stays strict for forward development — the carve-out is explicitly scoped to ingress.
- **Good:** `origin:` provenance is a constitutional requirement, so reverse-engineered specs stay distinguishable (consistent with ADR-0001's "`done` = shipped" semantics; revisable via ADR-0002's backflow).
- **Bad:** Constitution surface grows; the ingress clause is a new concept `using-maxi` and pipeline docs must describe when ingress skills ship.
- **Bad:** No mechanical enforcement yet that an ingress skill sets `origin:` — relies on skill implementation + tests.

## Confirmation

- Constitution v1.4.0 contains the ingress clause in Principle III and the status-constraint exception.
- `migrate-from-brownfield` (spec 0005) writes specs with `status: done` **and** `origin: reverse-engineered` (FR-011, FR-012); its fast-tier test asserts the `origin:` field is present.
- The ingress clause is scoped to ingress skills only; forward-development specs remain gated as before (no change to `clarify`/`plan`/etc. status checks).
