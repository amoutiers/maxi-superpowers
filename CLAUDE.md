# maxi-superpowers — Contributor Guidelines

## Overview

maxi-superpowers is a Claude Code plugin. It vendors superpowers' skills via git subtree and adds 8 maxi-native skills: 7 user-facing commands (`constitution`, `specify`, `clarify`, `plan`, `tasks`, `analyze`, `implement`) and 1 internal skill (`adr`).

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

Run `bash tests/run-all.sh` after changes (runs frontmatter, sync-invariant, and spec-fixture checks).
