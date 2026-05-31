---
slug: 0004-single-responsibility-migrate-adr-split
created: 2026-05-30
updated: 2026-05-31
status: done
# Allowed values: drafting | specified | clarified | planned | tasked | analyzed | implementing | done | parked | cancelled
parked_from: null
# parked_from: set by /maxi:park to the pre-park status; cleared to null by /maxi:resume
related_adrs: ["0009-single-responsibility-per-skill", "0010-migrate-adr-decomposition-support-files"]
---

# Feature Specification: Single-Responsibility principle + migrate-adr decomposition

> Establish "single responsibility per skill" as a maxi constitution principle, and bring the one
> clear violation — `migrate-adr` — into compliance by extracting its fused import and discover
> concerns into per-source briefs behind a single orchestrator. Behavior-preserving.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Codify single-responsibility as a project principle (Priority: P1)

A maintainer (or Claude authoring a skill) needs a durable, written rule that every skill owns
exactly one responsibility, so future skills don't silently fuse independent concerns the way
`migrate-adr` did. The principle lives in the constitution (the home for durable invariants), is
recorded as an amendment ADR, and the contributor-facing `CLAUDE.md` points to it without
duplicating the text.

**Why this priority**: This is the governing rationale for the whole feature and was explicitly
requested. It delivers standalone value — it constrains all future skill authoring even before any
existing skill is refactored.

**Independent Test**: Read `docs/maxi/constitution.md` and confirm a Core Principle states the
single-responsibility rule with a litmus test; confirm the constitution `version` was bumped and
`updated:` set; confirm an adoption ADR exists under `docs/maxi/adr/`; confirm `CLAUDE.md`
references the principle rather than restating it.

**Acceptance Scenarios**:

1. **Given** the constitution at v1.2.0 with no SRP principle, **When** the principle is added via `/maxi:constitution`, **Then** a Core Principle names the single-responsibility rule plus the "independent reasons to change ⇒ separate responsibilities" litmus, the version becomes 1.3.0, and `updated:` is today's date.
2. **Given** the amendment is being made, **When** `/maxi:constitution` records it, **Then** an ADR is proposed and (on consent) written via `/maxi:x-adr` capturing the adoption decision and its drivers.
3. **Given** `CLAUDE.md` already owns skill-authoring guidance, **When** the principle is codified, **Then** `CLAUDE.md` gains a one-line pointer to the constitution principle and does **not** duplicate the principle's body.

---

### User Story 2 - Decompose migrate-adr into orchestrator + per-source briefs (Priority: P1)

A maintainer working on `migrate-adr` should be able to change the import-format handling without
reading or risking the discovery heuristics, and vice versa, because the two concerns now live in
separate files behind a single orchestrator. The user-facing command, its cross-source dedup, and
its single consent gate are unchanged.

**Why this priority**: This is the concrete deliverable that applies the principle to its one clear
violation. It delivers standalone value (the two volatile source-handlers become independently
editable) even without the principle being written.

**Independent Test**: Confirm `skills/migrate-adr/` contains `SKILL.md` (orchestration only),
`import-subagent.md` (import logic only), and `discover-subagent.md` (discovery logic only); run
`/maxi:migrate-adr` against a fixture and confirm identical proposals, dedup, consent prompts, and
writes versus the pre-change behavior.

**Acceptance Scenarios**:

1. **Given** the 342-line `migrate-adr/SKILL.md` fusing Importer and Discoverer briefs, **When** the decomposition is applied, **Then** the format-detection/Nygard/MADR/Plain mapping content lives in `import-subagent.md`, the analysis-layers/significance-rubric/constitution-linkage content lives in `discover-subagent.md`, and `SKILL.md` retains only orchestration plus the shared proposal return-schema.
2. **Given** the new layout, **When** `SKILL.md`'s dispatch step runs, **Then** it references both brief files by path and dispatches Subagent A with the importer brief and Subagent B (unless `--import-only`) with the discoverer brief.
3. **Given** an identical project state, **When** `/maxi:migrate-adr` is run before and after the change, **Then** the proposals, cross-source deduplication, consent verbs, `.rejected` bookkeeping, `--import-only` behavior, and written ADRs are observably identical (no functional change).

