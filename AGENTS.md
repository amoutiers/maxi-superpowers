# maxi-superpowers — Contributor Guidelines

## Overview

maxi-superpowers is a multi-harness plugin aligned 1:1 with the superpowers v6.3.0 harness model: Claude Code, Antigravity, Codex App, Codex CLI, Cursor, Devin CLI, Factory Droid, Gemini CLI, GitHub Copilot CLI, Grok Build CLI, Kimi Code, OpenCode, Pi, and Hermes Agent. It vendors superpowers' skills via git subtree and adds 19 Maxi-native skills: 13 user-facing commands (`constitution`, `specify`, `clarify`, `plan`, `review`, `tasks`, `analyze`, `implement`, `board`, `cancel`, `park`, `resume`, `revise`), 2 internal pipeline skills (`x-adr`, `x-develop`), 1 session skill (`using-maxi`), and 3 migration skills (`migrate-from-speckit`, `migrate-from-brownfield`, `migrate-adr`).

## Git

**Never commit without explicit user consent.** Stage changes and show what will be committed, then wait for approval before running `git commit`.

## Developing New Skills

All new skills MUST be authored using `superpowers:writing-skills`. Do not hand-write SKILL.md files.

All skills MUST be single-responsibility — see the project Constitution, Principle VI (*Single Responsibility per Skill*). Do not duplicate the principle text here; the constitution is authoritative.

The authoring flow:
1. **brainstorm** — explore intent and design (`superpowers:brainstorming`)
2. **spec** — write the spec (`/maxi:specify`)
3. **plan** — write the implementation plan (`superpowers:writing-plans`, via `/maxi:plan`)
4. **writing-skills** — author/edit the SKILL.md (`superpowers:writing-skills`), which runs its own RED/GREEN/REFACTOR cycle internally

Every newly written `plan.md` carries exactly one `Global Constraints` section containing only applicable durable cross-task constraints from the spec and constitution; transient execution state and individual mutation authority are excluded, while a durable rule requiring fresh authorization is allowed.

## Vendored Skills

`skills/` contains a mix of vendored (from superpowers) and maxi-native skills.
- **Do NOT hand-edit vendored skills.** Run `scripts/sync-superpowers.sh` to re-sync.
- **To bump superpowers version:** run `scripts/bump-superpowers.sh <tag>`

## Artifact Convention

Per-project artifacts live at the user's project root:
- `docs/maxi/constitution.md` — project principles
- `docs/maxi/adr/` — Architecture Decision Records (auto-captured, NNNN-slug.md format)
- `docs/maxi/specs/NNNN-slug/` — spec, plan, tasks, analysis per feature

Reverse-engineered specs produced by `migrate-from-brownfield` carry two extra optional frontmatter fields — `origin: reverse-engineered` and `source_sha:` (the commit they were derived from) — and land at `status: done` per the constitution's migration-ingress clause (ADR-0011).

Every new ADR records its creating spec through a direct `spec` link containing the full spec slug, or `spec: null` when it is standalone. Existing ADRs are not migrated. `spec.md` frontmatter retains `related_adrs: [...]` as the spec-side index used by review and analysis; obsolete plural ADR fields (`related_specs`, `related_principles`, and `related_requirements`) remain forbidden (ADR-0024).

During an initial active lifecycle that lacks the monotone `reopened_from: done` watermark, a detected change to an accepted ADR whose `spec` matches the current spec triggers an agent-proposed active-spec amendment through internal `x-adr`. The full amended ADR and exact diff require explicit approval before writing. Missing or null links, `done`, `parked`, or `cancelled` specs, and reopened specs marked `reopened_from: done` use closed-spec supersession instead.

## Status Frontmatter

Every `spec.md` has a YAML frontmatter `status:` field:
`drafting | specified | clarified | planned | tasked | analyzed | implementing | done | parked | cancelled`

The 10-state FSM remains unchanged. The three fixed review boundaries are design review after the normal plan write, readiness review in `/maxi:analyze` before implementation, and the upstream SDD final implementation review. `/maxi:review` dispatches `skills/review/design-reviewer.md` with the complete exact current `spec.md`, `plan.md`, and accepted ADRs named by `spec.md`'s `related_adrs`, then writes `reviews/design-review.md` only after one exact terminal verdict. Task `Files` lists are expected primary edits rather than implementation allowlists; mechanical closure is nonblocking unless the reviewed design itself must change. A missing or stale approval stops task extraction before any write. Corrections stop after their owner write and never start a review or successor phase. Re-review is an explicit `/maxi:review` request.

