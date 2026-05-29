---
adr: 0006
slug: 0006-dual-tag-release-strategy
status: accepted
created: 2026-05-29
updated: 2026-05-29
decider: "[inferred] Antoine Moutiers"
related_specs: []
related_principles: []
related_requirements: []
supersedes: null
superseded_by: null
---

# ADR-0006: Dual-Tag Release Strategy — Semver Tag + Plugin-Name Tag

## Context

The Claude Code plugin marketplace requires a pinned commit reference in
`marketplace.json`. As the project grew, two release tag types emerged: `v*`
(semver, e.g. `v1.1.0`) and `maxi--v*` (plugin-name prefix, e.g.
`maxi--v1.1.0`). The `maxi--v*` format was adopted to satisfy a marketplace
or plugin-install convention that uses the plugin name as a tag prefix.
However, this dual-tag approach caused an immediate problem: `git-cliff` (the
changelog generator) matched both tag formats and generated a spurious
`[maxi--v1.0.0]` changelog section. A fix commit
(`fix(release): exclude plugin-name tags from changelog`) added
`ignore_tags = ".*--v[0-9]*"` to `cliff.toml` to suppress plugin-name tags
from changelog generation.

## Decision Drivers

- **Marketplace pinning**: `marketplace.json` must reference a specific commit;
  the release pipeline must produce a stable tag that marketplace consumers can
  reference.
- **Changelog integrity**: only semver (`v*`) tags should generate changelog
  sections; plugin-name tags are internal distribution markers.
- **Automation**: the GitHub Actions release workflow triggers on `v*` tag push;
  plugin-name tags must not trigger duplicate release runs.

## Considered Options

- **Option A: Dual tags — `v<N>` (semver) + `maxi--v<N>` (plugin-name prefix)**
  Both tags pushed at release time. `cliff.toml` filters out `maxi--v*` via
  `ignore_tags`. `marketplace.json` references the `v*` commit SHA directly.
  - ✅ Marketplace convention satisfied if tooling requires the plugin-name prefix
  - ✅ `ignore_tags` cleanly suppresses plugin-name changelog sections
  - ❌ Two tags per release; contributors must push both
  - ❌ `ignore_tags` is a workaround for a problem introduced by the dual-tag
    design itself

- **Option B: Single semver tag only (`v<N>`)**
  Only push `v*`; reference the commit SHA in `marketplace.json`.
  - ✅ Simpler — one tag per release; no `cliff.toml` workaround needed
  - ❌ Plugin-name convention not satisfied if marketplace tooling requires it

## Decision

[inferred] Chose **Option A**. The `maxi--v*` tag was first pushed alongside
`v1.0.0` (`maxi--v1.0.0` and `maxi--v1.1.0` both exist in the repo). The
changelog pollution was discovered and fixed by adding
`ignore_tags = ".*--v[0-9]*"` to `cliff.toml`.

## Consequences

- **Good:** Plugin-name tags are available if marketplace tooling ever requires
  them.
- **Good:** `cliff.toml ignore_tags` cleanly suppresses plugin-name entries from
  the changelog.
- **Bad:** Every release requires pushing two tags; the `/release` skill must
  handle both.
- **Bad:** The `ignore_tags` regex is a non-obvious workaround that future
  contributors may not understand without this ADR.

## Confirmation

- `cliff.toml` contains `ignore_tags = ".*--v[0-9]*"`.
- `git tag --list` shows both `v*` and `maxi--v*` tags for each release.
- The GitHub Actions `release.yml` triggers on `tags: ['v*']` only, preventing
  duplicate release runs from plugin-name tags.
