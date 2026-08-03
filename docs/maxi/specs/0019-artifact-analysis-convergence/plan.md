---
slug: 0019-artifact-analysis-convergence
spec_slug: 0019-artifact-analysis-convergence
created: 2026-08-03
updated: 2026-08-03
revision: 16
derived_from:
  - spec.md@7
---

# Bounded Minimal Replay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give future forward-pipeline specs visible document revisions, independently reviewed handoffs, and a confirmed minimal replay that stops at human review instead of looping through unrelated phases.

**Architecture:** Each structural owner write records its revision and writer context. A new internal `x-review` skill wraps `superpowers:requesting-code-review` with a read-only current-artifact envelope and is the sole writer of the two pre-phase review records. The read-only Bash 3.2 planner validates the confined revision graph, identifies stale descendants, and emits only executable phases up to the next review handoff; it neither creates reviews nor invokes a phase.

**Tech Stack:** Markdown skill instructions, Bash 3.2, POSIX tools already used by the test suite, existing shell-test helpers, and vendored `superpowers:requesting-code-review`.

## Global Constraints

- Apply only to specs created through the normal forward Maxi pipeline after this feature ships. Do not change migration or reverse-engineering behavior, or retrofit existing specs.
- Version exactly `spec.md`, `research.md`, `data-model.md`, `contracts/*.md`, `reviews/spec-review.md`, `plan.md`, `reviews/plan-review.md`, `tasks.md`, and `analysis.md` when those documents are created.
- Keep `revision`, `writer_context`, `structural_contributors`, and exact `derived_from` metadata with the owning document; a structural change increments only that document.
- Do not add an FSM status, a workflow ledger, write-ahead recovery, agentic integration test, or ADR-currentness framework.
- This feature MUST NOT create or write `workflow.md` or `.maxi-ops`.
- Keep the shared replay script read-only. It must neither write files, create review records, nor invoke skills.
- All `SKILL.md` edits, including the new `x-review` skill, use `superpowers:writing-skills`; vendored skills remain byte-identical.
- Bash must remain compatible with Bash 3.2.
- Do not stage, commit, or push without separate explicit user authorization.

---

## Constitution Check

| Principle | Result |
|---|---|
| I. Mandatory Spec-Driven Pipeline | Pass. Every forward phase remains present; review is a handoff gate, not a replacement phase. |
| II. Delegate to Superpowers | Pass. `x-review` delegates reviewer work to `superpowers:requesting-code-review` and owns only the persisted review artifact. |
| III. Strict Pipeline | Pass. Replay excludes only unaffected ancestors and stops before a required independent review rather than bypassing it. |
| IV. ADR for non-trivial decisions | Pass. [0019-bounded-forward-artifact-replay](../../adr/0019-bounded-forward-artifact-replay.md) and [0020-persisted-independent-handoff-reviews](../../adr/0020-persisted-independent-handoff-reviews.md) are accepted for the revision boundary and review gates. |
| V. Artifacts Over Chat | Pass. Review verdict, subject revision, reviewer context, and verification result live in versioned review artifacts. |
| VI. Single Responsibility per Skill | Pass. `x-review` owns review records, document producers own their artifacts and transitions, and the planner only reads and calculates. |

## Accepted Decisions

- [0019-bounded-forward-artifact-replay](../../adr/0019-bounded-forward-artifact-replay.md) records the future-forward revision boundary and read-only bounded replay.
- [0020-persisted-independent-handoff-reviews](../../adr/0020-persisted-independent-handoff-reviews.md) records persisted independent review handoffs with the unchanged FSM.

## Project Structure

