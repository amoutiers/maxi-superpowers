---
slug: 0026-git-closure
created: 2026-09-26
updated: 2026-09-26
status: implementing
design_cycle: 0
parked_from: null
related_adrs:
  - 0005-superpowers-vendoring-git-subtree
  - 0008-session-start-injection-gated-on-docs-maxi
  - 0021-align-superpowers-v6-3-model
  - 0029-convergent-design-workflow
---

# Feature Specification: Explicit Git Closure

## User Scenarios & Testing

### User Story 1: A finished local batch has an explicit outcome (Priority: P1)

As a plugin user, I need completed local work to reach an integration decision without adding closure instructions to my repository or personal configuration.

**Why this priority:** NavRouteEdge sessions repeatedly ended at committed and tested work while leaving its branch outcome implicit.

**Independent Test:** Load the installed plugin in an isolated Git fixture without a client AGENTS.md, finish a verified local maintenance batch, and inspect both the response and repository state.

**Acceptance Scenarios:**

1. **Given** a ready batch without integration authorization, **When** its owner concludes, **Then** it presents the applicable integration decision and preserves target refs.
2. **Given** a complete Maxi implementation, **When** the valid terminal receipt has been consumed, all tasks checked and done persisted, **Then** implement delegates branch finishing once and reports its Git outcome.

### User Story 2: Repository owners retain authority (Priority: P1)

As a repository owner, I need my instructions and operation permissions to govern the plugin without rewriting my AGENTS.md.

**Why this priority:** A shared plugin cannot require uniform customer policies.

**Independent Test:** Run fixtures with no policy, an explicit merge prohibition, applicable merge authorization, and authorization for a different batch.

**Acceptance Scenarios:**

1. **Given** a local prohibition, **When** ready work is reported, **Then** the prohibition remains intact and no prohibited mutation occurs.
2. **Given** explicit authorization for the exact batch and operation with passing gates, **When** finishing runs, **Then** it uses that authorization without asking the same question again.
3. **Given** permission for another batch or only local integration, **When** concluding this batch, **Then** the plugin does not extend that permission to this batch, a push, or publication.

### User Story 3: External waiting and local blockers stay distinct (Priority: P1)

As a maintainer, I need an independent operational wait to leave the local integration decision visible, while actual requirements continue blocking completion.

**Why this priority:** A broad acceptance register can otherwise hide locally ready work indefinitely.

**Independent Test:** Compare a ready maintenance batch awaiting independent deployment acceptance with an incomplete Maxi implementation and failing local verification.

**Acceptance Scenarios:**

1. **Given** independently outstanding operational acceptance and a locally ready authorized maintenance scope, **When** reporting the wait, **Then** its owner still evaluates local Git closure.
2. **Given** missing review, failing tests, incomplete tasks, stale readiness or invalid terminal evidence, **When** closure is considered, **Then** the blocker is named and neither integration nor fabricated done occurs.
3. **Given** an unmet requirement inside the current spec, **When** a smaller portion is ready, **Then** closure does not silently remove that requirement or finish the partial spec.

### User Story 4: One owner carries the decision across resume (Priority: P2)

As a coordinator, I need one integration decision and a preserved deliberate deferral.

**Why this priority:** Parallel sessions and repeated prompts obscure accountability.

**Independent Test:** Exercise a named coordinator and an unchanged resume after an explicit keep decision.

**Acceptance Scenarios:**

1. **Given** an explicitly named coordinator, **When** a participant completes its batch, **Then** it reports readiness to the authorized workflow without issuing a second integration decision or messaging another chat without authorization.
2. **Given** an explicit keep decision and its resume condition in existing work tracking, **When** the unchanged batch resumes, **Then** that decision is reported without repeating the same question.

### User Story 5: Finishing preserves work and evidence (Priority: P1)

As a developer, I need branch finishing to reflect actual checkout capabilities and preserve useful work.

**Why this priority:** Closing a session must not lose worktrees, concurrent changes, or unique ignored evidence.

**Independent Test:** Exercise detached checkout, a shared or in-use worktree, ignored unique evidence, and a merge result whose combined tests fail.

**Acceptance Scenarios:**

1. **Given** a detached checkout or an in-use worktree, **When** finishing runs, **Then** choices fit the actual environment and necessary work remains available.
2. **Given** ignored unique evidence, **When** cleanup is considered, **Then** it is preserved before archival or cleanup is deferred.
3. **Given** authorized local integration whose combined verification fails, **When** reporting the result, **Then** the failure and actual refs are reported, work is preserved, and no push or successful closure is claimed.

