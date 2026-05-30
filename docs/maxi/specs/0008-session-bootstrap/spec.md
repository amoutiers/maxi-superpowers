---
slug: 0008-session-bootstrap
created: 2026-05-30
updated: 2026-05-30
status: done
origin: reverse-engineered
source_sha: 7f945f8a8548bf1b4b123d28cc097e2cca897c68
parked_from: null
---

# Feature Specification: Dual-Harness Session Bootstrap

When a session begins, maxi injects its `using-maxi` skill (the spec-driven pipeline introduction) into the model's context so the agent knows the pipeline from turn zero. Because maxi targets two harnesses with incompatible context-injection mechanisms, the same bootstrap preamble is delivered two ways: Claude Code (and Cursor/Copilot CLI) via a `SessionStart` hook that emits platform-specific JSON, and OpenCode via a plugin that transforms the first user message. Both paths share an identical `<EXTREMELY_IMPORTANT>` preamble structure, only inject inside maxi projects (those with a `docs/maxi/` directory), and avoid redundant or duplicate injection.

## User Scenarios & Testing

### User Story 1 - Claude Code session injects maxi context at start (Priority: P1)

A developer opens, clears, or compacts a Claude Code session inside a maxi project; the agent should immediately know the maxi pipeline without being told.

**Why this priority**: Without injection, the agent has no awareness of the maxi pipeline at session start and cannot gate phases correctly — this is the primary value of the bootstrap.

**Independent Test**: In a directory containing `docs/maxi/`, invoke `hooks/run-hook.cmd session-start` with `CLAUDE_PLUGIN_ROOT` set; the script prints a JSON object containing `hookSpecificOutput.additionalContext` whose value is the `<EXTREMELY_IMPORTANT>` preamble wrapping the `using-maxi` SKILL.md content.

**Acceptance Scenarios**:

1. **Given** the working directory contains `docs/maxi/` and `CLAUDE_PLUGIN_ROOT` is set without `COPILOT_CLI`, **When** the `session-start` script runs, **Then** it reads `skills/using-maxi/SKILL.md`, JSON-escapes it, wraps it in the `<EXTREMELY_IMPORTANT>` preamble, and prints `{ "hookSpecificOutput": { "hookEventName": "SessionStart", "additionalContext": "..." } }`.
2. **Given** `CURSOR_PLUGIN_ROOT` is set, **When** the script runs, **Then** it prints the same context under top-level `additional_context`.
3. **Given** neither Cursor nor Claude Code env vars indicate their format (or `COPILOT_CLI=1` is set), **When** the script runs, **Then** it prints the context under top-level `additionalContext` (SDK-standard shape).
4. **Given** the hook event matches `startup`, `clear`, or `compact`, **When** Claude Code fires `SessionStart`, **Then** it synchronously invokes `run-hook.cmd session-start` via `${CLAUDE_PLUGIN_ROOT}`.

### User Story 2 - OpenCode session injects maxi context into first user message (Priority: P1)

A developer runs an OpenCode session inside a maxi project; the agent should receive the same maxi bootstrap, and OpenCode should discover maxi's skills without manual symlinks.

**Why this priority**: OpenCode is the second supported harness; bootstrap parity with Claude Code is required for maxi to behave identically across harnesses.

**Independent Test**: Load `MaxiPlugin` in a project with `docs/maxi/`; the `config` hook appends the maxi skills directory to `config.skills.paths`, and the `experimental.chat.messages.transform` hook prepends the `<EXTREMELY_IMPORTANT>` bootstrap text part to the first user message.

**Acceptance Scenarios**:

1. **Given** the OpenCode `config` hook runs, **When** the maxi skills directory is not already in `config.skills.paths`, **Then** it is appended (initializing `config.skills` / `config.skills.paths` as needed).
2. **Given** the project directory contains `docs/maxi/` and `using-maxi/SKILL.md` exists, **When** `experimental.chat.messages.transform` fires, **Then** the first user message gets a new leading text part containing the `<EXTREMELY_IMPORTANT>` preamble, the stripped-frontmatter SKILL.md body, and an OpenCode tool-mapping block.
3. **Given** the bootstrap content was already computed once, **When** the transform hook fires again on a later agent step, **Then** the cached value is reused with no further disk reads.

