---
adr: 0019
slug: 0019-bounded-forward-artifact-replay
status: superseded
created: 2026-08-03
updated: 2026-08-03
decider: "Antoine Moutiers"
supersedes: 0017
superseded_by: 0022
---

# ADR-0019: Bounded Replay for Future Forward Specs

## Context

ADR-0017 introduced a broad revision graph and workflow-ledger protocol. The
replacement 0019 specification limits the feature to specs created by the
normal forward Maxi pipeline after it ships. It must show document revisions
and exact direct inputs, then calculate the smallest safe replay without
restarting unaffected phases.

The former ledger, legacy adoption, write-ahead recovery, and broad validator
are outside the replacement scope. Migration and reverse-engineering workflows
remain unchanged.

## Decision Drivers

- FR-001 through FR-016 require versioned future documents, exact direct
  dependencies, confined graph validation, and explicit replay consent.
- FR-010 and FR-011 require bounded replay and forbid rerunning `specify`.
- Constitution Principles III, V, and VI require complete phase discipline,
  durable artifact metadata, and a single owner per responsibility.

## Considered Options

- **Option A: Bounded forward-only replay, selected**
  - ✅ Satisfies driver: records only future forward-pipeline documents.
  - ✅ Satisfies driver: replay stops at the first required handoff.
  - ✅ Satisfies driver: avoids ledger and recovery protocol scope.

- **Option B: Retain the broad artifact graph and workflow ledger**
  - ✅ Provides interruption recovery.
  - ❌ Violates driver: exceeds the bounded feature scope.

- **Option C: Infer legacy revisions and migrate existing specs**
  - ❌ Violates driver: existing and migrated specs must remain untouched.

## Decision

Choose Option A. Future forward specs carry revisions, writer provenance, and
exact direct dependencies. A read-only Bash 3.2 planner identifies stale
descendants and displays only the executable continuation up to the next
required review handoff. It never writes artifacts or invokes a phase.

## Consequences

- **Good:** A correction avoids unrelated pipeline restarts.
- **Good:** Existing and migration-created specs remain unchanged.
- **Bad:** Replay pauses for required human review handoffs.
- **Bad:** Out-of-band edits that do not use an owning skill are unsupported.

## Confirmation

`tests/check-bounded-replay.sh` will cover confined graph validation, exact
stale descendants, consent, review handoffs, and no-write behavior.
