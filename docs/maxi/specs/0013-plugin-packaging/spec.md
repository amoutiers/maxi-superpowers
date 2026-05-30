---
slug: 0013-plugin-packaging
created: 2026-05-30
updated: 2026-05-30
status: done
origin: reverse-engineered
source_sha: 7f945f8a8548bf1b4b123d28cc097e2cca897c68
parked_from: null
---

# Feature Specification: Plugin Packaging & Marketplace Declaration

maxi ships as an installable Claude Code plugin. Two JSON manifests under `.claude-plugin/` make this possible: `plugin.json` declares the plugin's identity (name, version, description, author, license, keywords, repository/homepage) so Claude Code can register and version it; `marketplace.json` declares a single-plugin marketplace whose entry points at a GitHub source pinned to a specific release commit, so installers fetch a reproducible, immutable snapshot of the plugin rather than a moving branch tip. The two files are coupled to the release process: `plugin.json.version` and `marketplace.json.plugins[0].source.commit` are advanced together at release time (here both reflect the `v1.2.0` release commit).

## User Scenarios & Testing

### User Story 1 - Install maxi from its marketplace (Priority: P1)

A Claude Code user adds the maxi marketplace and installs the maxi plugin.

**Why this priority**: Installation is the plugin's entire reason to exist; without a valid marketplace entry pointing at a resolvable source, the plugin cannot be distributed.

**Independent Test**: Read `marketplace.json`; confirm `plugins[0].source` resolves to `github` repo `amoutiers/maxi-superpowers` at a real commit, and that the named plugin (`maxi`) matches `plugin.json.name`.

**Acceptance Scenarios**:
1. **Given** the marketplace manifest, **When** an installer reads `plugins[0].source`, **Then** it gets `{ source: "github", repo: "amoutiers/maxi-superpowers", commit: "f0ca9e31b49dadf552ffc6319e7f40cc37b90e42" }` — a fully-qualified, immutable GitHub reference.
2. **Given** the installed plugin, **When** Claude Code reads `plugin.json`, **Then** it registers a plugin named `maxi` at version `1.2.0` with an MIT license.
3. **Given** both manifests, **When** their plugin names are compared, **Then** `marketplace.json.plugins[0].name` (`maxi`) equals `plugin.json.name` (`maxi`).

### User Story 2 - Reproducible, version-pinned distribution (Priority: P1)

A release advances the plugin version and re-pins the marketplace source so every install of a given version is byte-identical.

**Why this priority**: Without pinning to an exact commit, installs would drift with the default branch, breaking reproducibility and the release contract.

**Independent Test**: Resolve `marketplace.json.plugins[0].source.commit` in git; confirm it is the release commit whose subject corresponds to the version declared in `plugin.json` (`chore(release): v1.2.0`).

**Acceptance Scenarios**:
1. **Given** `plugin.json.version` is `1.2.0`, **When** the pinned commit `f0ca9e3` is resolved, **Then** its commit subject is `chore(release): v1.2.0` — version and pin agree.
2. **Given** the marketplace source, **When** an installer fetches it, **Then** it fetches an exact commit (not a branch or tag ref), guaranteeing an immutable snapshot.

### User Story 3 - Discoverable plugin metadata (Priority: P2)

A user browsing the marketplace sees enough metadata to evaluate the plugin.

**Why this priority**: Discovery/categorization is valuable but secondary to install + reproducibility.

**Independent Test**: Read both manifests; confirm description, author, homepage, category, and keywords are present.

**Acceptance Scenarios**:
1. **Given** `plugin.json`, **When** read, **Then** it exposes a description, `author.name`, `homepage`, `repository`, and a `keywords` array.
2. **Given** `marketplace.json`, **When** read, **Then** the plugin entry exposes `category` (`productivity`), `description`, `author.name`, and `homepage`.
3. **Given** `marketplace.json`, **When** read, **Then** it declares an `owner` with `name` and `email`.

### Edge Cases

- The marketplace `source` pins a `commit` rather than a tag or branch; if a release fails to re-pin this commit, installers continue to receive the previous version even though `plugin.json.version` may have changed — version and pin can silently diverge.
- `plugin.json` declares NO `hooks` key; hook wiring is not part of the plugin manifest and is sourced elsewhere (`hooks/hooks.json`), so the manifest alone does not register hooks.
- `plugin.json` carries no `$schema`, while `marketplace.json` does; only the marketplace file is schema-validated against `https://anthropic.com/claude-code/marketplace.schema.json`.
- `plugin.json` lacks an explicit author email; `marketplace.json` carries the maintainer email in `owner` — author identity is split across the two files (`author.name` only vs. `owner.name`+`owner.email`).

