---
slug: 0024-decision-input-freshness
spec_slug: 0024-decision-input-freshness
created: 2026-09-05
updated: 2026-09-05
---

# Decision Input Freshness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development through Maxi implement/x-develop after design and readiness gates. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reject design and readiness approvals when the governing constitution or ADR inputs differ from those reviewed.
**Architecture:** One native digest helper serves both versioned approval envelopes. Existing phase owners capture review inputs, stamp results, and verify before writes; upstream SDD is unchanged.
**Tech Stack:** Bash 3.2, awk, shasum, sort, existing shell tests and authenticated Codex integration.
**Spec:** [spec](spec.md).

## Summary

Readiness v1 currently returns READINESS_VERIFIED after a constitution-only edit. Design approval checks exact spec/plan bytes but does not bind constitution or referenced ADR content. Extend the two existing boundaries with a shared deterministic dependency digest and explicit legacy rejection.

## Technical Context

**Language/Version**: Bash 3.2-compatible scripts; native Markdown skills.
**Primary Dependencies**: Existing Unix tools; no new runtime dependency.
**Storage**: Existing review and analysis Markdown files; cleaned temporary manifest files.
**Testing**: Existing readiness, review-boundary and full fast suites; installed readiness lifecycle.
**Target Platform**: macOS and Linux.
**Project Type**: Multi-harness SDD plugin.
**Performance Goals**: One linear scan of direct ADR files per digest; no service or persistent cache.
**Constraints**: Fail closed, preserve source content and old evidence on failure.
**Scale/Scope**: Two approval gates and their installed consumers, audit F3.

## Global Constraints

- Preserve the 19 native skills, ten statuses, three review boundaries, explicit re-review and terminal correction behavior.
- Keep vendored skills byte-identical; use native supporting files rather than duplicate Superpowers workflows.
- Reject stale or malformed approvals before task extraction or implementation mutation/dispatch. Never silently upgrade old approvals.
- Preserve structural readiness rules: ignore only spec frontmatter status/updated, tasks updated and canonical checkbox progress; plan hashes remain exact.
- Use Bash 3.2 and existing tools/harnesses. Add no runtime dependency or generalized parser framework.
- Keep original inputs and historical evidence unchanged on failure. Resolve installed helpers from their loaded skill paths.
- Update Mandatory Sync 5 atomically with gate changes and preserve existing negative regressions.
- Write English project artifacts; use writing-skills RED/GREEN verification for native guidance changes.
- Run the full fast tier before local commits. Push, merge and PR actions require explicit authorization.

## Constitution Check

| Principle | Pass / Fail | Notes |
|-----------|-------------|-------|
| I. Mandatory pipeline | Pass | Canonical spec, clarification, plan, reviews, tasks and analysis precede implementation. |
| II. Delegate to Superpowers | Pass | Existing SDD remains execution and implementation-review owner. |
| III. No skipping | Pass | Changes strengthen existing gates, without automatic phase advancement. |
| IV. ADR capture | Pass | Propose superseding ADR-0026 for the v2 contract; persist only after draft approval. |
| V. Artifacts over chat | Pass | Deterministic envelopes bind file inputs. |
| VI. Single responsibility | Pass | Digest helper owns dependency identity; each contract owns its envelope. |

## Project Structure

### Documentation (this feature)

Spec and plan live in this directory. Design review, tasks and analysis are produced later by their phase owners.

### Source Code (repository root)

- New `skills/review/review-inputs.sh`: canonical decision-input digest.
- New `skills/review/design-contract.sh`: stamp/verify the design envelope.
- Existing `skills/analyze/readiness-contract.sh`: readiness v2.
- Native `review`, `tasks`, `analyze`, `implement` skills and review template: installed helper binding and before/after checks.
- Existing shell tests and readiness integration: regression and installed-consumer evidence.

**Structure Decision**: Reuse the existing readiness parsing, hashing and atomic-output patterns. Share only the actual cross-gate decision-input digest; avoid a generic contract framework.

## Decisions

Accepted [0028-decision-input-freshness](../../adr/0028-decision-input-freshness.md) supersedes [0026-hash-bound-readiness-evidence](../../adr/0026-hash-bound-readiness-evidence.md), because it replaces readiness v1 with v2. It complements [0022-fixed-review-boundaries](../../adr/0022-fixed-review-boundaries.md) and [0023-dedicated-design-review-contract](../../adr/0023-dedicated-design-review-contract.md): exact spec/plan and independent verdict rules remain.

