---
slug: 0012-test-harness
created: 2026-05-30
updated: 2026-05-30
status: done
origin: reverse-engineered
source_sha: 7f945f8a8548bf1b4b123d28cc097e2cca897c68
parked_from: null
---

# Feature Specification: Test Harness

The project ships a self-contained, two-tier test harness under `tests/`. The entrypoint `tests/run-all.sh` orchestrates everything via a `run_check` helper that prints a labelled banner per check, runs it, tallies failures, and exits non-zero if any failed. The default (fast) tier runs fifteen `check-*.sh` structural/script-invariant validators with no Claude runtime, requiring only `jq` and `bash`. An opt-in integration tier, gated behind the `--integration` flag, drives the real `claude` CLI through `tests/integration/run-all.sh` to assert that each maxi command skill auto-triggers from a naive prompt. Shared assertion primitives live in `tests/lib/test-helpers.sh`; fixtures live under `tests/fixtures/`.

## User Scenarios & Testing

### User Story 1 - Fast structural validation on every change (Priority: P1)

A contributor edits skills, templates, scripts, or manifests and runs `bash tests/run-all.sh` to confirm nothing structural broke, in seconds, without needing a Claude runtime or network.

**Why this priority**: This is the default, always-run tier and the primary regression guard for the repo. It is the gate referenced by the contributor guidelines ("Run `bash tests/run-all.sh` after changes").

**Independent Test**: Run `bash tests/run-all.sh` with no arguments on a clean checkout; it exercises the entire fast tier and exits 0 when all checks pass.

**Acceptance Scenarios**:
1. **Given** a clean checkout with `jq` installed, **When** `bash tests/run-all.sh` is run with no arguments, **Then** all fifteen fast-tier checks run, each prints `--- PASS`, and the script prints `All fast checks passed.` and exits 0.
2. **Given** a single failing check, **When** the fast tier runs, **Then** that check prints `--- FAIL` to stderr, the failure counter increments, the run prints `FAILED: N check(s) failed`, and the script exits non-zero.
3. **Given** `jq` is not installed, **When** the harness starts, **Then** it prints `ERROR: jq is required but not installed` and exits before running any check.
4. **Given** an unrecognized argument, **When** `bash tests/run-all.sh --bogus` is run, **Then** it prints `Unknown argument` to stderr and exits 1.

### User Story 2 - Integration skill-triggering verification (Priority: P2)

A contributor wants to confirm that each maxi command skill still auto-triggers from a realistic, naive user prompt (not just an explicit `/maxi:` invocation), so they run `bash tests/run-all.sh --integration`.

**Why this priority**: It validates end-to-end skill-discovery behavior against a live Claude runtime, but is slow (minutes) and requires the `claude` CLI, so it is opt-in rather than default.

**Independent Test**: Run `bash tests/run-all.sh --integration`; after the fast tier passes it invokes `tests/integration/run-all.sh`, which loops over twelve command skills and runs one trigger test each.

**Acceptance Scenarios**:
1. **Given** the fast tier passed and `--integration` was supplied, **When** the integration tier runs, **Then** for each of the twelve skills a naive prompt is sent to `claude -p` with `--plugin-dir`, `--max-turns`, and `--output-format stream-json`, and the run asserts the `Skill` tool was invoked for that skill name (matching `"skill":"(maxi:)?<name>"` in the stream-json log).
2. **Given** a skill is invoked correctly, **When** its trigger test parses the log, **Then** it prints `PASS` and exits 0; the runner tallies a per-skill PASS/FAIL summary and exits non-zero if any skill failed.
3. **Given** no prompt file exists for a listed skill, **When** the runner reaches it, **Then** it prints `SKIP` and continues.

### Edge Cases
- If the `claude` CLI is absent, the integration tier cannot run; the fast tier is fully independent of it and still passes.
- If GNU `timeout` is not present (common on macOS), `run-trigger-test.sh` warns and runs `claude` without a timeout rather than failing.
- If `tests/integration/run-all.sh` is missing when `--integration` is requested, the harness prints an error and exits 1 rather than silently skipping.

## Requirements

### Functional Requirements

