---
slug: 0010-x-develop
created: 2026-05-30
updated: 2026-05-30
status: done
origin: reverse-engineered
source_sha: 7f945f8a8548bf1b4b123d28cc097e2cca897c68
parked_from: null
---

# Feature Specification: x-develop — Subagent-Driven Implementation Patch Layer

The `x-develop` skill is the internal pipeline skill that `/maxi:implement` delegates to in order to execute a maxi plan via subagent-driven development. It is not a standalone executor: it is a thin patch layer over the vendored `superpowers:subagent-driven-development` skill. It announces the development mode, declares a set of override directives that take precedence over the vanilla skill where they conflict, then loads and follows `superpowers:subagent-driven-development`. The patches close known gaps: fresh-subagent dispatch on every iteration, a hard cap on fix-review cycles, explicit TodoWrite task-state transitions, handling rules for the implementer's `DONE_WITH_CONCERNS` and `NEEDS_CONTEXT` reports, and substitution of an integration reviewer (whole-implementation review) for the per-task code-quality reviewer at the end of the run. A companion `integration-reviewer-prompt.md` template supplies the exact Task-tool prompt for that final review.

## User Scenarios & Testing

### User Story 1 - Execute a maxi plan via subagents (Priority: P1)

**Why this priority**: This is the skill's reason to exist — it is the execution engine `/maxi:implement` delegates to. Without it, a tasked-and-analyzed maxi plan cannot be turned into committed code through the subagent loop.

**Independent Test**: Trigger the skill in an implement-delegation context and confirm it announces the development mode, loads `superpowers:subagent-driven-development` via the Skill tool, and applies the patch directives in preference to the vanilla content.

**Acceptance Scenarios**:
1. **Given** `/maxi:implement` delegates execution of a maxi plan, **When** `x-develop` starts, **Then** it announces "I'm using Subagent-Driven Development to execute this plan."
2. **Given** the skill body has been read, **When** execution begins, **Then** it loads and follows `superpowers:subagent-driven-development` using the Skill tool.
3. **Given** a patch directive conflicts with the vanilla skill content, **When** the two disagree, **Then** the patch directive takes precedence.

### User Story 2 - Fresh implementer per task and per fix iteration (Priority: P1)

**Why this priority**: Reusing a stale subagent silently carries forward prior context and corrupts the implementation loop; this directive is core to correct subagent-driven execution.

**Independent Test**: Run a task that needs a fix iteration and confirm a brand-new implementer subagent is dispatched for the fix, with prior context restated in its prompt rather than assumed.

**Acceptance Scenarios**:
1. **Given** an initial task is ready, **When** dispatching its implementer, **Then** a fresh implementer subagent is dispatched.
2. **Given** a fix iteration is required, **When** re-dispatching, **Then** a fresh implementer subagent is dispatched and context from previous runs is passed explicitly in the prompt.

### User Story 3 - Bounded review loop with escalation (Priority: P1)

**Why this priority**: An unbounded fix-review loop can spin forever on a spec gap; the cap converts repeated disagreement into a human escalation rather than wasted iterations.

**Independent Test**: Simulate three consecutive fix-review cycles from the same reviewer without approval and confirm the skill stops and escalates to the human instead of dispatching a fourth.

**Acceptance Scenarios**:
1. **Given** the same reviewer has rejected three consecutive fix-review cycles without approval, **When** a fourth would begin, **Then** the skill stops and escalates to the human.
2. **Given** persistent disagreement, **When** escalating, **Then** it is treated as a spec gap rather than a fixable implementation error.

### User Story 4 - Explicit task-state transitions in TodoWrite (Priority: P2)

**Why this priority**: Accurate task state is what `/maxi:board` and the controller rely on to know progress; mis-timed transitions misreport completion.

**Independent Test**: Observe TodoWrite around one task and confirm it flips to `in_progress` before the implementer dispatch and to `complete` only after both reviews pass.

**Acceptance Scenarios**:
1. **Given** a task is about to be worked, **When** its implementer subagent is dispatched, **Then** the task is marked `in_progress` in TodoWrite beforehand.
2. **Given** a task's implementer has run, **When** marking it `complete`, **Then** completion occurs only after both reviews pass.

### User Story 5 - Handle implementer concern and context reports (Priority: P2)

**Why this priority**: The implementer can return non-success-but-non-failure statuses; mishandling them either ships unaddressed correctness issues or wrongly aborts recoverable work.

**Independent Test**: Feed the controller a `DONE_WITH_CONCERNS` report and a `NEEDS_CONTEXT` report and confirm each is routed per its rule.

