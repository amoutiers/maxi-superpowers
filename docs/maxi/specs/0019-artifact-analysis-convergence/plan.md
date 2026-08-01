---
slug: 0019-artifact-analysis-convergence
spec_slug: 0019-artifact-analysis-convergence
created: 2026-08-01
updated: 2026-08-01
related_adrs: [0017-revision-bound-artifact-graph, 0018-independent-analysis-bounded-convergence]
---

# Implementation Plan: Artifact Revisions and Bounded Analysis Convergence

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Maxi detect stale artifacts mechanically, require an independent passing semantic analysis before implementation, and converge through a bounded, consent-gated minimal replay instead of restarting the pipeline.

**Architecture:** Add one read-only internal `x-artifact-graph` skill as the single owner of revision, dependency, ADR, status, and coverage validation, plus an `x-converge` coordinator that owns exactly one consented correction-and-reanalysis goal. Artifact-producing skills maintain canonical metadata, lifecycle skills persist operational events in a separate `workflow.md` ledger, and `analyze` coordinates an isolated semantic reviewer while remaining the sole writer of the report. Existing artifacts stay revision 0 until their owning skill changes them.

**Tech Stack:** Markdown/YAML frontmatter, Bash 3.2-compatible scripts, standard Unix tools (`awk`, `grep`, `sed`, `sort`, `shasum` or `sha256sum`), optional Claude CLI integration scenarios.

## Global Constraints

- Follow the full Maxi pipeline; no phase or status gate may be bypassed.
- Delegate every `SKILL.md` creation or edit to `superpowers:writing-skills`; never hand-edit vendored skills.
- ADR bodies remain revision-free and append-only.
- Do not add an FSM status.
- Preserve revision-free legacy artifacts until an owning structural write occurs.
- Keep Tasks 1–12 as review checkpoints without commits. Create one final atomic implementation commit only after the Mandatory Sync 5, all fast tests, and independent review pass; integration scenarios remain opt-in.
- Update the Mandatory Sync 5 files atomically with any pipeline-gate or delegation change.
- All repository artifacts, code comments, and messages embedded in skills remain English.

---

## Summary

The clarified [spec](spec.md) replaces timestamp-based trust with an explicit mutable-artifact DAG, preserves constitution and ADR semantics on separate edge types, and changes final analysis from a report-only ceremony into a fail-closed gate. One approved correction cycle replays only the affected producer and descendants. A separate workflow ledger keeps lifecycle evidence from accidentally staling functional artifacts.

The plan has four layers:

1. Canonical metadata and a deterministic read-only validator.
2. Revision-aware artifact producers and a workflow ledger.
3. Independent semantic analysis with stable findings and bounded correction.
4. Implementation gating, documentation parity, deterministic fixtures, and opt-in agentic scenarios.

## Technical Context

**Language/Version**: Markdown, YAML frontmatter subset, Bash compatible with macOS Bash 3.2
**Primary Dependencies**: Existing skill loader; `tests/lib/test-helpers.sh`; standard Unix tools; SHA-256 via `shasum -a 256` with `sha256sum` fallback
**Storage**: Files under `docs/maxi/`, with per-spec `spec.md`, `workflow.md`, plan support artifacts, `tasks.md`, and `analysis.md`
**Testing**: Fast Bash contract/fixture tests through `bash tests/run-all.sh`; opt-in Claude CLI behavior scenarios through `bash tests/run-all.sh --integration`
**Target Platform**: Claude Code, Codex, OpenCode, Antigravity, Cursor, Pi, plus documented marketplace harnesses
**Project Type**: Multi-harness agentic workflow plugin
**Performance Goals**: Validate a normal spec graph in one process and one pass per artifact; no network or agent call before deterministic validation passes
**Constraints**: No YAML package dependency; validator must be read-only; independent review is an orchestration property and fails closed when isolation is unavailable; installed-plugin script lookup resolves relative to the loaded skill resource, never the target project cwd
**Scale/Scope**: 2 new internal skills, 2 internal Bash resources, 10 forward/lifecycle skills, 6 templates plus 1 reviewer prompt, 5 mandatory-sync docs, 5 new deterministic check scripts, and opt-in behavior scenarios

## Constitution Check

*GATE: Passed before Phase 0 research; re-checked after Phase 1 design.*

| Principle | Pass / Fail | Notes |
|---|---|---|
| I. Mandatory Spec-Driven Pipeline | ✓ | The feature itself follows specify, clarify, plan, tasks, analyze, implement and strengthens phase gates. |
| II. Delegate to Superpowers, Never Duplicate | ✓ | `writing-skills`, execution, TDD, and code review remain delegated. `x-artifact-graph` is Maxi-specific contract validation not supplied by Superpowers. |
| III. Strict Pipeline — No Skipping | ✓ | Failed/stale/provisional analysis cannot advance or implement. Minimal replay follows the same mandatory phases from the correct rollback point. |
| IV. ADR for Every Non-Trivial Architectural Decision | ✓ | [0017-revision-bound-artifact-graph](../../adr/0017-revision-bound-artifact-graph.md) and [0018-independent-analysis-bounded-convergence](../../adr/0018-independent-analysis-bounded-convergence.md) are accepted; the latter supersedes [0002-pipeline-backflow](../../adr/0002-pipeline-backflow.md). |
| V. Artifacts Over Chat | ✓ | Revisions, dependencies, findings, reviewer evidence, dispositions, and correction consent persist in files. |
| VI. Single Responsibility per Skill | ✓ | Validation has one internal owner; `analyze` owns one report; `revise` owns rollback and workflow events; `x-converge` owns one bounded correction goal; producers only maintain their artifacts. |

No constitution violation requires Complexity Tracking. The plan deliberately adds two internal skills because copying graph logic into four phase skills or leaving cross-phase replay to implicit agent continuation would violate Principles II, V, and VI.

