---
slug: 0023-sdd-handoff-remediation
spec_slug: 0023-sdd-handoff-remediation
created: 2026-09-05
updated: 2026-09-05
---

# Complete SDD Task Handoff Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development through Maxi implement / x-develop after design review and readiness. Steps use checkbox syntax for tracking.

**Goal:** Repair fresh startup and deliver complete reviewed plan tasks without rewriting historical execution evidence.

**Architecture:** Extend the existing native projection adapter with safe base initialization and a distinct v2 identity. Preserve upstream execution and review ownership and existing lineage validators.

**Tech Stack:** Bash 3.2, awk, sed, Git, shasum and the existing test harness.

**Spec:** [0023-sdd-handoff-remediation/spec](spec.md).

## Summary

Two independently testable tasks repair startup and the immutable payload contract. The second task includes compatibility, consumers, skill guidance and synchronized documentation.

## Technical Context

**Language/Version**: Bash 3.2-compatible shell and awk.
**Primary Dependencies**: Existing Git and Unix tools; none added.
**Storage**: Existing immutable projection files and ordinary SDD ledgers.
**Testing**: Existing adapter and handoff suites, then full fast tier.
**Target Platform**: macOS and Linux.
**Project Type**: Multi-harness plugin.
**Performance Goals**: One bounded scan of current plan/tasks plus existing lineage validation; no additional service.
**Constraints**: No vendored changes, source-body loss or historical evidence rewrite.
**Scale/Scope**: Audit F1 and F2 only.

## Global Constraints

- Keep vendored skills byte-identical to the pinned upstream; preserve its execution and review ownership.
- Preserve 19 native skills, ten statuses and three review boundaries.
- Preserve immutable projections, exact ledger anchors, validated completions, reviewer identity, review packages, receipts and complete ruling records.
- Reject invalid input before successor publication or pointer changes; never write through symlinked base components.
- Maintain Bash 3.2 compatibility without new dependencies or generalized parsing infrastructure.
- Write project artifacts and code comments in English; use superpowers:writing-skills for native skill edits.
- Update all Mandatory Sync 5 documents with the changed projection contract.
- Run failing regressions before implementation and the full fast tier after changes.
- Commits require explicit user consent; push, merge and PR operations require separate authorization.

## Constitution Check

| Principle | Pass / Fail | Notes |
|---|---|---|
| I, III: strict pipeline | Pass | Specification and clarification precede planning; review and readiness precede implementation. |
| II: delegation | Pass | Unmodified upstream task-brief, task reviews and final review retain ownership. |
| IV: architectural record | Pass | ADR-0027 records the approved v2 compatibility decision. |
| V: artifacts | Pass | Requirements and implementation steps persist here. |
| VI: responsibility | Pass | Existing projection, reconciliation and terminal validators retain their responsibilities. |

## Project Structure

### Documentation (this feature)

The feature directory contains [spec](spec.md) and this plan; review, tasks and analysis are produced later by their owners.

### Source Code (repository root)

- `skills/x-develop/`: projection, reconciliation and terminal validation owners.
- `tests/check-x-develop-adapter.sh`: composed behavioral regressions.
- `tests/fixtures/x-develop-adapter/`: canonical reordered task fixture.
- `docs/pipeline-flow.md`, `docs/delegation-map.md`, `skills/using-maxi/SKILL.md`, `AGENTS.md`, `docs/architecture.md`: Mandatory Sync 5.

**Structure Decision**: Repair existing owners. No new engine, status, command or runtime library.

## Decisions

[0027-complete-sdd-task-projections](../../adr/0027-complete-sdd-task-projections.md) is accepted and complements [0021-align-superpowers-v6-3-model](../../adr/0021-align-superpowers-v6-3-model.md), retaining its ownership rules.

## Complexity Tracking

No constitutional deviations.

### Task 1: Initialize the SDD base on a truly fresh project

**Files:** Modify `skills/x-develop/project-tasks.sh`; test `tests/check-x-develop-adapter.sh`.

**Interfaces:** Preserve all existing `project-tasks.sh` CLI arguments and its single canonical absolute projection-path stdout result. The helper owns creation of the canonical SDD base before requiring its projections directory.

