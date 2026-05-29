---
slug: 0003-constitution-adr-boundary-guard
created: 2026-05-29
updated: 2026-05-29
status: done
# Allowed values: drafting | specified | clarified | planned | tasked | analyzed | implementing | done | parked | cancelled
parked_from: null
# parked_from: set by /maxi:park to the pre-park status; cleared to null by /maxi:resume
---

# Feature Specification: Constitution/ADR Boundary Guard

The boundary between the **constitution** (durable project principles) and **ADRs** (specific architectural decisions) is conceptually clean across the maxi skills, but the guardrails that keep them apart are weak in exactly one place: authoring a constitution. The `constitution` skill never tells the author (or Claude) that a concrete, contestable, reversible technology *choice* belongs in an ADR rather than as a Core Principle — and the constitution template's example comments actively model decision-shaped content as principles. This feature adds the missing guard to the skill and tightens the template, so decisions get redirected to `/maxi:adr` instead of silently landing in the constitution.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Decision-shaped content is redirected to ADR during constitution authoring (Priority: P1)

When an author (or Claude running `/maxi:constitution`) is about to record something concrete and contestable — "we use PostgreSQL", "deploy on Vercel", "MAJOR.MINOR.BUILD versioning" — as a Core Principle, the skill recognizes it as an architectural *decision*, not a principle, and steers it to `/maxi:adr`. The constitution captures the underlying invariant instead.

**Why this priority**: This is the core gap. Without it, the constitution accumulates decisions that later go stale, duplicate ADRs, and pollute `/maxi:analyze`'s principle-based audit passes. Everything else in this spec supports this behavior.

**Independent Test**: Read `skills/constitution/SKILL.md` after the change and confirm a Critical Rule states the principle-vs-decision litmus test and instructs redirecting decisions to `/maxi:adr`, plus a matching Red Flag entry with a corrective action. Demonstrable by classifying the canonical example pair with no ambiguity.

**Acceptance Scenarios**:

1. **Given** the constitution skill, **When** a reader looks for guidance on a concrete tech choice, **Then** an explicit rule says that choice belongs in an ADR, not a Core Principle, and names `/maxi:adr` as the redirect target.
2. **Given** the litmus test, **When** classifying "Every storage choice must be justified against durability needs" vs "We use PostgreSQL", **Then** the first is a principle and the second is an ADR-bound decision.
3. **Given** an externally-imposed requirement with no real alternative (e.g. "must run on AWS GovCloud for compliance"), **When** applying the litmus test, **Then** it is treated as a legitimate Constraint that stays in the constitution — not redirected — because it is not contestable.

---

### User Story 2 - Constitution template stops modeling decisions as principles (Priority: P2)

An author copying `templates/constitution-template.md` sees example comments that illustrate *principles* and *constraints*, not concrete technology decisions. The versioning example no longer encodes a specific format, and the constraints-section example shows constraint-shaped content (forbidden/locked-in dependencies, compliance) with a note that concrete tech choices belong in ADRs.

**Why this priority**: The skill instructs authors to follow the template's structure, so a template that models decisions-as-principles undercuts the US1 guard. Important, but secondary to the skill rule itself.

**Independent Test**: Read `templates/constitution-template.md` and confirm the versioning example comment no longer contains a concrete format like `MAJOR.MINOR.BUILD`, and the constraints-section example comment presents constraint-shaped content plus an ADR redirect note.

**Acceptance Scenarios**:

1. **Given** the template, **When** reading the principle example comment that previously said `MAJOR.MINOR.BUILD format`, **Then** it shows a principle-shaped versioning example with no specific format decision.
2. **Given** the template, **When** reading the constraints-section example comment, **Then** it lists constraint-type examples (forbidden/locked-in dependencies, compliance standards) and notes that concrete technology *choices* belong in ADRs.

---

### User Story 3 - The guard fires proactively during elicitation, not only on review (Priority: P3)

While running the Elicitation Protocol Q&A, if an author's answer names a specific technology or a reversible choice, the skill notes that it belongs in an ADR and steers the principle toward the underlying invariant — catching the confusion at the moment it happens rather than after the constitution is written.

**Why this priority**: Improves the experience and catches confusion earlier, but the post-hoc Critical Rule + Red Flag from US1 already prevent the bad outcome. Nice to have.

**Independent Test**: Read the Elicitation Protocol section of `skills/constitution/SKILL.md` and confirm a one-line nudge instructs the skill to flag technology-specific/reversible answers and redirect them toward the invariant.

