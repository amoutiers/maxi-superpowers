---
spec_slug: 0026-git-closure
created: 2026-09-26
updated: 2026-09-26
---

# Implementation Plan: Explicit Git Closure

> **For agentic workers:** REQUIRED SUB-SKILL: Use the Maxi implement and x-develop owners with upstream subagent-driven-development. Steps use checkbox syntax. The outer design coordinator owns the bounded design review; this owner returns after writing.

**Goal:** Make every concluded local batch report an explicit Git disposition through the installed plugin.

**Architecture:** Add a concise session contract to using-maxi and a required report slot to implement. Preserve the existing handoff to the unmodified Superpowers finishing skill, with no additional phase, review, integration engine or persistent delivery ledger.

**Tech Stack:** Markdown skills, Bash, Git, jq, Python standard library and the existing authenticated Codex integration harness.

**Spec:** [0026-git-closure/spec](spec.md).

## Summary

The missing behavior is a closure decision and its reported outcome. The native session contract identifies its owner and trigger. Implement remains the normal pipeline finishing owner after all current gates and its persisted done transition. Explicit maintenance authorization is a separate scope supplied by the user, never an inferred escape from a partial spec. Behavioral fixtures exercise both paths and inspect actual Git state.

## Technical Context

**Language/Version:** Existing Bash 3.2-compatible shell, Python 3 and Markdown.  
**Primary Dependencies:** Existing Git, jq and authenticated Codex CLI.  
**Storage:** Existing task tracking, canonical Maxi artifacts and ignored integration evidence.  
**Testing:** Fast shell contracts, installed-plugin scenarios and independent Git assertions.  
**Target Platform:** Existing supported harnesses; behavioral acceptance uses macOS Codex CLI.  
**Project Type:** Multi-harness skill plugin.  
**Performance Goals:** No runtime service or polling; bounded CLI runs using the existing deadline supervisor.  
**Constraints:** Preserve gates, ownership, native skill count and vendored bytes.  
**Scale/Scope:** Two native skill changes plus the required documentation and one focused integration suite.

## Global Constraints

- Customer and personal AGENTS.md files remain user-owned and unchanged; plugin loading is the only session precondition.
- User instructions and applicable operation authorization remain authoritative. A decision request grants no merge, push, publication or cross-chat messaging authority.
- The normal Maxi path retains all current gates, x-develop checkbox and final-review ownership, and implement's sole done write before finishing. A partial spec cannot be closed by reclassifying it as maintenance.
- Delegate branch actions and worktree lifecycle to the existing Superpowers finishing skill and native tools. Do not hand-edit vendored skills or duplicate their implementation.
- Retain 19 native skills, ten statuses and existing tracking. Add no delivery ledger, policy file, service or hook.
- Preserve concurrent work, in-use worktrees and useful ignored evidence. Report failed combined verification without claiming successful integration.
- Keep baseline observations distinct from candidate results. Missing evidence, unknown event schemas and timeouts are failures, not passing behavior.
- All new project content is English without em dashes. Fast-tier tests must pass before commits; pipeline documentation changes accompany the owning skill change atomically.

## Constitution Check

| Principle | Pass / Fail | Notes |
|---|---|---|
| I Mandatory pipeline | Pass | Canonical spec, clarification, plan, independent design review, tasks, analysis and implementation owners. |
| II Delegate | Pass | Existing upstream finishing skill remains the only integration implementation. |
| III No skipping | Pass | Maintenance requires explicit user scope; incomplete Maxi work remains blocked. |
| IV ADR capture | Pass | Existing decisions cover this reporting and invocation repair; no new gate, status or Maxi/Superpowers relationship. |
| V Artifacts | Pass | Design, readiness and execution evidence use existing artifact locations. |
| VI Single responsibility | Pass | Session guidance, implementation result and integration tests stay with their current owners. |

## Project Structure

### Documentation (this feature)

The canonical [0026-git-closure/spec](spec.md), [0026-git-closure/plan](plan.md), subsequent tasks and analysis, and design review remain together in this feature directory. No duplicate proposal or delivery-state document is created.

### Source Code (repository root)

