---
slug: 0018-artifact-cross-reference-conventions
spec_slug: 0018-artifact-cross-reference-conventions
created: 2026-05-31
updated: 2026-05-31
---

# Implementation Plan: Artifact cross-reference conventions — direction and link form

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Invert ADR↔spec traceability (ADR loses `related_specs`/`related_principles`/`related_requirements`; spec gains `related_adrs`), re-point `analyze` Pass G to the spec side, and add a project-wide clickable-link rendering convention to all maxi skills — without breaking `bash tests/run-all.sh`.

**Architecture:** This is a documentation + skill-instruction + bash-test change in a markdown/bash plugin repo. There is no application runtime — the "code" is `SKILL.md` instruction files, markdown templates, bash test scripts, and the existing ADR/spec markdown corpus. Changes are sequenced so the test suite stays green at every commit: schema + tests first (TDD), then producers, then the read-side (`analyze`), then one-time data migration, then the cross-cutting link convention, then doc-sync.

**Tech Stack:** Markdown (skills, templates, ADRs, specs), Bash (`tests/*.sh` with `tests/lib/test-helpers.sh` providing `assert_grep` / `assert_not_grep` / `assert_file_exists`), YAML frontmatter.

> **⚠️ Authoring constraint (CLAUDE.md / Constitution Contributor Workflow):** every change to a `SKILL.md` file MUST be authored via `superpowers:writing-skills`, which runs its own RED/GREEN/REFACTOR cycle — **never hand-edit a `SKILL.md`.** This applies to `x-adr`, `analyze`, `specify`, `migrate-adr`, and the 12 skills receiving the link convention. Non-`SKILL.md` files (templates `adr-template.md`/`spec-template.md`, support briefs `discover-subagent.md`/`import-subagent.md`, bash tests, ADR/spec markdown, docs) are edited directly — but when a support brief belongs to a skill being changed, edit it within the same `writing-skills` session for that skill.

---

## Summary

The spec ([0018-artifact-cross-reference-conventions/spec](spec.md)) governs how maxi artifacts cross-reference each other along two axes. **Axis 1 (direction):** the durable ADR must stop pointing up at the ephemeral spec — remove the three cross-ref fields from the ADR schema and move the link to the spec via `related_adrs` (full ADR slugs); migrate `analyze` Pass G (the only machine consumer) to read spec-side. **Axis 2 (form):** every maxi skill that emits prose referencing an artifact renders a relative Markdown link whose visible text is the target filename without `.md`, forward-only, enforced by authoring guidance. Plus a one-time data migration of 11 ADRs + 6 specs, reconciliation of superseded FR-016/FR-017, and doc-sync.

## Technical Context

**Language/Version**: Markdown + Bash (POSIX/zsh, `set -euo pipefail`)
**Primary Dependencies**: `tests/lib/test-helpers.sh` (`assert_grep`, `assert_not_grep`, `assert_file_exists`, `summary_and_exit`); git (`git rev-parse --show-toplevel`)
**Storage**: Flat markdown files under `docs/maxi/` and `skills/`
**Testing**: `bash tests/run-all.sh` (fast tier, no Claude runtime); `tests/check-templates.sh` and `tests/check-migrate-adr.sh` are the directly-affected suites
**Target Platform**: Claude Code + OpenCode dual harness; skill `SKILL.md` files are harness-agnostic (no OpenCode-specific duplication needed — the link convention lives in shared skill instructions, not in `.opencode/plugins/maxi.js`)
**Project Type**: Claude Code / OpenCode plugin (skills + hooks + tests)
**Performance Goals**: N/A (no runtime)
**Constraints**: `bash tests/run-all.sh` MUST pass before every commit (constitution Constraint: Fast-tier tests mandatory); ADR bodies are append-only (only `status`/`supersedes`/`superseded_by` may change); vendored superpowers skills must not be touched (all skills modified here are maxi-native)
**Scale/Scope**: 1 ADR template, 1 spec template, 2 test scripts, 1 fixture, ~5 producer/consumer skill files, ~12 skills for the link convention, 11 ADRs, 6 specs, 2 doc files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Pass / Fail | Notes |
|-----------|-------------|-------|
| I. Mandatory Spec-Driven Pipeline | ✓ | This change is itself going through the pipeline. |
| II. Delegate to Superpowers, Never Duplicate | ✓ | Only maxi-native skills modified; no superpowers capability re-implemented. |
| III. Strict Pipeline — No Skipping | ✓ | Forward development; no phase skipped. |
| IV. ADR for Every Non-Trivial Decision | ✓ | The inversion is captured as a correction ADR during this `/maxi:plan` (post-plan ADR scan). |
| V. Artifacts Over Chat | ✓ | All decisions live in spec/plan/ADR. |
| VI. Single Responsibility per Skill | ✓ (noted) | ~12 skills receive uniform link guidance (a cross-cutting convention, not responsibility fusion); `x-adr` gains a spec back-link write, which is part of its single responsibility "record a decision and its traceability". No skill fuses concerns with independent reasons to change. |

