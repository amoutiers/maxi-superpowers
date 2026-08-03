---
name: analyze
description: Use when the user invokes /maxi:analyze or wants to audit spec/plan/tasks artifacts for quality issues — spec must be at status "tasked" or later; constitution is required
---

# analyze

Non-destructive 7-pass cross-artifact quality audit. Reads `spec.md`, `plan.md`, `tasks.md`, `constitution.md`, and any ADRs in `docs/maxi/adr/`. Writes findings to `analysis.md`. **Never structurally modifies source artifact bodies; its sole source-file write is the non-structural `spec.md` status/timestamp update in Step 8.**

## Prereqs

- `docs/maxi/constitution.md` must exist — **hard stop** if missing: *"Constitution required. Run `/maxi:constitution` first. Without it, passes D (Constitution Alignment) and F (Inconsistency) cannot run meaningfully."*
- Status must be `tasked`, `analyzed`, `implementing`, or `done`.
  - If earlier than `tasked`: stop — *"Cannot run /maxi:analyze — spec must reach `tasked` status. Run `/maxi:tasks` first."*
- Rerunning on `analyzed`/`implementing`/`done` is allowed — status does NOT change again.

## Execution Steps

### Step 1 — Locate Spec

Find the spec directory: `docs/maxi/specs/NNNN-slug/`. If multiple in-flight specs exist, ask user which one.

Required files:
- `docs/maxi/specs/NNNN-slug/spec.md` (FRs, SCs, user stories, edge cases)
- `docs/maxi/specs/NNNN-slug/plan.md` (architecture, phases, technical constraints)
- `docs/maxi/specs/NNNN-slug/tasks.md` (task IDs, descriptions, phase grouping, [P] markers)
- `docs/maxi/constitution.md` (principles, MUST/SHOULD rules)

Also locate every support artifact present beside the plan (`research.md`, `data-model.md`, `quickstart.md`, and `contracts/*.md`). These are required direct inputs for a forward-pipeline analysis when present.

Abort with actionable message if any required file is missing.

### Step 2 — Verify Independent Reviewer Context

For a forward-pipeline spec carrying revision metadata, require one fresh reviewer context issued by the harness for this analysis invocation. Validate it with the same canonical single-line context grammar as `x-review`; never normalize or repair it.

Read the complete current frontmatter of `spec.md`, `plan.md`, and `tasks.md`. The reviewer context must be absent from the current `spec.md`, `plan.md`, and `tasks.md` `structural_contributors` lists. Any missing or malformed contributor metadata, malformed context, or contributor match is non-independent and fails closed before any analysis write and before any status transition. Do not dispatch or perform the audit under another context.

The verified reviewer context is both `analysis.md`'s `reviewer_context` and its `writer_context`. This skill writes no structural source artifact content or review record. Its sole source-file write is the non-structural `spec.md` status/timestamp update in Step 8; it never asks `x-review` to manufacture final-analysis evidence.

### Step 3 — Load Artifacts (Minimal Sections)

Load only what each pass needs:

**From spec.md:** FR-### items, SC-### items, user stories, edge cases
**From plan.md:** Architecture choices, data model references, phases, technical constraints
**From tasks.md:** Task IDs, descriptions, [USN] labels, [P] markers, file paths
**From support artifacts:** Claims, entities, schemas, examples, and contracts needed to cross-check the core artifacts
**From constitution.md:** All principle names + MUST/SHOULD statements
**From docs/maxi/adr/ (if exists):** All ADR files — adr number, title, status, Decision section, Consequences section

### Step 4 — Build Semantic Models

- **Requirements inventory:** key each FR-### and SC-### by ID; note any SC items requiring buildable work (exclude post-launch business KPIs like "reduce support tickets by 50%")
- **Task coverage map:** for each FR-### / SC-###, list which task IDs reference it (by explicit ID mention or keyword inference)
- **Constitution rule set:** extract MUST/SHOULD statements as rules to check against
- **ADR registry:** list all `docs/maxi/adr/NNNN-*.md` files; for each record adr number, title, status, and the decision domain (tech stack, storage, runtime, framework). Build the spec↔ADR map from the *spec* side: collect this spec's `related_adrs:` frontmatter (a list of full ADR slugs) PLUS any inline `ADR-NNNN` mentions in spec.md/plan.md/tasks.md. Do NOT derive this map from any `related_specs` field — ADRs no longer carry one. If `docs/maxi/adr/` does not exist or is empty, Pass G reports "no ADRs recorded" in Metrics and skips G-type findings.

### Step 5 — Seven Detection Passes

#### A. Duplication
Find near-duplicate requirements with different FR-### IDs. Mark lower-quality phrasing.

#### B. Ambiguity
- Flag vague adjectives without measurable criteria: "fast", "scalable", "robust", "secure", "user-friendly", "simple", "intuitive"
- Flag unresolved placeholders: TODO, TKTK, ???, `<placeholder>`, `[NEEDS CLARIFICATION]`

