---
slug: 0016-migrate-adr
created: 2026-05-30
updated: 2026-05-30
status: done
origin: reverse-engineered
source_sha: 7f945f8a8548bf1b4b123d28cc097e2cca897c68
parked_from: null
---

# Feature Specification: migrate-adr — Bootstrap a Project's maxi ADR Log

The `migrate-adr` skill bootstraps a project's `docs/maxi/adr/` directory by populating it from two sources running in parallel: an **Importer** that finds existing ADR files (Nygard, MADR, or plain Markdown) and converts them to maxi format, and a **Discoverer** that surfaces undocumented architectural decisions from package manifests, config files, directory structure, and git history. It is non-destructive (originals are never deleted or moved), requires no spec status, and gates every single ADR write behind explicit per-proposal user consent. The `--import-only` flag suppresses the Discoverer. After the consent loop completes, it regenerates `docs/maxi/adr/README.md` once.

## User Scenarios & Testing

### User Story 1 - Import existing ADR files into maxi format (Priority: P1)

A user with an existing ADR collection (e.g. `docs/adr/` in Nygard format) runs `/maxi:migrate-adr` to bring those records into the maxi ADR log without rewriting them by hand.

**Why this priority**: Importing pre-existing, already-authored decisions is the highest-fidelity migration path — the decisions are explicit on disk and only need format conversion, so this is the core value and the only path that runs under `--import-only`.

**Independent Test**: Run `/maxi:migrate-adr --import-only` against a project containing Nygard/MADR/plain ADR files; verify each detected file is presented as a draft and, on `accept`, written to `docs/maxi/adr/` with provenance `source:` frontmatter pointing at the original, while originals remain untouched.

**Acceptance Scenarios**:

1. **Given** `docs/adr/0001-use-postgres.md` in Nygard format (`## Status`, `## Context`, `## Decision`, `## Consequences`) and a present constitution, **When** the Importer runs, **Then** the file is detected as Nygard, its sections mapped to maxi fields, missing sections (`## Decision Drivers`, `## Considered Options`, `## Confirmation`) filled with the explicit "Not recorded in source ADR" placeholders, and the draft shown to the user.
2. **Given** a MADR file with YAML frontmatter (`title:`, `status:`, `deciders:`, `date:`), **When** the Importer runs, **Then** `deciders:`→`decider:`, `date:`→`created:`, and `status:` are mapped to maxi frontmatter and the draft is presented.
3. **Given** the user responds `accept` to an imported draft, **When** the consent gate processes it, **Then** the ADR is written with `status: accepted`, NNNN assigned from the current max at write time, and the original source file is preserved.
4. **Given** the user responds `deprecate` to an imported draft, **When** the consent gate processes it, **Then** the ADR is written with `status: deprecated`.
5. **Given** the user responds `skip` to an imported draft, **When** the consent gate processes it, **Then** no file is written and nothing is logged to `.rejected` (the source file on disk is already the record).
6. **Given** a `README.md` / `template.md` / `index.md` / `CONTRIBUTING.md` in a scanned ADR directory, **When** the Importer scans, **Then** the file is skipped by the filename blocklist before format detection (so a project README is never imported via the plain-Markdown catch-all).

### User Story 2 - Discover undocumented architectural decisions (Priority: P2)

A user whose project has no written ADRs (or partial ones) runs `/maxi:migrate-adr` to surface significant decisions implied by the codebase — dependencies, CI config, repo layout, and git-history signals — and record the worthwhile ones.

**Why this priority**: Discovery is inference-based and lower-fidelity than import, and is skippable via `--import-only`; it is a force-multiplier on top of import but not strictly required for the skill to deliver value.

**Independent Test**: Run `/maxi:migrate-adr` (without `--import-only`) against a project with manifests/config/git history but no ADR files; verify discovered decisions that pass the significance rubric are proposed, gated for consent, and written with `decider: "[unknown — inferred from code analysis]"`.

**Acceptance Scenarios**:

1. **Given** a `Cargo.toml` selecting a costly-to-reverse runtime/framework, **When** the Discoverer runs, **Then** a proposal is produced because it meets the significance rubric (costly to reverse / constrains future choices / was contested).
2. **Given** a trivially-reversible, uncontested choice (e.g. a code formatter / `.prettierrc`), **When** the Discoverer runs, **Then** no proposal is produced (the rubric filters out trivia).
3. **Given** a discovered decision relates to a named constitution principle passed by the orchestrator, **When** the draft is built, **Then** `related_principles` is set to that principle and the link is noted in `## Context`; if none relates, `related_principles: []` and no link is fabricated.
4. **Given** the user responds `skip` to a discovered proposal, **When** the consent gate processes it, **Then** no file is written AND the proposal's domain label is appended to `docs/maxi/adr/.rejected` so a future re-run does not re-propose it.
5. **Given** the user responds `accept` to a discovered proposal, **When** the consent gate processes it, **Then** the ADR is written with `status: accepted`.

### Edge Cases

- **No constitution**: if `docs/maxi/constitution.md` is missing, the skill stops immediately with "No constitution found. Run `/maxi:constitution` first." before any work.
- **Nothing found**: if neither importer nor discoverer produces proposals, output "Nothing to migrate and no architectural decisions detected. Use `/maxi:x-adr` to record decisions manually." and exit cleanly.
- **Importer finds nothing**: reported, but the Discoverer still runs (unless `--import-only`).
- **Discoverer finds nothing**: reported, but Importer results are still presented.
- **Unsupported file format**: skipped with a warning; processing continues.
- **Ambiguous consent response** ("ok", "sure", "yes", "no", silence): intent is never inferred — the gate re-asks once naming the explicit verbs; a second ambiguous response defaults to `skip` (no file written).
- **Same domain proposed by both subagents**: the imported draft wins as the base, discovery evidence is appended under `## Context` → `### Additional evidence`, and the discovered duplicate is dropped. When uncertain whether two proposals share a domain, both are kept.
- **Partial-overlap / no-qualifying-token exclusion match**: surfaced to the user, never auto-excluded — biasing against false exclusions.
- **Non-empty `docs/maxi/adr/`**: existing ADRs are read first to build exclusion context, then new ADRs are appended (append-only; existing files are never edited).

## Requirements

### Functional Requirements

