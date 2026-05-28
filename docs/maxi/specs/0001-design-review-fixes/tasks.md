---
slug: 0001-design-review-fixes
spec_slug: 0001-design-review-fixes
created: 2026-05-24
updated: 2026-05-24
---

# Tasks: Design Review Fixes

**Input**: `docs/maxi/specs/0001-design-review-fixes/`
**Prerequisites**: `plan.md` ✓, `spec.md` ✓, `constitution.md` ✓

**Tests**: `bash tests/run-all.sh` (fast tier) after every bash/doc change. Integration tier (`bash tests/run-all.sh --integration`) after every new skill. For bash script changes: manual canary test (drift → fail, restore → pass) before committing.

---

## Phase 1: Setup

**Purpose**: Verify clean baseline and fix the known constitution violation before any work begins.

- [ ] T001 [P] Verify baseline: `bash tests/run-all.sh` must pass green before any changes
- [ ] T002 Translate `## Clarifications` section in `docs/maxi/specs/0001-design-review-fixes/spec.md` to English — constitution v1.1.0 requires English in all artifacts

**Checkpoint**: Baseline green, no known constitution violation. All phases can begin.

---

## Phase 2: Foundational ⚠️ P0 FIXES — RESTORE ARCHITECTURAL INTEGRITY

**Purpose**: These three fixes contradict the declared architecture and must be done before any P1 work. US1 especially: every session start currently loads a wrong map.

- [ ] T003 [P] [US1] Fix phase-gating table in `skills/using-maxi/SKILL.md:67-74` — replace `accepts specified (warns)` / `tasked or analyzed` with strict values; add "phases are cheap" note below table
- [ ] T004 [P] [US2] Replace SKILL.md-only comparison with `diff -r` in `tests/check-sync-invariant.sh` loop body
- [ ] T005 [P] [US3] Update `CLAUDE.md` overview (10→11 skills, 7→8 user-facing, 7→8 integration prompts) and fix comment in `tests/check-skills-present.sh:2`
- [ ] T006 [US2] Canary test for T004: manually append a line to `skills/brainstorming/SKILL.md`, run `bash tests/check-sync-invariant.sh`, confirm FAIL; restore file, confirm PASS

**Checkpoint**: P0 complete — `bash tests/run-all.sh` green, grep `"10 maxi-native"` returns zero results, sync-invariant catches full-dir drift. Commit.

---

## Phase 3: ADR Proposals + FR-012 — Migration Notes

**Purpose**: Architectural decisions (FSM expansion, backflow) must be captured as ADRs *before* the implementation phases that introduce them (Phase 5 and Phase 6). Also document the strict-pipeline migration exception.

**⚠️ ADRs FIRST**: Constitution Principle IV — "ADRs proposed automatically during `/maxi:plan`, written only with explicit consent." These must exist before Phases 5 and 6 begin.

- [ ] T007 Invoke `/maxi:adr` for ADR-1 — FSM status set expansion: adding `parked` (non-terminal, reversible) and `cancelled` (terminal) statuses. Context from plan.md "ADR Proposals" section. Write to `docs/maxi/adr/0001-fsm-status-expansion.md`.
- [ ] T008 Invoke `/maxi:adr` for ADR-2 — Backflow in the pipeline (`/maxi:revise`): first skill that makes `status:` go backwards. A+ picker, consent-gated, artefacts left in place. Write to `docs/maxi/adr/0002-pipeline-backflow.md`.
- [ ] T009 Update `docs/architecture.md` strict-pipeline Consequences section — extend to document the migration exception for statuses `planned`/`tasked`/`done` explicitly (this is architecture documentation, not a formal ADR; the formal ADR for the exception is superseded by the migration design intent documented here)
- [ ] T010 Read `skills/migrate-from-speckit/migrate.sh` lines 90–115 to locate status-inference block and `target_spec` write; then append Migration Notes generation block (bash `case` on inferred status → append `## Migration Notes` section to spec.md)
- [ ] T011 Add one sentence to reporting step in `skills/migrate-from-speckit/SKILL.md`: inform user that migrated specs above `specified` status will have a `## Migration Notes` section

