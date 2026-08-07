# Specification Analysis Report

Generated: 2026-08-06
Spec: [spec](spec.md) (status at analysis start: `planned`)
Plan: [plan](plan.md) revision 21
Review mode: `independent`
Result: `pass-clean`

## Audit Boundary

This fresh seven-pass audit covers the current [spec](spec.md), [plan](plan.md), regenerated [tasks](tasks.md), [constitution](../../constitution.md), and the two accepted related ADRs. The pre-existing `research.md`, `data-model.md`, `contracts/`, and `quickstart.md` describe the superseded 0019 scope and are not inputs to this analysis.

Spec 0019 predates the future-forward mechanism it defines. Its own missing `replay_contract: bounded-v1` marker and missing spec/plan review records are therefore expected compatibility evidence, not findings. Revision 21 explicitly requires the actual unmarked 0019 directory to remain `UNSUPPORTED_LEGACY` without writes.

## Findings

No open issues found.

## Resolved Finding Registry

| ID | Prior Severity | State | Resolution Evidence |
|---|---|---|---|
| F0001 | HIGH | resolved | T008 specifies and tests the durable `clarify -> spec review -> plan -> plan review -> tasks` continuation, including persisted source/subject markers, no-write re-presentation after rejection or interruption, and fresh literal consent at each executable segment. |
| F0002 | HIGH | resolved | T008 requires plan-review resume to validate the current plan subject and every transitive ancestor, with separate stale fixtures for `spec.md`, `research.md`, `data-model.md`, one contract, and `reviews/spec-review.md`; failure occurs before continuation output or writes. |
| F0003 | HIGH | resolved | T007 makes the exact `replay_contract: bounded-v1` marker, written only by future `/maxi:specify`, the sole eligibility signal. Revision-bearing unmarked 0019 and all migration/reverse-engineering ingress remain unsupported, and duplicate or wrong markers fail as malformed. |
| F0004 | HIGH | resolved | The global contract and T007 define one structural `reviewed_sha256` projection shared by `x-review`, the planner, `plan`, and `tasks`; only top-level `status:` and `updated:` are excluded, with positive non-structural and negative structural mutation fixtures. |
| F0005 | HIGH | resolved | T007 defines the exact ten-field x-review envelope and exhaustive validation in both normal owner gates before delegation or any artifact/status/timestamp write; T008 revalidates that full envelope and ancestry at presentation and immediately before an approved owner write. |
| F0006 | HIGH | resolved | T007 tightens the existing frontmatter parser so list entries are legal only in the active `structural_contributors` or `derived_from` block, and adds normal-document plus review-record cases for stray items after scalars and after an ended list, all required to exit 2 before proposal output. |
| F0007 | HIGH | resolved | The ordinary marker-bound plan-review post-write path now validates current plan ancestry before any proposal record when the review itself is current. Five regressions independently stale `spec.md`, `research.md`, `data-model.md`, one contract, or `reviews/spec-review.md`; each exits 2 without `CHANGED`, `STALE`, `CONTINUATION`, `REPLAY`, or `REVIEW_REQUIRED` output. |
| F0008 | HIGH | resolved | `analyze` and `implement` now activate their future-only revision, provenance, and independent-analysis contracts only for exactly one `replay_contract: bounded-v1` root marker. Revision metadata alone does not opt in the actual revision-bearing, unmarked 0019 spec, and duplicate or non-exact markers remain malformed. |
| F0009 | MEDIUM | resolved | The `plan` and `tasks` rows in both `skills/using-maxi/SKILL.md` and `docs/delegation-map.md` now qualify their current approved review prerequisites as marker-bound, matching the owner skills and future-only boundary. |

## Seven-Pass Results

| Pass | Result | Evidence |
|---|---|---|
| A. Duplication | Pass | FR-001 through FR-023 and SC-001 through SC-009 remain distinct; T007 and T008 divide metadata/review strictness from continuation/ancestry without duplicating ownership. |
| B. Ambiguity | Pass | Revision 21 defines the exact eligibility marker, structural digest bytes, ten review fields and invariants, legal resume combinations, stale-ancestor set, exit behavior, consent token, and phase sequence. |
| C. Underspecification | Pass | T007 and T008 name exact files, RED cases, expected failures, implementation constraints, GREEN commands, and independent review gates; T009 names the synchronized docs, final commands, review base, and staging boundary. |
| D. Constitution Alignment | Pass | The full forward pipeline remains intact, Superpowers authoring/review delegation is retained, accepted ADRs cover both consequential decisions, artifact ownership stays separated, and no FSM status is added. |
| E. Coverage | Pass | The plan has one non-empty row for each of 32 requirements. T007-T009 and the final corrective batch collectively cover all nine repaired findings, and all nine tasks map to setup, behavior, correction, or final synchronization. |
| F. Consistency | Pass | Spec revision 7, plan revision 21, regenerated T007-T009, and the final corrective batch agree on exact-marker future-only eligibility, non-retroactive 0019 behavior, structural digests, full review validation, persisted two-review continuation, stale-ancestor rejection on resume and ordinary post-write paths, unchanged FSM, and Mandatory Sync 5. |
| G. ADR Alignment | Pass | Both related ADRs are accepted and current. The marker is a concrete enforcement of ADR-0019's future-only boundary, while persisted review handoffs and the unchanged FSM implement ADR-0020. No cycle or constitution conflict was found. |

## Coverage Summary

