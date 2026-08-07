---
slug: 0019-artifact-analysis-convergence
spec_slug: 0019-artifact-analysis-convergence
created: 2026-08-01
updated: 2026-08-01
---

# Research: Artifact Revisions and Bounded Analysis Convergence

> **Superseded historical artifact.**
>
> The content below is archival only and does not prescribe active Maxi behavior.
> It does not require creating or writing `workflow.md`, `.maxi-ops`, `workflow-ledger.sh`, or `x-artifact-graph`.
> Active requirements are governed by the current `spec.md`, `plan.md`, and `tasks.md`.

## Scope

This research resolves the technical choices left open by the clarified [spec](spec.md). The implementation remains a Markdown and Bash plugin with no package installation step and must work in every harness supported by Maxi.

## Decision 1: One internal graph-validation skill

### Options considered

1. Repeat validation instructions in `plan`, `tasks`, `analyze`, and `implement`.
2. Add a shared script under the repository-level `scripts/` directory and call it directly from each phase skill.
3. Add one internal `x-artifact-graph` skill containing the contract, deterministic Bash validator, and invocation rules.

### Choice

Choose option 3. A single internal skill gives the validation contract one owner, satisfies Constitution Principle VI, and lets phase skills delegate without duplicating parsing or graph logic. Its script is read-only and returns machine-stable exit codes plus human-readable evidence. This increases the Maxi-native skill count from 18 to 19 and therefore activates the Mandatory Sync 5 rule.

## Decision 2: Canonical dependency serialization

### Options considered

1. Nested YAML mappings such as `{ artifact: spec.md, revision: 3 }`.
2. JSON embedded in YAML.
3. A YAML list of canonical `relative/path.md@REVISION` scalars.

### Choice

Choose option 3:

```yaml
revision: 4
derived_from:
  - spec.md@3
  - research.md@2
```

The path is relative to the artifact carrying the metadata. It must be normalized, must remain inside `docs/maxi/`, must not contain `@`, and must name a mutable Markdown artifact. The revision is a base-10 integer greater than or equal to zero. Zero is valid only when the referenced legacy artifact has no `revision` field. List entries are sorted lexicographically by normalized path and may not repeat a path.

This representation is unambiguous, readable, and parseable with Bash 3.2 plus `awk`, `grep`, and `sed`. It avoids adding a YAML runtime dependency to a multi-harness plugin.

Dependency membership is closed by artifact type rather than left to agent judgment: research depends on spec; data model depends on spec plus research when present; contracts depend on spec plus present research/data model; quickstart and plan depend on spec plus every present support artifact; tasks add plan; analysis adds tasks. The validator rejects both missing and extra mutable edges.

## Decision 3: Constitution and ADR edges remain separate

`validated_against` is a single constitution reference on the active root `spec.md`, in the same `path@revision` form, for example `validated_against: ../../constitution.md@5`. It records the most recent phase-gate alignment but is not treated as proof that a later structural graph is aligned. It is not part of `derived_from`, so a constitution amendment yields `REVALIDATION_REQUIRED` rather than content staleness. Every forward phase reruns semantic alignment unconditionally against the complete post-write graph immediately before transition, replaces the root marker after a pass, and reruns deterministic validation. A real conflict is persisted as a `gate-failed` correction event and blocks.

`related_adrs` remains a list of full immutable ADR slugs. The validator checks existence and `status: accepted`; it reports a declared successor but never substitutes one. ADR files must reject `revision`, `derived_from`, and `validated_against` fields.

## Decision 4: Workflow events use a separate ledger

Lifecycle events currently append text to `spec.md`. Under structural revisions, parking, resuming, cancelling, or rolling back would therefore advance the spec revision and stale descendants even when no requirement changed.

Add `workflow.md` beside each spec. It is a mutable, revisioned source artifact with no `derived_from` field. It records ordered lifecycle and correction-cycle events. Content artifacts do not depend on its revision. `analysis.md` records `validated_workflow`, a SHA-256 of the canonical correction events only, because correction-cycle limits affect the result while unrelated park, resume, and cancel events do not.

The ledger has two exact body markers: `## Lifecycle Events` followed by `## Correction Cycles`. Lifecycle writers insert only before the correction marker; correction writers append only after it. The correction-state digest is SHA-256 over the UTF-8 bytes from the `## Correction Cycles` line through the final normalized LF. The empty legacy state uses the same bytes as an empty template correction section, so no YAML or prose normalization is inferred.

New specs create the ledger at revision 1. Legacy absence means an empty revision-0 ledger and is not migrated in bulk. The first governed event creates revision 1.

## Decision 5: Deterministic coverage is explicit

Every implementation task line uses a terminal coverage clause:

```markdown
- [ ] T012 [US1] Implement the gate in `skills/analyze/SKILL.md` (covers: FR-004, FR-005, SC-001)
```

The validator extracts only IDs from `(covers: ...)`. Mentions elsewhere are informative and do not count. Every FR and SC is coverage-required by default. A spec may exempt a non-build success criterion only by adding an inline marker with a non-empty reason:

```markdown
- **SC-NNN**: Measure adoption after release. <!-- maxi:coverage-exempt reason="post-release outcome" -->
```

This makes build relevance deterministic and prevents keyword inference from masquerading as evidence.

## Decision 6: Independent semantic review is fail-closed

