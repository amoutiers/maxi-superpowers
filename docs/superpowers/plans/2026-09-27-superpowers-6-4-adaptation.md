# Superpowers 6.4.2 Adaptation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate exact Superpowers v6.4.2 into Maxi while preserving governed SDD evidence, lean planning and supported harness behavior.

**Architecture:** Prepare Maxi's existing validation boundaries before the upstream import. Preserve planning and review content through existing owners, then port the new host surfaces into Maxi-owned adapters. Keep the product's `/maxi:implement` on SDD, regardless of the execution method selected for this repository maintenance plan.

**Tech Stack:** Bash, AWK, Node.js standard library, JSON/YAML manifests, Markdown, existing shell and installed-Codex integration runners. No added dependency.

**Spec:** [2026-09-27-superpowers-6-4-adaptation-design](../specs/2026-09-27-superpowers-6-4-adaptation-design.md), approved by the user on 2026-09-27.

## Global Constraints

- Target Superpowers v6.4.2, `8ca22dba9a94f28898bbce59f2537ff4d87c747d`, through the existing subtree bump and sync scripts; preserve exact upstream bytes.
- Preserve the 19 Maxi-native skills, ten FSM states, three review boundaries and current task/status owners. The target inventory is 15 upstream skills plus 19 native skills.
- Preserve immutable projections, predecessor ledgers, historical receipts, decision-input digests and complete `Ruling:` lines.
- Preserve project gating for executable bootstrap and documented host-specific limitations.
- Add no runtime dependency, duplicate executor, general test framework or replacement importer.
- Write project artifacts in English. Author native skill edits through `superpowers:writing-skills` and its RED/GREEN cycle.
- Update all five Mandatory Sync files in each pipeline-affecting commit; the complete fast tier must pass before a local commit.
- Record architecture through the existing ADR approval procedure; remote publication, pushes, merges and pull requests require explicit authorization.
- Distinguish deterministic, installed-agent, native harness and publication evidence. Missing native acceptance remains an open gate.

## Review Focus

- A completed v1 migration has no selected tasks but does have real implementation history: fresh review must remain possible. Task 1 pairs that positive case with empty-range rejection.
- A foreign or symlinked marker exists in a predecessor workspace: resumed consumers must reject without altering any evidence. Task 2 tests current and predecessor ownership through every consumer.
- Postformatting retains task headings but loses assertions or Review Focus: Task 4 checks template, canonical output, projection, task brief and final-review context separately.
- One invalid OpenCode V2 skill registration disables the entire plugin: Task 6 exercises a rejecting `draft.add` and verifies other skills and bootstrap survive.
- A Muse manifest works today but is skipped by the next release bump: Task 7 tests manifest versions and both release commit inventories.

---

## File Responsibilities and Execution Rules

| Files | Responsibility |
| --- | --- |
| `skills/x-develop/{project-tasks,record-terminal,result-contract}.sh` | Shared projection/lineage ownership and terminal range validation |
| `tests/check-x-develop-adapter.sh`, `tests/fixtures/x-develop-adapter/` | Existing executable adapter regressions and canonical fixture payloads |
| `scripts/bump-superpowers.sh`, `scripts/sync-superpowers.sh` | Existing import mechanism, used without replacement |
| `vendor/superpowers/`, vendored directories under `skills/`, `VENDORED.md` | Exact upstream source, synchronized skills and pin |
| `skills/plan/`, `skills/specify/`, `skills/review/design-operation.md`, `skills/x-develop/SKILL.md` | Maxi-owned planning, requested destinations and final evidence handoff |
| `.opencode/plugins/maxi.js`, new `index.js`, `package.json` | V1/V2 adapter and package entrypoint |
| New `.muse-plugin/{plugin,marketplace}.json`, `hooks/session-start` | Muse discovery and observed bootstrap protocol |
| `.agents/skills/release/SKILL.md` and release tests | Version/staging inventory; retain `.claude/skills/release` symlink |
| Existing integration runners plus the focused upgrade scenario in Task 8 | Installed behavior and end-to-end evidence |