## Project Structure

### Documentation (this feature)

```text
docs/maxi/specs/0019-artifact-analysis-convergence/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── analysis-report.md
│   ├── artifact-metadata.md
│   └── validator-cli.md
└── tasks.md                         # created by /maxi:tasks, not this phase
```

### Source Code (repository root)

```text
skills/
├── x-artifact-graph/               # new internal read-only validation owner
│   ├── SKILL.md
│   └── artifact-graph.sh
├── x-converge/                     # new internal one-cycle replay coordinator
│   └── SKILL.md
├── analyze/
│   ├── SKILL.md
│   ├── analysis-template.md        # new current-report schema
│   └── reviewer-prompt.md          # new read-only independent reviewer contract
├── revise/
│   ├── SKILL.md
│   └── workflow-template.md        # new per-spec lifecycle/correction ledger
├── constitution/{SKILL.md,constitution-template.md}
├── specify/{SKILL.md,spec-template.md}
├── clarify/SKILL.md
├── plan/{SKILL.md,plan-template.md}
├── tasks/{SKILL.md,tasks-template.md}
├── implement/SKILL.md
├── park/SKILL.md
├── resume/SKILL.md
├── cancel/SKILL.md
├── x-adr/SKILL.md
└── using-maxi/SKILL.md

tests/
├── check-artifact-graph.sh
├── check-analysis-convergence.sh
├── check-revision-producers.sh
├── fixtures/artifact-graph/
│   ├── fresh/
│   ├── stale-plan/
│   ├── task-only/
│   ├── legacy/
│   ├── adr-status/
│   ├── cycles/
│   └── analysis-gates/
├── integration/
│   ├── run-agentic-scenarios.sh
│   └── scenarios/
│       ├── deterministic-stop.txt
│       ├── self-review-handoff.txt
│       ├── independent-pass.txt
│       └── correction-limit.txt
└── run-all.sh

docs/{pipeline-flow.md,delegation-map.md,architecture.md}
AGENTS.md
README.md
```

**Structure Decision**: `x-artifact-graph` is a new internal skill rather than a repository-global utility because installed skills must carry their own resources and phase skills need one explicit delegation contract. Its script resolves from the loaded skill directory and receives the target project root explicitly. `workflow.md` belongs to `revise`; `specify` requests idempotent initialization through the revise-owned ledger resource and never writes the ledger directly.

## Decisions

> **Auto-populated by `/maxi:plan` when architectural choices are recorded as ADRs.**

| ADR | Title | Status |
|---|---|---|
| [0017](../../adr/0017-revision-bound-artifact-graph.md) | Revision-bound artifact graph and workflow ledger | accepted |
| [0018](../../adr/0018-independent-analysis-bounded-convergence.md) | Read-only independent analysis with crash-safe bounded convergence | accepted; supersedes [0002-pipeline-backflow](../../adr/0002-pipeline-backflow.md) |

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| — | — | — |

---

## Phase 1: Deterministic artifact contract

### Task 1: Freeze the metadata and CLI contracts in fixtures

**Files:**
- Create: `tests/fixtures/artifact-graph/**`
- Create: `tests/check-artifact-graph.sh`

**Interfaces:**
- Produces: canonical `path@revision` fixtures and expected `CODE|artifact|dependency_path|message` output consumed by Task 2.
- Produces: exit-code contract `0,2,3,4,5,6,7,8,9` from [validator-cli](contracts/validator-cli.md).

- [ ] **Step 1: Add RED fixtures for schema, staleness, cycles, ADR status, and legacy revision 0**

Each fixture is a complete `docs/maxi/` tree. The fresh fixture's root `spec.md` starts with:

```yaml
revision: 2
validated_against: ../../constitution.md@1
```

Its `plan.md` carries only `revision` and the exact `derived_from` set. No derived artifact carries `validated_against`.

Include negative fixtures for duplicate edges, unsorted edges, `../` escape, declared revision mismatch, missing target, cycle, superseded ADR, unknown FR, missing SC coverage, self-review, `not-run`, failed result, stale `validated_workflow` correction hash, overlay duplicate targets, staged-path escape/symlink, digest mismatch, and forbidden implement-overlay fields. Include a passing fixture where park/resume changes the ledger revision but not its correction hash and a staged correction fixture that validates under canonical identities.

- [ ] **Step 2: Write the failing validator test**

`tests/check-artifact-graph.sh` must call `skills/x-artifact-graph/artifact-graph.sh validate` for every fixture, assert the exact exit code, and compare sorted output to `expected.txt` using `assert_files_equal`.

- [ ] **Step 3: Run RED**

Run: `bash tests/check-artifact-graph.sh`
Expected: FAIL with `file not found: skills/x-artifact-graph/artifact-graph.sh`.

- [ ] **Step 4: Record the RED checkpoint without committing**

Keep the focused failing output as TDD evidence. Do not register the failing check in `tests/run-all.sh` and do not commit while the implementation or Mandatory Sync 5 is incomplete. Task 2 carries this checkpoint to GREEN; Task 12 registers every new focused check together after all are GREEN.

### Task 2: Author `x-artifact-graph` and the read-only Bash validator

**Files:**
- Create: `skills/x-artifact-graph/SKILL.md`
- Create: `skills/x-artifact-graph/artifact-graph.sh`
- Modify: `tests/check-skills-present.sh`

**Interfaces:**
- Consumes: `validate --project-root PATH --spec PATH --gate plan|tasks|analyze|implement`.
- Produces: deterministic exit codes and sorted evidence from Task 1; performs no writes.

- [ ] **Step 1: Invoke `superpowers:writing-skills` with the RED fixtures**

