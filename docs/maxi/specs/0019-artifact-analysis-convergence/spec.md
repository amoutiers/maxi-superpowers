---
slug: 0019-artifact-analysis-convergence
created: 2026-08-01
updated: 2026-08-01
status: tasked
# Allowed values: drafting | specified | clarified | planned | tasked | analyzed | implementing | done | parked | cancelled
parked_from: null
# parked_from: set by /maxi:park to the pre-park status; cleared to null by /maxi:resume
related_adrs: [0017-revision-bound-artifact-graph, 0018-independent-analysis-bounded-convergence]
# related_adrs: full ADR slugs (NNNN-slug) appended by x-adr when an ADR is accepted
---

# Feature Specification: Artifact Revisions and Bounded Analysis Convergence

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Block Invalid Implementation Entry (Priority: P1)

As a feature owner, I want the final analysis gate to advance a spec only when its artifacts are current and its blocking findings are cleared, so implementation cannot start from a known-invalid design.

**Why this priority**: The current status transition can make a failed analysis eligible for implementation. Preventing that unsafe transition is the minimum viable correction.

**Independent Test**: Create a tasked fixture with a blocking analysis finding, run the analysis workflow, and verify the spec remains `tasked` and implementation refuses to start. Resolve the finding, rerun analysis, and verify the spec becomes `analyzed`.

**Acceptance Scenarios**:

1. **Given** a spec at `tasked` with at least one open blocking finding, **When** analysis completes, **Then** the spec remains at `tasked` and the report result is `failed`.
2. **Given** a spec at `tasked` with current artifacts and no open blocking finding, **When** independent analysis completes successfully, **Then** the report records a passing result and the spec transitions to `analyzed`.
3. **Given** a spec whose frontmatter says `analyzed` but whose analysis is failed, absent, or stale, **When** implementation is requested, **Then** implementation refuses and identifies the invalid prerequisite.

---

### User Story 2 - Detect Stale Artifacts and Replay Minimally (Priority: P1)

As a Maxi user, I want mutable artifacts to record their revisions and direct inputs, so the workflow can identify stale descendants and replay only the producers that are actually affected.

**Why this priority**: Reliable minimal replay is the primary mechanism for removing unnecessary full-pipeline regeneration.

**Independent Test**: Build a current constitution/spec/plan/tasks/analysis fixture, change each upstream artifact in turn, and verify the validator reports exactly the expected stale descendants and rollback entry point.

**Acceptance Scenarios**:

1. **Given** a current plan derived from spec revision 3, **When** the spec advances to revision 4, **Then** the plan and all of its descendants are reported stale.
2. **Given** a current task list derived from plan revision 5, **When** only the plan advances to revision 6, **Then** the task list and analysis are stale while the spec remains current.
3. **Given** a defect owned only by `tasks.md`, **When** correction is approved, **Then** the workflow returns to `planned` and replays `tasks` and `analyze` without rerunning `clarify` or `plan`.
4. **Given** a task-only correction is approved, **When** the rollback decision is persisted, **Then** it advances only the per-spec workflow ledger and does not advance the revisions of `spec.md` or `plan.md`.

---

### User Story 3 - Repair Original Specification Gaps (Priority: P1)

As a feature owner, I want any missing normative behavior discovered downstream to be corrected in the original specification, so plans, contracts, and tasks cannot silently become competing sources of requirements.

**Why this priority**: Local compensation for specification gaps creates inconsistent sources of truth and makes later analysis unstable.

**Independent Test**: Present a plan-time or analysis-time finding that identifies a missing public behavior, verify the finding owner is `spec.md`, approve the rollback, and confirm only the targeted clarification plus downstream regeneration occurs.

**Acceptance Scenarios**:

1. **Given** a plan exposes a missing public error behavior, **When** its local gate classifies the defect, **Then** the owner is `spec.md` and the proposed rollback target is `specified`.
2. **Given** the user approves a rollback for a real specification gap, **When** `clarify` resumes, **Then** it resolves only the identified gap and preserves previously valid clarifications.
3. **Given** a downstream artifact attempts to add behavior absent from the spec, **When** its local gate runs, **Then** the gate refuses to advance and directs the correction to `spec.md`.

