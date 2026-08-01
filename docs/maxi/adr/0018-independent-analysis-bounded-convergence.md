---
adr: 0018
slug: 0018-independent-analysis-bounded-convergence
status: accepted
created: 2026-08-01
updated: 2026-08-01
decider: "Antoine Moutiers"
supersedes: 0002
superseded_by: null
---

# ADR-0018: Independent Read-Only Analysis with Crash-Safe Bounded Convergence

## Context

Maxi's current `analyze` phase performs seven audit passes, writes
`analysis.md`, then advances a tasked spec to `analyzed` regardless of whether
blocking findings remain. `implement` trusts that status instead of validating
the report and its inputs.

[0002-pipeline-backflow](0002-pipeline-backflow.md) introduced explicit
pipeline backflow through `revise`, but it cannot return to `specified`, records
staleness only in prose, and leaves replay to manual agent continuation. A later
review can therefore restart analysis from the beginning, regenerate unaffected
artifacts, or continue correcting without a bounded user authorization.

The workflow requires a final semantic reviewer that is independent from
artifact authors, stable evidence across reruns, and one explicit correction
cycle whose state survives interruptions. Reviewer independence must also
survive reuse: a reviewer returns findings but never writes a project artifact
that it could inspect on the next pass.

Cross-file correction introduces a second risk. A crash between ledger, status,
and content writes can rerun a producer or increment revisions twice. Technical
write-ahead evidence cannot live inside the semantic workflow bytes hashed by
`analysis.md`, because the expected analysis hash and workflow hash would then
depend on each other.

Finally, an ADR accepted after planning must not become an exempt backlink that
allows stale plan, tasks, and analysis artifacts to remain implementation-ready.

## Decision Drivers

- FR-004 through FR-006 and FR-047 through FR-052 require implementation to
  depend on a current independent passing analysis rather than status alone.
- FR-023 through FR-032 require earliest-owner rollback, correction of original
  spec gaps, one explicit batch confirmation, and minimal descendant replay.
- FR-037 through FR-046 and FR-059 through FR-060 require deterministic
  validation, actual reviewer separation, stable findings, and integrity
  evidence for the reviewed semantic set.
- FR-048 through FR-051 require a hard stop after one correction and
  re-analysis cycle unless the user makes a new direct decision.
- FR-061 and SC-011 require idempotent recovery at every cross-file write
  boundary without duplicate revisions or phase execution.
- FR-062 and SC-012 require post-plan architectural decisions to force plan,
  tasks, and analysis replay before implementation.
- Constitution Principles III, V, and VI require fail-closed phase enforcement,
  persisted state outside chat, and one owner for each responsibility.
- [0012-traceability-direction-spec-to-adr](0012-traceability-direction-spec-to-adr.md)
  makes spec-side ADR references canonical.

## Considered Options

- **Option A: Read-only independent review with external crash-safe convergence**
  `analyze` validates deterministically, obtains findings from a read-only
  isolated reviewer or separate-session handoff, and remains the sole writer of
  `analysis.md`. A persisted coordinator runs one consented correction cycle.
  Semantic workflow events remain in `workflow.md`; technical write-ahead state
  lives in `.maxi-ops` and staged graphs validate through canonical overlays.
  - ✅ Satisfies driver: implementation cannot enter from stale, failed,
    self-reviewed, or absent evidence.
  - ✅ Satisfies driver: the same independent reviewer can be reused without
    becoming an artifact author or corrector.
  - ✅ Satisfies driver: one user decision authorizes one bounded correction
    goal whose state survives interruption.
  - ✅ Satisfies driver: prepared writes recover exactly once without creating
    a circular workflow/report hash.
  - ✅ Satisfies driver: post-plan ADRs force structural replanning.
  - ❌ Adds reviewer handoff, stable finding, staged-overlay, operation-journal,
    ADR-parity, and coordinator contracts.
  - ❌ Runtimes without reviewer isolation cannot automatically reach
    `analyzed` in one session.

- **Option B: Independent review with semantic and technical state in one ledger**
  Require independent review and persist write-ahead events directly in
  `workflow.md`.
  - ✅ Satisfies driver: review judgment is independent.
  - ✅ Keeps all state in one visible file.
  - ❌ Violates driver: staged analysis would hash workflow data containing its
    own expected output hash.
  - ❌ A completion event written after analysis would immediately stale the
    report.
  - ❌ Manual replay remains vulnerable to duplicate phase execution.

- **Option C: Reviewer-authored reports with repeated automatic correction**
  Let a separate-session reviewer write `analysis.md` and keep correcting until
  clean.
  - ✅ Lowest orchestration cost.
  - ❌ Violates driver: a reused reviewer authored an artifact in its next
    review packet.
  - ❌ Violates driver: there is no hard convergence bound.
  - ❌ Reproduces the clarify, regenerate, and re-analyze loop this decision
    exists to prevent.

## Decision

Choose **Option A** and supersede
[0002-pipeline-backflow](0002-pipeline-backflow.md).

`analyze` first invokes the shared deterministic artifact validator. If that
fails, it writes `result: failed` with `review_mode: not-run`, performs no
semantic review, and leaves status `tasked`.

