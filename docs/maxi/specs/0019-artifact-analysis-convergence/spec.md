---
slug: 0019-artifact-analysis-convergence
created: 2026-08-03
updated: 2026-08-03
revision: 7
status: implementing
parked_from: null
related_adrs: [0019-bounded-forward-artifact-replay, 0020-persisted-independent-handoff-reviews]
---

# Feature Specification: Bounded Minimal Replay

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See Current Document Versions (Priority: P1)

As a Maxi user, I want every pipeline-owned document in a new spec to show its version and direct inputs, so I can tell which design information is current.

**Why this priority**: Visible versions make the source of a stale downstream document understandable without retroactively changing existing specs.

**Independent Test**: Create a new spec through the normal pipeline and verify that every pipeline-owned document starts at revision 1; modify one owned document and verify that only its revision increments and its direct descendants are identified as stale.

**Acceptance Scenarios**:

1. **Given** a new spec created through the normal Maxi pipeline, **When** the pipeline creates `spec.md`, `research.md`, `data-model.md`, a file under `contracts/`, either review record under `reviews/`, `plan.md`, `tasks.md`, or `analysis.md`, **Then** that document has `revision: 1`.
2. **Given** a derived document, **When** its owner creates or structurally changes it, **Then** it records each direct document input and the exact input revision.
3. **Given** an existing or migration-created spec without revision metadata, **When** Maxi reads it, **Then** this feature does not modify it or infer a revision for it.

---

### User Story 2 - Propose the Smallest Safe Replay (Priority: P1)

As a Maxi user, I want Maxi to identify only the stale descendants of a changed document and propose the shortest continuation, so a correction does not restart unrelated phases.

**Why this priority**: Avoiding unnecessary `specify -> clarify -> plan -> tasks -> analyze` loops is the feature's primary outcome.

**Independent Test**: Change a plan and a task list independently, then verify the proposal names exactly the affected descendants and excludes unaffected ancestors.

**Acceptance Scenarios**:

1. **Given** `plan.md` changes, **When** Maxi compares declared direct input revisions, **Then** it marks `reviews/plan-review.md`, `tasks.md`, and `analysis.md` stale, stops at the required plan-review handoff, and proposes `tasks -> analyze` only after a matching approved review is present.
2. **Given** `tasks.md` changes, **When** Maxi compares declared direct input revisions, **Then** it marks only `analysis.md` stale and proposes a fresh independent `analyze`.
3. **Given** `revise` changes `spec.md` and returns the spec to `specified`, **When** Maxi compares declared direct input revisions, **Then** it proposes `clarify`, stops for the required spec-review handoff, and does not rerun `specify`.
4. **Given** `clarify` structurally changes `spec.md`, **When** Maxi compares declared direct input revisions, **Then** it requires a fresh spec review before it may propose `plan -> tasks -> analyze`; it does not rerun `clarify`.
5. **Given** a dependency path is missing or cyclic, **When** Maxi prepares a replay proposal, **Then** it stops with an actionable diagnostic and performs no regeneration.

---

### User Story 3 - Keep Replay Under User Control (Priority: P1)

As a Maxi user, I want to approve every proposed replay and to be stopped after a failed re-analysis, so Maxi cannot enter an automatic correction loop.

**Why this priority**: Minimal replay is useful only when it remains visible and controllable.

**Independent Test**: Trigger a stale descendant, reject and accept the same proposal, then make the resulting analysis fail and verify that Maxi requests another decision instead of replaying again.

**Acceptance Scenarios**:

1. **Given** stale descendants, **When** Maxi proposes a continuation, **Then** it shows the changed revisions, stale documents, and exact phase sequence before any replay-generated artifact write.
2. **Given** a replay proposal, **When** the user has not answered `yes`, **Then** no phase runs and no replay-generated artifact changes.
3. **Given** the user answers `yes`, **When** Maxi replays the proposal, **Then** it runs only the displayed sequence in dependency order.
4. **Given** the analysis after one approved replay still fails, **When** Maxi reports that failure, **Then** it stops and requires a new explicit user decision before another correction or replay.
5. **Given** a replay reaches an independent-review handoff, **When** its review is absent or stale, **Then** Maxi stops before the successor phase and names the reviewed document and revision; after a matching approved review is present, Maxi displays the remaining continuation and waits for a new explicit `yes` before executing it.