The new skill's only responsibility is validation. Its instructions must require callers to resolve `artifact-graph.sh` adjacent to the loaded `SKILL.md`, pass an explicit target project root, and stop if the resource cannot be resolved. Never assume the target project contains the plugin's `skills/` directory.

- [ ] **Step 2: Implement narrow frontmatter parsing**

The parser accepts only the canonical fields needed by the contract. Dependency parsing must split on the final `@`, normalize without `realpath`, reject absolute paths and `..`, resolve directories with `pwd -P`, and confirm the result stays under `<project-root>/docs/maxi`. Overlay parsing accepts only the exact manifest grammar, confines staged paths to the selected spec's `.maxi-ops/<operation-id>/`, substitutes staged bytes for canonical graph reads, and never reports hidden paths as artifact identity.

Required function boundary:

```bash
read_revision()          # file -> integer, missing field => 0
read_dependencies()      # file -> canonical path@revision lines
validate_schema()        # file -> schema errors
validate_graph()         # root artifact -> missing/stale/cycle errors
validate_constitution()  # active artifact set -> marker errors
validate_adrs()          # spec/plan -> accepted immutable references
validate_coverage()      # spec + tasks -> explicit covers-clause errors
validate_gate()          # gate + status + analysis metadata
```

- [ ] **Step 3: Add portable SHA-256 support**

```bash
sha256_file() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else die "SHA-256 tool missing: install shasum or sha256sum"; fi
}
```

Use it to verify the canonical reviewed-finding TSV block when `review_mode` is `independent` or `self-review`.

- [ ] **Step 4: Register the 19th Maxi-native skill**

Add `x-artifact-graph` to `MAXI_SKILLS` in `tests/check-skills-present.sh`. Do not update prose counts until the Mandatory Sync task so the implementation milestone exposes expected documentation drift.

- [ ] **Step 5: Run GREEN and focused shell checks**

Run: `bash -n skills/x-artifact-graph/artifact-graph.sh`
Expected: exit 0.

Run: `bash tests/check-artifact-graph.sh`
Expected: all artifact graph fixtures pass.

- [ ] **Step 6: Review the validator checkpoint without committing**

Inspect the focused diff and retain the GREEN output. Do not commit because the new pipeline skill already requires the still-pending Mandatory Sync 5 update in Task 12.

## Phase 2: Revision-aware producers and workflow ledger

### Task 3: Add canonical metadata to templates

**Files:**
- Modify: `skills/constitution/constitution-template.md`
- Modify: `skills/specify/spec-template.md`
- Modify: `skills/plan/plan-template.md`
- Modify: `skills/tasks/tasks-template.md`
- Create: `skills/analyze/analysis-template.md`
- Create: `skills/revise/workflow-template.md`
- Modify: `tests/check-templates.sh`

**Interfaces:**
- Produces: new source artifacts at revision 1 and derived artifacts with canonical dependency placeholders that owning skills must replace.

- [ ] **Step 1: Extend template assertions first**

Require `revision:` on every mutable template, `derived_from:` on plan/tasks/analysis, `related_adrs: []` on spec and plan, `validated_against:` only on the active root spec template, `validated_workflow:` on analysis, and assert all revision/dependency/validation fields remain absent from `skills/x-adr/adr-template.md` and ADR fixtures.

- [ ] **Step 2: Run RED**

Run: `bash tests/check-templates.sh`
Expected: FAIL on missing `revision`, `derived_from`, analysis template, and workflow template.

- [ ] **Step 3: Apply exact template defaults**

Source templates use `revision: 1`. Derived templates include:

```yaml
revision: 1
derived_from: []
```

`spec-template.md` additionally includes `validated_against: null`. `plan-template.md` includes `related_adrs: []`. `analysis-template.md` includes `validated_workflow: null`, `result: failed`, `review_mode: not-run`, `review_origin: none`, `reviewer_ref: null`, and `reviewed_findings_sha256: null`. `workflow-template.md` contains `revision: 1` and the two exact event markers, with no `derived_from`. Owning skills populate the exact dependency matrix from [artifact-metadata](contracts/artifact-metadata.md); the validator rejects missing and extra edges.

- [ ] **Step 4: Run GREEN**

Run: `bash tests/check-templates.sh`
Expected: PASS, including explicit ADR absence checks.

- [ ] **Step 5: Review the template checkpoint without committing**

Inspect the template/test diff and retain the GREEN output for the final evidence bundle. The change remains uncommitted until Task 13.

### Task 4: Make artifact owners increment revisions exactly once

**Files:**
- Create: `tests/check-revision-producers.sh`
- Modify via `superpowers:writing-skills`: `skills/constitution/SKILL.md`, `skills/specify/SKILL.md`, `skills/clarify/SKILL.md`, `skills/plan/SKILL.md`, `skills/tasks/SKILL.md`, `skills/analyze/SKILL.md`, `skills/x-adr/SKILL.md`, `skills/using-maxi/SKILL.md`, `skills/migrate-from-speckit/SKILL.md`, `skills/migrate-from-brownfield/SKILL.md`
- Modify: `tests/check-migrate-from-speckit.sh`, `tests/check-migrate-from-brownfield.sh`

**Interfaces:**
- Produces: revision 1 for new artifacts; `current + 1` for structural writes; no increment for the closed exemption set.

- [ ] **Step 1: Add RED textual contract checks**

`tests/check-revision-producers.sh` asserts each owner states all four cases: new artifact 1, legacy 0 to 1, structural increment once, exempt-only write unchanged. It also asserts `x-adr` forbids revision metadata.

- [ ] **Step 2: Run RED**

Run: `bash tests/check-revision-producers.sh`
Expected: FAIL for every unchanged producer.

- [ ] **Step 3: Edit each `SKILL.md` through `superpowers:writing-skills`**