```text
skills/
├── specify/{SKILL.md,spec-template.md}  # initial version/context metadata
├── x-review/
│   ├── SKILL.md                          # sole review-record owner
│   └── review-template.md                # spec and plan review record schema
├── clarify/SKILL.md                      # structural spec write then replay proposal
├── plan/{SKILL.md,plan-template.md}      # requires current approved spec review
├── tasks/{SKILL.md,tasks-template.md}    # requires current approved plan review
├── analyze/SKILL.md                      # independent final review report
├── implement/SKILL.md                    # validates independent analysis entry
└── revise/
    ├── SKILL.md                          # rollback, consent, replay handoff
    └── replay-plan.sh                    # read-only graph and pause calculation
tests/
├── check-bounded-replay.sh               # graph, handoff, consent, no-write checks
├── check-x-review.sh                     # review-envelope and provenance checks
├── check-templates.sh                    # version/context template contracts
├── check-skills-present.sh               # x-review registration
├── run-all.sh                            # fast-tier registration
└── fixtures/bounded-replay/              # forward, review, malformed, legacy graphs
docs/
├── pipeline-flow.md
├── delegation-map.md
└── architecture.md
```

## Task 1: Establish failing revision, provenance, review, and replay fixtures

**Files:**

- Create: `tests/check-bounded-replay.sh`
- Create: `tests/fixtures/bounded-replay/current/{spec.md,research.md,data-model.md,contracts/api.md,reviews/spec-review.md,plan.md,reviews/plan-review.md,tasks.md,analysis.md}`
- Create: `tests/fixtures/bounded-replay/{legacy,missing-review,self-review,cycle,escape}/`

**Interfaces:**

- Planner command: `bash skills/revise/replay-plan.sh --spec-dir <dir> --changed <relative-path> --previous-revision <n> --start-phase <phase>`.
- Planner records: `CHANGED|<path>|<old>|<new>`, lexical `STALE|<path>`, `REVIEW_REQUIRED|<subject>|<revision>`, then dependency-ordered `REPLAY|<phase>`.
- Review record fields: `revision`, `writer_context`, `structural_contributors`, `derived_from`, `reviewed_document`, `reviewed_revision`, `reviewer_context`, and `verdict`.

- [ ] **Step 1: Write the RED fixture runner**

  Use `tests/lib/test-helpers.sh`. Every current fixture document must declare revision 1 and a unique writer context; review fixtures must have an approved verdict and a reviewer context absent from the reviewed document's structural contributors. Copy fixtures into a worktree-local directory before mutation and calculate source digests before and after every planner call.

- [ ] **Step 2: Add exact RED cases**

  Mutate copied `plan.md` from revision 1 to 2 and append its new writer context. Assert the exact records:

  ```text
  CHANGED|plan.md|1|2
  STALE|analysis.md
  STALE|reviews/plan-review.md
  STALE|tasks.md
  REVIEW_REQUIRED|plan.md|2
  ```

  Add independent cases for a tasks-only mutation (`REPLAY|analyze`), a revised source spec (`REPLAY|clarify` then `REVIEW_REQUIRED|spec.md|<new>`), a clarified spec change (spec-review handoff), a newly approved `reviews/spec-review.md` (`REPLAY|plan`), a newly approved `reviews/plan-review.md` (`REPLAY|tasks`, then `REPLAY|analyze`), missing review, self-review, malformed contributor metadata, multiple direct inputs, disconnected cycle, physical symlink escape, and legacy input returning `UNSUPPORTED_LEGACY` with no write.

- [ ] **Step 3: Prove RED**

  Run: `bash tests/check-bounded-replay.sh`

  Expected: nonzero because `skills/revise/replay-plan.sh` and `skills/x-review/` do not yet exist.

## Task 2: Register deterministic bounded-replay coverage

**Files:**

- Modify: `tests/run-all.sh`

- [ ] **Step 1: Register only deterministic coverage**

  Add `run_check "$TESTS_DIR/check-bounded-replay.sh" "Bounded replay"` to `tests/run-all.sh`. Do not add an agentic integration scenario.

## Task 3: Add revision and writer-context contracts to forward producers

**Files:**

- Modify: `skills/specify/{SKILL.md,spec-template.md}`
- Modify: `skills/plan/{SKILL.md,plan-template.md}`
- Modify: `skills/tasks/{SKILL.md,tasks-template.md}`
- Modify: `skills/analyze/SKILL.md`
- Modify: `tests/check-templates.sh`
- Modify: `tests/check-bounded-replay.sh`

**Interfaces:**