**Mandatory Sync set:** `docs/pipeline-flow.md`, `docs/delegation-map.md`, `skills/using-maxi/SKILL.md`, `AGENTS.md`, `docs/architecture.md`. Any task below changing a pipeline contract includes the affected statements in all five files in the same commit.

Paths are repository-relative. Use the existing clean delivery worktree and preserve unrelated changes. All tasks run sequentially because they share adapter tests, skills and documentation. Extend existing tests rather than introduce a parallel test framework.

Before Task 3 adoption, propose the full successor to ADR-0021 through `x-adr` and obtain its explicit approval. Allocate its number only when recording it. Use the standalone `spec: null` convention and link this Superpowers design in the ADR body. Keep ADR-0027's completed-migration guarantee. This plan does not fabricate a Maxi spec/status to manage the user-selected Superpowers workflow.

For every code/skill task, save RED command and decisive assertion, then GREEN evidence. Run `bash tests/run-all.sh` before its commit. Stage exact owned files and inspect the staged list. Installed Codex runners require a clean source checkout: commit the fast-verified task first, run its installed checks, and fix any failures in a subsequent verified commit before continuing. That checkpoint is not installed acceptance.

### Task 1: Preserve completed migration under strict review ranges

**Files:** Modify `skills/x-develop/record-terminal.sh`, `skills/x-develop/result-contract.sh`, `skills/x-develop/SKILL.md`, `tests/check-x-develop-adapter.sh`, and the Mandatory Sync set.

**Interfaces:** Preserve `record-terminal.sh --worktree ROOT --merge-base BASE --projection FILE --ledger FILE --final-review FILE --spec FILE --tasks FILE --output FILE` and `result-contract.sh --tasks FILE --receipt FILE`. Extend each existing `verify_package_bytes(worktree, projection, start, end, package, expected)` shell function before it invokes upstream. Success remains exit 0; rejected terminal evidence remains exit 2 without `READY_TO_FINISH`.

- [ ] **Step 1: Add regression cases.** Repair `An all-completed v1 upgrade needs fresh, real terminal review evidence.` using a genuine fixture implementation commit and its prior base, with distinct recorded reviewed head/tree. Preserve the zero-selection successor and fresh-review requirement. Add `equal full range rejected`, `equal fix range rejected`, `nonancestor range rejected` and `historical zero-range receipt rejected` cases. Snapshot any existing receipt before each rejection.
- [ ] **Step 2: Establish RED.** Run `bash tests/check-x-develop-adapter.sh` on v6.3.0. The new equal-range acceptance assertions must expose current permissiveness; already-covered negative cases may pass. The repaired positive migration must pass, establishing that the fixture preserves the intended behavior.
- [ ] **Step 3: Implement the boundary check.** In both existing package verifiers, require resolved commit endpoints, strict ancestry and a nonempty commit range before package regeneration. Keep byte-exact package comparison. Through `writing-skills`, specify recovery from the recorded original implementation base and fresh review, never fabricated commits or relaxed vendor guards.
- [ ] **Step 4: Establish GREEN.** Run the adapter suite, then the full fast tier. Expected fixture assertions include:

```bash
assert_eq "$empty_selection_status" 0 'real-history empty selection succeeds'
assert_eq "$equal_range_status" 2 'equal full range rejected'
assert_eq "$(sha "$prior_receipt")" "$prior_receipt_sha" 'rejection preserves receipt'
assert_not_has "$rejected_output" 'READY_TO_FINISH' 'invalid range cannot complete'
```

Capture these values in the named existing fixture scopes; retain the separate absent-receipt assertion. Check the same cases in a disposable next-pin copy, without changing the delivery pin yet.
- [ ] **Step 5: Commit.** `fix: preserve migration reviews with nonempty Git ranges` after full fast PASS and atomic Sync-5 updates.

