---
slug: 0019-artifact-analysis-convergence
spec_slug: 0019-artifact-analysis-convergence
created: 2026-08-03
updated: 2026-08-04
revision: 21
derived_from:
  - spec.md@7
---

# Bounded Minimal Replay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give future forward-pipeline specs visible document revisions, independently reviewed handoffs, and a confirmed minimal replay that stops at human review instead of looping through unrelated phases.

**Architecture:** `specify` alone marks a newly created forward spec as eligible for bounded replay; revisions on an unmarked historical spec do not opt it in. Structural owners keep revisions and writer provenance on their documents, while `spec.md` and `plan.md` carry the smallest pending continuation marker needed to resume the `spec review -> plan -> plan review -> tasks` chain after interruption. `x-review` remains the sole review-record writer, owner gates validate its complete persisted envelope, and the read-only Bash 3.2 planner validates the confined graph, rejects stale ancestors, and only formats the next consent-bounded segment.

**Tech Stack:** Markdown skill instructions, Bash 3.2, POSIX tools already used by the test suite, existing shell-test helpers, and vendored `superpowers:requesting-code-review`.

## Global Constraints

- Apply only when `specify` created the root `spec.md` with the exact eligibility marker `replay_contract: bounded-v1`. Revision metadata alone never enables replay. Do not change migration or reverse-engineering behavior, retrofit existing specs, or add this marker from any other skill.
- Version exactly `spec.md`, `research.md`, `data-model.md`, `contracts/*.md`, `reviews/spec-review.md`, `plan.md`, `reviews/plan-review.md`, `tasks.md`, and `analysis.md` when those documents are created.
- `quickstart.md` may remain a planning output under the existing plan template, but it is not pipeline-owned by this feature: never add its revision or provenance to the forward graph, and never make it a direct input of `plan.md`, `tasks.md`, or `analysis.md`.
- Keep `revision`, `writer_context`, `structural_contributors`, exact `derived_from`, and any owner-managed `replay_continuation` marker with the owning document; a structural change increments only that document.
- Define `reviewed_sha256` as the SHA-256 of the canonical structural projection of the reviewed artifact: omit only top-level `status:` and `updated:` lines from the first YAML frontmatter block, preserve every other line in order, and hash the retained lines with one LF after each. A status/timestamp-only write therefore preserves a valid review, while any other byte change invalidates it.
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
├── clarify/SKILL.md                      # spec owner plus persisted plan continuation
├── plan/{SKILL.md,plan-template.md}      # spec-review presenter plus plan owner
├── tasks/{SKILL.md,tasks-template.md}    # plan-review presenter plus tasks owner
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

## Task 7: Make replay eligibility and review evidence fail closed

**Files:**

- Modify: `skills/specify/SKILL.md`
- Modify: `skills/x-review/{SKILL.md,review-template.md}`
- Modify: `skills/plan/SKILL.md`
- Modify: `skills/tasks/SKILL.md`
- Modify: `skills/revise/replay-plan.sh`
- Modify: `tests/check-bounded-replay.sh`
- Modify: `tests/check-x-review.sh`
- Modify: `tests/check-templates.sh`
- Modify: `tests/fixtures/bounded-replay/current/spec.md`
- Modify: `tests/fixtures/bounded-replay/current/reviews/{spec-review.md,plan-review.md}`
- Modify: `tests/fixtures/bounded-replay/self-review/reviews/spec-review.md`

**Interfaces:**

