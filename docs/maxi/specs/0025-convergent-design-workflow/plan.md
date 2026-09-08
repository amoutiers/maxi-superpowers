---
slug: 0025-convergent-design-workflow
spec_slug: 0025-convergent-design-workflow
created: 2026-09-08
updated: 2026-09-08
---

# Implementation Plan: Convergent Initial Specs and Revisions

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans for implementation. Use superpowers:writing-skills and its RED/GREEN/REFACTOR cycle for every native skill edit. This document plans the work; it does not authorize implementation.

**Goal:** Complete initial specifications and revisions without redundant questions or manual command relays, while bounding design review and preserving evidence validity.

**Architecture:** Existing native entry points coordinate a requested design goal and invoke artifact owners. One shared instruction brief describes sequencing; existing design-contract support manages bounded continuation inside the existing review report. No new skill, persistent ledger, runtime dependency, or approval format is introduced.

**Tech Stack:** Markdown skills, existing Bash 3.2-compatible approval helpers, shell tests, existing Codex integration infrastructure with Perl deadlines and jq.

**Spec:** [0025-convergent-design-workflow/spec](spec.md)

## Summary

Implement three deliverables: guarded report continuity, native owner coordination with synchronized documentation, and behavioral integration coverage. The first deliverable is inert until the native workflow uses it. The second activates the policy in one coherent change. The third proves that installed instructions follow it, rather than merely containing the expected wording.

## Technical Context

**Language/Version**: Markdown and Bash compatible with macOS Bash 3.2; jq and Perl only in the existing opt-in integration tier.
**Primary Dependencies**: Existing shell tools and installed Superpowers skills; no additional dependency.
**Storage**: Existing spec, plan, and reviews/design-review.md. Temporary candidates and a transient mutation lock are not persistent workflow records.
**Testing**: Existing test-helpers.sh and approval-cases.sh; new focused shell scenarios and one behavioral integration runner.
**Target Platform**: Existing supported harnesses; authenticated Codex provides the executable behavioral proof. Do not claim equivalent runtime proof for untested harnesses.
**Project Type**: Multi-harness instruction plugin with deterministic approval helpers.
**Performance Goals**: Zero redundant prompts or command relays in complete-brief cases; at most two reviewer dispatches per coordinated operation. Report actual elapsed time without promising a fixed speedup.
**Constraints**: Nineteen native skills, ten FSM states, three review boundaries, existing approval envelopes and exact decision digests.
**Scale/Scope**: Initial specify/clarify/plan and existing-spec revision through design review. Downstream implementation orchestration is unchanged.

## Global Constraints

- Preserve every pipeline phase responsibility, existing artifact ownership, the ten-state FSM, nineteen native skills, and three review boundaries.
- Delegate brainstorming, planning, and skill authoring to Superpowers; keep vendored skills byte-identical.
- Produce one canonical spec and respect the user's requested destination; design work does not authorize implementation or publication.
- Preserve exact artifact hashes, complete decision-input digests, atomic publication, installed verifier resolution, and fail-closed downstream gates.
- Permit at most two independent design-review dispatches per coordinated operation; unresolved defects remain blocking and interruption cannot reset the allowance.
- Preserve parked/cancelled guards, reopened_from: done, completion lineage, and stale downstream artifacts.
- ADR changes require the existing separate explicit approval; do not infer it from workflow continuation.
- Add no native skill, command, FSM status, separate ledger, runtime dependency, or orchestration service.
- All repository artifacts and instructions are English; synchronize the five mandatory pipeline documents when activating changed gating.
- Complete the fast suite and behavioral integration checks before claiming the new workflow works; static instruction checks alone are insufficient.

## Constitution Check

| Principle | Pass / Fail | Notes |
| --- | --- | --- |
| I. Mandatory Spec-Driven Pipeline | Pass | Owners still perform specify, clarify, plan, tasks, analyze, and implement at their proper boundaries. |
| II. Delegate, Never Duplicate | Pass | Native context adapts delegated Superpowers output and stop points; its engine and vendored files remain unchanged. |
| III. Strict Pipeline | Pass | Automated handoffs do not omit phase checks or manufacture statuses. |
| IV. ADR Capture | Pass | Accepted ADR-0029 authorizes the changed coordination and continuation rules. |
| V. Artifacts Over Chat | Pass | Canonical artifacts and report continuity persist the relevant state. |
| VI. Single Responsibility | Pass | Shared sequencing brief and spec-author brief separate coordination from document ownership; design-contract remains the report/evidence writer. |

