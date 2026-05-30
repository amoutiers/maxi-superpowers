---
slug: 0017-migrate-from-speckit
created: 2026-05-30
updated: 2026-05-30
status: done
origin: reverse-engineered
source_sha: 7f945f8a8548bf1b4b123d28cc097e2cca897c68
parked_from: null
---

# Feature Specification: Migrate from github-spec-kit to maxi

A one-shot, non-destructive migration utility that converts an existing github-spec-kit project into maxi conventions. It detects a `.specify/` directory and `specs/NNN-*` folders, previews exactly what would change (constitution path, every spec's source→target, inferred maxi status with reason, aux files present), waits for explicit user confirmation, then copies specs into `docs/maxi/specs/`, copies the constitution to `docs/maxi/constitution.md`, prepends YAML frontmatter, infers each spec's maxi pipeline status from the files present, and appends Migration Notes to any spec that skipped pipeline phases. Originals in `specs/` and `.specify/` are never modified.

## User Scenarios & Testing

### User Story 1 - Preview the migration plan before committing (Priority: P1)

A user with a spec-kit project wants to see exactly what the migration will do before any files are written, so they can verify the inferred statuses and target paths.

**Why this priority**: The preview is the default mode and the safety contract of the whole utility — no file is ever written without the user first seeing the plan. Without it, migration is opaque and unsafe.

**Independent Test**: Run `migrate.sh --preview` (or with no args) in a spec-kit project; confirm it prints the constitution mapping, a per-spec source→target line with inferred `status=` and reason, and exits 0 having written nothing.

**Acceptance Scenarios**:

1. **Given** a project with `.specify/` and one or more `specs/NNN-*` directories, **When** the user runs the skill, **Then** the workflow runs `migrate.sh --preview` and prints a manifest: constitution path with `[COPY]`/`[SKIP ...]` action, each spec's `specs/<slug> → docs/maxi/specs/<slug>` line with `status=<inferred>` and a human-readable reason, and the aux-files-preserved notice.
2. **Given** preview mode is active (`MODE=preview`), **When** the manifest finishes printing, **Then** the script exits 0 before reaching any apply logic, writing no files.
3. **Given** a spec folder whose status field reads `Shipped` or `Implemented`, or that contains `retrospective.md`, **When** the preview computes status, **Then** the inferred maxi status is `done`; a `tasks.md` yields `tasked`; a `plan.md` yields `planned`; otherwise `specified`.

### User Story 2 - Confirm, then apply the migration non-destructively (Priority: P1)

After reviewing the preview, the user approves the migration; the utility copies everything into `docs/maxi/` and rewrites frontmatter without touching the originals.

**Why this priority**: This is the core value — actually performing the conversion. It must be gated on explicit consent and must preserve originals so the migration is reversible by deletion.

**Independent Test**: In a spec-kit project, run the skill, answer `y` at the confirmation prompt (or run `migrate.sh --apply --yes`), and confirm `docs/maxi/specs/<slug>/spec.md` exists with YAML frontmatter while `specs/<slug>/spec.md` is byte-unchanged.

**Acceptance Scenarios**:

1. **Given** the preview has been shown, **When** the skill asks "Proceed with migration? (y/N)" and the user answers `y` or `yes`, **Then** it runs `migrate.sh --apply`; any other response aborts with no writes.
2. **Given** `--apply` proceeds, **When** the script processes each spec, **Then** it copies the directory verbatim with `cp -r specs/<slug> docs/maxi/specs/<slug>` (never `git mv`), leaving `specs/` and `.specify/` originals intact.
3. **Given** a copied `spec.md`, **When** frontmatter is written, **Then** the script prepends a `---` block with `slug`, `created`, `updated`, `status`, and strips inline `**Feature Branch**:`, `**Status**:`, `**Created**:`, and `**Input**:` header lines.
4. **Given** the source constitution `.specify/memory/constitution.md` exists and `docs/maxi/constitution.md` does not, **When** apply runs, **Then** the constitution is copied; if the target already exists or the source is missing, it is skipped.
5. **Given** a spec inferred at status `planned`, `tasked`, or `done`, **When** apply rewrites its `spec.md`, **Then** a `## Migration Notes` section is appended listing the maxi pipeline phases not run (trusted from spec-kit history); specs at `specified` get no such section.
6. **Given** a copied `plan.md` or `tasks.md` lacking frontmatter, **When** apply runs, **Then** it prepends the appropriate YAML block (tasks.md includes a `description` derived from the spec's H1 feature name); files already starting with `---` are left as-is.

### Edge Cases

- **Not a spec-kit project**: If `.specify/` is missing, or no `specs/NNN-*` directory exists, the skill stops immediately with "Not a spec-kit project: `.specify/` or `specs/NNN-*` not found. Nothing to migrate." and `migrate.sh` dies before doing any work.
- **Target already populated (clobber guard)**: In apply mode, if `docs/maxi/specs/` exists and is non-empty, the script dies with an abort message and writes nothing, so an existing maxi project is never overwritten.
- **User declines at confirmation**: If the user answers anything other than `y`/`yes` to the prompt, the script prints "Aborted." and exits 0 with no files written.
- **Spec folder missing spec.md**: The folder is recorded as skipped, reported in the preview and the final summary, and processing continues (it does not abort the run).
- **Spec.md with no Created field**: The `created` date falls back to today's date.

## Requirements

### Functional Requirements

- **FR-001**: System MUST require a `.specify/` directory at the project root and at least one `specs/NNN-*` directory before doing anything, stopping otherwise. (skills/migrate-from-speckit/SKILL.md:24, skills/migrate-from-speckit/migrate.sh:35, skills/migrate-from-speckit/migrate.sh:38)
- **FR-002**: System MUST default to preview mode, supporting `--preview`, `--apply`, and `--yes` arguments and dying on any unknown argument. (skills/migrate-from-speckit/migrate.sh:20, skills/migrate-from-speckit/migrate.sh:23)
- **FR-003**: System MUST, in apply mode, abort if `docs/maxi/specs/` already exists and is non-empty, to avoid overwriting an existing maxi project. (skills/migrate-from-speckit/migrate.sh:45, skills/migrate-from-speckit/SKILL.md:71)
- **FR-004**: System MUST infer each spec's maxi status as `done` when the spec-kit status is `Shipped`/`Implemented` or `retrospective.md` is present, else `tasked` when `tasks.md` is present, else `planned` when `plan.md` is present, else `specified`. (skills/migrate-from-speckit/migrate.sh:97, skills/migrate-from-speckit/migrate.sh:99, skills/migrate-from-speckit/migrate.sh:101, skills/migrate-from-speckit/migrate.sh:104)
- **FR-005**: System MUST print a preview manifest showing the constitution source→target with its action, each spec's source→target with inferred status and reason, and any skipped folders, then exit 0 in preview mode without writing files. (skills/migrate-from-speckit/migrate.sh:140, skills/migrate-from-speckit/migrate.sh:147, skills/migrate-from-speckit/migrate.sh:164)
- **FR-006**: System MUST, in apply mode without `--yes`, prompt "Proceed with migration? [y/N]" and abort unless the reply matches `y`/`yes`. (skills/migrate-from-speckit/migrate.sh:169, skills/migrate-from-speckit/migrate.sh:171)
- **FR-007**: System MUST copy the constitution from `.specify/memory/constitution.md` to `docs/maxi/constitution.md` only when the source exists and the target does not. (skills/migrate-from-speckit/migrate.sh:54, skills/migrate-from-speckit/migrate.sh:56, skills/migrate-from-speckit/migrate.sh:177)
- **FR-008**: System MUST copy each spec directory verbatim with `cp -r` into `docs/maxi/specs/`, preserving aux files (`contracts/`, `data-model.md`, `quickstart.md`, `research.md`, `retrospective.md`) and never modifying the originals. (skills/migrate-from-speckit/migrate.sh:194, skills/migrate-from-speckit/migrate.sh:123, skills/migrate-from-speckit/SKILL.md:11)
- **FR-009**: System MUST rewrite each copied `spec.md` to prepend YAML frontmatter (`slug`, `created`, `updated`, `status`) and strip the inline spec-kit header lines `**Feature Branch**:`, `**Status**:`, `**Created**:`, `**Input**:`. (skills/migrate-from-speckit/migrate.sh:205, skills/migrate-from-speckit/migrate.sh:208)
- **FR-010**: System MUST append a `## Migration Notes` section to any spec.md whose inferred status is `planned`, `tasked`, or `done`, listing the maxi pipeline phases not run; specs at `specified` get no such section. (skills/migrate-from-speckit/migrate.sh:213, skills/migrate-from-speckit/migrate.sh:230)
- **FR-011**: System MUST prepend YAML frontmatter to a copied `plan.md` only if present and not already starting with `---`. (skills/migrate-from-speckit/migrate.sh:237)
- **FR-012**: System MUST prepend YAML frontmatter (including a `description` derived from the spec's H1 feature name) to a copied `tasks.md` only if present and not already starting with `---`. (skills/migrate-from-speckit/migrate.sh:201, skills/migrate-from-speckit/migrate.sh:248, skills/migrate-from-speckit/migrate.sh:251)
- **FR-013**: System MUST skip (and report as skipped) any `specs/NNN-*` folder lacking a `spec.md`, without aborting the run. (skills/migrate-from-speckit/migrate.sh:78, skills/migrate-from-speckit/migrate.sh:154)
- **FR-014**: System MUST default a spec's `created` date to today when no `**Created**:` field is found in the source spec.md. (skills/migrate-from-speckit/migrate.sh:84, skills/migrate-from-speckit/migrate.sh:86)
- **FR-015**: System MUST print a final summary after apply tallying migrated specs by status and listing skipped folders and whether the constitution was copied. (skills/migrate-from-speckit/migrate.sh:268, skills/migrate-from-speckit/migrate.sh:271)
- **FR-016**: The skill MUST delegate ALL file operations to `migrate.sh` and never re-implement migration logic via manual bash loops or Edit/Read/Write sequences. (skills/migrate-from-speckit/SKILL.md:13, skills/migrate-from-speckit/SKILL.md:15, skills/migrate-from-speckit/SKILL.md:125)
- **FR-017**: System MUST direct the user, after a successful apply, to run `/maxi:migrate-adr` to bootstrap their ADR log (spec-kit migration brings no ADRs) and then `/maxi:specify` for new features. (skills/migrate-from-speckit/SKILL.md:105, skills/migrate-from-speckit/migrate.sh:281)

### Key Entities

- **`.specify/memory/constitution.md` → `docs/maxi/constitution.md`**: The project constitution, copied only when the target does not already exist.
- **`specs/NNN-slug/` → `docs/maxi/specs/NNN-slug/`**: Each spec directory, copied verbatim including aux files; its `spec.md`, `plan.md`, and `tasks.md` gain maxi YAML frontmatter.
- **`spec.md`**: Gains frontmatter (`slug`, `created`, `updated`, `status`) with spec-kit inline header lines stripped; may gain a `## Migration Notes` section.
- **Inferred status**: A maxi pipeline status (`done`/`tasked`/`planned`/`specified`) derived from spec-kit status field and presence of `retrospective.md`/`tasks.md`/`plan.md`.
- **Untouched originals**: `.specify/`, `specs/`, and `.claude/skills/speckit-*` are never modified.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Running the utility on a spec-kit project with no prior maxi artifacts produces `docs/maxi/specs/<slug>/spec.md` for every source spec that has a `spec.md`, each with valid maxi frontmatter and an inferred `status`.
- **SC-002**: After migration, every original file under `specs/` and `.specify/` is byte-for-byte unchanged.
- **SC-003**: No file is written in preview mode, and no file is written in apply mode unless the user explicitly confirmed with `y`/`yes` (or `--yes` was passed).
- **SC-004**: Running apply against a project that already has a non-empty `docs/maxi/specs/` aborts without writing any file.
- **SC-005**: Every spec inferred at `planned`/`tasked`/`done` carries a `## Migration Notes` section documenting which pipeline phases were trusted from spec-kit history; specs at `specified` carry none.
- **SC-006**: The final summary's per-status tally plus skipped count equals the number of `specs/NNN-*` directories present.

## Assumptions

- The script is run from the project root (the directory containing `.specify/` and `specs/`).
- Spec-kit spec directories follow the `specs/NNN-slug/` naming convention with a three-digit numeric prefix.
- The spec-kit `spec.md` uses inline header lines of the form `**Created**:`, `**Status**:`, `**Feature Branch**:`, `**Input**:` and a top-level `# ` H1 for the feature name.
- A spec-kit status of `Shipped` or `Implemented`, or the presence of `retrospective.md`, reliably indicates a completed (`done`) feature.
- ADRs are out of scope for this migration and are handled separately by `/maxi:migrate-adr`.

## Migration Notes

- Reverse-engineered from commit `7f945f8a8548bf1b4b123d28cc097e2cca897c68`.
- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).
- Verified against code by an adversarial pass before acceptance.