Upstream SDD owns the only whole-branch review. Before dispatch, internal `x-develop` persists the immutable initial task-selection anchor in the ordinary SDD ledger. It also owns immutable task projection, ledger reconciliation, persisted harness reviewer identity, byte-exact Git review packages, and the hash-bound terminal receipt. It returns `READY_TO_FINISH` only when all evidence validates. `implement` owns the sole `implementing → done` transition and never dispatches a duplicate final review.

The 19 Maxi-native skills remain in place; the 10-state FSM remains unchanged. `/maxi:x-develop` maps canonical Maxi `TNNN` tasks to an immutable SDD `Task N` projection. Upstream SDD owns task review, fix rounds, and the final implementation review. `/maxi:x-develop` is the sole incremental Maxi checkbox owner; `/maxi:implement` validates that every task is checked and alone persists `implementing → done`. Branch finishing starts only after Maxi has recorded `done`.

Only canonical annotated upstream completion records acquit tasks; bare or malformed completion lines fail closed. The accepted annotations are `review clean` or a positive `K parked`, with exactly two seven-hex commit IDs.

A null fix package requires exactly `**Ready to merge?** Yes`; a non-null byte-exact fix package requires the initial `**Ready to merge?** With fixes` plus exactly `**Fix round:** All findings addressed, no new Critical/Important breakage`.

Every projection's exact distributed bytes are SHA-256-bound by its ordinary SDD ledger; missing, duplicate, malformed, or mismatched projection-byte anchors fail closed across the current and predecessor lineage.

Removing an anchored incomplete `TNNN` during structural correction fails before successor creation and leaves the active-projection pointer unchanged.

Complete ledger lines containing `Ruling:` are preserved byte-for-byte in lineage order and hash-bound by the terminal receipt.

Skills read this to enforce phase gating. Never bypass it.

## Pipeline Documentation — Mandatory Sync

**Any change to the pipeline — new skill, new FSM status, new phase transition, changed gating rule — MUST update all five of these in the same commit:**

1. **`docs/pipeline-flow.md`** — Mermaid diagram, legend, FSM status set diagram, and notes.
2. **`docs/delegation-map.md`** — Forward pipeline table and lifecycle skills table (required status, delegates to, status transition).
3. **`skills/using-maxi/SKILL.md`** — Phase gating table and status state machine string (injected at every session start — stale content misleads agents from turn 0).
4. **`AGENTS.md`** (this file) — Skill count in Overview, status field values in Status Frontmatter, fast-tier descriptions, and integration test list.
5. **`docs/architecture.md`** — maxi-native skill count + breakdown in the layered-architecture overview, and the `skills/` file tree.

**This is not optional.** The 2026-05-24 design review found that `using-maxi` had been injecting a stale phase-gating table for every session after the strict-pipeline decision — because only the skill implementations were updated, not the documentation. The 2026-05-30 brownfield-skill review found `docs/architecture.md` left at a stale skill count for the same reason — it stated the count but was not in this list. That class of bug is prevented by updating all five files atomically.

**Now partly automated:** `check-skill-count.sh` and `check-status-consistency.sh` fail the fast tier if skill counts or the status set drift between docs; `check-artifact-link-convention.sh` guards the duplicated "Artifact reference links" block. Run the `doc-consistency` skill (`.claude/skills/doc-consistency/` or `.agents/skills/doc-consistency/`) before a release for prose-level drift the deterministic checks can't catch.

## Testing

Run `bash tests/run-all.sh` after changes.

