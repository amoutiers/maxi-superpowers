---
slug: 0019-artifact-analysis-convergence
spec_slug: 0019-artifact-analysis-convergence
created: 2026-08-01
updated: 2026-08-01
---

# Contract: Mutable Artifact Metadata

## Canonical frontmatter

```yaml
revision: 3
derived_from:
  - contracts/error-contract.md@2
  - research.md@1
  - spec.md@4
validated_workflow: sha256:8d969eef6ecad3c29a3a629280e686cff8ca4a9cbf2848e95c15d07e4dcfd51
```

The example is an `analysis.md` fragment. The active root `spec.md` instead has no `derived_from` or `validated_workflow` and carries `validated_against: ../../constitution.md@2`.

Rules:

1. `revision` is a positive base-10 integer when present. Absence means legacy revision 0.
2. Each dependency is `<normalized-relative-path>@<revision>` and resolves inside `docs/maxi/`.
3. Dependency entries are sorted by path, unique, and name every direct mutable input.
4. A referenced revision must equal the target artifact's current revision, interpreting missing target metadata as zero.
5. `validated_against` appears on the active root spec, points only to `docs/maxi/constitution.md`, and is refreshed only after a successful whole-graph alignment check. Every forward transition repeats that semantic check unconditionally against its complete post-write graph, even when the stored constitution revision is already current.
6. ADRs never contain these fields. ADR identity remains a full slug in `related_adrs`.
7. Operational-only writes do not increment structural revision. Mixed writes increment exactly once.
8. `validated_workflow` is analysis-only and hashes exact bytes from the unique `## Correction Cycles` marker through one final LF; it is not a `derived_from` edge to the whole workflow ledger.
9. A legacy derived artifact has neither `revision` nor `derived_from`; validation supplies the exact expected dependency set at revision 0. Mixed presence is invalid, and any positive-revision input makes the legacy dependent stale.

## Direct inputs by artifact

| Artifact | Required direct mutable inputs |
|---|---|
| `spec.md` | none |
| `workflow.md` | none |
| `research.md` | `spec.md` |
| `data-model.md` | `spec.md` and `research.md` when research exists |
| `contracts/*.md` | `spec.md`, `research.md` when present, and `data-model.md` when present |
| `quickstart.md` | `spec.md` and every present research/data-model/contract artifact |
| `plan.md` | `spec.md` and every present research/data-model/contract/quickstart artifact |
| `tasks.md` | `spec.md`, `plan.md`, and every present plan support artifact |
| `analysis.md` | `spec.md`, `plan.md`, `tasks.md`, and every present plan support artifact; correction state is separate in `validated_workflow` |

These sets are exact, not advisory. The validator rejects missing and extra mutable dependency edges, so an agent cannot avoid staleness by claiming it did not consult a present support artifact.

Per ADR-0012, `spec.md.related_adrs` remains the canonical spec-to-ADR traceability list. `plan.md.related_adrs` is a derived parity snapshot used only to prove that the current plan incorporated every canonical decision. At the tasks, analyze, and implement gates, that snapshot must equal the spec list. An ADR accepted after planning therefore blocks until the plan owner incorporates the decision structurally; updating only the exempt spec backlink never refreshes plan, tasks, or analysis.

## Structural write examples

| Write | Increment? |
|---|---|
| Replace an FR, plan decision, task description, finding state, or workflow event body | yes |
| Add or remove a dependency | yes |
| Set `status`, `parked_from`, `updated`, `related_adrs`, `validated_against`, or `validated_workflow` only | no |
| Tick or untick a task checkbox only | no |
| Change an ADR body | forbidden; supersede with a new ADR |
