---
slug: 0003-constitution-adr-boundary-guard
spec_slug: 0003-constitution-adr-boundary-guard
created: 2026-05-29
updated: 2026-05-29
---

# Implementation Plan: Constitution/ADR Boundary Guard

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **AUTHORING CONSTRAINT:** The edits to `skills/constitution/SKILL.md` MUST be made via `superpowers:writing-skills` (project CLAUDE.md: "editing existing skills" goes through writing-skills; constitution Contributor Workflow line 41). Do NOT hand-edit the SKILL.md. The edit to `templates/constitution-template.md` is not a skill and may be a plain `Edit`.

**Goal:** Add a "principles, not decisions" guard to the `constitution` skill and tighten two constitution-template example comments, so concrete architectural decisions get redirected to `/maxi:adr` instead of being recorded as Core Principles.

**Architecture:** Pure documentation/skill-text change. Two files: the `constitution` SKILL.md gains one Critical Rule (the litmus test + redirect), one matching Red Flag, and a one-line elicitation nudge; the constitution template loses two decision-shaped example comments. No code, no new files, no FSM/gating/relationship change — therefore no ADR and no pipeline-doc-sync obligation.

**Tech Stack:** Markdown only. Verification via the existing fast-tier bash test suite (`tests/run-all.sh`).

---

## Summary

The constitution↔ADR boundary is conceptually clean everywhere except constitution *authoring*: the skill never says "concrete decisions go in an ADR, not here," and the template's example comments model decision-shaped content as principles. This plan closes that gap with five small, surgical edits across two files (FR-001 … FR-008) while staying inside the explicit scope fence (FR-009).

## Technical Context

**Language/Version**: Markdown (skill + template authoring)
**Primary Dependencies**: superpowers:writing-skills (mandatory authoring path for SKILL.md edits)
**Storage**: N/A
**Testing**: `bash tests/run-all.sh` fast tier — `check-templates.sh`, `check-frontmatter.sh` (regression guards); plus a manual content checklist (no automated test asserts skill *prose*)
**Target Platform**: Claude Code + OpenCode plugin
**Project Type**: documentation / skill maintenance
**Performance Goals**: N/A
**Constraints**: blast radius limited to exactly 2 files (SC-004); template section headers unchanged (FR-008)
**Scale/Scope**: 2 files, 5 edits

## Constitution Check

*GATE: Must pass before implementation. Re-checked after design.*

| Principle | Pass / Fail | Notes |
|-----------|-------------|-------|
| I. Mandatory Spec-Driven Pipeline | ✓ | Change is itself going through specify → clarify → plan. |
| II. Delegate to Superpowers, Never Duplicate | ✓ | Edits maxi-native `constitution` skill + template; SKILL.md edit delegated to `writing-skills`. No duplication. |
| III. Strict Pipeline — No Skipping | ✓ | No phase skipped. |
| IV. ADR for Every Non-Trivial Architectural Decision | ✓ | Contributor Workflow line 43: ADR required only for gating-rule / FSM / maxi↔superpowers changes. This change is none of those (FR-009). No ADR. |
| V. Artifacts Over Chat | ✓ | All output persisted to spec.md / plan.md / the two edited files. |
| Constraint: English only | ✓ | All content English. |
| Constraint: Strict vendoring | ✓ | `constitution` skill + constitution-template are maxi-native, not vendored — editable. |
| Constraint: Fast-tier tests mandatory | ✓ | Task 4 runs `tests/run-all.sh`; FR-008 keeps headers intact. |

No violations → Complexity Tracking left empty.

## Project Structure

### Documentation (this feature)

```text
docs/maxi/specs/0003-constitution-adr-boundary-guard/
├── spec.md     # status: clarified
├── plan.md     # this file
└── tasks.md    # produced later by /maxi:tasks
```

### Files Touched (repository root)

```text
skills/constitution/SKILL.md          # +1 Critical Rule, +1 Red Flag, +1 elicitation nudge (via writing-skills)
templates/constitution-template.md    # 2 example-comment edits (plain Edit)
```

**Structure Decision**: No new files. Exactly two existing files change, satisfying SC-004 (blast radius). The SKILL.md edit is additive (new bullets only); the template edit replaces text inside existing HTML comments without altering any `#`/`##` header (FR-008).

## Decisions

> **Auto-populated by `/maxi:plan` when architectural choices are recorded as ADRs.**

| ADR | Title | Status |
|-----|-------|--------|
| — | No ADRs recorded — change does not touch a gating rule, the FSM, or the maxi↔superpowers relationship (constitution line 43). | — |

## Complexity Tracking

