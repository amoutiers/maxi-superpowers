---
slug: 0002-migrate-adr-review-fixes
created: 2026-05-29
updated: 2026-05-29
status: done
# Allowed values: drafting | specified | clarified | planned | tasked | analyzed | implementing | done | parked | cancelled
parked_from: null
# parked_from: set by /maxi:park to the pre-park status; cleared to null by /maxi:resume
---

# Feature Specification: migrate-adr Review Fixes

A review of `skills/migrate-adr/SKILL.md` surfaced 11 issues (3 high, 4 medium, 4 low), all on the most safety-critical parts of the skill: the consent gate and the exclusion-matching logic. Brainstorming added two further items — a significance rubric (shared with the `adr` skill) and a correction to the documented authoring flow in `CLAUDE.md`. This spec covers the full remediation as a single skill-authoring pass routed through `superpowers:writing-skills`.

Source design doc: `docs/superpowers/specs/2026-05-29-migrate-adr-review-fixes-design.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Saying "no" never writes a file unexpectedly (Priority: P1)

When the user is presented with an imported ADR proposal and declines it, no file is written unless they explicitly chose to preserve it as deprecated. The consent prompt offers distinct verbs (`accept` / `skip` / `deprecate` / `edit`) so intent is never inferred from an ambiguous "no".

**Why this priority**: This is the skill's Iron Rule ("Never Write Without Consent"). The current binary prompt treats "no" as "import as deprecated" — it writes a file the user did not ask for. This is the most serious correctness defect.

**Independent Test**: Run the consent gate on a single imported proposal, reply `skip`, and verify no file is created under `docs/maxi/adr/`. Reply `deprecate` and verify a file with `status: deprecated` is written.

**Acceptance Scenarios**:

1. **Given** an imported ADR proposal, **When** the user replies `skip`, **Then** no file is written.
2. **Given** an imported ADR proposal, **When** the user replies `deprecate`, **Then** a file with `status: deprecated` is written.
3. **Given** an imported ADR proposal, **When** the user replies `accept`, **Then** a file with `status: accepted` is written.
4. **Given** any proposal, **When** the user reply is ambiguous twice, **Then** the skill defaults to `skip` (no file written).

---

### User Story 2 - Exclusion matching does not silently drop decisions (Priority: P1)

When deciding whether a proposed decision is already covered by an existing ADR, matching is precise enough that generic words (`primary`, `store`, `use`) and short tokens (`go`, `js`) do not cause false exclusions.

**Why this priority**: The current symmetric substring rule produces false positives that silently drop legitimate proposals — the user never sees them and cannot consent. A correctness defect that defeats the consent gate by omission.

**Independent Test**: Provide an existing ADR titled "Use Tokio for async runtime" and a new proposal "Use Postgres as primary store"; verify the proposal is NOT excluded. Provide a proposal whose only token is `go`; verify it is flagged for the user, not auto-excluded.

**Acceptance Scenarios**:

1. **Given** an existing ADR and an unrelated proposal sharing only a generic token, **When** matching runs, **Then** the proposal is not excluded.
2. **Given** a proposal whose proper-noun token set equals an existing ADR's set, **When** matching runs, **Then** the proposal is excluded.
3. **Given** a proposal whose token set partially overlaps an existing ADR's set (shared token, not equal), **When** matching runs, **Then** it is flagged for the user, not auto-excluded.
4. **Given** a proposal with no token of 3+ characters, **When** matching runs, **Then** it is flagged for the user rather than auto-excluded.

---

### User Story 3 - Importer imports only real ADRs, with provenance (Priority: P2)

The importer skips non-ADR files (`README.md`, `index.md`, `template.md`, `CONTRIBUTING.md`) and records the original file path in each imported ADR.

**Why this priority**: Without the blocklist, a project `README.md` can be imported as an ADR via the plain-Markdown catch-all. Provenance makes imports auditable. Important but lower blast radius than US1/US2.

**Independent Test**: Point the importer at a directory containing `README.md` plus one real Nygard ADR; verify only the ADR is proposed and its draft carries a `source:` field with the original path.

**Acceptance Scenarios**:

1. **Given** a scan directory containing `README.md`, **When** the importer runs, **Then** `README.md` is not proposed as an ADR.
2. **Given** an imported ADR, **When** its draft is shown, **Then** it includes a `source:` frontmatter field pointing at the original file.

---

### User Story 4 - Discarded discoveries are not re-proposed on re-run (Priority: P2)

When the user skips a discovered proposal, the skill records it so a later re-run does not surface the same decision again.

**Why this priority**: Re-running the migration today re-proposes everything previously rejected, creating repeated noise. Recording rejections respects the user's earlier decision.

**Independent Test**: Run discovery, `skip` one proposal, run discovery again; verify the skipped decision is not proposed the second time.

**Acceptance Scenarios**:

1. **Given** a discovered proposal the user skips, **When** the skill processes the skip, **Then** the proposal's domain label is appended to `docs/maxi/adr/.rejected`.
2. **Given** a populated `.rejected` file, **When** a later run builds exclusion context, **Then** rejected labels are excluded (after passing through the same token normalization as ADR matching).
3. **Given** an imported proposal the user skips, **When** the skill processes the skip, **Then** nothing is appended to `.rejected` (the source file is already the record).

---

### User Story 5 - Subagents return a defined contract informed by the constitution (Priority: P2)

Both subagents return proposals in an explicit, documented schema, and the Discoverer is given the constitution's principles so discovered decisions can reference related principles.

**Why this priority**: The dedup and summary-table steps depend on structured output that the skill never defined, leaving behavior undefined. The constitution gate is currently checked but never used — this makes it load-bearing.

**Independent Test**: Inspect the subagent dispatch instructions for an explicit return schema; run discovery in a project whose constitution names a principle the discovered decision relates to, and verify `related_principles` is populated.

**Acceptance Scenarios**:

1. **Given** the dispatch step, **When** subagents return, **Then** each proposal includes `source`, `domain_label`, `title`, and (for imports) `format` and `source_path`.
2. **Given** a constitution with named principles, **When** the Discoverer surfaces a related decision, **Then** the draft's `related_principles` references the matching principle.

---

### User Story 6 - Only significant decisions are proposed (Priority: P2)

The Discoverer applies a testable rubric — a decision is proposed only if it is costly to reverse, constrains future choices, or was contested. The `adr` skill's description states the same bar.

**Why this priority**: Without a bar, a bare dependency or git-log keyword hit is enough to propose, drowning the user in trivial items. The consent gate should not be the only filter.

**Independent Test**: Run discovery on a project that uses a formatter (easily reversible, uncontested) and a database (costly to reverse); verify only the database decision is proposed.

**Acceptance Scenarios**:

1. **Given** an easily-reversible, uncontested dependency, **When** discovery runs, **Then** it is not proposed.
2. **Given** a decision that is costly to reverse, **When** discovery runs, **Then** it is proposed.

---

### User Story 7 - Polish: correct git flag, honest table, single README regen (Priority: P3)

Cosmetic and efficiency fixes that do not change the consent contract.

**Why this priority**: Low blast radius; quality-of-life and clarity.

**Independent Test**: Read the revised skill and confirm `git log -n 200`, a row-index summary table (no tentative ADR numbers), and a single README regeneration at the end of the consent loop.

**Acceptance Scenarios**:

1. **Given** the discovery step, **When** it reads git history, **Then** it uses `git log -n 200`.
2. **Given** the summary table, **When** it is displayed, **Then** it uses a plain row index, not tentative `ADR-NNNN (t)` numbers.
3. **Given** a consent loop that writes several ADRs, **When** it completes, **Then** `README.md` is regenerated once.

---

### User Story 8 - CLAUDE.md documents the real authoring flow (Priority: P3)

The "Developing New Skills" section of `CLAUDE.md` documents the flow brainstorm → spec → `writing-plans` → `superpowers:writing-skills`.

**Why this priority**: Documentation accuracy; does not affect runtime skill behavior.

**Independent Test**: Read `CLAUDE.md` and confirm the RED/GREEN/REFACTOR cycle is replaced by the four-step flow.

**Acceptance Scenarios**:

1. **Given** `CLAUDE.md`, **When** the "Developing New Skills" section is read, **Then** it documents brainstorm → spec → writing-plans → writing-skills.
2. **Given** the constitution's Contributor Workflow, **When** it is read, **Then** it no longer references CLAUDE.md or the RED/GREEN/REFACTOR cycle; the dependency direction points one way only (CLAUDE.md/skills → constitution).
3. **Given** the constitution is amended, **When** the change lands, **Then** `version` is bumped, the `updated` date is refreshed, and an ADR recording the amendment is written.

---

### Edge Cases

- What happens when `.rejected` does not yet exist on first run? — Treated as empty; created on first discovered skip.
- What happens when a proposal's only distinguishing token is a generic word after stopword stripping? — Flagged for the user, not auto-excluded (US2 #3).
- What happens when the constitution exists but names no principle relevant to a discovered decision? — `related_principles` stays empty; no fabricated links.
- What happens when an imported ADR's source format omits a `source:`-eligible path? — `source:` records the scanned file path; if genuinely unknown, `[unknown]`.
- What happens to the `adr` skill description's significance bar versus plan/implement's actual detection? — Description documents the bar; plan/implement detection behavior is unchanged this pass (see Assumptions).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The imported-proposal consent prompt MUST offer four explicit verbs: `accept`, `skip`, `deprecate`, `edit`.
- **FR-002**: A `skip` response MUST NOT write any ADR file.
- **FR-003**: A `deprecate` response MUST write an ADR with `status: deprecated`; `accept` and `edit` MUST write with `status: accepted`.
- **FR-004**: The discovered-proposal consent prompt MUST offer `accept`, `skip` (no file), and `edit`, with verbs whose meaning does not change between imported and discovered cases.
- **FR-005**: On an ambiguous response the skill MUST re-ask once naming the explicit verbs; a second ambiguous response MUST default to `skip` (no file written).
- **FR-006**: Exclusion matching MUST normalize labels (lowercase, strip stopwords `use`, `for`, `the`, `a`, `as`, `with`, `to`) and compare on a single core token.
- **FR-007**: Matching MUST compare the **set of proper-noun (capitalized) tokens** of each label. If a label has no proper-noun token, its longest remaining token (3+ chars) forms a single-element set. A proposal is excluded only when its set is **equal** to an existing entry's set. When the sets **partially overlap** (share at least one token but are not equal), the proposal MUST be **flagged for the user, not auto-excluded**. No overlap = kept.
- **FR-008**: If no qualifying token exists (all stopwords, or every candidate token shorter than 3 characters), the proposal MUST be flagged for the user rather than auto-excluded.
- **FR-009**: The importer MUST skip a fixed, case-insensitive filename blocklist: `README.md`, `index.md`, `template.md`, `CONTRIBUTING.md`. No subjective H1 heuristic is used.
- **FR-010**: Every imported ADR MUST carry a `source:` frontmatter field with the original file path (`[unknown]` if genuinely undeterminable).
- **FR-011**: On `skip` of a discovered proposal, the skill MUST append its domain label to `docs/maxi/adr/.rejected` (one label per line, with a `#`-comment header).
- **FR-012**: On `skip` of an imported proposal, the skill MUST NOT write to `.rejected`.
- **FR-013**: Exclusion-context construction MUST read `.rejected` alongside existing ADR files, applying the FR-006/FR-007 normalization to its labels.
- **FR-014**: Writing to `.rejected` MUST be exempt from the consent gate / Iron Rule (it is bookkeeping, not an ADR).
- **FR-015**: The subagent dispatch MUST specify a return schema where each proposal includes `source` (import|discover), `domain_label`, `title`, the draft body, and (imports only) `format` and `source_path`.
- **FR-016**: The skill MUST pass the constitution's principles to the Discoverer and populate `related_principles` when a discovered decision relates to a named principle.
- **FR-017**: The Discoverer MUST apply a significance rubric — propose only if the decision is costly to reverse, constrains future choices, or was contested — and a bare dependency or keyword hit MUST NOT be sufficient on its own.
- **FR-018**: The `adr` skill description MUST state the same significance rubric in place of the current example list.
- **FR-019**: The discovery step MUST use `git log -n 200` (not `git log -200`).
- **FR-020**: The summary table MUST use a plain row index and MUST NOT display tentative `ADR-NNNN (t)` numbers; a note MUST state numbers are assigned sequentially at write time.
- **FR-021**: `docs/maxi/adr/README.md` MUST be regenerated once at the end of the consent loop (with partial regeneration on early exit), not after every write.
- **FR-022**: `CLAUDE.md`'s "Developing New Skills" section MUST document the flow brainstorm → spec → `writing-plans` → `superpowers:writing-skills`.
- **FR-023**: All edits MUST preserve `migrate-adr`'s existing non-defective behavior (two-subagent architecture, Nygard/MADR/Plain detection tables, dedup precedence).
- **FR-024**: The constitution's Contributor Workflow MUST be reworded to remove its reference to CLAUDE.md and the RED/GREEN/REFACTOR cycle; the constitution MUST NOT depend on CLAUDE.md. The dependency direction is one-way: CLAUDE.md and skills may reference the constitution, never the reverse.
- **FR-025**: Amending the constitution (FR-024) MUST bump its `version` (semver), refresh its `updated` date, and generate an ADR recording the amendment, per `constitution.md` Governance.