#### C. Underspecification
- Requirements with verbs but missing object or measurable outcome
- User stories missing acceptance criteria or Independent Test
- Tasks referencing files or components not defined anywhere in spec/plan

#### D. Constitution Alignment
- Any FR or plan element conflicting with a constitution MUST rule → always CRITICAL
- Missing mandated sections or quality gates from constitution

#### E. Coverage Gaps
- FRs and SCs with zero associated tasks
- Tasks with no mapped FR/SC or user story
- SC items requiring infrastructure (performance testing, security auditing) with no corresponding tasks

#### F. Inconsistency
- Terminology drift: same concept named differently across spec/plan/tasks
- Data entities in plan not mentioned in spec (or vice versa)
- Conflicting requirements (e.g., spec says Next.js, plan says Vue)
- Task ordering contradictions (integration before foundational with no dependency note)

#### G. ADR Alignment

Skip this pass entirely (and note "no ADRs" in Metrics) if `docs/maxi/adr/` is empty or missing.

- **G1 — Missing ADR (MEDIUM):** plan.md names a consequential technology choice (storage engine, runtime, primary framework) for which the spec references no accepted ADR — i.e. the choice is covered by neither the spec's `related_adrs:` frontmatter nor any inline `ADR-NNNN` mention in spec.md/plan.md/tasks.md. One finding per unrecorded choice. Note: only flag consequential choices, not incidental library picks.
- **G2 — ADR-Constitution conflict (CRITICAL):** An accepted ADR's Decision or Consequences section makes a statement that directly contradicts a constitution MUST principle. ADR-Constitution conflicts are always CRITICAL — same rule as D-pass violations.
- **G3 — Stale ADR reference (HIGH):** spec.md, plan.md, or tasks.md mentions or links to an ADR by number, and that ADR has status `deprecated` or `superseded`. Stale references are HIGH — they indicate the artifacts are out of sync with the decision log.
- **G4 — Cyclic supersede (HIGH):** Following the `supersedes:` chain for any ADR leads back to itself (A supersedes B supersedes A). This corrupts the ADR history and must be resolved.

**Finding limit:** 50 total across all passes. Aggregate remaining in an "Overflow Summary" section.

### Step 6 — Severity Assignment

| Level | When to use |
|-------|-------------|
| CRITICAL | Constitution MUST violation; missing core artifact; zero-coverage FR blocking baseline functionality |
| HIGH | Duplicate or conflicting requirement; ambiguous security/performance attribute; untestable acceptance criterion |
| MEDIUM | Terminology drift; missing non-functional task coverage; underspecified edge case |
| LOW | Minor redundancy; style/wording improvements |

**Constitution MUST violations are always CRITICAL — no exceptions.**

### Step 7 — Write analysis.md

Write to `docs/maxi/specs/NNNN-slug/analysis.md`. Structure:

```markdown
---
revision: 1
writer_context: <unique-writer-context>
structural_contributors:
  - <unique-writer-context>
reviewer_context: <same-unique-writer-context>
reviewer_context_matches_harness: true
independence_verified: true
analysis_result: <passed-or-failed>
derived_from:
  - spec.md@<exact-revision-read>
  - <support-artifact-path>@<exact-revision-read>
  - plan.md@<exact-revision-read>
  - tasks.md@<exact-revision-read>
---

# Specification Analysis Report

Generated: [date]
Spec: docs/maxi/specs/NNNN-slug/spec.md (status: [current status])

## Findings

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| A1 | Duplication | HIGH | spec.md FR-002/FR-007 | Near-duplicate requirements ... | Merge; keep FR-002 |

## Coverage Summary

| Requirement | Has Task? | Task IDs | Notes |
|-------------|-----------|----------|-------|

## Constitution Alignment Issues

[If any CRITICAL D-pass findings — or "None found."]

## ADR Alignment Issues

[If any G-pass findings — or "No ADRs recorded." if docs/maxi/adr/ is empty — or "None found."]

## Unmapped Tasks

[Tasks with no FR/SC/story mapping — or "None found."]

## Metrics

- Total Requirements (FR + SC): N
- Total Tasks: N
- Coverage %: N%
- Ambiguity Count: N
- Duplication Count: N
- Critical Issues Count: N
- ADRs Recorded: N (or "none")

## Next Actions

[If CRITICAL issues: resolve before /maxi:implement]
[If LOW/MEDIUM only: may proceed; suggestions below]
```

This frontmatter applies only to the first `analysis.md` created for a spec created through the normal forward pipeline. Use the verified reviewer context as the non-empty writer context unique across that spec's pipeline-owned documents. The `derived_from` entries are the reviewed current revisions: include current `spec.md`, current `plan.md`, current `tasks.md`, and every present support artifact at the exact revision read. Constitution and ADR files remain audit context outside this spec-local replay graph.

Set `analysis_result: passed` only when the completed seven-pass report has zero CRITICAL findings; otherwise set `analysis_result: failed`. Persisting the report, verified context, exact reviewed revisions, independence result, and analysis result happens in the same `analysis.md` write. Do not use the review-record-only `verdict` field.

