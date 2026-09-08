---
slug: 0025-convergent-design-workflow
created: 2026-09-08
updated: 2026-09-08
status: implementing
parked_from: null
related_adrs: [0029-convergent-design-workflow]
---

# Feature Specification: Convergent Initial Specs and Revisions

Source: [revision-workflow-proposal](../../../revision-workflow-proposal.md), approved in conversation and expanded to initial specifications. This specification describes proposed behavior; it does not activate that behavior in the current pipeline.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Revise Without Relaying Commands (Priority: P1)

A user supplies a requirement change and receives a coherent updated spec and plan with a current design verdict, without repeatedly requesting rollback, correction, and review.

**Why this priority**: This is the observed NavRouteEdge failure and the primary source of wasted user turns.

**Independent Test**: Revise a planned spec with a supplied target and change; observe owner writes, user prompts, and review dispatches through the terminal result.

**Acceptance Scenarios**:

1. **Given** a planned spec and an explicit requirement change, **When** revision starts, **Then** the actual requirement and affected plan are updated by their owners without requesting the description again or manual successor commands.
2. **Given** three compatible demonstrated blockers, **When** the owner corrects the rejected design, **Then** it resolves them together and checks their interactions before verification review.
3. **Given** a second rejected verdict, **When** the revision ends, **Then** it reports unresolved causes and a recommended decision without another dispatch or a mechanical restart request.

### User Story 2 - Create a Spec Without Duplicate Elicitation (Priority: P1)

A complete feature brief produces one canonical clarified spec. A request through design validation additionally produces a reviewed plan without command relays.

**Why this priority**: Initial creation exposes the same repeated questions, approvals, and handoffs as revision.

**Independent Test**: Submit complete and incomplete initial briefs with distinct requested destinations; inspect questions, canonical artifacts, and final statuses.

**Acceptance Scenarios**:

1. **Given** a complete approved design and a spec-only request, **When** specification and the real clarification scan finish, **Then** one canonical spec is clarified, no answered question is repeated, and no plan or design review exists.
2. **Given** a request through design validation, **When** the brief is sufficient, **Then** specify, clarify, plan, and bounded design review run through their owners without command relays.
3. **Given** three independent product questions, **When** elicitation runs, **Then** they may be grouped in one turn and their answers are reused during clarification; dependent questions remain sequential.
4. **Given** approval of the exact design, **When** that content is formatted into the Maxi template, **Then** no equivalent second approval or duplicate Superpowers design document is required.

### User Story 3 - Preserve Scope, Evidence, and Lifecycle Safety (Priority: P1)

Users can request only drafting, editing, or reviewing. Coordinated work cannot approve stale inputs or erase earlier attempts.

**Why this priority**: Reducing friction must not reintroduce unbounded replay.

**Independent Test**: Exercise narrow requests, interrupted reviews, changed decision inputs, and reopened or inactive specs; inspect writes and dispatch counts.

**Acceptance Scenarios**:

1. **Given** review-only or edit-only scope, **When** its owner completes, **Then** no unrequested correction or successor phase runs.
2. **Given** inputs change during review, **When** publication is attempted, **Then** no current approval is published for stale inputs.
3. **Given** compaction or an unavailable reviewer, **When** the operation resumes, **Then** consumed review allowance is retained; missing continuity cannot grant a fresh allowance automatically.
4. **Given** a spec reopened from done, **When** revision runs, **Then** the watermark, completion lineage protections, and downstream freshness checks remain effective.

### Edge Cases