- All structural producer outputs carry `revision: 1`, a unique `writer_context`, and `structural_contributors` containing that context.
- Every derived output carries direct input paths and exact revisions in `derived_from`.

- [ ] **Step 1: Add RED template checks**

  Require the forward spec, plan, and task templates to instruct owners to write `revision`, `writer_context`, and `structural_contributors`. Require derived-document instructions to include `derived_from`. Add negative assertions that migration and reverse-engineering skills and fixtures have no new revision or provenance requirement.

- [ ] **Step 2: Prove RED**

  Run: `bash tests/check-templates.sh`

  Expected: nonzero with missing version/provenance contract assertions.

- [ ] **Step 3: Update producer contracts through `superpowers:writing-skills`**

  Define the exact direct inputs: support artifacts derive from `spec.md`; `plan.md` derives from `spec.md`, every support artifact read, and the current approved `reviews/spec-review.md`; `tasks.md` derives from all documents it reads, including `plan.md` and the current approved `reviews/plan-review.md`; `analysis.md` derives from the current `spec.md`, support artifacts, `plan.md`, and `tasks.md`.

  A structural write increments only its own revision and appends its generated writer context. Status, timestamps, task-completion checkboxes, and `related_adrs` remain non-structural. Existing, migrated, and reverse-engineered specs receive no inferred metadata.

- [ ] **Step 4: Prove GREEN**

  Run: `bash tests/check-templates.sh && bash tests/check-migrate-from-speckit.sh && bash tests/check-migrate-from-brownfield.sh`

  Expected: all commands exit 0.

## Task 4: Add the independent review-record owner

**Files:**

- Create: `skills/x-review/SKILL.md`
- Create: `skills/x-review/review-template.md`
- Create: `tests/check-x-review.sh`
- Modify: `tests/check-skills-present.sh`
- Modify: `tests/check-templates.sh`
- Modify: `tests/check-bounded-replay.sh`

**Interfaces:**

- `x-review` consumes one subject path and current revision plus one fresh reviewer context issued by the harness.
- It wraps `superpowers:requesting-code-review` with a read-only subject envelope: relative path, claimed revision, SHA-256 of the exact current bytes, the complete current artifact content, the harness-issued reviewer context, and the relevant spec requirements. The reviewer returns the envelope's path, revision, SHA-256, reviewer context, findings, and verdict.
- It rejects a result whose envelope does not match the current subject or whose returned reviewer context does not exactly equal the harness-issued context; on an approved matching verdict only, it writes either `reviews/spec-review.md` or `reviews/plan-review.md`.
- It is the sole writer of review records; it never changes `status`, runs a successor phase, writes `workflow.md`, or writes `.maxi-ops`.

- [ ] **Step 1: Define RED review-record assertions**

  In `tests/check-x-review.sh`, require the review template to persist the exact field set from Task 1 plus the reviewed SHA-256 and the harness-context equality result. Require the owner to reject an unknown subject, revision or SHA-256 mismatch, a reviewer context different from the harness-issued context, non-approved verdict, missing context, or a reviewer context present in the subject's structural contributors. Require creation to initialize, and update to append, the record's writer context in `structural_contributors`. Require the report body to preserve the review findings and verdict rather than only a chat response.

- [ ] **Step 2: Prove RED**

  Run the two expected failures without short-circuiting:

  ```bash
  bash tests/check-x-review.sh
  x_review_status=$?
  bash tests/check-skills-present.sh
  skill_status=$?
  test "$x_review_status" -ne 0 && test "$skill_status" -ne 0
  ```

  Expected: exit 0 only because both underlying commands fail: `x-review` and its targeted contract check are absent.

- [ ] **Step 3: Author the skill through `superpowers:writing-skills`**

  Create one internal, single-purpose review-record owner. It must retain the vendored review checklist and output format rather than duplicate a code-review prompt. Because the vendored skill's git range cannot identify an uncommitted current artifact, supply the subject envelope as additional context and instruct the reviewer to evaluate those exact bytes, not `HEAD`. On approval, compare the returned path, revision, SHA-256, and reviewer context with the current subject and the harness-issued context; only then create or structurally update the selected record, set its direct input to the current subject revision, set the verified reviewer context as its writer context, initialize or append that context in the record's `structural_contributors`, and retain the findings plus both verification results. After the record write, it may call the read-only planner to display, but never execute, the remaining continuation.

