# 0019 Simplified Bounded Replay Design

## Purpose

Prevent unnecessary loops through `specify -> clarify -> plan -> tasks -> analyze` while retaining visible document revisions. The system must identify the smallest affected continuation, tell the user what is stale, and wait for explicit confirmation before it regenerates anything.

## Scope

- Every document created for a future spec through the normal Maxi pipeline carries `revision: 1`.
- Existing specs and their documents are not migrated, rewritten, or interpreted differently.
- Migration and reverse-engineering workflows are outside this mechanism.
- A derived document records only its direct document inputs and their revisions in `derived_from`.
- A structural, owner-managed change increments that document's revision. Operational metadata and task-completion checkboxes do not trigger replay by themselves.

## Document Flow

`spec.md` is the source of requirements. Planning support documents and `plan.md` derive from the spec. `tasks.md` derives from the plan. `analysis.md` derives from the current plan and task list.

When a direct input revision no longer matches a declared dependency, the affected document is stale. Transitive descendants of a stale document are also stale.

Examples:

- A `plan.md` revision changes: `tasks.md` and `analysis.md` are stale. The minimal continuation is `tasks -> analyze`.
- A `tasks.md` revision changes: only `analysis.md` is stale. The minimal continuation is `analyze`.
- A `spec.md` revision changes: the planning documents, plan, tasks, and analysis are stale. The minimal continuation is `clarify -> plan -> tasks -> analyze`.

## User Interaction

The responsible skill calculates the stale descendants and presents a replay proposal before any regeneration:

```text
plan.md changed: revision 3 -> 4
Stale descendants: tasks.md, analysis.md
Minimal continuation: tasks -> analyze
No action has been performed. Continue? [yes/no]
```

Only an explicit `yes` authorizes that displayed continuation. Silence, an ambiguous acknowledgement, and prior approval do not authorize a replay. The proposal must never include unaffected ancestors or a full pipeline restart unless the source spec itself changed.

If the re-run analysis still fails, Maxi reports the result and stops. It does not start another correction or replay until the user explicitly authorizes a new proposal.

## Implementation Boundary

The behavior is implemented by updating the owner skills (`specify`, `clarify`, `plan`, `tasks`, `analyze`, `revise`, and `implement`) and one small shared replay-planning support script. The support script only reads revisions and direct dependencies, computes stale descendants, and formats the proposal. It does not write artifacts, own lifecycle state, or orchestrate phases.

No new FSM status, workflow ledger, transactional write-ahead protocol, ADR-currentness framework, agentic integration runner, or retrospective migration of existing specs is part of this design.

## Error Handling

- Missing or malformed revision metadata in a newly created pipeline spec stops the relevant phase with an actionable diagnostic.
- A missing declared input or a dependency cycle stops the proposal and performs no regeneration.
- A user rejection leaves every artifact unchanged.
- Unsupported existing specs remain outside the mechanism instead of receiving inferred revisions.

## Verification

Focused deterministic tests cover:

1. New pipeline specs create every spec document at revision 1.
2. A plan-only change proposes `tasks -> analyze` and excludes `clarify` and `plan`.
3. A tasks-only change proposes `analyze` only.
4. A spec change proposes the complete downstream path without rerunning `specify`.
5. No replay occurs before explicit confirmation.
6. A second failed analysis stops and requires a fresh user decision.
7. Existing and migration-created specs are unaffected.remplacer