---

### User Story 3 - Enforce the single-responsibility boundary in tests (Priority: P2)

A reviewer needs the SRP boundary for `migrate-adr` to be machine-enforced, so a future edit can't
silently re-inline a brief back into `SKILL.md` and regress the principle.

**Why this priority**: Turns a one-time cleanup into a durable guard. It builds on US2 (the split must
exist to be enforced), but its assertions are independently testable.

**Independent Test**: With the split in place, run `tests/check-migrate-adr.sh`; confirm it fails if
the importer or discoverer signature content is moved back into `SKILL.md`, and passes when each
lives only in its own brief.

**Acceptance Scenarios**:

1. **Given** the decomposed skill, **When** `tests/check-migrate-adr.sh` runs, **Then** it asserts each brief's signature content is present in its own file AND absent from `SKILL.md`, and that `SKILL.md` references both briefs.
2. **Given** a regression where the importer brief is pasted back into `SKILL.md`, **When** the suite runs, **Then** the boundary assertion fails.
3. **Given** the full change, **When** `bash tests/run-all.sh` runs, **Then** the fast tier passes.

### Edge Cases

- An "absent-from-SKILL.md" assertion could false-positive if a brief's signature string also legitimately appears in orchestration prose — mitigate by choosing distinctive signature strings (e.g. a full format-mapping table header) for the absence checks.
- `--import-only`: the Discoverer brief is not dispatched; the orchestrator still owns the flag and the importer-only path must be unaffected.
- Support briefs are consumed as subagent prompts, so they reference orchestrator-supplied context (exclusion list, constitution principles); the orchestrator must still pass that context exactly as today.
- Existing ADR files and `docs/maxi/adr/README.md` must not change as a side effect (append-only / behavior-preserving).

## Requirements *(mandatory)*

### Functional Requirements

**Principle (US1)**

- **FR-001**: The constitution (`docs/maxi/constitution.md`) MUST include a Core Principle establishing that every skill owns exactly one responsibility, with a litmus test ("if two parts of a skill would change for unrelated reasons, they are separate responsibilities").
- **FR-002**: The principle MUST be applied as a constitution amendment: `version` bumped from 1.2.0 to 1.3.0 and `updated:` set to the amendment date, performed via `/maxi:constitution`.
- **FR-003**: The amendment MUST be captured as an ADR via `/maxi:x-adr`, recording the adoption decision and its drivers, on user consent.
- **FR-004**: `CLAUDE.md` MUST reference the constitution's single-responsibility principle as a one-line pointer; it MUST NOT duplicate the principle's body (preserving the one-way constitution→CLAUDE.md decoupling from spec 0002).

**Decomposition (US2)**

- **FR-005**: The Importer brief — scanned directories, filename blocklist, format-detection table, Nygard/MADR/Plain-Markdown mappings, and imported-ADR frontmatter invariants — MUST live in `skills/migrate-adr/import-subagent.md`.
- **FR-006**: The Discoverer brief — analysis layers, significance rubric, constitution linkage, and discovered-ADR default frontmatter — MUST live in `skills/migrate-adr/discover-subagent.md`.
- **FR-007**: `skills/migrate-adr/SKILL.md` MUST retain only orchestration — the consent Iron Rule, exclusion-context matching (Step 2), dispatch (Step 3), the shared proposal return-schema, dedup (Step 4), summary (Step 5), consent gate (Step 6), guards, and common mistakes — and MUST reference both brief files in its dispatch step.
- **FR-008**: The decomposition MUST be behavior-preserving: identical dispatch, cross-source deduplication, single per-proposal consent gate, `--import-only` handling, `.rejected` bookkeeping, NNNN-at-write-time, and README regeneration. No functional change.
- **FR-009**: The two brief files MUST be valid as support files without YAML frontmatter (consumed as subagent prompts), consistent with `check-frontmatter.sh` scoping frontmatter validation to `SKILL.md` only.

