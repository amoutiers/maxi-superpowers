---
adr: 0016
slug: 0016-align-upstream-harness-model
status: accepted
created: 2026-07-04
updated: 2026-07-04
decider: "Antoine Moutiers"
supersedes: 0015
superseded_by: null
---

# ADR-0016: Align Upstream Harness Model 1:1 with superpowers v6.1.1

## Context

ADR-0015 aligned maxi's Codex hook manifest selection with superpowers v6.0.3 —
each harness (Claude Code, Codex, OpenCode, Antigravity) had a dedicated
`hooks/session-start-<harness>` wrapper, a dedicated `hooks/hooks-<harness>.json`
manifest, and an `.antigravity-plugin/` package directory. The support matrix
was four harnesses.

Upstream superpowers has since simplified to a single env-aware
`hooks/session-start` shared by Claude Code, Antigravity, Cursor, and Copilot
CLI; Codex now ships `"hooks": {}` to rely on native skill discovery;
OpenCode keeps its message-transform plugin; Pi ships a `package.json` `pi`
section + `.pi/extensions/<name>.ts`; Antigravity installs from the repo root
(no dedicated package dir); Kimi Code, Factory Droid, and GitHub Copilot CLI
are documented via marketplace README sections only. The legacy Gemini CLI is
removed entirely. The vendored `using-superpowers` bootstrap was also
compressed from 121 to 62 lines in v6.1.0, dropping three per-harness tool
references (`claude-code-tools.md`, `copilot-tools.md`, `gemini-tools.md`).

We bumped vendored superpowers from v6.0.3 to v6.1.1 (Phase A) and now align
maxi's own harness model 1:1 with the upstream.

## Decision Drivers

- **Match upstream convention:** maxi should use the same harness model as
  superpowers v6.1.1 unless there is a project-specific reason not to.
- **Single Responsibility / DRY:** one env-aware hook replaces four wrappers.
- **Testable packaging:** every in-repo packaging surface is guarded by a
  fast-tier check.
- **Bootstrap parity:** the `<EXTREMELY_IMPORTANT>` preamble is identical
  across the bash hook, the OpenCode plugin, and the Pi extension.

## Considered Options

- **Option A: Adopt the upstream harness model 1:1 (selected)**
  - ✅ Single `hooks/session-start` (env-aware) replaces four wrappers.
  - ✅ `hooks/hooks.json` (root, Claude Code + Antigravity) + `hooks/hooks-cursor.json` (Cursor).
  - ✅ Codex `"hooks": {}` (native skill discovery, no SessionStart hook).
  - ✅ Antigravity installs from repo root (no `.antigravity-plugin/`).
  - ✅ Adds Pi (`package.json` `pi` section + `.pi/extensions/maxi.ts`) and Cursor (`hooks-cursor.json`).
  - ✅ Removes legacy Gemini CLI entirely.
  - ✅ Bootstrap parity guarded across bash hook, OpenCode plugin, Pi extension.
  - ❌ Larger surface change than keeping wrappers.

- **Option B: Keep the four-wrapper model and ADR-0015**
  - ✅ Smaller diff.
  - ❌ Diverges from upstream; maxi carries more code than superpowers.
  - ❌ Cannot add Cursor/Pi without bespoke wrappers per harness.
  - ❌ `using-superpowers` v6.1.1 bootstrap references dropped refs (`claude-code-tools.md`, `copilot-tools.md`, `gemini-tools.md`) — wrappers would re-implement them.

- **Option C: Adopt the upstream mechanism but limit to four harnesses**
  - ✅ Smaller scope than 10 harnesses.
  - ❌ Rejects Cursor and Pi which upstream actively supports.
  - ❌ Inconsistent: "match upstream 1:1" but exclude supported harnesses.

## Decision

Chose **Option A**. maxi adopts the superpowers v6.1.1 harness model 1:1:

- **Claude Code:** `.claude-plugin/plugin.json` + root `hooks/hooks.json`
  (SessionStart → `hooks/session-start`, `${CLAUDE_PLUGIN_ROOT}`).
- **Antigravity:** `agy plugin install <repo>`; reads root `hooks/hooks.json`.
- **Cursor:** `hooks/hooks-cursor.json` (Cursor `sessionStart` event,
  `additional_context` snake_case) → `hooks/session-start`.
- **Codex:** `.codex-plugin/plugin.json` declares `"hooks": {}` (native skill
  discovery); `.agents/plugins/marketplace.json` + `plugins/maxi`.
- **OpenCode:** `.opencode/plugins/maxi.js` (message-transform + config hook).
- **Pi:** `package.json` `pi` section + `.pi/extensions/maxi.ts`.
- **Kimi Code, Factory Droid, GitHub Copilot CLI:** README marketplace docs
  only (no in-repo packaging).

Removed:
- `hooks/session-start-core`, `hooks/session-start-claude`,
  `hooks/session-start-codex`, `hooks/session-start-antigravity`.
- `hooks/hooks-claude.json`, `hooks/hooks-codex.json`,
  `hooks/hooks-antigravity.json`.
- `.antigravity-plugin/` (Antigravity installs from repo root).
- Root `plugin.json` (superseded by `.claude-plugin/plugin.json`).
- Legacy Gemini CLI install section.

Added:
- `hooks/session-start` (single env-aware hook).
- `hooks/hooks-cursor.json`.
- `.pi/extensions/maxi.ts`.
- `package.json` `pi` section, `"type": "module"`, `main` field.

This supersedes ADR-0015. ADR-0013 and ADR-0014 remain superseded.

## Consequences

- **Good:** maxi's harness model is byte-aligned with superpowers v6.1.1; future
  upstream bumps copy cleanly.
- **Good:** One unified hook instead of four wrappers — less code to maintain.
- **Good:** Six in-repo packaging surfaces + three marketplace-only harnesses
  documented, all guarded by fast-tier tests
  (`check-hooks.sh`, `check-cursor-hooks.sh`, `check-codex-plugin.sh`,
  `check-plugin-manifest.sh`, `check-opencode-plugin.sh`, `check-pi-extension.sh`,
  `check-bootstrap-parity.sh`).
- **Good:** Codex no longer pays a SessionStart round-trip — native skill
  discovery mirrors superpowers v6.1.1.
- **Bad:** Existing local Antigravity installs that pointed at
  `.antigravity-plugin/` need a reinstall from the repo root.
- **Bad:** Local Codex installs that trusted `hooks/hooks-codex.json` may need
  a plugin refresh to drop the old hook.

## Confirmation

- `tests/check-hooks.sh` validates the unified hook + both manifests + stale
  wrapper/manifest removal + `.antigravity-plugin/` removal.
- `tests/check-cursor-hooks.sh` and `tests/check-pi-extension.sh` guard the new
  in-repo packaging surfaces.
- `tests/check-codex-plugin.sh` asserts `.hooks == {}`.
- `tests/check-bootstrap-parity.sh` guards the preamble across
  `hooks/session-start`, `.opencode/plugins/maxi.js`, and
  `.pi/extensions/maxi.ts`.
- `bash tests/run-all.sh` passes.