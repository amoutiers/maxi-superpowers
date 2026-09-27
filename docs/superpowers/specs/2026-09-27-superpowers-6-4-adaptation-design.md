# Superpowers 6.4.2 Integration into Maxi

- Date: 2026-09-27
- State: Proposed design, awaiting user review
- Baseline: Maxi `3fab96ac92a740ea8f9e3f91bf2231cf08ccb35d`, vendored Superpowers v6.3.0
- Target: Superpowers v6.4.2, `8ca22dba9a94f28898bbce59f2537ff4d87c747d`

## Intent

Adapt Maxi to the new Superpowers release, repair demonstrated compatibility failures and preserve Maxi's evidence and workflow guarantees. The user requested an integration study and remediation proposal, then selected a Superpowers specification as the design artifact.

This document follows the Superpowers design workflow. It does not create a Maxi pipeline feature or change any product pipeline status. Its proposed scope includes the engine upgrade, planning/review compatibility, OpenCode V2, Muse and Qwen. These scope choices await review of this document.

Success means the exact upstream release is integrated without a vendored fork, completed work remains safely resumable, new plan content survives Maxi's wrappers, and each claimed harness has appropriate qualification evidence.

## Findings and Evidence

### Confirmed compatibility failure

A disposable clone of the committed Maxi baseline received the exact v6.4.2 tree and ran `bash scripts/sync-superpowers.sh`. Synchronization copied 15 upstream skills alongside the existing 19 Maxi-native skills.

`bash tests/run-all.sh` exited 1: 34 top-level checks passed and the SDD adapter check failed with `empty commit range: <SHA>..<same SHA>`.

The failing scenario in [check-x-develop-adapter.sh](../../../tests/check-x-develop-adapter.sh), identified by `An all-completed v1 upgrade needs fresh, real terminal review evidence.`, generates a final-review package with identical base and head. Upstream now rejects such packages. The scenario's requirement for fresh review remains valid; its zero-commit fixture must change.

Omitting only that block in a disposable diagnostic copy allowed the remainder of the adapter suite to pass. This establishes the immediate failing seam, not acceptance of an upgrade. Removing the scenario is not an acceptable fix. Version documentation stayed at v6.3.0 in that experiment, so its passing version check also does not establish a completed bump. No installed-agent or native harness acceptance was performed.

### Changes requiring adaptation

| Surface | Upstream change | Maxi impact |
| --- | --- | --- |
| Review packages | Reject empty and non-descendant commit ranges before output | Repair migration fixtures and validate current terminal evidence against the stricter range contract |
| SDD workspace | Adds `plan-path` ownership and selects a suffixed directory on collision | Maxi currently binds projection and terminal evidence to a basename-derived workspace; prevent divergent ledger selection |
| Plans | Review Focus and lean task descriptions with interfaces and assertions | Preserve the new content through the Maxi template, projection and reviewer handoff |
| Design handoff | Stronger artifact approval wording and Native/SDD execution selection | Preserve explicit Maxi owner destinations and existing authorization scope |
| Final review | Reasonable-user behavior assessment and `Declined to judge` | Retain complete review output and the controller's dispositions |
| Native execution | `tests:` completion records and a different fix-review contract | Import the skill but keep it outside `/maxi:implement` |
| OpenCode | V1 and V2 exports, directory entrypoint and session lifecycle handling | Port the supported host interfaces into Maxi's own adapter |
| Muse and Qwen | New packaging/bootstrap and marketplace support | Add Maxi packaging, release inventory and native qualification |

The workspace-collision risk is source-derived, not reproduced by the fast-tier experiment. Establish a focused regression before changing it. Upstream Muse comments and emitted hook format disagree; actual host behavior must determine the adopted protocol.

## Approach and Alternatives

**Recommended: exact upstream import with focused Maxi adaptations.** Retain SDD as the governed execution engine, reuse existing validators and host adapters, and change only the compatibility boundaries identified above. This preserves upstream maintenance and Maxi's existing evidence model.

**Plain dependency bump:** smallest initial diff, but the reproduced adapter failure and Maxi-owned host entrypoints make it insufficient.

**Adopt Native as another Maxi executor now:** expands the completion, review and recovery contracts. Defer this to a separate design if requested. A vendored fork is excluded by strict vendoring.

## Scope and Invariants

- Import all 15 upstream skills, including `diagnosing-superpowers`, using the existing subtree bump and sync scripts. Preserve exact upstream bytes.
- Preserve the 19 Maxi-native skills, ten FSM states, three review boundaries and current task/status owners.
- Preserve immutable projections, predecessor ledgers, historical receipts, decision-input digests and complete `Ruling:` lines.
- Preserve project gating for executable bootstrap and documented host-specific limitations.
- Add no runtime dependency, duplicate executor, general test framework or replacement importer.
- Keep installation, native acceptance and remote publication separate. This design authorizes no release or external mutation.

