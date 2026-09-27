---
adr: 0031
slug: 0031-align-superpowers-v6-4-model
spec: null
design_cycle: 0
status: accepted
created: 2026-09-27
updated: 2026-09-27
decider: "Antoine Moutiers"
supersedes: 0021
superseded_by: null
---

# ADR-0031: Align Superpowers v6.4.2 Execution and Harness Model

## Context

Superpowers v6.4.2 adds stricter review ranges, workspace ownership, lean plans, new review context and additional harness interfaces. The approved [integration design](../../superpowers/specs/2026-09-27-superpowers-6-4-adaptation-design.md) requires adoption without weakening Maxi's evidence or product pipeline guarantees.

ADR-0021 describes the v6.3.0 relationship and becomes historical. The current maintenance uses the user-selected Superpowers workflow; that choice does not change Maxi's product pipeline.

## Decision Drivers

- Delegate upstream capabilities and preserve exact vendoring (Constitution II and strict vendoring).
- Preserve task ownership, reviewed evidence and the terminal transition (Constitution III and V).
- Keep executable bootstrap project-gated and qualify actual host behavior (ADR-0008).
- Preserve completed migrations and decision-input freshness (ADR-0027 and ADR-0028).

## Considered Options

- Option A: Import v6.4.2 and adapt existing Maxi boundaries. Satisfies all drivers; requires focused compatibility and host tests.
- Option B: Bump only the vendor. Preserves upstream bytes but leaves the reproduced empty-range failure and missing host interfaces.
- Option C: Introduce Native as a second Maxi executor. Reuses an upstream mode but requires a new completion and review contract outside this upgrade.

## Decision

Choose Option A.

- Import exact v6.4.2 through the existing subtree/sync workflow. Preserve 15 upstream skills, 19 Maxi-native skills and the ten-state FSM.
- Keep x-develop as the TNNN-to-Task N adapter and SDD as the execution engine for /maxi:implement. Preserve upstream task/fix/final reviews and all three product review boundaries.
- Return from upstream before workspace deletion and branch finishing. Maxi retains checkbox ownership, terminal receipt validation and implementing-to-done ownership before finishing.
- Require real nonempty ancestral review ranges. Keep completed v1 migrations with fresh review of genuine historical implementation; reject incompatible receipt reuse without rewriting history.
- Validate upstream workspace ownership through Maxi's existing projection/lineage boundary. Preserve read-only verification and immutable predecessors.
- Preserve lean plan interfaces, assertions and Review Focus through existing owners. Keep explicit requested destinations and ADR-0029's authorization semantics. Retain complete reviewer output and controller Ruling lines.
- Import Native and diagnostics as upstream skills, without accepting Native completion lines in Maxi's governed SDD pipeline.
- Retain existing harness support and add OpenCode V2, Muse and Qwen only with supported interfaces and explicit qualification. Preserve executable docs/maxi gating. Retain ADR-0021's documented Gemini/Kimi declarative exception; no new exception is granted silently.
- Keep deterministic tests, installed-agent evidence, native acceptance and publication distinct. An unavailable host remains an open acceptance gate.

## Consequences

- Good: Upstream remains the implementation engine without a vendored fork.
- Good: Existing resume, migration and terminal guarantees remain enforceable.
- Good: New harness surfaces have explicit ownership and qualification requirements.
- Bad: Maxi must maintain narrow compatibility checks at its existing boundaries.
- Bad: Host availability may delay full qualification even when deterministic checks pass.
- Bad: Native execution remains unavailable as a Maxi pipeline mode until separately designed.

## Confirmation

Run the existing adapter, template, review-boundary, host, release-inventory, sync and version checks, followed by the complete fast tier. Qualify actual installed design/execution/resume/final-review behavior and native OpenCode V1/V2, Muse and Qwen sessions. Record source identities and unresolved gates in the upgrade qualification report. Update the Mandatory Sync five atomically with pipeline-affecting changes.