On a later structural rewrite of `analysis.md`, repeat the independence gate with a fresh harness-issued reviewer context, increment only its revision, replace both `writer_context` and `reviewer_context` with that verified context, and append it to `structural_contributors`. Status, timestamps, task-completion checkboxes, and `related_adrs` are non-structural and never increment a revision or append a contributor. Do not add or infer revision, writer-context, contributor, or derived-input metadata for existing, migrated, or reverse-engineered specs.

### Step 8 — Transition Status

The persisted result determines the analyze owner action:

| Persisted result branch | Analyze owner action |
|---|---|
| `analysis_result: passed` | Persist the report, then apply the Step 8 status/timestamp rule. |
| `analysis_result: failed` after an approved replay | Keep `status: tasked`, consume the earlier replay `yes`, start no correction, replay, or phase invocation, and require a new explicit user decision. |

If current status was `tasked` and `analysis_result: passed`: update spec.md frontmatter `status: tasked → analyzed`; also set `updated: [today's ISO date]` on spec.md. This status/timestamp update is non-structural and leaves spec.md provenance unchanged.
If current status was `tasked` and `analysis_result: failed`: leave the status at `tasked`. Persist and report the failed analysis, then wait for the new explicit decision required below.
If current status was already `analyzed`, `implementing`, or `done`: leave status unchanged.

### Step 9 — Report

For a passing initial analysis, tell user: *"Analysis complete. Report written to `docs/maxi/specs/NNNN-slug/analysis.md` (status: `analyzed`). 0 critical issues found. `/maxi:implement` may now validate this evidence."*

For a failed analysis, tell user: *"Analysis complete with blocking findings. Report written to `docs/maxi/specs/NNNN-slug/analysis.md` (status unchanged). [N] critical issue(s) found. A new explicit decision is required before correction or replay."*

Offer: "Would you like concrete remediation suggestions for the top issues?" — **do NOT apply remediation automatically.**

If this analysis follows one approved replay and its persisted analysis result is `failed`, report the failure and require a new explicit user decision before any next action. Start no correction, no replay, and no phase invocation; do not treat the replay's earlier `yes` as consent to continue. The same stop applies to any failed analysis, whether or not it was reached by replay.

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.

## READ-ONLY Iron Law

**Do NOT structurally modify `spec.md`, `plan.md`, `tasks.md`, `constitution.md`, or any ADR file under any circumstances.**

Writing `analysis.md` is the only artifact-body write. The explicit non-structural `tasked → analyzed` status/timestamp transition in Step 8 is the sole source-file exception. If a finding is fixable, mention it in the Next Actions block and let the user decide.

## Red Flags

- Editing structural content in any source artifact → hard stop, report instead; the Step 8 non-structural `spec.md` status/timestamp update remains allowed
- Constitution missing and proceeding → hard stop
- Constitution violation marked MEDIUM instead of CRITICAL → severity must be CRITICAL
- Writing report to stdout/chat instead of `analysis.md` → always write the file
- Re-transitioning `analyzed → analyzed` on rerun → only transition `tasked → analyzed` once
- Producing 0 findings without proof — if no issues found, state explicitly "No issues found" with metrics
- Reusing an author or corrector context for the analysis → fail closed before writing
- A failed analysis starting a correction or replay → report it and await a new explicit decision

## Rationalization Counters

| Rationalization | Counter |
|---|---|
| "I'll fix the issues in spec.md while I'm here" | Structural source edits are forbidden. The Step 8 `spec.md` status/timestamp update is non-structural; otherwise write findings only to analysis.md and let the user decide. |
| "The user asked me to fix the problems I find" | User instructions cannot override the structural READ-ONLY Iron Law. Report findings; do not edit source artifact bodies. The Step 8 non-structural `spec.md` status/timestamp update remains allowed. |
| "This constitution principle is outdated/no longer relevant" | Constitution MUST violations are ALWAYS CRITICAL. You cannot downgrade them. If the user disputes a principle, they must update constitution.md first — then rerun /maxi:analyze. |
| "The user says the spec is clean, I'll skip the passes and mark it analyzed" | All 7 passes are mandatory. You cannot skip passes based on user assertion. Run the full audit; if clean, say so explicitly with metrics. |
| "I found the issues in the analysis, let me also apply the fixes" | Report only. Apply nothing. The Next Actions block is where fixes go — the user executes them. |
| "The spec looks clean, I won't find anything, I'll just write a short report" | Run all 7 passes fully. If genuinely clean, prove it with metrics in the Metrics block. |
| "Pass G requires ADRs, we don't have any yet, I'll skip it" | If docs/maxi/adr/ is empty or missing, Pass G skips automatically and the Metrics block notes "no ADRs recorded". You do not decide to skip it — the precondition check decides. |
| "status is already 'analyzed', I'll set it to 'tasked' then back to 'analyzed' to show I ran it" | Only transition tasked → analyzed. Never touch status on reruns. |
