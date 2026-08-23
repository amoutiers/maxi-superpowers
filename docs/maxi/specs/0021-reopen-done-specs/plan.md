---
slug: 0021-reopen-done-specs
spec_slug: 0021-reopen-done-specs
created: 2026-08-23
updated: 2026-08-23
---

# Implementation Plan: Reopen Completed Specs

## Summary

Allow `/maxi:revise` to reopen a completed specification through its existing
consent-gated A+ rollback flow. Persist `reopened_from: done` on that
specification and use it as a permanent `x-adr` eligibility boundary: initial
active specs retain consent-gated ADR amendments, while reopened specs use
supersession.

## Technical Context

**Language/Version**: Markdown and Bash
**Primary Dependencies**: POSIX shell utilities already used by the fast tier
**Storage**: Repository Markdown frontmatter and ADR records
**Testing**: Targeted deterministic Bash checks, then `bash tests/run-all.sh`
**Target Platform**: Supported agent harnesses
**Project Type**: Multi-harness skills plugin
**Performance Goals**: No runtime work outside the existing skill prompts
**Constraints**: No new FSM status; explicit consent before a spec rollback or
ADR write; never revise an accepted ADR body after its spec has been reopened
from `done`; preserve the existing amendment path before a spec first reaches
`done`
**Scale/Scope**: Three skill ownership boundaries (`revise`, `x-adr`, and
`using-maxi`), their deterministic checks, the existing ADR supersession, and
all governance documents that state the lifecycle or ADR policy

## Constitution Check

| Principle | Pass / Fail | Notes |
|-----------|-------------|-------|
| I. Mandatory Spec-Driven Pipeline | Pass | The completed-spec change follows `specify → clarify → plan → tasks → analyze → implement`. |
| II. Delegate to Superpowers, Never Duplicate | Pass | The change extends Maxi-owned lifecycle and ADR skills only. |
| III. Strict Pipeline, No Skipping | Pass | `/maxi:revise` remains the sole backward transition and retains its consent gate. |
| IV. ADR for Every Non-Trivial Architectural Decision | Pass | Accepted ADR-0025 supersedes ADR-0024. |
| V. Artifacts Over Chat | Pass | The reopening watermark and supersession chain are persistent artifacts. |
| VI. Single Responsibility per Skill | Pass | `revise` owns the spec watermark; `x-adr` owns ADR eligibility and supersession. |

## Project Structure

```text
docs/maxi/
├── adr/
│   ├── 0024-active-spec-adr-amendment.md       # superseded, body unchanged
│   └── 0025-reopened-spec-adr-eligibility.md   # new superseding ADR
└── specs/0021-reopen-done-specs/
    ├── spec.md
    ├── plan.md
    └── tasks.md

skills/
├── revise/SKILL.md                             # done rollback and watermark
├── using-maxi/SKILL.md                         # session lifecycle guidance
└── x-adr/SKILL.md                              # amendment eligibility boundary

tests/
├── check-migrate-adr.sh                        # ADR eligibility contract
├── check-revise.sh                             # completed-spec rollback contract
└── run-all.sh                                  # fast-tier registration
```

**Structure Decision**: Use the optional, monotone
`reopened_from: done` field on a spec only after `/maxi:revise` reopens it.
Do not add an FSM status or an ADR-local mutation flag. `x-adr` reads the
linked spec's field before allowing its pre-existing active-spec amendment
route.

## Decisions

| ADR | Title | Status |
|-----|-------|--------|
| [0025-reopened-spec-adr-eligibility](../../adr/0025-reopened-spec-adr-eligibility.md) | Reopened-Spec ADR Eligibility | accepted |

## Complexity Tracking

No constitution violations require justification.

## Implementation Tasks

### Task 1: Lock the completed-spec eligibility contract

**Files:**

- Create: `tests/check-revise.sh`
- Modify: `tests/check-migrate-adr.sh`
- Modify: `tests/run-all.sh`

**Interfaces:**

- Consumes: `skills/revise/SKILL.md`, `skills/x-adr/SKILL.md`, and
  `skills/using-maxi/SKILL.md`.
- Produces: deterministic fast-tier failures if a `done` spec is refused, the
  watermark is not permanent, or a reopened spec can amend an accepted ADR.

- [ ] Add `check-revise.sh` assertions that `revise` accepts `done`, preserves
  the A+ picker and explicit `yes`, writes `reopened_from: done`, and no longer
  calls `done` shipped.
- [ ] Extend `check-migrate-adr.sh` to require the existing amendment path for
  active specs that have never reached `done`, and supersession when the linked
  spec contains `reopened_from: done`.
- [ ] Register `check-revise.sh` in the fast-tier runner and run both targeted
  checks. They must fail before the skill text changes.

### Task 2: Implement the irreversible reopened-spec boundary

**Files:**

- Modify: `skills/revise/SKILL.md`
- Modify: `skills/x-adr/SKILL.md`
- Modify: `skills/using-maxi/SKILL.md`

**Interfaces:**

- `revise`: on a confirmed rollback from `done`, set
  `reopened_from: done` in addition to its existing `status`, `updated`, and
  clarification-note write.
- `x-adr`: permit its current full-draft, exact-diff, explicit-`yes` amendment
  only when the linked spec is active and lacks `reopened_from: done`;
  otherwise route to normal supersession.
- `using-maxi`: tell every session that the watermark is permanent and does not
  add a status or automatic successor phase.

- [ ] Remove the `done (shipped)` refusal and list `done` as a valid revision
  source in `revise`.
- [ ] State that a missing watermark means the spec has not been reopened from
  `done`, and that later status changes never clear the watermark.
- [ ] Make `x-adr` check the linked spec's watermark before status-based
  amendment eligibility, while retaining the current consent package for an
  eligible initial lifecycle.
- [ ] Run `bash tests/check-revise.sh` and
  `bash tests/check-migrate-adr.sh` until both pass.

### Task 3: Verify the accepted supersession and synchronize governance

**Files:**

- Modify: `docs/maxi/constitution.md`
- Modify: `docs/pipeline-flow.md`
- Modify: `docs/delegation-map.md`
- Modify: `AGENTS.md`
- Modify: `docs/architecture.md`
- Modify: `README.md`
- Modify: `tests/check-skill-count.sh`

**Interfaces:**

- ADR-0025 already has `spec: 0021-reopen-done-specs`, supersedes ADR-0024,
  and explains the post-reopening supersession rule.
- ADR-0024 is already `superseded` with `superseded_by: 0025`; its body is not
  an implementation target.
- The Mandatory Sync documents describe the same two eligibility paths.

- [ ] Verify that ADR-0025 is accepted, linked to this spec, and supersedes
  ADR-0024 without changing ADR-0024's body.
- [ ] Replace status-only wording in all policy documents with the permanent
  watermark rule, and make `check-skill-count.sh` fail on divergence.
- [ ] Run the targeted governance checks after the documentation change.

### Task 4: Verify the finished policy change

**Files:**

- Modify: no additional files

- [ ] Inspect `git diff --check` and the full diff to verify that ADR-0024's
  body has not changed and that the only edits to it are supersession metadata.
- [ ] Run `bash tests/run-all.sh` and record its final result.
- [ ] Commit each reviewed SDD task under the owner's explicit authorization;
  inspect the final committed range and leave the worktree clean.
