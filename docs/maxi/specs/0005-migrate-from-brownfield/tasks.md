---
slug: 0005-migrate-from-brownfield
spec_slug: 0005-migrate-from-brownfield
created: 2026-05-30
updated: 2026-05-30
---

# Tasks: migrate-from-brownfield

> **Filled in by `/maxi:tasks`.** Extracted from `plan.md`. Implement via `superpowers:subagent-driven-development` or `superpowers:executing-plans`.

**Input**: `docs/maxi/specs/0005-migrate-from-brownfield/{spec.md,plan.md}`

**Tests**: Test-first per `superpowers:test-driven-development` — the deterministic `brownfield.sh` surface is unit-tested in the fast tier; subagent briefs and `SKILL.md` are validated by structural checks and the integration tier.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: different files, no dependency — safe to parallelize
- **[USN]**: user story implemented (US1 P1 / US2 P2 / US3 P3)

---

## Phase 1: Setup

**Purpose**: Test fixture the deterministic suite runs against.

- [x] T001 [P] Create fixture brownfield repo at `tests/fixtures/brownfield-project/` — `src/auth/login.js`, `src/billing/invoice.js`, `package.json`, minimal `docs/maxi/constitution.md`, and a pre-existing reverse-engineered `docs/maxi/specs/0001-auth/spec.md` (`origin: reverse-engineered`, FR with `src/auth/login.js:3` ref) to drive the exclusion test.

**Checkpoint**: Fixture in place — foundational phase can begin.

---

## Phase 2: Foundational ⚠️ BLOCKS ALL USER STORIES

**Purpose**: The helper script + fast-tier harness every story depends on.

**⚠️ CRITICAL**: No user-story work begins until this is complete.

- [x] T002 Create `tests/check-migrate-from-brownfield.sh` (sourcing `tests/lib/test-helpers.sh`) and `skills/migrate-from-brownfield/brownfield.sh` with the `guard` subcommand + dispatch `case`; assert guard exits 0 (constitution+code), 2 (no constitution, points to `/maxi:constitution`), 3 (no recognized code). Make executable. (plan Task 2)

**Checkpoint**: Script skeleton + test harness green — user stories can begin.

---

## Phase 3: User Story 1 - Reverse-engineer one boundary into a trustworthy baseline (Priority: P1) 🎯 MVP

**Goal**: Produce one verified `spec.md` baseline (drafted → adversarially verified → consent → written at `done`).

**Independent Test**: Against a one-module repo, the skill writes a `spec.md` at `status: done` with `file:line`-traceable FRs and Migration Notes, and writes nothing until explicit `accept`.

### Tests for User Story 1 (write first, ensure they FAIL)

