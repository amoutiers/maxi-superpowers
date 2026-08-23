---
slug: 0022-durable-global-constraints
spec_slug: 0022-durable-global-constraints
created: 2026-08-23
updated: 2026-08-23
---

# Implementation Plan: Durable Global Constraints

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` to implement this plan task by task.
> Use `superpowers:writing-skills` for the existing Maxi skill edit and
> `superpowers:test-driven-development` before implementation changes.

## Summary

Make the existing `Global Constraints` heading an explicit Maxi plan contract.
The Maxi-owned plan template and coordinator will require one simple bullet
list of applicable durable cross-task constraints, or one explicit no-additional-
constraints bullet, while excluding transient execution state and individual
mutation authority. Existing design-review predicates, task extraction,
analysis, SDD projection, ledger recovery, and terminal evidence remain
unchanged.

## Technical Context

**Language/Version**: Markdown and Bash 3.2-compatible deterministic checks
**Primary Dependencies**: Existing Maxi plan coordinator, plan template,
test helpers, and vendored Superpowers v6.3.0
**Storage**: Repository Markdown skills, templates, specifications, and
pipeline documentation
**Testing**: Existing Bash fast-tier checks plus `bash tests/run-all.sh`
**Target Platform**: All harnesses supported by maxi-superpowers
**Project Type**: Multi-harness skills plugin
**Performance Goals**: No additional runtime phase, artifact, dispatch, or
ledger processing
**Constraints**: Preserve the fixed review boundaries, ten-state FSM, current
review predicates, upstream SDD ownership, vendored-skill byte identity, and
forward-only treatment of existing plan files
**Scale/Scope**: Two Maxi-owned planning surfaces, one focused fixture-backed
contract check, existing review and sync guards, and the Mandatory Sync 5
documentation set

## Global Constraints

- Preserve exactly one `Global Constraints` section; do not add a second
  delivery-contract section or artifact.
- Represent only applicable durable cross-task constraints as simple bullets;
  do not add fixed category labels or per-category `None` entries.
- When none apply, use one explicit bullet stating that no additional global
  constraints apply.
- Exclude transient worktree, HEAD, task-selection, and stop-point values, and
  exclude individual authority for Git-history, remote-repository,
  deployment/infrastructure, data-publication, or secret-access mutations.
- A durable rule requiring fresh authorization is allowed, but an earlier
  authorization never carries forward.
- Do not modify vendored Superpowers skills, the design reviewer, `analyze`,
  `implement`, `x-develop`, projection bytes, ledger bytes, or receipt formats.
- Keep all project artifacts and implementation text in English.
- Update all Mandatory Sync 5 documents in the same reviewed change and leave
  historical plan files byte-unchanged.

## Constitution Check

| Principle | Pass / Fail | Notes |
|-----------|-------------|-------|
| I. Mandatory Spec-Driven Pipeline | Pass | The feature follows the complete Maxi pipeline and changes only its planning contract. |
| II. Delegate to Superpowers, Never Duplicate | Pass | Maxi continues to invoke vendored `writing-plans`; the wrapper only post-formats Maxi's own schema. |
| III. Strict Pipeline, No Skipping | Pass | No phase, gate, status, or review boundary is removed or bypassed. |
| IV. ADR for Every Non-Trivial Architectural Decision | Pass | The design preserves ownership and gates, so no new architectural decision is introduced; `x-adr` remains available if implementation reveals one. |
| V. Artifacts Over Chat | Pass | Durable constraints become explicit plan bytes reviewed with the current spec. |
| VI. Single Responsibility per Skill | Pass | `plan` continues to own plan creation and correction; no reviewer or execution responsibility moves into it. |

## Project Structure

### Documentation (this feature)

```text
docs/maxi/specs/0022-durable-global-constraints/
├── spec.md                         # clarified requirements and boundaries
└── plan.md                         # this implementation plan
```

### Source and verification surfaces

```text
skills/plan/
├── SKILL.md                        # durable-versus-transient classification
└── plan-template.md                # canonical Global Constraints section

