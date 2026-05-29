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
