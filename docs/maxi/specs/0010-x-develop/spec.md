---
slug: 0010-x-develop
created: 2026-05-30
updated: 2026-06-21
status: done
origin: reverse-engineered
source_sha: 2d90daada2d8e09404671a77a148edb2d73e7f76
parked_from: null
---

# Feature Specification: x-develop — Subagent-Driven Implementation Patch Layer

The `x-develop` skill is the internal pipeline skill that `/maxi:implement` delegates to in order to execute a maxi plan via subagent-driven development. It is not a standalone executor: it is a thin patch layer over the vendored `superpowers:subagent-driven-development` skill. It announces the development mode, declares a set of override directives that take precedence over the vanilla skill where they conflict, then loads and follows `superpowers:subagent-driven-development`. The vanilla skill now handles implementer status codes (`DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, `BLOCKED`), BASE-commit capture plus `review-package`, the durable progress ledger, and the final whole-branch review natively; the patches address only the gaps it still leaves: fresh-subagent dispatch on every iteration, a hard cap on fix-review cycles, the task-completion gate, and a cross-task emphasis layered onto the vanilla skill's own final review.

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
2. **Given** a fix iteration is required, **When** re-dispatching, **Then** a fresh implementer subagent is dispatched and everything it needs (task brief, reviewer findings, report file) is passed explicitly in the prompt.

### User Story 3 - Bounded review loop with escalation (Priority: P1)

**Why this priority**: An unbounded fix-review loop can spin forever on a spec gap; the cap converts repeated disagreement into a human escalation rather than wasted iterations. The vanilla skill has no such cap, so this is a genuine maxi addition.

**Independent Test**: Simulate three consecutive fix-review cycles on the same task without the task reviewer approving and confirm the skill stops and escalates to the human instead of dispatching a fourth.

**Acceptance Scenarios**:
1. **Given** the task reviewer has rejected three consecutive fix-review cycles on the same task without approving, **When** a fourth would begin, **Then** the skill stops and escalates to the human.
2. **Given** persistent disagreement, **When** escalating, **Then** it is treated as a spec gap rather than a fixable implementation error.

### User Story 4 - Task completion gate (Priority: P2)

**Why this priority**: Accurate task state is what `/maxi:board`, the progress ledger, and the controller rely on to know progress and to survive compaction; a premature `complete` misreports progress or risks re-dispatching finished work.

**Independent Test**: Observe one task's bookkeeping and confirm it is marked `complete` in both the todo list and the progress ledger only after its task review passes (spec compliance AND code quality).

**Acceptance Scenarios**:
1. **Given** a task's implementer has run, **When** marking it `complete`, **Then** completion is recorded in both the todo list and the progress ledger, and only after the task review passes both spec compliance and code quality.
2. **Given** a progress ledger lists a task as complete, **When** resuming after compaction, **Then** that task is treated as done and is not re-dispatched.

### User Story 5 - Cross-task emphasis on the final whole-branch review (Priority: P2)

**Why this priority**: The vanilla skill already runs one final whole-branch review via `superpowers:requesting-code-review`'s `code-reviewer.md`. Per-task reviews never inspect what crosses task boundaries, so the patch directs that final review's attention at the inter-task dimension without replacing the template.

**Independent Test**: After all tasks complete, confirm the controller uses the vanilla `code-reviewer.md` template (no maxi-specific substitute) and that the constraints block it hands the reviewer adds a cross-task emphasis.

**Acceptance Scenarios**:
1. **Given** all tasks are complete, **When** running the final review, **Then** the vanilla `superpowers:requesting-code-review` `code-reviewer.md` template is used as-is, not a maxi-specific reviewer prompt.
2. **Given** the final review is dispatched, **When** its constraints block is composed, **Then** it adds a cross-task emphasis covering cross-task naming/pattern consistency, interface fit between separately-built components, gaps that fall between tasks, and regressions where a later task broke an earlier one's work.
3. **Given** the cross-task emphasis is added, **When** wording it, **Then** it is additive emphasis only and never instructs the reviewer what *not* to flag.

### Edge Cases

- A patch directive and the vanilla skill disagree: the patch wins (SKILL.md:8-9, SKILL.md:39-40).
- Three failed fix-review cycles on the same task: stop and escalate to human rather than continue (SKILL.md:21-23).
- A task review passes only one of spec compliance / code quality: the task is not yet `complete` (SKILL.md:25-26).
- A progress ledger marks a task complete after compaction: trust it, do not re-dispatch (SKILL.md:26-27).
- Implementer status codes (`DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, `BLOCKED`), BASE-commit capture, and the progress ledger are handled by the vanilla skill, not patched here (SKILL.md:9-12).

## Requirements

### Functional Requirements