- `skills/specify/SKILL.md` is the only producer of the root marker `replay_contract: bounded-v1`, written during creation of a new normal forward spec. The marker is absent from `spec-template.md`, migration skills, reverse-engineering skills, and this pre-mechanism 0019 `spec.md`. The planner returns `UNSUPPORTED_LEGACY` with exit 4 for every unmarked root, even when that root already has `revision`, `writer_context`, or `derived_from`; a present duplicate or non-exact marker is malformed metadata and exits 2.
- `reviewed_sha256` is the canonical structural digest defined in Global Constraints. `x-review`, the planner, `plan`, and `tasks` use the same projection. Changing only root-frontmatter `status:` or `updated:` keeps the digest valid; changing the body, revision, writer, contributors, dependencies, continuation marker, or any other frontmatter invalidates it.
- A valid persisted review has exactly the ten top-level fields already produced by `x-review`: `revision`, `writer_context`, `structural_contributors`, `derived_from`, `reviewed_document`, `reviewed_revision`, `reviewed_sha256`, `reviewer_context`, `reviewer_context_matches_harness`, and `verdict`. The `plan` and `tasks` owner gates validate this complete envelope before any delegation, artifact write, or status/timestamp write: exact field set; positive record and reviewed revisions; exactly one mapped direct input; canonical and unique contributors; canonical `writer_context` and `reviewer_context`; writer equals reviewer and appears in contributors; exact mapped subject and current subject revision; current structural digest; harness equality exactly `true`; verdict exactly `approved`; and reviewer absence from the subject contributors.
- The frontmatter parser accepts list entries only while parsing the immediately active `structural_contributors` or `derived_from` block. Any stray YAML list item elsewhere in frontmatter, including one after a scalar field or after a list has ended, is malformed metadata and exits 2.

- [ ] **Step 1: Write the four RED regression groups**

  In `tests/check-bounded-replay.sh`, add a marked forward fixture and three eligibility cases: exact marker succeeds, a revision-bearing copy without the marker exits 4 with only `UNSUPPORTED_LEGACY`, and the actual unmarked 0019 directory also exits 4 without changing its digest. Add duplicate and wrong-value marker cases that exit 2. Assert migration and reverse-engineering skills/templates never write the marker.

  Add canonical-digest cases in both planner and owner-contract checks: mutate only `status:` and `updated:` after an approved review and require acceptance; mutate one body byte and each other structural frontmatter class and require rejection. Add complete-envelope negative cases for each missing, extra, duplicate, malformed, mismatched, stale, self-reviewed, or non-approved field/property listed in the interface. Add stray list items after `revision`, `writer_context`, `reviewed_sha256`, and an ended `derived_from` block in both a normal document and a review record; every case must exit 2 before any proposal record.

- [ ] **Step 2: Prove RED independently**

  Run without short-circuiting:

  ```bash
  bash tests/check-bounded-replay.sh
  bounded_status=$?
  bash tests/check-x-review.sh
  review_status=$?
  bash tests/check-templates.sh
  template_status=$?
  test "$bounded_status" -ne 0 && test "$review_status" -ne 0 && test "$template_status" -ne 0
  ```

  Expected: the wrapper exits 0 because the current planner infers eligibility from revision metadata, hashes exact bytes, permits stray list entries, and the owner skills validate only a subset of the review envelope.

- [ ] **Step 3: Implement only the strict metadata boundary**

  Use `superpowers:test-driven-development` for the planner/test change and `superpowers:writing-skills` for every `SKILL.md` edit. Make the root eligibility check occur before document-graph parsing so unmarked revision-bearing 0019 is unsupported rather than malformed. Implement the structural digest directly in the existing `x-review` instructions, owner-gate instructions, and `replay-plan.sh`; do not add an executable review helper. Tighten the existing parser and review validator in place. Preserve the unchanged FSM, Bash 3.2 compatibility, migrations, the read-only planner, and the bans on `workflow.md` and `.maxi-ops`.

- [ ] **Step 4: Prove GREEN**

  Run:

  ```bash
  bash tests/check-bounded-replay.sh
  bash tests/check-x-review.sh
  bash tests/check-templates.sh
  bash tests/check-migrate-from-speckit.sh
  bash tests/check-migrate-from-brownfield.sh
  bash tests/check-frontmatter.sh
  /bin/bash -n skills/revise/replay-plan.sh tests/check-bounded-replay.sh tests/check-x-review.sh tests/check-templates.sh
  git diff --check
  ```

  Expected: every command exits 0; marked fixtures use replay, revision-bearing unmarked 0019 is unsupported, non-structural status/timestamp changes retain review validity, structural changes invalidate it, owner gates enforce the full envelope, and every stray list item fails closed.

