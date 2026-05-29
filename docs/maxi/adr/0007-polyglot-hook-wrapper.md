---
adr: 0007
slug: 0007-polyglot-hook-wrapper
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

# ADR-0007: Polyglot Hook Wrapper for Cross-Platform Windows/Unix Compatibility

## Context

The Claude Code plugin system invokes hook scripts via a shell command specified
in `hooks.json`. On Unix systems, hook scripts are plain bash. On Windows, Claude
Code auto-prepends `bash` to any command containing `.sh` — but extensionless
scripts get no such treatment, and Windows users may have bash in non-standard
locations (Git for Windows, MSYS2). To support Windows without requiring manual
configuration, the hook command was wrapped in `hooks/run-hook.cmd` — a polyglot
file valid as both a Windows `.cmd` batch script and a Unix shell script. The
batch portion searches for bash in known Windows locations; the Unix portion
directly executes the named script.

A follow-up fix (`fix(hooks): quote Windows args in run-hook.cmd to handle
spaces`) was required to correctly handle arguments containing spaces or special
characters using `"%~N"` syntax.

## Decision Drivers

- **Windows support without user configuration**: the wrapper must locate bash
  automatically — Program Files, Program Files (x86), and PATH are checked in
  order.
- **Extensionless hook scripts**: hook scripts use extensionless filenames (e.g.
  `session-start`, not `session-start.sh`) to avoid Claude Code's Windows
  auto-detection prepending `bash` twice.
- **Silent fallback**: if no bash is found on Windows, the hook exits silently
  (`exit /b 0`) — the plugin degrades gracefully rather than crashing Claude Code.

## Considered Options

- **Option A: Polyglot `.cmd`/bash wrapper (`run-hook.cmd`)**
  A single file interpreted as batch by `cmd.exe` and as bash by Unix shells.
  The batch section searches for bash; the Unix section executes the named script.
  - ✅ Windows and Unix share the same `hooks.json` entry
  - ✅ Silent fallback if no bash found on Windows
  - ❌ Polyglot syntax (`: << 'CMDBLOCK'` heredoc trick) is non-obvious to maintain
  - ❌ Windows argument quoting is tricky; a follow-up fix was needed (`"%~N"`)

- **Option B: Separate `.sh` and `.cmd` files, platform-detected in `hooks.json`**
  Two files; `hooks.json` detects platform and selects the right one.
  - ✅ Cleaner — no polyglot trick
  - ❌ Claude Code's `hooks.json` does not support platform-conditional commands

- **Option C: Unix only — no Windows support**
  Only bash scripts, no Windows wrapper.
  - ✅ Simplest
  - ❌ Excludes Windows users entirely

## Decision

[inferred] Chose **Option A**. `run-hook.cmd` is the entry point registered in
`hooks.json`. It handles both Windows (batch) and Unix (bash) execution paths in
a single file.

## Consequences

- **Good:** Windows and Unix users share the same `hooks.json` entry — no
  platform-specific configuration required.
- **Good:** Silent fallback on Windows (no bash found) means the plugin degrades
  gracefully rather than crashing Claude Code.
- **Bad:** Polyglot syntax requires contributors to understand both batch and bash
  idioms to maintain `run-hook.cmd`.
- **Bad:** Argument quoting on Windows is tricky — a follow-up fix was needed for
  space-containing paths (`"%~N"` syntax).
- **Bad:** Hook script names must remain extensionless (no `.sh`) to avoid Claude
  Code's Windows auto-detection double-prepending `bash`.

## Confirmation

- `hooks/run-hook.cmd` is the registered hook command in `hooks.json`.
- Hook scripts in `hooks/` use extensionless filenames.
- `tests/check-hooks.sh` validates that hook scripts exist and are executable.
- Windows argument quoting uses `"%~N"` syntax for all positional arguments.