**Checkpoint**: Two ADRs written and accepted; migration exception documented; `bash tests/run-all.sh` green. Commit.

---

## Phase 4: US6 — Slug Derivation Deterministic (Priority: P2)

**Goal**: Same description always produces the same slug; stop-word rule and example agree; slug-suffix collisions surface a disambiguation prompt.

**Independent Test**: Run specify with "build a CSV to JSON converter" twice in clean environments — both produce `csv-json-converter`. Run in a project where that suffix exists — disambiguation prompt appears.

- [ ] T012 [US6] Fix stop-word example in `skills/specify/SKILL.md` line ~70: `csv-to-json-converter` → `csv-json-converter`
- [ ] T013 [US6] Append slug-collision check paragraph to Step 3 of `skills/specify/SKILL.md` (after stop-word examples, before Step 4): exact-suffix-match scan of `docs/maxi/specs/`; if match found, prompt user to disambiguate (suggested default: `<suffix>-v2`)

**Checkpoint**: US6 complete. `bash tests/run-all.sh` green. Commit.

---

## Phase 5: US5 — Parked/Cancelled Lifecycle (Priority: P2)

**Goal**: Specs can be parked (reversible) or cancelled (terminal) without hand-editing `status:`. `/maxi:board` shows the new buckets. `check-spec-fixture.sh` validates all 10 statuses.

**Independent Test**: Park a spec → `status: parked`, `parked_from:` set. Resume → status restored. Cancel → `status: cancelled`, terminal. Board shows both buckets even when empty.

### Data model and template

- [ ] T014 [P] [US5] Update `templates/spec-template.md` frontmatter: add `parked_from: null` field + extend allowed-values comment to include `parked | cancelled`
- [ ] T015 [P] [US5] Update `tests/fixtures/sample-spec.md` frontmatter (same changes as T014)
- [ ] T016 [P] [US5] Update `tests/check-spec-fixture.sh` `VALID_STATUSES` array: add `parked` and `cancelled` (line 9)

### Board display

- [ ] T017 [P] [US5] Update `skills/board/SKILL.md` Step 3 canonical status list to include `parked` (before `done`) and `cancelled` (after `done`); update Step 5 staleness rule (no staleness for `cancelled`); update Step 6 render example and rendering rules

### New skills (write each via `superpowers:writing-skills`)

- [ ] T018 [P] [US5] RED — create integration test prompt `tests/integration/prompts/cancel.txt`: `"I want to cancel the current spec for this project."` (must exist BEFORE writing the skill)
- [ ] T019 [P] [US5] RED — create integration test prompt `tests/integration/prompts/park.txt`: `"I need to put the current feature on hold for a while."`
- [ ] T020 [P] [US5] RED — create integration test prompt `tests/integration/prompts/resume.txt`: `"Resume the spec that's currently parked."`
- [ ] T021 [US5] GREEN — invoke `superpowers:writing-skills` to write `skills/cancel/SKILL.md` using behavioral spec from `plan.md` Task 9 Step 1 (consent-gated, terminal, reason required, explicit yes)
- [ ] T022 [US5] GREEN — invoke `superpowers:writing-skills` to write `skills/park/SKILL.md` using behavioral spec from `plan.md` Task 10 Step 1 (consent-gated, sets `parked_from:`, non-terminal)
- [ ] T023 [US5] GREEN — invoke `superpowers:writing-skills` to write `skills/resume/SKILL.md` using behavioral spec from `plan.md` Task 10 Step 2 (reads `parked_from:`, restores status, clears field)
- [ ] T024 [US5] Register `cancel`, `park`, `resume` in `tests/check-skills-present.sh` MAXI_SKILLS array; add all three to `tests/integration/run-all.sh` SKILLS array
- [ ] T025 [US5] Run `bash tests/run-all.sh` — fast tier must pass (frontmatter, skills-present, sync-invariant all green)
- [ ] T026 [US5] Run `bash tests/run-all.sh --integration` for `cancel`, `park`, `resume` — each skill must auto-trigger from its prompt

**Checkpoint**: US5 complete — 10 statuses round-trip, board shows parked/cancelled, three lifecycle skills pass integration. Commit.

---

## Phase 6: US4 — Spec Backflow via /maxi:revise (Priority: P2)

