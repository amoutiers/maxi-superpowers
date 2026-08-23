---
slug: 0022-durable-global-constraints
created: 2026-08-23
updated: 2026-08-23
status: done
parked_from: null
related_adrs: []
---

# Feature Specification: Durable Global Constraints

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Preserve Durable Delivery Constraints (Priority: P1)

As a Maxi user, I want every implementation plan to preserve the durable
cross-task constraints established by the specification and constitution, so
implementation workers can follow them without reconstructing the goal from
chat history.

**Why this priority**: Durable artifact context is the smallest change that
prevents scope, safety, verification, compatibility, and handoff requirements
from being lost between planning and implementation.

**Independent Test**: Create a plan from a clarified fixture whose spec defines
scope limits, protected artifacts, verification evidence, a compatibility
handoff, and a reporting expectation; verify that the existing `Global
Constraints` section preserves every applicable constraint.

**Acceptance Scenarios**:

1. **Given** a clarified spec and constitution with durable cross-task constraints, **When** `/maxi:plan` writes the implementation plan, **Then** one `Global Constraints` section records every applicable constraint.
2. **Given** a durable requirement that applies to every implementation task, **When** tasks are projected for execution, **Then** the existing projection flow carries the `Global Constraints` section without a second contract or state mechanism.
3. **Given** no additional durable cross-task constraint, **When** `/maxi:plan` writes the plan, **Then** the section explicitly states that no additional global constraints apply instead of inventing one.

---

### User Story 2 - Keep Temporary Authority Out of Durable Artifacts (Priority: P1)

As a Maxi user, I want temporary execution context and one-time permissions to
remain outside the durable plan contract, so a later worker cannot mistake old
state or consent for current authorization.

**Why this priority**: Persisting an old worktree, commit, task selection, or
permission as a durable rule creates both stale-state failures and unsafe
authorization transfer.

**Independent Test**: Plan a fixture containing durable compatibility
requirements alongside a current checkout, HEAD, selected task, stop point,
and one-time mutation permission; verify that only the durable requirements
enter `Global Constraints`.

**Acceptance Scenarios**:

1. **Given** planning context containing a current worktree, HEAD, task selection, or stop point, **When** `/maxi:plan` classifies constraints, **Then** those transient values are excluded from `Global Constraints`.
2. **Given** a prior permission to commit, push, publish a pull request, deploy, publish data, or retrieve secrets, **When** the plan is written or reviewed, **Then** that permission is not persisted as authorization for a later action or session.
3. **Given** a durable rule that an external mutation always requires fresh consent, **When** `/maxi:plan` writes the plan, **Then** the rule may be preserved while any individual grant remains excluded.

---

### User Story 3 - Reject an Incomplete Durable Contract Before Tasks (Priority: P2)

As a Maxi user, I want the existing design review to reject a plan that loses
or contradicts a durable constraint, so task extraction cannot proceed from an
incomplete contract.

**Why this priority**: The current exact-byte design-review boundary already
owns requirement, safety, and verification coverage; extending that boundary
avoids another phase or reviewer.

**Independent Test**: Review one complete spec-plan fixture, one plan that
omits a durable constraint, and one plan that carries a stale permission;
verify that only the complete fixture is approved.

**Acceptance Scenarios**:

1. **Given** a spec-plan pair with complete and consistent durable constraints, **When** `/maxi:review` runs, **Then** the existing design reviewer may approve it without a new verdict type.
2. **Given** a plan that omits or contradicts an applicable durable constraint from the spec or constitution, **When** `/maxi:review` runs, **Then** it returns a blocking finding under the existing design-review predicate.
3. **Given** a plan that presents prior consent as continuing authority, **When** `/maxi:review` runs, **Then** it rejects the unsafe design before `/maxi:tasks` can write.

### Edge Cases

- A constraint applies to only one executable task; it remains in that task
  rather than being promoted to `Global Constraints`.
- A required external repository and compatible revision are durable, while a
  local checkout path and its current HEAD are transient.
- The constitution permanently requires fresh approval for an action; that
  authorization rule is durable, but a specific approval is not.
- A plan is structurally corrected after its original review; the corrected
  plan uses the same `Global Constraints` contract and requires the existing
  explicit `/maxi:review` command before task extraction.
- A historical completed plan lacks the clarified contract; it remains
  unchanged until an owning workflow explicitly rewrites that plan.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Maxi plan template MUST contain exactly one `Global Constraints` section using the existing section name rather than introducing a separate delivery-contract artifact or section.