**Acceptance Scenarios**:
1. **Given** an implementer returns `DONE_WITH_CONCERNS`, **When** evaluating before the spec reviewer, **Then** concerns touching correctness or scope are addressed first; otherwise the controller proceeds with a note.
2. **Given** an implementer returns `NEEDS_CONTEXT` mid- or post-task, **When** handling it, **Then** it is treated as a hit information wall (not a failure), the missing context is provided, and the implementer is re-dispatched.

### User Story 6 - Whole-implementation integration review (Priority: P2)

**Why this priority**: Per-task reviews never inspect what crosses task boundaries; the integration review is the only gate that catches inter-task gaps, regressions, and merge readiness.

**Independent Test**: After all tasks complete, confirm the controller uses `integration-reviewer-prompt.md` (not the code-quality reviewer) and supplies a diff range from a previously captured BASE_SHA to current HEAD.

**Acceptance Scenarios**:
1. **Given** all tasks are complete, **When** running the final review, **Then** `./integration-reviewer-prompt.md` is used rather than `./code-quality-reviewer-prompt.md`.
2. **Given** the integration review needs a diff range, **When** it was set up, **Then** BASE_SHA (current HEAD) was captured before dispatching the first implementer subagent and HEAD_SHA is the current HEAD.
3. **Given** the integration reviewer runs, **When** it reports, **Then** it returns either "Ready to merge" or an "Issues" list with file:line references categorised by cross-task consistency, integration, regressions, or merge readiness.

### Edge Cases

- A patch directive and the vanilla skill disagree: the patch wins (SKILL.md:9-10, SKILL.md:37).
- Three failed fix-review cycles from the same reviewer: stop and escalate to human rather than continue (SKILL.md:17-19).
- `DONE_WITH_CONCERNS` whose concerns do not touch correctness or scope: proceed, but with a note (SKILL.md:24-25).
- `NEEDS_CONTEXT` returned after a task appears done: still valid, provide context and re-dispatch — not a terminal failure (SKILL.md:27-28).
- BASE_SHA not captured before the first implementer dispatch: the integration review cannot produce a valid diff range (SKILL.md:32, integration-reviewer-prompt.md:9, integration-reviewer-prompt.md:26-28).

## Requirements

### Functional Requirements

- **FR-001**: The skill MUST announce "I'm using Subagent-Driven Development to execute this plan." at start. (skills/x-develop/SKILL.md:12)
- **FR-002**: The skill MUST always dispatch a fresh implementer subagent for both initial tasks and fix iterations. (skills/x-develop/SKILL.md:14-15)
- **FR-003**: The skill MUST pass context from previous runs explicitly in the subagent prompt rather than relying on retained subagent context. (skills/x-develop/SKILL.md:15)
- **FR-004**: After 3 consecutive fix-review cycles without approval from the same reviewer, the skill MUST stop and escalate to the human. (skills/x-develop/SKILL.md:17-19)
- **FR-005**: The skill MUST treat persistent reviewer disagreement as a spec gap, not a fixable implementation error. (skills/x-develop/SKILL.md:18-19)
- **FR-006**: The skill MUST mark each task `in_progress` in TodoWrite before dispatching its implementer subagent. (skills/x-develop/SKILL.md:21-22)
- **FR-007**: The skill MUST mark a task `complete` only after both reviews pass. (skills/x-develop/SKILL.md:22)
- **FR-008**: On `DONE_WITH_CONCERNS`, before proceeding to the spec reviewer, the skill MUST address concerns that touch correctness or scope first, and otherwise proceed with a note. (skills/x-develop/SKILL.md:24-25)
- **FR-009**: The skill MUST treat `NEEDS_CONTEXT` (mid- or post-task) as a valid non-failure state, provide the missing context, and re-dispatch the implementer. (skills/x-develop/SKILL.md:27-28)
- **FR-010**: After all tasks complete, the skill MUST use `./integration-reviewer-prompt.md` for the whole-implementation review instead of `./code-quality-reviewer-prompt.md`. (skills/x-develop/SKILL.md:30-31)
- **FR-011**: The skill MUST capture BASE_SHA (current HEAD) before dispatching the first implementer subagent. (skills/x-develop/SKILL.md:32, skills/x-develop/integration-reviewer-prompt.md:9)
- **FR-012**: The skill MUST load and follow `superpowers:subagent-driven-development` using the Skill tool, with the patch directives taking precedence where they conflict with the vanilla content. (skills/x-develop/SKILL.md:36-37)
- **FR-013**: The integration review MUST be run once per implementation (after all tasks complete), not per task. (skills/x-develop/integration-reviewer-prompt.md:3)
- **FR-014**: The integration review MUST focus on what crosses task boundaries — cross-task consistency, integration at interfaces, regressions, and merge readiness — since per-task spec compliance and code quality are already reviewed. (skills/x-develop/integration-reviewer-prompt.md:5-7, integration-reviewer-prompt.md:31-45)
- **FR-015**: The integration reviewer MUST be dispatched as a general-purpose Task with a diff range of BASE_SHA to HEAD_SHA. (skills/x-develop/integration-reviewer-prompt.md:12-13, integration-reviewer-prompt.md:26-28)
- **FR-016**: The integration reviewer MUST report either "Ready to merge" or an "Issues" list with file:line references categorised by the review type. (skills/x-develop/integration-reviewer-prompt.md:47-49)

