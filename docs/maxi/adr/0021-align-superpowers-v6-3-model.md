---
adr: 0021
slug: 0021-align-superpowers-v6-3-model
status: accepted
created: 2026-08-19
updated: 2026-08-19
decider: "Antoine Moutiers"
supersedes: 0016
superseded_by: null
---

# ADR-0021: Align Superpowers v6.3.0 Execution and Harness Model

## Context

Superpowers v6.3.0 replaces the execution assumptions recorded by
[0016-align-upstream-harness-model](0016-align-upstream-harness-model.md). It
now owns a durable plan-scoped SDD workspace, task briefs, resume-based fix
rounds, task reviews, whole-branch review, and additional harness packaging.
Maxi must adopt those upstream capabilities without duplicating them, while
preserving its own `TNNN` task artifacts, checkbox ownership, strict pipeline,
and terminal status transition.

The two systems expose different task interfaces. Maxi executes `TNNN`
checkbox entries derived from `tasks.md`; upstream SDD executes `Task N`
sections from a plan and normally continues directly to branch finishing.
Removing the compatibility boundary would either bypass Maxi's artifact and
status owners or require Maxi to copy upstream's fix and review loops. The
[constitution](../constitution.md), Principles II, III, V, and VI, instead
requires a narrow adapter that delegates the implementation engine while
keeping each Maxi artifact transition with its existing owner.

Superpowers v6.3.0 also adds or formalizes packaging for Cursor, Kimi Code,
Gemini CLI, Devin CLI, and Hermes Agent. Executable adapters can preserve the
artifact gate from
[0008-session-start-injection-gated-on-docs-maxi](0008-session-start-injection-gated-on-docs-maxi.md),
but Gemini and Kimi declarative installed-plugin APIs load their bootstrap
before they can inspect the current working directory. Their global bootstrap
is therefore an unavoidable, documented exception rather than a simulated
conditional gate.

## Decision Drivers

- **Delegate implementation mechanics upstream:** Constitution Principle II
  requires Maxi to use Superpowers' v6.3.0 SDD fix loop and implementation
  reviews instead of copying or overriding them.
- **Preserve Maxi pipeline ownership:** Constitution Principles III and V
  require `tasks.md` checkbox reconciliation and the `implementing -> done`
  transition to remain with Maxi, with branch finishing only after `done` is
  persisted.
- **Match real harness capabilities:** Packaging must follow the actual v6.3.0
  surfaces, retain the `docs/maxi/` gate wherever code can evaluate it, and
  explicitly document declarative APIs that cannot implement that gate.
- **Keep governed boundaries stable:** Constitution Principle VI, the accepted
  vendoring contract, the 19 Maxi-native skills, and the ten-state FSM must
  remain unchanged unless the compatibility requirement proves otherwise.

## Considered Options

- **Option A: Keep a narrow Maxi-to-SDD adapter and adopt all v6.3.0 packaging surfaces** — retain `x-develop` only for `TNNN`/`Task N` projection, reconciliation, and the return boundary; delegate fix and review mechanics to upstream SDD.
  - ✅ Satisfies driver: Delegate implementation mechanics upstream.
  - ✅ Satisfies driver: Preserve Maxi pipeline ownership.
  - ✅ Satisfies driver: Match real harness capabilities.
  - ✅ Satisfies driver: Keep governed boundaries stable.
  - ❌ Accepts a documented global-bootstrap limitation for Gemini and Kimi because their declarative APIs cannot evaluate the project gate first.
- **Option B: Remove `x-develop` and let upstream SDD own execution through branch finishing** — translate Maxi artifacts once, then accept upstream's lifecycle unchanged.
  - ✅ Satisfies driver: Delegate implementation mechanics upstream.
  - ❌ Violates driver: Preserve Maxi pipeline ownership, because upstream would finish the branch before Maxi reconciles its authoritative checkboxes and persists `done`.
  - ❌ Violates driver: Keep governed boundaries stable, because the Maxi task interface would no longer have an owner.