- [ ] **Step 5: Complete the independent review gate**

  Give a fresh read-only reviewer the Task 7 diff and the four regression groups. If it reports a finding, keep T007 unchecked, assign the complete finding batch to a fresh corrector using the same TDD and writing-skills constraints, rerun Step 4, and send the corrected diff to a fresh independent re-review. Check T007 only after the reviewer returns approved with no open findings.

## Task 8: Persist and resume the complete spec-to-tasks continuation

**Files:**

- Modify: `skills/clarify/SKILL.md`
- Modify: `skills/revise/SKILL.md`
- Modify: `skills/plan/SKILL.md`
- Modify: `skills/tasks/SKILL.md`
- Modify: `skills/x-review/SKILL.md`
- Modify: `skills/revise/replay-plan.sh`
- Modify: `tests/check-bounded-replay.sh`
- Modify: `tests/check-x-review.sh`
- Modify: `tests/fixtures/bounded-replay/current/{spec.md,plan.md}`

**Interfaces:**

- On the exceptional source-spec rollback to `specified`, `revise` writes `replay_continuation: clarify@<new-spec-revision>` with the structural `spec.md` mutation. Its first proposal remains consent-gated. If that proposal is rejected, ambiguous, or interrupted, `/maxi:clarify` invokes `bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed spec.md --previous-revision <current-spec-revision> --start-phase clarify --resume-current-source`, displays `CONTINUATION|clarify@<current-spec-revision>` plus `REPLAY|clarify`, and waits for a fresh literal `yes`. `--resume-current-source` is legal only for that exact path/phase/marker combination and never writes or executes.
- After `clarify` completes for an eligible spec, including the no-content-change branch, `spec.md` carries `replay_continuation: plan@<current-spec-revision>` in the same owner write that leaves the spec at `clarified`. The marker is owner-managed handoff metadata, not a status or dependency edge. It binds only the current spec revision and survives rejection, ambiguity, or session interruption.
- When `x-review` creates or replaces the matching `reviews/spec-review.md`, it captures review revision 0 or `n`, writes revision 1 or `n + 1`, then calls `bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed reviews/spec-review.md --previous-revision <0-or-n> --start-phase plan`. The planner validates the full Task 7 envelope plus the exact spec marker, displays `CONTINUATION|plan@<current-spec-revision>` and `REPLAY|plan`, and executes nothing.
- For an eligible clarified spec with that marker, `/maxi:plan` is the no-write resume presenter. Before any planning delegation or write it calls `bash skills/revise/replay-plan.sh --spec-dir <spec-dir> --changed reviews/spec-review.md --previous-revision <current-spec-review-revision> --start-phase plan --resume-current-review`, displays the same two records, and waits for a new exact lowercase `yes`. Rejection, ambiguity, or interruption changes no byte; a later `/maxi:plan` repeats the presentation. Immediately before planning, it revalidates the marker, complete review envelope, and current ancestry.
- A plan created or structurally corrected as that replay segment writes `replay_continuation: tasks@<new-plan-revision>` with `plan.md`, returns only to `planned`, calls the ordinary changed-plan proposal, and stops at `REVIEW_REQUIRED|plan.md|<new-plan-revision>`. `x-review` then uses the analogous plan-review post-write command, and `/maxi:tasks` remains the no-write plan-review presenter. Its fresh exact `yes` runs task extraction and may then propose `analyze`; neither review approval is reused as replay consent.
- `--resume-current-review` accepts exactly two combinations: `reviews/spec-review.md` with start phase `plan`, or `reviews/plan-review.md` with start phase `tasks`. Before either resume output, the planner requires the review to be current, the subject marker to match the subject revision, and the subject plus every transitive `derived_from` ancestor to be current. For plan resume, a stale `spec.md`, support artifact, or spec review therefore exits 2 before `CONTINUATION` or `REPLAY`, even when `plan.md` and its plan review still match each other.
- Normal owner-managed plan/tasks correction statuses remain exactly those already approved after T006. No new status, phase, helper, ledger, or automatic review is introduced.