### Edge Cases

- **Non-maxi project (no `docs/maxi/`)**: the Claude Code script exits 0 with no output; the OpenCode plugin caches `null` and the transform hook returns without injecting.
- **Already-injected first user message (OpenCode)**: if any text part of the first user message already contains `EXTREMELY_IMPORTANT`, the transform returns without re-injecting, preventing double injection when an already-transformed message array is reprocessed.
- **Missing `using-maxi/SKILL.md` (OpenCode)**: the plugin caches `null` and injects nothing; (Claude Code path substitutes an error string into the content rather than failing).
- **No first user message / empty parts (OpenCode)**: the transform returns early without injecting.
- **Non-matching SessionStart event**: events other than `startup|clear|compact` do not fire the hook.
- **Windows with no bash available**: `run-hook.cmd` exits 0 silently so the plugin still loads without context injection.

## Requirements

### Functional Requirements

- **FR-001**: System MUST register a Claude Code `SessionStart` hook matching `startup|clear|compact` that synchronously runs the session-start script via `${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd session-start`. (hooks/hooks.json:5)
- **FR-002**: System MUST skip injection in projects lacking a `docs/maxi` directory by exiting early with no output. (hooks/session-start:11)
- **FR-003**: System MUST read the `using-maxi` skill body from `${PLUGIN_ROOT}/skills/using-maxi/SKILL.md`, substituting an error placeholder string if the read fails. (hooks/session-start:16)
- **FR-004**: System MUST JSON-escape the skill content (backslash, double-quote, newline, carriage-return, tab) before embedding it in JSON output. (hooks/session-start:21)
- **FR-005**: System MUST wrap the escaped skill content in an `<EXTREMELY_IMPORTANT>` preamble introducing maxi and the `using-maxi` skill. (hooks/session-start:32)
- **FR-006**: System MUST emit Cursor-format JSON (top-level `additional_context`) when `CURSOR_PLUGIN_ROOT` is set. (hooks/session-start:44)
- **FR-007**: System MUST emit Claude Code-format JSON (`hookSpecificOutput.additionalContext` with `hookEventName: SessionStart`) when `CLAUDE_PLUGIN_ROOT` is set and `COPILOT_CLI` is unset. (hooks/session-start:47)
- **FR-008**: System MUST emit SDK-standard JSON (top-level `additionalContext`) for Copilot CLI or unknown platforms. (hooks/session-start:51)
- **FR-009**: System MUST use `printf` rather than a heredoc for JSON output to avoid the bash 5.3+ heredoc hang. (hooks/session-start:42)
- **FR-010**: System MUST provide a cross-platform polyglot wrapper that, on Windows, locates Git-for-Windows bash in standard install paths or on PATH and invokes the named hook script. (hooks/run-hook.cmd:21)
- **FR-011**: System MUST exit 0 silently on Windows when no bash is found so the plugin still loads without context injection. (hooks/run-hook.cmd:39)
- **FR-012**: System MUST, on Unix, resolve its own directory and exec the named hook script under bash with the remaining arguments. (hooks/run-hook.cmd:46)
- **FR-013**: System MUST error and exit non-zero when run-hook.cmd is called without a script name. (hooks/run-hook.cmd:13)
- **FR-014**: System MUST register the maxi skills directory (`../../skills` relative to the plugin) into OpenCode's live `config.skills.paths` if not already present. (.opencode/plugins/maxi.js:113)
- **FR-015**: System MUST inject the bootstrap into the first user message via the `experimental.chat.messages.transform` hook, returning early if there is no bootstrap, no messages, no first user message, or no parts. (.opencode/plugins/maxi.js:130)
- **FR-016**: System MUST guard against double injection by skipping when any text part of the first user message already contains `EXTREMELY_IMPORTANT`. (.opencode/plugins/maxi.js:139)
- **FR-017**: System MUST cache bootstrap content at module level (undefined = unloaded, null = unavailable) so repeated transform-hook calls perform no redundant disk or regex work. (.opencode/plugins/maxi.js:53)
- **FR-018**: System MUST resolve the OpenCode bootstrap eligibility from the passed project `directory` (falling back to `process.cwd()`), caching null when `docs/maxi` or the SKILL.md file is absent. (.opencode/plugins/maxi.js:69)
- **FR-019**: System MUST strip YAML frontmatter from the SKILL.md before embedding its body in the OpenCode bootstrap. (.opencode/plugins/maxi.js:84)
- **FR-020**: System MUST wrap the OpenCode bootstrap in the same `<EXTREMELY_IMPORTANT>` preamble as the Claude Code path and append an OpenCode tool-mapping block (TodoWrite, Task/subagents, Skill, native tools). (.opencode/plugins/maxi.js:95)
- **FR-021**: System MUST prepend the bootstrap as a new leading text part cloned from the existing first part of the first user message. (.opencode/plugins/maxi.js:142)

