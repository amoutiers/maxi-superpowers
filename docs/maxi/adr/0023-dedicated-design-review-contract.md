---
adr: 0023
slug: 0023-dedicated-design-review-contract
status: accepted
created: 2026-08-23
updated: 2026-08-23
decider: "Antoine Moutiers"
supersedes: null
superseded_by: null
---

# ADR-0023: Dedicated Design Review Contract

## Context

The public `/maxi:review` skill reviews the exact current `spec.md` and
`plan.md` before task extraction. It currently delegates this work to
`superpowers:requesting-code-review`, whose reviewer contract expects a
completed implementation, Git SHAs, a Git diff, production readiness, and a
`Ready to merge` verdict.

Those inputs and outputs conflict with the artifact-design boundary established
by [0022-fixed-review-boundaries](0022-fixed-review-boundaries.md). In practice,
the mismatch lets implementation-completeness findings, such as omitted module
registrations or callers, repeatedly reject an otherwise valid design.

The [constitution](../constitution.md) requires delegation to Superpowers when
a matching capability exists, ADR capture for changes to the Maxi-to-Superpowers
relationship, and one responsibility per skill. Superpowers' code-review
capability remains the correct owner of completed-code review, but it does not
provide the artifact-design contract required here.

The corrected
[0020-fixed-review-boundaries/design](../specs/0020-fixed-review-boundaries/design.md)
requires a design reviewer bound to the complete supplied `spec.md` and
`plan.md` pair. Mechanical implementation closure is nonblocking unless it
reveals a requirement, feasibility, architecture, contract, decomposition,
ordering, safety, or verification defect in that reviewed design.

## Decision Drivers

- Preserve Constitution Principle II by retaining Superpowers ownership of
  completed-code task and final implementation reviews.
- Preserve Constitution Principle VI by giving artifact design and completed
  code review separate, single-purpose contracts.
- Keep the three fixed review boundaries and ten-state FSM from ADR-0022
  unchanged.
- Prevent mechanical implementation closure from being misclassified as a
  blocking design defect.

## Considered Options

- **Option A: Retain the Superpowers completed-code reviewer**
  - ✅ Satisfies driver: maximizes direct reuse of an existing Superpowers
    capability.
  - ❌ Violates driver: its Git diff, implementation-completeness, and
    `Ready to merge` contract does not match the artifact-design boundary.
  - ❌ Violates driver: mechanical closure can remain a false design blocker.

- **Option B: Add design-review overrides around the completed-code reviewer**
  - ✅ Satisfies driver: retains the existing delegation entry point.
  - ❌ Violates driver: two conflicting input, severity, and verdict contracts
    remain active in one reviewer.
  - ❌ Violates driver: future upstream code-review changes can silently alter
    Maxi design-review behavior.

- **Option C: Use a dedicated artifact-design reviewer brief**
  - ✅ Satisfies driver: gives the design boundary one input and verdict
    contract.
  - ✅ Satisfies driver: keeps Superpowers code review unchanged for task and
    final implementation review.
  - ✅ Satisfies driver: adds no skill, command, state, ledger, replay, or
    automatic transition.
  - ❌ Requires Maxi to maintain one small supporting reviewer brief and its
    contract tests.

## Decision

Choose **Option C**.

`/maxi:review` owns a dedicated read-only `design-reviewer.md` supporting brief.
The coordinator supplies the complete current `spec.md` and `plan.md`, their
paths and exact SHA-256 values, and applicable constitution requirements.

The reviewer reports complete findings followed by exactly
`VERDICT: approved` or `VERDICT: rejected`. A Critical or Important finding must
name the reviewed design element that needs to change and its blocking basis.

Task `Files` lists identify expected primary edits, not implementation
allowlists. Callers, module declarations, registrations, fixtures, manifests,
generated metadata, and lockfiles are nonblocking when they only implement the
reviewed owning task without adding behavior beyond the reviewed spec and task.
This does not excuse a technically infeasible or materially incorrect design.

The existing exact-byte validation, stale-review rejection, single persisted
review, explicit re-review boundary, three review gates, and ten-state FSM
remain unchanged.

## Consequences

- **Good:** Design review uses inputs, severity rules, and a verdict appropriate
  to artifact design.
- **Good:** Mechanical closure cannot reject a valid plan by itself.
- **Good:** Superpowers retains ownership of task review, fix rounds, and final
  implementation review as established by
  [0021-align-superpowers-v6-3-model](0021-align-superpowers-v6-3-model.md).
- **Good:** The change adds only one supporting brief behind the existing
  `/maxi:review` coordinator.
- **Bad:** Maxi must maintain and test a small reviewer contract that is not
  supplied by upstream Superpowers.
- **Bad:** Changes to the design-blocker predicate require synchronized skill,
  fixture, and pipeline-document updates.

## Confirmation

`tests/check-review-boundaries.sh` verifies the dedicated reviewer wiring,
closed blocking predicate, mechanical-closure rule, exact verdicts, and absence
of the completed-code review contract at the design boundary.

Fresh-agent behavioral samples verify that a mechanical-registration omission
is approved while an architecture-ownership violation is rejected with an
explicit blocking basis.

`bash tests/run-all.sh` and the Mandatory Sync 5 documentation checks must pass
before release.
