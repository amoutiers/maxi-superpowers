# Fixed Review Boundaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace bounded replay with three fixed review boundaries that cannot automatically re-enter the pipeline.

**Architecture:** Remove the marker-driven artifact graph and its automatic review handoffs. A renamed public `review` skill writes one design-review record for the exact `spec.md`/`plan.md` pair; `tasks` accepts only that current approval. `analyze` remains the readiness review and upstream SDD remains the final implementation review.

**Tech Stack:** Markdown skills, Bash 3.2 deterministic checks, Git worktrees, vendored Superpowers v6.3.0.

**Spec:** [0020-fixed-review-boundaries/design](design.md)

## Global Constraints

- Keep the ten-state FSM unchanged.
- Do not add a dependency or a new workflow ledger.
- Keep exactly 19 Maxi-native skills: rename `x-review` to public `review`; do not add a wrapper skill.
- Use `superpowers:writing-skills` for every Maxi skill edit and `superpowers:test-driven-development` before implementation edits.
- A correction writes only its owned artifact and must not dispatch a reviewer or a successor phase.
- Do not commit, push, or publish without fresh explicit user authorization.
- Update the Mandatory Sync 5 documents and the public README in the same change.

---

## File Structure

| Path | Responsibility |
|---|---|
| `skills/review/SKILL.md` | Public, explicit design review of current spec and plan bytes. |
| `skills/review/review-template.md` | Persisted `reviews/design-review.md` schema. |
| `skills/{specify,clarify,revise,plan,tasks,analyze,implement,using-maxi}/SKILL.md` | Ordinary pipeline ownership and three fixed boundaries. |
| `skills/revise/replay-plan.sh` | Deleted: no artifact graph or automatic replay remains. |
| `skills/x-develop/{SKILL.md,project-tasks.sh,record-terminal.sh,result-contract.sh}` | Keep SDD final review; remove only marker-conditioned branching. |
| `tests/check-review-boundaries.sh` | Deterministic regression guard for fixed boundaries and no automatic re-review. |
| `tests/{check-bounded-replay.sh,check-x-review.sh,fixtures/bounded-replay/}` | Deleted with the obsolete mechanism. |
| `tests/{check-templates.sh,check-skills-present.sh,check-skill-count.sh,check-x-develop-adapter.sh,check-implement-handoff.sh,run-all.sh}` | Inventory, contracts, and fast-tier registration. |
| `docs/maxi/adr/0022-fixed-review-boundaries.md` | Superseding architecture decision. |
| `docs/{pipeline-flow.md,delegation-map.md,architecture.md}`, `AGENTS.md`, `skills/using-maxi/SKILL.md`, `README.md` | One consistent public pipeline description. |

### Task 1: Establish failing fixed-boundary checks

**Files:**
- Create: `tests/check-review-boundaries.sh`
- Modify: `tests/run-all.sh`
- Test: `tests/check-review-boundaries.sh`

**Interfaces:**
- Consumes: source skill files and the five pipeline documents.
- Produces: a zero-exit deterministic check only when the fixed-boundary contract is present and all replay triggers are absent.

- [ ] **Step 1: Write the RED check before changing a skill**

Add checks equivalent to:

```bash
assert_file_exists "$ROOT/skills/review/SKILL.md" "public design review skill"
assert_grep "$ROOT/skills/plan/SKILL.md" 'one design review.*spec.md.*plan.md' "plan has one design boundary"
assert_grep "$ROOT/skills/tasks/SKILL.md" 'missing or stale.*design review.*stop' "tasks require a current design review"
assert_grep "$ROOT/skills/analyze/SKILL.md" 'readiness review.*before implementation' "analysis is readiness review"
assert_not_grep "$ROOT/skills/plan/SKILL.md" 'replay_continuation|REVIEW_REQUIRED|x-review' "plan cannot auto-replay"
```

Also assert that no listed owner skill dispatches a review after a correction and that `x-develop` still names upstream SDD as final-review owner.

- [ ] **Step 2: Register and run the check**

Add `bash "$ROOT/tests/check-review-boundaries.sh"` to the fast tier, then run:

```bash
bash tests/check-review-boundaries.sh
```

Expected: failure because `review/` does not yet exist and replay terms remain.

### Task 2: Remove bounded replay and simplify ordinary owners

**Files:**
- Modify: `skills/{specify,clarify,revise,plan,tasks,analyze,implement}/SKILL.md`
- Modify: `skills/specify/spec-template.md`
- Delete: `skills/revise/replay-plan.sh`
- Test: `tests/check-review-boundaries.sh`

**Interfaces:**
- Consumes: the unchanged FSM and each owner skill’s existing public phase.
- Produces: one normal forward flow without markers, artifact revisions, continuation presenters, replay commands, or automatic review dispatch.

- [ ] **Step 1: Remove obsolete creation and replay contracts**

With `superpowers:writing-skills`, remove `replay_contract`, structural contributor metadata, direct-input revision graphs, `replay_continuation`, `--resume-current-*`, `REVIEW_REQUIRED`, and every `replay-plan.sh` invocation. `specify` creates the ordinary spec-template frontmatter only.

- [ ] **Step 2: Preserve explicit correction ownership**

Rewrite `revise`, `plan`, and `tasks` correction modes so each changes its owned artifact and returns to its ordinary FSM status. Their required terminal language is equivalent to:

```text
Correction recorded. No review or successor phase was started.
Request /maxi:review when you want a new design review.
```

No correction may touch a descendant, create a review, or request chained consent.

- [ ] **Step 3: Run the focused RED-to-GREEN check**

```bash
bash tests/check-review-boundaries.sh
git diff --check
```

Expected: the replay assertions are gone; the test still fails until Task 3 creates the public review skill.

### Task 3: Replace two handoffs with one explicit design review

**Files:**
- Move: `skills/x-review/` to `skills/review/`
- Modify: `skills/review/SKILL.md`
- Modify: `skills/review/review-template.md`
- Modify: `skills/plan/SKILL.md`
- Modify: `skills/tasks/SKILL.md`
- Test: `tests/check-review-boundaries.sh`

**Interfaces:**
- Consumes: exact current `spec.md` and `plan.md` bytes.
- Produces: `reviews/design-review.md` with both SHA-256 values and `verdict: approved | rejected`.

- [ ] **Step 1: Define the two-document review record**

Replace the single-subject envelope with this minimum stable shape:

```yaml
reviewed_spec_sha256: <sha256>
reviewed_plan_sha256: <sha256>
verdict: approved
```

The body records findings and the review’s verification. A changed spec or plan makes the record stale; staleness has no side effect.

- [ ] **Step 2: Make review explicit after corrections**

The normal first `plan` completion invokes the design review once. The public `/maxi:review` command reruns it only when the user explicitly requests it. A rejected review reports findings and stops; it never starts a correction or a replacement review.

- [ ] **Step 3: Gate only task extraction**

`tasks` computes both current hashes and accepts only an approved matching `reviews/design-review.md`. On a missing or stale record it performs no write and emits a concise command to request `/maxi:review`; it must not invoke that skill itself.

- [ ] **Step 4: Prove the boundary behavior**

Extend the Task 1 check to prove all four cases: first normal plan completion has one review dispatch, correction dispatches zero, stale approval blocks tasks without writing, and explicit `/maxi:review` is the only re-review entry point.

```bash
bash tests/check-review-boundaries.sh
git diff --check
```

Expected: PASS.

### Task 4: Retain readiness and final code review without duplicate machinery

**Files:**
- Modify: `skills/analyze/SKILL.md`
- Modify: `skills/implement/SKILL.md`
- Modify: `skills/x-develop/{SKILL.md,project-tasks.sh,record-terminal.sh,result-contract.sh}`
- Modify: `tests/{check-implement-handoff.sh,check-x-develop-adapter.sh}`
- Test: `tests/check-review-boundaries.sh`

**Interfaces:**
- Consumes: normal spec, plan, and tasks artifacts; the existing SDD ledger and review package.
- Produces: one readiness decision from `analyze` and the unchanged SDD final-review receipt.

- [ ] **Step 1: Make analysis the named readiness boundary**

