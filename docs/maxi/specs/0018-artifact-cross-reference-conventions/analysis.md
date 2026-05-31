# Specification Analysis Report

Generated: 2026-05-31 (re-run after /maxi:revise applied findings E1 + C1)
Spec: docs/maxi/specs/0018-artifact-cross-reference-conventions/spec.md (status: tasked)

## Findings

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| B1 | Ambiguity | LOW | spec.md FR-009; plan.md Task 7 | "consequential technology choice" is an unmeasurable qualifier. | No action — inherited verbatim from existing `analyze` G1 wording; out of scope to redefine. Noted for awareness. |
| E2 | Coverage (informational) | LOW | spec.md FR-016 | FR-016 (capture correction ADR during `/maxi:plan`) has no task — already satisfied at plan time (`0012-traceability-direction-spec-to-adr`, `accepted`). | None — recorded so "no task" reads as already-done, not missing. |

> **Prior-run findings now resolved:**
> - **C1 (was MEDIUM)** — SC-003 reworded to an explicit manual acceptance check; the buildable-fixture implication is gone, coverage is honest.
> - **E1 (was MEDIUM)** — **FR-022** added (ADR index column rebuilt by spec-side reverse-lookup); tasks T007 + T010 now map to it.

## Coverage Summary

| Requirement | Has Task? | Task IDs | Notes |
|-------------|-----------|----------|-------|
| FR-001 | ✅ | T002 | ADR template loses 3 fields |
| FR-002 | ✅ | T003 | spec template gains related_adrs |
| FR-003 | ✅ | T003 | specify initializes related_adrs |
| FR-004 | ✅ | T005 | x-adr writes spec back-link |
| FR-005 | ✅ | T004 | x-adr stops writing fields |
| FR-006 | ✅ | T004 | drivers cite prose, not fields |
| FR-007 | ✅ | T011 | migrate-adr stops emitting fields |
| FR-008 | ✅ | T006 | analyze registry spec-side |
| FR-009 | ✅ | T006 | G1 reformulated |
| FR-010 | ✅ | T006 | G3 preserved |
| FR-011 | ✅ | T008 | strip 11 ADRs (+0012) |
| FR-012 | ✅ | T009 | back-links onto 6 specs |
| FR-013 | ✅ | T008 | ADR bodies untouched |
| FR-014 | ✅ | T002, T003 | check-templates + fixture |
| FR-015 | ✅ | T012, T013 | supersession notes + drop guard |
| FR-016 | ✅ (plan-time) | — (ADR-0012) | satisfied during /maxi:plan; see E2 |
| FR-017 | ✅ | T015 | doc-sync CLAUDE.md + architecture.md |
| FR-018 | ✅ | T014 | link convention in 12 skills |
| FR-019 | ✅ | T014 | exemptions in the block |
| FR-020 | ✅ | T014, T016 | guidance-only; spot-check |
| FR-021 | ✅ | T014 | forward-only stated in block |
| FR-022 | ✅ | T007, T010 | ADR index reverse-lookup (added this revision) |
| SC-001 | ✅ | T016 | zero removed-field grep |
| SC-002 | ✅ | T016 | 6 links preserved |
| SC-003 | ✅ | T016 | manual acceptance check (reworded) |
| SC-004 | ✅ | T016 (+all) | suite green each commit |
| SC-005 | ✅ | T016 | link block in 12 skills |

## Constitution Alignment Issues

None found. All six principles + constraints clear (unchanged from prior run): delegate-not-duplicate ✅, ADR captured (0012) ✅, single-responsibility (two axes unified) ✅, strict vendoring (all 12 touched skills maxi-native) ✅, authoring-via-writing-skills (tasks tagged `[writing-skills]`) ✅, English-only / fast-tier-green ✅.

## ADR Alignment Issues

ADRs recorded: 12. Pass G ran fully.
- **G1:** the one consequential choice (traceability inversion) is recorded as `0012-traceability-direction-spec-to-adr`, linked to this spec. No missing ADR.
- **G2:** ADR-0012 aligns with ADR-0003 + constitution; no contradiction.
- **G3:** referenced ADRs (0003, 0012) are both `accepted`; no stale references.
- **G4:** ADR-0012 `supersedes: null`; no cycle.

None found.

## Unmapped Tasks

- T001 (baseline) and T016 (verification) are Setup/Polish — no story label by design.
- All other tasks map to a requirement (T007/T010 now → FR-022).
- None unmapped.

## Metrics

- Total Requirements (FR + SC): 27 (22 FR + 5 SC)
- Total Tasks: 16
- Coverage %: 100% (27/27 tasked or satisfied at plan time)
- Ambiguity Count: 1 (LOW)
- Duplication Count: 0
- Critical Issues Count: 0
- ADRs Recorded: 12

## Next Actions

No CRITICAL, HIGH, or MEDIUM issues. The two prior MEDIUM findings are resolved. Remaining items are 1 LOW (inherited wording, no action) and 1 informational (FR-016 already done). **The spec is clean — proceed to `/maxi:implement`.**