**Goal**: A spec at any status ≥ `clarified` can be rolled back with a documented reason, without hand-editing. Downstream artefacts stay on disk; a `## Clarifications` entry flags them as stale.

**Independent Test**: With spec at `status: planned`, invoke `/maxi:revise "add offline mode"`. A+ picker proposes `clarified` with justification. After yes: `status: clarified`, `## Clarifications` entry present, `plan.md` untouched.

- [ ] T027 [US4] RED — create integration test prompt `tests/integration/prompts/revise.txt`: `"The requirements for the current spec have changed and we need to revise it."`
- [ ] T028 [US4] GREEN — invoke `superpowers:writing-skills` to write `skills/revise/SKILL.md` using behavioral spec from `plan.md` Task 11 Step 1 (A+ picker, consent-gated, no artefact deletion, constitution check before confirm)
- [ ] T029 [US4] Register `revise` in `tests/check-skills-present.sh` MAXI_SKILLS array; add to `tests/integration/run-all.sh` SKILLS array
- [ ] T030 [US4] Update `CLAUDE.md` final skills count: 11 + 4 new = 15 maxi-native skills, 12 user-facing commands; fix `check-skills-present.sh:2` comment to "15"
- [ ] T031 [US4] Run `bash tests/run-all.sh` — fast tier green
- [ ] T032 [US4] Run integration test for `revise` — skill must auto-trigger

**Checkpoint**: US4 complete — revise skill passes integration, skills inventory accurate at 15. Commit.

---

## Phase 7: US7 — Conditional Session Injection (Priority: P3)

**Goal**: In projects without `docs/maxi/`, the `session-start` hook exits immediately without injecting `using-maxi` content.

**Independent Test**: Run `hooks/session-start` in a temp dir (no `docs/maxi/`) — no output. Run in the maxi-superpowers project root — JSON injection present.

- [ ] T033 [P] [US7] Add guard block to `hooks/session-start` after line 8 (plugin root set): `if [ ! -d "$PWD/docs/maxi" ]; then exit 0; fi`
- [ ] T034 [US7] Manual test: `cd /tmp && mkdir -p no-maxi && cd no-maxi && PWD="$PWD" bash <plugin-root>/hooks/session-start` — expected: empty stdout, exit 0
- [ ] T035 [US7] Manual test: `cd <project-root> && bash hooks/session-start | head -3` — expected: JSON output with `hookSpecificOutput`
- [ ] T036 [US7] Run `bash tests/run-all.sh` — `check-hooks` must pass

**Checkpoint**: US7 complete — injection gated on `docs/maxi/` presence. Commit.

---

## Phase 8: Polish

**Purpose**: Full test suite validation.

- [ ] T037 [P] Run full test suite: `bash tests/run-all.sh && bash tests/run-all.sh --integration`

**Checkpoint**: All tests green. ADRs written (T007–T008 in Phase 3). Implementation complete.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — start immediately
- **Phase 2 (Foundational P0)**: Depends on Phase 1 — T003/T004/T005 can run in parallel once T001 passes
- **Phase 3 (FR-012)**: Independent of Phase 2 — can start after Phase 1
- **Phase 4 (US6)**: Independent — can start after Phase 1
- **Phase 5 (US5)**: T012–T018 can run in parallel after Phase 1; T019–T021 (skill writing) after T016–T018 (test prompts exist); T022 after T019–T021
- **Phase 6 (US4)**: T026 (skill writing) after T025 (test prompt exists)
- **Phase 7 (US7)**: Independent — can start after Phase 1
- **Phase 8 (Polish)**: Depends on all user story phases complete

### Parallel Opportunities

- T003, T004, T005 (Phase 2): different files, fully parallel
- T007, T008, T009 (Phase 3): T007 is independent; T008 and T009 touch different files
- T010, T011 (Phase 4): touch same file — sequential
- T012, T013, T014, T015, T016, T017, T018 (Phase 5 data + prompts): all different files, fully parallel
- T019, T020, T021 (Phase 5 skills): different output files, parallel (but wait for T016–T018)
- Phases 3, 4, 7 can run concurrently with Phase 2 if using dispatched subagents