## Requirements

### Functional Requirements

- **FR-001**: The plugin MUST declare a unique name `maxi` (.claude-plugin/plugin.json:2).
- **FR-002**: The plugin MUST declare a human-readable description of the spec-driven pipeline (.claude-plugin/plugin.json:3).
- **FR-003**: The plugin MUST declare a semantic `version` (`1.2.0`) (.claude-plugin/plugin.json:4).
- **FR-004**: The plugin MUST declare an `author.name` (.claude-plugin/plugin.json:5).
- **FR-005**: The plugin MUST declare a `homepage` URL (.claude-plugin/plugin.json:8).
- **FR-006**: The plugin MUST declare a `repository` URL (.claude-plugin/plugin.json:9).
- **FR-007**: The plugin MUST declare a `license` (`MIT`) (.claude-plugin/plugin.json:10).
- **FR-008**: The plugin MUST declare a `keywords` array for discovery (.claude-plugin/plugin.json:11).
- **FR-009**: The marketplace manifest MUST declare a `$schema` pointing at the Claude Code marketplace schema (.claude-plugin/marketplace.json:2).
- **FR-010**: The marketplace MUST declare a marketplace `name` (`maxi`) (.claude-plugin/marketplace.json:3).
- **FR-011**: The marketplace MUST declare an `owner` with `name` and `email` (.claude-plugin/marketplace.json:5).
- **FR-012**: The marketplace MUST list one or more `plugins` (.claude-plugin/marketplace.json:9).
- **FR-013**: The marketplace plugin entry MUST carry a `name` matching the plugin manifest (`maxi`) (.claude-plugin/marketplace.json:11).
- **FR-014**: The marketplace plugin entry MUST declare a `category` (`productivity`) (.claude-plugin/marketplace.json:16).
- **FR-015**: The marketplace plugin entry MUST declare a `source` of type `github` (.claude-plugin/marketplace.json:17).
- **FR-016**: The marketplace `source` MUST name the GitHub `repo` (`amoutiers/maxi-superpowers`) (.claude-plugin/marketplace.json:19).
- **FR-017**: The marketplace `source` MUST pin an exact `commit` SHA for reproducible installs (.claude-plugin/marketplace.json:20).
- **FR-018**: The marketplace plugin entry MUST declare a `homepage` URL (.claude-plugin/marketplace.json:22).

### Key Entities

- **plugin.json**: The plugin manifest. Fields: `name`, `description`, `version`, `author.name`, `homepage`, `repository`, `license`, `keywords[]`.
- **marketplace.json**: The single-plugin marketplace manifest. Fields: `$schema`, `name`, `description`, `owner.{name,email}`, `plugins[]`.
- **plugins[0]** (marketplace entry): `name`, `description`, `author.name`, `category`, `source`, `homepage`.
- **source** (marketplace entry): `source` (`github`), `repo`, `commit` — the pinned, immutable install reference.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Both manifests parse as valid JSON.
- **SC-002**: `marketplace.json.plugins[0].name` equals `plugin.json.name` (both `maxi`) — exactly one consistent plugin identity.
- **SC-003**: `marketplace.json.plugins[0].source.commit` resolves to a real commit in the repository whose subject matches the `plugin.json.version` release (`v1.2.0`).
- **SC-004**: `marketplace.json` validates against its declared `$schema`.
- **SC-005**: Every required field for install (plugin `name`, `version`; marketplace `source.repo` + `source.commit`) is present and non-empty.

## Assumptions

- Hook registration is intentionally out of scope for `plugin.json`; hooks are wired via `hooks/hooks.json` (a separate boundary), so this manifest declaring no `hooks` key is by design.
- The marketplace `source.commit` is expected to be re-pinned by the release process on every version bump; the present value (`f0ca9e3`) corresponds to the `v1.2.0` release commit and is assumed to be the intended pin for the declared version.
- A single-plugin marketplace (one entry in `plugins[]`) is intentional — this repository publishes only the `maxi` plugin.
- The `$schema` URL on `marketplace.json` is the authoritative validation contract for the marketplace file shape.

## Migration Notes

- Reverse-engineered from commit `7f945f8a8548bf1b4b123d28cc097e2cca897c68`.
- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).
- Verified against code by an adversarial pass before acceptance.
