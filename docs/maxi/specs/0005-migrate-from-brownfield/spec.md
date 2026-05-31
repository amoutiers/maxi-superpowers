---
slug: 0005-migrate-from-brownfield
created: 2026-05-30
updated: 2026-05-31
status: done
parked_from: null
related_adrs: ["0011-migration-ingress-terminal-status"]
---

# Feature Specification: migrate-from-brownfield

A maxi skill that reverse-engineers an existing brownfield codebase into faithful, traceable `spec.md` baselines (status `done`) so a project with real code but no spec artifacts can adopt spec-driven development. It produces specs and nothing else — single-responsibility per Constitution Principle VI.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reverse-engineer one feature boundary into a trustworthy baseline (Priority: P1)

A developer onboarding a brownfield project to maxi wants a faithful `spec.md` that documents what an existing subsystem already does, so future changes to it can flow through the SDD pipeline against a written baseline. The skill drafts the spec from the code, has a second agent verify it against the actual source, and asks for explicit consent before writing.

**Why this priority**: This is the core value — a single verified baseline. Even if the skill could only document one boundary at a time with no decomposition or batching, the project could still adopt SDD on that subsystem. Everything else amplifies this.

**Independent Test**: Point the skill at a repo with a constitution and one clearly-bounded module; confirm it produces a `spec.md` at status `done` whose functional requirements each carry a `file:line` reference traceable to real code, with a `## Migration Notes` section — and that nothing is written until the user explicitly accepts.

**Acceptance Scenarios**:

1. **Given** a project with `docs/maxi/constitution.md` and source code, **When** the skill drafts a spec for a boundary and the user responds `accept`, **Then** `docs/maxi/specs/NNNN-slug/spec.md` is written with `status: done`, `origin: reverse-engineered`, the source git SHA, and a `## Migration Notes` section.
2. **Given** a drafted spec containing a functional requirement not supported by any code, **When** the adversarial verification pass runs, **Then** the unsupported requirement is flagged and removed (or corrected) before the draft is shown to the user.
3. **Given** a vetted draft shown to the user, **When** the user gives an ambiguous response (e.g. "ok", silence), **Then** the skill re-asks once naming the explicit verbs and, if still ambiguous, defaults to `skip` with no file written.

---

### User Story 2 - Decompose a large codebase and document it in waves (Priority: P2)

A developer facing a large repo cannot reverse-engineer everything in one pass. The skill proposes a map of candidate feature boundaries with supporting evidence, lets the user collapse/split/rename/sequence them, and skips boundaries already documented in prior runs — so onboarding is a repeatable, incremental activity.

**Why this priority**: Makes the P1 capability tractable at real-world scale and across many projects. Important, but the core baseline value (P1) stands without it for small modules.

**Independent Test**: Run the skill twice on a multi-module repo; confirm the first run proposes a boundary map with per-boundary evidence and only documents the selected subset, and the second run excludes already-documented boundaries from its proposals.

**Acceptance Scenarios**:

1. **Given** a repo with multiple modules, **When** discovery runs, **Then** the skill presents a boundary map where each candidate lists the paths that back it.
2. **Given** the proposed boundary map, **When** the user collapses, splits, renames, or deselects entries, **Then** only the selected boundaries are reverse-engineered in this run.
3. **Given** a repo where `docs/maxi/specs/` already contains reverse-engineered specs, **When** the skill runs again, **Then** boundaries already documented are excluded from the new proposals.

---

### User Story 3 - Provenance and traceability of generated baselines (Priority: P3)

A developer reviewing or later revising a reverse-engineered spec needs to know it was machine-inferred from code (not authored through the full pipeline) and be able to audit each claim back to its source.

**Why this priority**: Protects long-term trust — a reverse-engineered spec that silently looks like a pipeline-authored one misleads future SDD work. Valuable but built on top of P1's output.

**Independent Test**: Inspect a written baseline; confirm `origin: reverse-engineered` and the source SHA are in frontmatter, every FR has a `file:line` reference, and Migration Notes states which pipeline phases never ran.

**Acceptance Scenarios**:

1. **Given** an accepted baseline, **When** its frontmatter is inspected, **Then** it carries `status: done`, `origin: reverse-engineered`, and the commit SHA it was derived from.
2. **Given** an accepted baseline, **When** its `## Migration Notes` are read, **Then** they record that plan/tasks/analyze/implement phases never ran and that the spec was verified against code.

### Edge Cases

- **No constitution**: stop immediately with *"Run `/maxi:constitution` first"* and separately suggest `/maxi:migrate-adr`; write nothing.
- **No source code detected**: stop cleanly — nothing to reverse-engineer.
- **Slug collision** with an existing spec directory: follow `/maxi:specify` collision behavior (ask for a disambiguating suffix).
- **All discovered boundaries already documented**: report that there is nothing new to document and exit cleanly.
- **Adversarial verifier and drafter disagree irreconcilably** on a requirement: drop the unverifiable requirement rather than ship an unsupported claim; note the omission.
- **Detached HEAD / uncommitted working tree**: still record the resolved commit SHA; the baseline reflects the code state at run time.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The skill MUST refuse to run and instruct the user to run `/maxi:constitution` first when `docs/maxi/constitution.md` is absent, writing no files.
- **FR-002**: The skill MUST stop cleanly when no recognized code files are detected in the project ("no source code"). When code exists but exhibits no clean structure (monolith, single large file), the skill MUST NOT hard-fail — it degrades gracefully per FR-004.
- **FR-003**: The skill MUST resolve and record the current git commit SHA so every produced spec references the exact code state it was reverse-engineered from.
- **FR-004**: The skill MUST analyze the codebase (directory structure, module/package boundaries, entry points, routes/exports, naming clusters) and propose candidate feature boundaries, each accompanied by the source paths that back it. When no clean structure can be inferred, the skill MUST propose a single whole-project boundary as a floor, which the user can split via the boundary-map review (FR-006).
- **FR-005**: The skill MUST read existing `docs/maxi/specs/*/spec.md`, build an exclusion set of already-documented boundaries, and MUST NOT re-propose them — making the skill resumable across runs. Matching is path-overlap primary: a candidate whose backing source paths are already covered by an existing reverse-engineered spec's `file:line` references is excluded. Label token-set matching (reusing `migrate-adr`'s rule) is the fallback for specs without code references. Partial overlap MUST be flagged to the user, never auto-excluded.
- **FR-006**: The skill MUST present the boundary map for user editing — collapse, split, rename, and select/deselect — and reverse-engineer only the boundaries the user selects in that run.
- **FR-007**: For each selected boundary the skill MUST draft a `spec.md` conforming to the full maxi spec-template schema (user stories with priorities, Independent Tests, Given/When/Then acceptance scenarios, FRs, success criteria), with two as-built adaptations: acceptance scenarios MUST be phrased as observed/current behavior (`Given <current state>, When <real input>, Then <observed output>`) rather than aspirational, and each functional requirement MUST carry a `file:line` reference to its supporting code. Default to one P1 user story per boundary; split into multiple stories only when the code has genuinely separable sub-features.
- **FR-008**: Before showing any draft to the user, the skill MUST run an independent adversarial verification pass that checks the draft against the actual code for (a) requirements unsupported by code, (b) behaviors present in code but absent from the draft, and (c) wrong or stale file references, and revise the draft accordingly.
- **FR-009**: The skill MUST present each vetted draft and obtain an explicit `accept` / `skip` / `edit` decision; on an ambiguous response it MUST re-ask once naming the verbs, then default to `skip`. An `edit` response means accept-with-changes: the skill applies the user's amendments and writes the spec immediately, without a second confirmation (matching `migrate-adr`).
- **FR-010**: The skill MUST NOT write any spec file without an explicit `accept` for that specific draft.
- **FR-011**: On accept, the skill MUST write `docs/maxi/specs/NNNN-slug/spec.md` with `status: done`, the NNNN computed from the current maximum in `docs/maxi/specs/` at write time.
- **FR-012**: Each written spec MUST include the additive frontmatter field `origin: reverse-engineered` and the source commit SHA, and MUST NOT introduce any new status value into the pipeline FSM.
- **FR-013**: Each written spec MUST include a `## Migration Notes` section recording: the commit SHA it was reverse-engineered from; that plan/tasks/analyze/implement phases never ran; and that the spec was verified against code.
- **FR-014**: The skill MUST process selected boundaries as independent units so they can be reverse-engineered in parallel.
- **FR-015**: The skill MUST NOT bootstrap a constitution, generate ADRs, fabricate `plan.md`/`tasks.md`, or delete/move any existing code or spec files (out-of-scope responsibilities deferred to `/maxi:constitution` and `/maxi:migrate-adr`).
- **FR-016**: The skill MUST be user-invocable as `/maxi:migrate-from-brownfield`.