## Project Structure

### Documentation (this feature)

```text
docs/maxi/specs/0025-convergent-design-workflow/
  spec.md
  plan.md
  reviews/design-review.md
```

### Source Code (repository root)

```text
skills/
  specify/SKILL.md
  specify/spec-author.md                 # New support brief; no new skill
  clarify/SKILL.md
  revise/SKILL.md
  plan/SKILL.md
  review/SKILL.md
  review/design-operation.md             # New shared sequencing brief
  review/design-reviewer.md
  review/review-template.md
  review/design-contract.sh
  using-maxi/SKILL.md
tests/
  check-design-operation.sh               # New executable report scenarios
  check-review-boundaries.sh
  check-revise.sh
  check-skills-present.sh
  check-skill-count.sh
  check-integration-harness.sh
  run-all.sh
  integration/run-codex-design-test.sh    # New behavioral runner
  integration/assert-design-events.jq    # New independent transcript assertions
  integration/design-cases/              # Small fixture requests/source files
  integration/run-all.sh
```

Also update the five mandatory pipeline documents and README.md, including its testing guidance. File lists identify primary changes; mechanical fixture and caller updates belong to the owning deliverable.

**Structure Decision**: Reuse the loaded review skill as the location for shared orchestration support. Native specify and revise load its design-operation.md without invoking public review just to discover support. Keep all evidence writes in design-contract.sh and its existing guard functions. Spec-author.md handles creation/editing; it never dispatches the broader pipeline.

## Decisions

| ADR | Title | Status |
| --- | --- | --- |
| [0029-convergent-design-workflow](../../adr/0029-convergent-design-workflow.md) | Convergent Initial Specs and Revisions | Accepted |
| [0023-dedicated-design-review-contract](../../adr/0023-dedicated-design-review-contract.md) | Dedicated reviewer and blocking predicate; continuation clause refined by ADR-0029 | Accepted |
| [0028-decision-input-freshness](../../adr/0028-decision-input-freshness.md) | Exact decision-input freshness | Accepted |

## Complexity Tracking

No constitution exception. A transient directory lock is needed only around report mutations: compare-then-rename alone cannot prevent two shell writers from consuming the same review slot. No scheduler, database, event service, or general workflow framework is justified.

## Design Contract

### Ownership and destination

| Entry | Coordinates | Allowed destination |
| --- | --- | --- |
| specify, bare or spec-only | spec-author then clarify | clarified |
| specify, explicit design validation | spec-author, clarify, plan, review round | planned plus current verdict |
| revise with explicit change | own rollback/note, spec-author or clarify where needed, plan, review round | planned plus current verdict |
| explicit draft-only/edit-only/phase-only | requested owner only | explicit narrower stop |
| public review | one report-only review invocation | report only, no correction |
| standalone initial plan | existing planning owner and initial review | planned plus verdict; no correction unless design coordination was authorized |

A coordinator passes a context containing the actual user request, target, destination, previously settled product decisions, and owner-only return instruction. This is conversation context, never new spec frontmatter or Global Constraints content. Owners return after their own write; they cannot recursively invoke the coordinator. Plan's old automatic initial-review hook is suppressed only when an enclosing coordinator will perform that same boundary once. Standalone behavior retains its one initial review.

Revise's rollback belongs to revise. A requirements change goes through the existing-spec author mode with status clarified as its input, then real clarification if needed; a demonstrated source ambiguity uses specified then clarify; plan-only correction keeps planned. The author mode writes requirements and clears only a genuinely resolved marker, not tasks or analysis. New semantic gaps are explicit questions, not automatic guesses. Revise retains its revision note and monotone reopened_from watermark.

The coordinated unit is identified by the actual initiating user message, not by an agent-written claim of permission. Resuming the same request never means starting a fresh operation. Before planning there is no consumed review allowance; after the first reservation the report is mandatory continuation evidence. If the conversation cannot establish destination or a fresh request, stop for that specific missing information.

### Report continuation and dispatch allowance

Add narrowly scoped modes to existing design-contract.sh; keep legacy stamp/verify signatures and maxi-design-review-v1 unchanged. Every mutation uses the same canonical report path, existing symlink/alias guards, a private sibling candidate, and an exclusive transient sibling lock directory. A lock collision or a lock left by a killed process fails closed; never remove another writer's lock automatically. Clean up only a lock this invocation successfully created. Read-only modes create nothing.