- **FR-001**: The skill MUST announce "I'm using Subagent-Driven Development to execute this plan." at start. (skills/x-develop/SKILL.md:14)
- **FR-002**: The skill MUST always dispatch a fresh implementer subagent for both initial tasks and fix iterations. (skills/x-develop/SKILL.md:16-17)
- **FR-003**: The skill MUST pass everything a fix subagent needs (task brief, reviewer findings, report file) explicitly in the dispatch rather than relying on retained subagent context. (skills/x-develop/SKILL.md:17-19)
- **FR-004**: After 3 consecutive fix-review cycles on the same task without the task reviewer approving, the skill MUST stop and escalate to the human. (skills/x-develop/SKILL.md:21-22)
- **FR-005**: The skill MUST treat persistent reviewer disagreement as a spec gap, not a fixable implementation error. (skills/x-develop/SKILL.md:22-23)
- **FR-006**: The skill MUST mark a task `complete` in both the todo list and the progress ledger, and only after its task review passes spec compliance AND code quality. (skills/x-develop/SKILL.md:25-26)
- **FR-007**: The skill MUST trust the progress ledger across compaction and never re-dispatch a task the ledger marks complete. (skills/x-develop/SKILL.md:26-27)
- **FR-008**: After all tasks complete, the skill MUST use the vanilla `superpowers:requesting-code-review` `code-reviewer.md` template for the final whole-branch review, not a maxi-specific reviewer prompt. (skills/x-develop/SKILL.md:29-31)
- **FR-009**: The skill MUST add a cross-task emphasis to the final review's constraints block — cross-task consistency, interface fit, between-task gaps, and regressions — as additive emphasis that never tells the reviewer what not to flag. (skills/x-develop/SKILL.md:31-35)
- **FR-010**: The skill MUST defer to the vanilla skill for implementer status codes (`DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, `BLOCKED`), BASE-commit capture plus `review-package`, and the durable progress ledger. (skills/x-develop/SKILL.md:9-12)
- **FR-011**: The skill MUST load and follow `superpowers:subagent-driven-development` using the Skill tool, with the patch directives taking precedence where they conflict with the vanilla content. (skills/x-develop/SKILL.md:39-40)

### Key Entities

- **Patch directives**: The ordered set of override rules (announce, fresh subagent per dispatch, review-loop cap, task-completion gate, final-review cross-task emphasis) that take precedence over the vanilla skill. (skills/x-develop/SKILL.md:8-35)
- **Vanilla skill**: `superpowers:subagent-driven-development`, loaded and followed after the patches are declared; it natively owns status-code handling, BASE capture, the progress ledger, and the final review. (skills/x-develop/SKILL.md:9-12, SKILL.md:39-40)
- **Implementer subagent**: The fresh subagent dispatched per task and per fix iteration to perform the work. (skills/x-develop/SKILL.md:16-19)
- **Task reviewer**: The vanilla per-task reviewer (spec compliance + code quality) whose three consecutive rejections on one task trigger escalation. (skills/x-develop/SKILL.md:21-22)
- **Final whole-branch review**: The vanilla skill's single end-of-run review via `superpowers:requesting-code-review`'s `code-reviewer.md`, to which the patch adds a cross-task emphasis. (skills/x-develop/SKILL.md:29-35)
- **Progress ledger**: The vanilla skill's durable completion record the task-completion gate writes to and trusts across compaction. (skills/x-develop/SKILL.md:25-27)

## Success Criteria

### Measurable Outcomes

- **SC-001**: Every task reaches `complete` — in both the todo list and the progress ledger — only after its task review passes both spec compliance and code quality. 100% of tasks. (skills/x-develop/SKILL.md:25-26)
- **SC-002**: No more than 3 consecutive fix-review cycles run against the same task before a human escalation occurs. (skills/x-develop/SKILL.md:21-22)
- **SC-003**: Every implementer dispatch — initial and fix — uses a freshly created subagent (zero reused subagents). (skills/x-develop/SKILL.md:16-17)
- **SC-004**: Exactly one final whole-branch review runs per implementation, after all tasks complete, using the vanilla `code-reviewer.md` template with a cross-task emphasis added to its constraints block. (skills/x-develop/SKILL.md:29-35)
- **SC-005**: Where any patch directive conflicts with the vanilla skill, the patch behaviour is the one observed at runtime. (skills/x-develop/SKILL.md:8-9, SKILL.md:40)

## Assumptions

- The skill is invoked in the context of `/maxi:implement` delegating execution, or otherwise to execute a maxi plan via subagent-driven development; it is not a user-facing command. (skills/x-develop/SKILL.md:3)
- `superpowers:subagent-driven-development` is available via the Skill tool and supplies all behaviour not overridden by the patches, including status-code handling, BASE capture, `review-package`, the progress ledger, and the final whole-branch review. (skills/x-develop/SKILL.md:9-12, SKILL.md:39-40)
- `superpowers:requesting-code-review` is available and supplies the `code-reviewer.md` template used for the final review. (skills/x-develop/SKILL.md:29-30)
- Git is in use, so the vanilla skill can capture a BASE commit and produce a review package for the final review. (skills/x-develop/SKILL.md:9-11)

## Migration Notes

- Originally reverse-engineered from commit `7f945f8a8548bf1b4b123d28cc097e2cca897c68`; re-derived on 2026-06-21 against commit `2d90daa` (the x-develop rework accompanying the superpowers v6.0.3 bump). `source_sha` now points to that re-derivation commit.
- The v6.0.3 vanilla `subagent-driven-development` absorbed four prior patches (implementer status-code handling, BASE/`review-package` capture, the progress ledger, and a native final whole-branch review). Those directives were removed from `x-develop`; the integration-reviewer substitution and its `integration-reviewer-prompt.md` template were dropped in favour of the vanilla `code-reviewer.md` with a cross-task emphasis. See the evaluation that drove this: the vanilla reviewer wins on rigour, severity grading, read-only safety, and controller wiring, and maxi's only edge (cross-task scoping) survives as an attention lens.
- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).
- Verified against code by an adversarial pass before acceptance.
