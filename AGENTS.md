# maxi-superpowers — Contributor Guidelines

## Overview

maxi-superpowers is a multi-harness plugin aligned 1:1 with the superpowers v6.3.0 harness model (Claude Code · Codex · OpenCode · Antigravity · Cursor · Pi; plus Kimi Code, Factory Droid, and GitHub Copilot CLI via marketplace docs). It vendors superpowers' skills via git subtree and adds 19 maxi-native skills: 12 user-facing commands (`constitution`, `specify`, `clarify`, `plan`, `tasks`, `analyze`, `implement`, `board`, `cancel`, `park`, `resume`, `revise`), 3 internal pipeline skills (`x-adr`, `x-develop`, `x-review`), 1 session skill (`using-maxi`), and 3 migration utilities (`migrate-from-speckit`, `migrate-from-brownfield`, `migrate-adr`).

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

Spec→ADR traceability is recorded spec-side: `spec.md` frontmatter carries `related_adrs: [...]` (a list of full ADR slugs), the canonical spec→ADR link, written by `x-adr` when an ADR is accepted. ADRs themselves no longer carry `related_specs`/`related_principles`/`related_requirements` — an ADR is a self-contained record (metadata + supersession chain), and traceability lives spec-side (ADR-0012).

## Status Frontmatter

Every `spec.md` has a YAML frontmatter `status:` field:
`drafting | specified | clarified | planned | tasked | analyzed | implementing | done | parked | cancelled`

The 10-state FSM remains unchanged. For a marker-bound root, `reviews/spec-review.md` gates `plan`, and `reviews/plan-review.md` gates `tasks`; both records are persisted and versioned by internal `x-review`. These external review handoffs are gates, not statuses or automatic replay phases. The read-only `skills/revise/replay-plan.sh` planner calculates bounded replay proposals and never writes artifacts, creates or approves reviews, or executes phases. `revise` reserves the exceptional `specified` rollback for a demonstrated source-spec gap and resumes replay at `clarify`, never `specify`.

Bounded replay is future-only. Eligible roots carry exactly one `replay_contract: bounded-v1`; only `/maxi:specify` writes this marker, during normal forward-spec creation. An unmarked existing, migrated, or reverse-engineered spec returns `UNSUPPORTED_LEGACY`; revision metadata alone never opts it in.

For a marker-bound root, `reviewed_sha256` hashes the canonical structural projection, which omits only root-frontmatter `status:` and `updated:`, preserves every other line in order, and hashes one LF after each retained line. The exact ten-field review envelope is `revision`, `writer_context`, `structural_contributors`, `derived_from`, `reviewed_document`, `reviewed_revision`, `reviewed_sha256`, `reviewer_context`, `reviewer_context_matches_harness`, and `verdict`. Before delegation, artifact write, or status/timestamp change, `plan` and `tasks` require positive record and reviewed revisions, exactly one mapped direct input, the exact current subject/revision/digest, canonical unique contributors and contexts, writer equals reviewer and appears in contributors, harness equality exactly `true`, verdict exactly `approved`, and reviewer independence from the subject contributors.

The persisted continuation is `replay_continuation: clarify@<current-spec-revision>` after the exceptional source rollback; `/maxi:clarify` can re-present it with `--resume-current-source` after rejection, ambiguity, or interruption. `--resume-current-source` is legal only for `spec.md`, start phase `clarify`, and that matching current marker. Clarification replaces it with `replay_continuation: plan@<current-spec-revision>`. After `x-review` writes the matching spec review, `/maxi:plan` can re-present the spec review continuation with `--resume-current-review`; a consented plan write persists `replay_continuation: tasks@<current-plan-revision>`. After the matching plan review, `/maxi:tasks` can re-present the plan review continuation with `--resume-current-review`. `--resume-current-review` accepts exactly two combinations: `reviews/spec-review.md` with `plan`, or `reviews/plan-review.md` with `tasks`; both require the current subject and review plus every transitive `derived_from` ancestor. Each displayed executable segment requires its own fresh literal `yes`.

Before plan resume, a stale `spec.md`, support artifact, or specification review is rejected before any continuation output or write, even when `plan.md` and its plan review still match.

An explicit owner-managed plan correction is available only when explicitly requested at `planned`, `tasked`, `analyzed`, or `implementing`; it preserves the current spec-review gate, writes `replay_continuation: tasks@<current-plan-revision>` with the corrected plan, and returns only to `planned`. An explicit owner-managed tasks correction is available only when explicitly requested at `tasked`, `analyzed`, or `implementing`; it preserves the current plan-review gate and returns only to `tasked`. After `x-review` writes a marker-bound approved plan review, it immediately invokes the read-only planner with the predecessor review revision and displays the current approved `tasks -> analyze` continuation. `x-review` never executes a phase or obtains consent. For that marker-bearing corrected plan, `/maxi:tasks` is only the later no-write resume presenter: it invokes the read-only planner with `--resume-current-review`, redisplays that continuation, and requires a fresh literal `yes` before extraction. Rejection, ambiguity, or session interruption changes nothing and the same current review can be presented again.

