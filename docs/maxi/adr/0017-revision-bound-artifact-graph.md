---
adr: 0017
slug: 0017-revision-bound-artifact-graph
status: accepted
created: 2026-08-01
updated: 2026-08-01
decider: "Antoine Moutiers"
supersedes: null
superseded_by: null
---

# ADR-0017: Revision-Bound Artifact Graph with Separate Workflow Validation

## Context

Maxi currently infers artifact currency from pipeline status, file presence, and
human-readable dates. [0002-pipeline-backflow](0002-pipeline-backflow.md)
preserves downstream artifacts after rollback,
but marks them stale only in prose. A later phase can therefore consume an
outdated plan, task list, or analysis when status and content disagree.

The pipeline needs deterministic freshness without rewriting historical
artifacts, making constitution amendments invalidate every completed artifact,
or imposing mutable revision metadata on append-only ADRs. Lifecycle events
also need durable evidence without changing `spec.md` and falsely staling its
content descendants.

## Decision Drivers

- FR-007 through FR-022 require structural revisions, direct dependency
  freshness, legacy revision 0, separate constitution validation, and
  revision-free ADR identity.
- FR-033 and FR-034 require one deterministic contract shared by `plan`,
  `tasks`, `analyze`, and `implement`.
- FR-056 through FR-058 require lifecycle and correction evidence without
  changing unrelated content-artifact revisions.
- Constitution Principle VI requires one owner for graph validation rather
  than duplicated rules in four phase skills.
- [0003-constitution-decoupled-from-claudemd](0003-constitution-decoupled-from-claudemd.md)
  and
  [0012-traceability-direction-spec-to-adr](0012-traceability-direction-spec-to-adr.md)
  require dependency direction to preserve authoritative and immutable artifact
  boundaries.

## Considered Options

- **Option A: Revision-bound DAG plus separate validation edges and workflow ledger**
  Mutable content artifacts carry `revision` and canonical
  `derived_from: path@revision` edges. The root spec carries
  `validated_against`; analysis carries `validated_workflow`; ADRs remain
  revision-free. A read-only internal `x-artifact-graph` skill owns validation.
  - ✅ Satisfies driver: deterministic direct and transitive freshness.
  - ✅ Satisfies driver: legacy artifacts remain virtual revision 0 until an
    owning structural write.
  - ✅ Satisfies driver: constitution, workflow, and ADR checks do not create
    false mutable-content edges.
  - ✅ Satisfies driver: one validation owner under Principle VI.
  - ❌ Adds metadata, one internal skill, a Bash validator, and fixture
    maintenance.

- **Option B: Repeat validation instructions in every phase skill**
  Each of `plan`, `tasks`, `analyze`, and `implement` independently parses and
  validates artifacts.
  - ✅ Smaller initial file count.
  - ❌ Violates driver: one deterministic contract and one responsibility owner.
  - ❌ Creates drift between gates, reproducing the class of pipeline-doc drift
    already observed in this project.

- **Option C: Keep status/date checks and regenerate the full pipeline after change**
  Treat every detected issue as a reset to clarification and rebuild all
  descendants.
  - ✅ No new metadata or parser.
  - ❌ Violates driver: cannot prove freshness.
  - ❌ Violates SC-002 and minimal replay requirements.
  - ❌ Recreates the unbounded analysis loop this feature exists to remove.

## Decision

Choose **Option A**.

Mutable derived artifacts use an exact, closed dependency matrix and canonical
relative `path@revision` entries. Missing `revision` and `derived_from` together
mean a legacy baseline with virtual revision-0 edges; mixed presence is invalid.
The validator rejects missing, extra, duplicate, stale, cyclic, or escaping
edges.

Constitution validation is stored on the active root spec as
`validated_against`. A constitution revision returns
`REVALIDATION_REQUIRED`, not content staleness. ADRs retain immutable full-slug
references and must not carry revision metadata.

Each spec has a revisioned `workflow.md` with distinct lifecycle and correction
sections. Analysis stores a SHA-256 of the correction section only, so a
correction event invalidates the report while park/resume/cancel events do not.

The internal `x-artifact-graph` skill and its read-only Bash script own the
contract. Phase skills delegate to it and may not reimplement graph parsing.

## Consequences

- **Good:** Status alone can no longer make stale artifacts eligible for a
  phase or implementation.
- **Good:** Legacy projects adopt metadata incrementally without bulk rewrites.
- **Good:** Constitution changes trigger semantic revalidation instead of
  mechanical graph invalidation.
- **Good:** ADR append-only identity and spec-side traceability remain intact.
- **Good:** Lifecycle history no longer changes functional spec revisions.
- **Bad:** Maxi-native skill count increases and Mandatory Sync 5 documentation
  must change atomically.
- **Bad:** The canonical Markdown/YAML subset becomes a maintained compatibility
  contract.
- **Bad:** Silent out-of-band edits that do not advance revision remain
  unsupported and cannot be detected by metadata alone.

## Confirmation

- `tests/check-artifact-graph.sh` covers fresh, stale, cyclic, escaping, ADR,
  constitution-revalidation, workflow-hash, and legacy fixtures.
- `tests/check-revision-producers.sh` verifies exact increment and exemption
  rules for every artifact owner.
- `tests/check-workflow-ledger.sh` proves lifecycle-only events do not stale
  content artifacts or analysis correction state.
- `bash tests/run-all.sh` includes all deterministic checks.
- ADR fixtures assert that `revision`, `derived_from`, `validated_against`, and
  `validated_workflow` remain absent from ADR files.