tests/
├── check-global-constraints.sh      # fixture-backed plan-contract outcomes
├── check-templates.sh              # plan-template shape
├── check-review-boundaries.sh      # unchanged reviewer predicates
├── check-skill-count.sh            # Mandatory Sync 5 parity
├── run-all.sh                      # focused-check registration
└── fixtures/global-constraints/
    ├── complete-spec.md            # all five durable categories
    ├── complete-plan.md            # applicable-only approved case
    ├── none-spec.md                # no additional durable constraint
    ├── none-plan.md                # one explicit no-additional bullet
    ├── omitted-plan.md             # rejected missing-constraint case
    ├── duplicate-plan.md           # rejected second-section case
    └── stale-authority-plan.md      # rejected carried-authority case

docs/
├── pipeline-flow.md                # planning-flow contract
├── delegation-map.md               # plan delegation contract
└── architecture.md                 # plan-layer contract

skills/using-maxi/SKILL.md           # session-start planning guidance
AGENTS.md                            # contributor and test contract
```

**Structure Decision**: Extend the existing Maxi-owned plan template and
coordinator, add one focused Bash 3.2 fixture oracle for observable contract
outcomes, and reuse the current artifact-design reviewer unchanged. The fixture
oracle is test-only and adds no runtime validator. No research, data model, API
contract, dependency, or runtime helper is needed.

## Decisions

| ADR | Title | Status |
|-----|-------|--------|
| None | Existing plan, review, and SDD ownership remain unchanged. | N/A |

## Complexity Tracking

No constitution violations require justification.

## Requirement Coverage

| Requirement | Delivery |
|-------------|----------|
| FR-001, FR-002, FR-003, FR-004 | Task 1 Steps 1 through 3 define fixture outcomes, then implement the single applicable-only section and its transient-authority exclusions. |
| FR-005 | Task 1 Steps 1 and 5 pair approved and rejected fixture cases with the unchanged review-boundary predicates and verdicts. |
| FR-006, FR-007 | Task 1 Steps 3 and 5 preserve the FSM, review, SDD, runtime-artifact, and dependency inventories. |
| FR-008 | Task 1 Global Constraints and Step 3 limit production writes to the template and coordinator; historical plans are not implementation targets. |
| FR-009 | Task 1 Steps 3 and 5 leave vendored skills untouched and run the sync invariant. |
| FR-010 | Task 1 Steps 2, 4, and 6 synchronize and verify the Mandatory Sync 5 set. |

## Implementation Tasks

### Task 1: Make durable global constraints an explicit atomic plan contract

**Files:**

- Create: `tests/check-global-constraints.sh`
- Create: `tests/fixtures/global-constraints/complete-spec.md`
- Create: `tests/fixtures/global-constraints/complete-plan.md`
- Create: `tests/fixtures/global-constraints/none-spec.md`
- Create: `tests/fixtures/global-constraints/none-plan.md`
- Create: `tests/fixtures/global-constraints/omitted-plan.md`
- Create: `tests/fixtures/global-constraints/duplicate-plan.md`
- Create: `tests/fixtures/global-constraints/stale-authority-plan.md`
- Modify: `tests/check-templates.sh`
- Modify: `tests/check-skill-count.sh`
- Modify: `tests/run-all.sh`
- Modify: `skills/plan/plan-template.md`
- Modify: `skills/plan/SKILL.md`
- Modify: `docs/pipeline-flow.md`
- Modify: `docs/delegation-map.md`
- Modify: `skills/using-maxi/SKILL.md`
- Modify: `AGENTS.md`
- Modify: `docs/architecture.md`
- Test unchanged: `tests/check-review-boundaries.sh`
- Test unchanged: `tests/check-sync-invariant.sh`

**Interfaces:**

- Consumes: the clarified requirements in
  [0022-durable-global-constraints/spec](spec.md), the current Maxi plan schema,
  and the existing artifact-design blocking predicates.
- Produces: exactly one `Global Constraints` plan section containing only
  applicable durable bullets, or one explicit no-additional-constraints bullet;
  deterministic approved and rejected fixture outcomes; deterministic failures
  if the plan or Mandatory Sync 5 surfaces drift.
- Preserves: exact-byte design review, task-extraction gating, readiness
  analysis, vendored Superpowers bytes, SDD projection and ledger recovery, and
  terminal receipts.

- [ ] **Step 1: Add the failing fixture-backed contract check**

  Create `tests/check-global-constraints.sh` with the existing
  `tests/lib/test-helpers.sh`. Keep it test-only and Bash 3.2 compatible. It
  extracts `## Expected Global Constraints` bullets from a fixture spec and
  compares them with the single `## Global Constraints` section in its plan.
  Define these exact cases:

  ```bash
  check_case approved complete-spec.md complete-plan.md
  check_case approved none-spec.md none-plan.md
  check_case rejected complete-spec.md omitted-plan.md
  check_case rejected complete-spec.md duplicate-plan.md
  check_case rejected complete-spec.md stale-authority-plan.md
  ```

  The approved complete pair contains one plain bullet for each of the five
  durable categories and excludes the fixture's worktree, HEAD, selected task,
  stop point, and individual push permission. The approved none pair contains
  exactly `- No additional global constraints apply.` The three rejected plans
  respectively omit one required bullet, contain one canonical `Global
  Constraints` section plus a separate `## Delivery Contract` section, or add
  `- Push permission from the previous session remains authorized.`

  `check_case` returns `approved` only when there is exactly one canonical
  heading, there is no separately named delivery-contract section, the
  extracted bullet list matches the spec's expected list byte for byte, and no
  bullet in the plan's `Global Constraints` section carries individual
  authority. The complete input spec deliberately includes prior authority as
  transient context so the approved output proves its exclusion. `check_case`
  returns `rejected` otherwise. Assert each actual result equals the expected
  result, then also require the current `skills/plan/SKILL.md` to name the five
  durable categories, the five authority categories, exactly one canonical
  section with no second delivery-contract section, simple applicable-only
  bullets, the exact none line, excluded transient values, and the allowed
  fresh-authorization rule.

  Register the check in `tests/run-all.sh` and run:

  ```bash
  bash tests/check-global-constraints.sh
  ```

  Expected: FAIL because the current Maxi coordinator does not yet define the
  complete durable-versus-transient contract. The fixture oracle itself must
  already report the two approved and three rejected cases exactly.