A managed report body starts with one reserved block immediately after its `# Design Review` heading:

```text
<!-- maxi-design-operation-v1
operation_id: <sha256 of user-message identity and request bytes>
request_sha256: <sha256 of exact initiating request bytes>
mode: coordinated
phase: reserved
passes: 1
reviewer: <single-line harness identity or unavailable>
spec_sha256: <original exact spec hash>
plan_sha256: <original exact plan hash>
inputs_sha256: <original decision digest>
-->
```

The format is fixed, not arbitrary YAML. Validate exact keys, uniqueness, ordering, hashes, allowed enum values, and passes. Reject newline/control characters in reviewer identity. Mode is coordinated (limit two) or report-only (limit one). Phases are reserved, rejected, approved, and stopped; these are report-local values, not new spec FSM statuses. Reject duplicate/reserved markers in reviewer output before composing the report. Do not search raw quoted historical text for current metadata.

The first reservation replaces any prior report with an **unstamped pending report**, containing its new operation block and the complete previous report in a clearly delimited historical section. Pending reports fail the unchanged approval-envelope check. During successful publication, retain prior findings needed for the correction round in the report body; never relabel them as a current verdict. This is continuity in the already-owned report, not an additional ledger file.

Internal command interfaces (all paths absolute at runtime):

```text
design-contract.sh reserve REVIEW SPEC PLAN ROOT OPERATION_ID REQUEST_SHA MODE REVIEWER EXPECTED_REPORT_SHA
design-contract.sh operation REVIEW SPEC PLAN ROOT OPERATION_ID
design-contract.sh stamp-operation CANDIDATE REVIEW SPEC PLAN VERDICT ROOT ORIGINAL_INPUTS OPERATION_ID EXPECTED_REPORT_SHA
design-contract.sh stop-operation REVIEW SPEC PLAN ROOT OPERATION_ID EXPECTED_REPORT_SHA
```

EXPECTED_REPORT_SHA is the exact hash of the current report, or literal absent only for a missing report on a fresh operation. The owner verifies fresh-request authorization before first reserve. The helper checks report identity and transition, not human intent; it cannot authenticate a user from a shell argument. An existing active operation cannot be replaced by reserve. After a terminal operation, a new identity requires an explicit new user request and, following failure, a stated changed strategy. Never synthesize that request to obtain new slots.

Transitions:

- First reserve for a fresh operation records passes=1 and original spec/plan/input hashes **before dispatch**, with phase=reserved. The success response includes operation ID, pass, and the new report hash; only this success permits one dispatch.
- A matching operation in phase=rejected with passes=1 and mode=coordinated may reserve pass two after the owner has corrected the design. Replace stored artifact hashes with the corrected snapshot, retain the same operation/request identity and previous findings. A changed decision snapshot is supplied completely to the reviewer; it does not reset the count.
- A matching reserved operation can accept its still-running reviewer's eventual valid result. Resume may wait/read that reviewer, but must never redispatch the reserved pass. If the result or reviewer cannot be recovered, stop the operation. A missing or malformed report stops without rebuilding it from history.
- stamp-operation requires phase=reserved, the same ID and pass, unchanged reservation report hash, unchanged original artifact hashes and digest, and a candidate containing the exact operation block with only phase changed to the supplied verdict. Validate the exact terminal reviewer verdict separately, then use existing stamping mechanics under the same lock. Approved evidence must additionally pass verify.
- A rejected second pass, malformed output, unavailable unrecoverable reviewer, or freshness failure ends automatic continuation. stop-operation marks the diagnostic state stopped without adding an approval envelope; it preserves existing findings and consumed passes. If inputs themselves are unsafe/unreadable, leave the report unchanged and report the stop instead of forcing a write.
- Legacy stamp refuses a destination containing managed operation state, so it cannot erase the guard. verify validates the operation block when present and permits only matching approved state with passes in range; legacy stamped approvals without the block retain existing verification semantics. Operation resume always requires the managed block, even if legacy approval verification would otherwise succeed.

All mutations compare EXPECTED_REPORT_SHA while holding the report lock and again immediately before rename. Failed publication preserves the last report byte-for-byte. The guard is coordination under trusted owner instructions, not tamper-proof authorization against an actor able to rewrite arbitrary workspace files.

### Missing inputs, scope replacement, and historical reports

