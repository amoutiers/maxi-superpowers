---
adr: 0013
slug: 0013-tri-harness-support-strategy
status: superseded
created: 2026-05-31
updated: 2026-06-22
decider: Antoine Moutiers
supersedes: 0004
superseded_by: 0014
---

# ADR-0013: Tri-Harness Support Strategy — Claude Code · OpenCode · Antigravity

## Context

ADR-0004 committed to two harnesses (Claude Code + OpenCode). The repo since gained
Antigravity compatibility manifests (root `hooks.json` + `plugin.json` via
`${extensionPath}`, validated by `check-hooks.sh` / `check-plugin-manifest.sh`), plus an
exploratory Cursor shim (a `CURSOR_PLUGIN_ROOT` branch in `hooks/session-start`) and a
Copilot CLI branch. The Cursor shim was built on the wrong mechanism — Cursor ≥ 1.7 uses
`.cursor/hooks.json` + the `sessionStart` event, not `${extensionPath}` /
`CURSOR_PLUGIN_ROOT` — so it never fired. The supported harness set was stated
inconsistently across `architecture.md`, `CLAUDE.md`, and `README.md`.

## Decision

The officially supported harnesses are **Claude Code, OpenCode, and Antigravity**.

- Antigravity entry points: root `hooks.json` + `plugin.json` (`${extensionPath}`).
- **Cursor is dropped** for now: the dead `CURSOR_PLUGIN_ROOT` branch is removed from
  `hooks/session-start`. Real Cursor support (`.cursor/hooks.json`, `sessionStart`) is
  deferred to a future ADR/spec.
- Copilot CLI and legacy Gemini CLI are **not** promoted (legacy Gemini documented as
  legacy; Antigravity is its successor).

This supersedes ADR-0004.

## Consequences

- `architecture.md`, `CLAUDE.md`, and `README.md` state the same tri-harness set.
- No documentation claims a harness as supported without a verified mechanism.
- The Cursor dead code is removed. `spec 0008-session-bootstrap` is left intact: it is a
  reverse-engineered as-built snapshot pinned to its `source_sha` (pre-removal), so it
  correctly documents the behaviour at that commit and is not retro-edited.