### Key Entities *(include if feature involves data)*

- **Proposal**: An ADR candidate from a subagent. Attributes: `source` (import|discover), `domain_label`, `title`, draft body; imports add `format`, `source_path`.
- **`.rejected` log**: A line-oriented file at `docs/maxi/adr/` recording domain labels of skipped discovered proposals; consumed by exclusion-context construction.
- **Imported ADR**: An ADR written from an existing source file, carrying a `source:` provenance field.

## Clarifications

- **Q**: How should the conflict between FR-022 (CLAUDE.md authoring flow) and the constitution's reference to "the RED/GREEN/REFACTOR cycle documented in CLAUDE.md" be resolved?
  **A**: The constitution must not reference CLAUDE.md at all — the dependency direction is one-way (CLAUDE.md/skills → constitution). Reword the constitution's Contributor Workflow to drop the reference (FR-024), and amend it formally (version bump + ADR, FR-025).

- **Q**: When a label has more than one proper-noun token, which is the core token for exclusion matching (FR-007)?
  **A**: Match on the full set of proper-noun tokens. Exclude only when the sets are equal; flag (do not auto-exclude) when they partially overlap; keep when there is no overlap. This biases against the false exclusions US2 (P1) exists to prevent, and reuses FR-008's flag-don't-drop pattern.