### Key Entities *(include if feature involves data)*

- **Boundary candidate**: a proposed feature/subsystem unit — a name, a set of backing source paths (evidence), and a selected/edited state in the review.
- **Reverse-engineered spec**: a `spec.md` at `status: done` with `origin: reverse-engineered`, a source SHA, traceable FRs, and Migration Notes.
- **Exclusion set**: the collection of already-documented boundaries derived from existing specs, used to keep runs idempotent.

## Clarifications

**Q: What schema should a reverse-engineered `spec.md` follow?**
A: The full maxi spec-template schema (so downstream skills — `revise`, `clarify`, `analyze`, `plan` — can read it), with two as-built adaptations: acceptance scenarios are phrased as observed/current behavior rather than aspirational, and each FR carries a `file:line` reference. One P1 story per boundary by default; split only when the code has separable sub-features.

**Q: How does the skill decide a candidate boundary is already documented (idempotency)?**
A: Path-overlap is primary — a candidate whose backing paths are already covered by an existing reverse-engineered spec's `file:line` refs is excluded. Label token-set matching (reusing `migrate-adr`'s rule) is the fallback for specs without code refs. Partial overlap is flagged to the user, never auto-excluded.

**Q: When the user responds `edit` on a vetted draft, what happens?**
A: `edit` means accept-with-changes — the skill applies the amendments and writes immediately, with no second confirmation (consistent with `migrate-adr`).

**Q: What does the skill do on a messy or structureless repository?**
A: "No source code" means no recognized code files at all → stop cleanly. If code exists but has no clean structure, the skill proposes a single whole-project boundary as a floor, which the user splits via the boundary-map review. It never hard-fails on messy code.

**Revised (2026-05-30):** Rolled back from `analyzed` to `clarified`. Change: apply analysis findings F1 and F2.
- **F1 (FR-010 reading):** FR-010 is authoritatively read as *"the skill MUST NOT write any spec file without an explicit `accept` **or** `edit`"* — `edit` (accept-with-changes) also writes, per FR-009 and SC-002. Behavior was already correct; this resolves the wording.
- **F2 (boundary identity naming):** the boundary-identity field is `name` everywhere (per the `Boundary candidate` entity). The `brownfield.sh exclude` helper flag is `--name` (was `--label` in the draft plan); "label" is retained only as prose for the migrate-adr token-set rule. plan.md/tasks.md regenerate with this naming.
Note: plan.md, tasks.md, and analysis.md from phases after `clarified` are stale and will be regenerated by re-running `/maxi:plan → /maxi:tasks → /maxi:analyze`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of functional requirements in a written baseline carry a `file:line` reference that resolves to existing code at the recorded SHA.
- **SC-002**: No spec file is ever written without explicit per-draft consent (0 writes on `skip` or ambiguous-default-`skip` paths; `accept` and `edit` both write).
- **SC-003**: Re-running the skill on an already-partially-documented project proposes 0 boundaries that duplicate existing reverse-engineered specs.
- **SC-004**: Every reverse-engineered baseline is distinguishable from a pipeline-authored spec by frontmatter alone (presence of `origin: reverse-engineered`).
- **SC-005**: The skill introduces 0 new status values into the pipeline FSM (board, revise, and gating behavior are unchanged).

## Assumptions

- The target project is a git repository (a SHA can be resolved).
- The constitution requirement and `/maxi:specify` slug/numbering conventions apply unchanged to specs this skill produces.
- Reverse-engineered baselines land at `status: done`; changing a documented feature later goes through `/maxi:revise`, which rolls the spec back into the forward pipeline.
- Surfacing the `origin` marker visually (e.g. a `/maxi:board` badge) is a separate skill's concern and out of scope here.
- The adversarial verification pass and the drafting pass are performed by independent agents so verification is not self-confirming.