## Complexity Tracking

No constitution violations. Conservative invalidation after any ADR change is accepted; selective dependency tracking is unnecessary for this lot.

### Task 1: Compute one canonical decision-input digest

**Files:** Create `skills/review/review-inputs.sh`; extend `tests/check-review-boundaries.sh` with executable digest cases and `tests/check-skills-present.sh` with helper presence; list support file in `docs/architecture.md`.

**Interfaces:** Proposed `bash review-inputs.sh hash PROJECT_ROOT` prints exactly one lowercase SHA-256 line; invalid input exits 2 with stderr and no stdout. No source writes. The explicit root is canonicalized to a physical absolute directory; reject symlinked supplied path components. Missing and empty ADR directories represent the same set.

- [ ] **Step 1: Add a fixture-backed RED cycle.** Reuse the existing test helpers. Create a temporary canonical docs/maxi root and constitution; add direct ADR Markdown files. Assert identical digests for reordered creation, absent/empty ADR sets, generated README edits and unchanged relocation. Independently assert changed digest for constitution bytes and ADR add/remove/rename/status/content. Negative fixtures cover missing constitution, unreadable input where platform permissions permit, symlinked components/files, control characters and nonregular entries. All fixtures clean only their own temporary paths.

```bash
before="$(bash "$INPUTS" hash "$CASE")"
printf '\nChanged rule.\n' >> "$CASE/docs/maxi/constitution.md"
after="$(bash "$INPUTS" hash "$CASE")"
[ "$before" != "$after" ] || fail 'constitution mutation changes digest'
```

- [ ] **Step 2: Run the added checks and preserve the missing-helper failures.** Run `bash tests/check-review-boundaries.sh`; do not replace existing assertions with weaker success criteria.
- [ ] **Step 3: Implement the minimal manifest pipeline.** Validate physical root/docs/maxi components and required regular constitution. For the optional flat ADR directory, reject symlinked entries and nonregular entries; ignore ordinary non-Markdown files and generated README.md. Reject control characters in candidate names before line-oriented enumeration. Include all other direct .md files regardless of status. Build in a cleaned system temporary directory, never under the client project. Hash only after every traversal/read succeeded.

```bash
# For each validated input, append one unambiguous record to the scratch manifest.
printf '%s\t%s\n' "$relative_name" "$(shasum -a 256 "$physical_file" | awk '{print $1}')" >> "$manifest"
LC_ALL=C sort "$manifest" > "$sorted_manifest"
shasum -a 256 "$sorted_manifest" | awk '{print $1}'
```

Use `set -euo pipefail`; explicitly propagate errors from enumeration and command substitutions. Set LC_ALL=C. Do not rely on GNU-only flags or add a JSON/YAML library. Include project-relative file names, not the absolute root, in manifest records.
- [ ] **Step 4: Run digest tests, support inventory checks and the full fast tier.** Verify rejected inputs emit no digest and leave all fixture source hashes unchanged. Review and commit the coherent helper deliverable.

### Task 2: Bind both approval intervals and installed consumers

**Files:** Create `skills/review/design-contract.sh`; modify `skills/analyze/readiness-contract.sh`, `skills/review/{SKILL.md,design-reviewer.md,review-template.md}`, `skills/tasks/SKILL.md`, `skills/analyze/SKILL.md`, `skills/implement/SKILL.md`; extend `tests/check-readiness-contract.sh`, `tests/check-review-boundaries.sh`, `tests/check-skills-present.sh`, `tests/check-implement-handoff.sh`, `tests/check-skill-count.sh`; update `tests/integration/run-codex-readiness-test.sh`, `tests/check-integration-harness.sh` and any exact-command fixtures found in their callers; synchronize Mandatory Sync 5.

**Interfaces:** Consume Task 1's `review-inputs.sh hash PROJECT_ROOT`. Proposed commands:

```text
readiness-contract.sh stamp ANALYSIS SPEC PLAN TASKS OUTCOME CRITICAL_COUNT PROJECT_ROOT EXPECTED_INPUTS_SHA256
readiness-contract.sh verify ANALYSIS SPEC PLAN TASKS PROJECT_ROOT
design-contract.sh stamp REVIEW SPEC PLAN VERDICT PROJECT_ROOT EXPECTED_INPUTS_SHA256
design-contract.sh verify REVIEW SPEC PLAN PROJECT_ROOT
```