Semantic review runs in a context that did not author or correct the current
artifacts. The reviewer receives an immutable packet and returns only a
canonical finding set, reconciliation declarations, recommendations, and an
independence declaration. It performs no project writes, corrections, status
transitions, or workflow operations. When isolation is unavailable, self-review
is provisional and produces a complete separate-session handoff.

The authoring `analyze` coordinator verifies the response, reconciles stable
finding identities, and is the sole writer of `analysis.md`. Correction always
returns to an authoring context. The same read-only independent reviewer is
preferred for the second pass; another independent reviewer may reconcile the
registry when reuse is unavailable.

Findings retain never-recycled `FNNN` identities. A canonical hash covers the
reviewer-owned semantic fields. Disposition-only changes may retain evidence
only while that block is byte-identical. CRITICAL and HIGH findings block.
MEDIUM and LOW findings require resolution, accepted rationale, or an active
follow-up spec. Constitution findings are never waivable.

Only current independent `pass-clean` and `pass-with-exceptions` reports permit
`tasked -> analyzed`. `implement` repeats evidence, freshness, constitution,
ADR-parity, and disposition checks before `implementing`.

After a first failed independent review, the complete finding inventory selects
one earliest owner and rollback target:

- `spec.md` -> `specified`
- plan or technical support artifact -> `clarified`
- `tasks.md` -> `planned`
- `analysis.md` -> `tasked`

The internal `x-converge` coordinator shows the complete correction batch and
accepts one explicit user confirmation. It coordinates `revise`, the owning
producer, every stale descendant, and one complete independent re-analysis. A
second failed independent analysis stops. Each later direct user decision can
authorize at most one additional cycle.

`workflow.md` contains semantic lifecycle and correction events only. Technical
write-ahead mechanics live in `<spec-dir>/.maxi-ops/<operation-id>/`, outside
the bytes covered by `validated_workflow`. The revise-owned
`workflow-ledger.sh` resource is the only writer of the semantic ledger and
operation journals.

Before a multi-file mutation, the owning phase stages its complete output set,
records exact before and expected after hashes and revisions, and validates the
staged graph through a canonical-path overlay. Each file is replaced atomically
and acknowledged. Recovery applies an untouched prepared output once,
acknowledges an exact completed output without rewriting it, or stops on any
conflicting state.

Final analysis uses two stable operations. The first writes and validates the
candidate report while the canonical spec remains `tasked`. The second projects
`status: analyzed`, runs the implementation gate against that projection, and
atomically applies the status-only spec update. No semantic workflow event is
written after the report; technical completion in `.maxi-ops` cannot stale it.

Per
[0012-traceability-direction-spec-to-adr](0012-traceability-direction-spec-to-adr.md),
`spec.md.related_adrs` remains canonical. `plan.md.related_adrs` is a derived
parity snapshot proving that the current plan incorporated every canonical
decision. Candidate-plan, tasks, analyze, and implement gates require equality.
An ADR accepted after planning stops forward work until the plan owner
incorporates it structurally, increments plan revision, and replays tasks plus
independent analysis.

This preserves the core principle of explicit, non-destructive backflow from
[0002-pipeline-backflow](0002-pipeline-backflow.md), but replaces its rollback
range, prose-only staleness, manual continuation, and unbounded recovery model.

## Consequences

- **Good:** A failed or provisional analysis cannot make a spec
  implementation-ready.
- **Good:** Independent reviewers never author an artifact they may later
  reassess.
- **Good:** Reviewer evidence, findings, dispositions, consent, and replay state
  persist outside chat.
- **Good:** A real gap discovered downstream is repaired in the original spec.
- **Good:** Correction replays only the owning producer and stale descendants.
- **Good:** Automatic convergence has a hard one-cycle bound.
- **Good:** Interrupted operations cannot silently duplicate artifact writes or
  revision increments.
- **Good:** Semantic workflow hashes remain non-circular and stable after final
  analysis.
- **Good:** Architectural decisions discovered during implementation cannot
  bypass planning and analysis freshness.
- **Bad:** Independent review may require a second session on runtimes without
  isolated reviewer contexts.
- **Bad:** A clean self-review is insufficient to open implementation.
- **Bad:** Two internal skills, one validator, one workflow transaction resource,
  and `.maxi-ops` increase Maxi's protocol surface.
- **Bad:** Recovery stops for manual repair when state matches neither the
  prepared before-state nor expected after-state.

## Confirmation

- `tests/check-artifact-graph.sh` covers fresh and stale graphs, owner-ranked
  failures, ADR parity, canonical staged overlays, path confinement, digest
  mismatch, and forged implementation status.
- `tests/check-analysis-convergence.sh` covers result calculation, review modes,
  read-only reviewer separation, finding integrity, stable IDs, dispositions,
  classification disagreements, and second-failure reporting.
- `tests/check-workflow-ledger.sh` covers idempotency-key reuse and interruption
  at authorization, consumption, preparation, replacement, acknowledgement,
  and completion boundaries.
- `tests/check-convergence-coordinator.sh` covers one confirmation, exact replay
  chains, interruption resume, and the second-failure stop.
- Invalid analysis fixtures remain blocked even when spec status is manually
  forged to `analyzed`.
- Post-plan ADR fixtures remain blocked until plan, tasks, and independent
  analysis are current.
- `bash tests/run-all.sh` remains the mandatory deterministic gate.