- [ ] **Step 1: Add the missing fresh-project test.** Use `init_repo` and `seed_case`, then remove the empty directories created by those helpers before calling `run_project`:

```bash
FRESH="$WORK/no-sdd-base"
init_repo "$FRESH"
seed_case "$FRESH"
rmdir "$FRESH/.superpowers/sdd/projections"
rmdir "$FRESH/.superpowers/sdd"
rmdir "$FRESH/.superpowers"
run_project "$FRESH"
assert_eq "$PROJECT_STATUS" 0 'first invocation without any SDD base'
```

- [ ] **Step 2: Run `bash tests/check-x-develop-adapter.sh`.** Record the new assertion failing with `output parent is missing`.
- [ ] **Step 3: Initialize only the canonical components.** Starting from the already resolved physical Git root, visit `.superpowers`, then `.superpowers/sdd`. For each component, reject a symlink or existing non-directory, create it if absent, and require `pwd -P` to equal the expected path. Then use the existing `projections` creation logic. Keep output/state validation before any projection or pointer write.

```bash
for component in "$ROOT/.superpowers" "$ROOT/.superpowers/sdd"; do
  [ ! -L "$component" ] || die 'SDD base component is a symlink'
  [ ! -e "$component" ] || [ -d "$component" ] || die 'SDD base component is not a directory'
  [ -d "$component" ] || mkdir "$component" || die 'cannot create SDD base'
  [ "$(cd -P "$component" && pwd)" = "$component" ] || die 'SDD base escapes physical worktree'
done
```

- [ ] **Step 4: Cover both existing components as files, external symlinks and dangling symlinks.** Preserve the existing rejection checks. Re-run the adapter suite and verify the fresh fixture now succeeds without touching an external sentinel.
- [ ] **Step 5: Verify and prepare the scoped commit.** Run the fast tier and review the diff; proposed subject: `fix: initialize the canonical SDD base before projection`. Commit only after the applicable consent.

### Task 2: Deliver complete plan tasks without rewriting existing evidence

**Files:** Modify `skills/x-develop/project-tasks.sh`, `reconcile-tasks.sh`, `record-terminal.sh`, `result-contract.sh`, `skills/x-develop/SKILL.md`; test `tests/check-x-develop-adapter.sh` and `tests/fixtures/x-develop-adapter/{plan,tasks}.md`; update Mandatory Sync 5 and relevant assertions in `tests/check-implement-handoff.sh` / `tests/check-skill-count.sh`.

**Interfaces:** New projections use `sdd_projection: maxi-v2` and basename `<slug>-v2-p-<plan12>-t-<tasks12>-sdd.md`. Existing v1 projections remain immutable predecessors. Current execution uses v2; both versions remain verifiable as historical lineage. Canonical TNNN records map bijectively to executable original `Task N` headings through the existing terminal `(plan Task N)` annotation.

- [ ] **Step 1: Add composed assertions after running upstream `task-brief`.** Keep the existing task order T003, T001, T002 and assert actual payload, not only labels:

```bash
assert_has "$WORK/task-1-brief.md" 'src/three.txt' 'brief retains third-task file'
assert_has "$WORK/task-1-brief.md" 'Write the complete third task body through end of file.' 'brief retains implementation detail'
assert_has "$WORK/task-2-brief.md" 'Keep this line after the backtick fence.' 'brief survives fenced heading'
assert_has "$WORK/task-3-brief.md" 'Keep this line after the tilde fence.' 'brief survives tilde fence'
```

- [ ] **Step 2: Run the adapter suite and capture these failures.** Explicitly replace the old expectation that plan bodies are absent, documenting why the reviewed behavior changes. Do not remove tampering or lineage assertions.
- [ ] **Step 3: Use the already extracted plan sections.** Parse exactly one terminal mapping per canonical task; reject missing, duplicate, non-positive or unknown mappings and unmapped executable plan tasks before creating any projection. Retain the plan preamble and render the full mapped task body after the TNNN heading and canonical checkbox line. Correct shell prefix stripping with a quoted literal pattern:

