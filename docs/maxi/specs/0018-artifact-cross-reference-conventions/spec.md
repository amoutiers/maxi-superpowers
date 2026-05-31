---
slug: 0018-artifact-cross-reference-conventions
created: 2026-05-31
updated: 2026-05-31
status: done
parked_from: null
related_adrs: ["0012-traceability-direction-spec-to-adr"]
---

# Feature Specification: Artifact cross-reference conventions — direction and link form

> **Filled in by `/maxi:specify`.**

This feature governs **how maxi artifacts reference one another**, along two axes:

**Axis 1 — direction (spec → ADR).** Today every ADR carries three cross-reference frontmatter fields — `related_specs`, `related_principles`, `related_requirements` — so the durable, append-only ADR points *up* at the ephemeral, mutable spec. This contradicts the dependency-direction doctrine [0003-constitution-decoupled-from-claudemd](../../adr/0003-constitution-decoupled-from-claudemd.md) established for the constitution: an artifact that is authoritative and long-lived must not depend on a lower-tier, revisable one (a spec can be `revised`, `parked`, or `cancelled`; an ADR cannot). This feature corrects that inversion. The ADR returns to a self-contained Nygard/MADR record (metadata + supersession chain only); traceability lives on the spec side via a new `related_adrs` field. Analyze's Pass G — the only machine consumer of the removed fields — is re-pointed to read the spec→ADR direction.

**Axis 2 — form (clickable links everywhere).** Wherever a maxi skill emits *prose* that references another artifact (an ADR, spec, plan, tasks, constitution, or a repo file), it must render a clickable relative Markdown link rather than a bare slug, number, or code span — so a reader can navigate directly. Both axes are the same concern: the conventions by which artifacts cross-reference each other. Frontmatter data values (e.g. `related_adrs`) stay as slugs — they are machine data, not navigable prose.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - ADR is a self-contained record, not coupled to a spec (Priority: P1)

As a maintainer reading an ADR months later, I want it to stand on its own — decision, drivers, consequences — without frontmatter that depends on a spec that may have since been revised, parked, or cancelled. The ADR schema should carry only genre-native metadata.

**Why this priority**: This is the core correction. It removes the dependency inversion that violates the project's own established doctrine and is the precondition for every other change. Without it, the durable artifact keeps depending on the ephemeral one.

**Independent Test**: Open any newly created ADR and confirm its frontmatter contains no `related_specs`, `related_principles`, or `related_requirements`, and that the body (Context, Decision Drivers, Decision, Consequences) still conveys every principle/requirement linkage in prose. Run `tests/check-templates.sh` and confirm it passes against the slimmed schema.

**Acceptance Scenarios**:

1. **Given** the ADR template, **When** an ADR is created via `x-adr`, **Then** its frontmatter contains exactly `adr`, `slug`, `status`, `created`, `updated`, `decider`, `supersedes`, `superseded_by` — and none of the three cross-ref fields.
2. **Given** an ADR whose decision was driven by a constitution principle and a spec requirement, **When** the ADR is written, **Then** that principle and requirement are cited inline in the Decision Drivers / Context prose, not in frontmatter.
3. **Given** `tests/check-templates.sh`, **When** the suite runs against the new template and fixture, **Then** it asserts the three fields are absent and passes.

---

### User Story 2 - Traceability lives on the spec, pointing down to ADRs (Priority: P1)

As a maintainer or as `analyze`, I want to find which architectural decisions back a feature by reading the spec, not by scanning every ADR for a matching `related_specs`. The spec — the artifact that owns the feature — should reference its ADRs.

**Why this priority**: The removal in US1 deletes the only existing link. Without a replacement on the spec side, traceability is lost and `analyze` Pass G has nothing to read. US1 and US2 ship together to preserve the capability while flipping its direction.

**Independent Test**: Add an ADR to a feature via `x-adr` during `/maxi:plan`; confirm the active spec's `related_adrs` frontmatter now lists that ADR's full slug. Confirm a spec with no decisions carries `related_adrs: []`.

**Acceptance Scenarios**:

1. **Given** the spec template, **When** a new spec is created, **Then** its frontmatter includes `related_adrs: []`.
2. **Given** `x-adr` creates and the user accepts an ADR while a spec is the active feature, **When** the ADR transitions to `accepted`, **Then** `x-adr` appends that ADR's full slug to the spec's `related_adrs` and bumps the spec's `updated` date.
3. **Given** a spec that references an ADR only inline in prose (`ADR-0009`), **When** traceability is resolved, **Then** that inline reference is also recognized as a link (frontmatter and inline both count).

---

### User Story 3 - Analyze Pass G reads the corrected direction (Priority: P1)

As `analyze`, I must keep detecting missing ADRs (G1) and stale ADR references (G3) after the schema change, by building the spec↔ADR registry from the spec side instead of from `ADR.related_specs`.

**Why this priority**: Pass G is the only automated consumer of `related_specs`. If it is not migrated in the same change, removing the field silently breaks the audit — the exact stale-tooling failure class the project's documentation-sync rule exists to prevent.

**Independent Test**: Run `/maxi:analyze` on a spec whose plan names a consequential tech choice with no backing ADR and confirm G1 still fires; run it on a spec referencing a superseded ADR and confirm G3 still fires — both using spec-side links only.

**Acceptance Scenarios**:

1. **Given** `analyze` Step 3, **When** it builds the ADR registry, **Then** the spec↔ADR map is derived from the spec's `related_adrs` plus inline `ADR-NNNN` mentions, with no read of any `related_specs` field.
2. **Given** a plan with a consequential technology choice and a spec that references no ADR for it, **When** Pass G1 runs, **Then** it reports a "missing ADR" finding.
3. **Given** a spec/plan/tasks artifact that references an ADR whose status is `superseded` or `deprecated`, **When** Pass G3 runs, **Then** it reports a "stale ADR reference" finding.

---

### User Story 4 - Existing ADRs and specs migrated without losing history (Priority: P2)

As a maintainer, I want the 11 existing ADRs stripped of the three fields and the previously-encoded `related_specs` links preserved by writing them back onto the corresponding specs, so no traceability is lost in the transition.

**Why this priority**: One-time data migration. It is important for correctness of the existing corpus but is mechanical and separable from the schema/skill changes; the new pipeline works regardless of whether old data is migrated.

**Independent Test**: After migration, grep the ADR corpus for the three field names and confirm zero frontmatter matches; confirm each of the 6 specs that an ADR previously pointed to now lists that ADR in `related_adrs`.

**Acceptance Scenarios**:

1. **Given** the 11 existing ADRs, **When** migration runs, **Then** none of their frontmatter contains `related_specs`, `related_principles`, or `related_requirements`.
2. **Given** the 6 ADRs that carried a non-empty `related_specs`, **When** migration runs, **Then** the referenced spec's `related_adrs` gains that ADR's full slug (ADR 0001→spec 0001, 0002→0001, 0003→0002, 0009→0004, 0010→0004, 0011→0005).
3. **Given** an ADR body that mentions a removed field name in prose (e.g. ADR-0003's `(related_requirements: FR-025)`), **When** migration runs, **Then** that body text is left untouched, honoring the append-only rule for ADR bodies.

---

### User Story 5 - Producers stop writing the removed fields; migrate-adr requirement reconciled (Priority: P2)

As a maintainer, I want every producer of the three fields updated — `x-adr`, `adr-template`, and the `migrate-adr` discover/import subagents — and the prior requirement that `migrate-adr` populate `related_principles` (FR-016/FR-017) explicitly reconciled, so no skill writes a field that no longer exists.

**Why this priority**: Required for internal consistency, but the affected skills keep functioning even mid-migration; it does not block the schema or analyze changes.

**Independent Test**: Inspect `x-adr/SKILL.md`, `adr-template.md`, and both `migrate-adr` subagent files for any write of the three fields and confirm none remain; confirm `tests/check-migrate-adr.sh` no longer asserts `related_principles` and passes.

**Acceptance Scenarios**:

1. **Given** `x-adr` and the ADR template, **When** an ADR is produced, **Then** no removed field is written and `x-adr` instead records the link on the spec's `related_adrs`.
2. **Given** the `migrate-adr` discover and import subagents, **When** they emit a draft ADR, **Then** the draft frontmatter omits the three fields.
3. **Given** specs 0002 (FR-016) and 0016 (FR-017) which require `related_principles` population, **When** this feature ships, **Then** those requirements are reconciled (superseded or revised) and `tests/check-migrate-adr.sh`'s `related_principles` assertion is removed, leaving the suite green.

---

### User Story 6 - Artifact references are clickable everywhere (Priority: P2)

As a reader of any maxi output — a spec, a plan, an `analysis.md` finding, a board listing, an ADR body, or a skill's chat report — I want every reference to another artifact to be a clickable link, so I can navigate to it without hunting for the file by its slug or number.

**Why this priority**: A project-wide authoring convention that improves navigability across all artifacts. It is cross-cutting but additive — it changes how references are *rendered*, not what any pipeline phase *does*, so it does not block Axis 1. It belongs in this spec because it is the second half of the same concern (how artifacts cross-reference each other).

**Independent Test**: Trigger any maxi skill that emits an artifact reference (e.g. `analyze` citing an ADR, `board` listing specs, `x-adr` referencing a superseded ADR) and confirm the reference is rendered as a relative Markdown link to the target file, not a bare slug/number/code span.

**Acceptance Scenarios**:

1. **Given** any maxi skill whose output (artifact body or chat report) names an ADR, spec, plan, tasks, constitution, or repo file, **When** that output is produced, **Then** the reference is a relative Markdown link to the target file.
2. **Given** a frontmatter data field such as `related_adrs`, **When** the field is written, **Then** its values remain bare slugs (not links) — the link convention applies to prose, not to YAML data.
3. **Given** a within-document reference to a requirement ID (`FR-012`) or section, **When** it appears in prose, **Then** the link convention does not require linking it (only cross-*file* artifact references are in scope).

---

### Edge Cases

- **Discovered ADR with no spec (brownfield).** `migrate-adr` surfaces decisions from code in a project that may have no specs. The ADR is created with no spec to back-link; this is correct — orphan historical ADRs simply appear in no spec's `related_adrs`, and Pass G1 does not flag them (G1 keys off a spec's plan, not off the ADR).
- **ADR referenced by a parked or cancelled spec.** A spec's `related_adrs` persists across `park`/`cancel`; the ADR remains valid. Traceability is unaffected by spec lifecycle status.
- **Multiple specs referencing the same ADR.** An ADR may be listed in more than one spec's `related_adrs` (a cross-cutting decision). The registry is many-to-many; no field on the ADR enforces a single owner.
- **Inline reference drift.** A spec cites `ADR-0009` in prose but omits it from `related_adrs`. Both are recognized as links, so the reference still resolves; the frontmatter field is the canonical, machine-first source and the inline mention is a tolerated fallback.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The ADR template (`skills/x-adr/adr-template.md`) MUST NOT contain `related_specs`, `related_principles`, or `related_requirements` frontmatter fields. Its frontmatter MUST be exactly: `adr`, `slug`, `status`, `created`, `updated`, `decider`, `supersedes`, `superseded_by`.
- **FR-002**: The spec template (`skills/specify/spec-template.md`) MUST include a `related_adrs:` frontmatter field defaulting to `[]`. Entries are full ADR slugs (`"NNNN-slug"`), not bare numbers.
- **FR-003**: `/maxi:specify` MUST initialize `related_adrs: []` in every new spec's frontmatter.
- **FR-004**: `x-adr` MUST, when an ADR is created and accepted in the context of an active spec, append that ADR's full slug to the spec's `related_adrs` field and bump the spec's `updated` date in the same write.
- **FR-005**: `x-adr` MUST NOT write `related_specs`, `related_principles`, or `related_requirements` into any ADR.
- **FR-006**: `x-adr`'s guidance for deriving Decision Drivers MUST continue to instruct citing constitution principles and spec requirements as inline prose (Context / Decision Drivers), without referencing the removed frontmatter fields.
- **FR-007**: The `migrate-adr` discover and import subagents MUST NOT emit `related_specs`, `related_principles`, or `related_requirements` in draft ADR frontmatter.
- **FR-008**: `analyze` MUST build its spec↔ADR registry (Step 3) from each spec's `related_adrs` frontmatter plus inline `ADR-NNNN` mentions in `spec.md`/`plan.md`/`tasks.md`, and MUST NOT read any `related_specs` field.
- **FR-009**: `analyze` Pass G1 (Missing ADR) MUST be expressed as: a `plan.md` names a consequential technology choice for which the spec references no accepted ADR.
- **FR-010**: `analyze` Pass G3 (Stale ADR reference) MUST continue to flag spec/plan/tasks references to ADRs whose status is `superseded` or `deprecated`.
- **FR-011**: All 11 existing ADRs (`docs/maxi/adr/0001`–`0011`) MUST have the three cross-ref fields removed from their frontmatter.
- **FR-012**: For each existing ADR that carried a non-empty `related_specs`, the referenced spec's `related_adrs` MUST gain that ADR's full slug, per the mapping:
  - spec `0001-design-review-fixes` → `["0001-fsm-status-expansion", "0002-pipeline-backflow"]`
  - spec `0002-migrate-adr-review-fixes` → `["0003-constitution-decoupled-from-claudemd"]`
  - spec `0004-single-responsibility-migrate-adr-split` → `["0009-single-responsibility-per-skill", "0010-migrate-adr-decomposition-support-files"]`
  - spec `0005-migrate-from-brownfield` → `["0011-migration-ingress-terminal-status"]`
