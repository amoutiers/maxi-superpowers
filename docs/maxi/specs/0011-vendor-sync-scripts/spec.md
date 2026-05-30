---
slug: 0011-vendor-sync-scripts
created: 2026-05-30
updated: 2026-05-30
status: done
origin: reverse-engineered
source_sha: 7f945f8a8548bf1b4b123d28cc097e2cca897c68
parked_from: null
---

# Feature Specification: Vendor Sync & Bump Tooling

Three bash scripts under `scripts/` form the maintenance entrypoint for the vendored superpowers dependency. They (1) copy vendored skills from `vendor/superpowers/skills/` into the published `skills/` directory without disturbing maxi-native skills, (2) bump the vendored dependency to a named upstream git tag via git-subtree and re-sync, and (3) rewrite the `VENDORED.md` provenance metadata (pinned version and sync date). The scripts are layered: `bump-superpowers.sh` orchestrates `sync-superpowers.sh` and `_update-vendored-md.sh`.

## User Scenarios & Testing

### User Story 1 - Re-sync vendored skills into the published tree (Priority: P1)

A maintainer who has already vendored superpowers (via `git subtree add`) wants the contents of `vendor/superpowers/skills/` reflected in the top-level `skills/` directory, overwriting only the vendored skills and leaving maxi-native skills intact.

**Why this priority**: This is the core copy operation every bump depends on; bump invokes it. Without it the published `skills/` tree drifts from the vendored source. The sync-invariant test (`check-sync-invariant.sh`) asserts byte-identity, so this script is the mechanism that keeps that invariant true.

**Independent Test**: Run `bash scripts/sync-superpowers.sh` with `vendor/superpowers/skills/` populated and a maxi-native skill present in `skills/`. Verify each vendored skill dir is copied into `skills/` and the maxi-native skill is untouched.

**Acceptance Scenarios**:
1. **Given** `vendor/superpowers/skills/` exists and contains N skill directories, **When** the script runs, **Then** each is removed from `skills/` and re-copied (`rm -rf` then `cp -r`), it prints `Synced N skills from vendor/superpowers into skills/`, and exits 0.
2. **Given** a previous run recorded skills in `vendor/superpowers/.synced-skills`, **When** an entry in that list no longer exists in `vendor/superpowers/skills/` but still exists in `skills/`, **Then** the script prints `Removing orphaned vendored skill: <name>` and `rm -rf`s it from `skills/`.
3. **Given** a successful sync, **When** it completes, **Then** the set of synced skill names is written (one per line) to `vendor/superpowers/.synced-skills` for the next run's orphan detection.
4. **Given** a maxi-native skill exists in `skills/` but not in `vendor/superpowers/skills/`, **When** the script runs, **Then** that skill is neither overwritten nor removed.

### User Story 2 - Bump the vendored dependency to a new upstream tag (Priority: P2)

A maintainer wants to pull a specific upstream superpowers release tag into `vendor/superpowers/`, re-sync the skills, and update the provenance metadata in one command.

**Why this priority**: Depends on User Story 1 (it calls the sync script). Less frequent than re-sync and only needed at upstream release boundaries, but it is the documented mechanism for advancing the pinned version.

**Independent Test**: Run `bash scripts/bump-superpowers.sh v6.0.0` and verify it performs a squashed subtree pull from the upstream repo at that tag, re-syncs skills, and rewrites `VENDORED.md` with the new version and today's date.

**Acceptance Scenarios**:
1. **Given** a tag argument, **When** the script runs, **Then** it executes `git subtree pull --prefix=vendor/superpowers https://github.com/obra/superpowers.git <tag> --squash`.
2. **Given** the subtree pull succeeds, **When** the script continues, **Then** it runs `sync-superpowers.sh` from the same `scripts/` directory.
3. **Given** the sync succeeds, **When** the script continues, **Then** it runs `_update-vendored-md.sh <tag> <today's date as YYYY-MM-DD>`.
4. **Given** all steps succeed, **When** it finishes, **Then** it prints a reminder to commit `vendor/superpowers skills/ VENDORED.md` with message `chore: bump superpowers to <tag>` (it does NOT commit automatically).