Use this shared rule verbatim in every mutable-artifact owner:

```markdown
Before a governed write, read the current `revision` (missing = 0). If the write changes body content or non-exempt frontmatter, write `revision: current + 1` in the same operation. If every change is in the closed exemption set (`updated`, `status`, `parked_from`, task checkbox state, `related_adrs`, `validated_against`, `validated_workflow`), preserve the current revision or preserve legacy absence. A mixed write increments exactly once.
```

`specify` requests idempotent `workflow.md` initialization through `revise/workflow-ledger.sh` and the revise-owned template. `plan` assigns exact dependencies to every artifact it creates and, after an accepted post-plan ADR scan, copies the returned ADR slug into plan-side `related_adrs` as exempt traceability because the decision is already structural content of that plan revision. `tasks` derives from spec, plan, and every support artifact it actually reads. `analyze` derives from the complete reviewed input set.

- [ ] **Step 4: Keep legacy migrations non-destructive**

Do not bulk-add revisions in migration scripts. Add instructions and tests that brownfield/done imports remain historical, active spec-kit imports use the virtual revision-0 graph, and a legacy tasked import without explicit coverage rolls back only to `planned` for task regeneration. Assert both migration scripts continue to omit `revision`, `derived_from`, and `workflow.md` creation.

- [ ] **Step 5: Run GREEN**

Run: `bash tests/check-revision-producers.sh`
Expected: PASS.

- [ ] **Step 6: Review the producer checkpoint without committing**

Inspect the producer contracts together so the exemption list and dependency matrix cannot drift. Keep the changes uncommitted until the atomic final gate.

### Task 5: Move lifecycle and rollback history to `workflow.md`

**Files:**
- Modify via `superpowers:writing-skills`: `skills/park/SKILL.md`, `skills/resume/SKILL.md`, `skills/cancel/SKILL.md`, `skills/revise/SKILL.md`, `skills/clarify/SKILL.md`
- Create: `skills/revise/workflow-ledger.sh`
- Create: `tests/check-workflow-ledger.sh`
- Add fixtures under: `tests/fixtures/artifact-graph/workflow/`

**Interfaces:**
- Consumes: explicit consent plus current spec status.
- Produces: sequential `E001` events and ledger revision increments; only exempt spec frontmatter changes for park/resume/cancel/rollback.

- [ ] **Step 1: Write RED lifecycle fixtures**

Assert that task-only revise, park, resume, and cancel change no content-artifact revision. Assert legacy missing ledger becomes revision 1 on the first event and later events increment once.

- [ ] **Step 2: Replace `## Clarifications` lifecycle writes**

Through `superpowers:writing-skills`, remove lifecycle-event appends from `spec.md`. `revise` owns the adjacent `workflow-ledger.sh` initialization, append, and recovery resource; no other skill writes `workflow.md` directly. `specify` delegates idempotent initialization, while lifecycle skills delegate event appends with an explicit project root and perform their status write under the same operation ID. `revise` gains `specified` as the exceptional target for an identified spec gap and uses the fixed owner map from [research](research.md).

`clarify` detects an active spec-gap correction event, asks only questions tied to its finding IDs, preserves all unrelated prior Q&A, and refuses to broaden the correction batch without a new direct user decision.

- [ ] **Step 3: Enforce correction authorization**

For analysis-triggered correction, `revise` accepts the complete finding batch only after exact user `yes`, appends `correction-authorized`, then appends semantic write-ahead `correction-consumed` before the first rollback mutation. `workflow-ledger.sh` owns atomic semantic-ledger writes and the separate `.maxi-ops` journal. Before a phase mutation, its owner stages the complete output set and validates it with `--overlay-manifest`, then persists exact before/after hashes and revisions outside `workflow.md`. Every target uses a journaled start, atomic replacement, completion, and the recovery table from [data-model](data-model.md). Ambiguous acknowledgement remains no consent. `revise` never edits the defective content itself.

- [ ] **Step 4: Run focused tests**

Run: `bash tests/check-workflow-ledger.sh`
Expected: PASS for new, legacy, lifecycle, rollback, cycle-limit, idempotency-key reuse, and interruption fixtures at authorization, consumption, phase preparation, status/artifact replacement, acknowledgement, and phase completion.

- [ ] **Step 5: Review the workflow checkpoint without committing**

Inspect the lifecycle and correction event writes as one unit. Keep the changes uncommitted so later analysis and coordinator checks can validate the complete protocol.

## Phase 3: Shared forward gates and explicit coverage

### Task 6: Gate `plan` and `tasks` through `x-artifact-graph`

**Files:**
- Modify via `superpowers:writing-skills`: `skills/plan/SKILL.md`, `skills/tasks/SKILL.md`
- Modify: `skills/tasks/tasks-template.md`
- Modify: `tests/check-artifact-graph.sh`

**Interfaces:**
- Consumes: validator gates `plan` and `tasks`.
- Produces: no phase transition until the newly written artifact set validates deterministically and its owning skill confirms it introduced no normative behavior absent from `spec.md`.

- [ ] **Step 1: Add pre-write and post-write gate fixtures**

Cover malformed current inputs, a plan that introduces an absent normative behavior, incomplete derived inputs, and a post-write stale dependency. Expected behavior is fail closed without status transition.

- [ ] **Step 2: Delegate validation in both skills**

`plan` invokes `x-artifact-graph --gate plan` before planning, writes its candidate support artifacts and plan, runs the post-plan ADR scan, and copies each accepted returned slug to plan-side `related_adrs`. It then invokes `--gate plan --candidate-plan plan.md` before `planned`, including exact ADR parity. `tasks` invokes `--gate tasks` before extraction, writes its candidate, then invokes `--gate tasks --candidate-tasks tasks.md` before `tasked`. Candidate modes validate completed outputs without circularly requiring the status they authorize.