The first reserve requires a real spec/plan pair; the owner creates the real reviews directory only at that boundary. A user explicitly replacing the current operation with a different request may stop the old report operation before beginning the new one; a coordinator cannot invent that request. A direct review request does not resume an old coordinated correction allowance: it is a new report-only request after the old operation is explicitly stopped or terminal. A report-only invocation consumes one slot and stops after its verdict.

Historical report sections are payload, never parsed as active state. Use exact byte-length framing for preserved previous bytes so old operation markers cannot be confused with the single leading current block; validate the byte count before parsing trailing content. A rejected first-pass report retains its findings when reserving pass two. This framing belongs in the existing helper and is exercised with a previous managed report as well as legacy evidence.

### Reviewer continuity

Allocate a fresh independent reviewer for pass one. Save its returned identity in the reservation before sending the review payload; an identity handshake must not perform a design review and does not consume another pass. Reuse that reviewer for pass two where supported. If unavailable after a completed first rejection, allocate a fresh reviewer for the still-unused second pass and provide the complete current snapshot plus previous findings. Do not replace a reviewer whose reserved pass may already have run.

The review brief retains its existing blocking predicate. Add a correction-round section requiring each prior finding to be marked resolved or still blocking, with current evidence, and requiring inspection of interactions changed by the correction. New demonstrated blockers remain valid. No broad second audit is requested merely to find additional work.

## Implementation Tasks

### Task 1: Guard Review Reservations and Publication in the Existing Report

**Files:** Modify skills/review/design-contract.sh; create tests/check-design-operation.sh. Reuse skills/review/approval-guard.sh and tests/lib/test-helpers.sh; do not duplicate their path or assertion helpers.

**Interfaces:** Implements the four internal modes defined above. Existing public stamp/verify arguments remain compatible for unmanaged historical evidence. This task is inert until Task 2 invokes managed modes.

- [ ] **Step 1: Add executable negative and lifecycle cases.** Use mktemp project fixtures with real spec/plan/constitution and the existing digest helper. Add shell assertions for fresh reserve, rejected pass one, corrected pass two, and approved verification. Include executable assertions of these outcomes:

```bash
# After reserve, pending evidence must not verify.
if bash "$contract" verify "$report" "$spec" "$plan" "$fixture"; then exit 1; fi
# After a second reserve, another reserve must preserve the pending bytes.
before=$(shasum -a 256 < "$report")
if bash "$contract" reserve "$report" "$spec" "$plan" "$fixture" "$op" "$request" coordinated unavailable "$report_sha"; then exit 1; fi
[ "$before" = "$(shasum -a 256 < "$report")" ]
```

The test initializes fixture/contract/op/request/report_sha variables from actual files and command outputs. Also cover lost results, operation mismatch, duplicate/invalid metadata, missing continuity, stale expected report hash, edited spec/plan/ADR, legacy-stamp bypass, path aliases, and competing mutation lock acquisition. Verify interrupted reservation does not dispatch again using a counted reviewer stub outside production code.

- [ ] **Step 2: Run RED.** `bash tests/check-design-operation.sh` must fail because reserve is not implemented. Confirm failures concern the missing behavior rather than fixture setup.
- [ ] **Step 3: Implement the modes in design-contract.sh.** Add fixed-format block parsing and transition validation. Extract existing stamp publication into an internal routine so stamp-operation reuses it without reacquiring its own lock. Wrap both legacy and managed writes in the shared transient lock; read-only verify/operation stay free of writes. Keep envelope fields unchanged and add managed-body validation without weakening legacy exact_fields.

```bash
case "$phase:$passes:$mode" in
  rejected:1:coordinated) next_pass=2 ;;
  *) die 'no unused review pass is available' ;;
esac
# After all checks, write the complete pending candidate then atomically rename.
# The owner dispatches only after receiving this successful reservation.
```

Implement the separate fresh-operation branch, exact original-hash comparisons, and candidate preservation described in Design Contract; the snippet above is only the repeat-pass branch.

- [ ] **Step 4: Verify the deliverable.** Run `bash tests/check-design-operation.sh`, `bash tests/check-review-boundaries.sh`, and `bash tests/check-readiness-contract.sh`. All must pass; unchanged legacy approval scenarios remain green. Defer activation and final commit until the synchronized owner changes in Task 2.

### Task 2: Coordinate Initial Specs and Revisions Through Existing Owners