> No Constitution Check violations — section intentionally empty.

---

## Implementation Tasks

> **Verification note (read first):** There is no automated test that asserts the *prose* of a skill. The fast-tier suite (`check-templates.sh`, `check-frontmatter.sh`) is a **regression guard** — it proves the edits did not break structure (FR-008). Correctness of the added guidance is verified by the **content checklist** in Task 4 against the spec's Acceptance Scenarios. This is the honest verification model for a docs change; do not fabricate a unit test for Markdown.

### Task 1: Add the "Principles, not decisions" Critical Rule to the constitution skill

Implements **FR-001, FR-002, FR-004** (litmus test + ADR redirect + contrasting example, incl. the constraint carve-out from US1 Acceptance Scenario 3).

**Files:**
- Modify (via `superpowers:writing-skills`): `skills/constitution/SKILL.md` — insert a new bullet in the `## Critical Rules` list, immediately after the existing `- **Keep categories separate.** ...` bullet (currently line 70).

- [ ] **Step 1: Invoke writing-skills for the SKILL.md edit**

Authoring constraint: this edit goes through `superpowers:writing-skills`, not a raw `Edit`. Give writing-skills the exact target content below.

- [ ] **Step 2: Insert this exact bullet after the "Keep categories separate" rule**

```markdown
- **Principles, not decisions.** A constitution holds *invariants that constrain all future decisions* — not the decisions themselves. Litmus test: if it names a specific technology, is contestable (real alternatives exist), or could be reversed by a later choice, it is an architectural **decision → capture it via `/maxi:adr`, not here**. If it is a durable rule that every future decision must satisfy, it is a principle. Example: *"Every storage choice must be justified against data-durability needs"* is a principle; *"We use PostgreSQL"* is a decision that belongs in an ADR. An externally-imposed requirement with no real alternative (e.g. a compliance-mandated platform) is **not** contestable — it is a legitimate Constraint and stays in the constitution.
```

- [ ] **Step 3: Verify placement**

Run: `grep -n "Principles, not decisions" skills/constitution/SKILL.md`
Expected: one match, located between the "Keep categories separate" line and the "Minimum 3, maximum 7" line.

- [ ] **Step 4: Commit**

```bash
git add skills/constitution/SKILL.md
git commit -m "feat(constitution): add 'principles, not decisions' critical rule (FR-001,002,004)"
```

### Task 2: Add the matching Red Flag to the constitution skill