### User Story 3 - Update VENDORED.md provenance metadata (Priority: P3)

A maintainer (or the bump orchestrator) wants the `VENDORED.md` `**Pinned version**` and `**Last synced**` lines rewritten to a given tag and date.

**Why this priority**: A leaf utility, normally invoked by bump but runnable standalone. Guards the documented provenance contract (`check-vendored-doc.sh`, `check-bump-script.sh`).

**Independent Test**: Run `bash scripts/_update-vendored-md.sh v6.0.0 2026-05-08` and verify the two lines in `VENDORED.md` are replaced and no `.bak` file remains.

**Acceptance Scenarios**:
1. **Given** tag and date arguments and an existing `VENDORED.md`, **When** the script runs, **Then** it `sed`-replaces the `**Pinned version**:` line to `**Pinned version**: <tag>` and the `**Last synced**:` line to `**Last synced**: <date>`.
2. **Given** macOS-style `sed -i.bak`, **When** the edit completes, **Then** the temporary `VENDORED.md.bak` is removed and it prints `Updated VENDORED.md: version=<tag> date=<date>`.

### Edge Cases
- **sync: vendor skills dir missing** — if `vendor/superpowers/skills/` does not exist, the script prints `ERROR: ... does not exist — run 'git subtree add' first` to stderr and exits 1.
- **sync: zero skills found** — if the glob matches no skill directories, it prints `WARNING: 0 skills synced — check that vendor/superpowers/skills/ is populated` to stderr and exits 1 (treated as failure).
- **sync: empty skill name** — if a basename resolves empty, it prints `ERROR: empty skill name from '<dir>'` to stderr and exits 1.
- **sync: no prior .synced-skills file** — orphan-removal loop is skipped entirely (the file-existence guard short-circuits); first run simply syncs and writes the list.
- **bump: missing tag argument** — `${1:?usage: bash scripts/bump-superpowers.sh <tag>}` aborts with the usage message before any git operation.
- **update: missing tag or date argument** — each `${N:?usage: ...}` aborts with the usage message.
- **update: VENDORED.md missing** — prints `ERROR: <path> not found` to stderr and exits 1.
- **all scripts** — run under `set -euo pipefail`, so any unexpected command failure (e.g. a failed subtree pull) aborts the script immediately.

## Requirements

### Functional Requirements

- **FR-001**: System MUST resolve the repository root via `git rev-parse --show-toplevel` and derive `vendor/superpowers`, `vendor/superpowers/skills` (source), and `skills` (destination) paths from it (scripts/sync-superpowers.sh:5).
- **FR-002**: System MUST abort with a stderr error and exit 1 if the vendored skills source directory does not exist (scripts/sync-superpowers.sh:10).
- **FR-003**: System MUST detect and remove orphaned vendored skills by reading `vendor/superpowers/.synced-skills`, removing any listed skill that no longer exists in the source but still exists in the destination (scripts/sync-superpowers.sh:20).
- **FR-004**: System MUST, for each source skill directory, `rm -rf` the destination then `cp -r` the source into it (scripts/sync-superpowers.sh:35).
- **FR-005**: System MUST abort with a stderr error and exit 1 if a skill basename resolves to an empty string (scripts/sync-superpowers.sh:34).
- **FR-006**: System MUST treat zero synced skills as a failure, printing a stderr warning and exiting 1 (scripts/sync-superpowers.sh:41).
- **FR-007**: System MUST write the list of synced skill names (one per line) to `vendor/superpowers/.synced-skills` after a successful sync (scripts/sync-superpowers.sh:47).
- **FR-008**: System MUST print a summary line reporting the count of skills synced (scripts/sync-superpowers.sh:49).
- **FR-009**: System MUST require a tag argument to bump, aborting with a usage message if absent (scripts/bump-superpowers.sh:5).
- **FR-010**: System MUST pull the named tag from `https://github.com/obra/superpowers.git` via `git subtree pull --prefix=vendor/superpowers ... --squash` (scripts/bump-superpowers.sh:6, scripts/bump-superpowers.sh:10).
- **FR-011**: System MUST re-run `sync-superpowers.sh` from the bump script's own directory after the subtree pull (scripts/bump-superpowers.sh:13).
- **FR-012**: System MUST update `VENDORED.md` by invoking `_update-vendored-md.sh` with the tag and the current date formatted `%Y-%m-%d` (scripts/bump-superpowers.sh:16).
- **FR-013**: System MUST print a manual commit reminder after bump rather than committing automatically (scripts/bump-superpowers.sh:18).
- **FR-014**: System MUST require both a tag and a date argument to update VENDORED.md, aborting with usage messages otherwise (scripts/_update-vendored-md.sh:7, scripts/_update-vendored-md.sh:8).
- **FR-015**: System MUST abort with a stderr error and exit 1 if `VENDORED.md` is absent (scripts/_update-vendored-md.sh:12).
- **FR-016**: System MUST rewrite the `**Pinned version**:` and `**Last synced**:` lines in `VENDORED.md` via `sed` and remove the `.bak` backup it creates (scripts/_update-vendored-md.sh:17, scripts/_update-vendored-md.sh:21).
- **FR-017**: System MUST print a confirmation line reporting the new version and date after updating VENDORED.md (scripts/_update-vendored-md.sh:23).
- **FR-018**: All three scripts MUST run under `set -euo pipefail` so any unhandled command failure aborts execution (scripts/sync-superpowers.sh:3, scripts/bump-superpowers.sh:3, scripts/_update-vendored-md.sh:5).

