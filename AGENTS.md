# maxi-superpowers — Contributor Guidelines

## Overview

maxi-superpowers is a multi-harness plugin for Claude Code, Codex, OpenCode, and Antigravity. It vendors superpowers' skills via git subtree and adds 18 maxi-native skills: 12 user-facing commands (`constitution`, `specify`, `clarify`, `plan`, `tasks`, `analyze`, `implement`, `board`, `cancel`, `park`, `resume`, `revise`), 2 internal pipeline skills (`x-adr`, `x-develop`), 1 session skill (`using-maxi`), and 3 migration utilities (`migrate-from-speckit`, `migrate-from-brownfield`, `migrate-adr`).

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

**Fast tier** (~10s, no agent runtime, runs by default):
- `check-frontmatter.sh` — every `skills/*/SKILL.md` has valid YAML frontmatter
- `check-sync-invariant.sh` — vendored skills in `skills/` are byte-identical to `vendor/superpowers/skills/`
- `check-spec-fixture.sh` — spec fixture has valid `slug`/`created` fields (the 10-status consistency check now lives in `check-status-consistency.sh`)
- `check-templates.sh` — all 5 maxi templates + 2 fixtures have required fields and body sections
- `check-skills-present.sh` — all 18 maxi-native skills exist
- `check-plugin-manifest.sh` — `.claude-plugin/plugin.json` is valid JSON with required fields
- `check-codex-plugin.sh` — `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`, and `plugins/maxi` are valid for Codex plugin installation
- `check-hooks.sh` — hook manifests are valid; hook scripts exist and are executable
- `check-vendored-doc.sh` — `VENDORED.md` has required version/date lines (regression guard for `bump-superpowers.sh`)
- `check-sync-script.sh` — `sync-superpowers.sh` copies vendor skills and leaves maxi-native skills untouched
- `check-bump-script.sh` — `_update-vendored-md.sh` correctly updates version and date lines
- `check-opencode-plugin.sh` — `.opencode/plugins/maxi.js` exports required hooks, has bootstrap caching and conditional injection
- `check-bootstrap-parity.sh` — the `<EXTREMELY_IMPORTANT>` bootstrap preamble is identical across `hooks/session-start-core` and `.opencode/plugins/maxi.js`
- `check-integration-harness.sh` — optional integration harness stays runnable on macOS without GNU `timeout` and keeps prompt discovery guarded
- `check-doc-consistency-skill.sh` — local doc-consistency skills stay aligned with the Mandatory Sync 5 rule
- `check-release-skill.sh` — local release skill keeps the fast-tier and doc-consistency pre-flight gates
- `check-migrate-adr.sh` — `migrate-adr` skill/script behaves correctly
- `check-migrate-from-speckit.sh` — `migrate-from-speckit` detects `.specify/` and migrates non-destructively
- `check-migrate-from-brownfield.sh` — `migrate-from-brownfield`'s `brownfield.sh` (guard / write-spec / exclude) behaves correctly
- `check-skill-count.sh` — maxi-native skill count (derived from the filesystem) matches AGENTS.md + architecture.md
- `check-status-consistency.sh` — the 10 FSM statuses are consistent across spec-template, board, and AGENTS.md
- `check-artifact-link-convention.sh` — the duplicated artifact-link block is byte-identical to the canonical fixture
- `check-version-consistency.sh` — superpowers version citations in `README.md`/`docs/architecture.md`/`docs/delegation-map.md` match the `VENDORED.md` pin

**Integration tier** (opt-in, requires `claude` CLI, ~minutes):
```
bash tests/run-all.sh --integration
```
Runs `tests/integration/run-all.sh`: every prompt in `tests/integration/prompts/*.txt` is checked to assert the matching maxi skill auto-triggers via the Skill tool.
