# Specification Analysis Report

Generated: 2026-05-30 (re-run after revise — F1/F2 resolved)
Spec: docs/maxi/specs/0005-migrate-from-brownfield/spec.md (status: tasked)

## Findings

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| E1 | Coverage / Underspecification | MEDIUM | spec.md FR-005; plan.md `cmd_exclude`; tasks T009/T007 | The **name token-set fallback** branch of FR-005 (for ref-less, forward-pipeline specs) still has no explicit implementation step and no fast-tier test/fixture. `cmd_exclude` returns `keep` on no path-overlap; the fallback is described as living in `SKILL.md` (T007) without a discrete sub-step or fixture. | Add a ref-less spec to `tests/fixtures/brownfield-project/` + an assertion, and make the name-fallback an explicit sub-step of T007. Otherwise the branch ships untested. Best folded into implementation of T007/T009. |
| E2 | Coverage Gap | LOW | spec.md SC-001; tasks T005/T006/T014 | SC-001 (refs *resolve* at the recorded SHA) has no deterministic test — validated only by the adversarial verify agent (T006) and manual smoke (T014). | Acceptable: agent-authored ref resolution is inherently non-deterministic. Note in tasks that SC-001 is integration/agent-validated. |
| C1 | Ambiguity | LOW | spec.md FR-002/FR-004 "no clean structure" | The cutoff between "clean structure" (multiple boundaries) and "structureless" (single floor) is agent judgment with no operational threshold. | Acceptable for a heuristic; optional cue in `discover-subagent.md` (e.g. "no lens yields ≥2 disjoint clusters → emit one floor candidate"). |
| O1 | Observation | LOW | tasks.md T012; CLAUDE.md | Mandatory doc-sync (T012) maps to no FR/SC — a project-process obligation, not a feature requirement. | No action; correctly placed in Polish. |

### Resolved since prior run
- **F1 (was MEDIUM)** — FR-010's reading is now fixed by the `## Clarifications` "Revised (2026-05-30)" entry (write triggers = `accept` **or** `edit`) and reinforced in plan.md Task 8 consent semantics. ✅
- **F2 (was LOW)** — boundary identity is now `name` throughout; `brownfield.sh exclude` uses `--name` (plan.md `cmd_exclude` + test assertions updated); "label" kept only as prose for the migrate-adr rule. ✅

## Coverage Summary

| Requirement | Has Task? | Task IDs | Notes |
|-------------|-----------|----------|-------|
| FR-001 no-constitution stop | ✓ | T002, T007 | guard exit 2 |
| FR-002 no-code stop / degrade | ✓ | T002, T007 | guard exit 3 + floor |
| FR-003 record SHA | ✓ | T004, T007 | `git rev-parse HEAD` → `source_sha` |
| FR-004 discovery + paths + floor | ✓ | T010, T007 | multi-modal + single floor |
| FR-005 exclusion / idempotency | ◑ | T008, T009, T007 | path-overlap tested; **name fallback untested (E1)** |
| FR-006 boundary-map review | ✓ | T007 | |
| FR-007 as-built schema + file:line | ✓ | T005 | |
| FR-008 adversarial verify | ✓ | T006 | |
| FR-009 consent verbs / edit-writes | ✓ | T007 | |
| FR-010 no write without accept/edit | ✓ | T007 | F1 resolved |
| FR-011 write done + NNNN at write time | ✓ | T004 | |
| FR-012 origin + sha, no new FSM status | ✓ | T004 | ADR-0011 |
| FR-013 Migration Notes | ✓ | T004 | |
| FR-014 parallel boundaries | ✓ | T007, T010 | |
| FR-015 out of scope | ✓ | T007 | |
| FR-016 user-invocable | ✓ | T007 | |
| SC-001 file:line resolves | ◑ | T005, T006, T014 | agent/manual only (E2) |
| SC-002 no write without consent | ✓ | T003, T007 | |
| SC-003 0 duplicate proposals | ✓ | T009 | |
| SC-004 distinguishable by frontmatter | ✓ | T004 | |
| SC-005 0 new FSM status | ✓ | T004 | ADR-0011 |

## Constitution Alignment Issues

None found. Done-on-creation (FR-011/FR-012) is sanctioned by constitution v1.4.0's ingress clause and ADR-0011; `origin:` provenance (FR-012) and "no forward-gating change" (FR-015) satisfy the clause's conditions. Single-responsibility (VI) enforced by FR-015. No FSM status added (FR-012). Skill authored via `writing-skills` (T007) per Contributor Workflow.

## ADR Alignment Issues

None found. ADR-0011 (`accepted`, `related_specs: 0005-migrate-from-brownfield`) records the only non-trivial decision and is linked from plan.md. No missing ADR (no new tech stack), no ADR↔constitution conflict (0011 drove v1.4.0), no stale references (0011/0001/0002 all `accepted`), no supersede cycles.

## Unmapped Tasks

T001 (fixture), T002 (script skeleton), T011 (registration), T012 (doc-sync), T013 (integration prompt), T014 (verification) — Setup / Foundational / Polish; legitimately unlabeled. No orphaned implementation tasks.

## Metrics

- Total Requirements (FR + SC): 21 (16 FR + 5 SC)
- Total Tasks: 14
- Coverage %: 100% have ≥1 task (2 partial — FR-005 name-fallback branch, SC-001)
- Ambiguity Count: 1 (LOW)
- Duplication Count: 0
- Critical Issues Count: 0
- ADRs Recorded: 11

## Next Actions

No CRITICAL or HIGH findings — clear to `/maxi:implement`. F1 and F2 resolved by the revise.

One MEDIUM remains, best handled inside implementation (not blocking):
1. **E1** — when implementing T009/T007, add a ref-less spec to the fixture and an explicit assertion + step for the FR-005 **name token-set fallback** so it doesn't ship untested.

LOW items (E2/C1/O1) are acknowledgements, no action required.