## Proposed Design

### 1. Review ranges and completed migrations

An empty task selection and an empty Git range are different states. A fully completed v1 lineage can still need a v2 successor and a fresh final review of its genuine prior implementation history.

Keep that migration supported. Obtain the original recorded branch base and the reviewed head from validated evidence. Both endpoints must resolve to commits, the base must be an ancestor of the head, and the range must contain a commit. Fix packages must satisfy the same nonempty ancestral-range requirement.

Repair the positive fixture with a real implementation change and its actual prior base. Add independent negative cases for equal endpoints, non-ancestor endpoints and historical zero-range receipts. Do not manufacture an empty commit, skip the migration test or weaken upstream checks.

Enforce the range contract at existing terminal generation and revalidation boundaries in [record-terminal.sh](../../../skills/x-develop/record-terminal.sh) and [result-contract.sh](../../../skills/x-develop/result-contract.sh). Invalid evidence produces no new success receipt and no `READY_TO_FINISH`. Preserve older receipts as history while rejecting incompatible current reuse. Recovery requires a genuine range and fresh review.

### 2. Workspace ownership

Keep Maxi's existing bound workspace and evidence schemas. Validate upstream `plan-path` in the shared projection/lineage path in [project-tasks.sh](../../../skills/x-develop/project-tasks.sh). Reconciliation and terminal helpers already invoke its verification mode; reuse that boundary.

A new workspace may start without a marker. An existing legacy workspace without a marker remains reusable only after its Maxi lineage validates. An existing marker must match the canonical plan identity emitted by the pinned upstream helper. Foreign, malformed or symlinked markers fail before dispatch or authoritative mutation.

Before invoking SDD, confirm that upstream resolves the already-bound workspace. Do not independently implement its collision allocator or follow an unbound suffixed directory. Verification-only calls create no directory, marker or successor and do not change tasks, pointers, ledgers or receipts.

### 3. Lean plans and review information

Update the Maxi plan template and wrapper to preserve one `Global Constraints` section and one `Review Focus` section. Global Constraints keeps its existing durable-rule semantics. Review Focus contains zero to five justified cases after an actual scan; each case identifies its owning task and test. Do not invent concerns to fill a quota.

Task bodies retain exact interfaces, assertions and verification commands without requiring ordinary implementation code bodies. The existing complete-body projection must preserve this information. Carry plan/spec context and Review Focus into the existing final reviewer; task-specific interfaces and assertions must survive upstream task-brief extraction.

Preserve complete final-review output. Record dispositions of `Declined to judge` behaviors through existing controller `Ruling:` lines and retain them across ledger reload and terminal receipts. No additional reviewer, verdict grammar or evidence schema is needed.

### 4. Maxi owner boundaries around upstream skills

The product's explicit destination remains authoritative: spec-only, plan-only, coordinated design review or execution through SDD. Preserve settled answers and existing scoped approvals when upstream brainstorming/planning runs within those owners.

Genuine unresolved design questions remain valid. Writing or approving a plan cannot start implementation. A plan-only return must not open an execution menu; `/maxi:implement` continues through `x-develop` and SDD. Native `tests:` completion records must not be accepted as reviewed SDD evidence.

Test these as installed-agent behaviors as well as deterministic contracts. An instruction string in a skill is insufficient proof that its enclosing owner returns correctly.

### 5. OpenCode V1/V2

Adapt [.opencode/plugins/maxi.js](../../../.opencode/plugins/maxi.js) from the pinned upstream implementation. Preserve the named V1 `MaxiPlugin` export, add the V2 default `{ id, server, setup }` shape and a root directory-install re-export. Target OpenCode V2 2.0.4 or later as supported by that implementation.

Use demonstrated `ctx.skill.transform` and `ctx.session.hook('context', ...)` interfaces. Retain Maxi identity, all 34 skill paths, project gating, project-specific caching and child-session exclusion. Exercise startup, continuation, restart, fork and compaction. Bootstrap must remain available in the appropriate root context without duplicate injection into one supplied context.

Reuse upstream host-shaped test patterns. Confirm both installation entrypoints and actual V1/V2 sessions before claiming native support.

### 6. Muse/Qwen and release inventory

Add Maxi Muse plugin and marketplace manifests using the verified upstream schema. Resolve Maxi identities and real skill files. Extend [hooks/session-start](../../../hooks/session-start) only for the observed Muse protocol, including precedence when Muse and Claude environment variables coexist. Its declared interpreter must support the actual Bash implementation; do not blindly copy an upstream `sh` command.