- **FR-013**: Existing ADR *body* prose that mentions a removed field name MUST be left unchanged, honoring the ADR append-only-body rule.
- **FR-014**: `tests/check-templates.sh` and the `tests/fixtures/sample-adr.md` fixture MUST be updated to assert the three fields are absent from the ADR schema; the full fast-tier suite MUST pass.
- **FR-015**: FR-016 (spec 0002) and FR-017 (spec 0016), which require `migrate-adr` to populate `related_principles`, MUST each receive an in-place supersession note that links to this spec per the Link rendering convention — e.g. `> **Superseded by [0018-artifact-cross-reference-conventions/spec](../0018-artifact-cross-reference-conventions/spec.md)** — related_principles removed from the ADR schema.` — without changing those specs' `status`. The `related_principles` assertion in `tests/check-migrate-adr.sh` MUST be removed, leaving that suite green.
- **FR-016**: This traceability-direction reversal MUST be captured as a new ADR during `/maxi:plan`, recorded in the present spec's `related_adrs`, and cross-referencing ADR-0003's dependency-direction doctrine.
- **FR-017**: Documentation describing the spec artifact schema (`CLAUDE.md` Artifact Convention, `docs/architecture.md`) MUST note the new `related_adrs` spec field; documentation describing the ADR schema MUST drop the three removed fields.
- **FR-018**: Every maxi skill that emits prose referencing another maxi artifact (ADR, spec, plan, tasks, constitution, or a repo file) — in an artifact body or in its chat report to the user — MUST render that reference as a **relative Markdown link** to the target file per the **Link rendering convention** (Key Entities): visible text = the target filename without `.md` (feature-directory-prefixed for generic spec-artifact files), URL = a relative path resolved from the referencing file's location. Not a bare slug, number, or code span. At minimum this covers `x-adr`, `analyze`, `board`, `plan`, `tasks`, `specify`, `clarify`, `revise`, `migrate-adr`, `migrate-from-speckit`, `migrate-from-brownfield`, and `constitution`.
- **FR-019**: The link convention MUST NOT apply to frontmatter data values (e.g. `related_adrs` entries stay bare slugs) nor mandate linking within-document references such as `FR-###`/`SC-###` IDs or section names — only cross-*file* artifact references are in scope.
- **FR-020**: The link convention is realized as authoring guidance embedded in each affected skill's instructions (output/report templates). Automated enforcement of link rendering in free prose is explicitly **out of scope** for this feature — no brittle grep-based test is required; the boundary is stated so the absence of a test is a deliberate decision, not an omission.
- **FR-021**: The link convention (FR-018) applies **forward-only** — to prose emitted after this feature ships. The existing artifact corpus MUST NOT be retrofitted: pre-existing bare references in current specs, ADRs, and docs are left as-is. (ADR bodies are append-only per FR-013 and cannot be retrofitted in any case; retrofitting only specs/docs would produce an inconsistent corpus, so no retrofit is done.)
- **FR-022**: The ADR README index (`docs/maxi/adr/README.md`) "Related Specs" column MUST be rebuilt by **spec-side reverse-lookup** — scanning every `docs/maxi/specs/*/spec.md` for `related_adrs` and inverting the map (for each ADR, list the specs whose `related_adrs` contains its slug) — with no read of any ADR-side field. `x-adr`'s index-regeneration step is updated accordingly. (Surfaced during planning as a consumer of the removed `related_specs`; recorded here so the work is governed by a requirement.)