After candidate graph validation and regardless of whether the root marker is already current, each phase compares the complete post-write graph to the current constitution immediately before transition. A pass updates only root `spec.md.validated_against` and reruns the candidate validator. A conflict delegates a `gate-failed` append to `revise/workflow-ledger.sh` with owner, evidence, and rollback target, then stops without transition.

Before either transition, the owner performs a semantic source-of-truth check: every public behavior, constraint, error contract, and success condition in the new artifact must cite an existing FR or SC. If a required behavior is missing, the owner records a spec-gap finding and stops at the current status. It never repairs the gap only in plan/support/tasks.

- [ ] **Step 3: Add explicit coverage syntax**

Every generated task ends with `(covers: FR-..., SC-...)`. `tasks` builds the complete requirement set, allows only the explicit `maxi:coverage-exempt` marker with non-empty reason, and refuses to transition if any required ID is absent or any task references an unknown ID.

- [ ] **Step 4: Run tests**

Run: `bash tests/check-artifact-graph.sh`
Expected: PASS for plan/tasks gate and coverage fixtures.

- [ ] **Step 5: Review the forward-gate checkpoint without committing**

Inspect plan/tasks delegation and coverage fixtures together. Preserve the passing output and continue without a commit.

## Phase 4: Independent analysis and bounded convergence

### Task 7: Define the independent reviewer and stable report schema

**Files:**
- Create: `skills/analyze/reviewer-prompt.md`
- Modify: `skills/analyze/analysis-template.md`
- Create: `tests/check-analysis-convergence.sh`
- Add: `tests/fixtures/artifact-graph/analysis-gates/**`

**Interfaces:**
- Reviewer consumes a frozen packet and returns findings only.
- Coordinator produces the canonical hashed TSV finding set, registry dispositions, delta, and result.

- [ ] **Step 1: Write RED report fixtures**

Cover stable ID reuse, moved-location semantic equivalence, non-recycled IDs, exact TSV bytes and digest, forbidden bytes/escapes, CRLF, hash mismatch, invalid accepted rationale, invalid deferred target, constitution waiver attempt, pass-clean, pass-with-exceptions, self-review, not-run, second-failure stop, original unresolved findings, newly discovered findings, and classification disagreements.

- [ ] **Step 2: Author the reviewer prompt through `superpowers:writing-skills`**

The prompt must state: no writes, no correction, no status changes, full inventory before recommendation, earliest content owner, all eight semantic passes, prior-ID reconciliation, and an explicit independence declaration. It returns a structured finding set but never decides user dispositions.

- [ ] **Step 3: Finalize `analysis-template.md`**

Required sections are `Validation Evidence`, `Review Evidence`, `Reviewed Finding Set`, `Finding Registry`, `Delta`, `Original Unresolved`, `Newly Discovered`, `Classification Disagreements`, `Coverage Summary`, `Constitution Alignment`, `ADR Alignment`, `Correction Proposal`, `Independent Review Handoff`, and `Metrics`.

- [ ] **Step 4: Add canonical hash verification**

The test changes one hashed field while preserving the old digest and expects exit 7. It changes only a disposition and expects the digest to remain valid. It hashes the same exact LF-terminated fixture with `shasum` and `sha256sum` when present, rejects raw TAB/CR/LF/NUL and malformed backslash escapes inside fields, and proves header/final-LF inclusion.

- [ ] **Step 5: Run RED**

Run: `bash tests/check-analysis-convergence.sh`
Expected: fixture-shape checks pass; coordinator behavior assertions fail until Task 8.

- [ ] **Step 6: Record the analysis RED checkpoint without committing**

Keep the failing coordinator assertions as TDD evidence. Do not register a failing fast-tier state or commit; Task 8 must make the report contract GREEN first.

### Task 8: Rewrite `analyze` as a fail-closed one-writer coordinator

**Files:**
- Modify via `superpowers:writing-skills`: `skills/analyze/SKILL.md`
- Modify: `tests/check-analysis-convergence.sh`

**Interfaces:**
- Consumes: deterministic validator, reviewer prompt, prior report, workflow ledger.
- Produces: revisioned `analysis.md`; transitions only independent `pass-clean` or `pass-with-exceptions` with current inputs.

- [ ] **Step 1: Stop before semantic review on deterministic failure**

Write a `failed` report with `review_mode: not-run`, no reviewer identity/hash, actionable validator evidence, and status unchanged at `tasked`.

- [ ] **Step 2: Dispatch or hand off honestly**

When a fresh reviewer primitive exists, dispatch one context and pass the frozen packet. Set `review_origin: isolated-agent`. If unavailable, run at most a provisional self-review, set `review_origin: self`, keep status `tasked`, and emit the complete separate-session handoff. A random ID alone may never set `independent`.

When a separate session consumes the handoff, it returns structured findings and an independence declaration without writing a project file. An authoring coordinator verifies and persists the response in `analysis.md`. The reviewer emits a correction handoff on failure and remains eligible for the preferred second review.

- [ ] **Step 3: Reconcile the persistent registry**

Reuse exact fingerprints automatically, accept reviewer-declared equivalence for moved findings, allocate `max + 1` for new findings, retain resolved rows, and compute new/unchanged/resolved delta. Preserve the same independent reviewer reference for the second pass when the runtime can resume it.

- [ ] **Step 4: Calculate result and correction proposal**

Validate severities and dispositions exactly as [analysis-report](contracts/analysis-report.md) defines. A failed independent first pass inventories all findings before proposing one owner-mapped correction batch. If the workflow ledger shows a consumed cycle since the preceding failed independent review, delegate a `correction-stopped` append to `revise/workflow-ledger.sh` before writing the failed report, compute `validated_workflow` from that updated ledger, and do not roll back.