---

### User Story 4 - Converge with Stable Findings (Priority: P2)

As a feature owner, I want analysis findings to retain stable identities and automatic correction to stop after one replay, so repeated reviews show a meaningful delta instead of restarting an unbounded loop.

**Why this priority**: Stable evidence and a hard stop make semantic review understandable and bounded even when a second reviewer finds something new.

**Independent Test**: Run two independent analyses around one approved correction cycle and verify finding identities, state changes, delta reporting, and the stop behavior after a second failure.

**Acceptance Scenarios**:

1. **Given** a finding recorded as `F001`, **When** a later analysis observes the same issue, **Then** it retains `F001` rather than creating a duplicate identity.
2. **Given** one user-approved correction cycle has already completed, **When** the second complete analysis still fails, **Then** the workflow performs no further rollback or regeneration and requests a new user decision.
3. **Given** the second analysis completes, **When** its report is written, **Then** it distinguishes new, resolved, and unchanged findings.

---

### User Story 5 - Preserve Legacy and ADR Semantics (Priority: P2)

As a maintainer, I want existing artifacts to adopt revisions incrementally while ADRs remain revision-free and append-only, so the feature does not require a destructive migration or weaken the decision log.

**Why this priority**: Maxi must improve active workflows without rewriting historical project artifacts or changing ADR identity semantics.

**Independent Test**: Validate legacy mutable artifacts and current, superseded, and deprecated ADR fixtures, then modify one legacy artifact and confirm only that artifact adopts revision 1.

**Acceptance Scenarios**:

1. **Given** a legacy mutable artifact without revision metadata, **When** it is read, **Then** it is treated as revision 0 without being rewritten.
2. **Given** that legacy artifact is modified by its owning skill, **When** the write completes, **Then** it records revision 1 in the same operation.
3. **Given** an accepted ADR referenced by a current plan, **When** the artifact graph is validated, **Then** the ADR is checked by immutable slug and status without revision metadata.
4. **Given** a referenced ADR is superseded or deprecated, **When** a phase gate runs, **Then** it blocks, identifies the obsolete reference and any declared successor, and never substitutes the successor automatically.

### Edge Cases