**Files:** Modify skills/specify/SKILL.md, skills/clarify/SKILL.md, skills/revise/SKILL.md, skills/plan/SKILL.md, skills/review/SKILL.md, skills/review/design-reviewer.md, skills/review/review-template.md; create skills/specify/spec-author.md and skills/review/design-operation.md. Modify tests/check-review-boundaries.sh, tests/check-revise.sh, tests/check-skills-present.sh, tests/check-skill-count.sh, tests/run-all.sh. Synchronize docs/pipeline-flow.md, docs/delegation-map.md, skills/using-maxi/SKILL.md, AGENTS.md, docs/architecture.md, and README.md.

**Interfaces:** Native callers load review support by registered skill name, canonicalize the exact loaded directory, require regular non-symlink support files, and never fall back to client-project skills. Coordinators pass target/request/destination/settled choices and owner-only context; review alone writes the report through Task 1's helper modes.

- [ ] **Step 1: Invoke writing-skills and establish RED scenarios.** Use its pressure-test process for a complete approved initial brief, three independent unresolved choices, a clear revision after rejection, and an explicit review-only request. Capture actual repeated questions, duplicated artifacts, command relays, and owner writes before editing instructions. Record findings in ignored execution scratch, not another product artifact. Do not request another user approval of this already approved design.
- [ ] **Step 2: Replace conflicting contracts, not just add exceptions.** Remove the unconditional repeat-description/A+ confirmation requirement, terminal-correction commands, and fresh-reviewer-per-retry mandates where ADR-0029 replaces them. Keep narrower scope and real missing-authorization stops. Update test expectations that currently enforce these obsolete clauses; retain watermark, paths, hashes, terminal-verdict, and single-owner tests. Add the new deterministic suite to run-all.sh.
- [ ] **Step 3: Author the native support and owner flows.** The shared design-operation.md specifies the destination table, owner-only returns, complete-flow self-check, and two-pass protocol. The spec-author brief owns template-based creation and explicit existing-spec edits without starting another interview or pipeline. Specify remains the initial entry coordinator; revise remains the revision entry coordinator and owns its rollback/note.

The native instructions must contain this concrete branch policy, adapted into their existing prose:

```text
If the user requests only a draft or an edit, invoke only the owner needed and stop.
For spec-only creation: reuse approved design -> author -> actual clarify scan -> return clarified.
For design-validation creation: author -> clarify -> owner-only plan -> bounded review round.
For revision: reuse the change -> authorized rollback/note -> affected author/clarify -> owner-only plan -> bounded review round.
A rejected first pass returns all findings to the owners once; a rejected second pass stops.
Never invoke tasks, analyze, or implement as a consequence of completing this operation.
```

For delegated brainstorming, explicitly supply the canonical Maxi path, already settled answers/approval, grouped-question policy, and return-to-owner boundary. Suppress only duplicate output and repeated approval of unchanged content, not consideration of real product choices. For clarification, replace unconditional one-question-per-turn with up to three independent questions and zero questions when the real scan is clean. For planning, add complete producer/mutation/persistence/reload/consumer analysis and suppress nested initial-review dispatch only under the outer coordinator. Review remains a report-only owner in both direct and coordinated calls.

- [ ] **Step 4: Synchronize diagrams and gating tables in this same change.** All five documents must distinguish owner phase completion from coordinated destination, show preserved FSM and three gates, show direct review-only semantics, and document bounded correction with continuity. Update standalone initial-plan behavior consistently. Preserve the existing durable Global Constraints sentence; transient operation state belongs only in review context/report, never plan constraints.
- [ ] **Step 5: Run GREEN/REFACTOR and static gates.** Repeat the pressure scenarios from Step 1 against the changed installed skill snapshot, retain transcript evidence, then run `bash tests/run-all.sh` and the local doc-consistency skill. Include installed-path failure tests for each new support file. Keep Task 1, Task 2, and mandatory doc synchronization together in the activation commit; no partial commit of contradictory gating rules.

### Task 3: Prove Initial and Revision Behavior Through the Installed Plugin

**Files:** Create tests/integration/run-codex-design-test.sh, tests/integration/assert-design-events.jq, and minimal tests/integration/design-cases fixtures; modify tests/integration/run-all.sh, tests/check-integration-harness.sh, README.md, and AGENTS.md's integration description.