- [using-maxi](../../../../skills/using-maxi/SKILL.md): closure trigger and owner in the loaded session contract.
- [implement](../../../../skills/implement/SKILL.md): required Git outcome at the existing finishing return.
- [check-implement-handoff.sh](../../../../tests/check-implement-handoff.sh): preserve gates and assert the required reporting contract.
- `tests/integration/run-codex-git-closure-test.sh`: isolated installation and real scenario execution.
- `tests/integration/git-closure-cases/`: focused case data and evidence assertions using existing tooling.
- [integration/run-all.sh](../../../../tests/integration/run-all.sh): opt-in suite registration.
- [pipeline-flow](../../../pipeline-flow.md), [delegation-map](../../../delegation-map.md), [architecture](../../../architecture.md), [AGENTS.md](../../../../AGENTS.md) and using-maxi: Mandatory Sync 5.

**Structure Decision:** Reuse the existing integration runner pattern and deadline supervisor. Share only a helper already suitable for this task; no generic harness refactor is required.

## Decisions

| ADR | Title | Status |
|---|---|---|
| [0005-superpowers-vendoring-git-subtree](../../adr/0005-superpowers-vendoring-git-subtree.md) | Preserve vendored upstream implementation | accepted |
| [0008-session-start-injection-gated-on-docs-maxi](../../adr/0008-session-start-injection-gated-on-docs-maxi.md) | Reuse existing session loading | accepted |
| [0021-align-superpowers-v6-3-model](../../adr/0021-align-superpowers-v6-3-model.md) | Preserve implement/SDD/finishing ownership | accepted |
| [0029-convergent-design-workflow](../../adr/0029-convergent-design-workflow.md) | Reuse canonical design coordination | accepted |

No new architectural choice is needed. If actual behavior requires changing a gate or upstream ownership, return to the design owner and ADR workflow instead of expanding this patch.

## Complexity Tracking

No constitutional exceptions.

## Data and Control Flow

1. Existing bootstrap loads using-maxi. The session identifies exact scope, current evidence and the already designated owner from the user request and existing tracking.
2. At local completion or external waiting, that owner evaluates closure. In the normal pipeline this points to implement; it never starts a second finishing call inside x-develop.
3. Existing readiness verification precedes implementation. X-develop projects, executes, reviews and verifies its receipt. Implement consumes READY_TO_FINISH, verifies all checkboxes and persists done before its existing finishing invocation.
4. Upstream finishing reads actual Git/worktree state, required verification and applicable authorization. Its result feeds the required native report slot: integrated, awaiting decision, deliberately retained, or blocked, with scope, evidence and next action.
5. A keep decision and its resume condition use the workflow's existing tracking. Resume rereads that decision and current evidence; unchanged deferral does not ask the same question again.
6. The integration runner snapshots installed bytes and Git refs before the agent, then reads CLI/session evidence and Git state afterward. Agent claims never substitute for ref, ancestry, status or evidence-file assertions.

## Review Focus and Test Matrix

| Focus | Fixture variants | Independent oracle |
|---|---|---|
| C1 Autonomous closure | Ready maintenance without client AGENTS; normal Maxi completion after valid gates | Explicit outcome/decision; no target-ref change without authorization; installed-skill read |
| C2 Authority | Local prohibition; exact merge authorization; authorization for another batch | Policy bytes unchanged; exact expected ref/ancestry effects; no push; no redundant permission question |
| C3 Waiting versus blocking | Independent operational wait; missing review; failing tests; incomplete tasks; invalid receipt or readiness | Wait keeps local outcome; blockers preserve target refs and non-done state |
| C4 Ownership and resume | Explicit coordinator; keep plus unchanged resume | One designated decision owner; no repeat decision or unauthorized message |
| C5 Work preservation | Detached; shared/in-use; ignored unique evidence; combined-result test failure | Real checkout capability, preserved worktree and evidence bytes, truthful failing result, no push |

### Task 1: Add a focused installed Git-closure behavior runner

**Files:** Create `tests/integration/run-codex-git-closure-test.sh` and `tests/integration/git-closure-cases/`; modify [integration/run-all.sh](../../../../tests/integration/run-all.sh) and the existing fast harness checks only where registration needs coverage.

**Interfaces:** Consumes the current checkout's plugin snapshot, Codex authentication and existing `run-with-deadline.pl`. Produces an executable no-argument suite returning zero only when every scenario has complete passing evidence, plus preserved per-case logs and Git snapshots under the existing ignored integration directory.

