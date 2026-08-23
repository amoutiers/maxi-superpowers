---
slug: 0020-active-spec-adr-amendment
spec_slug: 0020-active-spec-adr-amendment
created: 2026-08-23
updated: 2026-08-23
---

# Implementation Plan: Active-spec ADR amendment

## Summary

Record the creating spec directly in every newly written ADR. While that spec
is active, an agent that detects an architectural-decision change proposes an
explicitly approved amendment through internal `x-adr`; closed specs retain
the existing supersession flow.

## Technical Context

**Language/Version**: Markdown and Bash
**Primary Dependencies**: POSIX shell utilities already used by the fast tier
**Storage**: Repository Markdown artifacts
**Testing**: `bash tests/check-templates.sh`, `bash tests/check-migrate-adr.sh`, then `bash tests/run-all.sh`
**Target Platform**: Supported agent harnesses
**Project Type**: Multi-harness skills plugin
**Performance Goals**: No runtime cost outside ADR proposal handling
**Constraints**: English artifacts; no new FSM status, command, or dependency; explicit consent before every ADR amendment; existing ADRs remain unchanged
**Scale/Scope**: Existing ADR template, internal ADR and migration skills, two invariant suites, and governance documentation

## Constitution Check

| Principle | Pass / Fail | Notes |
|-----------|-------------|-------|
| I. Mandatory Spec-Driven Pipeline | Pass | The change follows the forward pipeline. |
| II. Delegate to Superpowers, Never Duplicate | Pass | No Superpowers capability is reimplemented. |
| III. Strict Pipeline, No Skipping | Pass | No phase or status changes. |
| IV. ADR for Every Non-Trivial Architectural Decision | Pass | The accepted ADR-0024 is amended with consent and records the supersession of its predecessor. |
| V. Artifacts Over Chat | Pass | The creating-spec relation and every decision remain durable artifacts. |
| VI. Single Responsibility per Skill | Pass | `x-adr` remains the sole ADR lifecycle owner. |

## Project Structure

```text
docs/maxi/
├── constitution.md
├── adr/
│   └── 0024-active-spec-adr-amendment.md
└── specs/0020-active-spec-adr-amendment/
    ├── spec.md
    ├── plan.md
    ├── tasks.md
    └── analysis.md

skills/
├── x-adr/
│   ├── SKILL.md
│   └── adr-template.md
└── migrate-adr/
    ├── SKILL.md
    ├── import-subagent.md
    └── discover-subagent.md

tests/
├── check-templates.sh
├── check-migrate-adr.sh
├── check-skill-count.sh
└── fixtures/sample-adr.md
```

**Structure Decision**: Add one scalar `spec` frontmatter field to new ADRs and preserve `related_adrs` as the existing spec-side review and analysis index. `x-adr` remains internal; no new command or skill is created.

## Decisions

| ADR | Title | Status |
|-----|-------|--------|
| 0024-active-spec-adr-amendment | Active-spec ADR amendments with direct spec links | accepted, amended during planning |

## Complexity Tracking

No constitution violations require justification.

## Implementation Tasks

### Task 1: Lock the direct-link and amendment contract

**Files:**
- Modify: `tests/check-templates.sh`
- Modify: `tests/check-migrate-adr.sh`
- Modify: `tests/check-skill-count.sh`
- Modify: `tests/fixtures/sample-adr.md`

- [ ] Require `spec:` in the ADR template and fixture, while retaining the prohibition on obsolete plural traceability fields.
- [ ] Require `x-adr` to write the active spec slug or `null`, preserve it during an amendment, reject missing or null links, require explicit diff-and-consent, and use supersession for closed specs.
- [ ] Require migration guidance to create `spec: null` without rewriting existing ADRs.
- [ ] Require the Constitution and Mandatory Sync 5 documents to state the direct `spec` link, agent-proposed active-spec amendment, and closed-spec supersession rule.
- [ ] Run all three targeted checks and verify they fail before the skill contract is updated.

### Task 2: Give internal `x-adr` the active-spec amendment procedure

**Files:**
- Modify: `skills/x-adr/SKILL.md`
- Modify: `skills/x-adr/adr-template.md`
- Modify: `skills/using-maxi/SKILL.md`
- Modify: `skills/migrate-adr/SKILL.md`
- Modify: `skills/migrate-adr/import-subagent.md`
- Modify: `skills/migrate-adr/discover-subagent.md`

- [ ] Add `spec: null` to every new ADR template path; have `x-adr` replace it with the current spec slug only when it writes an ADR for that active spec.
- [ ] Remove the plan/implement-only invocation limit from `x-adr` while keeping it internal and non-user-invocable.
- [ ] Require the session-level active-spec workflow to invoke internal `x-adr` when an agent detects a change to an accepted ADR whose `spec` equals the current active spec slug, at every active status.
- [ ] Define the amendment proposal: `x-adr` shows the full amended ADR and exact diff, then writes only after `yes`.
- [ ] Preserve `adr`, `slug`, `spec`, `created`, `status`, and supersession fields during an amendment; reject `done`, `parked`, `cancelled`, missing, and `null` links with the existing supersession flow.
- [ ] Keep existing ADRs untouched and make every migration-created ADR use `spec: null`.
- [ ] Run all three targeted checks and verify they pass.

### Task 3: Synchronize governance documentation

**Files:**
- Modify: `docs/maxi/constitution.md`
- Modify: `docs/pipeline-flow.md`
- Modify: `docs/delegation-map.md`
- Modify: `AGENTS.md`
- Modify: `docs/architecture.md`

- [ ] Bump the Constitution to `1.4.2` and state the direct `spec` link plus the active-spec, agent-proposed amendment rule.
- [ ] Update the Mandatory Sync 5 documents and architecture description with the same internal proposal and closed-spec supersession rule.
- [ ] Run `bash tests/run-all.sh` and verify the full fast tier passes.

### Task 4: Verify the finished change

**Files:**
- Modify: no additional files

- [ ] Inspect the diff and verify that historical ADRs are unchanged except for the `superseded_by` metadata on ADR-0024's predecessor, that ADR-0024 is amended rather than replaced, and that the spec keeps its existing `related_adrs` entry.
- [ ] Stage the exact diff and wait for explicit commit approval. Do not commit without it.