Before declaring failure for MEDIUM/LOW findings, offer only the valid disposition choices. A non-empty accepted rationale or active follow-up spec changes disposition fields outside the semantic hash and may yield `pass-with-exceptions`; `resolved` always requires source correction and another review.

- [ ] **Step 5: Transition only after post-write validation**

Invoke `x-artifact-graph --gate analyze` before review. Rerun whole-graph constitution alignment unconditionally and refresh root `validated_against` if needed while status remains `tasked`. Stage the report operation and invoke `--gate analyze --candidate-analysis analysis.md --overlay-manifest ...` against it; include a prepared semantic workflow update in that overlay only when `correction-stopped` is required. After an independent passing candidate, stage a separate status-only spec operation and invoke `--gate implement --overlay-manifest ...` against the projected `analyzed` spec before atomically applying it. Both operations complete only in `.maxi-ops`; no later workflow event may stale the report. Every non-passing analysis result leaves `tasked`.

- [ ] **Step 6: Run GREEN**

Run: `bash tests/check-analysis-convergence.sh`
Expected: all report, registry, review-mode, and cycle-limit fixtures pass.

Run: `bash tests/check-artifact-graph.sh`
Expected: all gates pass.

- [ ] **Step 7: Review the analysis checkpoint without committing**

Inspect reviewer separation, registry reconciliation, dispositions, result calculation, and status transition together. Preserve the GREEN evidence for Task 13.

### Task 9: Author `x-converge` as the one-cycle replay coordinator

**Files:**
- Create via `superpowers:writing-skills`: `skills/x-converge/SKILL.md`
- Create: `tests/check-convergence-coordinator.sh`
- Modify: `tests/check-skills-present.sh`, `tests/check-analysis-convergence.sh`

**Interfaces:**
- Consumes: a complete failed independent analysis proposal and current `workflow.md` cycle state.
- Produces: exactly one consented chain through `revise`, the owning producer, every stale descendant, and a complete independent `analyze`; never writes content artifacts itself.

- [ ] **Step 1: Freeze the coordinator state machine in RED checks**

Assert the new skill requires: complete inventory before consent, exact rollback map, one explicit user `yes`, no duplicate confirmation in `revise`, authorization consumed before the first rollback write, stable operation IDs, idempotent resume at every write boundary, dependency-order replay, second-failure stop, and one new cycle per later direct decision.

- [ ] **Step 2: Author the skill through `superpowers:writing-skills`**

Use this state machine:

```text
proposed -> authorized -> rollback-started -> replaying -> reanalyzing -> passed|stopped
```

`x-converge` asks the single confirmation after showing findings, owner, rollback status, stale descendants, and exact phase chain. On `yes`, it passes that same direct consent to `revise`, which records `correction-authorized` and semantic write-ahead `correction-consumed` without asking again. It then invokes only the required phase skills. All semantic ledger and external journal writes delegate to `revise/workflow-ledger.sh`. On interruption, the coordinator uses the stable operation ID, external manifest, staged files, and recorded before/after evidence to acknowledge an exact completed output or atomically apply an untouched prepared output once; an ambiguous state records `recovery-conflict` and stops.

Include each pre-analysis `phase-completed` event in that phase's prepared semantic ledger only after every earlier declared output has completed, and do so before the final `analyze` call. The final analysis operation records completion only in `.maxi-ops`. If analysis passes, its current dependency on the semantic ledger hash is terminal evidence and `x-converge` performs no post-analysis workflow write. If analysis fails, `analyze` prepares semantic `correction-stopped` before finalizing the report; the failed report is intentionally non-implementable.

- [ ] **Step 3: Define the four replay chains**

```text
spec.md owner       : revise->specified, clarify, plan, tasks, analyze
plan/support owner  : revise->clarified, plan, tasks, analyze
tasks.md owner      : revise->planned, tasks, analyze
analysis.md owner   : revise->tasked, analyze
```

If the final independent analysis fails, record `stopped` and return control to the user. A later explicit decision creates one new authorization and no more.

- [ ] **Step 4: Connect `analyze` to the coordinator**

After writing a failed independent report with an available cycle, `analyze` invokes `x-converge` with the persisted proposal only from an authoring coordinator context. A separate-session reviewer emits the proposal as a handoff instead. A deterministic failure, self-review, or `not-run` report does not auto-correct and cannot invoke the coordinator.

- [ ] **Step 5: Run focused tests**

Run: `bash tests/check-convergence-coordinator.sh`
Expected: PASS.

Run: `bash tests/check-analysis-convergence.sh`
Expected: PASS, including interrupted replay and second-failure stop fixtures.

- [ ] **Step 6: Review the convergence checkpoint without committing**

Inspect every state transition and replay chain against `workflow.md`. Keep the changes uncommitted until documentation, tests, and skills can land atomically.

## Phase 5: Implementation gate and agentic regression coverage

### Task 10: Make implementation validate evidence, not status alone

**Files:**
- Modify via `superpowers:writing-skills`: `skills/implement/SKILL.md`
- Modify via `superpowers:writing-skills`: `skills/x-adr/SKILL.md`
- Modify: `tests/check-analysis-convergence.sh`, `tests/check-artifact-graph.sh`

**Interfaces:**
- Consumes: `x-artifact-graph --gate implement`.
- Produces: refusal before `implementing` for absent, stale, failed, self-review, not-run, bad hash, invalid disposition, or undeclared mode.

- [ ] **Step 1: Add failing manual-status and ADR-parity fixtures**

Set spec status to `analyzed` in every invalid analysis fixture. Assert implementation still refuses and reports the first invalid artifact/path. Add a current analysis whose spec lists a newly accepted ADR absent from its plan; tasks/analyze/implement gates must report `ADR_REPLAN_REQUIRED`.