- [ ] **Step 1: Write RED end-to-end continuation cases**

  Add one deterministic scenario that begins with a structural `spec.md` revision, rejects and then resumes the persisted `clarify` presentation, completes `clarify`, creates/replaces the spec review, presents and consents to `plan`, creates/replaces the plan review, then presents and consents to `tasks`. Assert the exact marker binding and planner records at every boundary, the absence of `specify`, a fresh literal `yes` for each resumed segment, and no review creation by the planner.

  Add separate reject, non-`yes`, and fresh-session-interruption cases for both `/maxi:plan` and `/maxi:tasks`; each later invocation must re-present from the current persisted review without rewriting it. Add plan-resume fixtures where only `spec.md`, `research.md`, `data-model.md`, one `contracts/*.md`, or `reviews/spec-review.md` becomes stale while plan and plan review bytes remain matched; each must exit 2 with no continuation output or write. Keep the existing plan-only correction and tasks-only correction cases.

- [ ] **Step 2: Prove RED**

  Run: `bash tests/check-bounded-replay.sh && bash tests/check-x-review.sh`

  Expected: nonzero because current continuation persistence starts only at a corrected plan, spec-review writes do not display or preserve their successor, `plan` cannot resume the current spec review, and plan-review resume ignores stale ancestors.

- [ ] **Step 3: Implement the bounded chain**

  Use `superpowers:test-driven-development` for planner/test work and `superpowers:writing-skills` for all five `SKILL.md` edits. Extend the existing marker and resume mechanisms in the same planner rather than creating another coordinator or executable helper. Keep review writes solely in `x-review`, artifact writes solely in their owner skills, and all planner paths read-only. Revalidate the current marker before resumed clarification, and revalidate the full Task 7 review envelope plus ancestry both when presenting and immediately before an approved post-review owner write.

- [ ] **Step 4: Prove GREEN**

  Run:

  ```bash
  bash tests/check-bounded-replay.sh
  bash tests/check-x-review.sh
  bash tests/check-templates.sh
  bash tests/check-frontmatter.sh
  /bin/bash -n skills/revise/replay-plan.sh tests/check-bounded-replay.sh tests/check-x-review.sh
  git diff --check
  ```

  Expected: every command exits 0; the persisted chain resumes at `clarify`, reaches `tasks` through both independent reviews after any supported re-presentation, and every plan resume with a stale ancestor fails before output or writes.

- [ ] **Step 5: Complete the independent review gate**

  Give a fresh read-only reviewer the Task 8 diff and the exact end-to-end/stale-ancestor cases. If it reports a finding, keep T008 unchecked, use a fresh corrector with the same TDD and writing-skills constraints, rerun Step 4, and obtain a fresh independent re-review. Check T008 only after approved re-review with no open findings.

## Task 9: Synchronize documented gates and finish deterministic verification

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
- The same five documents describe the future-only eligibility marker, structural review digest, full owner-gate envelope, persisted spec-to-plan-to-tasks continuation, stale-ancestor rejection, and explicit plan/tasks correction statuses without presenting any of them as new phases or statuses.

- [ ] **Step 1: Add RED documentation checks**

  Extend deterministic checks to require every interface completed by Tasks 7 and 8 across Mandatory Sync 5, README, the `x-review` registration, the read-only `replay-plan.sh` contract, the targeted `check-x-review.sh` entry, and the updated native skill count. Do not retain a superseded coordination or validation framework.

- [ ] **Step 2: Prove RED**

  Run: `bash tests/check-skill-count.sh && bash tests/check-skills-present.sh && bash tests/check-status-consistency.sh`

  Expected: nonzero until the Mandatory Sync 5 and registration are aligned.

