
## [2.0.1] - 2026-06-21

### Features

- Add Codex plugin packaging

### Bug Fixes

- Split Claude and Codex session hooks


## [2.0.0] - 2026-06-21

### Bug Fixes

- Tighten using-maxi + release CSO descriptions
- Prevent superpowers tag pollution in bump + release

### Documentation

- Re-derive x-develop baseline against v6 rework
- Update vendored superpowers version citations to v6.0.3

### Refactoring

- Align patch layer with superpowers v6 SDD
- Extract reference detail to reference.md

### Testing

- Guard superpowers version citations against VENDORED.md

### Internal

- Bump superpowers to v6.0.3


## [1.3.0] - 2026-05-31

### Features

- Invert ADR↔spec traceability + project-wide link convention

### Bug Fixes

- Kebab-case slug validation + preserve internal spaces in exclude (#1)

### Documentation

- Maxi reverse-engineers itself — 12 as-built spec baselines
- Audit-driven doc corrections + tri-harness strategy


## [1.2.0] - 2026-05-30

### Features

- Add maxi:x-develop SDD wrapper and rename internal skills to x- prefix
- Single-responsibility principle + migrate-adr decomposition
- Add migrate-from-brownfield skill (reverse-engineer specs)

### Bug Fixes

- Exclude plugin-name tags from changelog (cliff ignore_tags)
- Update stale /maxi:adr references to /maxi:x-adr (review C1)
- Key bootstrap on project directory not process.cwd(); add ESM syntax guard (review H3, M1)

### Documentation

- Bootstrap ADR log with 5 discovered architectural decisions (ADR-0004–0008)
- Wire x-develop into pipeline diagrams and delegation tables
- Update using-maxi and CLAUDE.md for x-develop (now 18 maxi-native skills)
- Newcomer onboarding + accurate existing-project paths

### Testing

- Update check-skills-present for 18 maxi-native skills (add x-develop)
- Assert package.json version matches plugin manifest (review M4)
- Assert session-start emits valid JSON in/out of a maxi project (review M1)
- Add cross-harness bootstrap preamble parity check (review H2)

### Internal

- Mark design-review-fixes done


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

- Pin marketplace.json to v1.0.0 release commit
- Mark spec done — migrate-adr review fixes complete
- Co-locate templates with skills + uniformize to maxi format
- Add doc-consistency skill + fix documentation drift

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
- Relocate constitution to docs/constitution.md
- Add ADR template (NNN-slug, custom maxi format)
- Add adr skill (internal, system-driven, user-consented)
- Add ADR support (auto-proposed, user-consented)
- Add migrate-from-speckit skill
- Track vendored skills list to detect and remove orphans
- Add Decision Drivers section and inline pros/cons per option
- Add /maxi:board kanban skill
- Enforce strict phase gating — no phase skips
- Use 4-digit zero-padded numbering (NNNN- / 0001-)
- Relocate to docs/maxi/constitution.md
- ADRs + migration notes for skipped pipeline phases
- Lifecycle skills (cancel/park/resume/revise) + parked/cancelled statuses
- Gate session-start injection on docs/maxi/ presence
- Full spec+plan+tasks+analysis for design-review-fixes (0001)
- Add Antigravity CLI compatibility manifests, tests, and docs
- Add OpenCode plugin support
- Add marketplace.json for claude plugin install

### Bug Fixes

- Improve sync and bump scripts (misleading comment, zero-sync warning, VENDORED.md guard)
- Correct path references and command names in templates
- Address code review findings on ADR feature
- Merge two sed calls in _update-vendored-md to prevent .bak leak on failure
- Guard timeout command for macOS in integration trigger test
- Restructure template check as standalone instruction
- Guard against empty skill name in sync-superpowers.sh
- Align skill name in frontmatter (maxi-adr → adr)
- Add migrate-from-speckit to skill list, update CLAUDE.md count
- Correct spec-kit GitHub URL
- Restructure template check as standalone instruction
- Quote Windows args in run-hook.cmd to handle spaces
- Strict-pipeline table, board doc count, full-dir sync invariant
- Stop-word example consistency (F10) + slug collision detection (F7)
- Reason string overwrote tasks.md with plan.md when both present
- Add required owner field to marketplace.json
- Use github source type in marketplace.json

### Documentation

- Add README, architecture, and delegation map
- Add logo to README
- Document migrate-from-speckit command
- Replace vague Phase Gating bullets with precise table
- Formalize updated: bump invariant, fix clarify step order
- Add fail-fast template existence check to 5 skills
- Clarify multi-platform session-start support
- Clarify plugin name and adr initial status (C4, C5)
- Add Mermaid flow diagram and strict-pipeline rationale
- Update pipeline-flow + delegation-map for new lifecycle skills + mandatory sync rule
- Horizontal layout (flowchart LR)
- Right-to-left layout (flowchart RL)
- Move vendored subgraph to bottom via invisible links
- Revert to top-down (TD) layout
- Lifecycle and vendored side by side at bottom (nested LR subgraph)
- Pipeline+lifecycle side by side (top), vendored below (bottom)
- Lifecycle left, pipeline right
- Harmonize /maxi:command slash prefix across all docs and skills

### Refactoring

- Close loopholes in constitution skill (REFACTOR phase)
- Rename artifact directory .maxi/ → docs/maxi/
- Fix helpers — self-init failures, add assert_files_equal, OK output on assert_grep
- Use assert_files_equal in check-sync-invariant
- Simplify check-sync-script — drop git commit, use assert_files_equal
- Simplify check-bump-script — drop git commits, use assert_grep
- Convert VALID_STATUSES to bash array in check-spec-fixture
- Review and tighten templates and skills
- Standardize placeholders, dates, and slugs (B4-B7)

### Testing

- Add ADR template and fixture validation check
- Expand test suite with structural, script, and behavioral coverage
- Register board in fast and integration test tiers

### Internal

- Initial scaffold (empty plugin skeleton)
- Squash 'vendor/superpowers/' content from commit f2cbfbe
- Merge subtree '8c06ad08e1855e19eb26f34d3bd298f730572dc9' as 'vendor/superpowers'
- Vendor superpowers v5.1.0 via git subtree; sync 14 skills
- Ignore vendor/superpowers/.synced-skills
- Remove stale spec-kit-0.8.7 entry
- Update logo to shield and bolt crest with thermal execution color scheme
- Exclude docs/superpowers/ from tracking