**Tests (US3)**

- **FR-010**: Every existing `migrate-adr` invariant assertion in `tests/check-migrate-adr.sh` MUST continue to pass, each repointed to the file that now owns it (orchestration → `SKILL.md`, format/import → `import-subagent.md`, discovery → `discover-subagent.md`).
- **FR-011**: `tests/check-migrate-adr.sh` MUST add structural boundary assertions: each brief's signature content present in its own file AND absent from `SKILL.md`, and `SKILL.md` references both brief files.
- **FR-012**: The full fast-tier suite (`bash tests/run-all.sh`) MUST pass.

### Key Entities *(artifacts this feature touches)*

- **SRP Core Principle** — new durable invariant in `docs/maxi/constitution.md`.
- **Adoption ADR** — new `docs/maxi/adr/NNNN-*.md` recording the principle's adoption.
- **migrate-adr orchestrator** — slimmed `skills/migrate-adr/SKILL.md`; owns coordination + the shared return schema.
- **import-subagent brief** — new `skills/migrate-adr/import-subagent.md`; owns import-format handling.
- **discover-subagent brief** — new `skills/migrate-adr/discover-subagent.md`; owns discovery heuristics.
- **Boundary test** — extended `tests/check-migrate-adr.sh`; owns SRP-boundary enforcement.

## Clarifications

<!--
  Populated by `/maxi:clarify`. Each entry is a Q/A pair recording how an
  ambiguity in the spec was resolved.
-->

_Clarify pass (2026-05-30): self-scan found no `[NEEDS CLARIFICATION]` markers, no unresolved questions in the FRs, and no vague/ambiguous requirements. The two design forks (principle placement; boundary enforcement) were resolved during brainstorming and are already baked into FR-004 and FR-011/US3. No questions required — spec was clarification-clean._

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A reader of `docs/maxi/constitution.md` finds the single-responsibility Core Principle and its litmus test, and the constitution `version` reads 1.3.0.
- **SC-002**: `skills/migrate-adr/` contains exactly three authored files — `SKILL.md`, `import-subagent.md`, `discover-subagent.md` — with import logic present only in `import-subagent.md` and discovery logic present only in `discover-subagent.md`.
- **SC-003**: Running `/maxi:migrate-adr` (and `/maxi:migrate-adr --import-only`) produces the same proposals, deduplication, consent prompts, `.rejected` writes, and ADR files as before the change — zero observable behavior difference.
- **SC-004**: `tests/check-migrate-adr.sh` includes SRP-boundary assertions (content-in-brief AND absent-from-`SKILL.md`) and `bash tests/run-all.sh` reports all fast checks passing.
- **SC-005**: `CLAUDE.md` links to the constitution's single-responsibility principle, and the principle body is not duplicated there.

## Assumptions

- The constitution amendment (principle text, version bump, `updated:` date) and its ADR are produced through `/maxi:constitution` and `/maxi:x-adr` — not by hand-editing governed frontmatter.
- Support briefs without frontmatter are valid skill support files (precedent: `skills/x-adr/adr-template.md`); `check-frontmatter.sh` validates frontmatter only for `SKILL.md`.
- This feature adds no new skill and changes no FSM status or gating rule, so the pipeline mandatory-sync set (`pipeline-flow.md`, `delegation-map.md`, `using-maxi/SKILL.md`) is untouched; `CLAUDE.md` changes only to add the principle pointer.
- `migrate-adr` remains user-invocable and standalone (no spec-status prerequisite); its two source-handlers are the parts most likely to grow (new ADR formats, new discovery layers), which is why isolating them is the maintainability win — not file-size reduction (`SKILL.md` stays ≈245 lines).
- Behavior-preservation is verified primarily through the existing `tests/check-migrate-adr.sh` invariant set, repointed to the new file layout.