### Edge Cases

- No plugin loaded: outside scope, no claim of global enforcement.
- No pending Git work: report the verified state without manufacturing a merge decision.
- Detached HEAD: use the existing finishing skill's supported choices.
- An explicit keep decision is not a new Maxi status and does not authorize later mutations.
- Unknown CLI event schema, timeout, incomplete context or missing installed-skill read evidence: test failure, never behavioral success.

## Requirements

### Functional Requirements

- **FR-001:** The installed plugin MUST provide the closure trigger and required Git outcome without depending on customer or personal AGENTS.md changes.
- **FR-002:** The current chat MUST own closure unless an explicit coordinator already owns it. Responsibility alone MUST NOT authorize cross-chat messaging.
- **FR-003:** At a completed local batch or an external wait, the owner MUST evaluate exact scope and applicable evidence and report one outcome: integrated, awaiting decision, deliberately retained, or blocked with its reason and next action.
- **FR-004:** The normal Maxi path MUST retain current readiness, task, review and receipt gates. Implement alone persists done and delegates finishing only after that write; x-develop MUST retain its current return boundary. A partial spec MUST NOT be treated as complete.
- **FR-005:** Explicitly authorized maintenance outside the normal Maxi pipeline MUST use its own bounded scope and required tests/review. An unrelated operational wait MUST NOT stand in for a local readiness decision, and this exception MUST NOT be inferred from a partially completed Maxi spec.
- **FR-006:** Finishing MUST reuse Superpowers' existing skill and applicable user authorization. It MUST respect differing local rules, keep local integration distinct from push/publication, and avoid duplicate decisions after an unchanged explicit deferral.
- **FR-007:** Existing work tracking MUST retain a deliberate keep decision and its resume condition. No new delivery ledger, policy file, skill, hook, service or pipeline status may be introduced.
- **FR-008:** Finishing MUST preserve concurrent or in-use work and useful ignored evidence, use native lifecycle tools when available, and report actual verification failures without pretending successful integration.
- **FR-009:** Integration tests MUST use isolated installed-plugin snapshots and external Git fixtures without personal closure instructions, verify real skill-read evidence and Git effects independently of agent prose, and reject incomplete runs. Prompts MUST request normal work completion without explicitly soliciting a merge menu.
- **FR-010:** The change MUST retain 19 native skills, ten statuses, byte-identical vendored skills, existing final-review ownership, and synchronized pipeline documentation.

### Key Entities

- **Local batch:** The exact user-authorized scope and its required verification, within a full Maxi spec or explicitly authorized maintenance.
- **Closure outcome:** The reported Git disposition, branch/worktree identity, evidence or blocker, and next action. It is not a pipeline status.
- **Closure owner:** The current chat or the explicitly designated integration coordinator.

## Clarifications

- Clarification scan on 2026-09-26 found no unresolved product decision. Prior user approval and the customer-policy correction supply the required scope.

- The approved design places the mechanism in the plugin. Customer AGENTS.md contents remain user-owned and unchanged.
- The existing Maxi implementation gates and Superpowers finishing owner remain authoritative.
- An operational wait is independent only when it is not a required acceptance condition of this local batch.

## Success Criteria

### Measurable Outcomes

- **SC-001:** A no-client-policy fixture produces an explicit integration decision with unchanged target refs when authorization is absent.
- **SC-002:** Local-policy, exact-authorization and other-scope-authorization cases all preserve their respective authority boundaries without customer-file edits.
- **SC-003:** Independent waits retain a local outcome; each actual blocker prevents integration and fabricated done.
- **SC-004:** Coordinator and unchanged-deferral cases produce no duplicate decision or unauthorized message.
- **SC-005:** Detached, in-use, ignored-evidence and combined-test-failure cases preserve the asserted work and show truthful outcomes.
- **SC-006:** Fast-tier tests and installed behavioral cases pass for the candidate; baseline observations and limitations are recorded separately, including any baseline cases already passing.

## Assumptions

- The plugin has been loaded through the existing harness mechanism.
- Required user decisions can remain pending; completing implementation does not grant integration or publication authority.
- Existing Git, Bash, Python, jq and Codex integration tooling suffice. No new dependency is needed.
