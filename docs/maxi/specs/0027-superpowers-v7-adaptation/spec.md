---
slug: 0027-superpowers-v7-adaptation
created: 2026-10-17
updated: 2026-10-17
status: done
design_cycle: 0
parked_from: null
related_adrs: [0005-superpowers-vendoring-git-subtree, 0032-align-superpowers-v7-model]
---

# Feature Specification: Superpowers v7 Adaptation

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Use the new design conversation within Maxi (Priority: P1)

As a Maxi user, I want v7's intent-driven conversation and builder check while retaining one canonical specification and the existing product pipeline.

**Why this priority**: Brainstorming is the substantial behavior change in v7 and enters through the specification coordinator.

**Independent Test**: Run installed specification cases for a complete request, unresolved intent and an interview opt-out; inspect canonical artifacts, builder dispatch and phase boundaries.

**Acceptance Scenarios**:

1. **Given** a complete approved request, **When** specification runs, **Then** settled choices are reused, the canonical specification is authored, the actual clarification scan runs, and the requested destination is respected.
2. **Given** an unresolved product need, **When** brainstorming runs, **Then** it elicits intent and significant implementation choices, distinguishes assumptions from user decisions, and returns through the specification owner.
3. **Given** an interview opt-out or a small request, **When** Maxi handles it, **Then** mandatory artifacts, statuses and approval gates remain applicable.
4. **Given** a newly created canonical specification, **When** the builder check runs, **Then** a fresh independent reader uses the bundled upstream prompt, returns material planning questions once, and corrections pass through the author before clarification.
5. **Given** a draft-only request, **When** the author returns, **Then** no interview, builder check or successor phase runs.

### User Story 2 - Load the plugin correctly on supported hosts (Priority: P1)

As a plugin user, I want Antigravity to recognize a native Maxi package and Hermes and hook-based hosts to discover installed skills reliably.

**Why this priority**: The audit reproduced rejected packaging, empty descriptions and missing bootstrap content with an empty PATH.

**Independent Test**: Validate the native Antigravity manifest, exercise Hermes registration in both layouts, and execute root hooks with empty PATH and normal host environments.

**Acceptance Scenarios**:

1. **Given** a native Antigravity install, **When** skills are discovered, **Then** a recognized manifest, consistent version metadata and an explicit project-aware route load Maxi's session instructions.
2. **Given** a Maxi project and empty PATH, **When** Bash invokes the hook or wrapper, **Then** valid host-specific JSON includes the complete installed session skill.
3. **Given** Windows Bash discovery, **When** the wrapper chooses Bash, **Then** current-directory executables and WSL launchers are excluded and the hook exit status propagates.
4. **Given** either Hermes layout, **When** the adapter registers skills, **Then** all 34 skills have their actual nonempty descriptions and the first-turn project gate remains effective.

### User Story 3 - Upgrade and resume with verifiable evidence (Priority: P2)

As a maintainer, I want an exact import and installed-agent qualification that preserve completion, pause/resume and terminal evidence.

**Why this priority**: Source comparison cannot demonstrate installed design and execution behavior.

**Independent Test**: Run the fast tier, installed initial/revision design and brainstorming cases, and existing two-task pause/resume and completed-v1 continuation qualification.

**Acceptance Scenarios**:

1. **Given** the official v7.0.0 tag, **When** the existing bump/sync workflow imports it, **Then** skills remain byte-identical and the inventory remains 15 upstream and 19 Maxi-native skills.
2. **Given** paused two-task execution, **When** it resumes, **Then** completed work is not replayed and the existing SDD contract obtains fresh final evidence.
3. **Given** completed historical v1 work, **When** it continues, **Then** existing empty-v2 and fresh final-review requirements remain enforced.
4. **Given** unavailable native evidence, **When** qualification is reported, **Then** deterministic checks, validators and actual agent behavior remain separate claims.

### Edge Cases

