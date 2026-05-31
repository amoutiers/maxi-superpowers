---
adr: 0005
slug: 0005-superpowers-vendoring-git-subtree
status: accepted
created: 2026-05-29
updated: 2026-05-29
decider: "[inferred] Antoine Moutiers"
supersedes: null
superseded_by: null
---

# ADR-0005: Vendoring Superpowers via Git Subtree

## Context

maxi-superpowers delegates execution to superpowers' skills (`brainstorming`,
`writing-plans`, `executing-plans`, etc.) rather than duplicating them. A
vendoring strategy was needed: runtime npm dependency, git submodule, copy-paste,
or git subtree? The project chose `git subtree add --prefix=vendor/superpowers`
at a pinned tag (`v5.1.0`). Skills are synced from `vendor/superpowers/skills/`
into `skills/` via `scripts/sync-superpowers.sh`. `check-sync-invariant.sh`
enforces byte-identity between the two directories. `VENDORED.md` records the
pinned version, subtree prefix, and last-synced date.

## Decision Drivers

- **Principle II — Delegate to Superpowers, Never Duplicate**: skills must come
  from upstream, not be hand-written copies. Drift must be CI-detectable.
- **Offline availability**: plugin consumers need skills available at install
  time, without a separate fetch step.
- **Pinned, auditable versions**: contributors need to know exactly which upstream
  commit they are running.
- **Constrains future upgrade path**: switching vendoring strategies later would
  require migrating subtree history and all sync tooling.

## Considered Options

- **Option A: Git subtree at `vendor/superpowers/` + sync script**
  - ✅ offline availability — skills committed to repo
  - ✅ pinned and auditable — subtree commit SHA recorded
  - ✅ drift detectable — sync invariant test fails on divergence
  - ❌ subtree history baked into `git log`
  - ❌ orphan tracking (`vendor/superpowers/.synced-skills`) required for
    upstream skill removals

- **Option B: Git submodule**
  - ✅ clean separation of history
  - ❌ requires `git submodule init` on clone — breaks simple install
  - ❌ more complex contributor workflow

- **Option C: npm/package.json dependency**
  - ✅ standard dependency management
  - ❌ superpowers is not published to npm
  - ❌ adds a runtime install step; conflicts with the "skills in repo" model

- **Option D: Copy-paste (no tracking)**
  - ✅ simplest — no tooling needed
  - ❌ no upgrade path; violates Principle II (drift undetectable)

## Decision

Chose **Option A**. `git subtree add` was used in the initial vendoring commit
(`chore(vendor): vendor superpowers v5.1.0 via git subtree; sync 14 skills`).
`sync-superpowers.sh` + `bump-superpowers.sh` + `check-sync-invariant.sh` form
the supporting toolchain.

## Consequences

- **Good:** Skills are committed to the repo — no fetch step required at install
  time.
- **Good:** `check-sync-invariant.sh` makes drift a CI failure, not a silent bug.
- **Good:** Orphan tracking (`vendor/superpowers/.synced-skills`) handles upstream
  skill removals without silent pollution of `skills/`.
- **Bad:** Subtree history is baked into `git log`; initial squash mitigates but
  does not eliminate.
- **Bad:** Upgrading requires running `bump-superpowers.sh` — contributors must
  remember to re-sync after a version bump.
- **Bad:** maxi-native skills in `skills/` must never be overwritten by the sync
  script — `sync-superpowers.sh` guards this explicitly.

## Confirmation

- `tests/check-sync-invariant.sh` verifies `skills/<vendored>` are byte-identical
  to `vendor/superpowers/skills/<vendored>`.
- `tests/check-sync-script.sh` verifies `sync-superpowers.sh` copies vendor skills
  and leaves maxi-native skills untouched.
- `tests/check-bump-script.sh` verifies `_update-vendored-md.sh` correctly updates
  version and date in `VENDORED.md`.
- `VENDORED.md` records pinned version, subtree prefix, and last-synced date.