- [x] T003 [US1] [US3] Add failing `write-spec` assertions to `tests/check-migrate-from-brownfield.sh`: written spec has `status: done`, `origin: reverse-engineered`, `source_sha`, correct next `NNNN` (0002 over fixture's 0001), and a `## Migration Notes` section naming the un-run phases. (plan Task 3 Step 1)

### Implementation for User Story 1

- [x] T004 [US1] [US3] Implement `cmd_write_spec` in `skills/migrate-from-brownfield/brownfield.sh` (`--slug/--body/--sha`; NNNN = max+1 at write time; emits ingress frontmatter + Migration Notes); make T003 pass. (plan Task 3)
- [x] T005 [P] [US1] [US3] Author `skills/migrate-from-brownfield/draft-subagent.md` — full maxi-schema spec with as-built acceptance scenarios and a `(path:line)` ref on every FR; returns `DraftedSpec` with `fr_refs`. (plan Task 6)
- [x] T006 [P] [US1] Author `skills/migrate-from-brownfield/verify-subagent.md` — independent adversarial pass flagging `hallucination`/`omission`/`stale_ref`, drops unverifiable FRs, returns `Verdict` with `revised_spec_markdown`. (plan Task 7)
- [x] T007 [US1] Author `skills/migrate-from-brownfield/SKILL.md` via `superpowers:writing-skills` — coordinator workflow (guard → SHA → exclusion set → dispatch discovery → dedup → boundary-map review → per boundary: draft→verify→consent → serial `write-spec`), Iron Rule consent (`accept`/`skip`/`edit`, ambiguous→re-ask→`skip`), guards, out-of-scope (FR-015); validate with `bash tests/check-frontmatter.sh`. Depends on T004–T006. (plan Task 8)

**Checkpoint** 🎯 MVP: a single verified baseline can be produced end-to-end and is independently testable.

---

## Phase 4: User Story 2 - Decompose a large codebase and document it in waves (Priority: P2)

**Goal**: Multi-modal discovery → editable boundary map → idempotent re-runs.

**Independent Test**: First run proposes boundaries with per-boundary evidence; second run excludes already-documented boundaries.

### Tests for User Story 2 (write first, ensure they FAIL)

- [x] T008 [US2] Add failing `exclude` assertions to `tests/check-migrate-from-brownfield.sh`: candidate fully covered by `0001-auth` → `exclude`; brand-new `billing` → `keep`; spanning auth+billing → `flag`. (plan Task 4 Step 1)

### Implementation for User Story 2

- [x] T009 [US2] Implement `cmd_exclude` in `brownfield.sh` (flag `--name`/`--paths`) — path-overlap primary (covered candidate → `exclude`), partial overlap → `flag`, no overlap → `keep` (name token-set fallback reserved for ref-less specs); make T008 pass. (plan Task 4)
- [x] T010 [P] [US2] Author `skills/migrate-from-brownfield/discover-subagent.md` — single-lens multi-modal discovery (`directory`/`entrypoint`/`manifest`/`route`), honors the exclusion set, returns `BoundaryCandidate[]` with `backing_paths`+`evidence`. (plan Task 5)

> The boundary-map edit/select review and the Jaccard ≥ 0.5 dedup rule live in `SKILL.md` (T007); US2 adds the discovery lenses (T010) and idempotency matcher (T009).

**Checkpoint**: US1 + US2 both work — large repos are decomposable and resumable.

---

## Phase 5: User Story 3 - Provenance and traceability (Priority: P3)

**Goal**: Reverse-engineered baselines are distinguishable from pipeline-authored specs and auditable to source.

**Independent Test**: Inspect a written baseline — `origin: reverse-engineered` + `source_sha` in frontmatter, every FR carries a `file:line`, Migration Notes records un-run phases.

> Pure extraction: US3 is delivered by **T004** (`write-spec` emits `origin`/`source_sha`/Migration Notes — FR-012/FR-013) and **T005** (drafter puts a `file:line` on every FR — FR-007/SC-001), both dual-tagged `[US3]` above. No additional implementation tasks. Its acceptance is asserted by the T003 frontmatter checks and confirmed in T014.

**Checkpoint**: All three stories independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T011 [P] Register the skill: add `migrate-from-brownfield` to `tests/check-skills-present.sh` `MAXI_SKILLS` (header 17→18) and register `check-migrate-from-brownfield.sh` in `tests/run-all.sh`; add to `.claude-plugin/plugin.json` only if it enumerates skills. (plan Task 9)
- [x] T012 Mandatory pipeline-doc sync (ATOMIC, one commit): `docs/pipeline-flow.md` (ingress note), `docs/delegation-map.md` (skill row), `skills/using-maxi/SKILL.md` (Getting-Started pointer, not the forward gating table), `CLAUDE.md` (count 17→18, `origin:`/`source_sha` in artifact convention, fast-tier test list). (plan Task 10)
- [x] T013 [P] Add integration prompt `tests/integration/prompts/migrate-from-brownfield.txt` (naive "reverse-engineer my existing code into specs" phrasing). (plan Task 11)
- [x] T014 Full verification: `bash tests/run-all.sh` (fast tier green), then optional `bash tests/run-all.sh --integration` (skill auto-triggers). Stage for review via `superpowers:requesting-code-review`; do NOT commit without user consent. (plan Task 12)

---

## Dependencies & Execution Order

### Phase order
- **Setup (T001)** → **Foundational (T002)** → **US1 (T003–T007)** / **US2 (T008–T010)** → **US3 (verification-only)** → **Polish (T011–T014)**.
- US1 and US2 both depend only on Foundational; they can proceed in parallel after T002. US3 needs T004+T005 (in US1). Polish needs all stories.

### Key edges
- T002 blocks everything. T003 before T004 (TDD). T008 before T009 (TDD). T007 (SKILL) depends on T004, T005, T006 (references the script + briefs). T012 should land after T002/T011 so the doc list reflects the real test. T014 last.

### Parallel opportunities
- `[P]` tasks touch disjoint files: **T005** (draft brief) ∥ **T006** (verify brief) ∥ **T010** (discover brief) can all be authored concurrently. **T011** ∥ **T013** are independent. **T001** is standalone.
- Sequential (shared files): T002→T003→T004→T009 all touch `brownfield.sh` and/or the one test file — keep ordered.

### Within each story
- Tests fail before implementation (T003→T004, T008→T009).
- Script subcommands before the SKILL that orchestrates them (T004/T009 before T007).
- `SKILL.md` authored only via `superpowers:writing-skills` (project rule).

## Notes
- Commit after each task or logical group; final staging awaits explicit user consent (project Git rule).
- US3 has no standalone implementation task by design — provenance is produced by the US1 write path; this is faithful extraction, not an omission.
