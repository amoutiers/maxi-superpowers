---
slug: 0014-constitution
created: 2026-05-30
updated: 2026-05-30
status: done
origin: reverse-engineered
source_sha: 7f945f8a8548bf1b4b123d28cc097e2cca897c68
parked_from: null
---

# Feature Specification: Project Constitution Command

The `constitution` skill establishes or amends a project's constitution — the set of non-negotiable principles, development conventions, and constraints that every downstream `/maxi:*` workflow skill checks against. It is the mandatory first step of the maxi pipeline: until `docs/maxi/constitution.md` exists, all other workflow skills refuse to run. The skill operates by elicitation (interactive Q&A with the user), never by inferring principles from existing files or source code, and it enforces a strict boundary between durable *principles/constraints* (which belong in the constitution) and contestable *architectural decisions* (which are routed to ADRs captured later via `/maxi:x-adr` during planning/implementation).

## User Scenarios & Testing

### User Story 1 - Create a new constitution (Priority: P1)

A user starting a maxi project invokes `/maxi:constitution`. No constitution exists yet, so the skill copies the bundled template into the canonical path and walks the user through eliciting 3–7 principles, then writes the result.

**Why this priority**: This is the gateway to the entire pipeline. Without it, every other workflow skill is blocked. It is the single most-exercised path of the skill.

**Independent Test**: In a project with no `docs/maxi/constitution.md`, invoke the skill; verify the template is copied first, elicitation questions are asked, and a populated `docs/maxi/constitution.md` exists afterward with `version: 1.0.0` and today's `created`/`updated` dates.

**Acceptance Scenarios**:
1. **Given** `docs/maxi/constitution.md` does not exist, **When** the skill runs, **Then** it copies `constitution-template.md` into `docs/maxi/constitution.md` before writing any content, then proceeds to elicitation.
2. **Given** a new constitution is being created, **When** elicitation completes, **Then** the YAML frontmatter is set to `version: 1.0.0`, `created: [today]`, `updated: [today]`.
3. **Given** the constitution has just been written, **When** the skill finishes, **Then** it verifies the file exists at `docs/maxi/constitution.md` and tells the user they are ready for `/maxi:specify`.

### User Story 2 - Amend an existing constitution (Priority: P2)

A user invokes the skill in a project that already has a constitution. The skill loads it, shows the current principles, and asks whether to amend or confirm.

**Why this priority**: Constitutions evolve. The amend path is needed but secondary to first creation.

**Acceptance Scenarios**:
1. **Given** `docs/maxi/constitution.md` exists, **When** the skill runs, **Then** it loads the existing file, shows its principles, and asks "Amend or confirm?".
2. **Given** the user chooses to amend, **When** the update is written, **Then** the version is bumped (MAJOR.MINOR.PATCH) and `updated` is set to today.
3. **Given** the user chooses to confirm (no changes), **When** the skill finishes, **Then** it tells the user they are ready for `/maxi:specify` without rewriting principles.

### User Story 3 - Elicitation-only authoring with boundary enforcement (Priority: P1)

During elicitation, the user offers a candidate that is actually an architectural decision (names a specific technology or is reversible). The skill recognizes it and steers it toward the underlying invariant, noting the concrete choice is destined for an ADR.

**Why this priority**: The constitution/ADR boundary guard is the defining behavior that keeps the constitution actionable for `/maxi:analyze`. Conflating decisions with principles corrupts the whole pipeline.

**Independent Test**: During elicitation, offer "We use PostgreSQL"; verify the skill does not write it as a Core Principle but instead routes it as an ADR-worthy decision and reframes toward an invariant (e.g. "every storage choice must be justified against data-durability needs").

**Acceptance Scenarios**:
1. **Given** an elicitation answer names a specific technology or a reversible choice, **When** the skill processes it, **Then** it notes the item is an architectural decision for an ADR (captured later via `/maxi:x-adr`) and steers the principle toward the underlying invariant instead.
2. **Given** a dependency mandated or banned with no real alternative, **When** classified, **Then** it is recorded as a Constraint in the constitution (not routed to an ADR).
3. **Given** a dependency chosen among viable options, **When** classified, **Then** it is treated as a decision destined for an ADR, not the constitution.