- [ ] **Step 3: Update documentation and integration inventory**

  Update the Mermaid flow, delegation map, session guidance, contributor guide, architecture tree, README, and fast-tier inventory. State that review handoffs are gates, not statuses or automatic replay phases; reviews are persisted and versioned; and the normal forward FSM remains unchanged. Do not claim the optional agentic integration tier passed without terminal output.

- [ ] **Step 4: Verify deterministically and independently review**

  Run in this order:

  ```bash
  bash tests/check-bounded-replay.sh
  bash tests/check-x-review.sh
  bash tests/check-templates.sh
  bash tests/check-migrate-from-speckit.sh
  bash tests/check-migrate-from-brownfield.sh
  bash tests/check-skills-present.sh
  bash tests/check-skill-count.sh
  bash tests/check-status-consistency.sh
  bash tests/check-frontmatter.sh
  /bin/bash -n skills/revise/replay-plan.sh tests/check-bounded-replay.sh tests/check-x-review.sh tests/check-templates.sh
  bash tests/run-all.sh
  git diff --check
  ```

  Then run `maxi:doc-consistency` and prepare a fresh independent whole-feature review package. Its `Base` must be the pre-T001 implementation base `8257869e22edbc0e81dd5aa6cf1d89768b1cf5f7`, not `44b840a76040603d88d9092546b155633d95a815`. The reviewer must inspect the exact working tree, all six repaired findings, committed T001-T006, uncommitted corrections/documentation, `git status --short`, and every path in the explicit staging manifest. Apply every finding batch with a fresh corrector, rerun the complete deterministic sequence, and obtain independent re-review before checking T009.

  Integration remains opt-in. If it is attempted again and repeats the known failure, preserve the exact terminal evidence `Passed: 0 / 13` and `--- FAIL: Integration tier`, report it as failed, and do not retry. Never describe an interrupted, `Killed: 9`, or 0/13 run as green. Prepare the staging manifest only, then request fresh authorization before staging or committing.

## Requirement Coverage

| Requirement | Planned tasks |
|---|---|
| FR-001 | 3, 7 |
| FR-002 | 1, 3, 4 |
| FR-003 | 3, 4, 7, 8 |
| FR-004 | 3, 4, 7 |
| FR-005 | 1, 5, 7, 8 |
| FR-006 | 5, 8 |
| FR-007 | 5, 6, 8 |
| FR-008 | 6, 8 |
| FR-009 | 6, 8 |
| FR-010 | 6 |
| FR-011 | 5, 6, 8 |
| FR-012 | 3, 7 |
| FR-013 | 1, 5, 7, 8 |
| FR-014 | 6, 8, 9 |
| FR-015 | 5, 6, 8 |
| FR-016 | 6, 8 |
| FR-017 | 3, 4, 7 |
| FR-018 | 4, 6, 7, 8 |
| FR-019 | 4, 6, 7, 8 |
| FR-020 | 6 |
| FR-021 | 4, 6, 7, 8 |
| FR-022 | 4, 5, 7, 8 |
| FR-023 | 4, 5, 6, 8 |
| SC-001 | 1, 3, 4, 7 |
| SC-002 | 1, 5, 8 |
| SC-003 | 1, 5, 6, 8 |
| SC-004 | 1, 5, 8 |
| SC-005 | 6 |
| SC-006 | 3, 7 |
| SC-007 | 4, 6, 7, 8 |
| SC-008 | 4, 5, 7, 8 |
| SC-009 | 6 |

## Execution Handoff

T001 through T006 remain completed historical milestones. Resume sequentially at Task 7, Task 8, then Task 9. Use a fresh implementer and an independent reviewer for each remaining task; apply each finding batch with a fresh corrector, rerun that task's GREEN gate, and obtain re-review before marking it complete. Do not run concurrent implementers on shared skills, planner, tests, or documentation. Tasks 7 through 9 are one atomic final change set because they change pipeline gates and activate Mandatory Sync 5; do not stage or commit a subset.