Remove marker-specific provenance and independent-context parsing from `analyze` and `implement`. Preserve the existing analysis requirement to finish before implementation, and document it as the review of current design and tasks before code begins.

- [ ] **Step 2: Remove marker branching from SDD adapters only**

Delete `replay_contract` detection from the x-develop adapters. Preserve immutable task projection, task reconciliation, reviewer identity, fix rounds, and the terminal receipt. Use the existing ordinary task projection for every spec.

- [ ] **Step 3: Keep final-review ownership intact**

Assert that no Maxi skill introduces a second final code-review protocol and that upstream SDD still owns task review, fix rounds, and its final implementation review.

```bash
bash tests/check-x-develop-adapter.sh
bash tests/check-implement-handoff.sh
bash tests/check-review-boundaries.sh
```

Expected: all pass with no bounded-replay dependency.

### Task 5: Delete obsolete tests and synchronize documentation and ADRs

**Files:**
- Delete: `tests/check-bounded-replay.sh`, `tests/check-x-review.sh`, `tests/fixtures/bounded-replay/`
- Modify: `tests/{check-templates.sh,check-skills-present.sh,check-skill-count.sh,run-all.sh}`
- Create: `docs/maxi/adr/0022-fixed-review-boundaries.md`
- Modify: `docs/maxi/adr/{0019-bounded-forward-artifact-replay.md,0020-persisted-independent-handoff-reviews.md}`
- Modify: `docs/pipeline-flow.md`, `docs/delegation-map.md`, `skills/using-maxi/SKILL.md`, `AGENTS.md`, `docs/architecture.md`, `README.md`

**Interfaces:**
- Consumes: the fixed-boundary behavior from Tasks 2 through 4.
- Produces: one documented 19-skill pipeline and an ADR supersession chain.

- [ ] **Step 1: Remove the old test surface**

Delete the planner fixtures and both old checks. Replace every test inventory reference with `check-review-boundaries.sh`; make the template and skill-count tests assert `review/`, `reviews/design-review.md`, and the absence of replay metadata.

- [ ] **Step 2: Record the architecture decision**

Create ADR-0022, superseding ADR-0019 and ADR-0020. Its decision is the three fixed review boundaries, explicit re-review after corrections, and retained SDD final review. Update the old ADRs’ `superseded_by` fields only to point to 0022.

- [ ] **Step 3: Update every public pipeline description atomically**

Update the Mandatory Sync 5 documents and README to say: 13 user-facing, 2 internal, 1 session, and 3 migration skills; fixed design/readiness/final review boundaries; no replay marker, graph, or auto-re-review; unchanged ten-state FSM and SDD final ownership.

- [ ] **Step 4: Run documentation guards**

```bash
bash tests/check-templates.sh
bash tests/check-skills-present.sh
bash tests/check-skill-count.sh
git diff --check
```

Expected: all pass and no active document mentions bounded replay except the superseded ADR history.

### Task 6: Run the full suite and request final independent reviews

**Files:**
- Verify: all files changed by Tasks 1 through 5
- Test: `tests/run-all.sh`

**Interfaces:**
- Consumes: the complete fixed-boundary diff.
- Produces: verified implementation evidence and review findings, without auto-fixing a finding.

- [ ] **Step 1: Run the complete deterministic suite**

```bash
bash tests/run-all.sh
git diff --check
git status --short
```

Expected: all fast checks pass and the only changes are the planned review-boundary files.

- [ ] **Step 2: Run prose consistency review**

Use `maxi:doc-consistency` to check the Mandatory Sync 5 documents and README for contradictory review terminology.

- [ ] **Step 3: Request end-of-work independent review**

Request at least one fresh whole-diff review through `superpowers:requesting-code-review`; the user may request additional independent reviewers at this final boundary. If a finding needs a correction, correct it once, rerun the affected checks, and request a new final review only when explicitly authorized.

- [ ] **Step 4: Prepare handoff without committing**

Show `git diff --check`, the exact changed-file list, test evidence, and a proposed commit message:

```text
fix(pipeline): replace bounded replay with fixed review boundaries
```

Wait for explicit authorization before staging or committing.