**Interfaces:** New runner accepts `initial`, `revision`, `boundaries`, or `all` as its single optional case selector (default all). Output goes to the existing ignored .superpowers/sdd/integration tree. Reuse the existing local marketplace staging, byte-checked installed snapshot, authenticated Codex invocation, and Perl deadline supervisor demonstrated by run-codex-readiness-test.sh. Do not refactor the existing harness into a new framework.

- [ ] **Step 1: Add deterministic checker tests.** Feed assert-design-events.jq synthetic recorded transcripts representing extra user questions, duplicate design files, a third review reservation/dispatch, an unauthorized successor, absent owner evidence, and false success claims. Each must fail. A passing synthetic transcript must include completed owner/tool evidence and match fixture outputs, not only final assistant text. Add these checker self-tests to check-integration-harness.sh without requiring authentication.
- [ ] **Step 2: Implement isolated behavioral cases.** Materially stage all changed skills and support files and compare their installed bytes. Use a clean source checkout requirement, fixture Git HEAD snapshots, no commits in fixture prompts, and existing timeout normalization. Before execution, seed fixture-only user scripts and technical source paths so the runner can verify actual artifact writes. Never modify the user's live NavRouteEdge task.

Cases:

1. Approved complete initial brief, spec-only: clarified canonical spec, no plan/review/duplicate design file, no redundant question.
2. Initial design-validation brief: real owner phases and at most two review dispatches, current approval or truthful bounded rejection, no implementation.
3. Three independent choices and one dependent follow-up: replay fixed user answers through successive Codex turns in the same isolated session; verify answers are not requested again during clarification. Start this case without --ephemeral; capture the session identifier emitted by the installed CLI and resume from the same fixture cwd and isolated CODEX_HOME with `codex exec resume --json "$session_id" "$answer"`. The argument interface was verified with `codex exec resume --help` during planning. Fail if a unique session identifier cannot be extracted; never use --last across cases.
4. Clear revision: seed a rejected provenance plan with compatible inversion/reload/ownership defects and real minimal source files. Verify actual requirement/plan correction and the consolidated mapping, not just the report's claimed outcome.
5. Review-only/edit-only, parked/cancelled, reopened-done, missing continuity: verify exact permitted writes and no unexpected phase calls.

Inject second rejection, stale input, malformed result, and reviewer loss in the deterministic Task 1 harness where outcomes can be controlled honestly. Label those as deterministic fault tests, not live-agent proof. For live review counts, extract actual structured tool events; unknown or unexposed dispatch schemas yield incomplete evidence, never an assumed zero. Do not use a stubbed reviewer to claim end-to-end independent review worked.

- [ ] **Step 3: Validate the installed workflow.** Run the new runner's initial, revision, and boundaries groups, then `bash tests/run-all.sh --integration` from a clean isolated implementation checkout. Commands must fail on missing authentication, invalid installed bytes, unknown event shapes, missed deadlines, or unverified reports. Inspect the real transcript for product-question quality; counts alone do not prove necessity.
- [ ] **Step 4: Report measured outcomes.** Compare the baseline pressure-run artifacts from Task 2 with the same cases after implementation. Report user-turn, duplicate-document, review-dispatch, elapsed-time, and unresolved-blocker counts. Run the final fast suite after any resulting change. Do not call the feature fixed when only static tests passed or a live case timed out.

## Self-Review

| Requirements | Planned coverage |
| --- | --- |
| FR-001 through FR-008 | Task 2 destination/owner flows and delegated adaptation; Task 3 initial/revision scenarios |
| FR-009, FR-011, FR-012 | Task 2 full-flow self-check and correction brief; Task 3 provenance fixture |
| FR-010, FR-013, FR-014 | Task 1 executable reservation/publication invariants; Task 3 fault and live evidence separation |
| FR-015 through FR-018 | Task 2 narrow scopes, lifecycle preservation, three gates, and atomic doc synchronization |
| FR-019, SC-001 through SC-006 | Task 3 transcript and fixture assertions plus recorded baseline comparison |

Source checks completed during planning: legacy design-contract has exact five-field envelopes but no operation tracking; approval-guard provides canonical path/alias checks; revise and review-boundary tests explicitly enforce the obsolete terminal behavior; the readiness integration runner proves installed snapshots and artifacts, while generic trigger prompts only prove skill loading. These are the actual owners and verification paths to change.

ADR scan: report-local continuity, native coordination, and delegation adaptation implement accepted ADR-0029. The transient write lock and exact command modes are routine implementation details, not a new architectural decision. No new ADR is proposed.