- A real source-spec gap routes to its owner; a technical finding does not silently become a product requirement.
- Opposing suggestions are checked against governing requirements and source evidence rather than adopted alternately.
- Newly demonstrated defects remain blocking even when the review allowance is exhausted.
- Missing, malformed, interrupted, or stale review results grant neither approval nor an automatic retry allowance.
- Reviewer replacement receives complete current inputs and consumes the same operation's remaining allowance.
- Parked/cancelled guards remain; an ambiguous target requires clarification before writing.
- A user stop or material scope change interrupts continuation. After exhaustion, a new operation requires an explicit new instruction and a stated changed strategy, not an agent-proposed mechanical restart.
- Historical approvals are not given fabricated continuation metadata.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Bind the target, change or initial feature, and stop point from the request and conversation. Ask only when missing information materially affects outcome, scope, or risk.
- **FR-002**: Initial spec-only requests, including bare `/maxi:specify`, MUST end at clarified after an actual clarification scan. Requests through design validation additionally complete planning and bounded review. Explicit draft-only or phase-only scope stops earlier.
- **FR-003**: Clear revision requests MUST coordinate actual spec and affected plan corrections through design validation using existing artifact owners. A status change and note alone do not satisfy a requirement edit.
- **FR-004**: Reuse facts, answers, and approval for the exact current design. Do not demand repeated descriptions, redundant rollback confirmation within an explicit request, or another approval solely for formatting.
- **FR-005**: Ask only unresolved material questions, allow up to three independent questions per turn, keep dependent questions sequential, and impose no arbitrary question or alternative quotas. Agent-proposed material product choices require user approval before becoming settled.
- **FR-006**: Clarification MUST scan the complete written spec, use recorded evidence, ask about remaining gaps, and advance without a user turn when none remain. It MUST NOT fabricate answers or defer mandatory information to claim completion.
- **FR-007**: Produce one canonical Maxi spec. Native wrappers MUST delegate with explicit Maxi artifact and dialogue adaptations instead of duplicating Superpowers or modifying vendored bytes.
- **FR-008**: Preserve all phase responsibilities and the ten-state FSM. Native owners retain artifact writes and transitions; coordinators own sequencing. Introduce no native skill, command, status, separate ledger, or orchestration service.
- **FR-009**: Before independent review, check the complete affected data lifecycle against requirements and all findings together using actual source behavior where applicable. Record the chosen solution and decisive evidence in the existing plan self-review section.
- **FR-010**: Each coordinated operation MUST allow at most two independent design-review dispatches: initial review and, if needed, verification after one consolidated in-scope correction. Invalid or interrupted results MUST NOT create an automatic retry allowance.
- **FR-011**: Report all demonstrated blockers together under the existing blocking predicate. Mechanical closure and preferences remain nonblocking. Verify conflicting suggestions against requirements, constitution, applicable decisions, and source evidence.
- **FR-012**: Prefer the same independent reviewer for verification when supported. Supply prior findings, changes, and complete current artifacts; recheck resolved findings and changed interactions while admitting new genuine blockers.
- **FR-013**: Exhausted or unrecoverable operations MUST stop with unresolved causes and a recommended decision or changed strategy, never forced approval or a third dispatch. Existing review-report continuity MUST survive compaction; missing continuity stops rather than resets the allowance.
- **FR-014**: Preserve exact spec/plan hashes, the complete decision-input digest, installed verifiers, atomic publication, and fail-closed freshness checks. Diagnostic continuation information MUST remain distinguishable from valid approval evidence and cannot make rejected, incomplete, or stale reports pass.
- **FR-015**: Public `/maxi:review` remains report-only. Edit-only and draft-only requests retain their stop points. Coordinated design work authorizes no task extraction, readiness analysis, implementation, Git publication, or deployment.
- **FR-016**: Preserve parked/cancelled guards, monotone `reopened_from: done`, completion lineage protections, and separate ADR approval. Preserve stale descendants without treating them as current.
- **FR-017**: Retain the design, readiness, and upstream SDD final implementation review boundaries. Add no independent spec review.
- **FR-018**: Synchronize changed contracts across the five mandatory pipeline documents, README, native instructions, and affected tests. Replace contradictory handoff guidance instead of retaining it beside new rules.
- **FR-019**: Validate observable owner dispatches, prompts, writes, review counts, and evidence validity for initial creation and revision. Static instruction matching alone cannot establish behavioral success.

### Key Entities

- **Design operation**: One authorized initial or revision goal with a target, scope, stop point, and consumed review allowance.
- **Canonical artifacts**: Existing spec, plan, and review report with their existing owners; no parallel design document.
- **Findings and continuity**: Existing review-report content identifying unresolved findings and progress without substituting for stamped approval evidence.

## Clarifications

**Q: Does the workflow also cover initial specifications?**
A: Yes. The user explicitly expanded the approved revision proposal to initial specs before requesting the next step.

**Q: What is the default destination for an initial spec request?**
A: The accepted proposal distinguishes a clarified spec from explicit design validation. A bare specification request stops at clarified; a broader design-validation request includes the plan and bounded review.

**Q: Does the review limit require approving unresolved defects?**
A: No. Two dispatches are the maximum per coordinated operation. A remaining defect, invalid result, or missing continuity produces a concrete stop, never fabricated approval or an automatic allowance reset.

**Clarification scan (2026-09-08):** Reviewed all stories, requirements, edge cases, and success criteria against the approved proposal. No unresolved product question remains. Approval of the replacement ADR is a separate decision gate, not missing product information. The concrete report-continuity representation and test harness belong to technical planning.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Complete approved initial designs and clear revisions produce zero redundant elicitation/confirmation turns and zero command-relay turns within their requested destination.
- **SC-002**: Every coordinated design-validation scenario performs at most two independent review dispatches, including second rejection, interruption, compaction, and reviewer replacement.
- **SC-003**: Initial creation produces exactly one canonical spec and no duplicate design document; spec-only scenarios produce no plan or review.
- **SC-004**: All narrow-scope, stale-input, inactive-spec, and reopened-spec scenarios preserve their boundaries; no negative scenario yields valid approval or unauthorized successor work.
- **SC-005**: Behavioral checks demonstrate one consolidated correction for compatible findings, continued blocking for a genuine unresolved defect, and no architecture oscillation based solely on conflicting advice.
- **SC-006**: The full fast suite passes and authenticated behavioral scenarios report user-turn count, review count, artifact count, elapsed time, and unresolved blockers against initial and revision baselines. No absolute wall-clock speedup is promised.

## Assumptions

- The approved conversation proposal supplies the product design; this spec formalizes it rather than introducing a new objective.
- Activation requires a successor to [0022-fixed-review-boundaries](../../adr/0022-fixed-review-boundaries.md), explicitly refining the repeated explicit-review clause of [0023-dedicated-design-review-contract](../../adr/0023-dedicated-design-review-contract.md) while retaining its reviewer predicate and [0028-decision-input-freshness](../../adr/0028-decision-input-freshness.md).
- Selective ADR loading, semantic-hash approval reuse, implementation-loop changes, automatic publication, dependencies, and historical artifact migration are out of scope.
- Reviewer continuity is an optimization, not a harness guarantee. Missing context requires complete current inputs within the same allowance.
- Underspecified features may need multiple product discussions. The cap bounds review dispatches, not necessary decisions.