---

### User Story 4 - Require Independent Reviews at Handoffs (Priority: P1)

As a Maxi user, I want an independent review before planning, before task extraction, and before implementation, so a single author cannot silently carry an error through the pipeline.

**Why this priority**: The bounded replay mechanism only helps after a defect is found; independent handoff reviews make defects cheaper to find before their descendants are produced.

**Independent Test**: For a clarified spec and a planned plan, attempt the next producer without a matching approved review and verify it makes no write or status transition. Then supply an approved review from a context that did not author or correct the reviewed artifact and verify the next producer may proceed.

**Acceptance Scenarios**:

1. **Given** `clarify` has completed, **When** a fresh external reviewer approves the current `spec.md`, **Then** Maxi persists a versioned review record that names the reviewed path and exact revision, its reviewer context, and the verified absence of that context from the reviewed document's structural contributors before `plan` may run.
2. **Given** a clarified spec without a matching approved external review, **When** `plan` is invoked, **Then** it stops before writing `plan.md` or changing `status`.
3. **Given** `plan` has completed, **When** a fresh external reviewer approves the current `plan.md`, **Then** Maxi persists a versioned review record that names the reviewed path and exact revision before `tasks` may run.
4. **Given** a planned spec without a matching approved external review, **When** `tasks` is invoked, **Then** it stops before writing `tasks.md` or changing `status`.
5. **Given** `tasks` has completed, **When** `analyze` runs, **Then** it is performed by a reviewer context that is absent from the persisted structural contributors of the current `spec.md`, `plan.md`, and `tasks.md`, and it persists its result in `analysis.md` before implementation may proceed.
6. **Given** a reviewed artifact changes structurally, **When** Maxi checks its review record, **Then** that review is stale and cannot approve its successor phase.

### Edge Cases

