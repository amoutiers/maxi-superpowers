# Convergent initial specs and revisions

Status: proposal for user review; not an approved Maxi spec or implementation plan.

## Outcome

A clear request to prepare a feature through design validation, or to revise an existing spec, should produce a coherent spec/plan pair and a current design verdict without requiring the user to relay commands between owners. A request for a spec alone ends with a clarified spec; a request to review only remains read-only apart from its report. This proposal does not authorize implementation or modify the existing workflow.

## Evidence and diagnosis

The NavRouteEdge task “Auditer les performances” repeatedly corrected the route-point name-provenance design, moving from a response-model extension to parallel editor state, then a draft wrapper, then persisted provenance. The September 8 review took approximately 23 minutes; the subsequent plan correction took approximately 12 minutes before another review began. These are observations, not performance targets.

Two causes require separate fixes:

- Corrections address individual findings without checking their combined effect on the complete data lifecycle. Each local solution exposes another omission.
- The current revision contract makes the user coordinate owners manually. `revise` changes status and a note, `plan` stops after its correction, and `review` requires another explicit invocation. Each fresh review reloads the full decision snapshot.

[ADR-0022](maxi/adr/0022-fixed-review-boundaries.md) deliberately removed automatic replay. Restoring unbounded replay would repeat the earlier failure. The existing reviewer already requires complete findings and excludes mechanical file-list closure from blockers; strengthen application and behavioral tests rather than duplicate those rules.

Initial creation has related friction: `specify` requires the complete brainstorming dialogue before writing requirements, then `clarify` conducts another ambiguity scan with one question per turn. The scan is useful, but it must reuse prior answers. The current `specify` handoff also suggests proceeding directly to `plan` from `specified`, although `plan` requires `clarified`. Correct that contradictory guidance rather than teaching users another workaround.

## Recommended behavior

### 0. Apply the same convergence rules to initial creation

Use existing native entry points, with `using-maxi` explaining goal routing and `specify` coordinating the explicitly requested initial design scope through the existing owners. Do not add a command, skill, FSM status, or duplicate planning engine.

- **Respect the requested destination.** “Write a spec” or a bare `/maxi:specify` produces a clarified spec, including the actual clarification scan. “Prepare this feature through design validation” additionally runs planning and the bounded design-review round. An explicit draft-only or phase-only request stops earlier. None authorizes implementation.
- **Read before interviewing.** Reuse the supplied brief, prior answers, existing patterns, constitution, and applicable decisions. Gather unresolved product questions before asking; do not make the user restate facts already supplied.
- **Scale the dialogue to uncertainty.** For a well-defined feature, propose the concise design and assumptions together. Ask only questions whose answers materially change behavior, scope, risk, or acceptance criteria. Group up to three independent questions in one turn; ask dependent questions sequentially. Do not invent quotas of questions, alternatives, user stories, or edge cases.
- **Approve the product choice once.** Present one coherent proposal before treating agent-proposed requirements as settled. Reuse an explicit approval already given for that exact design. A material new choice needs a decision; formatting the approved content into the canonical spec does not need another approval. A complete user-provided design should not trigger an artificial brainstorming interview.
- **Clarify without repeating brainstorming.** The clarification owner still scans the complete written spec. It resolves from recorded evidence what it can and asks only remaining questions. With no unresolved questions, advance to `clarified` without a user round trip. Missing mandatory information must not be silently assumed or deferred to claim completion.
- **Keep one canonical spec.** In the Maxi context, write the approved design into the existing spec template rather than publishing a second Superpowers design document and requesting a second review of equivalent content. Express this as explicit native wrapper instructions passed to the delegated skill; preserve vendored bytes and the delegation requirement. Test that the installed harness honors this adaptation.
- **Validate the design once.** When the requested scope includes the plan, use the same complete-flow self-check and maximum two independent review passes as revisions. Do not add a separate independent spec review. The existing design boundary reviews the complete spec/plan pair.

Keep all normal phase responsibilities and transitions: `drafting → specified → clarified → planned`, followed by the existing design gate when planning is in scope. Consolidating user interactions must not manufacture completed phases or approved evidence. A poorly understood feature may require more discussion; the cap applies to automatic review dispatches, not to necessary product decisions.

### 1. One request authorizes one bounded revision

Use the existing `revise` entry point to coordinate the revision goal. Reuse the user's supplied change description. Ask only for an unresolved product choice, ambiguous target, expanded scope, or separately protected action. Announce the affected artifacts and required rollback without asking the user to repeat an already explicit instruction.

Keep artifact writes with their existing owners. Define an explicit existing-spec edit mode for the spec owner; `revise` must not merely change status and leave the requested requirement unwritten. Delegate plan corrections to the existing planner. A direct `/maxi:review` remains report-only, and an explicit “edit only” request ends after editing.

The coordinated request ends at design validation. It never starts task extraction, readiness analysis, implementation, Git publication, or deployment. Preserve `reopened_from: done`, parked/cancelled guards, downstream stale-evidence checks, and separate ADR approval.

### 2. Stabilize the design before the independent review

Before changing the plan, inspect actual producers, transformations, persistence, reload, and consumers touched by the requested behavior. Check the proposed correction against all existing findings together. Reuse the plan's existing self-review section to record the chosen solution and the decisive source evidence.

For the NavRouteEdge example, the relevant checks are creation, explicit rename, reorder/inversion, save, reload, and generated-name exclusion. A list of files or a successful `git diff --check` does not establish those properties.

Do not turn a rejected design suggestion into a binding requirement without verifying it. Resolve contradictory findings against the spec, constitution, applicable ADRs, and actual source behavior. If that exposes a real product decision, ask that decision once.