- [ ] **Step 2: Delegate the implementation preflight**

Before setting `implementing`, invoke the validator with gate `implement`, rerun whole-graph constitution alignment unconditionally, refresh root `validated_against`, and repeat the implement gate. Remove any status-only success path. Resuming from `implementing` repeats the same preflight against current inputs before the first unchecked task. If `x-adr` accepts a decision after planning, it updates the spec backlink as usual but returns `ADR_REPLAN_REQUIRED`; `implement` stops before any further task or code write and routes through consented `revise -> clarified -> plan -> tasks -> analyze`. The plan owner adds the ADR, advances plan revision, and thereby stales descendants mechanically.

- [ ] **Step 3: Preserve checkbox exemption**

Task completion toggles do not increment tasks revision, so execution does not stale its own analysis. Any task description or coverage edit is structural and requires rollback/re-analysis.

- [ ] **Step 4: Run tests**

Run: `bash tests/check-analysis-convergence.sh`
Expected: 100% of invalid analyzed-status and ADR-parity fixtures refuse.

- [ ] **Step 5: Review the implementation-gate checkpoint without committing**

Inspect all forged-status fixtures and the resume path. Retain passing evidence and continue without a commit.

### Task 11: Add opt-in end-to-end agentic scenarios

**Files:**
- Create: `tests/integration/run-agentic-scenarios.sh`
- Create: `tests/integration/scenarios/*.txt`
- Modify: `tests/integration/run-all.sh`
- Modify: `tests/check-integration-harness.sh`

**Interfaces:**
- Consumes: Claude CLI as the repository's existing integration runtime.
- Produces: behavioral evidence beyond textual skill checks; leaves fixtures in a temporary directory.

- [ ] **Step 1: Add a scenario runner with bounded turns**

The runner creates a temporary Maxi project per scenario, installs the plugin through `--plugin-dir`, uses the existing portable timeout pattern, and asserts files/status with shell checks. It must never operate in the repository worktree.

- [ ] **Step 2: Add four scenarios**

1. Deterministic stale input writes `not-run` and remains `tasked`.
2. No isolation produces a self-review handoff and remains `tasked`.
3. An isolated clean reviewer produces independent pass and `analyzed`.
4. A second failed independent analysis after one consumed cycle performs no rollback.

- [ ] **Step 3: Keep the fast tier runtime-free**

`check-integration-harness.sh` validates that scenarios exist, use temp directories, and retain prompt discovery/timeout guards. Only `tests/run-all.sh --integration` executes them.

- [ ] **Step 4: Run structural and optional behavior checks**

Run: `bash tests/check-integration-harness.sh`
Expected: PASS.

Run when `claude` is available: `bash tests/run-all.sh --integration`
Expected: trigger tests and four agentic scenarios pass. If the runtime cannot expose an isolated reviewer primitive, scenario 3 must be reported unsupported rather than relabeled self-review as independent.

- [ ] **Step 5: Review the agentic-scenario checkpoint without committing**

Inspect temp-directory safety, timeout handling, and unsupported-isolation reporting. Keep the changes uncommitted for the final atomic gate.

## Phase 6: Documentation and system-wide consistency

### Task 12: Synchronize the pipeline contract everywhere

**Files:**
- Modify: `docs/pipeline-flow.md`
- Modify: `docs/delegation-map.md`
- Modify via `superpowers:writing-skills`: `skills/using-maxi/SKILL.md`
- Modify: `AGENTS.md`
- Modify: `docs/architecture.md`
- Modify: `README.md`
- Modify: `tests/check-skill-count.sh`, `tests/check-status-consistency.sh`, `tests/check-skills-present.sh`
- Modify: `tests/run-all.sh`

**Interfaces:**
- Produces: one consistent account of 20 native skills, unchanged 10-status FSM, new validator and convergence delegations, independent analysis, workflow ledger, and implementation evidence gate.

- [ ] **Step 1: Update all Mandatory Sync 5 files in one change**

Show `x-artifact-graph` as an internal read-only delegate of plan/tasks/analyze/implement and `x-converge` as analyze's consented correction coordinator. Show analyze as `tasked -> analyzed` only for independent passing current evidence. Show revise rollback target `specified` for a real spec gap without adding a status.

- [ ] **Step 2: Update counts and testing inventory**

Change the native skill breakdown from 18 to 20 and add all new fast-tier checks to `AGENTS.md`. Update the architecture tree and delegation tables. Keep README user-facing and avoid exposing `x-artifact-graph` or `x-converge` as commands.

- [ ] **Step 3: Register every new GREEN check once**

Only after all five focused scripts pass, add exactly one `run_check` entry for each of `check-artifact-graph.sh`, `check-revision-producers.sh`, `check-workflow-ledger.sh`, `check-analysis-convergence.sh`, and `check-convergence-coordinator.sh`. Assert the run-all inventory contains each basename exactly once, then run the fast tier. No earlier task edits `tests/run-all.sh`.

- [ ] **Step 4: Run deterministic consistency checks**

Run: `bash tests/check-skill-count.sh`
Expected: PASS with 20.

Run: `bash tests/check-status-consistency.sh`
Expected: PASS with the same 10 statuses.

Run: `bash tests/check-skills-present.sh`
Expected: PASS including `x-artifact-graph` and `x-converge`.

- [ ] **Step 5: Invoke `maxi:doc-consistency`**

Run the complete mechanical and semantic review. Fix every confirmed drift across the Mandatory Sync 5 and README before continuing.

- [ ] **Step 6: Review the synchronized documentation without committing**

Inspect the complete Mandatory Sync 5 diff plus README and deterministic consistency checks. Keep it in the same working tree as the implementation so Task 13 can verify and commit the entire pipeline change atomically.

### Task 13: Final coverage, portability, and no-hole audit

