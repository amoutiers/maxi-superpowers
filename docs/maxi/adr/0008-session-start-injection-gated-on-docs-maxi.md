---
adr: 0008
slug: 0008-session-start-injection-gated-on-docs-maxi
status: accepted
created: 2026-05-29
updated: 2026-05-29
decider: "[inferred] Antoine Moutiers"
related_specs: []
related_principles: ["I. Mandatory Spec-Driven Pipeline", "V. Artifacts Over Chat"]
related_requirements: []
supersedes: null
superseded_by: null
---

# ADR-0008: Session-Start Injection Gated on docs/maxi/ Presence

## Context

The maxi plugin injects `using-maxi/SKILL.md` content into every session via a
SessionStart hook (Claude Code) and a system prompt transform (OpenCode). Without
a guard, this injection fires in every project where the plugin is installed —
including projects that have never run `/maxi:constitution` and have no maxi
artifacts. This creates noise in non-maxi projects and, critically, a
dual-injection risk if superpowers is also installed (both could inject bootstrap
content, ballooning the system prompt). A commit
(`feat(using-maxi): gate session-start injection on docs/maxi/ presence`) added
an early-exit guard: both `hooks/session-start` and `.opencode/plugins/maxi.js`
check for `docs/maxi/` at startup and skip injection if the directory is absent.

## Decision Drivers

- **Signal-to-noise ratio**: injecting 200+ lines of pipeline documentation into
  every project regardless of whether they use maxi degrades session quality.
- **Dual-injection risk**: if superpowers is also installed, the combined system
  prompt balloons; maxi content could appear twice if superpowers includes
  `using-maxi`.
- **Opt-in semantics**: running `/maxi:constitution` is the explicit opt-in to the
  maxi pipeline. `docs/maxi/` is the artifact-level signal that a project uses maxi.
- **Principle V — Artifacts Over Chat**: `docs/maxi/` existing is the authoritative
  indicator — more reliable than any in-memory or configuration flag.

## Considered Options

- **Option A: Gate injection on `docs/maxi/` directory presence**
  Both hooks check for `docs/maxi/` at runtime. If absent, exit silently.
  - ✅ No injection in non-maxi projects
  - ✅ Dual-injection risk resolved
  - ✅ Artifact-based gate, consistent with Principle V
  - ❌ A manually created `docs/maxi/` (without running `/maxi:constitution`) would
    trigger injection — unlikely edge case

- **Option B: Always inject, opt-out via config flag (e.g. `MAXI_DISABLED=1`)**
  Inject everywhere; users add a flag to suppress in non-maxi projects.
  - ✅ Simpler logic
  - ❌ Users must actively opt out in every non-maxi project
  - ❌ Violates Principle V — configuration flag, not artifact-based

- **Option C: Gate on `docs/maxi/specs/` being non-empty**
  Only inject once at least one spec has been created.
  - ✅ Even less noise
  - ❌ Prevents injection after `/maxi:constitution` but before the first spec —
    the user would not see pipeline guidance when they need it most

## Decision

Chose **Option A**. Both the bash hook (`hooks/session-start`) and the JavaScript
OpenCode plugin (`.opencode/plugins/maxi.js`) check for `docs/maxi/` at startup
and skip injection if the directory is absent.

## Consequences

- **Good:** Non-maxi projects with the plugin installed see no maxi content injected.
- **Good:** Dual-injection with superpowers is prevented.
- **Good:** The gate is artifact-based (`docs/maxi/` exists), consistent with
  Principle V.
- **Bad:** A manually created `docs/maxi/` (without running `/maxi:constitution`)
  would trigger injection — an unlikely but possible edge case.
- **Bad:** Bootstrap cache is module-level in the OpenCode plugin; a project that
  acquires `docs/maxi/` mid-session will not get injection until the next session.

## Confirmation

- `hooks/session-start` exits 0 with no output if `$PWD/docs/maxi` does not exist.
- `.opencode/plugins/maxi.js` `getBootstrapContent()` returns `null` if `docs/maxi`
  is absent.
- `tests/check-opencode-plugin.sh` asserts conditional injection behavior.