- [ ] **Step 4: Prove the isolated review-record contract**

  Run: `bash tests/check-x-review.sh && bash tests/check-skills-present.sh && bash tests/check-frontmatter.sh`

  Expected: all commands exit 0. `tests/check-bounded-replay.sh` remains RED until Task 5 creates `skills/revise/replay-plan.sh`.

## Task 5: Implement the read-only bounded replay planner

**Files:**

- Create: `skills/revise/replay-plan.sh`
- Modify: `tests/check-bounded-replay.sh`

**Interfaces:**

- Command: `bash skills/revise/replay-plan.sh --spec-dir <directory> --changed <relative-path> --previous-revision <n> --start-phase <phase>`.
- Exit `0` for a valid proposal, `2` for bad arguments or metadata, `3` for missing paths/cycles/physical escapes, `4` for `UNSUPPORTED_LEGACY`.
- It accepts only the supported pipeline-owned paths and emits no writes.

- [ ] **Step 1: Parse only the confined supported graph**

  Use Bash 3.2 with `awk`, `sed`, `grep`, and `sort`. Resolve selected documents via `cd -P`; reject any document or declared input outside the selected spec directory. Parse positive revisions, non-empty context IDs, contributor lists, and `derived_from` entries in `<relative path>@<positive integer>` form. Validate all supported documents, including disconnected cycles, before computing descendants.

- [ ] **Step 2: Calculate stale descendants and review handoffs**

  Compare each direct input revision with the named current document, then walk reverse dependencies once. A changed `spec.md` makes its spec review stale; a changed `plan.md` makes its plan review stale. Emit lexical stale records. If the next successor needs an absent or stale review, emit `REVIEW_REQUIRED` and no later `REPLAY` record. A newly approved current `reviews/spec-review.md` maps to the remaining `plan` segment; a newly approved current `reviews/plan-review.md` maps to `tasks -> analyze`. The planner never creates a review record or invokes a phase.

- [ ] **Step 3: Map executable producers only**

  Preserve this mapping before the first review handoff:

  ```text
  spec.md via revise  -> clarify, then review spec.md
  spec.md via clarify -> review spec.md
  plan.md             -> review plan.md
  reviews/spec-review.md -> plan
  reviews/plan-review.md -> tasks, analyze
  tasks.md            -> analyze
  analysis.md         -> no replay
  support document    -> plan, then review plan.md when plan structurally changes
  ```

  Do not emit `specify`. Emit every executable phase at most once and retain dependency order.

- [ ] **Step 4: Prove GREEN and no-write behavior**

  Run: `bash tests/check-bounded-replay.sh`

  Expected: exit 0 and `All bounded replay checks passed.` Source-tree digests remain identical after every planner call.

## Task 6: Gate producers and analysis on independent evidence

**Files:**

- Modify: `skills/clarify/SKILL.md`
- Modify: `skills/plan/SKILL.md`
- Modify: `skills/tasks/SKILL.md`
- Modify: `skills/analyze/SKILL.md`
- Modify: `skills/implement/SKILL.md`
- Modify: `skills/revise/SKILL.md`
- Modify: `tests/check-bounded-replay.sh`

**Interfaces:**

- `plan` accepts only a current approved `reviews/spec-review.md` whose reviewer context is independent of `spec.md` contributors.
- `tasks` accepts only the analogous plan review.
- `analyze` records and verifies an independent reviewer context before `implement`; `implement` rejects an absent, stale, failed, or non-independent analysis.
- Replay has one explicit `yes` per displayed executable segment and pauses at every review handoff.