### Task 2: Bind upstream workspace ownership to Maxi lineage

**Files:** Modify `skills/x-develop/project-tasks.sh`, `skills/x-develop/SKILL.md`, `tests/check-x-develop-adapter.sh`, and the Mandatory Sync set. Exercise existing `reconcile-tasks.sh`, `record-terminal.sh` and `result-contract.sh` through their current calls to projection verification.

**Interfaces:** Preserve `project-tasks.sh --spec FILE --plan FILE --tasks FILE --output FILE --state-file FILE [--verify-only]`. Add one internal `validate_workspace_owner(projection, root)` shell validator, exit 0 for an admissible marker state and nonzero otherwise. Call it at current, predecessor and candidate workspace boundaries before reuse/publication. Existing lineage validation remains mandatory when a legacy marker is absent.

- [ ] **Step 1: Add owner regressions.** Cover fresh absent marker, validated legacy absence, exact marker, foreign marker, empty/multiline marker, regular-file replacement and symlink marker, including a dangling symlink. Use the upstream repo-relative projection identity, followed by LF, for the valid case. Repeat foreign/predecessor cases through projection, reconciliation and both terminal consumers.
- [ ] **Step 2: Establish RED.** Run `bash tests/check-x-develop-adapter.sh`. Expect the new foreign-owner rejection to fail before the guard exists. For each failure-path invocation, preserve hashes of canonical tasks, pointer, projection, ledger and receipt and inventory workspace directories.
- [ ] **Step 3: Implement the shared validator.** Compare safe existing markers with the pinned helper's physical canonical plan identity. Reject foreign/unsafe markers without following a suffixed workspace. Allow missing markers only for fresh creation or independently validated legacy lineage. Keep `--verify-only` read-only. Document the pre-dispatch check that upstream `sdd-workspace PLAN_FILE` resolves the already-bound workspace.
- [ ] **Step 4: Establish GREEN.** Run the adapter suite on the current pin and the ownership cases against the next-pin snapshot. Assertions for each rejected consumer include:

```bash
assert_eq "$consumer_status" 2 'foreign owner fails closed'
assert_eq "$after_snapshot" "$before_snapshot" 'authoritative bytes and directories unchanged'
assert_eq "$upstream_workspace" "$bound_workspace" 'valid marker resolves bound workspace'
```

The snapshots cover current and predecessor evidence. Verification-only with an absent marker must leave it absent. Run the full fast tier.
- [ ] **Step 5: Commit.** `fix: validate SDD workspace ownership before evidence reuse` with Sync-5 updates.

### Task 3: Import exact v6.4.2 and close version inventory

**Files:** Import `vendor/superpowers/`; synchronize vendored `skills/`; modify `VENDORED.md`, `tests/check-version-consistency.sh`, `README.md`, and the Mandatory Sync set. Record the approved ADR successor through its owner, without rewriting historical bodies.

**Interfaces:** Existing `bash scripts/bump-superpowers.sh v6.4.2`, which performs a subtree pull, synchronization and pin update. Existing `bash scripts/sync-superpowers.sh` remains the only skill copier. The pin must agree with `vendor/superpowers/.claude-plugin/plugin.json`'s `version`.

- [ ] **Step 1: Verify preconditions.** Confirm ADR approval and the exact tag commit `8ca22dba9a94f28898bbce59f2537ff4d87c747d`. Run the complete fast tier and require a clean delivery checkout before the subtree operation, which creates local history. Resolve provenance conflicts through the existing import process.
- [ ] **Step 2: Prove the missing version check.** In an isolated fixture copy, mismatch the vendor manifest version and `VENDORED.md`; run `bash tests/check-version-consistency.sh` and record its current false pass. Do not mutate the delivery vendor for this test.
- [ ] **Step 3: Import and enforce the version check.** Run the bump script, then compare the actual vendor manifest with the pin in the existing checker. Update current inventories to 15 upstream plus 19 native skills. Preserve Maxi's independent design reviewer when the obsolete upstream plan-reviewer prompt disappears. Keep native harness qualification explicitly pending until Tasks 6 and 7.
- [ ] **Step 4: Verify.** Require the isolated mismatch check to exit nonzero and matching manifests to pass. Run `bash tests/check-sync-invariant.sh`, `bash tests/check-version-consistency.sh`, `bash tests/check-x-develop-adapter.sh`, then the full fast tier. In a disposable package with execute bits removed, run SDD helpers through Bash and verify nested calls succeed. Report Native-only failures separately; do not hand-edit vendor bytes.
- [ ] **Step 5: Commit import closure.** Retain generated subtree history and commit the verified skills/pin/docs/checker closure as `chore: adopt superpowers v6.4.2`.

