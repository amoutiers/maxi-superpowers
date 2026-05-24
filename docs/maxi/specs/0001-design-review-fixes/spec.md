---
slug: 0001-design-review-fixes
created: 2026-05-24
updated: 2026-05-24
status: analyzed
# Allowed values: drafting | specified | clarified | planned | tasked | analyzed | implementing | done
---

# Feature Specification: Design Review Fixes

Global design review of the maxi-superpowers plugin (2026-05-24). Ten findings were identified across three priority levels. This spec covers the full remediation.

## User Scenarios & Testing

### User Story 1 - Session starts with accurate pipeline context (Priority: P1)

As a user of the maxi plugin, when I start a new Claude Code session (or run `/clear` or `/compact`), the injected `using-maxi` context reflects the current strict-pipeline rules — so the model operates on a correct map of required statuses from turn 0.

**Why this priority**: F1 is the most urgent finding. `using-maxi/SKILL.md:71-74` still documents the pre-strict-pipeline tolerances (`plan` accepting `specified`, `implement` accepting `tasked or analyzed`), which directly contradicts `plan/SKILL.md:15` and `implement/SKILL.md`. Claude is mis-oriented at every session start.

**Independent Test**: Start a fresh session in a maxi project. Ask "what status does /maxi:plan require?". The answer must be "clarified, no tolerance" — not "accepts specified with warning".

**Acceptance Scenarios**:

1. **Given** a fresh session start, **When** I ask Claude what `/maxi:plan` requires, **Then** Claude answers "`clarified`, tolerance `none`" — not "accepts `specified` (warns)".
2. **Given** a fresh session start, **When** I ask what `/maxi:implement` requires, **Then** Claude answers "`analyzed`, tolerance `none`" — not "`tasked` or `analyzed`".

---

### User Story 2 - Vendor sync catches full-directory drift (Priority: P1)

As a maintainer bumping superpowers, when I run `bash tests/run-all.sh`, any drift between `vendor/superpowers/skills/<name>/` and `skills/<name>/` — including auxiliary files like `visual-companion.md`, not just `SKILL.md` — causes the test to fail.

**Why this priority**: `check-sync-invariant.sh` currently only diffs `SKILL.md`. A skill with reference files (e.g. `brainstorming/visual-companion.md`) can silently diverge, causing behavioral differences without any test failure.

**Independent Test**: Manually modify a non-`SKILL.md` file inside a vendored skill dir in `skills/`. Run `bash tests/run-all.sh`. The test must fail.

**Acceptance Scenarios**:

1. **Given** `skills/brainstorming/visual-companion.md` has been modified, **When** I run `bash tests/run-all.sh`, **Then** `check-sync-invariant` fails with a clear message identifying the diverging file.
2. **Given** all files in all vendored skill dirs are byte-identical to their vendor counterparts, **When** I run `bash tests/run-all.sh`, **Then** all sync-invariant checks pass.

---

### User Story 3 - `board` is a first-class documented skill (Priority: P1)

As a contributor reading `CLAUDE.md`, I see `board` listed as one of the 11 maxi-native skills, understand its role, and can find an integration test that covers its auto-trigger.

**Why this priority**: `board` exists on disk, is referenced in `using-maxi`, and is tested by `check-skills-present.sh` — but `CLAUDE.md` still says "10 skills, 7 user-facing commands" and no integration prompt covers `/maxi:board`. A change breaking `board`'s auto-trigger would pass CI green.

**Independent Test**: Search for "10 maxi-native skills" in the repo — zero results. Run `bash tests/run-all.sh --integration` — an integration test for `/maxi:board` runs and passes.

**Acceptance Scenarios**:

1. **Given** `CLAUDE.md`, **When** I read the skills inventory, **Then** I see "11 maxi-native skills: 8 user-facing commands (constitution, specify, clarify, plan, tasks, analyze, implement, board), ...".
2. **Given** the integration test suite, **When** I run it, **Then** a test verifies that invoking `/maxi:board` auto-triggers the `board` skill.

---

### User Story 4 - Spec can be revised after planning without hand-editing status (Priority: P2)

As a feature owner whose requirements changed after `/maxi:plan` ran, I can use `/maxi:revise` to document the change, roll back `status:` to the appropriate phase, and re-run the pipeline from there — without ever hand-editing `spec.md` frontmatter.

**Why this priority**: Currently, the pipeline has no backflow. After `planned`, `clarify` refuses to run and `analyze` is read-only. The only escape is hand-editing `status:` — which `using-maxi` explicitly forbids. Real projects change; the pipeline must support this.

**Independent Test**: With a spec at `status: planned`, invoke `/maxi:revise` with a description of the change. Verify `status:` rolls back to `clarified`, `updated:` is bumped, and `## Clarifications` has a timestamped entry. Then `/maxi:plan` runs successfully.

**Acceptance Scenarios**:

1. **Given** a spec at `status: planned`, **When** I invoke `/maxi:revise "add offline sync requirement"`, **Then** the skill proposes rolling back to `clarified`, waits for my confirmation, then sets `status: clarified` + bumps `updated:` + appends a `## Clarifications` entry.
2. **Given** a spec at `status: implementing`, **When** I invoke `/maxi:revise`, **Then** the skill asks which artifact needs changing and proposes the appropriate rollback target.
3. **Given** I decline the rollback in the confirm step, **When** revise runs, **Then** no file is modified.

