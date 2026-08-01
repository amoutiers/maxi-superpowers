---
slug: 0019-artifact-analysis-convergence
spec_slug: 0019-artifact-analysis-convergence
created: 2026-08-01
updated: 2026-08-01
---

# Contract: Artifact Graph Validator CLI

## Invocation

```bash
bash skills/x-artifact-graph/artifact-graph.sh validate \
  --project-root "$PWD" \
  --spec docs/maxi/specs/0019-artifact-analysis-convergence/spec.md \
  --gate analyze
```

Before the status transition, `analyze` validates a completed candidate report with:

```bash
bash skills/x-artifact-graph/artifact-graph.sh validate \
  --project-root "$PWD" \
  --spec docs/maxi/specs/0019-artifact-analysis-convergence/spec.md \
  --gate analyze \
  --candidate-analysis docs/maxi/specs/0019-artifact-analysis-convergence/analysis.md
```

Supported gates: `plan`, `tasks`, `analyze`, `implement`.

The two earlier producers use the same pre-transition pattern:

```bash
bash skills/x-artifact-graph/artifact-graph.sh validate \
  --project-root "$PWD" --spec "$spec" --gate plan --candidate-plan "$plan"
bash skills/x-artifact-graph/artifact-graph.sh validate \
  --project-root "$PWD" --spec "$spec" --gate tasks --candidate-tasks "$tasks"
```

Correction replay validates prepared multi-file output through:

```bash
bash skills/x-artifact-graph/artifact-graph.sh validate \
  --project-root "$PWD" --spec "$spec" --gate analyze \
  --candidate-analysis "$analysis" \
  --overlay-manifest "$spec_dir/.maxi-ops/$operation_id/overlay.tsv"
```

## Gate expectations

| Gate | Required status | Required current artifacts | Additional checks |
|---|---|---|---|
| `plan` | `clarified` | spec, optional legacy workflow; optional completed candidate plan and support set | root constitution marker, ADR references, candidate dependency shape without requiring `planned` status |
| `tasks` | `planned` | spec, plan, plan support artifacts; optional completed candidate tasks | complete graph, root constitution marker, ADR parity, candidate coverage without requiring `tasked` status |
| `analyze` | `tasked` | spec, plan, tasks, workflow defaulting to an empty legacy ledger, support artifacts; optional completed candidate analysis | complete content graph, explicit FR/SC task coverage, canonical correction-state hash, and candidate result/reviewer evidence without requiring `status: analyzed` |
| `implement` | `analyzed` | all analyze inputs plus analysis; optional staged root-spec status projection | independent passing result, current analysis dependencies, current `validated_workflow`, valid dispositions |

## Output

Success writes no files and prints:

```text
OK|analyze|docs/maxi/specs/0019-artifact-analysis-convergence/spec.md|artifact graph valid
```

Failure prints sorted records:

```text
STALE_DEPENDENCY|docs/maxi/specs/0019-artifact-analysis-convergence/tasks.md|tasks.md -> plan.md|expected plan.md@3, found revision 4
```

The first record is the earliest artifact in pipeline order. Callers show the full set but use the first record to choose the correction owner and rollback target.

A missing or older root `validated_against` returns exit 9 with `REVALIDATION_REQUIRED`, not a stale-artifact error. Independently of that mechanical result, every phase caller performs semantic constitution alignment unconditionally against the complete post-write graph immediately before transition. On pass it updates only the exempt root marker and reruns the validator; on conflict it persists `gate-failed` in `workflow.md` and stops without advancing status. A current marker can never bypass the post-write semantic check.

For a legacy derived artifact where both `revision` and `derived_from` are absent, the validator materializes the exact expected dependency set at revision 0 in memory. It performs no write. Mixed presence is exit 3; an expected input above revision 0 is exit 4.

`--candidate-analysis` is valid only with `--gate analyze` and a spec still at `tasked`. It runs every report check used by the implement gate except the post-transition `status: analyzed` requirement. This prevents a circular gate where analysis would need to advance status before validating its own report.

`--candidate-plan` and `--candidate-tasks` are valid only with their matching gate and pre-transition status. They validate the completed candidate artifact and its exact dependencies while omitting only the status that the successful check is intended to authorize. A failed candidate check leaves the current status unchanged. Candidate paths must resolve to the canonical artifact path for the selected spec.

`--overlay-manifest` is optional and valid with any candidate mode or with `--gate implement` for the final staged root-status projection. Each LF-terminated TSV row is `canonical-target<TAB>staged-path<TAB>expected-sha256`. Targets must be unique canonical files under the selected `docs/maxi` graph. Staged paths must resolve under the exact `.maxi-ops/<operation-id>/` directory adjacent to the selected spec and match the declared digest. Validation reads staged bytes wherever the graph references the canonical target but reports only canonical paths. The script rejects hidden paths as graph nodes outside this explicit overlay mechanism and never writes either location. At implement gate, the overlay may change only exempt root frontmatter and must project `status: analyzed`; all other files are read from their committed canonical paths.

## Safety

The script is read-only. It rejects paths escaping `docs/maxi/`, symlink escapes, duplicate edges, cycles, malformed frontmatter, unknown statuses, and unknown gates before semantic review.

Failure records are ordered by explicit correction-owner rank, then normalized artifact path, then code: root spec `10`; plan-owned research/data-model/contracts/quickstart/plan `20`; tasks `30`; analysis `40`; workflow metadata `50`. The rank is internal and is stripped from printed records. The first printed record therefore always selects the earliest correction owner rather than the lexicographically first filename. Multi-owner fixtures must prove that `spec.md` precedes `analysis.md` and that plan-owned support artifacts precede tasks.

At candidate-plan, tasks, analyze, and implement gates, a mismatch between spec-side and plan-side `related_adrs` is exit 6 with `ADR_REPLAN_REQUIRED`. The validator never copies or substitutes an ADR reference.
