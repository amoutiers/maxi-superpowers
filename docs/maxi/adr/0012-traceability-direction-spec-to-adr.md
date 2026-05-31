---
adr: 0012
slug: 0012-traceability-direction-spec-to-adr
status: accepted
created: 2026-05-31
updated: 2026-05-31
decider: "Antoine Moutiers"
supersedes: null
superseded_by: null
---

# ADR-0012: Traceability direction is spec → ADR, not ADR → spec

## Context

Each ADR carried three cross-reference frontmatter fields — `related_specs`,
`related_principles`, `related_requirements` — pointing from the ADR *up* to the
spec, principles, and requirements that motivated it. This makes a durable,
append-only ADR depend on an ephemeral, revisable spec (a spec can be `revised`,
`parked`, or `cancelled`; an ADR cannot). ADR-0003 already established, for the
constitution, that dependency direction must be one-way: an authoritative,
long-lived artifact must not depend on a lower-tier, revisable one. The same
inversion existed, unnoticed, between ADRs and specs. An audit also found that of
the three fields only `related_specs` had a machine consumer (`analyze` Pass G);
`related_principles` was produced but never analytically consumed, and
`related_requirements` had no consumer at all — both duplicated prose already
present in the ADR body.

## Decision Drivers

- **One-way dependency direction** — the doctrine ADR-0003 set for the
  constitution applies identically here: durable ADRs must not depend on
  revisable specs. (related: ADR-0003)
- **ADR self-containment** — the Nygard/MADR genre is a self-contained record
  (metadata + supersession chain); spec/requirement linkage belongs in the prose
  (Context, Decision Drivers), not in structured frontmatter.
- **Single machine consumer, re-pointable** — only `analyze` Pass G read
  `related_specs`; it can read the inverse `related_adrs` from the spec side with
  no loss of capability. (related_requirements: FR-008)

## Considered Options

- **Option A: Invert to spec → ADR** — remove all three fields from the ADR; add
  `related_adrs` (full ADR slugs) to `spec.md`, written by `x-adr` on acceptance;
  re-point `analyze` Pass G to read the spec side.
  - ✅ Satisfies driver: one-way dependency direction
  - ✅ Satisfies driver: ADR self-containment
  - ✅ Satisfies driver: single machine consumer re-pointable
  - ❌ Requires a one-time migration of 11 ADRs + 6 specs and reverses FR-016/FR-017
- **Option B: Drop only the two decorative fields, keep ADR-side `related_specs`** —
  remove `related_principles`/`related_requirements`, keep `related_specs`.
  - ✅ Smaller change; preserves the machine consumer in place
  - ❌ Violates driver: one-way dependency direction (the ADR still depends on the spec)
  - ❌ Violates driver: ADR self-containment
- **Option C: Keep all three as bidirectional traceability** — change nothing.
  - ✅ No migration cost
  - ❌ Violates driver: one-way dependency direction
  - ❌ Two of three fields have no machine consumer and duplicate the ADR's prose

## Decision

Chose **Option A**. The ADR schema is reduced to genre-native metadata
(`adr`, `slug`, `status`, `created`, `updated`, `decider`, `supersedes`,
`superseded_by`) plus its body. Traceability lives on the spec via
`related_adrs: ["NNNN-slug", ...]`, appended by `x-adr` when an ADR is accepted in
the context of an active spec. `analyze` Pass G builds its spec↔ADR registry from
`related_adrs` + inline `ADR-NNNN` mentions. This extends ADR-0003's
dependency-direction doctrine from constitution↔CLAUDE.md to ADR↔spec.

## Consequences

- **Good:** The ADR no longer depends on a mutable, lower-tier artifact; it is a
  self-contained Nygard/MADR record.
- **Good:** Dependency direction is uniformly one-way across the project, matching
  ADR-0003.
- **Good:** No machine capability is lost — `analyze` G1/G3 read the spec side.
- **Bad:** A one-time migration strips the three fields from 11 existing ADRs and
  writes back-links onto 6 specs.
- **Bad:** Reverses FR-016/FR-017 (migrate-adr populating `related_principles`);
  those requirements receive linked supersession notes pointing at spec 0018.

## Confirmation

Enforced by spec 0018's tests and criteria: `tests/check-templates.sh` asserts the
three fields are absent from the ADR template and fixture; `grep` over
`docs/maxi/adr/` returns zero `related_specs`/`related_principles`/`related_requirements`
frontmatter matches (SC-001); the six prior `related_specs` links are preserved as
`related_adrs` entries spec-side (SC-002); `analyze` Pass G1/G3 remain
behavior-preserving against the spec-side registry (SC-003); `bash tests/run-all.sh`
stays green (SC-004).