### Task 4: Preserve lean plans and explicit design destinations

**Files:** Modify `skills/plan/SKILL.md`, `skills/plan/plan-template.md`, `skills/specify/SKILL.md`, `skills/review/design-operation.md`, `tests/check-templates.sh`, `tests/check-review-boundaries.sh`, `tests/check-x-develop-adapter.sh`, `tests/fixtures/x-develop-adapter/plan.md`, `tests/integration/design-cases/cases.json`, and the Mandatory Sync set.

**Interfaces:** Canonical plans gain exactly one `## Review Focus`; retain exactly one `## Global Constraints`. Existing `maxi-v2` full-body projection and upstream `task-brief PLAN_FILE N` remain unchanged. Review Focus belongs in the plan/projection preamble; task-local interfaces and assertions belong in the extracted brief.

- [ ] **Step 1: Add content and owner cases.** Add exact fixture text `parse_count(text: str) -> int` and `assert parse_count("0") == 0` to one mapped task. Add a justified Review Focus case plus an explicitly empty-after-scan case. Add installed case names `lean-plan-only` and `settled-sdd-design`, with allowed canonical artifact paths, required sections/assertions and no tasks/analysis/source writes.
- [ ] **Step 2: Establish RED.** Run the template/review-boundary/adapter checks. Require missing Review Focus guidance to fail; existing payload preservation can already pass. For installed RED, create a disposable source copy containing only the new integration cases over the pre-change skills, pass its fast tier and commit that fixture checkpoint. Run the new cases there to capture behavioral baseline without committing failing deterministic checks in the delivery branch. The case prompt must not invite answers to already-settled choices.
- [ ] **Step 3: Adapt native instructions through writing-skills.** Preserve lean upstream content during postformatting. Retain requested destinations and owner-only returns, suppress a nested execution menu and reuse scoped answers. Do not suppress genuine unanswered design questions or the existing coordinated review. New plans preserve zero to five justified focus entries with tests in their owning tasks.
- [ ] **Step 4: Verify deterministic content.** Assert exact counts and payloads in the applicable generated files:

```bash
assert_eq "$(grep -c '^## Review Focus$' "$projection")" 1 'one projected focus section'
assert_has "$task_brief" 'parse_count(text: str) -> int' 'brief retains interface'
assert_has "$task_brief" 'assert parse_count("0") == 0' 'brief retains assertion'
```

Run all three targeted checks and the full fast tier, then commit `feat: retain lean planning through Maxi design owners` with Sync-5 updates.
- [ ] **Step 5: Verify installed behavior.** From the clean committed checkout run `bash tests/integration/run-codex-design-test.sh lean-plan-only`, `bash tests/integration/run-codex-design-test.sh settled-sdd-design`, then `bash tests/integration/run-codex-design-test.sh all`. Expect byte-checked installed reads, exact requested destinations and the existing bounded review count. A failing or timed-out case blocks this task's acceptance.

### Task 5: Carry final-review context and declined-behavior dispositions

**Files:** Modify `skills/x-develop/SKILL.md`, `tests/check-x-develop-adapter.sh`, and the Mandatory Sync set. Preserve existing terminal helper interfaces and schemas.