**Fast tier** (~2min, no agent runtime, runs by default):
- `check-frontmatter.sh` — every `skills/*/SKILL.md` has valid YAML frontmatter
- `check-sync-invariant.sh` — vendored skills in `skills/` are byte-identical to `vendor/superpowers/skills/`
- `check-spec-fixture.sh` — spec fixture has valid `slug`/`created` fields (the 10-status consistency check now lives in `check-status-consistency.sh`)
- `check-templates.sh` — all 6 maxi templates + 2 fixtures have required fields and body sections, including the single Global Constraints section
- `check-global-constraints.sh` — fixture-backed durable Global Constraints outcomes and planner guidance remain aligned
- `check-review-boundaries.sh` — the three fixed review boundaries, explicit re-review, and terminal corrections remain aligned
- `check-x-develop-adapter.sh` — immutable task projection, lineage reconciliation, final-review identity/package validation, and terminal receipts remain fail-closed
- `check-implement-handoff.sh` — `implement`/`x-develop` ownership and Mandatory Sync 5 terminal-gate contracts remain aligned
- `check-skills-present.sh` — all 19 maxi-native skills and targeted support files exist
- `check-revise.sh` — completed-spec reopening and explicit-consent invariants remain aligned
- `check-migrate-adr.sh` — `migrate-adr` skill/script behaves correctly
- `check-plugin-manifest.sh` — `.claude-plugin/plugin.json` is valid JSON with required fields
- `check-declarative-harnesses.sh` — Cursor, Kimi, Devin, and Gemini manifests match `package.json`, Kimi/Gemini bootstrap wiring is complete, and Pi remains project-gated
- `check-hermes-plugin.sh` — Hermes registers every skill, injects the short first-turn bootstrap only in Maxi projects, and stays below the 10,000-character limit
- `check-codex-plugin.sh` — `.codex-plugin/plugin.json` (`hooks: {}`), `.agents/plugins/marketplace.json`, and `plugins/maxi` are valid for Codex plugin installation
- `check-hooks.sh` — `hooks/hooks.json` (Claude Code + Antigravity) and `hooks/hooks-cursor.json` manifests are valid; the unified `hooks/session-start` exists, is executable, and emits the right JSON shape per harness; stale per-harness wrappers and the `.antigravity-plugin/` directory are gone
- `check-cursor-hooks.sh` — `hooks/hooks-cursor.json` is a valid Cursor `sessionStart` manifest invoking `hooks/session-start`
- `check-vendored-doc.sh` — `VENDORED.md` has required version/date lines (regression guard for `bump-superpowers.sh`)
- `check-sync-script.sh` — `sync-superpowers.sh` copies vendor skills and leaves maxi-native skills untouched
- `check-bump-script.sh` — `_update-vendored-md.sh` correctly updates version and date lines
- `check-migrate-from-speckit.sh` — `migrate-from-speckit` detects `.specify/` and migrates non-destructively
- `check-migrate-from-brownfield.sh` — `migrate-from-brownfield`'s `brownfield.sh` (guard / write-spec / exclude) behaves correctly
- `check-opencode-plugin.sh` — `.opencode/plugins/maxi.js` exports required hooks, has bootstrap caching and conditional injection
- `check-bootstrap-parity.sh` — the `<EXTREMELY_IMPORTANT>` bootstrap preamble is identical across `hooks/session-start`, `.opencode/plugins/maxi.js`, and `.pi/extensions/maxi.ts`
- `check-pi-extension.sh` — `.pi/extensions/maxi.ts` and `package.json` `pi` section are valid (Pi harness packaging)
- `check-integration-harness.sh` — optional Codex integration harness stays runnable on macOS without GNU `timeout`, keeps prompt discovery guarded, and verifies one completed JSONL command result read the byte-checked installed skill snapshot
- `integration/test-codex-timeout.sh` — macOS Perl deadline-supervisor regression runs in the fast tier, including material plugin staging and timeout status 124
- `check-doc-consistency-skill.sh` — local doc-consistency skills stay aligned with the Mandatory Sync 5 rule
- `check-release-skill.sh` — release instructions keep the fast-tier/doc-consistency gates, bump and stage all eight manifests, derive the plugin name from `.claude-plugin/plugin.json`, and leave marketplace pinning in commit 2
- `check-skill-count.sh` — maxi-native skill count, documented review contracts, and Mandatory Sync 5 durable-plan sentence match the filesystem
- `check-status-consistency.sh` — the 10 FSM statuses are consistent across spec-template, board, and AGENTS.md
- `check-artifact-link-convention.sh` — the duplicated artifact-link block is byte-identical to the canonical fixture
- `check-version-consistency.sh` — superpowers version citations in `README.md`/`docs/architecture.md`/`docs/delegation-map.md` match the `VENDORED.md` pin

**Integration tier** (opt-in, requires authenticated `codex` CLI, ~minutes):
```
bash tests/run-all.sh --integration
```
Runs `tests/integration/run-all.sh`: every prompt in `tests/integration/prompts/*.txt` runs in an isolated local Codex marketplace and is checked to assert one completed JSONL command result reads the byte-checked matching skill snapshot.
