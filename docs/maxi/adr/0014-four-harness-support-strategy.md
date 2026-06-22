---
adr: 0014
slug: 0014-four-harness-support-strategy
status: superseded
created: 2026-06-22
updated: 2026-06-22
decider: "Antoine Moutiers"
supersedes: 0013
superseded_by: 0015
---

# ADR-0014: Four-Harness Support Strategy

## Context

ADR-0013 established a tri-harness strategy: Claude Code, OpenCode, and
Antigravity. Since then, the repository has grown a Codex packaging surface with
`.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`, and
`plugins/maxi`. Local Codex verification also shows the installed maxi plugin
registering a `SessionStart` hook through `hooks/hooks.json`.

The repository therefore has four practical supported harnesses, but the
architecture docs and ADR log still describe the older tri-harness decision.
This creates drift between the distributed package, tests, and architectural
record.

## Decision Drivers

- **Principle V: Artifacts Over Chat**: support status must be recorded in files,
  not inferred from a local session.
- **No documentation claims without a verified mechanism**: each supported
  harness needs a concrete packaging or bootstrap entry point.
- **Compatibility preservation**: existing Claude Code, OpenCode, and
  Antigravity entry points must remain stable.
- **Testable ownership**: hook and manifest roles must be guarded by fast-tier
  checks.

## Considered Options

- **Option A: Four supported harnesses: Claude Code, Codex, OpenCode, Antigravity**
  - ✅ Satisfies driver: matches the actual repository packaging surface.
  - ✅ Satisfies driver: Codex has concrete manifests and local hook registration
    evidence.
  - ✅ Satisfies driver: preserves existing Claude Code, OpenCode, and
    Antigravity support.
  - ❌ Adds one more harness ownership surface to document and test.

- **Option B: Keep ADR-0013 tri-harness and describe Codex as experimental**
  - ✅ Smaller documentation change.
  - ❌ Violates driver: the repo already has tracked Codex manifests and tests.
  - ❌ Violates driver: local Codex hook registration contradicts skills-only
    documentation.

- **Option C: Remove Codex packaging until hook behavior is fully characterized**
  - ✅ Simplifies the support matrix.
  - ❌ Violates driver: removes useful working support.
  - ❌ Violates driver: regresses current users and current tests.

## Decision

Chose **Option A**. maxi officially supports four harnesses:

- Claude Code: `.claude-plugin/plugin.json`, marketplace metadata, and
  `hooks/hooks.json` / `hooks/hooks-claude.json`.
- Codex: `.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`,
  `plugins/maxi`, and locally verified `hooks/hooks.json` SessionStart
  registration.
- OpenCode: `.opencode/plugins/maxi.js`.
- Antigravity: root `plugin.json`, root `hooks.json`, and
  `hooks/session-start-antigravity`.

`hooks/hooks-codex.json` and `hooks/session-start-codex` remain in the repository
as Codex-oriented compatibility assets until Codex hook manifest selection is
fully characterized.

This supersedes ADR-0013.

## Consequences

- **Good:** README, architecture docs, tests, and ADRs can converge on one
  support matrix.
- **Good:** Codex support is no longer under-documented.
- **Good:** Hook ownership is explicit: root `hooks.json` and
  `hooks/session-start-antigravity` are Antigravity, `hooks/hooks.json` is the
  default plugin hook, `hooks/hooks-claude.json` is the Claude alias, and
  `hooks/hooks-codex.json` is the Codex-oriented compatibility manifest.
- **Bad:** The support matrix remains more complex than a single-harness plugin.
- **Bad:** Codex hook selection is based on local verification rather than a
  fully characterized public contract, so tests must avoid overclaiming which
  Codex manifest is authoritative.

Superseded note (2026-06-22): ADR-0015 moved Antigravity installation to the
dedicated `.antigravity-plugin` package and Codex hook selection to
`.codex-plugin/plugin.json`.

## Confirmation

- `README.md` documents Codex as a supported harness with native skills and
  locally verified plugin hook registration.
- `docs/architecture.md` lists all four harnesses and records hook manifest
  ownership.
- `tests/check-hooks.sh` verifies each hook manifest targets the intended hook
  script.
- `tests/check-codex-plugin.sh` verifies Codex manifests, marketplace wiring, and
  Codex-specific release skill paths.
- `bash tests/run-all.sh` passes.
