# Specification Analysis Report

Generated: 2026-05-29 (re-run after D1 remediation)
Spec: docs/maxi/specs/0002-migrate-adr-review-fixes/spec.md (status: tasked → analyzed)

## Findings

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| E1 | Coverage Gaps | MEDIUM | spec.md SC-001..SC-004; tasks.md T005..T023, T025/T026 | SC-001..004 are **runtime behavioral** outcomes ("skip → zero files", "zero false exclusions", "re-run skips rejected", "no non-ADR imports"). All automated checks are **textual `grep` assertions** verifying the skill *says* the right thing, not that it *behaves* so. Runtime coverage is only the opt-in integration tier (T025) + manual sanity (T026). | Accept textual + integration coverage explicitly (plan/tasks already note this), or add a migrate-adr integration prompt exercising skip/exclusion behavior so SC-001..004 have a runtime gate. Non-blocking. |
| B1 | Ambiguity | LOW | spec.md FR-017; tasks.md T016 | Rubric terms "costly to reverse", "constrains future choices", "was contested" have no measurable threshold — agent judgment. Testable only by example (US6's formatter-vs-database test). | Acceptable by design for an LLM rubric; keep the concrete US6 examples as the de-facto bar. No change. |
| F2 | Inconsistency | LOW | spec.md FR-007 / FR-008 | FR-007 builds a single-element set from "the longest remaining token (3+ chars)"; FR-008 handles "every candidate token shorter than 3 characters". Adjacent territory; could read as overlapping at the boundary. | Confirm during implementation that FR-008's <3-char fallback takes precedence over FR-007's set construction; no spec edit needed if so. |
| F3 | Inconsistency | LOW | CLAUDE.md "Mandatory Sync"; FR-022/FR-024 | Project CLAUDE.md requires a 4-file sync for *pipeline* changes (new skill / FSM status / phase transition / gating rule). This work changes a utility skill + docs, not the FSM, so the rule likely does not trigger — but FR-022 edits CLAUDE.md itself. | Verify during implementation that `using-maxi`, `delegation-map.md`, `pipeline-flow.md` need no update (expected: none). |
| G1 | ADR Alignment | LOW | constitution.md Principle IV; plan.md Decisions | Only the constitution-decoupling decision is slated for an ADR (FR-025/T022). The consent-gate redesign and set-based matching are skill-internal pattern changes; constitution line 43 scopes *mandatory* ADRs to gating-rule / FSM / maxi↔superpowers changes — none apply. | Optional: decide explicitly whether the matching-algorithm change merits its own ADR. Default (no ADR) is defensible. |

## Coverage Summary

| Requirement | Has Task? | Task IDs | Notes |
|-------------|-----------|----------|-------|
| FR-001..005 | ✅ | T005, T006 | US1 |
| FR-006,007,008 | ✅ | T007, T008 | US2 |
| FR-009,010 | ✅ | T009, T010 | US3 |
| FR-011,012,014 | ✅ | T011, T012 | US4 |
| FR-013 | ✅ | T012 (Step 2 read), T008 (normalization note) | US2/US4 |
| FR-015,016 | ✅ | T013, T014 | US5 |
| FR-017,018 | ✅ | T015, T016 | US6 |
| FR-019,020,021 | ✅ | T017, T018 | US7 |
| FR-022 | ✅ | T019, T021 | US8 |
| FR-023 | ✅ | T023 | Phase 11 preservation |
| FR-024,025 | ✅ | T020, T022 | US8 (ADR via /maxi:adr) |
| SC-001..004 | ⚠️ partial | textual asserts + T025/T026 | Runtime outcomes; see E1 |
| SC-005 | ✅ | T024, + per-commit D1 gate | Full fast tier |

All 25 FRs have task coverage. All implementation tasks carry a `[USN]`; setup/foundational/polish (T001–T004, T023–T026) correctly carry none.

## Constitution Alignment Issues

**None found.** The prior CRITICAL (D1 — commits not running the full fast tier) is **RESOLVED**: `plan.md` now carries a Commit Discipline rule and every commit step runs `bash tests/run-all.sh`; `tasks.md` marks the full-suite gate on every commit-bearing task (T004, T006, T008, T010, T012, T014, T016, T018, T021, T022, T026). The "fast-tier mandatory before any commit" constraint is satisfied.

## ADR Alignment Issues

ADRs recorded: 2 (`0001-fsm-status-expansion`, `0002-pipeline-backflow`), both `accepted`, both `related_specs: ["0001-design-review-fixes"]`, both `supersedes: null`.

- **G2 (ADR↔Constitution conflict):** None found.
- **G3 (Stale ADR reference):** None — neither ADR is deprecated/superseded; no artifact references an ADR by number.
- **G4 (Cyclic supersede):** None — both chains terminate.
- **G1 (Missing ADR):** No consequential new tech-stack choice; one optional consideration (LOW). The planned amendment ADR (T022) becomes ADR-0003 and should set `related_specs: ["0002-migrate-adr-review-fixes"]`.

## Unmapped Tasks

None. T001–T004 (Setup/Foundational) and T023–T026 (Polish) are intentionally story-agnostic; all other tasks map to a user story.

## Metrics

- Total Requirements (FR + SC): 30 (25 FR + 5 SC)
- Total Tasks: 26
- Coverage %: FR 100% (25/25); SC 100% mapped (SC-005 has a full automated gate; SC-001..004 textual + opt-in integration)
- Ambiguity Count: 1 (B1, LOW — by-design rubric)
- Duplication Count: 0
- Critical Issues Count: 0
- ADRs Recorded: 2

## Next Actions

**No CRITICAL issues — cleared to run `/maxi:implement`.**

Optional, non-blocking:
- **E1 (MEDIUM):** Decide whether SC-001..004 need a runtime/integration gate or are accepted as textual + opt-in integration coverage.
- **F2 (LOW):** Confirm FR-008's <3-char fallback precedence during implementation.
- **F3 (LOW):** Confirm the CLAUDE.md 4-file sync rule does not trigger (expected: it doesn't).
- **G1 (LOW):** Decide explicitly whether the matching-algorithm change warrants its own ADR (default no is defensible).

Change since prior run: D1 resolved (CRITICAL → cleared); F1 (Phase 10 task-ID ordering) resolved by re-extraction. Remaining items are 1 MEDIUM + 4 LOW, all non-blocking.