`analyze` remains the coordinator and sole writer of `analysis.md`. It performs deterministic validation first by invoking `x-artifact-graph`. Only after that passes does it create a reviewer packet.

- When the harness can create an isolated reviewer context, the coordinator dispatches the packet to a reviewer that did not author or correct the artifacts.
- When isolation is unavailable, the current context may produce a `self-review` report, but the result is provisional, status remains `tasked`, and the report contains a copyable handoff packet for another session.
- A separate-session reviewer returns a structured finding response and explicit independence declaration without writing any project file. An authoring coordinator persists that response in `analysis.md`. If review fails, correction occurs in an authoring context, then the same read-only reviewer session may be resumed for the second pass. The declaration is workflow evidence, not cryptographic proof.

The coordinator owns finding reconciliation and file writes. The reviewer returns findings only. This preserves one writer while making the semantic judgment independent.

## Decision 7: Stable finding registry and bounded correction

`analysis.md` contains a registry table with never-recycled `FNNN` IDs. Each finding also carries a stable fingerprint based on category, owner, and normalized meaning. Exact fingerprint matches are automatic; semantic equivalence after a location or wording change must be declared by the independent reviewer. New IDs start at one greater than the largest ID ever present.

`workflow.md` records correction-cycle authorization and consumption. A failed independent analysis may propose one batch with the earliest owner, rollback status, affected findings, and stale descendants. Explicit user consent records `correction-authorized`; the relevant phase chain consumes it exactly once. A second failed independent analysis stops. A new direct user decision authorizes at most one further cycle.

Add a second internal coordinator, `x-converge`, for this one bounded goal. `analyze` owns the report and proposal, `revise` owns rollback plus workflow events, and the phase skills own their artifacts. `x-converge` is the missing orchestration owner that carries one explicit confirmation through `revise -> owning producer -> descendants -> analyze`, resumes the same authorized cycle after interruption, and never interprets internal continuation as new consent.

`x-converge` runs only in an authoring/coordinator context. An `analyze` session with `review_origin: separate-session` must hand the proposal back instead of invoking it, otherwise that reviewer would become a corrector and could not remain independent on the preferred second pass.

Lifecycle and correction execution use a write-ahead operation journal under the spec directory, separate from the semantic bytes in `workflow.md`. Each phase has a stable operation ID, and only the revise-owned resource writes the semantic ledger or `.maxi-ops` journal. `correction-consumed` is appended to the semantic ledger before the first rollback mutation. Before a phase changes any project file, its owner stages the complete output set, validates it through a canonical-path overlay, hashes every before/after state, and persists one manifest. Each individual file is replaced atomically and acknowledged in the external journal. On resume, an exact before-state plus matching staged output executes once, an exact expected after-state is acknowledged without regeneration, and every other state records `recovery-conflict` and stops. Pre-analysis phase completion is a semantic workflow event; final analysis completion is journal-only so the report never hashes an event that depends on the report itself.

An ADR accepted after planning is first linked from the spec by `x-adr`, but forward gates require the plan's ADR set to match the spec's. `implement` stops immediately on a new decision and routes control through `revise` to the plan owner. Incorporating the ADR is structural plan work, so plan revision advances and tasks plus independent analysis replay before implementation can resume.

## Decision 8: Rollback mapping

The deterministic owner-to-status map is:

| Earliest owner | Rollback status | First producer replayed |
|---|---|---|
| `spec.md` | `specified` | `clarify` |
| `plan.md`, `research.md`, `data-model.md`, `contracts/*.md` | `clarified` | `plan` |
| `tasks.md` | `planned` | `tasks` |
| `analysis.md` | `tasked` | `analyze` |

Supporting technical artifacts are owned by `plan`. `workflow.md` is never a content-defect owner; invalid workflow metadata is repaired by `revise` without rolling content artifacts backward.

## Decision 9: Legacy and terminal artifacts

Missing revision metadata means revision 0 and causes no write. The next owning-skill structural write adds revision 1. `done` and `cancelled` specs remain historical and are not revalidated solely because the constitution or schema changed. Migration utilities continue to create revision-free historical ingress artifacts; forward work adopts revision metadata only when a governed owner modifies an artifact.

For a legacy derived artifact, absence of both `revision` and `derived_from` means a virtual dependency set at revision 0 using the exact artifact-type matrix. It is current only while every expected direct input is also revision 0. If any expected input is revision 1 or later, the legacy dependent is stale. A present `revision` with missing `derived_from`, or present `derived_from` with missing `revision`, is malformed rather than legacy.

Migration ingress remains explicit: brownfield and done spec-kit imports are historical and require no validation. Active `specified`, `planned`, or `tasked` spec-kit imports use the virtual revision-0 graph. A legacy task list without explicit FR/SC evidence fails only the tasks/analysis coverage gate and rolls back to `planned` for task regeneration; it does not restart clarification or planning.

## ADR outcome

The post-plan scan produced two accepted records: [0017-revision-bound-artifact-graph](../../adr/0017-revision-bound-artifact-graph.md) for the graph/ledger decision and [0018-independent-analysis-bounded-convergence](../../adr/0018-independent-analysis-bounded-convergence.md) for read-only independent analysis, external `.maxi-ops` recovery, canonical staged overlays, the two-operation final analysis transition, and mandatory plan/spec ADR parity. The latter supersedes [0002-pipeline-backflow](../../adr/0002-pipeline-backflow.md).