- **FR-002**: `/maxi:plan` MUST populate `Global Constraints` as a simple bullet list containing only the applicable durable cross-task constraints derived from the current spec and constitution, including scope boundaries, protected artifacts or data, required verification evidence, compatibility or integration handoffs, and completion or reporting expectations. It MUST NOT add fixed category labels or per-category `None` entries.
- **FR-003**: When none of the FR-002 categories adds a durable cross-task constraint beyond the remaining plan, `/maxi:plan` MUST include one explicit bullet stating that no additional global constraints apply; it MUST NOT invent constraints or leave an unresolved placeholder.
- **FR-004**: `Global Constraints` MUST NOT persist a current worktree path, current HEAD, selected task set, current stop point, or an individual authorization in any of these categories: Git-history mutation, remote-repository mutation, deployment or infrastructure mutation, data publication, or secret access. Named examples include commit, push, pull-request publication, deployment, infrastructure apply, data publication, and secret retrieval. The categories are authoritative rather than the example list. A durable rule requiring fresh authorization remains allowed.
- **FR-005**: `/maxi:review` MUST continue to evaluate an omitted or contradictory durable cross-task constraint, and any persisted individual mutation authority, through its existing requirement-coverage, extra-behavior, safety-control, and terminal-verdict contract; this feature MUST NOT add or change a blocking predicate or verdict.
- **FR-006**: The change MUST preserve the current fixed review boundaries, ten-state FSM, exact-byte review record, task-extraction gate, readiness analysis, upstream SDD ownership, projection format, ledger format, resume behavior, and terminal receipt contract.
- **FR-007**: The change MUST add no skill, command, status, runtime artifact, dependency, ledger record, replay marker, automatic review, or automatic successor phase.
- **FR-008**: Existing plan files MUST remain byte-unchanged unless an owning Maxi workflow explicitly creates or structurally corrects them; the clarified contract applies forward to newly written plan bytes.
- **FR-009**: Vendored Superpowers skills MUST remain byte-identical to `vendor/superpowers/skills/`; implementation MUST adapt Maxi-owned planning and review surfaces instead of editing the vendored `writing-plans` skill.
- **FR-010**: Any changed plan or review contract MUST be reflected in deterministic fast-tier checks and the Mandatory Sync 5 documentation set required by the repository guidelines.

### Key Entities

- **Durable Global Constraint**: A spec- or constitution-derived rule that
  applies across implementation tasks and remains valid across sessions.
- **Transient Execution Context**: A current checkout, commit, task selection,
  stop point, or individual permission whose validity is limited to an
  execution state or authorization boundary.

## Clarifications

**Q: How should `Global Constraints` represent the five durable constraint categories?**
A: Use a simple bullet list containing only applicable constraints. Do not add five fixed labels or category-specific `None` entries. When no additional global constraint applies, include one explicit bullet saying so.

**Q: Is the prohibition on persisting individual mutation authority limited to a closed list of named actions?**
A: No. It covers five durable categories: Git-history mutation, remote-repository mutation, deployment or infrastructure mutation, data publication, and secret access. Named commands and actions are examples of those categories, not an exhaustive list.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A deterministic template and instruction check confirms that newly written plans contain exactly one `Global Constraints` section and no second delivery-contract section.
- **SC-002**: A fixture covering all five FR-002 categories preserves every applicable constraint, while a no-additional-constraint fixture contains no placeholder or invented rule.
- **SC-003**: Deterministic contract checks confirm that the existing design reviewer retains requirement-omission, extra-behavior, and safety-control coverage for the new plan content without adding a blocking predicate or verdict.
- **SC-004**: Repository checks confirm that skill count, FSM statuses, review boundaries, projection and ledger contracts, runtime artifact inventory, and dependency inventory remain unchanged.
- **SC-005**: `bash tests/run-all.sh` exits 0 after implementation.

## Assumptions

- Durable delivery constraints are expressed in the current spec or
  constitution before planning; `/maxi:plan` classifies and preserves them but
  does not invent product or operational policy.
- The existing Superpowers `writing-plans` output already defines `Global
  Constraints`, and the current x-develop projection already carries that
  section to upstream SDD.
- The existing `/maxi:review` exact-byte record and `/maxi:tasks` stale-review
  gate remain sufficient to prevent task extraction from an unapproved plan.
- The existing `/maxi:implement` and `/maxi:x-develop` recovery flow remains
  the sole implementation-resume mechanism.
- No ADR is expected because the feature preserves existing ownership,
  review predicates, review boundaries, state transitions, and the
  Maxi-to-Superpowers relationship; planning must still propose one if it
  reveals a consequential architectural choice or gating-rule change.