### User Story 4 - Refusal to infer from existing files (Priority: P1)

The user is in a hurry and asks the skill to "just use my CLAUDE.md" or "infer from the codebase" or "use reasonable defaults". The skill refuses to skip elicitation.

**Why this priority**: The integrity of the constitution depends on it reflecting the user's *stated values*, not observed code. This guard is invoked on every shortcut attempt.

**Acceptance Scenarios**:
1. **Given** the user says they are in a hurry or to use reasonable defaults, **When** the skill runs, **Then** it asks the elicitation questions anyway — elicitation is never optional.
2. **Given** the user points to `CLAUDE.md` or another existing file, **When** the skill runs, **Then** it explains the constitution must follow the template format and be verified through elicitation, and never copies that file's content verbatim.
3. **Given** the user asks to infer principles from source files or commit history, **When** the skill runs, **Then** it refuses and elicits from the user's stated values instead.

### Edge Cases

- **Constitution already exists** → the skill does not blindly overwrite; it loads the existing file and offers amend-or-confirm. Amending bumps the version and updates the date.
- **ADR-worthy content offered as a principle** → rejected by the boundary guard. A concrete tech/tool choice ("we use PostgreSQL", "deploy on Vercel", "MAJOR.MINOR.BUILD versioning") is not written as a Core Principle; the underlying invariant is recorded instead and the choice is flagged for an ADR.
- **Template missing** → if `constitution-template.md` is not found, the skill stops with "Cannot proceed — `constitution-template.md` is missing. Please reinstall the maxi plugin."
- **Wrong write path** → writing anywhere other than `docs/maxi/constitution.md` is treated as an error to redo.
- **Too few / too many principles** → fewer than 3 is incomplete; more than 7 must be consolidated to 7 maximum.
- **Mixed categories** → conventions, constraints, and core principles mixed in the same section must be separated.

## Requirements

### Functional Requirements

- **FR-001**: The constitution MUST be written to exactly `<project-root>/docs/maxi/constitution.md`; no other path is permitted (skills/constitution/SKILL.md:16, skills/constitution/SKILL.md:19).
- **FR-002**: The constitution MUST be the mandatory first step — all other maxi workflow skills refuse to run until `docs/maxi/constitution.md` exists (skills/constitution/SKILL.md:10).
- **FR-003**: When the constitution file already exists, the system MUST load it, show its principles, and ask whether to amend or confirm rather than overwrite (skills/constitution/SKILL.md:34, skills/constitution/SKILL.md:36, skills/constitution/SKILL.md:37, skills/constitution/SKILL.md:38).
- **FR-004**: When the constitution file is missing, the system MUST copy `constitution-template.md` into `docs/maxi/constitution.md` before writing any content, then elicit principles (skills/constitution/SKILL.md:35, skills/constitution/SKILL.md:39, skills/constitution/SKILL.md:67).
- **FR-005**: Before copying the template, the system MUST verify `constitution-template.md` exists, and if missing MUST stop with the reinstall message (skills/constitution/SKILL.md:66).
- **FR-006**: The system MUST elicit principles via one-question-at-a-time Q&A, producing between 3 and 7 principles (skills/constitution/SKILL.md:48, skills/constitution/SKILL.md:77).
- **FR-007**: For a newly created constitution, the system MUST set frontmatter `version: 1.0.0`, `created: [today]`, `updated: [today]` (skills/constitution/SKILL.md:67).
- **FR-008**: When amending, the system MUST bump the version (MAJOR.MINOR.PATCH) and set `updated` to today (skills/constitution/SKILL.md:67).
- **FR-009**: The system MUST NOT write any principle before the user has answered elicitation questions, even if the user is in a hurry, asks for reasonable defaults, points to an existing file, or asks to infer from the codebase (skills/constitution/SKILL.md:68, skills/constitution/SKILL.md:84).
- **FR-010**: The system MUST NOT treat `CLAUDE.md` (or any other existing file) as a constitution; it may use such a file as context for better questions but MUST NOT copy its content verbatim or use it as a substitute for elicitation (skills/constitution/SKILL.md:69, skills/constitution/SKILL.md:85).
- **FR-011**: The system MUST NOT generate principles by reading source files, configs, or commit history; principles MUST come from the user's stated values (skills/constitution/SKILL.md:70, skills/constitution/SKILL.md:86).
- **FR-012**: The system MUST keep Core Principles, Development Conventions, and Constraints in separate categories (skills/constitution/SKILL.md:71, skills/constitution/SKILL.md:87).
- **FR-013**: The system MUST apply the principle/decision boundary guard: a candidate that names a specific technology, is contestable, or is reversible MUST be routed to an ADR (captured via `/maxi:x-adr` during plan/implement) and reframed toward its underlying invariant, not written as a Core Principle (skills/constitution/SKILL.md:72, skills/constitution/SKILL.md:73, skills/constitution/SKILL.md:74, skills/constitution/SKILL.md:76, skills/constitution/SKILL.md:88).
- **FR-014**: The system MUST classify an externally-imposed requirement with no real alternative (e.g. compliance-mandated platform, mandated/banned dependency) as a Constraint kept in the constitution, while a dependency chosen among viable options is a decision destined for an ADR (skills/constitution/SKILL.md:62, skills/constitution/SKILL.md:75).
- **FR-015**: After writing, the system MUST verify the file exists at `docs/maxi/constitution.md` and, if it does not, diagnose and retry (skills/constitution/SKILL.md:78, skills/constitution/SKILL.md:41).
- **FR-016**: On completion, the system MUST tell the user they are ready for `/maxi:specify` (skills/constitution/SKILL.md:32, skills/constitution/SKILL.md:42).
- **FR-017**: The written constitution MUST follow the template's section structure — frontmatter (`version`/`created`/`updated`), Core Principles, additional constraint/convention sections, and Governance with a closing Version line (skills/constitution/SKILL.md:67, skills/constitution/constitution-template.md:1, skills/constitution/constitution-template.md:12, skills/constitution/constitution-template.md:51, skills/constitution/constitution-template.md:57).