### 3. One independent review, at most one correction round

After initial planning or a consolidated revision within the authorized design-validation scope, run one independent design review. Require all demonstrated blockers together, their requirement or decision basis, and the minimum correction. Preferences and mechanical implementation closure remain nonblocking under the existing predicate.

If rejected, the owner may perform one consolidated in-scope correction followed by one verification review. Reuse the same independent reviewer when the harness permits; provide the previous findings, exact changes, and complete current artifacts. Recheck resolved findings and interactions introduced by the correction. New genuine blockers remain valid and must cite their evidence; do not suppress them to force approval.

If the second verdict is rejected, stop with the unresolved causes, competing constraints, and a recommended decision. Do not spawn a third review, reset the allowance on context compaction, claim the next pass will be the last, or request another command mechanically. Use the existing review report for continuity; no new ledger, status, or orchestration service.

### 4. Preserve integrity while avoiding unnecessary repetition

Keep exact artifact hashes, the full decision-input digest, atomic report publication, and fail-closed downstream verification. A changed artifact never inherits an old approval, including an editorial change.

For this first change, preserve the current full decision-input contract. The same reviewer may retain unchanged context within the bounded round, but each pass must verify current inputs. A missing reviewer context or changed decision snapshot requires complete current inputs again, within the same review allowance.

Selective ADR loading and semantic-hash approvals are deferred: both change the evidence model and are not needed to remove the manual relay or uncontrolled review repetition. Measure their remaining cost after this fix.

## Implementation sequence

1. **Specify the changed contract and decision.** Create the normal Maxi spec for initial creation and revision convergence, with the behavior above as acceptance criteria. Propose a superseding ADR for ADR-0022's terminal-correction and explicit-re-review clauses, also recording initial-goal coordination and the native brainstorming adaptation. Preserve the three review boundaries and ten-state FSM. Obtain the required explicit ADR approval before writing it as accepted.
2. **Reproduce the failure behavior.** Extend existing specify/clarify/plan and revision/review scenarios with a complete initial brief, previously answered questions, a supplied change description, a rejected plan, conflicting local fixes, and a second rejection. Capture baseline owner dispatches, user prompts, review counts, artifact writes, and verdict validity. Use `superpowers:writing-skills` for the subsequent skill edits and its RED/GREEN/REFACTOR authoring cycle.
3. **Implement bounded coordination in native skills.** Update `skills/specify/SKILL.md` for initial-goal coordination, canonical spec output, delegated brainstorming adaptation, and explicit existing-spec edits; update `skills/clarify/SKILL.md` for prior-answer reuse, grouped independent questions, and automatic completion of a clean scan. Update `skills/revise/SKILL.md`, `skills/plan/SKILL.md`, and `skills/review/SKILL.md` for revision coordination and the bounded review contract. Keep `review` itself report-only; the initial or revision coordinator owns sequencing. Update the reviewer brief only for correction-round continuity and evidence requirements not already covered.
4. **Replace conflicting tests and synchronize documentation.** Update `tests/check-review-boundaries.sh`, `tests/check-revise.sh`, relevant integration prompts, and affected shared test cases. In the same implementation commit, synchronize `docs/pipeline-flow.md`, `docs/delegation-map.md`, `skills/using-maxi/SKILL.md`, `AGENTS.md`, and `docs/architecture.md`; update the README command descriptions as needed. Do not hand-edit vendored Superpowers skills.
5. **Validate behavior and report measured results.** Run the targeted checks, `bash tests/run-all.sh`, the repository doc-consistency skill, and authenticated integration scenarios. Compare a complete initial brief and the NavRouteEdge-shaped revision replay with their baselines using user-turn count, independent-review count, duplicate artifact count, elapsed time, and unresolved blockers. Passing static wording checks alone is insufficient to demonstrate convergence.

## Acceptance scenarios

| Scenario | Required result |
| --- | --- |
| Complete initial brief requests a spec only | Canonical spec reaches `clarified` after the real scan; no redundant questions, plan, or design review |
| Initial feature request includes design validation | Owners complete specify, clarify, plan, and the bounded design review without command relays |
| Initial brief leaves three independent product choices open | One grouped question turn; answers are reused by clarification |
| A question depends on a previous answer | Ask sequentially rather than requesting incompatible decisions together |
| Exact design already has explicit user approval | No second approval for reformatting it into the canonical spec |
| User requests only an initial draft | Preserve the requested stop point; do not infer permission for planning |
| Initial brainstorming is delegated in a Maxi context | One canonical spec, no duplicate design document or second approval of equivalent content; vendored files remain unchanged |
| Initial clarification scan finds a real gap | Ask about that gap; do not mark the phase complete to avoid a user turn |
| Clear request includes target and requirement change | No repeated description or redundant rollback confirmation; owners update the actual requirement and affected plan |
| One real product ambiguity | One focused question; independent investigation continues where possible |
| Review finds three compatible blockers | One consolidated correction and one verification review |
| Second review still rejects | Stop with a concrete decision or diagnosis; no third dispatch |
| Reviewer proposes a conflicting architecture preference | Verify against governing requirements; do not oscillate between designs on authority alone |
| Context is compacted during correction | The existing report preserves round continuity; the allowance is not reset |
| User requests review only or edit only | No unauthorized correction or successor phase |
| Spec, plan, constitution, or ADR changes during review | No current approval published for stale inputs |
| Spec is reopened from done | Preserve watermark, completion lineage safeguards, and stale downstream evidence |
| Spec is parked or cancelled | Preserve lifecycle guards; do not implicitly resume |

Success means fewer user relays and bounded review dispatches with current, valid evidence. No fixed wall-clock promise and no forced approval of an unresolved design.
