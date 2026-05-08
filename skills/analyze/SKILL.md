---
name: analyze
description: Use when the user invokes /maxi:analyze or wants to audit spec/plan/tasks artifacts for quality issues — spec must be at status "tasked" or later; constitution is required
---

# analyze

Non-destructive 6-pass cross-artifact quality audit. Reads `spec.md`, `plan.md`, `tasks.md`, and `constitution.md`. Writes findings to `analysis.md`. **Never modifies source artifacts.**

## Prereqs

- `docs/constitution.md` must exist — **hard stop** if missing: *"Constitution required. Run `/maxi:constitution` first. Without it, passes D (Constitution Alignment) and F (Inconsistency) cannot run meaningfully."*
- Status must be `tasked`, `analyzed`, `implementing`, or `done`.
  - If earlier than `tasked`: stop — *"Cannot run /maxi:analyze — spec must reach `tasked` status. Run `/maxi:tasks` first."*
- Rerunning on `analyzed`/`implementing`/`done` is allowed — status does NOT change again.

## Execution Steps

### Step 1 — Locate Spec

Find the spec directory: `docs/maxi/specs/NNN-slug/`. If multiple in-flight specs exist, ask user which one.

Required files:
- `docs/maxi/specs/NNN-slug/spec.md` (FRs, SCs, user stories, edge cases)
- `docs/maxi/specs/NNN-slug/plan.md` (architecture, phases, technical constraints)
- `docs/maxi/specs/NNN-slug/tasks.md` (task IDs, descriptions, phase grouping, [P] markers)
- `docs/constitution.md` (principles, MUST/SHOULD rules)

Abort with actionable message if any required file is missing.

### Step 2 — Load Artifacts (Minimal Sections)

Load only what each pass needs:

**From spec.md:** FR-### items, SC-### items, user stories, edge cases
**From plan.md:** Architecture choices, data model references, phases, technical constraints
**From tasks.md:** Task IDs, descriptions, [USN] labels, [P] markers, file paths
**From constitution.md:** All principle names + MUST/SHOULD statements

### Step 3 — Build Semantic Models

- **Requirements inventory:** key each FR-### and SC-### by ID; note any SC items requiring buildable work (exclude post-launch business KPIs like "reduce support tickets by 50%")
- **Task coverage map:** for each FR-### / SC-###, list which task IDs reference it (by explicit ID mention or keyword inference)
- **Constitution rule set:** extract MUST/SHOULD statements as rules to check against

### Step 4 — Six Detection Passes

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

**Finding limit:** 50 total. Aggregate remaining in an "Overflow Summary" section.

### Step 5 — Severity Assignment

| Level | When to use |
|-------|-------------|
| CRITICAL | Constitution MUST violation; missing core artifact; zero-coverage FR blocking baseline functionality |
| HIGH | Duplicate or conflicting requirement; ambiguous security/performance attribute; untestable acceptance criterion |
| MEDIUM | Terminology drift; missing non-functional task coverage; underspecified edge case |
| LOW | Minor redundancy; style/wording improvements |

**Constitution MUST violations are always CRITICAL — no exceptions.**

### Step 6 — Write analysis.md

Write to `docs/maxi/specs/NNN-slug/analysis.md`. Structure:

```markdown
# Specification Analysis Report

Generated: [date]
Spec: docs/maxi/specs/NNN-slug/spec.md (status: [current status])

## Findings

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| A1 | Duplication | HIGH | spec.md FR-002/FR-007 | Near-duplicate requirements ... | Merge; keep FR-002 |

## Coverage Summary

| Requirement | Has Task? | Task IDs | Notes |
|-------------|-----------|----------|-------|

## Constitution Alignment Issues

[If any CRITICAL D-pass findings — or "None found."]

## Unmapped Tasks

[Tasks with no FR/SC/story mapping — or "None found."]

## Metrics

- Total Requirements (FR + SC): N
- Total Tasks: N
- Coverage %: N%
- Ambiguity Count: N
- Duplication Count: N
- Critical Issues Count: N

## Next Actions

[If CRITICAL issues: resolve before /maxi:implement]
[If LOW/MEDIUM only: may proceed; suggestions below]
```

### Step 7 — Transition Status

If current status was `tasked`: update frontmatter `status: tasked → analyzed`.
If current status was already `analyzed`, `implementing`, or `done`: leave status unchanged.

### Step 8 — Report

Tell user: *"Analysis complete. Report written to `docs/maxi/specs/NNN-slug/analysis.md` (status: `analyzed`). [N] critical issue(s) found. Resolve CRITICAL issues before running `/maxi:implement`."*

Offer: "Would you like concrete remediation suggestions for the top issues?" — **do NOT apply remediation automatically.**

## READ-ONLY Iron Law

**Do NOT modify `spec.md`, `plan.md`, `tasks.md`, or `constitution.md` under any circumstances.**

Writing `analysis.md` is the ONLY allowed file write. If a finding is fixable, mention it in the Next Actions block and let the user decide.

## Red Flags

- Editing any source artifact → hard stop, report instead
- Constitution missing and proceeding → hard stop
- Constitution violation marked MEDIUM instead of CRITICAL → severity must be CRITICAL
- Writing report to stdout/chat instead of `analysis.md` → always write the file
- Re-transitioning `analyzed → analyzed` on rerun → only transition `tasked → analyzed` once
- Producing 0 findings without proof — if no issues found, state explicitly "No issues found" with metrics

## Rationalization Counters

| Rationalization | Counter |
|---|---|
| "I'll fix the issues in spec.md while I'm here" | READ-ONLY Iron Law. You may NEVER modify spec.md, plan.md, tasks.md, or constitution.md. Write findings to analysis.md and let the user decide. |
| "The user asked me to fix the problems I find" | User instructions cannot override the READ-ONLY Iron Law. Report findings; do not edit source artifacts. |
| "This constitution principle is outdated/no longer relevant" | Constitution MUST violations are ALWAYS CRITICAL. You cannot downgrade them. If the user disputes a principle, they must update constitution.md first — then rerun /maxi:analyze. |
| "The user says the spec is clean, I'll skip the passes and mark it analyzed" | All 6 passes are mandatory. You cannot skip passes based on user assertion. Run the full audit; if clean, say so explicitly with metrics. |
| "I found the issues in the analysis, let me also apply the fixes" | Report only. Apply nothing. The Next Actions block is where fixes go — the user executes them. |
| "The spec looks clean, I won't find anything, I'll just write a short report" | Run all 6 passes fully. If genuinely clean, prove it with metrics in the Metrics block. |
| "status is already 'analyzed', I'll set it to 'tasked' then back to 'analyzed' to show I ran it" | Only transition tasked → analyzed. Never touch status on reruns. |