- **FR-001**: System MUST require `docs/maxi/constitution.md` to exist; if missing, stop immediately with "No constitution found. Run `/maxi:constitution` first." (skills/migrate-adr/SKILL.md:89-91)
- **FR-002**: System MUST read existing `docs/maxi/adr/NNNN-*.md` files and `docs/maxi/adr/.rejected` (treating missing as empty) to build an exclusion context before dispatching subagents. (skills/migrate-adr/SKILL.md:98)
- **FR-003**: System MUST normalize exclusion labels by lowercasing and stripping stopwords (`use`, `for`, `the`, `a`, `as`, `with`, `to`), then match by proper-noun token set (or longest remaining 3+ char token). (skills/migrate-adr/SKILL.md:100)
- **FR-004**: System MUST exclude a new proposal only on an equal token set; on partial overlap, no-overlap-keep, or no-qualifying-token, it MUST keep or flag rather than auto-exclude. (skills/migrate-adr/SKILL.md:104-109)
- **FR-005**: System MUST dispatch the Importer and Discoverer subagents in parallel, passing the exclusion context to both and the constitution's principle names to the Discoverer. (skills/migrate-adr/SKILL.md:117)
- **FR-006**: System MUST dispatch only the Importer (skip the Discoverer) when invoked with `--import-only`. (skills/migrate-adr/SKILL.md:117)
- **FR-007**: Both subagents MUST return proposals in a fixed schema with `source`, `domain_label`, `title`, `body` (and importer-only `format`, `source_path`). (skills/migrate-adr/SKILL.md:119-129)
- **FR-008**: The Importer MUST scan `doc/adr/`, `docs/adr/`, `docs/decisions/`, `docs/architecture/`, `adr/`, `ADRs/` for `.md` files. (skills/migrate-adr/import-subagent.md:7-8)
- **FR-009**: The Importer MUST skip files whose basename (case-insensitive) is `README.md`, `index.md`, `template.md`, or `CONTRIBUTING.md` before format detection. (skills/migrate-adr/import-subagent.md:10)
- **FR-010**: The Importer MUST detect format per file as Nygard (no frontmatter; `## Status`/`## Context`/`## Decision`/`## Consequences`), MADR (frontmatter with `title:`/`status:`/`deciders:`), or Plain Markdown (H1, matching neither), and skip files matching no format with a warning. (skills/migrate-adr/import-subagent.md:12-20)
- **FR-011**: The Importer MUST map Nygard `## Status` values to maxi `status:` (Accepted→accepted, Proposed→proposed, Deprecated→deprecated, Superseded→superseded, Rejected→deprecated) and fill missing sections with the explicit "Not recorded in source ADR" placeholders. (skills/migrate-adr/import-subagent.md:22-33)
- **FR-012**: The Importer MUST map MADR fields (`title:`/`status:`/`deciders:`→`decider:`/`date:`→`created:`, Context, Decision Drivers, Considered Options, Decision Outcome, Consequences) to maxi fields. (skills/migrate-adr/import-subagent.md:37-50)
- **FR-013**: The Importer MUST map a Plain-Markdown body verbatim to `## Context`, extract the H1 as title and a date from filename/first paragraph, and fill all other sections with the explicit placeholder text. (skills/migrate-adr/import-subagent.md:52-58)
- **FR-014**: Every imported ADR MUST carry a `source:` frontmatter field recording the original file path (or `[unknown]`) for provenance, plus the documented frontmatter invariants. (skills/migrate-adr/import-subagent.md:60-73)
- **FR-015**: The Discoverer MUST analyze package manifests, config files, directory structure, and git history (`git log -n 200 --format="%H %s%n%b"` scanned for keywords: chose, decided, switched, migrated, replaced, adopted, dropped, moved to). (skills/migrate-adr/discover-subagent.md:8-15)
- **FR-016**: The Discoverer MUST propose a decision only if it is costly to reverse, constrains future choices, or was contested — dropping easily-reversible, uncontested choices. (skills/migrate-adr/discover-subagent.md:19)
- **FR-017**: The Discoverer MUST set `related_principles` to a constitution principle when a discovered decision relates to it, and leave it `[]` otherwise without fabricating a link. (skills/migrate-adr/discover-subagent.md:21)
- **FR-018**: Every discovered ADR MUST carry the default frontmatter including `decider: "[unknown — inferred from code analysis]"` and uncertain fields prefixed `[inferred]`. (skills/migrate-adr/discover-subagent.md:23-36)
- **FR-019**: When the Importer and Discoverer propose the same domain, the system MUST use the imported draft as the base, append discovery evidence under `## Context` → `### Additional evidence`, and drop the discovered proposal; keep both when domain-sharing is uncertain. (skills/migrate-adr/SKILL.md:146-151)
- **FR-020**: System MUST display a summary table of imported and discovered proposals (with a row-index `#` column) before the consent loop, and exit cleanly with the "Nothing to migrate" message if there are none. (skills/migrate-adr/SKILL.md:159-171)
- **FR-021**: System MUST gate every ADR write behind explicit per-proposal consent, showing the full draft and never writing any file before showing the draft and receiving an explicit verb. (skills/migrate-adr/SKILL.md:176-179, skills/migrate-adr/SKILL.md:24)
- **FR-022**: For imported proposals the consent verbs MUST be accept (write accepted) / skip (no file) / deprecate (write deprecated) / edit (amend inline, write accepted). (skills/migrate-adr/SKILL.md:181-189)
- **FR-023**: For discovered proposals the consent verbs MUST be accept (write accepted) / skip (discard) / edit (amend inline, write accepted). (skills/migrate-adr/SKILL.md:191-198)
- **FR-024**: On an ambiguous consent response the system MUST re-ask once naming the explicit verbs and, if the second response is still ambiguous, default to `skip` with no file written. (skills/migrate-adr/SKILL.md:200-205)
- **FR-025**: On `skip` of a discovered proposal the system MUST append its domain label to `docs/maxi/adr/.rejected` (creating the file with a `#`-comment header on first write); on `skip` of an imported proposal it MUST NOT log anything. (skills/migrate-adr/SKILL.md:207)
- **FR-026**: System MUST compute the NNNN ADR number from the current max in `docs/maxi/adr/` at write time, not at proposal time. (skills/migrate-adr/SKILL.md:209)
- **FR-027**: System MUST regenerate `docs/maxi/adr/README.md` exactly once after the consent loop completes (partial regeneration on early exit), as a table with columns ADR number, title, status, created, related specs. (skills/migrate-adr/SKILL.md:211)
- **FR-028**: System MUST be non-destructive and append-only: never delete, move, or retroactively edit original ADR files or existing `docs/maxi/adr/` files. (skills/migrate-adr/SKILL.md:16, skills/migrate-adr/SKILL.md:231-234)