- [ ] Read the complete existing design and trigger runners and their evidence checkers. Reuse external temporary fixtures and isolated runtime homes so personal or ancestor instructions cannot influence cases. Keep fixtures without remotes and avoid exposing authentication bytes.
- [ ] Add scenario data for every matrix variant. Prompts describe the ordinary finishing or waiting task and existing facts; they do not request a merge menu or prescribe the new output slot. Maintenance fixtures explicitly authorize the bounded outside-pipeline scope. Positive Maxi fixtures must carry verifiable terminal evidence, with synthetic fixture evidence labeled as such rather than described as a live upstream review.
- [ ] Add minimal checker regression cases that reject a claimed merge without corresponding refs, a changed protected file, a timeout, missing byte-checked skill-read output, and unknown event shape. Before implementing those assertions, run them and record their expected failures. A valid captured evidence sample must pass as the positive control.

```python
# Oracle examples for the actual fixture state, not agent self-report.
assert target_after == target_before  # no applicable merge authorization
assert policy_after == policy_before
assert evidence_after == evidence_before
assert exit_code == 0 and turn_completed
# Authorized successful integration additionally requires:
assert git_merge_base_is_ancestor(batch_tip, target_after)
```

- [ ] Implement the smallest runner around the existing installation and deadline pattern. Byte-compare staged and installed skills, preserve their snapshot, and require a completed tool-result read of the exact installed using-maxi/implement paths appropriate to the case. Measure refs, ancestry, status, worktree membership and protected file bytes directly. Parse known completed CLI events, fail unknown or incomplete execution evidence, and collect all case failures without counting them as success.
- [ ] Register the runner in the opt-in integration suite. Run checker regressions and the full fast tier, then run the behavior suite against the unchanged skills and retain baseline observations. Do not manufacture a failure when a baseline case already passes.
- [ ] Record runnable commands and exact outcomes in the existing SDD task evidence. Commit this independently reviewable harness only after the fast tier passes. Behavioral baseline failures are expected observations, not a passing candidate acceptance claim.

### Task 2: Require the plugin's explicit Git outcome and validate it

**Files:** Modify [using-maxi](../../../../skills/using-maxi/SKILL.md), [implement](../../../../skills/implement/SKILL.md), [check-implement-handoff.sh](../../../../tests/check-implement-handoff.sh), and Mandatory Sync 5 [pipeline-flow](../../../pipeline-flow.md), [delegation-map](../../../delegation-map.md), [architecture](../../../architecture.md), [AGENTS.md](../../../../AGENTS.md). Adjust Task 1 case expectations only for demonstrated oracle defects, preserving the specified acceptance behavior.

**Interfaces:** Consumes Task 1's no-argument runner and baseline evidence. Produces native session guidance and a required implementation report slot; existing READY_TO_FINISH, task projection, receipt schema and finishing API remain unchanged.

- [ ] Apply superpowers:writing-skills. Classify the observed omission and compare candidate wording against the unchanged full skill in fresh-context micro-tests, at least five samples per variant. Read every flagged output. If the control has no omission, investigate the historical failing scenario before writing guidance instead of inventing new policy.
- [ ] Add a failing native contract check proving that the report requires a Git outcome and the session delegates to the existing finishing owner. Preserve existing assertions for receipt, done order, one checkbox owner, one final review and retained evidence. Run `bash tests/check-implement-handoff.sh` and record the expected missing-contract failure.
- [ ] Add a concise session section covering exact-scope evaluation, one owner, independent waiting, applicable authorization and unchanged deferral. Use a required output slot in implement rather than duplicating the Git procedure. The intended report shape is:

```text
Git outcome: integrated | awaiting decision | deliberately retained | blocked
Scope: exact branch/worktree and local batch
Evidence/next action: verified result, pending decision, keep condition, or blocker
```

- [ ] Preserve the existing post-done finishing call. Refer to the session contract from the implementation report and retain projection lineage and rulings. Respect customer instructions and existing applicable permission without introducing an automatic merge default or a second decision owner.
- [ ] Synchronize all five pipeline documents in the same commit. Document that outcomes are reporting dispositions, not statuses, and that the mechanism belongs to the loaded plugin. Keep customer instructions, vendored skills, x-develop and existing artifact schemas unchanged.
- [ ] Run `bash tests/check-implement-handoff.sh`, `bash tests/check-sync-invariant.sh`, `bash tests/run-all.sh`, and `bash tests/integration/run-codex-git-closure-test.sh`. Inspect each behavioral failure before changing guidance or its oracle. Preserve both the baseline and candidate evidence and state any acceptance limit explicitly.
- [ ] Apply maxi:doc-consistency and finish the upstream-owned task and final reviews. Commit the coherent verified change with Mandatory Sync 5. Return through x-develop's validated receipt and implement's done transition before delegating branch finishing and reporting the actual Git outcome.