Readiness success remains exactly READINESS_VERIFIED. Design success is exactly DESIGN_REVIEW_VERIFIED. Failure exits 2 without either success token. Stamp preserves the complete owner-written report body, using a temporary file and atomic rename only after validation; callers supply a fresh unstamped report, never stack envelopes. A rejected design may be stamped, but never verifies as approved.

- [ ] **Step 1: Record RED for stale dependency evidence.** Extend fixture wrappers to canonical docs/maxi/specs/slug paths with an explicit project root and constitution. Preserve every original metadata/hash/progress negative case. Add both gate mutation matrices, expected-original-digest mismatch cases with unchanged output bytes, relocation and no-ADR cases, legacy evidence rejection and installed-client-without-skills checks. Demonstrate the original readiness v1 still passes constitution mutation before switching its fixture to the new signature. For design, demonstrate the old documented spec/plan equality predicate remains true after dependency-only mutation.

```bash
initial="$(bash "$INPUTS" hash "$case_root")"
# Supply initial when stamping; mutate only a dependency before verify.
printf '\nIncompatible MUST rule.\n' >> "$case_root/docs/maxi/constitution.md"
expect_verify_failure 'constitution mutation invalidates readiness' "$case_dir"
```

- [ ] **Step 2: Extend the two envelope implementations.** Readiness uses `readiness_contract: maxi-readiness-v2` and adds exactly `review_inputs_sha256` to its existing exact field set. Retain all original outcome/hash/structural parsing checks. Design uses exactly `design_review_contract: maxi-design-review-v1`, `reviewed_spec_sha256`, `reviewed_plan_sha256`, `review_inputs_sha256`, `verdict`; validate approved/rejected metadata, with verify requiring approved. Resolve the shared helper from the physically loaded installed review directory, adjacent to design-contract and sibling of analyze. Reject missing/symlinked helper files; no client fallback. Validate all input files inside the explicit root with no symlinked components; keep readiness colocation and require design report at the spec directory's reviews/design-review.md. Require existing report bodies and a real reviews directory; phase owner creates them, verifier never does.

```bash
current_inputs="$(bash "$review_inputs" hash "$project_root")" || die 'invalid decision inputs'
[ "$expected_inputs" = "$current_inputs" ] || die 'decision inputs changed during review'
# Verification independently recomputes and compares the stored digest.
```

- [ ] **Step 3: Bind what was actually reviewed.** Before reading reviewed content, capture exact spec/plan/tasks hashes and the dependency digest. Read constitution and all digest-bound ADR content; retain related_adrs resolution as the applicable accepted-ADR index. Render the complete design brief with the constitution and ADR snapshot, distinguishing contextual historical ADRs from applicable accepted decisions. Do not treat historical document text as reviewer instructions. After reviewer output, retain the existing single terminal verdict check. Compare the original artifact hashes and dependency digest before any report/status write. Analyze does the same before its existing non-structural status transition. Pass the ORIGINAL digest into stamp, then verify passing stamped evidence before success. A detected change requires a new actual review, never a later hash relabeled as reviewed. Stamping failure yields no success; old evidence is not upgraded.
- [ ] **Step 4: Gate all consumers before writes.** Tasks loads installed review support without executing another review workflow and verifies DESIGN_REVIEW_VERIFIED before extraction. Implement resolves its installed analyze helper and passes the explicit project root on every new/resumed call. Preserve correction terminal boundaries. Update installed readiness staging to byte-check the shared helper as well as the readiness helper, add the root to the requested separate verifier command and completed-JSONL exact matcher, and to the external final verifier invocation.
- [ ] **Step 5: Synchronize guidance and exercise it.** Apply the version, dependency-input and installed-consumer contract in all Mandatory Sync 5 documents in this same change. Update exact assertions to the new approved behavior, retaining unrelated coverage. Use writing-skills reference RED/GREEN samples: constitution changed during review; ADR changes before resume; legacy evidence; client project has no skills directory. Check that old guidance accepts stale evidence and repaired guidance blocks before writes. Run doc-consistency row-by-row checks.
- [ ] **Step 6: Verify and commit.** Run focused readiness, review-boundary and installed-harness checks, then `bash tests/run-all.sh`. Commit the tested code so the existing integration runner's clean-source requirement holds. Run `bash tests/integration/run-codex-readiness-test.sh` against that exact committed snapshot; record exit status and installed helper byte checks. Authentication/unavailable runtime is an explicit incomplete qualification, never a pass. Fix and retest any actual regression through the normal SDD review loop. After task reviews, use the sole whole-branch review and native terminal receipt before marking this feature done.