- Multiple findings belong to different artifacts: the earliest owner in the pipeline determines the rollback target for the approved batch.
- A constitution change does not stale existing artifacts; the next phase of an active spec reruns constitution alignment, updates `validated_against` on success, and opens a finding only on a real conflict. Done and cancelled specs remain historical records without revalidation.
- A dependency path is missing, duplicated, or cyclic: the deterministic gate fails before semantic analysis.
- Deterministic validation fails before a reviewer is invoked: the report records `review_mode: not-run`, `result: failed`, and no reviewer identity rather than misrepresenting the run as a self-review.
- A task references an unknown FR or SC identifier: coverage validation fails and the spec remains at its current pre-analysis status.
- A finding disappears because its location moved but its meaning remains: semantic matching preserves the existing finding identifier when the reviewer can establish equivalence.
- A non-blocking finding is accepted or deferred: acceptance requires a durable rationale, deferral requires a linked follow-up Maxi spec, and the disposition remains visible in later reports.
- A constitution violation is proposed for acceptance: the workflow refuses because constitution findings are never waivable through analysis disposition.
- The runtime cannot provide an independent reviewer context: a self-review may produce a provisional report, but the spec remains `tasked` and the workflow provides a handoff for analysis in a separate session.
- The original independent reviewer is available after correction: the same reviewer is preferred for the second analysis in that correction cycle; otherwise another independent reviewer reconciles the persisted finding registry.
- A user edits a mutable artifact outside its owning skill without incrementing `revision`: metadata-only validation cannot detect the silent edit; such out-of-band mutation is unsupported by this feature.
- A mutable artifact references a valid ADR whose successor exists but is not yet reflected in the spec or plan: the gate blocks for human review rather than changing the reference.
- A rollback is approved before any analysis report exists: the workflow creates the per-spec workflow ledger at revision 1 and records the decision there without modifying an unaffected content artifact.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `spec.md` MUST remain the sole source of expected behavior, public constraints, user-visible contracts, and success criteria.
- **FR-002**: `plan.md`, supporting technical artifacts, and `tasks.md` MUST NOT introduce normative behavior absent from `spec.md`.
- **FR-003**: Each forward phase MUST complete a gate for the artifact it owns before advancing the spec status.
- **FR-004**: A failed final analysis MUST leave the spec at `tasked`.
- **FR-005**: Analysis MUST transition `tasked` to `analyzed` only when an independent review result is passing and its input artifacts are current.
- **FR-006**: Implementation MUST validate the current independent analysis result and input freshness in addition to checking `status: analyzed`.
- **FR-007**: Every mutable per-project Maxi artifact governed by this workflow MUST carry a positive integer `revision` after creation or its first governed modification.
- **FR-008**: A newly created mutable Maxi artifact MUST start at `revision: 1`.
- **FR-009**: Every governed write that changes a mutable artifact's body or non-exempt frontmatter MUST increment `revision` in the same operation; the closed exemptions are `updated`, `status`, `parked_from`, task completion checkboxes, `related_adrs`, `validated_against`, and `validated_workflow`.
- **FR-010**: Mutable derived artifacts MUST record every direct mutable content input and its exact revision in canonical `derived_from`; constitution validation MUST be recorded separately in `validated_against`, correction-state validation MUST be recorded separately in `validated_workflow`, and immutable ADR references MUST remain in `related_adrs`.
- **FR-011**: Freshness validation MUST traverse direct dependencies to determine transitive staleness.
- **FR-012**: A stale artifact MUST NOT satisfy a phase transition or implementation gate.
- **FR-013**: A legacy mutable artifact with no `revision` field MUST be interpreted as revision 0 without an automatic rewrite.
- **FR-014**: The next governed modification of a legacy revision-0 artifact MUST write revision 1.
- **FR-015**: `updated:` MUST remain a human-readable date and MUST NOT be used as proof of artifact freshness.
- **FR-016**: The revision mechanism MUST apply to mutable per-project Maxi artifacts, including the constitution, specs, plans, research, data models, contracts, tasks, analyses, and per-spec workflow ledgers.
- **FR-017**: The revision mechanism MUST NOT be imposed on general repository documentation outside the per-project Maxi artifact graph.
- **FR-018**: ADR files MUST NOT carry `revision` or `derived_from` metadata.
- **FR-019**: Mutable artifacts MUST reference ADRs by full immutable slug separately from mutable `derived_from` entries.
- **FR-020**: A phase gate MUST validate that each referenced ADR exists and has `status: accepted`; proposed, superseded, deprecated, or missing ADRs MUST NOT satisfy the gate.
- **FR-021**: A reference to a superseded or deprecated ADR MUST block the relevant gate and identify any declared successor for review.
- **FR-022**: The workflow MUST NOT substitute an ADR successor automatically.
- **FR-023**: Every finding MUST be assigned to the earliest artifact whose content must change to resolve it.
- **FR-024**: A missing or ambiguous normative requirement discovered downstream MUST be owned by `spec.md`.
- **FR-025**: The rollback target MUST be `specified` for a specification gap, `clarified` for a plan or technical-contract defect, `planned` for a task defect, and `tasked` for an analysis-only defect.
- **FR-026**: `revise` MUST allow an explicit, exceptional rollback to `specified` when a real gap in the original specification is identified.
- **FR-027**: After a rollback to `specified`, `clarify` MUST process the identified gaps without reopening previously valid decisions unless a new finding directly invalidates them.
- **FR-028**: Before proposing rollback, the workflow MUST complete the current finding inventory, assign owners, select the earliest owner, and list every descendant that will become stale.
- **FR-029**: One explicit user confirmation MUST authorize the complete correction batch and its stated rollback target.
- **FR-030**: Internal context, automatic continuation, a persisted goal, silence, and ambiguous acknowledgements MUST NOT count as rollback consent.
- **FR-031**: After correction, the workflow MUST regenerate only the corrected artifact's descendants, in dependency order.
- **FR-032**: Previously valid decisions and clarifications MUST be preserved during targeted replay.
- **FR-033**: A single deterministic validation contract MUST govern artifact revision schema, content-dependency existence and freshness, cycles, constitution validation markers, ADR references, status compatibility, and explicit requirement references.
- **FR-034**: `plan`, `tasks`, `analyze`, and `implement` MUST apply the same deterministic validation contract at their relevant gates.
- **FR-035**: Tasks MUST reference every FR and build-relevant SC they cover using explicit identifiers.
- **FR-036**: Keyword inference MAY suggest a missing task reference but MUST NOT count as evidence of requirement coverage.
- **FR-037**: Deterministic validation failure during analysis MUST stop before semantic review, record actionable evidence, and leave the spec at `tasked`.
- **FR-038**: Semantic analysis MUST evaluate ambiguity, contradiction, missing requirements, unjustified decisions, constitution and ADR alignment, testability, feasibility, and gaps revealed by the existing codebase.
- **FR-039**: Semantic analysis MUST run in a reviewer context that did not author or correct the artifacts under review; the same independent reviewer SHOULD be reused for the second analysis in one correction cycle, with another independent reviewer allowed to reconcile the registry when reuse is unavailable.
- **FR-040**: Every analysis report MUST declare `review_mode` as `independent`, `self-review`, or `not-run`; `not-run` is permitted only when deterministic validation stopped before semantic review, and neither `self-review` nor `not-run` MAY transition the spec to `analyzed`.
- **FR-041**: Analysis MUST persist finding identifiers across runs and MUST NOT recycle an identifier.
- **FR-042**: Findings MUST support `open`, `resolved`, `accepted`, and `deferred`; `accepted` MUST carry a durable rationale, while `deferred` MUST link to an existing follow-up Maxi spec that is neither `done` nor `cancelled`.
- **FR-043**: Each analysis rerun MUST distinguish new, resolved, and unchanged findings.
- **FR-044**: CRITICAL and HIGH findings MUST be blocking; MEDIUM and LOW findings MUST be non-blocking but require a valid `resolved`, `accepted`, or `deferred` disposition before analysis can pass, and otherwise remain `open`.
- **FR-045**: A constitution violation MUST remain blocking and MUST NOT be accepted or deferred through analysis disposition.
- **FR-046**: Analysis results MUST be `failed` when any blocking finding is open or any non-blocking finding lacks a valid disposition, `pass-clean` when every finding is resolved, and `pass-with-exceptions` when no blocking finding is open and at least one non-blocking finding is validly accepted or deferred.
- **FR-047**: Only independent `pass-clean` and `pass-with-exceptions` results with current inputs MUST permit `tasked` to transition to `analyzed`.
- **FR-048**: The first failed independent final analysis MAY initiate one user-approved correction and regeneration cycle.
- **FR-049**: If the next complete independent analysis also fails, the workflow MUST perform no further automatic rollback, correction, or regeneration.
- **FR-050**: After a second consecutive failed final analysis, the workflow MUST report original unresolved findings, newly discovered findings, and classification disagreements separately.
- **FR-051**: Continuing after the correction-cycle limit MUST require a new direct user decision, and each such decision MUST authorize at most one additional correction and re-analysis cycle before the workflow stops again on failure.
- **FR-052**: Implementation MUST refuse an absent, failed, stale, self-reviewed, not-run, or undeclared-review-mode analysis even when the spec frontmatter says `analyzed`.
- **FR-053**: Gate failures MUST identify the earliest invalid or stale artifact and the dependency path that caused the failure.
- **FR-054**: The feature MUST introduce no new FSM status.
- **FR-055**: Pipeline documentation, templates, fixtures, and deterministic checks MUST be updated consistently with the new revision, rollback, analysis, and implementation-gate rules.
- **FR-056**: Lifecycle events, rollback decisions, correction-cycle authorizations, and correction-cycle consumption MUST be persisted in a per-spec `workflow.md` ledger rather than by changing an unaffected content artifact; lifecycle events include park, resume, cancel, and revise operations.
- **FR-057**: A workflow-ledger write MUST increment the ledger's own revision but MUST NOT by itself stale a content artifact; `analysis.md` MUST record in `validated_workflow` a canonical hash of correction-cycle events only, so a correction event stales the report while unrelated park, resume, or cancel events do not.
- **FR-058**: New specs MUST create `workflow.md` at revision 1, while legacy specs without the ledger MUST be interpreted as having no prior rollback or correction-cycle events and MUST create it at revision 1 on the first governed workflow event.
- **FR-059**: An analysis coordinator MUST label a review `independent` only when the runtime created a reviewer context separate from all contexts that authored or corrected the current artifacts, or when a separate-session handoff returns an explicit independence declaration; a generated identifier alone MUST NOT establish independence, and a separate-session reviewer that will be reused MUST hand correction back to an authoring context rather than editing reviewed source artifacts itself.
- **FR-060**: Every independent or self-review report MUST persist a canonical hash of the semantic finding set returned by the reviewer; disposition-only updates MAY retain that review evidence only when the hashed semantic fields remain byte-identical, and any semantic finding change MUST require another review.
- **FR-061**: Every lifecycle or correction-cycle mutation spanning the workflow ledger and another project file MUST use a persisted write-ahead operation identifier and idempotent recovery protocol; after interruption, the workflow MUST complete or acknowledge an already-written artifact exactly once, MUST NOT increment a revision twice, and MUST stop on any state that matches neither the recorded before-state nor a valid completed write.
- **FR-062**: An ADR accepted after planning MUST stop forward work until the plan owner incorporates the decision, increments the plan revision, and regenerates tasks and independent analysis; an exempt spec-side `related_adrs` update alone MUST NOT allow implementation to continue.