---

### User Story 5 - Specs can be parked or cancelled without hand-editing (Priority: P2)

As a project manager, when a feature is de-prioritized or abandoned, I can use `/maxi:park` or `/maxi:cancel` to record the decision with a reason and a date — and `/maxi:board` shows the feature in the correct bucket.

**Why this priority**: All 8 current statuses are forward-only. An abandoned spec lives in limbo (stale forever on `/maxi:board`) unless the user deletes the folder (losing history) or hand-edits the status (forbidden). Long-lived projects will have abandoned specs; the pipeline must handle them.

**Independent Test**: With a spec at `status: implementing`, invoke `/maxi:park "deprioritized for Q3"`. Verify `status: parked`, `parked_from: implementing`, `updated:` bumped, a `## Clarifications` entry. Then run `/maxi:resume` and verify `status` returns to `implementing`.

**Acceptance Scenarios**:

1. **Given** a spec at any active status, **When** I invoke `/maxi:park "reason"`, **Then** after confirmation: `status: parked`, `parked_from: <previous_status>`, `updated: today`, entry in `## Clarifications`.
2. **Given** a spec at `status: parked`, **When** I invoke `/maxi:resume`, **Then** after confirmation: `status: <parked_from>`, `updated: today`, entry in `## Clarifications`.
3. **Given** a spec at any status, **When** I invoke `/maxi:cancel "reason"`, **Then** after confirmation: `status: cancelled` (terminal), `updated: today`, entry in `## Clarifications`. Cannot be un-cancelled.
4. **Given** the `/maxi:board` view, **When** specs exist at `parked` or `cancelled`, **Then** they appear in dedicated buckets — `parked` above `done`, `cancelled` at the bottom.

---

### User Story 6 - Spec slug derivation is deterministic (Priority: P2)

As a user running `/maxi:specify`, the slug derived from my feature description follows a single consistent rule — the same description always produces the same slug, and slug suffix collisions trigger a disambiguation prompt.

**Why this priority**: `specify/SKILL.md:67` lists "to" as a stop-word but example line 70 preserves it. Two agents following rule vs example produce different slugs. Additionally, two different descriptions producing the same slug-suffix create ambiguous cross-references.

**Independent Test**: Run `/maxi:specify "build a CSV to JSON converter"` twice (in two separate test environments). Both produce the same slug. Run `/maxi:specify "csv json converter"` in a project where `0001-csv-json-converter` already exists — a disambiguation prompt appears.

**Acceptance Scenarios**:

1. **Given** the feature description "build a CSV to JSON converter", **When** I run `/maxi:specify`, **Then** the derived slug is `csv-json-converter` (not `csv-to-json-converter`) — "to" is dropped as a stop-word.
2. **Given** `docs/maxi/specs/0001-auth-flow/` already exists, **When** I run `/maxi:specify "auth flow redesign"` which derives to slug-suffix `auth-flow`, **Then** I am asked to disambiguate (suggested default: `auth-flow-v2`).

---

### User Story 7 - Session injection is conditional on maxi project context (Priority: P3)

As a user working in a non-maxi project, when I start a Claude Code session, the `using-maxi` pipeline orientation is NOT injected — reducing token waste and cognitive noise.

**Why this priority**: The `session-start` hook injects `using-maxi` unconditionally. In projects without `docs/maxi/`, this is pure noise. If both superpowers and maxi are installed, both `using-superpowers` and `using-maxi` fire, with no coordination.

**Independent Test**: Start a session in `/tmp/test-project` (no `docs/maxi/`). Verify `using-maxi` content is absent from the session context. Start a session in a maxi project — content is present.

**Acceptance Scenarios**:

1. **Given** a project without `docs/maxi/`, **When** a session starts, **Then** `hooks/session-start` does NOT inject the `using-maxi` content.
2. **Given** a project with `docs/maxi/`, **When** a session starts, **Then** `hooks/session-start` injects the `using-maxi` content as before.

---

### Edge Cases

- `/maxi:revise` called on a spec at `status: drafting` or `specified` — these phases are not past the point of no return; the skill should redirect to the appropriate existing skill (`clarify` or `specify`).
- `/maxi:park` called when spec is already `parked` or `cancelled` — no-op with message.
- `/maxi:resume` called on a `cancelled` spec — refuse (terminal status).
- Stop-word list: "to" is a stop-word when it appears standalone, but is it dropped when it's the only connector left (e.g. "sync to remote" → `sync-remote` loses meaning)? **Decision**: always drop stop-words per the list; meaning sufficiency is the user's responsibility when choosing a description.
- `migrate-from-speckit` producing a spec at `tasked` — that spec never went through `clarify` or `analyze`. The pipeline must handle it gracefully (strict gates apply going forward; migration notes document the skip).

## Requirements

### Functional Requirements