### Key Entities *(include if feature involves data)*

- **ADR frontmatter (post-change)**: `adr`, `slug`, `status`, `created`, `updated`, `decider`, `supersedes`, `superseded_by`. No cross-references to specs, principles, or requirements.
- **Spec frontmatter (post-change)**: existing fields (`slug`, `created`, `updated`, `status`, `parked_from`) plus `related_adrs: ["NNNN-slug", ...]` (full ADR slugs) — the canonical spec→ADR link, default `[]`.
- **Spec↔ADR registry (analyze)**: a derived many-to-many map built from `related_adrs` + inline `ADR-NNNN` mentions; replaces the prior `ADR.related_specs`-derived registry.
- **Link rendering convention**: the single rule by which any maxi skill renders a cross-file artifact reference in prose.
  - **Visible text** = the target file's name **without its `.md` extension**. For an ADR this is its slug (`0003-constitution-decoupled-from-claudemd`). For a non-`.md` file, the full filename (`check-templates.sh`). For a generic spec-artifact file (`spec.md`, `plan.md`, `tasks.md`, `analysis.md`) — whose bare name is non-identifying — prefix with the feature directory: `0002-migrate-adr-review-fixes/spec`.
  - **URL** = a relative path resolved **from the referencing file's own directory** (or workspace root for chat reports). Examples: spec→ADR `../../adr/<slug>.md`; ADR→sibling ADR `<slug>.md`; spec→sibling spec `../<feature-dir>/spec.md`; `analysis.md`→ADR `../../adr/<slug>.md`; chat→ADR `docs/maxi/adr/<slug>.md`.
  - There is **no `id — title` variant** and no terse/explicit distinction: the filename-without-`.md` is the visible text in every context. This makes the convention purely mechanical (derivable from the path alone, no H1-title lookup) and stable.

## Clarifications

**Q: What is the canonical format for entries in the spec's `related_adrs` field?**
A: Full ADR slugs (e.g. `["0003-constitution-decoupled-from-claudemd"]`), not bare numbers or integers. This mirrors the prior `related_specs` convention (which already used full spec slugs), is self-documenting, and stays stable because ADR slugs are append-only. `analyze` resolves each slug directly to its `docs/maxi/adr/<slug>.md` file.

**Q: How should FR-016 (spec 0002) and FR-017 (spec 0016) — which require `migrate-adr` to populate `related_principles` — be neutralized?**
A: Add an in-place supersession **note that links to this spec** on each affected FR, without changing those specs' `status` (they remain `done` historical archives). The link makes the reconciliation traceable from the old requirement. The behavioral removal is carried by FR-007 (producers stop emitting the field) and the `tests/check-migrate-adr.sh` assertion is dropped.

**Q: Should the "render artifact references as clickable links" convention be scoped to this feature's touch points, or be a project-wide convention?**
A: Project-wide. The spec's theme was broadened from "traceability direction" to "artifact cross-reference conventions" so it covers both the *direction* (Axis 1) and the *form* (Axis 2, clickable links) under one responsibility. The convention applies to all maxi skills that emit prose references (FR-018), exempts frontmatter data and within-document ID references (FR-019), and is enforced via skill authoring guidance rather than a brittle automated test (FR-020).