### Key Entities

- **VENDORED.md** — provenance file for vendored dependencies, with a `## superpowers` section containing `**Upstream**` (repo URL), `**Pinned version**` (the upstream tag, the line rewritten on bump), `**Subtree prefix**` (`vendor/superpowers/`), and `**Last synced**` (the YYYY-MM-DD date, also rewritten on bump).
- **vendor/superpowers/.synced-skills** — newline-delimited ledger of skill names copied on the last sync; consumed at the start of the next sync to detect and remove skills that disappeared upstream.
- **vendor/superpowers/skills/** — vendored source tree (git subtree); the authoritative copy source.
- **skills/** — published destination tree mixing copied vendored skills and untouched maxi-native skills.

## Success Criteria

### Measurable Outcomes

- **SC-001**: After `sync-superpowers.sh`, every directory in `vendor/superpowers/skills/` is byte-identical to its counterpart in `skills/`.
- **SC-002**: After a sync, no maxi-native skill (one absent from the vendored source) is added, removed, or modified.
- **SC-003**: A skill removed upstream is removed from `skills/` on the next sync, provided it was recorded in `.synced-skills`.
- **SC-004**: A sync that copies zero skills exits non-zero (fails loudly) rather than silently succeeding.
- **SC-005**: After `bump-superpowers.sh <tag>`, `VENDORED.md`'s `**Pinned version**` equals `<tag>` and `**Last synced**` equals the run date, with no `.bak` file left behind.
- **SC-006**: No script commits to git; the bump only prints a commit reminder.

## Assumptions

- The scripts run inside the maxi-superpowers git repository; `git rev-parse --show-toplevel` resolves the root.
- `git subtree` is available and `vendor/superpowers` was previously established via `git subtree add`.
- The host `sed` accepts the BSD/macOS `-i.bak` in-place form (the `.bak` is created then deleted).
- `VENDORED.md` already contains a `**Pinned version**:` and a `**Last synced**:` line for `sed` to match.
- Bash with `nullglob` support is available (the sync script enables `shopt -s nullglob`).
- The maintainer commits the resulting changes manually; the tooling deliberately leaves git history to the user.

## Migration Notes

- Reverse-engineered from commit `7f945f8a8548bf1b4b123d28cc097e2cca897c68`.
- The plan/tasks/analyze/implement phases never ran — the code is the implementation (constitution v1.4.0 ingress clause, ADR-0011).
- Verified against code by an adversarial pass before acceptance.