**Interfaces:** The existing final reviewer receives canonical spec/plan and Review Focus in its initial review context. Its complete output remains in `maxi-final-review.md`; controller dispositions use existing complete `Ruling:` ledger lines and the receipt's `rulings_sha256`.

- [ ] **Step 1: Add review evidence cases.** Add a review with `Declined to judge` and a controller line containing `Ruling: deferred startup behavior; reason: host unavailable`. Assert exact persistence/reload, returned lineage output and terminal hash invalidation after changing that complete line. Reject a Native `Task 1: complete (commits <7hex>..<7hex>, tests: passed)` record through every completion consumer, substituting real fixture commit IDs.
- [ ] **Step 2: Establish RED.** Run the adapter suite for deterministic behavior, plus writing-skills' focused controller scenario for missing final-review context/disposition instructions. Existing generic ruling preservation may already pass; do not rewrite working validators just to produce a diff.
- [ ] **Step 3: Adapt the handoff.** Through `writing-skills`, require the existing reviewer to receive the approved plan context, preserve all review output and record the controller's disposition. Reuse the sole whole-branch review, reviewer identity handshake, fix round and terminal receipt.
- [ ] **Step 4: Establish GREEN and commit.** Run the focused skill scenario, adapter suite and full fast tier. Require exact ruling bytes and no additional reviewer/receipt schema. Commit `feat: preserve upstream review context and dispositions` with Sync-5 updates. Task 8 supplies live final-review evidence.

### Task 6: Port OpenCode compatibility into the Maxi adapter

**Files:** Modify `.opencode/plugins/maxi.js`, `package.json`, `.opencode/INSTALL.md`, `tests/check-opencode-plugin.sh`, `tests/check-bootstrap-parity.sh`, `README.md`, `docs/architecture.md`; create `index.js` and `tests/opencode/test-host-compatibility.mjs`.

**Interfaces:** Preserve `export const MaxiPlugin = async ({ client, directory }) => hooks`. Add default `{ id: 'maxi', server: MaxiPlugin, setup }`, with `async setup(ctx)` accepting the pinned V2 domains and returning without registration for a V1-shaped context. V2 skill records use `{ id, name, description?, path, content }`, not `location`. Root `index.js` re-exports the named plugin and default. Set `package.json` main to that root entrypoint. The test script accepts `PLUGIN_PATH` as its only argument.

**Host preflight:** The pinned upstream adapter does not implement Maxi's project gate. Confirm the V2 host's project-root source from its actual schema/session payload before defining that fixture; do not invent a `ctx.directory` field or assume the plugin process cwd represents every project. Record the observed interface in the test. If no reliable project identity is available, keep V2 adoption blocked rather than inject bootstrap into an unknown project.

- [ ] **Step 1: Add host-shaped tests.** Adapt pinned upstream registration/session fixtures into the single focused Node test. Cover both module entrypoints, 34 real skill paths, V1 setup tolerance, repeated transforms, root/child/fork, compaction/fresh contexts, transient identity lookup failures, plain-then-Maxi project caches and hostile `draft.add`. Wire it into `check-opencode-plugin.sh`, already called by the fast tier.
- [ ] **Step 2: Establish RED.** Run `node tests/opencode/test-host-compatibility.mjs .opencode/plugins/maxi.js`. Missing V2 setup/root export must fail. Host fixture assertions include:

```javascript
assert.equal(mod.default.id, 'maxi');
assert.equal(registered.length, 34);
assert.ok(registered.every(s => typeof s.path === 'string' && !('location' in s)));
assert.equal(bootstrapCount(rootEvent), 1);
assert.equal(bootstrapCount(childEvent), 0);
assert.equal(survivors.length, 33); // one deliberately rejected registration
```