### Key Entities

- **`<EXTREMELY_IMPORTANT>` bootstrap preamble**: the shared wrapper text ("You have maxi… below is the full content of your 'maxi:using-maxi' skill…") emitted by both harnesses, keeping their injected context in parity.
- **`using-maxi` SKILL.md**: the source skill body that is injected; read from `skills/using-maxi/SKILL.md` in both paths.
- **SessionStart hook entry (hooks.json)**: matcher `startup|clear|compact` bound to the run-hook.cmd command.
- **run-hook.cmd polyglot wrapper**: a single file valid as both a Windows batch script and a Unix bash script that dispatches to extensionless hook scripts.
- **Bootstrap cache (`_bootstrapCache`)**: module-level tri-state cache (undefined/null/string) in the OpenCode plugin.
- **OpenCode config hook / transform hook**: the two returned plugin hooks — `config` (skills path registration) and `experimental.chat.messages.transform` (message injection).

## Success Criteria

### Measurable Outcomes

- **SC-001**: In a maxi project, every Claude Code session matching `startup|clear|compact` receives exactly one `additionalContext` payload containing the `using-maxi` content.
- **SC-002**: In a maxi project, every OpenCode session has exactly one bootstrap text part prepended to its first user message, and never more than one across repeated agent steps.
- **SC-003**: In a non-maxi project (no `docs/maxi/`), neither harness injects any bootstrap context.
- **SC-004**: The `<EXTREMELY_IMPORTANT>` preamble structure is byte-comparable between the Claude Code script and the OpenCode plugin (parity), aside from the OpenCode-only tool-mapping appendix.
- **SC-005**: On Windows with no bash installed, the plugin still loads (run-hook.cmd exits 0) with no injection rather than erroring.
- **SC-006**: Across N agent steps in one OpenCode session, the `using-maxi` SKILL.md is read and parsed from disk at most once.

## Assumptions

- The presence of a `docs/maxi/` directory is the canonical signal that a project is maxi-managed and eligible for bootstrap injection.
- Each harness sets the environment variables / passes the arguments the scripts branch on (`CURSOR_PLUGIN_ROOT`, `CLAUDE_PLUGIN_ROOT`, `COPILOT_CLI`, OpenCode's `directory`).
- OpenCode injects via a user message (rather than a system message) deliberately, to avoid per-turn token bloat and multi-system-message issues with some models.
- The hooks.json entry only registers the hook for Claude Code; Cursor/Copilot support depends on those platforms invoking the script through their own hook mechanisms.
- `using-maxi/SKILL.md` is the single source of truth injected by both paths and does not change during a session.

## Migration Notes

- Reverse-engineered from commit `7f945f8a8548bf1b4b123d28cc097e2cca897c68`.
- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).
- Verified against code by an adversarial pass before acceptance.
