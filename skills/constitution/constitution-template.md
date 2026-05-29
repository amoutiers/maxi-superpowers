---
version: "[constitution-version]"
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# [project-name] Constitution
<!-- Example: Spec Constitution, TaskFlow Constitution, etc. -->

> **Filled in by `/maxi:constitution`.** See `SKILL.md` in this directory for the workflow.

## Core Principles

### [principle-name]
<!-- Example: I. Library-First -->
[principle-description]
<!-- Example: Every feature starts as a standalone library; Libraries must be self-contained, independently testable, documented; Clear purpose required - no organizational-only libraries -->

### [principle-name]
<!-- Example: II. CLI Interface -->
[principle-description]
<!-- Example: Every library exposes functionality via CLI; Text in/out protocol: stdin/args → stdout, errors → stderr; Support JSON + human-readable formats -->

### [principle-name]
<!-- Example: III. Test-First (NON-NEGOTIABLE) -->
[principle-description]
<!-- Example: TDD mandatory: Tests written → User approved → Tests fail → Then implement; Red-Green-Refactor cycle strictly enforced -->

### [principle-name]
<!-- Example: IV. Integration Testing -->
[principle-description]
<!-- Example: Focus areas requiring integration tests: New library contract tests, Contract changes, Inter-service communication, Shared schemas -->

### [principle-name]
<!-- Example: V. Observability, VI. Versioning & Breaking Changes, VII. Simplicity -->
[principle-description]
<!-- Example: Text I/O ensures debuggability; Structured logging required; Or: versions follow a predictable, documented scheme; Or: Start simple, YAGNI principles -->

## [section-name]
<!-- Example: Additional Constraints, Security Requirements, Performance Standards, etc. -->

[section-content]
<!-- Example: forbidden or locked-in dependencies, compliance standards, deployment policies, etc. Concrete technology *choices* (e.g. "use PostgreSQL") are decisions — they belong in an ADR (captured during planning/implementation), not here. -->

## [section-name]
<!-- Example: Development Workflow, Review Process, Quality Gates, etc. -->

[section-content]
<!-- Example: Code review requirements, testing gates, deployment approval process, etc. -->

## Governance
<!-- Example: Constitution supersedes all other practices; Amendments require documentation, approval, migration plan -->

[governance-rules]
<!-- Example: All PRs/reviews must verify compliance; Complexity must be justified; Use [GUIDANCE_FILE] for runtime development guidance -->

**Version**: [constitution-version] | **Created**: YYYY-MM-DD | **Updated**: YYYY-MM-DD
<!-- Example: Version: 2.1.1 | Created: 2025-06-13 | Updated: 2025-07-16 -->