Use the pinned upstream `makeHarness`, `makeEvent` and bootstrap-count patterns with Maxi project fixtures, rather than inventing host payloads.
- [ ] **Step 3: Port the adapter.** Reuse upstream V1/V2 registration and session handling, preserving Maxi text, gate and per-project cache. Match `ctx.skill.transform` and `ctx.session.hook('context', callback)` to the pinned implementation; verify host documentation before relying on any additional field. Contain a rejected skill registration so other skills and bootstrap survive.
- [ ] **Step 4: Verify and commit.** Run the Node test, `bash tests/check-opencode-plugin.sh`, `bash tests/check-bootstrap-parity.sh`, and the full fast tier. Commit `feat: support OpenCode V2 with Maxi project gating`.
- [ ] **Step 5: Qualify native hosts.** Capture local V1 and V2 2.0.4+ sessions for installation entrypoints, skill discovery, root/child behavior and compaction. Keep host versions and logs for Task 8. An unavailable host is an open native gate, not a mock-based PASS.

### Task 7: Add Muse/Qwen surfaces and release coverage

**Files:** Create `.muse-plugin/plugin.json` and `.muse-plugin/marketplace.json`; modify `hooks/session-start`, `tests/check-hooks.sh`, `tests/check-declarative-harnesses.sh`, `.agents/skills/release/SKILL.md`, `tests/check-release-skill.sh`, `README.md`, `docs/architecture.md`. Preserve the `.claude/skills/release` symlink.

**Interfaces:** Follow the pinned Muse `schemaVersion: 1`, `compat: { source: 'native', manifestDir: '.muse-plugin' }` and skill `{ id, path }` records. Use Maxi identity and the current `package.json` version, not upstream's plugin version. Hook command invokes Bash. The marketplace's relative source is `./`; extend the existing release version/staging inventory without inventing a remote pin schema. Qwen reuses the existing Claude marketplace surface.

- [ ] **Step 1: Establish the host protocol.** Compare pinned Muse source/docs with an isolated actual local hook session. Determine the accepted context JSON shape and environment precedence. Record the observed answer before implementing a branch; an unavailable host leaves this protocol choice unresolved, rather than copying conflicting upstream comments as authority.
- [ ] **Step 2: Add failing packaging/release checks.** Require all 34 unique existing skill paths, current Maxi version in plugin and marketplace, and no upstream branding/contact metadata. Cover Muse-only and Muse+Claude environment cases, no bootstrap outside `docs/maxi/`, and Bash interpreter execution. Assert both version-bearing files occur in release instructions/staging at the appropriate existing commit boundary.
- [ ] **Step 3: Establish RED.** Run `bash tests/check-hooks.sh`, `bash tests/check-declarative-harnesses.sh` and `bash tests/check-release-skill.sh`. Expect missing Muse packaging/branch/inventory failures. Store exact expected hook JSON assertions from Step 1 in the existing hook tests.
- [ ] **Step 4: Implement the surfaces.** Add the manifests and verified hook branch, then author the release-skill adjustment through `writing-skills`. Preserve the existing two-commit release scheme. Document Qwen installation from the actual supported marketplace mechanism and any observed declarative gate limitation.
- [ ] **Step 5: Verify and commit.** Require all targeted checks and full fast tier PASS; commit `feat: add Muse and Qwen integration surfaces`. Qualify native Muse and Qwen discovery/bootstrap with verified CLI syntax in isolated local configuration. Retain evidence for Task 8; no remote installation/publication is inferred.

### Task 8: Qualify the complete installed upgrade

**Files:** Create focused `tests/integration/run-codex-upgrade-test.sh`, `tests/integration/upgrade-cases/check-evidence.py`, `tests/integration/upgrade-cases/test-checker.py`; modify `tests/integration/run-all.sh` and `tests/check-integration-harness.sh`. Record results in new `docs/superpowers/qualification/2026-09-27-superpowers-6-4-adaptation.md`; reconcile README and the Mandatory Sync set. Existing trigger/readiness/design/Git-closure runners remain in place.