- [ ] **Step 2: Add failing template and Mandatory Sync 5 checks**

  Extend `tests/check-templates.sh` to require exactly one
  `## Global Constraints` heading and no separately named delivery-contract
  heading in `plan-template.md`. Add a dedicated five-path array to
  `tests/check-skill-count.sh`, excluding `README.md`, and require the same
  one-line durable-plan sentence in every file:

  ```bash
  GLOBAL_CONSTRAINT_DOCS=(
    "$ROOT/docs/pipeline-flow.md"
    "$ROOT/docs/delegation-map.md"
    "$ROOT/skills/using-maxi/SKILL.md"
    "$ROOT/AGENTS.md"
    "$ROOT/docs/architecture.md"
  )
  GLOBAL_CONSTRAINT_SENTENCE='Every newly written `plan.md` carries exactly one `Global Constraints` section containing only applicable durable cross-task constraints from the spec and constitution; transient execution state and individual mutation authority are excluded, while a durable rule requiring fresh authorization is allowed.'

  for doc in "${GLOBAL_CONSTRAINT_DOCS[@]}"; do
    grep -Fqx "$GLOBAL_CONSTRAINT_SENTENCE" "$doc" || {
      echo "FAIL [$(basename "$doc") documents durable global constraints]" >&2
      failures=$((failures + 1))
    }
  done
  ```

  Run:

  ```bash
  bash tests/check-templates.sh
  bash tests/check-skill-count.sh
  ```

  Expected: both checks fail before the template and five documents change.