| Requirement | Has Task? | Task IDs | Notes |
|---|---|---|---|
| FR-001 | Yes | T003, T007 | Future-only eligibility is made explicit by the marker. |
| FR-002 | Yes | T001, T003, T004 | Revision initialization covers documents and review records. |
| FR-003 | Yes | T003, T004, T007, T008 | Structural revisions and continuation-marker owner writes are explicit. |
| FR-004 | Yes | T003, T004, T007 | Direct-input metadata and exact review-envelope mappings are validated. |
| FR-005 | Yes | T001, T005, T007, T008 | Direct, transitive, and resume-time ancestry freshness are covered. |
| FR-006 | Yes | T005, T008 | The earliest producer and bounded continuation survive both reviews. |
| FR-007 | Yes | T005, T006, T008 | Proposal and resumed continuation records are explicit. |
| FR-008 | Yes | T006, T008 | Each executable segment requires a fresh literal `yes`. |
| FR-009 | Yes | T006, T008 | Rejection, ambiguity, and interruption preserve bytes and allow re-presentation. |
| FR-010 | Yes | T006 | Failed re-analysis starts no automatic replay. |
| FR-011 | Yes | T005, T006, T008 | Source-spec replay resumes at `clarify`, never `specify`. |
| FR-012 | Yes | T003, T007 | Existing and ingress specs remain unmarked and unsupported. |
| FR-013 | Yes | T001, T005, T007, T008 | Graph, marker, parser, review, resume, and ancestry failures close before writes. |
| FR-014 | Yes | T006, T008, T009 | The ten-state FSM remains unchanged and synchronized. |
| FR-015 | Yes | T005, T006, T008 | Owners write; the existing planner only validates and presents. |
| FR-016 | Yes | T006, T008 | Exceptional source rollback persists and resumes `clarify`. |
| FR-017 | Yes | T003, T004, T007 | Structural contributor provenance participates in the exact envelope and digest. |
| FR-018 | Yes | T004, T006, T007, T008 | Spec review is fully validated before planning and on every resume. |
| FR-019 | Yes | T004, T006, T007, T008 | Plan review is fully validated before tasks and on every resume. |
| FR-020 | Yes | T006 | Independent analysis evidence remains the implementation gate. |
| FR-021 | Yes | T004, T006, T007, T008 | Invalid review evidence blocks only the successor before any write. |
| FR-022 | Yes | T004, T005, T007, T008 | Review records are versioned, structurally hashed, and ancestry-checked. |
| FR-023 | Yes | T004, T005, T006, T008 | Replay never creates reviews and requires renewed consent after each handoff. |
| SC-001 | Yes | T001, T003, T004, T007 | Future document initialization is tested without retrofitting 0019. |
| SC-002 | Yes | T001, T005, T008 | Exact stale descendants and review-boundary stops are tested. |
| SC-003 | Yes | T001, T005, T006, T008 | Literal consent, no-write behavior, and re-presentation are tested. |
| SC-004 | Yes | T001, T005, T008 | Replay excludes unaffected ancestors and rejects stale required ancestors. |
| SC-005 | Yes | T006 | A failed analysis requires a new user decision. |
| SC-006 | Yes | T003, T007 | Legacy, migration, reverse-engineered, and pre-mechanism 0019 cases remain excluded. |
| SC-007 | Yes | T004, T006, T007, T008 | Both owner gates enforce complete current review evidence before writes. |
| SC-008 | Yes | T004, T005, T007, T008 | Contributor independence, structural digest invalidation, and ancestry are covered. |
| SC-009 | Yes | T006 | Independent final analysis evidence remains required before implementation. |

## Constitution Alignment Issues

None found. The plan preserves every mandatory phase, delegates skill authoring and independent review to Superpowers, keeps accepted ADRs append-only, assigns each write and validation responsibility to one owner, retains Bash 3.2 compatibility, and reserves Mandatory Sync 5 plus the complete fast tier for T009.

## ADR Alignment Issues

None found. [0019-bounded-forward-artifact-replay](../../adr/0019-bounded-forward-artifact-replay.md) governs future-only revisions and read-only bounded replay. [0020-persisted-independent-handoff-reviews](../../adr/0020-persisted-independent-handoff-reviews.md) governs x-review-owned handoff records with the unchanged FSM. Both are accepted and neither has a stale or cyclic supersession reference.

## Unmapped Tasks

None found. T001-T002 establish deterministic infrastructure; T003-T006 are completed historical implementation milestones; T007 owns findings F0003-F0006; T008 owns findings F0001-F0002, F0007, and revalidates F0005; the corrected Task 6 gates resolve F0008; T009 synchronizes F0009 and independently reviews the complete atomic final change set.

## Metrics

- Total Requirements (FR + SC): 32
- Total Tasks: 9
- Coverage: 100% (32/32)
- Audited Repair Findings: 9
- Resolved Repair Findings: 9
- Open Findings: 0
- Ambiguity Count: 0
- Duplication Count: 0
- Critical Issues Count: 0
- High Issues Count: 0
- Medium Issues Count: 0
- Low Issues Count: 0
- ADRs Recorded: 2 accepted

## Next Actions

The final corrective batch is GREEN on `check-bounded-replay.sh`, `check-x-review.sh`, `check-templates.sh`, `check-frontmatter.sh`, `check-skill-count.sh`, `check-status-consistency.sh`, and `check-version-consistency.sh`; Bash syntax and `git diff --check` also pass. No integration or full-suite result is claimed. Independent analysis remains `pass-clean`. Resume sequentially at T007, then T008, then T009. Keep 0019 unmarked and do not require future review records for this pre-mechanism spec. Each task retains its RED/GREEN and independent review checkpoint; T009 performs Mandatory Sync 5, the complete deterministic suite, document consistency, and a whole-feature review of all nine repairs before any request to stage or commit.
