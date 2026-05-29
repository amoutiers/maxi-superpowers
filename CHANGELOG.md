
## [1.1.0] - 2026-05-29

### Features

- Add maxi:migrate-adr — import and discover ADRs
- Rejection log for skipped discoveries (FR-011,012,014)
- Subagent return contract + constitution-informed discovery (FR-015,016)
- Shared significance rubric (FR-017,018)
- Guard against recording decisions as principles

### Bug Fixes

- Clarify no-writes deprecated, fix git log, add placeholder text, matching rule, diagram
- Explicit consent verbs, skip never writes (FR-001..005)
- Set-based exclusion matching, flag don't drop (FR-006..008,013)
- Importer blocklist + source provenance (FR-009,010)
- Polish git flag, honest table, single README regen (FR-019..021)
- Clear stale per-write README regen refs (code review)

### Documentation

- Bump maxi skill count to 16, add migrate-adr to overview
- Add /maxi:migrate-adr to command list and getting started
- Spec+plan+tasks+analysis for migrate-adr review fixes
- Authoring flow brainstorm->spec->plan->writing-skills (FR-022)
- Decouple from CLAUDE.md, v1.2.0 + amendment ADR (FR-024,025)

### Testing

- Add fast-tier check skeleton for spec 0002
- Preservation assertions + full-suite verification (FR-023, SCs)

### Internal

- Mark spec done — migrate-adr review fixes complete
- Co-locate templates with skills + uniformize to maxi format
- Add doc-consistency skill + fix documentation drift

## [maxi--v1.0.0] - 2026-05-28

### Internal

- Pin marketplace.json to v1.0.0 release commit

# Changelog

All notable changes to this project will be documented in this file.

<!-- Entries above this line are prepended automatically by the release GitHub Action -->

## [1.0.0] - 2026-05-28

### Features

- Add artifact templates (adapted from spec-kit, maxi/ paths)
- Add test infrastructure (frontmatter lint, sync invariant, spec fixture)
- Add plugin manifest, hooks, and using-maxi bootstrap skill
- Add constitution skill (RED-GREEN phase)
- Add specify skill (RED-GREEN-REFACTOR)
- Add clarify skill (RED-GREEN-REFACTOR)
- Add plan skill (RED-GREEN-REFACTOR)
- Add tasks skill (RED-GREEN-REFACTOR)
- Add analyze skill — 6-pass cross-artifact audit (RED-GREEN-REFACTOR)
- Add implement skill (RED-GREEN-REFACTOR)
- Add ADR template (NNN-slug, custom maxi format)
- Add adr skill (internal, system-driven, user-consented)
- Add migrate-from-speckit skill
- Add /maxi:board kanban skill
- Enforce strict phase gating — no phase skips
- Use 4-digit zero-padded numbering (NNNN- / 0001-)
- Lifecycle skills (cancel/park/resume/revise) + parked/cancelled statuses
- Gate session-start injection on docs/maxi/ presence
- Add Antigravity CLI compatibility manifests, tests, and docs
- Add OpenCode plugin support
- Add marketplace.json for claude plugin install

### Bug Fixes

- Improve sync and bump scripts (misleading comment, zero-sync warning, VENDORED.md guard)
- Correct path references and command names in templates
- Address code review findings on ADR feature
- Guard against empty skill name in sync-superpowers.sh
- Align skill name in frontmatter (maxi-adr → adr)
- Strict-pipeline table, board doc count, full-dir sync invariant
- Stop-word example consistency (F10) + slug collision detection (F7)
- Reason string overwrote tasks.md with plan.md when both present
- Add required owner field to marketplace.json
- Use github source type in marketplace.json

### Documentation

- Add README, architecture, and delegation map
- Document migrate-from-speckit command
- Replace vague Phase Gating bullets with precise table
- Formalize updated: bump invariant, fix clarify step order
- Add Mermaid flow diagram and strict-pipeline rationale
- Update pipeline-flow + delegation-map for new lifecycle skills + mandatory sync rule
- Harmonize /maxi:command slash prefix across all docs and skills

### Refactoring

- Close loopholes in constitution skill (REFACTOR phase)
- Rename artifact directory .maxi/ → docs/maxi/
- Review and tighten templates and skills
- Standardize placeholders, dates, and slugs (B4-B7)

### Testing

- Add ADR template and fixture validation check
- Expand test suite with structural, script, and behavioral coverage
- Register board in fast and integration test tiers

### Internal

- Vendor superpowers v5.1.0 via git subtree; sync 14 skills
- Update logo to shield and bolt crest with thermal execution color scheme