**Acceptance Scenarios**:

1. **Given** the Elicitation Protocol, **When** an elicited answer names a specific technology, **Then** the skill is instructed to note it belongs in an ADR and ask for the underlying invariant instead.

---

### Edge Cases

- **Constraint vs decision**: An externally-imposed requirement with no viable alternative (compliance-mandated platform, legally-required retention) is a Constraint and stays in the constitution. The litmus test's "contestable (real alternatives exist)" clause is what separates it from a free decision — the guard must not over-redirect legitimate constraints.
- **Locked-in / forbidden dependencies**: The constitution skill already lists these as valid Constraints. The guard must remain compatible — "no GPL dependencies" is a constraint, while "use library X among several viable options" is a decision.
- **Constitution amendment recording a project-wide rule**: Amendments still generate an ADR (existing Governance rule, unchanged). The guard does not alter the amendment→ADR flow.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `skills/constitution/SKILL.md` MUST include a Critical Rule defining the principle-vs-decision litmus test: content that names a specific technology, is contestable (real alternatives exist), or could be reversed by a later choice is an architectural *decision*; content that is a durable invariant constraining all future decisions is a *principle*.
- **FR-002**: The same Critical Rule MUST instruct redirecting decision-shaped content to `/maxi:adr` rather than recording it as a Core Principle.
- **FR-003**: `skills/constitution/SKILL.md` MUST include a Red Flag entry for writing a concrete technology/tool choice as a Core Principle, paired with a corrective action that redirects to `/maxi:adr`.
- **FR-004**: The litmus test and Red Flag MUST include at least one concrete contrasting example pair — a principle (e.g. "every storage choice must be justified against durability needs") versus an ADR-bound decision (e.g. "we use PostgreSQL").
- **FR-005**: The Elicitation Protocol in `skills/constitution/SKILL.md` MUST include a nudge: when an elicited answer names a specific technology or a reversible choice, note that it belongs in an ADR and steer the principle toward the underlying invariant.
- **FR-006**: `templates/constitution-template.md` MUST replace the `MAJOR.MINOR.BUILD format` versioning example with a principle-shaped example that encodes no specific version format.
- **FR-007**: `templates/constitution-template.md` constraints-section example comment MUST present constraint-shaped examples (forbidden/locked-in dependencies, compliance standards, deployment policies) and note that concrete technology *choices* belong in ADRs.
- **FR-008**: The template edits MUST leave all section headers unchanged so that `tests/fast/check-templates.sh` continues to pass; only example comments may change.
- **FR-009**: The change MUST NOT modify any skill other than `constitution`, MUST NOT add a new shared reference file, and MUST NOT alter the pipeline FSM, statuses, or phase transitions — so no `docs/pipeline-flow.md` / `docs/delegation-map.md` / `using-maxi` / `CLAUDE.md` pipeline-doc-sync obligation is triggered.

## Clarifications

_`/maxi:clarify` scan (2026-05-29): no open questions. The only candidate ambiguity — constraint vs. decision — was already resolved in-spec via the "contestable (real alternatives exist)" clause (see US1 Acceptance Scenario 3, Edge Cases, and Assumptions). No `[NEEDS CLARIFICATION]` markers, no vague blocking requirements._

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A reader of `skills/constitution/SKILL.md` can locate an explicit statement that concrete architectural decisions belong in ADRs, not Core Principles — guidance that is absent before this change.
- **SC-002**: Using only the litmus test in the skill, the canonical example pair ("storage choice must be justified" = principle; "we use PostgreSQL" = decision/ADR) is classified correctly and unambiguously.
- **SC-003**: `bash tests/run-all.sh` (fast tier) passes after the changes, including `check-templates.sh` and `check-frontmatter.sh`.
- **SC-004**: No files outside `skills/constitution/SKILL.md` and `templates/constitution-template.md` are modified by this change.

## Assumptions

- The constitution/ADR boundary is conceptually correct elsewhere in the pipeline (adr, plan, analyze skills); only the constitution-authoring guardrails are weak. The fix targets authoring, not the broader model.
- The amendment→ADR Governance rule and the ADR "decision drivers derive from principles" relationship are intentional and not circular; they are out of scope for this change.
- `templates/constitution-template.md` is a maxi-native template (not vendored), so editing its example comments is permitted.
- The "contestable (real alternatives exist)" clause is sufficient to distinguish a free decision (→ ADR) from an externally-imposed constraint (→ constitution); no separate constraint-classification mechanism is needed.