- A structural owner-managed change increments only the changed document's revision; task-completion checkboxes and operational metadata do not make descendants stale.
- A document with multiple direct inputs is stale when any declared input revision no longer matches.
- A proposal never includes an unaffected ancestor or a full restart unless a changed `spec.md` makes that downstream path necessary.
- Migration and reverse-engineering workflows are outside this feature.
- A review rejection, a stale review, or an unverifiable reviewer independence claim blocks its successor phase; it does not cause an automatic replay.
- A replay may name a review handoff but never creates or approves a review record itself; a fresh external reviewer must create it before the user may approve the remaining continuation.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The revision and replay mechanism MUST apply only to specs created through the normal forward Maxi pipeline after this feature is introduced.
- **FR-002**: Every pipeline-owned document created for such a spec, namely `spec.md`, `research.md`, `data-model.md`, every `contracts/*.md`, `reviews/spec-review.md`, `plan.md`, `reviews/plan-review.md`, `tasks.md`, and `analysis.md`, MUST start with a positive integer `revision: 1`.
- **FR-003**: A structural owner-managed change to a versioned document MUST increment only that document's revision in the same write.
- **FR-004**: A derived document MUST declare its direct document inputs and their exact revisions in `derived_from`.
- **FR-005**: Maxi MUST identify a document as stale when one of its declared direct input revisions no longer matches, and MUST identify its transitive descendants as stale.
- **FR-006**: Maxi MUST compute the earliest stale producer and the shortest dependency-ordered continuation that regenerates only stale descendants, starting from the phase supplied by the owner that made the structural change. The continuation MUST stop before its first required independent-review handoff.
- **FR-007**: Before a replay, Maxi MUST display the owner-supplied previous revision, the current revision, stale documents, the proposed executable phase sequence, and any required review handoff that prevents a later successor phase.
- **FR-008**: Maxi MUST not replay any phase until the user gives an explicit `yes` to that displayed proposal.
- **FR-009**: A rejected, absent, or ambiguous response MUST leave every replay-generated artifact unchanged; it MUST NOT revert the already completed owner-managed source change that produced the proposal.
- **FR-010**: After one approved replay, a failed analysis MUST stop further correction and replay until a new explicit user decision.
- **FR-011**: `spec.md` changes MUST never cause `specify` to rerun; the full downstream continuation begins with `clarify`.
- **FR-012**: Existing, migrated, and reverse-engineered specs MUST remain outside this mechanism and MUST not be retroactively versioned.
- **FR-013**: Missing dependency paths, malformed revision metadata, dependency cycles anywhere in the pipeline-owned graph, and paths physically resolving outside the selected spec directory MUST fail closed before a replay is proposed.
- **FR-014**: The feature MUST introduce no new FSM status.
- **FR-015**: Owner skills remain responsible for document writes and provide the planner with the changed document, previous revision, and required first replay phase; a shared read-only support script MAY calculate staleness and format replay proposals but MUST not write artifacts or run phases.
- **FR-016**: For a real missing or ambiguous requirement in `spec.md`, `revise` MUST offer the exceptional rollback target `specified`, then the approved replay begins with `clarify`; all other rollback target rules remain unchanged.
- **FR-017**: Every structural write to a pipeline-owned document MUST persist its unique `writer_context` in that document's append-only `structural_contributors` list. A context that corrected a document is a structural contributor of that document.
- **FR-018**: Before `plan` writes `plan.md` or changes `status`, it MUST require `reviews/spec-review.md` with an `approved` verdict, `derived_from` the current `spec.md` revision, and a `reviewer_context` absent from `spec.md`'s persisted `structural_contributors` list.
- **FR-019**: Before `tasks` writes `tasks.md` or changes `status`, it MUST require `reviews/plan-review.md` with an `approved` verdict, `derived_from` the current `plan.md` revision, and a `reviewer_context` absent from `plan.md`'s persisted `structural_contributors` list.
- **FR-020**: `analyze` MUST be the independent review gate before `implement`: its `reviewer_context` MUST be absent from the persisted `structural_contributors` lists of the current `spec.md`, `plan.md`, and `tasks.md`; `analysis.md` MUST record the reviewed revisions, its `reviewer_context`, and the verification result.
- **FR-021**: A missing, rejected, malformed, unverified, or stale review record MUST block only its successor phase before any artifact write or status transition; it MUST not create a new FSM status, trigger replay, or alter an existing artifact.
- **FR-022**: Review records are pipeline-owned documents: they MUST carry a revision and exact direct input revisions, and a structural change to their reviewed artifact makes them stale under the same mechanism as every other derived document.
- **FR-023**: A replay MUST never generate or approve a review record. When a required review is stale or absent, it MUST stop before the successor phase and require an external review of the named current revision; after a matching approval is present, it MUST display the remaining continuation and require a new explicit `yes` before executing it.

### Key Entities

- **Versioned spec document**: A document created for a new forward-pipeline spec that carries a positive `revision`.
- **Pipeline-owned document**: `spec.md`, `research.md`, `data-model.md`, a `contracts/*.md` file, `reviews/spec-review.md`, `plan.md`, `reviews/plan-review.md`, `tasks.md`, or `analysis.md` created by the normal forward pipeline.
- **Structural contributor**: The unique `writer_context` of a context that made a structural write to a pipeline-owned document, persisted in that document's append-only `structural_contributors` list.
- **Review record**: `reviews/spec-review.md` or `reviews/plan-review.md`, a versioned external-review artifact with a reviewed document, exact reviewed revision, verdict, and `reviewer_context` verified against the reviewed document's structural contributors.
- **Direct input**: A document path and exact revision recorded in `derived_from` by a derived document.
- **Stale descendant**: A document whose direct input revision no longer matches, or whose transitive input is stale.
- **Replay proposal**: The displayed changed revision, stale documents, and shortest phase sequence awaiting explicit user confirmation.

## Clarifications

**Revised (2026-08-03):** Rolled back from `planned` to `clarified`. Change: define the replay entry phase, preserve the pre-write revision in the proposal contract, and enumerate the pipeline-owned documents. Note: `plan.md` and later artifacts are stale.

