---
slug: 0019-artifact-analysis-convergence
spec_slug: 0019-artifact-analysis-convergence
created: 2026-08-01
updated: 2026-08-01
---

# Quickstart: Verify Artifact Convergence

## Fresh graph

Create a fixture with `spec.md@2`, `plan.md@3` derived from `spec.md@2`, `tasks.md@1` derived from both, `workflow.md@1`, and independent `analysis.md@1` derived from the three content artifacts plus `validated_workflow` for the ledger's correction state. Then run:

```bash
bash skills/x-artifact-graph/artifact-graph.sh validate --project-root "$fixture" --spec docs/maxi/specs/0001-demo/spec.md --gate implement
```

Expected: exit 0 and one `OK|implement|...|artifact graph valid` line.

## Stale plan replay

Advance only `plan.md` from revision 3 to 4. Run the analyze gate.

Expected: exit 4; `tasks.md` and `analysis.md` are stale, while `spec.md` is current. The earliest correction owner is `plan.md`, so rollback is `clarified`.

## Task-only correction

Record a `revise` event in `workflow.md`, advancing only its revision. Correct `tasks.md` and advance only its revision. Regenerate analysis.

Expected: `spec.md` and `plan.md` revisions do not change; only tasks and analysis are regenerated.

## Failed independent analysis

Set one HIGH finding to `open` and `result: failed`.

Expected: analyze leaves status `tasked`; implement exits 7 even if status is manually changed to `analyzed`.

## Self-review fallback

Set `review_mode: self-review` with no isolated reviewer available.

Expected: report includes `## Independent Review Handoff`, status remains `tasked`, and implementation exits 7.

## Full verification

```bash
bash tests/check-artifact-graph.sh
bash tests/check-analysis-convergence.sh
bash tests/run-all.sh
```

Expected: all three commands exit 0. The integration tier may then be run with `bash tests/run-all.sh --integration` when a supported agent runtime is available.