### Key Entities

- **Mutable Maxi artifact**: A per-project constitution, spec, plan, research document, data model, technical contract, task list, or analysis report that may be updated by its owning workflow.
- **Artifact revision**: A positive integer representing the ordered governed writes to one mutable artifact; legacy absence is interpreted as revision 0.
- **Direct dependency**: A mutable input path and exact revision recorded by a derived artifact in `derived_from`.
- **Artifact graph**: The directed graph of mutable artifacts and their direct revision-bound dependencies, plus separate immutable ADR references.
- **Analysis finding**: A persistent issue with a stable identifier, state, severity, owner, location, summary, and recommendation.
- **Correction cycle**: One explicit user-approved rollback, correction, descendant regeneration, and complete re-analysis following a failed final analysis.
- **Review mode**: Evidence that semantic analysis ran with an author-independent reviewer, ran as a provisional self-review, or did not run because deterministic validation failed; only the independent mode may open the implementation gate.
- **Workflow ledger**: A per-spec mutable event record that persists lifecycle, rollback, and correction-cycle events without changing unrelated content-artifact revisions.

## Clarifications

**Q: Can a self-review transition a spec to `analyzed` when the runtime cannot create a fresh reviewer?**
A: No. Independent review is mandatory. A self-review may create a provisional report, but the spec remains `tasked`; runtimes without automatic isolation must provide a handoff for analysis in a separate session.