**Q: What is the visible text of a rendered artifact link?**
A: The target file's name without its `.md` extension — for an ADR this is its slug (`0003-constitution-decoupled-from-claudemd`), matching the token stored in `related_adrs`. Generic spec-artifact files (`spec.md`/`plan.md`/`tasks.md`/`analysis.md`) are prefixed with their feature directory (`0002-migrate-adr-review-fixes/spec`) since the bare name is non-identifying. Non-`.md` files keep their full filename. There is no `id — title` variant: the rule is purely mechanical (derivable from the path, no title lookup) and stable. Captured as the **Link rendering convention** Key Entity.

**Q: Does the link convention apply retroactively to the existing artifact corpus, or only to newly-emitted prose?**
A: Forward-only (FR-021). The convention governs prose emitted after the feature ships; pre-existing bare references in current specs, ADRs, and docs are left as-is. Decisive factor: ADR bodies are append-only (FR-013) and cannot be retrofitted, so a full retrofit is impossible — retrofitting only specs/docs would yield an inconsistent corpus. No retrofit is performed.

**Revised (2026-05-31):** Rolled back from `analyzed` to `tasked`. Change: applied analysis findings E1 and C1 — added **FR-022** (ADR index column rebuilt by spec-side reverse-lookup) and reworded **SC-003** into an explicit manual acceptance check. Note: `plan.md` and `tasks.md` already cover this behavior (T007/T010/T016) and remain valid; `analysis.md` from the prior run is stale and is regenerated by re-running `/maxi:analyze`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero ADR frontmatter blocks in the repository contain `related_specs`, `related_principles`, or `related_requirements` after the change (grep returns no frontmatter matches across `docs/maxi/adr/`, the template, and the fixture).
- **SC-002**: 100% of the previously-encoded `related_specs` links (6 ADRs) are preserved as `related_adrs` entries on the corresponding specs — no traceability link is lost in the transition.
- **SC-003**: `analyze` Pass G1 and G3 are **manually confirmed** behavior-preserving: running `/maxi:analyze` on a spec whose plan names an ADR-less consequential tech choice still fires G1, and on a spec referencing a superseded ADR still fires G3 — both resolved via the spec-side registry. This is a manual acceptance check; there is no automated analyze fixture in the fast tier (T016).
- **SC-004**: Both `bash tests/run-all.sh` (fast tier) and `tests/check-migrate-adr.sh` pass with no `related_principles`/`related_requirements`/`related_specs` assertions remaining in the ADR schema tests.
- **SC-005**: Every skill named in FR-018 has its output/report guidance updated to render artifact references as relative Markdown links; a spot-check of each skill's emitted reference style confirms link form (not bare slug) for cross-file references.

## Assumptions

- The constitution does not define the ADR schema field-by-field, so no constitution amendment (and no version bump) is required to remove the three fields — verified against `docs/maxi/constitution.md`.
- `related_adrs` is a frontmatter list of **full ADR slugs** (e.g. `"0003-constitution-decoupled-from-claudemd"`), preferred over a prose `## Decisions` body section. Full slugs mirror the prior `related_specs` convention (which used full spec slugs) and stay stable because ADR slugs are append-only; `analyze` resolves each slug directly to its `docs/maxi/adr/<slug>.md` file.
- Inline `ADR-NNNN` mentions remain a tolerated, secondary link source; `related_adrs` is canonical. This preserves `analyze` G3's existing inline-scanning behavior as a fallback.
- The four pipeline docs (`using-maxi`, `architecture.md`, `pipeline-flow.md`, `delegation-map.md`) do not currently mention the removed fields — verified — so the documentation-sync surface is limited to `CLAUDE.md`, `architecture.md`, and the skill/template/test files named in the requirements.
- Reconciling FR-016/FR-017 by supersession (not deletion) keeps the historical record intact, consistent with the project's append-only and spec-as-archive conventions.
- The spec's theme is "artifact cross-reference conventions" — direction (Axis 1) and link form (Axis 2) are treated as one responsibility because both govern how artifacts reference each other. The link convention (Axis 2) is enforced by skill authoring guidance, not automation, because reliably detecting "a bare slug that should be a link" in free prose is brittle; the boundary is stated explicitly (FR-020) so the absence of a test is intentional.