No violations → Complexity Tracking is empty.

## Project Structure

### Documentation (this feature)

```text
docs/maxi/specs/0018-artifact-cross-reference-conventions/
├── spec.md          # status: clarified (input)
├── plan.md          # This file
└── tasks.md         # Produced later by /maxi:tasks
```

### Source files touched (repository root)

```text
skills/x-adr/adr-template.md            # remove 3 fields (FR-001)
skills/x-adr/SKILL.md                   # remove field writes/append-only refs; add related_adrs back-link write (FR-004/005/006); README index reverse-lookup
skills/specify/spec-template.md         # add related_adrs: [] (FR-002)
skills/specify/SKILL.md                 # initialize related_adrs: [] (FR-003)
skills/analyze/SKILL.md                 # Step 2/3 + G1 read spec-side (FR-008/009/010)
skills/migrate-adr/discover-subagent.md # remove fields + constitution-linkage (FR-007)
skills/migrate-adr/import-subagent.md   # remove fields (FR-007)
skills/migrate-adr/SKILL.md             # remove "pass constitution principles to Discoverer" (FR-007/015)
tests/check-templates.sh                # assert 3 fields ABSENT from ADR template+fixture; assert related_adrs present in spec-template (FR-014)
tests/fixtures/sample-adr.md            # remove 3 fields (FR-014)
tests/check-migrate-adr.sh              # drop FR-016 principle-passing assertion (FR-015)
docs/maxi/adr/0001..0011-*.md           # strip 3 frontmatter fields (FR-011)
docs/maxi/adr/README.md                 # regenerated index (column rebuilt by reverse-lookup)
docs/maxi/specs/0001|0002|0004|0005/spec.md  # add related_adrs back-links (FR-012)
docs/maxi/specs/0002-migrate-adr-review-fixes/spec.md  # FR-016 supersession note (FR-015)
docs/maxi/specs/0016-migrate-adr/spec.md               # FR-017 supersession note (FR-015)
<~12 maxi skill SKILL.md files>         # Link rendering convention guidance (FR-018, forward-only)
CLAUDE.md                               # Artifact Convention note related_adrs (FR-017)
docs/architecture.md                    # spec frontmatter + ADR schema note (FR-017)
```

**Structure Decision**: No new directories. All edits are in-place to existing skill/test/doc/markdown files. The change is wide (many files) but shallow (small, mechanical edits per file), so tasks are grouped by responsibility and sequenced to keep tests green.

## Decisions

> **Auto-populated by `/maxi:plan` when architectural choices are recorded as ADRs.**
> Each entry links to the full decision record in `docs/maxi/adr/`.

| ADR | Title | Status |
|-----|-------|--------|
| — | Correction ADR proposed in this plan's post-plan ADR scan (traceability direction spec→ADR, superseding the implicit ADR-side-link design; cross-references [0003-constitution-decoupled-from-claudemd](../../adr/0003-constitution-decoupled-from-claudemd.md)). | proposed |

## Complexity Tracking

> No constitution violations — section intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |

---

## Spec gaps surfaced during planning

Two consumers of the removed fields that the spec did not name explicitly — both folded into tasks below; flag for `/maxi:analyze`:

1. **ADR README index "Related Specs" column** ([README.md:5](../../adr/README.md)) is built from `related_specs`. After removal it must be rebuilt by **reverse-lookup** (scan every spec's `related_adrs`, invert the map) so the index column survives without ADR-side data. Task 11 + Task 6 (x-adr regen logic).
2. **FR-016 test guard** is [check-migrate-adr.sh:47](../../../../tests/check-migrate-adr.sh) `assert_grep "$MIGRATE" "constitution's principles"` — *not* a literal `related_principles` string. That is the assertion to drop (Task 12), plus verify no schema-field assertion references a removed field.

---

## Phase 1 — Schema + templates + tests (TDD foundation)

### Task 1: ADR template loses the three cross-ref fields

**Files:**
- Modify: `tests/check-templates.sh:49-61`
- Modify: `skills/x-adr/adr-template.md:9-11`
- Modify: `tests/fixtures/sample-adr.md:9-10`
- Test: `tests/check-templates.sh`

- [ ] **Step 1: Make the test demand the fields' absence (RED)**

In `tests/check-templates.sh`, edit the two `check_template` calls for `adr-template.md` (lines 50-54) and `fixtures/sample-adr.md` (lines 57-61): remove `"related_specs:" "related_principles:" "related_requirements:"` from each field list. Then, immediately after each `check_template` call, add explicit absence assertions:

```bash
assert_not_grep "$ROOT/skills/x-adr/adr-template.md" "^related_specs:" "adr-template.md: no related_specs"
assert_not_grep "$ROOT/skills/x-adr/adr-template.md" "^related_principles:" "adr-template.md: no related_principles"
assert_not_grep "$ROOT/skills/x-adr/adr-template.md" "^related_requirements:" "adr-template.md: no related_requirements"
assert_not_grep "$ROOT/tests/fixtures/sample-adr.md" "^related_specs:" "sample-adr.md: no related_specs"
assert_not_grep "$ROOT/tests/fixtures/sample-adr.md" "^related_principles:" "sample-adr.md: no related_principles"
assert_not_grep "$ROOT/tests/fixtures/sample-adr.md" "^related_requirements:" "sample-adr.md: no related_requirements"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/check-templates.sh`
Expected: FAIL — `adr-template.md: no related_specs` (and the other five) fail because the template/fixture still contain the fields.

- [ ] **Step 3: Remove the fields from the template and fixture (GREEN)**

In `skills/x-adr/adr-template.md`, delete lines 9-11 (`related_specs: []`, `related_principles: []`, `related_requirements: []`). In `tests/fixtures/sample-adr.md`, delete the `related_principles:` and `related_requirements:` lines and the `related_specs:` line. Final ADR frontmatter is exactly: `adr`, `slug`, `status`, `created`, `updated`, `decider`, `supersedes`, `superseded_by`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/check-templates.sh`
Expected: PASS — `OK [adr-template.md]`, `OK [fixtures/sample-adr.md]`, and the six absence assertions pass.

- [ ] **Step 5: Commit**

```bash
git add skills/x-adr/adr-template.md tests/fixtures/sample-adr.md tests/check-templates.sh
git commit -m "feat(0018): remove cross-ref fields from ADR schema + assert absence"
```

### Task 2: Spec template gains `related_adrs`

**Files:**
- Modify: `tests/check-templates.sh:63-68`
- Modify: `skills/specify/spec-template.md:1-9`
- Modify: `skills/specify/SKILL.md` (Step 5 frontmatter block)

- [ ] **Step 1: Assert the spec template has the field (RED)**

In `tests/check-templates.sh`, add `"related_adrs:"` to the `spec-template` field list (line 66, after `"status:"`).

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/check-templates.sh`
Expected: FAIL — `spec-template.md: related_adrs:` fails (field not yet present).

- [ ] **Step 3: Add the field to the template (GREEN)**

In `skills/specify/spec-template.md`, add to the frontmatter (after `parked_from: null`):

```yaml
related_adrs: []
# related_adrs: full ADR slugs (e.g. ["0003-constitution-decoupled-from-claudemd"]) this spec's decisions are recorded in; appended by x-adr on ADR acceptance.
```

- [ ] **Step 4: Initialize the field in /maxi:specify**

In `skills/specify/SKILL.md` Step 5 ("Set initial frontmatter"), add `related_adrs: []` to the YAML block so new specs are created with it.

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/check-templates.sh`
Expected: PASS — `OK [spec-template.md]`.

- [ ] **Step 6: Commit**

```bash
git add skills/specify/spec-template.md skills/specify/SKILL.md tests/check-templates.sh
git commit -m "feat(0018): add related_adrs to spec schema + specify init"
```

## Phase 2 — Producers (x-adr, migrate-adr)

### Task 3: x-adr stops writing the removed fields

**Files:**
- Modify: `skills/x-adr/SKILL.md:94-98` (frontmatter fill list)
- Modify: `skills/x-adr/SKILL.md:103-107` (Decision Drivers derivation)
- Modify: `skills/x-adr/SKILL.md:170-172` (append-only field list)

- [ ] **Step 1: Remove the three field-fill bullets**

In `skills/x-adr/SKILL.md` Step 3, delete the three bullets at lines 94-96 (`related_specs:`, `related_principles:`, `related_requirements:`). The frontmatter fill list now ends `decider:` → `supersedes:` → `superseded_by: null`.

- [ ] **Step 2: Reword the Decision Drivers derivation (keep the intent, drop the field names)**

Replace lines 103-107 with guidance that keeps "derive drivers from principles and requirements" as inline prose without referencing the removed fields:

```markdown
- **Decision Drivers** — list 2–4 criteria that determine which option wins. Derive from:
  - Constitution principles relevant to the decision (cite them inline, e.g., "III. Data Integrity First")
  - Spec requirements relevant to the decision (cite FR-### / SC-### inline)
  - Explicit constraints from the plan (e.g., "must support 100+ concurrent writes")
  Never leave this section empty — if no requirements are referenced, state the implicit constraint that drove the choice.
```

- [ ] **Step 3: Remove the fields from the append-only list**

In `skills/x-adr/SKILL.md:172`, change `- \`adr\`, \`slug\`, \`created\`, \`related_specs\`, \`related_principles\`, \`related_requirements\`` to `- \`adr\`, \`slug\`, \`created\``.

- [ ] **Step 4: Verify no removed-field reference remains in x-adr**

Run: `grep -n "related_specs\|related_principles\|related_requirements" skills/x-adr/SKILL.md`
Expected: only matches inside the README-index examples (handled in Task 6) — no field-write or append-only references.

- [ ] **Step 5: Commit**

```bash
git add skills/x-adr/SKILL.md
git commit -m "feat(0018): x-adr stops writing ADR cross-ref fields"
```

### Task 4: x-adr writes the spec back-link on ADR acceptance (FR-004)

**Files:**
- Modify: `skills/x-adr/SKILL.md:131-136` (Step 6 "yes" handling)

- [ ] **Step 1: Add the back-link write to the consent handler**

In `skills/x-adr/SKILL.md` Step 6, under the `yes` → "Normal case" and "Supersede case" bullets, add a new sub-step (applies to both):

```markdown
- **Spec back-link (both cases):** if this ADR was created in the context of an active spec (the calling `/maxi:plan` or `/maxi:implement` knows the spec directory), append this ADR's full slug to that spec's `related_adrs` frontmatter list (create the list if absent) and bump the spec's `updated:` to today's ISO date — in the same write. If there is no active spec (e.g. a standalone decision), skip silently; the ADR still stands.
```

- [ ] **Step 2: Document the no-active-spec case in Common Mistakes**

Add a row to the Common Mistakes table:

```markdown
| Writing an ADR but forgetting the spec back-link | When an active spec exists, append the ADR slug to its `related_adrs` and bump `updated:` |
```

- [ ] **Step 3: Verify**

Run: `grep -n "related_adrs" skills/x-adr/SKILL.md`
Expected: the back-link write step is present.

- [ ] **Step 4: Commit**

```bash
git add skills/x-adr/SKILL.md
git commit -m "feat(0018): x-adr records spec->ADR back-link in related_adrs"
```

### Task 5: migrate-adr subagents + orchestrator stop emitting the fields (FR-007)

**Files:**
- Modify: `skills/migrate-adr/discover-subagent.md:21,28-29`
- Modify: `skills/migrate-adr/import-subagent.md:67-68`
- Modify: `skills/migrate-adr/SKILL.md` (the "pass constitution's principles to Discoverer" instruction)

- [ ] **Step 1: Remove the constitution-linkage paragraph + fields from the discoverer**

In `skills/migrate-adr/discover-subagent.md`, delete the "Constitution linkage" paragraph (line 21) and the `related_principles: []` / `related_requirements: []` lines (28-29) from the draft frontmatter example. Also remove `related_specs:` from that example if present.

- [ ] **Step 2: Remove the fields from the importer draft frontmatter**

In `skills/migrate-adr/import-subagent.md`, delete the `related_principles: []` and `related_requirements: []` lines (67-68) and any `related_specs:` line from the draft frontmatter example.

- [ ] **Step 3: Remove the principle-passing instruction from the orchestrator**

In `skills/migrate-adr/SKILL.md`, remove the instruction that passes the constitution's principles to the Discoverer for `related_principles` population (the text guarded by `check-migrate-adr.sh:47`). Leave the significance rubric and all other discoverer inputs intact.

- [ ] **Step 4: Verify no removed-field reference remains**

Run: `grep -rn "related_specs\|related_principles\|related_requirements" skills/migrate-adr/`
Expected: no matches.

- [ ] **Step 5: Commit**

```bash
git add skills/migrate-adr/
git commit -m "feat(0018): migrate-adr stops emitting ADR cross-ref fields"
```

### Task 6: x-adr README index rebuilt by reverse-lookup (spec gap #1)

**Files:**
- Modify: `skills/x-adr/SKILL.md:148-161` (Step 7 README regeneration)

- [ ] **Step 1: Change the index source from ADR.related_specs to spec-side reverse-lookup**

Rewrite Step 7 so the "Related Specs" column is built by scanning every `docs/maxi/specs/*/spec.md` for `related_adrs` and inverting the map (for each ADR slug, list the specs whose `related_adrs` contains it). Update the instruction and example:

```markdown
### 7. Regenerate docs/maxi/adr/README.md

After every successful write, rewrite the index by scanning all `.md` files in `docs/maxi/adr/` (excluding `README.md`). Sort by ADR number ascending. Read each file's frontmatter for `ADR`, `Title` (H1), `Status`, `Created`. Build the **Related Specs** column by reverse-lookup: scan every `docs/maxi/specs/*/spec.md` for `related_adrs`; for each ADR, list the spec slugs whose `related_adrs` contains this ADR's slug. If none, write `—`.

| ADR | Title | Status | Created | Related Specs |
|-----|-------|--------|---------|---------------|
| [0001](0001-slug.md) | Title of decision | accepted | 2026-05-08 | 0001-design-review-fixes |
```

- [ ] **Step 2: Verify the example no longer implies ADR-side related_specs**

Run: `grep -n "related_specs" skills/x-adr/SKILL.md`
Expected: only the reverse-lookup description references it (as the *spec-side* field), no ADR-frontmatter read.

- [ ] **Step 3: Commit**

```bash
git add skills/x-adr/SKILL.md
git commit -m "feat(0018): x-adr README index built by spec-side reverse-lookup"
```

## Phase 3 — Read side (analyze Pass G)

### Task 7: analyze reads the spec→ADR direction (FR-008/009/010)

**Files:**
- Modify: `skills/analyze/SKILL.md:39` (Step 2 ADR load)
- Modify: `skills/analyze/SKILL.md:46` (Step 3 ADR registry)
- Modify: `skills/analyze/SKILL.md:81` (G1 wording)

- [ ] **Step 1: Step 2 — stop loading removed fields**

Change line 39 to: `**From docs/maxi/adr/ (if exists):** All ADR files — adr number, title, status, Decision section, Consequences section` (drop `related_specs, related_principles`).

- [ ] **Step 2: Step 3 — build the registry from spec-side links**

Change line 46 to:

```markdown
- **ADR registry:** list all `docs/maxi/adr/NNNN-*.md` files; for each record adr number, title, status, and decision domain. Build the **spec↔ADR map** from each spec's `related_adrs` frontmatter plus inline `ADR-NNNN` mentions in `spec.md`/`plan.md`/`tasks.md` (do NOT read any `related_specs` field — it no longer exists). If `docs/maxi/adr/` is empty, Pass G reports "no ADRs recorded" and skips G-type findings.
```

- [ ] **Step 3: G1 — reformulate as spec references no ADR**

Change line 81 to:

```markdown
- **G1 — Missing ADR (MEDIUM):** plan.md has a "Tech Stack" section or names a consequential technology choice (storage engine, runtime, primary framework) for which the spec references no accepted ADR (via its `related_adrs` or an inline `ADR-NNNN` mention). One finding per unrecorded choice. Only flag consequential choices, not incidental library picks.
```

- [ ] **Step 4: Verify analyze no longer reads ADR-side related_specs**

Run: `grep -n "related_specs" skills/analyze/SKILL.md`
Expected: no matches (the registry now reads `related_adrs`).

- [ ] **Step 5: Commit**

```bash
git add skills/analyze/SKILL.md
git commit -m "feat(0018): analyze Pass G reads spec-side related_adrs"
```

## Phase 4 — Data migration (one-time)

### Task 8: Strip the three fields from the 11 existing ADRs (FR-011/013)

**Files:**
- Modify: `docs/maxi/adr/0001-*.md` … `docs/maxi/adr/0011-*.md` (frontmatter only)

- [ ] **Step 1: Remove the frontmatter lines from every ADR**

For each `docs/maxi/adr/000N-*.md` (0001–0011 **plus the correction ADR captured during `/maxi:plan`**, e.g. 0012 — it was written under the current schema and so still carries the three fields), delete the `related_specs:`, `related_principles:`, and `related_requirements:` frontmatter lines. **Do not touch any body prose** (e.g. ADR-0003's body mention `(related_requirements: FR-025)` stays — append-only bodies, FR-013).

- [ ] **Step 2: Verify zero frontmatter matches, bodies intact**

Run:
```bash
grep -rn "^related_specs:\|^related_principles:\|^related_requirements:" docs/maxi/adr/
grep -n "related_requirements: FR-025" docs/maxi/adr/0003-constitution-decoupled-from-claudemd.md
```
Expected: first command → no output; second → still present (body untouched).

- [ ] **Step 3: Commit**

```bash
git add docs/maxi/adr/
git commit -m "feat(0018): strip cross-ref fields from 11 existing ADRs"
```

### Task 9: Write the back-links onto the 6 specs (FR-012)

**Files:**
- Modify: `docs/maxi/specs/0001-design-review-fixes/spec.md`
- Modify: `docs/maxi/specs/0002-migrate-adr-review-fixes/spec.md`
- Modify: `docs/maxi/specs/0004-single-responsibility-migrate-adr-split/spec.md`
- Modify: `docs/maxi/specs/0005-migrate-from-brownfield/spec.md`

- [ ] **Step 1: Add `related_adrs` to each spec's frontmatter**

Add the field (after `parked_from:`), bumping each `updated:` to `2026-05-31`:

```yaml
# 0001-design-review-fixes/spec.md
related_adrs: ["0001-fsm-status-expansion", "0002-pipeline-backflow"]
# 0002-migrate-adr-review-fixes/spec.md
related_adrs: ["0003-constitution-decoupled-from-claudemd"]
# 0004-single-responsibility-migrate-adr-split/spec.md
related_adrs: ["0009-single-responsibility-per-skill", "0010-migrate-adr-decomposition-support-files"]
# 0005-migrate-from-brownfield/spec.md
related_adrs: ["0011-migration-ingress-terminal-status"]
# 0018-artifact-cross-reference-conventions/spec.md (this feature's own correction ADR)
related_adrs: ["<correction-ADR-slug captured during /maxi:plan, e.g. 0012-traceability-direction-spec-to-adr>"]
```

- [ ] **Step 2: Verify**

Run: `grep -rn "related_adrs" docs/maxi/specs/0001-design-review-fixes docs/maxi/specs/0002-migrate-adr-review-fixes docs/maxi/specs/0004-single-responsibility-migrate-adr-split docs/maxi/specs/0005-migrate-from-brownfield`
Expected: each spec lists its ADR slug(s).

- [ ] **Step 3: Commit**

```bash
git add docs/maxi/specs/0001-design-review-fixes/spec.md docs/maxi/specs/0002-migrate-adr-review-fixes/spec.md docs/maxi/specs/0004-single-responsibility-migrate-adr-split/spec.md docs/maxi/specs/0005-migrate-from-brownfield/spec.md
git commit -m "feat(0018): write spec->ADR back-links onto 6 migrated specs"
```

### Task 10: Reconcile FR-016 / FR-017 with linked supersession notes (FR-015)

**Files:**
- Modify: `docs/maxi/specs/0002-migrate-adr-review-fixes/spec.md` (FR-016 line)
- Modify: `docs/maxi/specs/0016-migrate-adr/spec.md` (FR-017 line)

- [ ] **Step 1: Add the supersession note under FR-016 (spec 0002)**

Immediately after the FR-016 bullet, insert (relative link from `specs/0002-…/` to `specs/0018-…/`):

```markdown
  > **Superseded by [0018-artifact-cross-reference-conventions/spec](../0018-artifact-cross-reference-conventions/spec.md)** — `related_principles` removed from the ADR schema; traceability moved spec-side.
```

- [ ] **Step 2: Add the supersession note under FR-017 (spec 0016)**

Immediately after the FR-017 bullet, insert the same note. Bump both specs' `updated:` to `2026-05-31`. Do **not** change either spec's `status` (they stay `done`).

- [ ] **Step 3: Verify**

Run: `grep -n "Superseded by \[0018-artifact-cross-reference-conventions" docs/maxi/specs/0002-migrate-adr-review-fixes/spec.md docs/maxi/specs/0016-migrate-adr/spec.md`
Expected: one match in each file.

- [ ] **Step 4: Commit**

```bash
git add docs/maxi/specs/0002-migrate-adr-review-fixes/spec.md docs/maxi/specs/0016-migrate-adr/spec.md
git commit -m "feat(0018): linked supersession notes reconcile FR-016/FR-017"
```

### Task 11: Regenerate the ADR README index (reverse-lookup result)

**Files:**
- Modify: `docs/maxi/adr/README.md`

- [ ] **Step 1: Rebuild the Related Specs column from the new spec-side links**

Regenerate `docs/maxi/adr/README.md` so the **Related Specs** column reflects the reverse-lookup (identical mapping to before the migration, now sourced spec-side): 0001→`0001-design-review-fixes`, 0002→`0001-design-review-fixes`, 0003→`0002-migrate-adr-review-fixes`, 0009 & 0010→`0004-single-responsibility-migrate-adr-split`, 0011→`0005-migrate-from-brownfield`, all others `—`. Status/Created columns unchanged.

- [ ] **Step 2: Verify the index matches the spec-side data**

Run: `grep -c "0001-design-review-fixes" docs/maxi/adr/README.md`
Expected: `2` (ADR-0001 and ADR-0002 rows).

- [ ] **Step 3: Commit**

```bash
git add docs/maxi/adr/README.md
git commit -m "feat(0018): regenerate ADR index from spec-side related_adrs"
```

### Task 12: Drop the FR-016 test guard, keep the suite green (FR-015)

**Files:**
- Modify: `tests/check-migrate-adr.sh:47`

- [ ] **Step 1: Remove the principle-passing assertion**

Delete line 47: `assert_grep "$MIGRATE" "constitution's principles" "FR-016 principles passed to Discoverer"`. Scan the rest of the file for any assertion referencing a removed field; there are none (schema-field assertions on lines 44-46 are `domain_label`/`source_path`/`Return schema`, which are unaffected and stay).

- [ ] **Step 2: Run the suite to verify green**

Run: `bash tests/check-migrate-adr.sh`
Expected: PASS — no assertion now depends on the removed `related_principles` behavior.

- [ ] **Step 3: Commit**

```bash
git add tests/check-migrate-adr.sh
git commit -m "feat(0018): drop FR-016 related_principles test guard"
```

## Phase 5 — Link rendering convention (Axis 2, forward-only)

### Task 13: Add the Link rendering convention to every reference-emitting maxi skill (FR-018/019/021)

**Files (each `SKILL.md`):** `skills/x-adr/`, `skills/analyze/`, `skills/board/`, `skills/plan/`, `skills/tasks/`, `skills/specify/`, `skills/clarify/`, `skills/revise/`, `skills/migrate-adr/`, `skills/migrate-from-speckit/`, `skills/migrate-from-brownfield/`, `skills/constitution/`

- [ ] **Step 1: Define one canonical guidance block to paste into each skill**

Insert this block into each listed `SKILL.md` (near its output/report section — for skills with a "Report" step, immediately above it; otherwise at the end before Red Flags):

```markdown
## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.
```

- [ ] **Step 2: Verify the block landed in all 12 skills**

Run: `grep -rl "Artifact reference links" skills/ | wc -l`
Expected: `12`.

- [ ] **Step 3: Run the full fast tier (frontmatter check covers all SKILL.md)**

Run: `bash tests/run-all.sh`
Expected: PASS (the added section is valid markdown under existing frontmatter; `check-frontmatter.sh` stays green).

- [ ] **Step 4: Commit**

```bash
git add skills/
git commit -m "feat(0018): add forward-only link rendering convention to 12 skills"
```

## Phase 6 — Documentation sync (FR-017)

### Task 14: CLAUDE.md + architecture.md note the schema changes

**Files:**
- Modify: `CLAUDE.md` (Artifact Convention, ~line 29-36)
- Modify: `docs/architecture.md` (ADR section ~line 96-111; spec frontmatter ~line 117-128)

- [ ] **Step 1: CLAUDE.md — note `related_adrs` and the slimmed ADR schema**

In the Artifact Convention section, add a line documenting that `spec.md` carries `related_adrs: [...]` (full ADR slugs, the canonical spec→ADR link) and that ADRs no longer carry `related_specs`/`related_principles`/`related_requirements`.

- [ ] **Step 2: architecture.md — update the ADR append-only + spec frontmatter notes**

In `docs/architecture.md`: in the ADR section (around line 111) confirm the append-only field list is unchanged (`status`/`supersedes`/`superseded_by`) and add that traceability is spec-side via `related_adrs`; in the spec-frontmatter section (around line 117) add `related_adrs` to the described fields.

- [ ] **Step 3: Run the doc-consistency fast check if present, else full suite**

Run: `bash tests/run-all.sh`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/architecture.md
git commit -m "docs(0018): note related_adrs + slimmed ADR schema (doc-sync)"
```

> **Note on the CLAUDE.md "five-file rule":** that rule fires for *pipeline* changes (new skill, new FSM status, new phase transition, changed gating rule). This feature changes neither gating nor the FSM, so `pipeline-flow.md`, `delegation-map.md`, and `using-maxi/SKILL.md` need no edit (verified: they do not mention the removed fields). Only `CLAUDE.md` + `architecture.md` require the schema note.

## Phase 7 — Verification

### Task 15: Full-suite green + spec success-criteria check

- [ ] **Step 1: Run the entire fast tier**

Run: `bash tests/run-all.sh`
Expected: PASS — all fast-tier checks green (SC-004).

- [ ] **Step 2: Verify SC-001 (zero removed fields in ADR frontmatter)**

Run: `grep -rn "^related_specs:\|^related_principles:\|^related_requirements:" docs/maxi/adr/ skills/x-adr/adr-template.md tests/fixtures/sample-adr.md`
Expected: no output.

- [ ] **Step 3: Verify SC-002 (6 back-links preserved)**

Run: `grep -rn "related_adrs" docs/maxi/specs/*/spec.md | grep -E "0001-fsm|0002-pipeline|0003-constitution|0009-single|0010-migrate|0011-migration"`
Expected: all six original links present spec-side.

- [ ] **Step 4: Verify SC-005 (link guidance in all 12 skills)**

Run: `grep -rl "Artifact reference links" skills/ | wc -l`
Expected: `12`.

- [ ] **Step 5: Final commit if any verification fix was needed**

```bash
git add -A
git commit -m "test(0018): verify SC-001/002/004/005 green"
```

> **SC-003 (analyze behavior-preserving):** there is no automated before/after fixture in the fast tier. Confirm manually by running `/maxi:analyze` on a spec with a tech choice lacking an ADR (G1 still fires) and one referencing a superseded ADR (G3 still fires), both via spec-side links. This is a manual acceptance check, noted here so it is not silently skipped.

---

## Self-review notes

- **Spec coverage:** FR-001→T1; FR-002/003→T2; FR-004→T4; FR-005/006→T3; FR-007→T5; FR-008/009/010→T7; FR-011/013→T8; FR-012→T9; FR-014→T1+T2; FR-015→T10+T12; FR-016 (correction ADR)→post-plan ADR scan; FR-017→T14; FR-018/019/021→T13; FR-020 (no automated enforcement)→honored by T13 being guidance-only. SC-001/002/004/005→T15; SC-003→manual check noted.
- **Two spec gaps** surfaced and tasked (README index reverse-lookup T6/T11; FR-016 guard is `"constitution's principles"` not literal `related_principles` T12).
- **Sequencing** keeps `tests/run-all.sh` green at each commit: schema+tests (TDD) before producers; producers before the read side; data migration after producers so x-adr's new regen logic matches; test guard dropped only once its behavior is gone.