**Q: What review mode is recorded when deterministic validation fails before semantic review?**
A: `not-run`. It is fail-closed, records no reviewer identity, leaves the spec at `tasked`, and cannot satisfy implementation.

**Q: Which writes increment an artifact revision?**
A: `revision` represents structural content. Body and non-exempt frontmatter changes increment it. The closed operational exemptions are `updated`, `status`, `parked_from`, task completion checkboxes, `related_adrs`, `validated_against`, and `validated_workflow`.

**Q: Does a constitution revision make existing specs and plans stale?**
A: No. Constitution revision is recorded under `validated_against`, not `derived_from`. Active specs rerun constitution alignment at their next phase and update the marker on success; only a real conflict opens a finding. Done and cancelled specs remain unchanged historical records.

**Q: Does updating ADR traceability or constitution validation increment structural revision?**
A: No. `related_adrs`, `validated_against`, and `validated_workflow` are traceability metadata in the closed exemption list. ADR status is checked separately, and a real architectural change increments the plan revision.

**Q: What happens after the correction-cycle limit when the user authorizes more work?**
A: Each new direct decision opens exactly one additional correction and independent re-analysis cycle. Another failure stops again and requires another decision.

**Q: What is the passing result when non-blocking findings are accepted or deferred?**
A: The result is `pass-with-exceptions`. `pass-clean` is reserved for analyses where every finding is resolved.