Implements **FR-003** (and reinforces FR-004's example pair).

**Files:**
- Modify (via `superpowers:writing-skills`): `skills/constitution/SKILL.md` — add a bullet to the `## Red Flags` list, after the existing `- Mixing "use TypeScript strict mode" (convention) with "never store PII unencrypted" (constraint) ...` bullet (currently line 81).

- [ ] **Step 1: Insert this exact Red Flag bullet**

```markdown
- Writing a concrete tech/tool choice ("we use PostgreSQL", "deploy on Vercel", "MAJOR.MINOR.BUILD versioning") as a Core Principle → **that's a decision, not a principle; record the underlying invariant here and propose the choice via `/maxi:adr`**
```

- [ ] **Step 2: Verify placement**

Run: `grep -n "that's a decision, not a principle" skills/constitution/SKILL.md`
Expected: one match inside the `## Red Flags` section (after the "Mixing ... convention ... constraint" flag).

- [ ] **Step 3: Commit**

```bash
git add skills/constitution/SKILL.md
git commit -m "feat(constitution): add red flag for decisions-as-principles (FR-003)"
```

### Task 3: Add the elicitation-time nudge to the constitution skill

Implements **FR-005** (US3 — guard fires during Q&A, not only on review).

**Files:**
- Modify (via `superpowers:writing-skills`): `skills/constitution/SKILL.md` — add a bullet to the **Core Principles** elicitation block in `## Elicitation Protocol`, after the three existing question bullets (currently ending at line 53, `- "What trade-off has your team made that might surprise an outsider?"`).

- [ ] **Step 1: Insert this exact bullet**

```markdown
- If an answer names a specific technology or a reversible choice, note that it belongs in an ADR (`/maxi:adr`) and steer the principle toward the underlying invariant instead.
```

- [ ] **Step 2: Verify placement**

Run: `grep -n "steer the principle toward the underlying invariant" skills/constitution/SKILL.md`
Expected: one match within the `## Elicitation Protocol` section, under the Core Principles questions.

- [ ] **Step 3: Commit**

```bash
git add skills/constitution/SKILL.md
git commit -m "feat(constitution): nudge decisions to ADR during elicitation (FR-005)"
```

### Task 4: Tighten the constitution template example comments

Implements **FR-006, FR-007, FR-008**. This file is a template, not a skill — use a plain `Edit`.

**Files:**
- Modify: `templates/constitution-template.md` line 35 (versioning example) and line 41 (constraints-section example).

- [ ] **Step 1: Replace the versioning example (line 35) — FR-006**

Old:

```markdown
<!-- Example: Text I/O ensures debuggability; Structured logging required; Or: MAJOR.MINOR.BUILD format; Or: Start simple, YAGNI principles -->
```

New (drop the concrete `MAJOR.MINOR.BUILD format` decision; keep a principle-shaped versioning example):

```markdown
<!-- Example: Text I/O ensures debuggability; Structured logging required; Or: versions follow a predictable, documented scheme; Or: Start simple, YAGNI principles -->
```

- [ ] **Step 2: Replace the constraints-section example (line 41) — FR-007**

Old:

```markdown
<!-- Example: Technology stack requirements, compliance standards, deployment policies, etc. -->
```

New (constraint-shaped examples + explicit ADR redirect for concrete tech choices):

```markdown
<!-- Example: forbidden or locked-in dependencies, compliance standards, deployment policies, etc. Concrete technology *choices* (e.g. "use PostgreSQL") are decisions — capture them via /maxi:adr, not here. -->
```

- [ ] **Step 3: Verify headers untouched (FR-008)**

Run: `grep -nE '^(#|##) ' templates/constitution-template.md`
Expected: identical header list to before the edit — `# [project-name] Constitution`, `## Core Principles`, the two `## [section-name]`, `## Governance`. (Only HTML-comment lines changed.)

- [ ] **Step 4: Commit**

```bash
git add templates/constitution-template.md
git commit -m "feat(constitution-template): tighten examples so decisions go to ADR (FR-006,007,008)"
```

### Task 5: Verify — fast-tier tests + content checklist

Implements verification of **SC-001, SC-002, SC-003, SC-004**.

**Files:** none modified (verification only).

- [ ] **Step 1: Run the fast-tier test suite (SC-003, FR-008)**

Run: `bash tests/run-all.sh`
Expected: all fast-tier checks pass — in particular `OK  [constitution-template.md]` and the `check-frontmatter.sh` checks. No failures.

- [ ] **Step 2: Content checklist against the spec (SC-001, SC-002)**

Confirm by reading `skills/constitution/SKILL.md`:
- SC-001: an explicit statement that concrete decisions belong in ADRs, not Core Principles, is now discoverable (the Critical Rule from Task 1).
- SC-002: the litmus test classifies the canonical pair unambiguously — "storage choice must be justified" = principle; "we use PostgreSQL" = decision/ADR.
- US1 Acceptance Scenario 3: the constraint carve-out ("not contestable → stays in constitution") is present.

- [ ] **Step 3: Blast-radius check (SC-004)**

Run: `git diff --name-only master...HEAD`
Expected: exactly `skills/constitution/SKILL.md`, `templates/constitution-template.md`, plus the spec/plan/tasks artifacts under `docs/maxi/specs/0003-constitution-adr-boundary-guard/`. No other source/doc files (no `docs/pipeline-flow.md`, `docs/delegation-map.md`, `using-maxi`, `CLAUDE.md`, or any other skill) — confirming FR-009.

- [ ] **Step 4: Final commit (if any verification fixups were needed)**

```bash
git add -A
git commit -m "test(constitution-guard): fast-tier + content verification (SCs)"
```

---

## Self-Review

**1. Spec coverage:**
- FR-001 → Task 1 (litmus test). FR-002 → Task 1 (ADR redirect). FR-003 → Task 2 (Red Flag). FR-004 → Task 1 example pair (+ Task 2). FR-005 → Task 3 (elicitation nudge). FR-006 → Task 4 Step 1. FR-007 → Task 4 Step 2. FR-008 → Task 4 Step 3 (header check). FR-009 → Task 5 Step 3 (blast-radius diff). SC-001/002 → Task 5 Step 2. SC-003 → Task 5 Step 1. SC-004 → Task 5 Step 3. US1/US2/US3 each map to Tasks 1–2 / 4 / 3 respectively. No gaps.

**2. Placeholder scan:** No TBD/TODO; every edit shows exact target Markdown and exact verification commands.

**3. Type/term consistency:** The redirect target is written `/maxi:adr` consistently across Tasks 1–4. The litmus-test example pair ("storage choice must be justified" / "we use PostgreSQL") is identical in the spec (FR-004, SC-002), Task 1, and Task 5.
