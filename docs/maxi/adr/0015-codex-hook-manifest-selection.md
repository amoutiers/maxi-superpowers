---
adr: 0015
slug: 0015-codex-hook-manifest-selection
status: superseded
created: 2026-06-22
updated: 2026-07-04
decider: "Antoine Moutiers"
supersedes: 0014
superseded_by: 0016
---

# ADR-0015: Codex Hook Manifest Selection

## Context

ADR-0014 promoted Codex to a supported harness but left hook manifest selection
partially characterized. Local state showed maxi registered through
`hooks/hooks.json`, while the upstream superpowers Codex plugin declares
`"hooks": "./hooks/hooks-codex.json"` in `.codex-plugin/plugin.json`.

The user asked to align maxi with superpowers.

## Decision Drivers

- **Match upstream convention:** maxi should use the same Codex manifest selection
  mechanism as superpowers unless there is a project-specific reason not to.
- **Dedicated per-harness files:** Claude Code, Codex, OpenCode, and Antigravity
  should each have explicit ownership boundaries.
- **Testable packaging:** the Codex manifest must declare the hook manifest path
  directly so fast checks catch drift.

## Considered Options

- **Option A: Declare `hooks/hooks-codex.json` in `.codex-plugin/plugin.json`**
  - ✅ Matches superpowers.
  - ✅ Keeps Codex on its dedicated hook wrapper and JSON payload shape.
  - ✅ Gives tests a concrete field to validate.

- **Option B: Keep relying on Codex discovering `hooks/hooks.json`**
  - ✅ Matches prior local state.
  - ❌ Leaves Codex using the Claude-oriented wrapper.
  - ❌ Keeps manifest selection implicit.

## Decision

Chose **Option A**. `.codex-plugin/plugin.json` declares:

```json
"hooks": "./hooks/hooks-codex.json"
```

Codex owns `hooks/hooks-codex.json` and `hooks/session-start-codex`. Claude Code
continues to own `hooks/hooks.json` and `hooks/hooks-claude.json`.
Antigravity owns `hooks/hooks-antigravity.json` through the
`.antigravity-plugin` package.

This supersedes ADR-0014.

## Consequences

- **Good:** maxi now follows the same Codex hook manifest convention as
  superpowers.
- **Good:** Codex no longer depends on the Claude-compatible default hook manifest.
- **Good:** `tests/check-codex-plugin.sh` guards the `.codex-plugin` hook path.
- **Bad:** Existing local Codex installs may retain old trusted hook state until
  the plugin is reinstalled or refreshed.

## Confirmation

- `tests/check-codex-plugin.sh` validates `.codex-plugin/plugin.json.hooks`.
- `tests/check-hooks.sh` validates `hooks/hooks-codex.json` and
  `hooks/session-start-codex`.