**Q: What distinguishes `accepted` from `deferred`?**
A: `accepted` preserves an intentional exception with a durable rationale. `deferred` records a real issue and must link to an existing follow-up Maxi spec. Without the required evidence, the finding remains open.

**Q: Must every re-analysis use a different reviewer?**
A: No. Independence means separation from the artifact author. The same independent reviewer is preferred for the second pass in one correction cycle; another independent reviewer may reconcile the existing registry if reuse is unavailable.

**Q: What happens if a correction run is interrupted between ledger and artifact writes?**
A: The workflow resumes the same persisted operation. It either applies an untouched prepared output once, acknowledges an exact completed output without rewriting it, or stops on a conflicting state. It never regenerates blindly or increments a revision twice.

**Q: What happens when implementation discovers an architectural decision?**
A: Implementation stops after the ADR decision is recorded. The plan owner must incorporate it structurally, then tasks and independent analysis replay before implementation may resume; the spec backlink alone is not freshness evidence.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In all analysis fixtures with at least one open blocking finding, 0 specs transition from `tasked` to `analyzed`.
- **SC-002**: For spec-only, plan-only, and task-only mutations, deterministic validation identifies 100% of the expected stale descendants and no unaffected ancestor as stale.
- **SC-003**: For every supported finding owner, the proposed rollback status matches the owning producer's required input status in 100% of behavioral fixtures.
- **SC-004**: Across repeated analysis fixtures, unchanged findings retain their identifiers and every report correctly classifies all findings as new, resolved, or unchanged.
- **SC-005**: After a second consecutive failed final analysis, 0 additional artifact corrections, rollbacks, or regenerations occur without a new direct user decision.
- **SC-006**: Internal context, automatic continuations, persisted goals, silence, and ambiguous acknowledgements authorize 0 rollback writes in consent fixtures.
- **SC-007**: Existing mutable artifacts without revision metadata require no bulk migration and adopt revision 1 only when individually modified by their owning workflow.
- **SC-008**: All ADR fixtures remain revision-free; accepted current references pass, while superseded or deprecated references block without automatic substitution.
- **SC-009**: Implementation rejects 100% of fixtures with absent, failed, stale, self-reviewed, not-run, or undeclared-review-mode analysis despite an `analyzed` spec status.
- **SC-010**: `bash tests/run-all.sh` passes with deterministic coverage for the artifact graph and skill-contract changes.
- **SC-011**: Lifecycle and correction interruption fixtures at authorization, consumption, preparation, status/artifact-write, and phase-completion boundaries produce exactly one intended write per artifact, exactly one structural revision increment when applicable, and no duplicate phase execution.
- **SC-012**: Implementation refuses 100% of fixtures where spec-side ADR references differ from the current plan, including an ADR accepted after analysis, until plan, tasks, and analysis are replayed.

## Assumptions

- Mutable Maxi artifacts are normally modified through their owning skills; silent out-of-band structural edits that do not bump `revision` are unsupported and cannot be detected by revision metadata alone.
- The canonical serialization of `derived_from` and the validator's implementation language are technical plan decisions, provided the representation is deterministic and portable across supported harnesses.
- Direct dependency edges are sufficient because validators traverse the graph for transitive freshness.
- Independent review is mandatory for `analyzed`; runtimes without automatic reviewer isolation must hand off analysis to a separate session, while self-review remains provisional.
- Non-blocking findings may be accepted only with a durable rationale or deferred only with a linked follow-up Maxi spec, and the disposition remains visible in the analysis registry.
- The accepted design document under `docs/superpowers/specs/` is local brainstorming evidence; this spec is the authoritative tracked Maxi artifact.
- Workflow events are operational evidence, not normative requirements; content artifacts depend on their actual content inputs, while `analysis.md` separately validates the canonical correction-event state.
