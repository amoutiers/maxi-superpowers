---
adr: 0004
slug: 0004-dual-harness-claude-code-opencode
status: superseded
created: 2026-05-29
updated: 2026-05-31
decider: "[inferred] Antoine Moutiers"
supersedes: null
superseded_by: 0013
---

# ADR-0004: Dual-Harness Plugin Design — Claude Code + OpenCode

## Context

[inferred] maxi-superpowers was initially built exclusively as a Claude Code
plugin (`.claude-plugin/plugin.json`, `hooks/hooks.json`, Claude Code SessionStart
hook). As OpenCode.ai emerged as an alternative AI coding harness with a plugin
system, the decision was made to extend maxi to support it as a second harness.
A design doc (`docs/superpowers/specs/2026-05-28-opencode-plugin-design.md`) was
written prior to implementation. The OpenCode harness was added in a single
commit (`feat(opencode): d9bad1ee`) introducing `.opencode/plugins/maxi.js` — a
module-based plugin using `experimental.chat.messages.transform` for system prompt
injection and a config hook for skills directory registration. The two harnesses
share the same `skills/` directory but use different injection mechanisms.

## Decision Drivers

- **Broadening reach**: OpenCode is a Claude Code alternative with a growing user
  base; supporting it without forking the skill library extends maxi's value.
- **Shared skill library**: Both harnesses can share `skills/` with no duplication —
  only the bootstrap/injection mechanism differs.
- **No dual-injection**: Both harnesses must coexist safely if both are installed
  in the same project; conditional injection (gated on `docs/maxi/` presence)
  prevents context flooding.
- **Principle II — Delegate to Superpowers, Never Duplicate**: The dual-harness
  design is consistent with the pattern of reusing existing infrastructure rather
  than forking.

## Considered Options

- **Option A: Dual-harness — same `skills/`, separate bootstrap per platform**
  `.claude-plugin/` for Claude Code, `.opencode/plugins/maxi.js` for OpenCode.
  Both read `skills/` from the same directory tree.
  - ✅ Satisfies driver: broadening reach
  - ✅ Satisfies driver: shared skill library — no duplication
  - ✅ Satisfies driver: no dual-injection (conditional gating)
  - ❌ Two distinct injection mechanisms to maintain; harness-specific bugs may diverge

- **Option B: Claude Code only, OpenCode users fork**
  Only Claude Code harness supported officially. OpenCode users maintain their own fork.
  - ✅ Simpler maintenance surface
  - ❌ Violates driver: broadening reach — OpenCode users excluded
  - ❌ Fragmentation: maxi skill updates don't reach OpenCode users

## Decision

[inferred] Chose **Option A**. A design doc was produced, then the OpenCode
harness was implemented as `.opencode/plugins/maxi.js` with bootstrap caching
and conditional injection gated on `docs/maxi/` presence. The Claude Code
harness (`hooks/`, `.claude-plugin/`) was left unchanged.

## Consequences

- **Good:** maxi works on both Claude Code and OpenCode with a single install
  from the same repository.
- **Good:** The `skills/` directory is the single source of truth for all skill
  content — no harness-specific divergence.
- **Good:** Conditional injection prevents noise in non-maxi projects and resolves
  the dual-injection risk when both harnesses are installed.
- **Bad:** Two injection mechanisms (`hooks/session-start` for Claude Code,
  `experimental.chat.messages.transform` for OpenCode) must be kept in sync when
  `using-maxi/SKILL.md` changes.
- **Bad:** The OpenCode API (`experimental.chat.messages.transform`) is flagged
  experimental — breakage on OpenCode upgrades is a risk.

## Confirmation

- `tests/check-opencode-plugin.sh` validates that `.opencode/plugins/maxi.js`
  exports required hooks, has bootstrap caching, and uses conditional injection.
- The Claude Code harness tests (`check-hooks.sh`, `check-plugin-manifest.sh`)
  continue to pass.
- Both harnesses inject the same `using-maxi/SKILL.md` content.