- **FR-001**: The harness MUST provide a single entrypoint `run-all.sh` that runs the full fast tier by default and accepts an optional `--integration` flag (tests/run-all.sh:11).
- **FR-002**: The harness MUST require `jq` and abort with an error before running any check if it is missing (tests/run-all.sh:19).
- **FR-003**: Each check MUST be run through a `run_check` helper that prints a labelled banner, runs the script, and records PASS/FAIL, tallying failures into a counter (tests/run-all.sh:21).
- **FR-004**: The fast tier MUST run the full set of structural/script-invariant validators with no Claude runtime (tests/run-all.sh:35).
- **FR-005**: The harness MUST exit non-zero with a `FAILED: N check(s) failed` message when one or more fast-tier checks fail, and print `All fast checks passed.` otherwise (tests/run-all.sh:51).
- **FR-006**: The integration tier MUST run only when `--integration` is supplied, and only after the fast tier has passed; it MUST error if the integration runner is missing (tests/run-all.sh:59).
- **FR-007**: The integration runner MUST iterate over the twelve maxi command skills and run one trigger test per skill, tallying a PASS/FAIL summary and exiting non-zero on any failure (tests/integration/run-all.sh:8).
- **FR-008**: A missing per-skill prompt file MUST be reported as `SKIP` rather than failing the integration run (tests/integration/run-all.sh:33).
- **FR-009**: Each trigger test MUST invoke the real `claude` CLI with `--plugin-dir`, `--dangerously-skip-permissions`, `--max-turns`, and `--output-format stream-json`, capturing output to a timestamped log (tests/integration/run-trigger-test.sh:34).
- **FR-010**: A trigger test MUST pass only if the stream-json log shows the `Skill` tool was invoked for the expected skill, matched as `"skill":"(maxi:)?<name>"` (tests/integration/run-trigger-test.sh:47).
- **FR-011**: When GNU `timeout` is unavailable, the trigger test MUST warn and run `claude` without a timeout rather than aborting (tests/integration/run-trigger-test.sh:28).
- **FR-012**: Fast-tier checks MUST share assertion primitives sourced from `tests/lib/test-helpers.sh` and emit a per-check summary via `summary_and_exit` (tests/check-frontmatter.sh:6).
- **FR-013**: The sync-invariant check MUST fail if any vendored skill is missing from `skills/` or differs from its `vendor/superpowers/skills/` source, using a recursive `diff` (tests/check-sync-invariant.sh:34).
- **FR-014**: The skills-present check MUST assert all eighteen maxi-native skills exist as `skills/<name>/SKILL.md` (tests/check-skills-present.sh:11).

### Key Entities

- **`run-all.sh`** — fast-tier orchestrator; defines the `run_check` helper, the ordered check list, and the `--integration` gate.
- **`check-*.sh` validators** — the fifteen fast-tier checks, each a standalone script sourcing the shared helpers: frontmatter, sync-invariant, spec-fixture, templates, skills-present, migrate-adr, plugin-manifest, hooks, vendored-doc, sync-script, bump-script, migrate-from-speckit, migrate-from-brownfield, opencode-plugin, bootstrap-parity.
- **`tests/lib/test-helpers.sh`** — shared assertion library (`assert_file_exists`, `assert_grep`, `assert_starts_with_yaml_frontmatter`, `summary_and_exit`).
- **`tests/integration/run-all.sh`** — integration-tier orchestrator; holds the twelve-skill list and per-skill PASS/FAIL summary.
- **`tests/integration/run-trigger-test.sh`** — single-skill driver that runs `claude -p` and asserts Skill-tool invocation from the stream-json log.
- **`tests/fixtures/`** — fixture inputs (`sample-spec.md`, `sample-adr.md`, `brownfield-project/`, `speckit-project/`) consumed by the validators.

## Success Criteria

### Measurable Outcomes
- **SC-001**: `bash tests/run-all.sh` completes the entire fast tier in roughly ten seconds with no Claude runtime or network access.
- **SC-002**: A clean checkout exits 0 on the fast tier; introducing any structural regression (e.g., editing a vendored skill, removing a maxi-native skill) causes the corresponding check to fail and the run to exit non-zero.
- **SC-003**: The fast tier runs all fifteen named checks on every invocation.
- **SC-004**: `--integration` runs trigger tests for all twelve command skills and reports a per-skill PASS/FAIL summary, exiting non-zero if any skill failed to auto-trigger.

## Assumptions
- `bash`, `jq`, and `git` are available; the fast tier depends on no other external tooling.
- The integration tier additionally requires the `claude` CLI and is intended to be run manually, not in the default flow; GNU `timeout` is optional.
- `git rev-parse --show-toplevel` resolves the repo root, so the harness assumes it is run from within the git working tree.

## Migration Notes

- Reverse-engineered from commit `7f945f8a8548bf1b4b123d28cc097e2cca897c68`.
- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).
- Verified against code by an adversarial pass before acceptance.
