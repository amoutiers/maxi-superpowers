# maxi-superpowers — Contributor Guidelines

## Overview

maxi-superpowers is a dual-harness plugin for Claude Code and OpenCode. It vendors superpowers' skills via git subtree and adds 17 maxi-native skills: 12 user-facing commands (`constitution`, `specify`, `clarify`, `plan`, `tasks`, `analyze`, `implement`, `board`, `cancel`, `park`, `resume`, `revise`), 2 internal pipeline skills (`x-adr`, `x-develop`), 1 session skill (`using-maxi`), and 2 migration utilities (`migrate-from-speckit`, `migrate-adr`).

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

## Status Frontmatter

Every `spec.md` has a YAML frontmatter `status:` field:
`drafting | specified | clarified | planned | tasked | analyzed | implementing | done | parked | cancelled`

Skills read this to enforce phase gating. Never bypass it.

## ⚠️ Pipeline Documentation — Mandatory Sync

**Any change to the pipeline — new skill, new FSM status, new phase transition, changed gating rule — MUST update all four of these in the same commit:**

1. **`docs/pipeline-flow.md`** — Mermaid diagram, legend, FSM status set diagram, and notes.
2. **`docs/delegation-map.md`** — Forward pipeline table and lifecycle skills table (required status, delegates to, status transition).
3. **`skills/using-maxi/SKILL.md`** — Phase gating table and status state machine string (injected at every session start — stale content misleads Claude from turn 0).
4. **`CLAUDE.md`** (this file) — Skill count in Overview, status field values in Status Frontmatter, fast-tier descriptions, and integration test list.

**This is not optional.** The 2026-05-24 design review found that `using-maxi` had been injecting a stale phase-gating table for every session after the strict-pipeline decision — because only the skill implementations were updated, not the documentation. That class of bug is prevented by updating all four files atomically.

## Testing

Run `bash tests/run-all.sh` after changes.

**Fast tier** (~10s, no Claude runtime, runs by default):
- `check-frontmatter.sh` — every `skills/*/SKILL.md` has valid YAML frontmatter
- `check-sync-invariant.sh` — vendored skills in `skills/` are byte-identical to `vendor/superpowers/skills/`
- `check-spec-fixture.sh` — spec fixture has `slug`/`created`/`status` fields; all 10 status values round-trip
- `check-templates.sh` — all 5 maxi templates + 2 fixtures have required fields and body sections
- `check-skills-present.sh` — all 17 maxi-native skills exist
- `check-plugin-manifest.sh` — `.claude-plugin/plugin.json` is valid JSON with required fields
- `check-hooks.sh` — `hooks/hooks.json` is valid; hook scripts exist and are executable
- `check-vendored-doc.sh` — `VENDORED.md` has required version/date lines (regression guard for `bump-superpowers.sh`)
- `check-sync-script.sh` — `sync-superpowers.sh` copies vendor skills and leaves maxi-native skills untouched
- `check-bump-script.sh` — `_update-vendored-md.sh` correctly updates version and date lines
- `check-opencode-plugin.sh` — `.opencode/plugins/maxi.js` exports required hooks, has bootstrap caching and conditional injection
- `check-bootstrap-parity.sh` — the `<EXTREMELY_IMPORTANT>` bootstrap preamble is identical across `hooks/session-start` and `.opencode/plugins/maxi.js`
- `check-migrate-adr.sh` — `migrate-adr` skill/script behaves correctly
- `check-migrate-from-speckit.sh` — `migrate-from-speckit` detects `.specify/` and migrates non-destructively

**Integration tier** (opt-in, requires `claude` CLI, ~minutes):
```
bash tests/run-all.sh --integration
```
Runs `tests/integration/run-all.sh`: 12 naive prompts that assert each maxi command skill (`/maxi:specify`, `/maxi:clarify`, `/maxi:plan`, `/maxi:tasks`, `/maxi:analyze`, `/maxi:implement`, `/maxi:constitution`, `/maxi:board`, `/maxi:cancel`, `/maxi:park`, `/maxi:resume`, `/maxi:revise`) auto-triggers via the Skill tool.
