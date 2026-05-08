# maxi-superpowers Architecture

## Plugin Overview

maxi-superpowers is a Claude Code plugin with two layers:

1. **spec-kit pipeline** — 7 maxi-native skills (`constitution`, `specify`, `clarify`, `plan`, `tasks`, `analyze`, `implement`) that enforce a phase-gated workflow. Each skill reads artifacts from `docs/maxi/` and refuses to run if the spec is in the wrong phase.

2. **superpowers implementation engine** — vendored superpowers v5.1.0 skills (`brainstorming`, `writing-plans`, `executing-plans`, etc.) that do the heavy lifting. Pipeline skills delegate to them at the right moments.

The result: a project goes from blank slate to shipped code through a reproducible, auditable sequence. Nothing skips the queue.

## Repo Layout

```
maxi-superpowers/
├── .claude-plugin/          # Claude Code plugin manifest
├── hooks/                   # Session-start and event hooks
│   ├── hooks.json
│   ├── run-hook.cmd
│   └── session-start
├── skills/
│   ├── constitution/        # maxi-native pipeline skills
│   ├── specify/
│   ├── clarify/
│   ├── plan/
│   ├── tasks/
│   ├── analyze/
│   ├── implement/
│   ├── using-maxi/          # maxi-native meta skill
│   ├── brainstorming/       # vendored from superpowers (do not hand-edit)
│   ├── writing-plans/
│   ├── executing-plans/
│   ├── writing-skills/
│   ├── systematic-debugging/
│   ├── test-driven-development/
│   ├── verification-before-completion/
│   ├── finishing-a-development-branch/
│   ├── using-git-worktrees/
│   ├── dispatching-parallel-agents/
│   ├── subagent-driven-development/
│   ├── requesting-code-review/
│   ├── receiving-code-review/
│   └── using-superpowers/
├── templates/               # Artifact templates
│   ├── constitution-template.md
│   ├── spec-template.md
│   ├── plan-template.md
│   └── tasks-template.md
├── scripts/
│   ├── sync-superpowers.sh  # re-sync vendored skills from vendor/superpowers/
│   └── bump-superpowers.sh  # pull new superpowers tag into vendor/
├── vendor/
│   └── superpowers/         # git subtree of superpowers upstream
├── tests/
│   ├── run-all.sh
│   ├── check-frontmatter.sh
│   ├── check-sync-invariant.sh
│   ├── check-spec-fixture.sh
│   └── fixtures/
├── docs/
│   ├── architecture.md      # this file
│   └── delegation-map.md
├── CLAUDE.md                # contributor guidelines
├── VENDORED.md              # vendored dependency record
└── package.json
```

Skills under `skills/` that originate from superpowers are kept in sync with `vendor/superpowers/skills/` by `scripts/sync-superpowers.sh`. Do not hand-edit them.

## The Delegation Map

See [delegation-map.md](delegation-map.md) for the full table. Summary:

| maxi skill | Delegates to |
|---|---|
| `constitution` | (none — writes directly) |
| `specify` | `maxi:brainstorming` |
| `clarify` | (none — interactive dialogue) |
| `plan` | `maxi:writing-plans` |
| `tasks` | (none — extraction only) |
| `analyze` | (none — reads artifacts, writes analysis.md) |
| `implement` | `maxi:executing-plans`, then `maxi:requesting-code-review` |

## Phase Gating

Every `spec.md` carries a `status:` field in its YAML frontmatter:

```
drafting → specified → clarified → planned → tasked → analyzed → implementing → done
```

Each skill checks this field at startup:

- If the spec is **behind** the required status, the skill stops with a message directing the user to the missing step.
- If the spec is **ahead** of the status (e.g., already `planned` when calling `/maxi:plan`), the skill stops to prevent accidental re-runs.
- Some skills allow adjacent statuses with a warning (e.g., `/maxi:plan` accepts `specified` with a "clarification skipped" notice).

Skills update `status:` in-place at the end of their process. The frontmatter is the single source of truth for pipeline position.

## Vendoring Mechanics

superpowers is vendored as a git subtree at `vendor/superpowers/`:

```bash
# Initial add (already done):
git subtree add --prefix=vendor/superpowers https://github.com/obra/superpowers v5.1.0 --squash

# Bump to a new version:
bash scripts/bump-superpowers.sh <new-tag>

# Re-sync skills/ from vendor/:
bash scripts/sync-superpowers.sh
```

`sync-superpowers.sh` copies skills from `vendor/superpowers/skills/` into `skills/` and updates `VENDORED.md`. The `check-sync-invariant.sh` test verifies that `skills/` and `vendor/superpowers/skills/` are in sync — it fails if they diverge.