- **FR-001**: `using-maxi/SKILL.md` MUST reflect strict-pipeline status requirements (`plan` requires `clarified`, `implement` requires `analyzed`) in its Phase Gating table.
- **FR-002**: `tests/check-sync-invariant.sh` MUST perform a recursive directory diff, not just a `SKILL.md` comparison, for all vendored skills.
- **FR-003**: `CLAUDE.md` MUST accurately document 11 maxi-native skills including `board`; `check-skills-present.sh` comment MUST match the array count.
- **FR-004**: The integration test suite MUST include a test for `/maxi:board` auto-trigger.
- **FR-005**: A `maxi:revise` skill MUST exist that rolls back `status:` to the appropriate phase after consent, appends a timestamped `## Clarifications` entry, bumps `updated:`, and re-queues the pipeline from that phase.
- **FR-006**: `maxi:park` and `maxi:resume` skills MUST exist; `maxi:cancel` MUST exist. All three are consent-gated. `parked_from:` frontmatter field records the pre-park status for resume.
- **FR-007**: `templates/spec-template.md` allowed-values comment MUST include `parked` and `cancelled`. `tests/check-spec-fixture.sh` MUST validate all 10 statuses round-trip.
- **FR-008**: `skills/board/SKILL.md` MUST display `parked` and `cancelled` buckets (always shown, even if empty).
- **FR-009**: `specify/SKILL.md` stop-word list and examples MUST be consistent: "to" is a stop-word in all cases.
- **FR-010**: `specify/SKILL.md` MUST check for slug-suffix collisions after derivation and prompt the user to disambiguate if a collision exists.
- **FR-011**: `hooks/session-start` MUST check for the presence of `docs/maxi/` in `$PWD` before injecting `using-maxi` content.
- **FR-012**: `migrate-from-speckit` MUST append a `## Migration Notes` section to any migrated spec that skipped pipeline phases, listing which phases were not run.

### Key Entities

- **spec.md frontmatter**: adds `parked_from: <status>` field (null when not parked).
- **FSM status set**: expands from 8 to 10 values: `drafting | specified | clarified | planned | tasked | analyzed | implementing | done | parked | cancelled`.
- **maxi:revise skill**: new skill, consent-gated, modifies `status:` and appends `## Clarifications`.
- **maxi:park / maxi:resume / maxi:cancel skills**: new skills, consent-gated lifecycle management.

## Clarifications

**Q1 (2026-05-24) — How does `maxi:revise` determine the rollback target status?**
A: A+ picker (suggested default). The skill reads the change description, proposes a target status with a one-sentence justification (e.g. "change touches requirements → I suggest `clarified`"), and the user either accepts the default or overrides from the list `[clarified | planned | tasked | analyzed]`. The inference is visible and correctable — no hidden magic.

**Q2 (2026-05-24) — What happens to downstream artefacts (plan.md, tasks.md, analysis.md) on rollback?**
A: Left in place. A timestamped `## Clarifications` entry records the rollback and explicitly flags that downstream files pre-date the rollback. The next `/maxi:plan` will overwrite them. Benefit: preserves the context useful for re-planning.

**Q3 (2026-05-24) — FR-010: what counts as a slug collision?**
A: Exact suffix match only. The derived suffix (post-`NNNN-`) must be character-for-character identical to an existing suffix. No fuzzy matching (no plurals, common prefixes, or near-variants). Simple, predictable rule, explainable in one sentence.

## Success Criteria

- **SC-001**: `bash tests/run-all.sh` passes green after all P0 fixes.
- **SC-002**: Starting a session in a maxi project and asking "what does `/maxi:plan` require?" yields "`clarified`, no tolerance" — not the pre-strict-pipeline answer.
- **SC-003**: Manually drifting a non-`SKILL.md` file in a vendored skill causes `check-sync-invariant` to fail.
- **SC-004**: `grep -r "10 maxi-native" .` returns zero results in the repo.
- **SC-005**: `bash tests/run-all.sh --integration` includes and passes a `/maxi:board` trigger test.
- **SC-006**: A spec at `status: planned` can be rolled back to `clarified` via `/maxi:revise` without any hand-edit.
- **SC-007**: `/maxi:board` displays `parked` and `cancelled` buckets.
- **SC-008**: The feature description "build a CSV to JSON converter" consistently produces slug `csv-json-converter` across multiple invocations.
- **SC-009**: Starting a Claude session in `/tmp/empty-project` (no `docs/maxi/`) produces no `using-maxi` injection.

## Assumptions

- The `superpowers:writing-skills` TDD cycle will be used to author `maxi:revise`, `maxi:park`, `maxi:resume`, and `maxi:cancel`.
- The `parked_from:` field is added to `spec-template.md` with a default value of `null`; migration for existing specs is not required (field is absent = not parked).
- `migrate-from-speckit` ADR exception (F6 option B) will be documented in `docs/architecture.md` rather than requiring a new ADR — the strict-pipeline ADR will be amended.
- F8 (PreToolUse hook for FSM validation) and F9-C (payload reduction) are out of scope for this spec; they will be separate specs after stabilization.
- The `session-start` hook cwd detection uses `$PWD` at hook invocation time, which equals the directory where `claude` was launched.
