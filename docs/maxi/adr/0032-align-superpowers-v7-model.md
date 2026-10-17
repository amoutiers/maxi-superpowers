---
adr: 0032
slug: 0032-align-superpowers-v7-model
spec: 0027-superpowers-v7-adaptation
design_cycle: 0
status: accepted
created: 2026-10-17
updated: 2026-10-17
decider: "Antoine Moutiers"
supersedes: 0031
superseded_by: null
---

# ADR-0032: Align Superpowers v7 Design and Harness Model

## Context

Superpowers v7.0.0 rebuilds brainstorming, adds a builder check and native Antigravity packaging, and fixes hook and Hermes behavior. The approved adaptation requires adoption within Maxi's existing pipeline. This supersedes ADR-0031's version and harness relationship; its execution and evidence safeguards remain applicable as stated below.

## Decision Drivers

- Delegate upstream capabilities and preserve exact vendoring (Constitution II; FR-001 and FR-003).
- Preserve canonical ownership and mandatory product gates (Constitution I, III and V; FR-002 through FR-006).
- Use actual host interfaces and distinguish packaging from native behavior (FR-007 through FR-011).

## Considered Options

- Option A: Import v7 and adapt existing Maxi boundaries. Satisfies all drivers; requires focused compatibility and installed tests.
- Option B: Import v7 alone. Preserves upstream bytes but leaves the reproduced host defects and unadapted design exits.
- Option C: Modify vendored skills or add another executor. Violates exact delegation or expands the completion contract beyond this upgrade.

## Decision

Choose Option A.

- Import exact v7.0.0 through existing subtree/sync scripts, retaining 15 upstream skills, 19 Maxi-native skills and ten FSM states.
- Bind delegated skills, builder prompt and helpers to the loaded owner's installed snapshot.
- Return every delegated brainstorming exit to Maxi's author. Request size, interview opt-out and prototypes do not authorize skipping forward-development phases.
- Run one fresh upstream builder check on newly created non-draft canonical specifications before clarification. Route corrections through the author. The check grants no design approval, writes no additional review artifact and does not replace the existing spec/plan review. Existing revisions and draft-only requests retain their boundaries.
- Keep SDD and x-develop ownership, all three product review boundaries, immutable projections, completion ancestry, fresh historical-continuation review and terminal receipt requirements. Only implement records done before branch finishing.
- Add native Antigravity packaging. Explicitly permit its surfaced skill description to trigger a project check before using-maxi activates the pipeline. This is a discovery-based host exception alongside the retained Gemini/Kimi exceptions. Keep executable adapters gated on docs/maxi and add no per-model-call hook.
- Port root hook and Hermes fixes while preserving host formats, project gates and complete skill descriptions.

## Consequences

- Good: v7 capabilities integrate without a vendored fork or another completion path.
- Good: Canonical ownership and existing evidence remain enforceable.
- Bad: Narrow compatibility and host checks remain Maxi's responsibility.
- Bad: Discovery depends on model selection; native behavior requires actual acceptance evidence. A validator alone proves packaging, and unavailable native hosts remain explicit open qualification limits.

## Confirmation

Run the complete fast tier, installed v7 intent/builder/opt-out cases, initial and revision design, two-task pause/resume and completed-v1 continuation. Retain installed-byte checks, actual child identities and reads, Git packages and receipts. Update the Mandatory Sync five with owning changes and report source identities and unresolved host limits separately from publication.