### Key Entities

- **Nygard ADR**: a Markdown file with no YAML frontmatter and `## Status`, `## Context`, `## Decision`, `## Consequences` headings; may carry "Supersedes ADR-NNN" in its status.
- **MADR ADR**: a Markdown file with YAML frontmatter containing `title:`, `status:`, `deciders:` (and optionally `date:`), plus MADR body sections (Context and Problem Statement, Decision Drivers, Considered Options, Decision Outcome, Consequences).
- **Plain Markdown ADR**: an H1-titled document matching neither Nygard nor MADR; its body maps verbatim to `## Context` with other sections as placeholders.
- **maxi ADR**: the output format written to `docs/maxi/adr/NNNN-slug.md` with maxi frontmatter (`status`, `created`, `updated`, `source`/`decider`, `related_specs`, `related_principles`, `related_requirements`, `supersedes`, `superseded_by`) and sections `## Context`, `## Decision Drivers`, `## Considered Options`, `## Decision`, `## Consequences`, `## Confirmation`.
- **Proposal**: an in-flight object (`source`, `domain_label`, `title`, `body`, plus importer-only `format`/`source_path`) returned by a subagent and consumed by dedup, summary, and consent steps.
- **`.rejected` log**: `docs/maxi/adr/.rejected`, a bookkeeping file of skipped discovered domain labels (one per line, `#`-comment header) feeding the exclusion context on re-run; not an ADR and exempt from the consent gate.
- **README index**: `docs/maxi/adr/README.md`, a regenerated table (ADR number, title, status, created, related specs).

## Success Criteria

### Measurable Outcomes

- **SC-001**: Running the skill against a project with existing ADR files produces one maxi-format draft per detected ADR (excluding blocklisted filenames and unsupported formats), each traceable to its source file via `source:` frontmatter.
- **SC-002**: No ADR file is ever written without the user issuing an explicit verb (`accept`/`deprecate`/`edit`) for that specific proposal; skips and ambiguous-twice responses write nothing.
- **SC-003**: ADR numbers in `docs/maxi/adr/` are sequential and gap-free relative to the prior max, regardless of how many proposals were skipped.
- **SC-004**: After a run, `docs/maxi/adr/README.md` reflects exactly the ADRs present (regenerated once), and originals on disk are byte-identical to before the run.
- **SC-005**: A second run after skipping discovered proposals does not re-propose the same discovered domains (they are recorded in `.rejected`).
- **SC-006**: With `--import-only`, no discovered proposals are generated and the Discoverer subagent is never dispatched.

## Assumptions

- A maxi project layout is in use, so `docs/maxi/` is the canonical location for the constitution and ADR log.
- The orchestrator runs in an environment where two subagents can be dispatched in parallel (`maxi:dispatching-parallel-agents`) and `git log` is available for the discovery layer.
- Format detection (Nygard/MADR/plain) plus the filename blocklist is a sufficient filter for identifying ADR files; no subjective "does this H1 look like a decision" heuristic is used.
- The token-set exclusion matcher intentionally biases toward keeping/flagging over excluding, to avoid silently dropping legitimate decisions on generic residue tokens.
- The user is the final filter on significance via the consent gate; the Discoverer's significance rubric is a pre-filter, not the only one.

## Migration Notes

- Reverse-engineered from commit `7f945f8a8548bf1b4b123d28cc097e2cca897c68`.
- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).
- Verified against code by an adversarial pass before acceptance.