- Approved choices must not trigger a second interview or imply approval for unrelated changes.
- Builder questions already answered by request or repository use that evidence; routine decisions are marked as agent choices; material user choices remain explicit.
- The builder check cannot write duplicate designs, invoke planning, or substitute for the existing spec/plan review.
- A missing bundled prompt/helper stops its handoff without a co-installed engine or client-repository fallback.
- Empty PATH cannot produce JSON containing an error message in place of the actual session skill.
- A successful validator must not fail solely because its human-readable success marker changed.
- Tracked SDD ignore files and platform-specific physical paths retain imported upstream behavior.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Import exact Superpowers v7.0.0 through the existing subtree bump/sync scripts; preserve byte-identical vendoring.
- **FR-002**: Preserve 19 native skills, 15 upstream skills, ten FSM states, three fixed product review boundaries, artifact ownership and the SDD completion contract.
- **FR-003**: Bind brainstorming, its builder prompt and delegated engines to the owning installed snapshot, preserving canonical paths, settled answers and owner-only returns.
- **FR-004**: Adapt all delegated brainstorming exits so request size, interview opt-out and prototypes do not bypass forward-development gates or requested destinations.
- **FR-005**: Run the upstream builder check once for non-draft specification creation, on its authored canonical specification before clarification; route findings through the author. Draft-only creation and existing-spec revision retain their existing owner boundaries.
- **FR-006**: Preserve bounded independent review of the exact specification/plan; the builder check prepares ambiguity resolution and grants no approval or successor authorization.
- **FR-007**: Add native Antigravity packaging and project-aware discovery bootstrap; update installation guidance, structural checks and all affected release inventories.
- **FR-008**: Port upstream robustness fixes into root hooks, retaining Maxi's project gate, bootstrap parity and host JSON formats.
- **FR-009**: Register actual frontmatter descriptions for every Hermes skill and test both layouts without a new parsing dependency.
- **FR-010**: Extend existing deterministic and installed coverage for v7 intake, builder identity and prompt provenance, opt-out, packaging, hook failures and descriptions.
- **FR-011**: Execute installed initial/revision design, two-task pause/resume and completed-v1 continuation against a byte-checked candidate.
- **FR-012**: Update the Mandatory Sync five, current version references and affected release skills in the same coherent commits as their owning changes; preserve historical artifacts.
- **FR-013**: Record source identities, exact commands, results and evidence paths in an English qualification report with explicit native limits.
- **FR-014**: Preserve unrelated checkouts, user configuration and existing evidence; publication and branch integration require their own explicit authorization.

### Key Entities

- **Installed snapshot**: A registered, byte-checked copy supplying one owner's skills, prompts and helpers.
- **Canonical specification**: The artifact owned first by the author and then by clarification.
- **Builder result**: One independent upstream-prompt response listing unresolved material planning questions, without design approval.
- **Qualification evidence**: Retained checks, validator and installed-agent results bound to tested source and installation.

## Clarifications

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All fast checks pass with the v7 pin and strict sync invariant intact.
- **SC-002**: Every installed intake case produces only allowed canonical artifacts at its requested destination; the builder case proves one independent check with bundled prompt and actual document reads.
- **SC-003**: Empty-PATH probes load complete instructions, all Hermes descriptions match, and native Antigravity validation passes.
- **SC-004**: Installed evidence demonstrates pending-only resume, historical continuation and valid fresh receipts with ten unchanged FSM states.
- **SC-005**: The report separates actual behavior, structural checks and unresolved acceptance, with reproducible commands and retained paths.

## Assumptions

- The approved audit fixes v7.0.0 at upstream commit bb92a77741419a4ab5f06e711a283343f1ada0c3.
- Existing Bash, Python, JavaScript and Codex tooling is reused without new runtime dependencies.
- New artifacts and changed technical documentation are English.
- Existing [vendoring](../../adr/0005-superpowers-vendoring-git-subtree.md) and [execution/harness ownership](../../adr/0031-align-superpowers-v6-4-model.md) decisions govern until an explicitly approved successor records this adaptation.