**Revised (2026-08-03):** Corrected the replay contract after independent review. A rejected proposal prevents only replay-generated writes, the planner validates the full confined graph, and a source-spec gap has the exceptional `specified` rollback required to run `clarify` legitimately.

**Revised (2026-08-03):** Rolled back from `planned` to `clarified` and added independent handoff reviews. A fresh external review now gates planning after clarification, task extraction after planning, and analysis before implementation; matching review records are versioned and stale when their reviewed artifact changes. Note: `plan.md` and later artifacts are stale.

**Revised (2026-08-03):** Made independent-review verification and replay handoffs explicit after review. Structural contributors are persisted and checked against a reviewer's context; replay stops at each external review rather than generating a review or continuing past it automatically.

**Revised (2026-08-03):** Corrected the post-review consent order. A matching external review causes Maxi to display the remaining continuation first; only a subsequent explicit `yes` executes it.

**Revised (2026-08-03):** Included both review records in the versioned-document acceptance scenario, matching the canonical requirement list.

**Revised (2026-08-03):** Rolled back from `tasked` to `planned` after independent task review found an impossible review-record checkpoint and missing failed-reanalysis-stop coverage. Note: `tasks.md` is stale and will be regenerated from the corrected plan.

**Revised (2026-08-03):** Rolled back from `analyzed` to `planned` after independent analysis found stale ADR-candidate instructions and a removed ledger reference. Note: `tasks.md` and `analysis.md` are stale and will be regenerated after the targeted plan correction.

**Q: Which specs receive document revisions?**
A: Only new specs created through Maxi's normal forward pipeline. Existing, migrated, and reverse-engineered specs remain unchanged.

**Q: What happens when Maxi finds stale descendants?**
A: Maxi displays the smallest replay proposal and waits for an explicit `yes`; it never continues automatically.

**Q: What happens when re-analysis fails after an approved replay?**
A: Maxi stops and requires a new explicit user decision before another correction or replay.

**Q: What determines the first phase in a replay proposal?**
A: The owner that made the structural change supplies it. A `revise` change to the source spec starts at `clarify`; a `clarify` change starts at `plan`.

**Q: How does a replay cross an independent-review handoff?**
A: It does not cross one automatically. The proposal stops before the handoff and names the current document and revision to review. After a matching independent review, Maxi displays the remaining phases and waits for a new explicit `yes`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of pipeline-owned documents created for a new forward-pipeline spec begin at revision 1.
- **SC-002**: In plan-only and tasks-only fixtures, the replay proposal identifies all and only stale descendants and stops at the first required independent-review handoff.
- **SC-003**: The deterministic owner-skill contract accepts only the exact reply `yes` as approval; every fixture for silence, `ok`, or prior consent produces no directed replay invocation, and the read-only planner changes no artifact or replay-generated output.
- **SC-004**: In 100% of accepted plan-only and tasks-only proposals, replay excludes unaffected ancestors.
- **SC-005**: In 100% of fixtures where re-analysis fails after one approved replay, Maxi requests a new user decision and starts no further replay.
- **SC-006**: Existing, migrated, and reverse-engineered fixture specs receive no revision metadata or replay behavior from this feature.
- **SC-007**: In 100% of fixtures without a matching approved independent review record, `plan` and `tasks` stop before writing their output or transitioning status.
- **SC-008**: In 100% of review fixtures, a context recorded as a structural contributor of the reviewed document cannot approve it, and a structural revision makes its prior review record stale.
- **SC-009**: In 100% of analysis fixtures, the report records a reviewer context verified absent from the structural contributors of the reviewed current artifacts before `implement` may proceed.

## Assumptions

- The normal forward pipeline continues to use `specify -> clarify -> plan -> tasks -> analyze -> implement`.
- Planning support documents are the pipeline-owned `research.md`, `data-model.md`, and `contracts/*.md` files; they are versioned when created and may be direct inputs of `plan.md`.
- Independent review records are created only at their corresponding handoffs. They are not new pipeline phases or FSM statuses.
- This replacement supersedes the former broad 0019 scope. The pre-existing `plan.md` and `tasks.md` describe that former scope and are non-authoritative until regenerated by the pipeline.
