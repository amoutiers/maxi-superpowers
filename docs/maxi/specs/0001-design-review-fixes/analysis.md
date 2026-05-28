# Analysis: 0001-design-review-fixes

**Date**: 2026-05-24 | **Status**: analyzed

---

## Summary

7-pass audit of spec.md, plan.md, tasks.md against constitution v1.1.0.

- **CRITICAL**: 1 (resolved inline before this report)
- **HIGH**: 4 (resolved inline)
- **MEDIUM**: 5 (accepted as-is or clarified below)
- **LOW**: 2 (informational)

---

## Resolved Before Implementation

**CRITICAL — French text in spec Clarifications (Pass D)**
Resolved: `## Clarifications` section translated to English. Constitution v1.1.0 "English only" constraint satisfied.

**HIGH — ADR timing (Pass G)**
Resolved: tasks.md reordered — T007/T008 (ADR proposals) moved to Phase 3, before Phase 5 (FSM expansion) and Phase 6 (revise skill). ADRs will be written before the architectural changes they govern are implemented.

**HIGH — ADR amendment vs. supersede (Pass D/G)**
Clarified: `docs/architecture.md` is architecture documentation, not a formal maxi ADR file. Constitution Principle IV (append-only, supersede chain) applies to files under `docs/maxi/adr/`. Updating `docs/architecture.md` Consequences section (T009) is not a formal ADR amendment — it is documentation maintenance. No supersede chain required.

**HIGH — FR-004 board integration test (Pass C/E)**
Clarified: `tests/integration/prompts/board.txt` and `tests/integration/run-all.sh` already include `board` in the SKILLS array. FR-004 is already satisfied. T005 (CLAUDE.md fix) will correct the "7 prompts" → "8 prompts" count. No additional task needed.

---

## Accepted Medium Findings

**MEDIUM — A+ picker inference rules in plan.md not echoed in spec (Pass B)**
Accepted: plan.md Task 11 Step 1 is the canonical behavioral spec for `/maxi:revise`. Spec.md intentionally delegates implementation details to plan.md — this is correct maxi pipeline separation. `superpowers:writing-skills` will receive the plan.md spec directly.

**MEDIUM — Slug collision: undefined behavior when `docs/maxi/specs/` does not exist (Pass C)**
Accepted: If `docs/maxi/specs/` does not exist, there are no existing slugs → no collision possible → proceed normally. The skill should handle the non-existent dir case as "no collision." This is implied by the spec and does not need explicit FR text.

**MEDIUM — Skill count updated in two separate tasks (T005 and T030) (Pass F)**
Accepted: T005 updates to "11 skills" (Phase 2); T030 updates to "15 skills" (Phase 6, after 4 new skills are written). Two-step update is intentional and sequential — no risk of permanent drift if tasks execute in order.

**MEDIUM — Stale artefacts have no enforcement mechanism after rollback (Pass D)**
Noted: This is a conscious design decision (spec Q2: artefacts left in place, flagged via `## Clarifications`). A future `PreToolUse` hook (F8, out of scope for this spec) would provide mechanical enforcement. Accepted for this spec.

**MEDIUM — `parked_from` restoration edge case underspecified (Pass C)**
Noted: plan.md Task 10 Step 2 says "warn and ask user" if `parked_from` is null on a parked spec. `superpowers:writing-skills` will receive the full behavioral spec including this edge case. Accepted — sufficient for skill authoring.

---

## Informational (Low)

**LOW — Plan uses ordinal task numbers; tasks.md uses T-IDs (Pass F)**
No action needed. Executors should use T-IDs from tasks.md as the authoritative reference.

**LOW — `$PWD` not set edge case in session-start guard (Pass B)**
Accepted: `set -euo pipefail` is already in the script; if `$PWD` is unset, bash will error out before the guard runs. Standard POSIX environments always set `$PWD`. No defensive check needed.

---

## Constitution Alignment (Pass D — final state)

| Principle | Status |
|---|---|
| I. Mandatory Spec-Driven Pipeline | ✅ This spec follows the full pipeline |
| II. Delegate to Superpowers | ✅ New skills via `superpowers:writing-skills`; writing-plans used for plan |
| III. Strict Pipeline — No Skipping | ✅ Migration exception documented in architecture.md |
| IV. ADR for Non-Trivial Decisions | ✅ T007/T008 propose ADRs before FSM/backflow implementation |
| V. Artifacts Over Chat | ✅ All decisions captured in spec/plan/tasks/analysis |
| English only | ✅ French Clarifications translated (T002 complete) |
| Status managed by pipeline | ✅ No hand-edits to status |
| Fast-tier tests mandatory | ✅ Checkpoints include `bash tests/run-all.sh` |

---

## ADR Alignment (Pass G — final state)

Two architectural choices require ADRs before implementation:
- **ADR-1** (T007): FSM status expansion — `parked` + `cancelled`
- **ADR-2** (T008): Pipeline backflow — `/maxi:revise`

Both are scheduled in Phase 3 (before Phases 5 and 6). ✅

---

## Next Actions

No CRITICAL issues remain. Implementation can proceed.

**Execution recommendation**: Use `superpowers:dispatching-parallel-agents` for Phase 2 (T003, T004, T005 are fully parallel — different files). Phase 3 is sequential (ADRs first, then migration notes). Phases 4–7 can proceed once Phase 3 is complete.