Qwen reuses the existing marketplace mechanism and needs installation documentation and local discovery qualification. Preserve executable project gates wherever the host supports them; document observed declarative limitations.

Extend the existing release skill and its tests for every added version-bearing manifest, staging list and marketplace pin. Preserve its two-commit release convention and the existing Claude release-skill symlink. No publication is part of this adaptation.

## Adaptation Sequence

This sequence describes dependencies and acceptance, not an executable implementation plan. A detailed Superpowers plan follows review of this specification.

| Order | Work | Exit condition |
| --- | --- | --- |
| 1 | Prepare range/workspace compatibility on v6.3.0 | Positive completed migration and negative range/owner cases pass on the current pin and against the next-pin helper snapshot |
| 2 | Import exact v6.4.2 through `scripts/bump-superpowers.sh` | Actual vendor version, documented pin and synchronized bytes agree; complete fast tier passes |
| 3 | Adapt lean planning and owner/reviewer handoffs | Projection preserves required content; installed agents respect requested design destinations |
| 4 | Port OpenCode V1/V2 | Host fixtures and actual V1/V2 sessions establish supported lifecycle and entrypoints |
| 5 | Add Muse/Qwen and release coverage | Manifest/version/hook checks pass and native discovery/bootstrap evidence is retained |
| 6 | Qualify the complete flow and reconcile docs | Installed flow, resume/migration, final review and terminal evidence pass; unsupported or unavailable host gates remain explicit |

Keep shared documentation changes sequential. Every pipeline-affecting implementation commit updates the existing Mandatory Sync five: [pipeline-flow](../../pipeline-flow.md), [delegation-map](../../delegation-map.md), [using-maxi](../../../skills/using-maxi/SKILL.md), [AGENTS.md](../../../AGENTS.md) and [architecture](../../architecture.md). Do not defer these updates to the final phase.

The delivery worktree must be clean before the subtree bump, which can create its own local commit. Run the complete fast tier first. Preserve unrelated checkout changes and resolve subtree provenance through the existing importer.

## Validation and Acceptance

| Layer | Required evidence |
| --- | --- |
| Deterministic adapter | Completed migration succeeds with a real nonempty range; empty/non-ancestor ranges and Native completion lines fail; foreign ownership leaves authoritative bytes unchanged |
| Plan content | One durable Global Constraints section, one bounded Review Focus section, exact interfaces/assertions preserved through projection and handoff |
| Packaging | 15 upstream plus 19 native skills; actual vendor manifest matches pin; V1/V2 exports, Muse manifests, interpreter and release inventory validated |
| Installed Codex | Actual installed skill snapshot read; spec-only/plan-only/coordinated boundaries, full execution, interruption/resume, review receipt and completion ownership observed |
| Native harnesses | Host version, installation form, commands and observed OpenCode V1/V2, Muse and Qwen session results retained |
| Documentation | Version, inventories and workflow statements agree; local doc-consistency review completed |

Use the existing fast tier (`bash tests/run-all.sh`) and installed suite (`bash tests/run-all.sh --integration`). Extend existing fixtures only where a required scenario is missing. Skill changes use `superpowers:writing-skills` and its RED/GREEN process.

Also exercise SDD helper invocation through Bash in a disposable package with executable bits removed. Report any limitation confined to the optional Native path separately; do not patch vendored bytes.

Record source identities, commands, exit codes, evidence locations and unresolved gates. A mock protocol or injected reviewer verdict does not establish native or live-review acceptance. An unavailable host remains an open gate; do not claim complete harness parity or release readiness.

## Architectural Records and Review Boundary

[ADR-0021](../../maxi/adr/0021-align-superpowers-v6-3-model.md) records the existing version/harness relationship. Propose its successor with the complete text for explicit approval before adopting the new relationship. This specification neither amends nor accepts an ADR.

[ADR-0027](../../maxi/adr/0027-complete-sdd-task-projections.md) requires fresh final review for completed migrations. The genuine historical range described here preserves that guarantee.

The user-selected Superpowers workflow governs this design artifact. Maxi's product pipeline guarantees remain part of the compatibility requirements. Review of this written specification precedes a detailed Superpowers implementation plan and selection of its execution method.

## Sources

- [Superpowers v6.4.2 release](https://github.com/obra/superpowers/releases/tag/v6.4.2).
- [Superpowers v6.4.1 release](https://github.com/obra/superpowers/releases/tag/v6.4.1).
- [Pinned upstream source](https://github.com/obra/superpowers/tree/8ca22dba9a94f28898bbce59f2537ff4d87c747d).
- Maxi baseline and disposable compatibility experiment described above. Findings are a dated design snapshot, not completed integration acceptance.