**Interfaces:** `bash tests/integration/run-codex-upgrade-test.sh` runs the focused upgrade scenario; `python3 tests/integration/upgrade-cases/check-evidence.py EVIDENCE_DIR` returns 0 only for complete evidence and nonzero for missing/invalid/unknown evidence. Reuse installed snapshot staging, external fixture isolation, `run-with-deadline.pl` and event-evidence patterns from existing runners. This is the missing end-to-end scenario, not a general replay framework.

- [ ] **Step 1: Pin the checker contract with negative tests.** Require exact installed snapshot reads, actual design/readiness outputs, task reconciliation, reviewer allocation/follow-up identity, real Git package endpoints, terminal receipt validation, and observed completion/Git-closure order. In stdlib tests, remove each required evidence component from one complete fixture and assert rejection. Timeout, unknown dispatch shape, synthetic terminal verdict and changed installed bytes must never pass. Wire checker tests into the existing fast harness check.
- [ ] **Step 2: Establish RED.** Run `python3 tests/integration/upgrade-cases/test-checker.py`; require the missing checker to fail, then implement its file/event assertions until injected incomplete evidence is rejected. Deterministic fixtures test the checker only.
- [ ] **Step 3: Add the live scenario.** In an external isolated Git fixture, create a lean plan through real owners, obtain current design approval, extract tasks, obtain readiness and execute SDD. Arrange a controlled stop after the first durably completed task; resume with a later task pending. Require the completed task not to run again. Run fresh final review over real history, validate the receipt, then observe `done` and Git closure. Add a completed-v1 migration continuation with a real original range and fresh reviewer evidence. Retain real declined-behavior dispositions when reported; never inject a claimed live reviewer verdict.
- [ ] **Step 4: Verify the runner and checkpoint.** Extend existing timeout/staging/event guards for this runner. Run the focused checker tests, `bash tests/check-integration-harness.sh` and full fast tier. Commit the test harness as `test: qualify the installed superpowers upgrade lifecycle` with the affected Sync-5 test descriptions, leaving a clean source checkout.
- [ ] **Step 5: Run acceptance.** Invoke `bash tests/run-all.sh --integration`, including the new scenario, and collect Tasks 6/7 native evidence. Require zero deterministic/installed failures. Retain interrupted-run snapshots and reject incomplete evidence instead of retrying it into a claimed success without diagnosis.
- [ ] **Step 6: Record qualification.** Write source/host versions, commands, exit codes, retained evidence paths and unresolved native gates to the qualification document. Apply local `doc-consistency`; reconcile affected version/count/workflow statements within the already-approved adaptation scope. Do not alter unrelated semantics. Any missing host/protocol evidence prevents full adaptation/release-readiness claims.
- [ ] **Step 7: Commit and hand off.** Run the full fast tier after final edits and commit `docs: record superpowers 6.4 adaptation qualification`. Return through the execution method's normal final-review and branch-finishing flow. Review this repository maintenance branch according to that selected method; the fixture's Maxi review does not replace it. Publication requires its own authorization.

## Dependency and Coverage Check

| Tasks | Spec coverage | Acceptance |
| --- | --- | --- |
| 1, 2 | Ranges, completed migrations, workspace ownership | Current-pin and next-pin positive/negative evidence |
| 3 | Exact vendoring, inventory, architectural record | Real version/source identity and synchronized bytes |
| 4, 5 | Lean plans, requested destinations, review context, Native exclusion | Deterministic payload tests and installed-owner evidence |
| 6 | OpenCode V1/V2 | Host-shaped tests plus native sessions |
| 7 | Muse/Qwen, bootstrap, release inventory | Observed protocol, packaging checks and native sessions |
| 8 | Full flow, resume, migration, documentation and qualification | Complete installed evidence and explicit remaining gates |

All eight tasks are sequential; Task 3 depends on Tasks 1 and 2 and the approved architecture record. Each Review Focus case has an owning regression. No ordinary implementation bodies, new product phase, new Maxi-native skill or vendored fork is proposed. The user reviews this plan and selects its execution method before implementation.