- [ ] **Step 3: Implement the minimum Maxi-owned plan contract**

  Use `superpowers:writing-skills` to update the existing `plan` skill. Add
  `## Global Constraints` to `plan-template.md` after Technical Context and
  before Constitution Check with guidance equivalent to:

  ```markdown
  ## Global Constraints

  <!--
    List only applicable durable cross-task constraints from the current spec
    and constitution as simple bullets. Do not add fixed category labels or
    per-category None entries. If none apply, write exactly one bullet:
    - No additional global constraints apply.

    Never persist current worktree, HEAD, selected tasks, stop point, or an
    individual authorization for Git-history, remote-repository,
    deployment/infrastructure, data-publication, or secret-access mutations.
    A durable rule requiring fresh authorization is allowed.
  -->
  ```

  In `skills/plan/SKILL.md`, make the same protocol apply to normal creation,
  replanning, and explicit structural plan correction. Keep delegation to
  vendored `writing-plans` mandatory, then classify and post-format its output
  without changing the vendored skill. Do not add a reviewer predicate,
  artifact, status, ledger record, or automatic dispatch.

- [ ] **Step 4: Synchronize the five pipeline documents atomically**

  Add this exact shared sentence as one physical line near each document's
  existing `/maxi:plan` description:

  ```markdown
  Every newly written `plan.md` carries exactly one `Global Constraints` section containing only applicable durable cross-task constraints from the spec and constitution; transient execution state and individual mutation authority are excluded, while a durable rule requiring fresh authorization is allowed.
  ```

  Also document and describe `check-global-constraints.sh` in `AGENTS.md`, and
  update the `check-templates.sh` and `check-skill-count.sh` descriptions so
  their responsibilities match the new checks. Do not change the pipeline
  diagram, status set, delegation owner, or review boundary because none of
  those contracts changes.

- [ ] **Step 5: Turn the focused checks green**

  Run:

  ```bash
  bash tests/check-global-constraints.sh
  bash tests/check-templates.sh
  bash tests/check-skill-count.sh
  bash tests/check-review-boundaries.sh
  bash tests/check-sync-invariant.sh
  git diff --check
  ```

  Expected: all commands exit 0. The focused fixture check proves the two
  approved and three rejected outcomes. The unchanged review-boundary check
  binds omission, extra behavior, and safety control to the existing reviewer
  predicates and verdicts; the sync invariant proves vendored skills remain
  byte-identical.

- [ ] **Step 6: Run prose and full-suite verification**

  Invoke `maxi:doc-consistency` against the Mandatory Sync 5 set, resolve any
  factual drift it identifies, then run:

  ```bash
  bash tests/run-all.sh
  git status --short
  git diff --check
  ```

  Expected: the doc-consistency review has no unresolved contradiction, the
  fast tier ends with `All fast checks passed.`, and the worktree contains only
  the planned source, test, documentation, and Maxi artifact changes.

- [ ] **Step 7: Prepare the single atomic commit boundary**

  Stage only the reviewed files after implementation and verification, run
  `git diff --cached --check`, and show the exact cached manifest and diff. Wait
  for fresh explicit user authorization before committing. After that approval,
  commit once so the plan contract and Mandatory Sync 5 remain atomic:

  ```bash
  git add skills/plan/plan-template.md skills/plan/SKILL.md \
    tests/check-global-constraints.sh tests/check-templates.sh \
    tests/check-skill-count.sh tests/run-all.sh \
    tests/fixtures/global-constraints/complete-spec.md \
    tests/fixtures/global-constraints/complete-plan.md \
    tests/fixtures/global-constraints/none-spec.md \
    tests/fixtures/global-constraints/none-plan.md \
    tests/fixtures/global-constraints/omitted-plan.md \
    tests/fixtures/global-constraints/duplicate-plan.md \
    tests/fixtures/global-constraints/stale-authority-plan.md \
    docs/pipeline-flow.md docs/delegation-map.md \
    skills/using-maxi/SKILL.md AGENTS.md docs/architecture.md \
    docs/maxi/specs/0022-durable-global-constraints/spec.md \
    docs/maxi/specs/0022-durable-global-constraints/plan.md \
    docs/maxi/specs/0022-durable-global-constraints/tasks.md \
    docs/maxi/specs/0022-durable-global-constraints/analysis.md \
    docs/maxi/specs/0022-durable-global-constraints/reviews/design-review.md
  git diff --cached --check
  git diff --cached --stat
  git diff --cached
  # Stop here and wait for explicit commit authorization.
  git commit -m "feat(plan): preserve durable global constraints"
  ```

  Include only artifacts that actually exist at the authorized commit boundary;
  never create a missing artifact merely to satisfy this manifest.