```bash
prefix="- [ ] $id "
description="${line#"$prefix"}"
printf '\n### Task %s: %s %s\n\n%s\n' "$projected" "$id" "$description" "$line" >> "$output"
section="$(awk -v task="$mapping" '$0 == task { print NR }' "$PLAN_PARTS/order")"
[ -n "$section" ] || die 'missing mapped plan section'
cat "$PLAN_PARTS/body-$section" >> "$output"
```

Store the parsed positive source task number in TASK_META's mapping column. The existing PLAN_PARTS/order file maps each source number to its section index; reject duplicates before rendering. Do not assume a Task N number equals its section index. Preserve prose before/after fenced blocks. Normalize accepted code fences to column-zero triple-backtick fences for upstream `task-brief`. If the payload cannot be represented without changing its content or confusing upstream's fence parser, reject it with an actionable error; never truncate it silently. Tests must include indented fences, tilde fences, embedded `Task 99` text and an unsupported nested/backtick payload that rejects.

- [ ] **Step 4: Implement the version transition in every native consumer.** A v1 active pointer produces a new v2 successor with the v1 file as predecessor only after validation succeeds. Validate v1 with its existing rendering/identity rules; validate v2 with the new complete rendering. Do not overwrite the v1 filename or reset its ledger. Extend orphan detection to both basename forms. Use only validated predecessor completion records to carry completed TNNNs; checkbox state alone is insufficient. A successor with no remaining tasks must still run a final review before any success receipt.
- [ ] **Step 5: Cover migration and failure atomicity.** Test unchanged v2 reuse, v1 → v2 after partial completion, all-completed v1 → v2 final-review-only, malformed legacy mappings, altered predecessor bytes, missing selection anchors and omitted pending tasks. Missing mappings require owner correction of current task artifacts; no guessing from task order. Failure preserves active-pointer bytes and creates no successor evidence. Existing body/ledger hash tampering must still reject.
- [ ] **Step 6: Update the native skill and synchronized docs.** State the full-body contract, accepted fence subset, v1 lineage/v2 execution policy and mapping failures. Use `superpowers:writing-skills`; do not edit vendored `task-brief` or implementer prompts.
- [ ] **Step 7: Run the adapter, handoff and full fast suites.** Prepare a coherent commit with the schema transition and Mandatory Sync 5 changes; proposed subject: `fix: preserve reviewed task content in versioned SDD projections`.


## Contract details shared by the two tasks

- Retain all CLI arguments and stdout paths. New basename: `<slug>-v2-p-<plan12>-t-<tasks12>-sdd.md`; historical v1 basename stays unchanged.
- Accept unique positive source task numbers without requiring them to equal section positions. Require one terminal mapping per canonical task and one canonical task per executable source heading, including already-checked tasks.
- Accept closed three-character backtick or tilde fence delimiters, optionally indented. Normalize delimiter indentation/type to column-zero triple backticks; preserve payload bytes. Reject longer or unclosed delimiters and payload lines that would toggle upstream triple-backtick state. Apply the same treatment to the preamble so its fence state cannot corrupt subsequent briefs.
- `--verify-only` must require an existing current v2 identity, reconstruct and compare it without creating directories, projections, workspaces, ledgers or pointers. If active evidence is v1, reject with an instruction to run ordinary projection for upgrade. Consumers must never trigger an upgrade while verifying evidence.
- Allow an empty successor only for a pure v1-to-v2 upgrade whose exact source plan/tasks hashes still match v1 and whose selection is fully completed by validated ledgers. Preserve rejection of all-completed structural source changes. The empty upgrade must still receive a fresh final review and receipt.
- Seed v1 compatibility fixtures with the baseline helper in an isolated fixture, captured as test support if needed, never by rewriting a live projection into v1. The baseline helper is test-only and may be replaced by a minimal deterministic fixture emitter with exact original bytes and anchors.
- Validate current v2 strictly and historical v1/v2 lineage explicitly. Preserve all tampering, orphan, missing-anchor, omitted-pending-task and ruling-line checks.

## Review preparation evidence

On 2026-09-05, the unchanged adapter returned exit 2 with `ERROR: output parent is missing` for a temporary project with no `.superpowers`. Creating only the SDD base made projection succeed; upstream task-brief then returned only a heading and canonical task line, without `src/three.txt` or the third task body. These are baseline reproductions, not corrected outcomes.