- [ ] **Step 1: Add RED owner-contract checks**

  Require `plan` and `tasks` to stop before their first write or status transition when the matching review is missing, rejected, malformed, stale, or self-reviewed. Require `revise` and `clarify` to render the changed revisions, stale paths, executable sequence, and `REVIEW_REQUIRED` boundary. Require the response to be literal `yes`; silence, `ok`, and prior consent produce no phase invocation. Add a fixture where analysis fails after one approved replay and assert that no further correction or replay begins until a new explicit decision. Require `implement` to reject non-independent analysis.

- [ ] **Step 2: Prove RED**

  Run: `bash tests/check-bounded-replay.sh`

  Expected: nonzero because existing owner skills have no review-gate contract.

- [ ] **Step 3: Update skills through `superpowers:writing-skills`**

  Keep all writes with their owner. `x-review` creates review records, `plan` and `tasks` only validate them, and the planner only reads. `revise` retains the exceptional `specified` target for real source-spec gaps. After an approved executable segment reaches a review handoff, it stops; after a matching external review, it displays the remaining segment and obtains a new literal `yes` before executing it. Do not create or write `workflow.md` or `.maxi-ops`.

- [ ] **Step 4: Prove GREEN**

  Run: `bash tests/check-bounded-replay.sh && bash tests/check-frontmatter.sh`

  Expected: both commands exit 0.

## Task 7: Synchronize documented gates and finish deterministic verification

**Files:**

- Modify: `docs/pipeline-flow.md`
- Modify: `docs/delegation-map.md`
- Modify: `skills/using-maxi/SKILL.md`
- Modify: `AGENTS.md`
- Modify: `docs/architecture.md`
- Modify: `README.md`
- Modify: `tests/check-skill-count.sh`
- Modify: `tests/check-skills-present.sh`
- Modify: `tests/run-all.sh`

**Interfaces:**

- The Mandatory Sync 5 describes the unchanged FSM and the two external-review handoffs.
- The documented maxi-native skill count increases by one for `x-review`.

- [ ] **Step 1: Add RED documentation checks**

  Extend deterministic checks to require the two review handoffs, the unchanged FSM, the `x-review` registration, the read-only `replay-plan.sh` contract, the targeted `check-x-review.sh` entry, and the updated native skill count. Do not retain a superseded coordination or validation framework.

- [ ] **Step 2: Prove RED**

  Run: `bash tests/check-skill-count.sh && bash tests/check-skills-present.sh && bash tests/check-status-consistency.sh`

  Expected: nonzero until the Mandatory Sync 5 and registration are aligned.

- [ ] **Step 3: Update documentation and integration inventory**

  Update the Mermaid flow, delegation map, session guidance, contributor guide, architecture tree, README, and fast-tier inventory. State that review handoffs are gates, not statuses or automatic replay phases; reviews are persisted and versioned; and the normal forward FSM remains unchanged. Do not claim the optional agentic integration tier passed without terminal output.

- [ ] **Step 4: Verify deterministically and independently review**

  Run in this order:

  ```bash
  bash tests/check-bounded-replay.sh
  bash tests/check-templates.sh
  bash tests/check-skills-present.sh
  bash tests/check-skill-count.sh
  bash tests/check-status-consistency.sh
  bash tests/check-frontmatter.sh
  bash tests/run-all.sh
  git diff --check
  ```

  Then run `maxi:doc-consistency` and a fresh independent whole-diff review. If an integration run is attempted, report its exact terminal result; do not call an interrupted or `Killed: 9` run green. Prepare an explicit staging manifest only, then request fresh authorization before staging or committing.

## Requirement Coverage

| Requirement | Planned tasks |
|---|---|
| FR-001 to FR-005 | 1, 2, 4 |
| FR-006 to FR-011 | 1, 4, 5 |
| FR-012 to FR-016 | 2, 4, 5 |
| FR-017 to FR-023 | 1, 3, 4, 5, 6 |
| SC-001 to SC-006 | 1, 2, 4, 5 |
| SC-007 to SC-009 | 1, 3, 5 |

## Execution Handoff

Implement sequentially. Use a fresh implementer and an independent reviewer for each task; apply each finding batch with a fresh corrector, then obtain re-review before marking the task complete. Do not run concurrent implementers on shared skills, test runners, or documentation surfaces.