### Key Entities

- **Patch directives**: The ordered set of override rules (announce, fresh subagent, review-loop cap, task state, DONE_WITH_CONCERNS, NEEDS_CONTEXT, integration reviewer) that take precedence over the vanilla skill. (skills/x-develop/SKILL.md:9-32)
- **Vanilla skill**: `superpowers:subagent-driven-development`, loaded and followed after the patches are declared. (skills/x-develop/SKILL.md:36-37)
- **Implementer subagent**: The fresh subagent dispatched per task and per fix iteration to perform the work. (skills/x-develop/SKILL.md:14-15)
- **Reviewer**: The reviewer whose repeated rejections (3 consecutive cycles) trigger escalation; distinct from the integration reviewer. (skills/x-develop/SKILL.md:17-18)
- **Integration reviewer**: A general-purpose Task using `integration-reviewer-prompt.md` for the final whole-implementation merge-readiness review. (skills/x-develop/SKILL.md:30-31, integration-reviewer-prompt.md:11-50)
- **BASE_SHA / HEAD_SHA**: The commit captured before the first implementer dispatch and the current HEAD, bounding the integration review diff range. (skills/x-develop/SKILL.md:32, integration-reviewer-prompt.md:26-28)
- **Implementer report statuses**: `DONE_WITH_CONCERNS` and `NEEDS_CONTEXT`, each with its own controller handling rule. (skills/x-develop/SKILL.md:24-28)

## Success Criteria

### Measurable Outcomes

- **SC-001**: Every task transitions through `in_progress` (before implementer dispatch) and reaches `complete` only after both its reviews pass — 100% of tasks. (skills/x-develop/SKILL.md:21-22)
- **SC-002**: No more than 3 consecutive fix-review cycles run against the same reviewer before a human escalation occurs. (skills/x-develop/SKILL.md:17-19)
- **SC-003**: Every implementer dispatch — initial and fix — uses a freshly created subagent (zero reused subagents). (skills/x-develop/SKILL.md:14-15)
- **SC-004**: Exactly one integration review runs per implementation, after all tasks complete, using the integration-reviewer template and a valid BASE_SHA..HEAD_SHA range. (skills/x-develop/integration-reviewer-prompt.md:3, SKILL.md:30-32)
- **SC-005**: Where any patch directive conflicts with the vanilla skill, the patch behaviour is the one observed at runtime. (skills/x-develop/SKILL.md:9-10, SKILL.md:37)

## Assumptions

- The skill is invoked in the context of `/maxi:implement` delegating execution, or otherwise to execute a maxi plan via subagent-driven development; it is not a user-facing command. (skills/x-develop/SKILL.md:3-4)
- `superpowers:subagent-driven-development` is available via the Skill tool and supplies all behaviour not overridden by the patches. (skills/x-develop/SKILL.md:36-37)
- A `./code-quality-reviewer-prompt.md` exists in the vanilla skill's flow as the per-task reviewer the integration reviewer replaces at the whole-implementation stage; it is referenced but not present in this skill's own directory. (skills/x-develop/SKILL.md:31)
- The implementer protocol defines `DONE_WITH_CONCERNS` and `NEEDS_CONTEXT` as report statuses the controller must interpret. (skills/x-develop/SKILL.md:24-28)
- Git is in use, so a HEAD SHA can be captured before the first implementer dispatch and again at review time. (skills/x-develop/SKILL.md:32, integration-reviewer-prompt.md:26-28)

## Migration Notes

- Reverse-engineered from commit `7f945f8a8548bf1b4b123d28cc097e2cca897c68`.
- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).
- Verified against code by an adversarial pass before acceptance.
