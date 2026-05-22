# maxi-superpowers — Contributor Guidelines

## Overview

maxi-superpowers is a Claude Code plugin. It vendors superpowers' skills via git subtree and adds 10 maxi-native skills: 7 user-facing commands (`constitution`, `specify`, `clarify`, `plan`, `tasks`, `analyze`, `implement`), 1 internal pipeline skill (`adr`), 1 session skill (`using-maxi`), and 1 migration utility (`migrate-from-speckit`).

## Developing New Skills

All new skills MUST be authored using `superpowers:writing-skills`. Do not hand-write SKILL.md files.

The writing-skills TDD cycle:
1. RED: run pressure scenario WITHOUT skill — document failures
2. GREEN: invoke `superpowers:writing-skills` with behavioral spec
3. REFACTOR: add explicit counters for any new rationalizations

## Vendored Skills

`skills/` contains a mix of vendored (from superpowers) and maxi-native skills.
- **Do NOT hand-edit vendored skills.** Run `scripts/sync-superpowers.sh` to re-sync.
- **To bump superpowers version:** run `scripts/bump-superpowers.sh <tag>`

## Artifact Convention

Per-project artifacts live at the user's project root:
- `docs/constitution.md` — project principles
- `docs/maxi/adr/` — Architecture Decision Records (auto-captured, NNN-slug.md format)
- `docs/maxi/specs/NNN-slug/` — spec, plan, tasks, analysis per feature

## Status Frontmatter

Every `spec.md` has a YAML frontmatter `status:` field:
`drafting | specified | clarified | planned | tasked | analyzed | implementing | done`

Skills read this to enforce phase gating. Never bypass it.

## Testing

Run `bash tests/run-all.sh` after changes.

**Fast tier** (~10s, no Claude runtime, runs by default):
- `check-frontmatter.sh` — every `skills/*/SKILL.md` has valid YAML frontmatter
- `check-sync-invariant.sh` — vendored skills in `skills/` are byte-identical to `vendor/superpowers/skills/`
- `check-spec-fixture.sh` — spec fixture has `slug`/`created`/`status` fields; all 8 status values round-trip
- `check-templates.sh` — all 5 maxi templates + 2 fixtures have required fields and body sections
- `check-skills-present.sh` — all 10 maxi-native skills exist
- `check-plugin-manifest.sh` — `.claude-plugin/plugin.json` is valid JSON with required fields
- `check-hooks.sh` — `hooks/hooks.json` is valid; hook scripts exist and are executable
- `check-vendored-doc.sh` — `VENDORED.md` has required version/date lines (regression guard for `bump-superpowers.sh`)
- `check-sync-script.sh` — `sync-superpowers.sh` copies vendor skills and leaves maxi-native skills untouched
- `check-bump-script.sh` — `_update-vendored-md.sh` correctly updates version and date lines

**Integration tier** (opt-in, requires `claude` CLI, ~minutes):
```
bash tests/run-all.sh --integration
```
Runs `tests/integration/run-all.sh`: 7 naive prompts that assert each maxi command skill (`/maxi:specify`, `/maxi:clarify`, `/maxi:plan`, `/maxi:tasks`, `/maxi:analyze`, `/maxi:implement`, `/maxi:constitution`) auto-triggers via the Skill tool.