### Key Entities

- **Constitution file** — `docs/maxi/constitution.md`; the authoritative per-project principles document with YAML frontmatter (`version`, `created`, `updated`), Core Principles, Constraint/Convention sections, and Governance (skills/constitution/SKILL.md:16, skills/constitution/constitution-template.md:1).
- **Constitution template** — `constitution-template.md` bundled in the skill directory; defines the required section structure copied at creation time (skills/constitution/SKILL.md:17, skills/constitution/constitution-template.md:7).
- **Principle** — a durable invariant every future decision must satisfy; one of Core Principles, Development Conventions, or Constraints (skills/constitution/SKILL.md:74, skills/constitution/SKILL.md:50).
- **Decision (ADR-bound)** — a contestable/reversible/technology-specific choice that the boundary guard routes out of the constitution to an ADR (skills/constitution/SKILL.md:73).

## Success Criteria

### Measurable Outcomes

- **SC-001**: After running the create path, a valid `docs/maxi/constitution.md` exists at the canonical path 100% of the time (write is verified before completion).
- **SC-002**: The constitution always contains between 3 and 7 principles — never fewer, never more.
- **SC-003**: Zero principles are written before any elicitation question is asked, across all shortcut-request scenarios (hurry, defaults, point-to-file, infer-from-code).
- **SC-004**: No concrete technology choice appears as a Core Principle; every such candidate is either reframed to an invariant or flagged for an ADR.
- **SC-005**: Every downstream `/maxi:*` workflow skill is unblocked once and only once the constitution exists at the canonical path.

## Assumptions

- The skill runs inside a maxi-managed project where `docs/maxi/` is the artifact root and the project root is the working directory.
- `/maxi:x-adr` and the plan/implement phases are the designated capture point for architectural decisions surfaced during elicitation; the constitution skill only flags them, it does not write ADRs.
- The user is available to answer interactive elicitation questions; the skill is not designed to run fully non-interactively.
- Today's ISO date is available for stamping `created`/`updated` frontmatter.

## Migration Notes

- Reverse-engineered from commit `7f945f8a8548bf1b4b123d28cc097e2cca897c68`.
- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).
- Verified against code by an adversarial pass before acceptance.