- **Revised (2026-05-29):** Rolled back from `analyzed` to `planned`. Change: fix analysis finding D1 — every commit step must run the full `bash tests/run-all.sh` (constitution: fast-tier mandatory before any commit), not just the targeted check; the fix lands as a single global commit-discipline rule in `plan.md`. Note: artefacts from phases after `planned` (`tasks.md`, `analysis.md`) are stale and will be regenerated by `/maxi:tasks` → `/maxi:analyze`.

- **Revised (2026-05-29):** Rolled back further from `planned` to `clarified`. Change: the D1 fix lives in `plan.md`, which only regenerates by re-running `/maxi:plan` (input status `clarified`); rolling to `planned` alone would not rewrite it. Clarification content is unchanged. Note: `plan.md`, `tasks.md`, `analysis.md` are stale and will be regenerated by `/maxi:plan` → `/maxi:tasks` → `/maxi:analyze`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of `skip` responses (imported or discovered) result in zero ADR files written.
- **SC-002**: Zero false exclusions in a test set pairing unrelated decisions that share only a generic token.
- **SC-003**: A re-run after skipping discovered proposals re-proposes none of the skipped decisions.
- **SC-004**: 0 non-ADR files (README/index/template/CONTRIBUTING) are imported when present in a scan directory.
- **SC-005**: `bash tests/run-all.sh` fast tier passes after all edits, including `check-frontmatter.sh` and `check-skills-present.sh`.

## Assumptions

- The brainstorming phase for this spec was completed in-session; its output is captured in the source design doc referenced above. `/maxi:specify`'s brainstorming step is satisfied by that dialogue.
- `.rejected` is intentionally NOT added to `CLAUDE.md`'s Artifact Convention section this pass (scoping decision). Recorded as a known, accepted omission.
- Updating `plan`/`implement` to *apply* the significance rubric is out of scope; only the `adr` description is changed. The judgment continues to be made by the calling skills.
- **Resolved (see Clarifications)**: the constitution's Contributor Workflow reference to CLAUDE.md is removed (FR-024) and the constitution amended formally (FR-025). The dependency direction is one-way: CLAUDE.md/skills → constitution, never the reverse.
- The two-subagent architecture and format-detection tables are sound and are preserved unchanged.