- **Option C: Preserve the v6.1.1 model and implement v6.3.0 fix, review, and packaging behavior inside Maxi** — keep the current harness boundary and add Maxi-specific equivalents.
  - ✅ Satisfies driver: Preserve Maxi pipeline ownership.
  - ❌ Violates driver: Delegate implementation mechanics upstream, because Maxi would duplicate capabilities now owned by Superpowers SDD.
  - ❌ Violates driver: Match real harness capabilities, because Kimi, Gemini, Devin, and Hermes would remain absent or bespoke.

## Decision

Choose **Option A**.

- Retain `x-develop` as the single `TNNN`-to-`Task N` compatibility adapter.
  It projects and reconciles Maxi tasks but does not implement its own SDD fix
  loop or implementation-review policy.
- Delegate the v6.3.0 task fix loop, task reviews, and final implementation
  review to upstream `superpowers:subagent-driven-development`.
- Intercept upstream at its Finish boundary and return to `/maxi:implement`
  before workspace deletion, branch finishing, or Maxi's terminal status
  transition. `/maxi:implement` validates the result, persists
  `implementing -> done`, then invokes
  `superpowers:finishing-a-development-branch`.
- Add or complete the v6.3.0 packaging surfaces for Cursor, Kimi Code, Gemini
  CLI, Devin CLI, and Hermes Agent while retaining the existing supported
  harness mechanisms.
- Retain `docs/maxi/` gating for every executable adapter, including the shared
  hook, OpenCode, Pi, and Hermes.
- Accept and document the unavoidable declarative bootstrap exception for
  Gemini and Kimi. Their installed-plugin bootstrap may load globally because
  their APIs cannot inspect the working directory first.
- Refine
  [0008-session-start-injection-gated-on-docs-maxi](0008-session-start-injection-gated-on-docs-maxi.md)
  only for those declarative installed-plugin surfaces. ADR-0008 remains
  accepted and continues to govern executable adapters.
- Keep exactly 19 Maxi-native skills and the existing ten-state FSM.

This decision supersedes
[0016-align-upstream-harness-model](0016-align-upstream-harness-model.md).

## Consequences

- **Good:** Maxi reuses upstream v6.3.0 SDD task, fix, and implementation-review behavior instead of maintaining a fork.
- **Good:** Maxi remains the sole owner of its task checkboxes and `done` transition, and branch finishing cannot precede the terminal artifact state.
- **Good:** Cursor, Kimi, Gemini, Devin, and Hermes receive explicit, testable packaging surfaces aligned with upstream.
- **Good:** Executable bootstrap remains silent outside projects containing `docs/maxi/`.
- **Good:** The native skill inventory and FSM stay unchanged.
- **Bad:** `x-develop` must maintain a deterministic compatibility projection and result handoff between two task models.
- **Bad:** Gemini and Kimi may load Maxi bootstrap in non-Maxi projects; their platform limitation must remain visible in documentation.
- **Bad:** The v6.1.1 harness decision becomes historical and its packaging inventory is replaced by this decision.

## Confirmation

- [check-x-develop-adapter.sh](../../../tests/check-x-develop-adapter.sh) verifies deterministic `TNNN`/`Task N` projection, reconciliation, resume identity, and the result gate.
- [check-implement-handoff.sh](../../../tests/check-implement-handoff.sh) verifies one checkbox owner, upstream review ownership, return before branch finishing, `done` after a valid SDD result, and branch finishing only after `done`.
- [check-declarative-harnesses.sh](../../../tests/check-declarative-harnesses.sh), [check-cursor-hooks.sh](../../../tests/check-cursor-hooks.sh), [check-pi-extension.sh](../../../tests/check-pi-extension.sh), and [check-hermes-plugin.sh](../../../tests/check-hermes-plugin.sh) verify the v6.3.0 packaging surfaces and the executable/declarative gate boundary.
- [check-sync-invariant.sh](../../../tests/check-sync-invariant.sh) preserves byte identity for vendored Superpowers skills.
- [check-skill-count.sh](../../../tests/check-skill-count.sh) and [check-status-consistency.sh](../../../tests/check-status-consistency.sh) keep the Maxi-native skill count at 19 and the FSM at ten states.
- [run-all.sh](../../../tests/run-all.sh) must pass before commit.