Only new specs created through the normal forward pipeline receive this revision and replay behavior; existing, migrated, and reverse-engineered specs remain untouched. For an unmarked root, plan and tasks use the ordinary pipeline: no review record, x-review handoff, review provenance, review reporting, or replay planner is required. This mechanism never creates or writes `workflow.md` or `.maxi-ops`.

Upstream SDD owns the only whole-branch review. Before dispatch, internal `x-develop` persists the immutable initial task-selection anchor in the ordinary SDD ledger. It also owns immutable task projection, ledger reconciliation, persisted harness reviewer identity, byte-exact Git review packages, and the hash-bound terminal receipt. It returns `READY_TO_FINISH` only when all evidence validates. `implement` owns the sole `implementing → done` transition and never dispatches a duplicate final review.

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
- `check-templates.sh` — all 6 maxi templates + 2 fixtures have required fields and body sections
- `check-bounded-replay.sh` — future-forward revision metadata, review gates, bounded replay, literal consent, and no-write behavior remain aligned
- `check-x-develop-adapter.sh` — immutable task projection, lineage reconciliation, final-review identity/package validation, and terminal receipts remain fail-closed
- `check-implement-handoff.sh` — `implement`/`x-develop` ownership and Mandatory Sync 5 terminal-gate contracts remain aligned
- `check-x-review.sh` — `x-review` preserves the independent review envelope, provenance validation, and versioned record contract
- `check-skills-present.sh` — all 19 maxi-native skills and targeted support files exist
- `check-plugin-manifest.sh` — `.claude-plugin/plugin.json` is valid JSON with required fields
- `check-codex-plugin.sh` — `.codex-plugin/plugin.json` (`hooks: {}`), `.agents/plugins/marketplace.json`, and `plugins/maxi` are valid for Codex plugin installation
- `check-hooks.sh` — `hooks/hooks.json` (Claude Code + Antigravity) and `hooks/hooks-cursor.json` manifests are valid; the unified `hooks/session-start` exists, is executable, and emits the right JSON shape per harness; stale per-harness wrappers and the `.antigravity-plugin/` directory are gone
- `check-cursor-hooks.sh` — `hooks/hooks-cursor.json` is a valid Cursor `sessionStart` manifest invoking `hooks/session-start`
- `check-vendored-doc.sh` — `VENDORED.md` has required version/date lines (regression guard for `bump-superpowers.sh`)
- `check-sync-script.sh` — `sync-superpowers.sh` copies vendor skills and leaves maxi-native skills untouched
- `check-bump-script.sh` — `_update-vendored-md.sh` correctly updates version and date lines
- `check-opencode-plugin.sh` — `.opencode/plugins/maxi.js` exports required hooks, has bootstrap caching and conditional injection
- `check-pi-extension.sh` — `.pi/extensions/maxi.ts` and `package.json` `pi` section are valid (Pi harness packaging)
- `check-bootstrap-parity.sh` — the `<EXTREMELY_IMPORTANT>` bootstrap preamble is identical across `hooks/session-start`, `.opencode/plugins/maxi.js`, and `.pi/extensions/maxi.ts`
- `check-integration-harness.sh` — optional Codex integration harness stays runnable on macOS without GNU `timeout`, keeps prompt discovery guarded, and verifies one completed JSONL command result read the byte-checked installed skill snapshot
- `test-codex-timeout.sh` — macOS Perl deadline-supervisor regression runs in the fast tier, including material plugin staging and timeout status 124
- `check-doc-consistency-skill.sh` — local doc-consistency skills stay aligned with the Mandatory Sync 5 rule
- `check-release-skill.sh` — local release skill keeps the fast-tier and doc-consistency pre-flight gates
- `check-migrate-adr.sh` — `migrate-adr` skill/script behaves correctly
- `check-migrate-from-speckit.sh` — `migrate-from-speckit` detects `.specify/` and migrates non-destructively
- `check-migrate-from-brownfield.sh` — `migrate-from-brownfield`'s `brownfield.sh` (guard / write-spec / exclude) behaves correctly
- `check-skill-count.sh` — maxi-native skill count and documented review/replay contracts match the filesystem and Mandatory Sync 5
- `check-status-consistency.sh` — the 10 FSM statuses are consistent across spec-template, board, and AGENTS.md
- `check-artifact-link-convention.sh` — the duplicated artifact-link block is byte-identical to the canonical fixture
- `check-version-consistency.sh` — superpowers version citations in `README.md`/`docs/architecture.md`/`docs/delegation-map.md` match the `VENDORED.md` pin

**Integration tier** (opt-in, requires authenticated `codex` CLI, ~minutes):
```
bash tests/run-all.sh --integration
```
Runs `tests/integration/run-all.sh`: every prompt in `tests/integration/prompts/*.txt` runs in an isolated local Codex marketplace and is checked to assert one completed JSONL command result reads the byte-checked matching skill snapshot.