**Files:**
- Verify: every file created or modified by Tasks 1–12
- Modify: `docs/maxi/specs/0019-artifact-analysis-convergence/quickstart.md` so its three verification commands exactly match the final script names

**Interfaces:**
- Produces: evidence that every FR-001 through FR-062 and SC-001 through SC-012 maps to an implementation task and test.

- [ ] **Step 1: Build a requirement-to-task matrix**

Extract every FR-001 through FR-062 and SC-001 through SC-012 from [spec](spec.md). Extract every `(covers: ...)` clause from the later `tasks.md`. Fail if any required ID is missing, unknown, or duplicated without a justified multi-task split.

- [ ] **Step 2: Audit agentic failure paths**

Manually trace: no script resource path, no Bash SHA tool, malformed YAML, legacy missing ledger, current constitution marker after a structural write, superseded ADR, ADR accepted after planning, no reviewer isolation, interrupted reviewer, changed reviewer on second pass, invalid disposition, ambiguous consent, correction limit, interruption at every write-ahead boundary, and status manually forged to `analyzed`. Every path must stop or produce a deterministic next action without writing unrelated artifacts.

- [ ] **Step 3: Run complete verification**

Run: `git diff --check`
Expected: exit 0.

Run: `bash tests/run-all.sh`
Expected: `All fast checks passed.`

Run when available: `bash tests/run-all.sh --integration`
Expected: all trigger and supported agentic scenarios pass; unsupported reviewer isolation is explicitly reported and never counted as an independent pass.

- [ ] **Step 4: Run independent code and spec review**

Invoke `superpowers:requesting-code-review` with the spec, plan, task coverage matrix, validator script, all changed skills, and test evidence. A finding returns execution to the task that owns the affected file; rerun that task's focused test and then repeat this final audit. Completion requires zero open CRITICAL/HIGH findings and a valid disposition for every MEDIUM/LOW finding.

- [ ] **Step 5: Commit the verified final milestone**

Build an explicit staging manifest from the exact concrete paths reviewed in Tasks 1–12. Expand fixture inventories to individual files, reject any path not present in those task inventories, and pass those paths explicitly to `git add --`. Do not stage broad directories such as `skills`, `tests`, or `docs`. Inspect `git diff --cached --name-status`, `git diff --cached --check`, and the complete cached diff, then obtain explicit user consent as required by `AGENTS.md`. Create the single implementation commit only after the cached paths exactly equal the reviewed manifest:

```bash
reviewed_manifest=/tmp/maxi-0019-reviewed-paths
while IFS= read -r reviewed_path; do
  test -n "$reviewed_path" || continue
  git add -- "$reviewed_path"
done < "$reviewed_manifest"
git commit -m "feat(0019): enforce bounded artifact analysis convergence"
```

---

## Dependencies and Execution Order

1. Task 1 freezes the contract before code.
2. Task 2 implements the shared validator and blocks every later gate integration.
3. Tasks 3 and 4 establish metadata before any phase can rely on it.
4. Task 5 isolates operational events so minimal replay is sound.
5. Task 6 integrates plan/tasks and explicit coverage.
6. Tasks 7 and 8 define then implement independent analysis.
7. Task 9 supplies the missing owner for one consented cross-phase replay.
8. Task 10 closes implementation entry.
9. Task 11 verifies agent behavior after deterministic contracts are stable.
10. Task 12 synchronizes all pipeline documentation atomically.
11. Task 13 performs the final coverage and no-hole audit.

Tasks that edit the same `SKILL.md` are intentionally sequential. Fixture creation in Tasks 1, 5, and 7 can be parallelized; Task 12 is the single owner of all `tests/run-all.sh` registration after focused GREEN evidence exists.

## Self-Review

- **Spec coverage:** Every requirement domain is assigned: revisions and legacy behavior (Tasks 1–5), shared gates and coverage (Task 6), independent findings/results (Tasks 7–8), bounded correction orchestration (Task 9), implementation refusal (Task 10), agent behavior (Task 11), pipeline parity (Task 12), measurable coverage and verification (Task 13).
- **Planning gap corrected:** Lifecycle and rollback notes no longer mutate `spec.md`; `workflow.md` prevents task-only corrections from staling plan/spec ancestors.
- **Review-mode gap corrected:** Deterministic stop uses `not-run`; self-review may compute a passing result but cannot advance; only actual isolation or a declared separate-session handoff may be independent.
- **Finding-integrity gap corrected:** Independent evidence hashes semantic finding fields; disposition-only updates cannot smuggle semantic changes under an old reviewer label.
- **Portability gap corrected:** The validator uses a Bash 3.2-compatible subset, explicit project root, adjacent skill-resource lookup, no `realpath`, and two SHA-256 tool fallbacks.
- **Enforcement gap bounded:** Fast tests exercise every deterministic rule. Opt-in agentic scenarios exercise orchestration behavior. Unsupported reviewer isolation fails closed instead of being inferred.
- **Continuation gap corrected:** `x-converge` persists one authorization and owns the phase chain; interrupted or automatic continuation cannot manufacture a new cycle.
- **Completeness scan:** No deferred implementation instruction or unspecified code step remains.
- **Type/name consistency:** `workflow.md`, `x-artifact-graph`, `x-converge`, `review_mode`, `review_origin`, `reviewer_ref`, `reviewed_findings_sha256`, `derived_from`, `validated_against`, `validated_workflow`, and `(covers: ...)` use the same names in research, data model, contracts, and tasks.

## Execution Handoff

After `/maxi:tasks` and an independent passing `/maxi:analyze`, implement with `superpowers:subagent-driven-development` using one fresh implementation worker per task, one integration owner, and independent spec-compliance plus code-quality review at every milestone. No implementation starts from this planning phase.
