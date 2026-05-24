# maxi-superpowers Architecture

## Plugin Overview

maxi-superpowers is a Claude Code plugin with two layers:

1. **spec-kit pipeline** — 7 user-facing commands plus 1 internal skill (`adr`), totalling 8 maxi-native skills. Each reads artifacts from `docs/maxi/constitution.md` and `docs/maxi/` and refuses to run if prerequisites are missing.

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
│   ├── adr/                 # internal ADR capture skill (invoked by plan + implement)
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
│   ├── tasks-template.md
│   └── adr-template.md
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

See [delegation-map.md](delegation-map.md) for the full table, and [pipeline-flow.md](pipeline-flow.md) for a visual Mermaid diagram of the complete pipeline including status transitions, bypass branches, and delegations. Summary:

| maxi skill | Delegates to |
|---|---|
| `constitution` | (none — writes directly) |
| `specify` | `maxi:brainstorming` |
| `clarify` | (none — interactive dialogue) |
| `plan` | `maxi:writing-plans`, then `maxi:adr` per detected architectural choice |
| `tasks` | (none — extraction only) |
| `analyze` | (none — reads artifacts + ADRs, writes analysis.md with 7-pass audit) |
| `implement` | `maxi:executing-plans`, then `maxi:adr` on unplanned forks, then `maxi:requesting-code-review` |
| `adr` | (internal — invoked by plan + implement; never invoked by user directly) |

## Architecture Decision Records

ADRs live in the **user's project**, not in this plugin repo. The layout in a user project:

```
docs/
└── maxi/
    ├── constitution.md      # mandatory, checked by every pipeline skill
    ├── adr/
    │   ├── README.md        # auto-maintained index (all ADRs, sorted by number)
    │   └── NNNN-slug.md     # 0001–9999, zero-padded
    └── specs/
        └── NNNN-feature-slug/
```

**Trigger points:** `/maxi:plan` scans the produced plan for tech-stack and architecture choices; `/maxi:implement` watches for unplanned forks reported by subagents. Both invoke `maxi:adr`, which drafts the ADR, shows it to the user, and writes only on explicit consent.

**Append-only:** ADR body is immutable after creation. Only `status`, `supersedes`, and `superseded_by` frontmatter fields may change. To revise a decision, create a new ADR that supersedes the old one.

**Pass G (analyze):** `/maxi:analyze` runs a 7th detection pass — ADR Alignment — that flags missing ADRs for consequential tech choices (G1, MEDIUM), ADRs contradicting constitution MUST rules (G2, CRITICAL), stale ADR references (G3, HIGH), and cyclic supersede chains (G4, HIGH). If `docs/maxi/adr/` is empty or absent, Pass G is skipped and the metrics note "no ADRs recorded."

## Phase Gating

Every `spec.md` carries a `status:` field in its YAML frontmatter:

```
drafting → specified → clarified → planned → tasked → analyzed → implementing → done
```

Each skill checks this field at startup:

- If the spec is **behind** the required status, the skill stops with a message directing the user to the missing step.
- If the spec is **ahead** of the status (e.g., already `planned` when calling `/maxi:plan`), the skill stops to prevent accidental re-runs.

Skills update `status:` in-place at the end of their process. The frontmatter is the single source of truth for pipeline position.

### Phase Gating Philosophy

Each pipeline phase has its own responsibility — that is why it exists as a separate skill. Allowing a phase to be bypassed contradicts the premise that each phase deserves a dedicated step. The pipeline is therefore strict: every feature passes through every phase, in order.

Skills are designed to be cheap when there is nothing to do. `/maxi:clarify` can resolve to "no ambiguities found" in a single step. `/maxi:analyze` produces a clean `analysis.md` with zero findings instantly. The ceremony cost is real but bounded; the value of the discipline is not.

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

## Design Decisions

### Strict pipeline — no skips (2026-05-28)

**Decision:** Every pipeline phase is mandatory. No phase may be bypassed, even with a warning.

**Context:** An earlier version allowed two skips: `/maxi:plan` accepted `specified` (skipping clarify, with warning), and `/maxi:implement` accepted `tasked` (skipping analyze, with warning). This created an undocumented asymmetry — only `clarify` and `analyze` were skippable, with no written rationale. The phrase "Nothing skips the queue" in this document was contradicted in practice.

**Alternatives considered:**
- *Status quo + docs*: document the asymmetry as "raffinement vs structurel" rule. Rejected because it justifies the symptom rather than fixing the design.
- *Extend skippability to `tasks`*: apply the same "derivable from plan.md" logic. Rejected because it weakens the pipeline further.
- *Per-project mandatory flags*: constitution declares which phases are mandatory per project. Rejected as over-engineering for a marginal gain.

**Rationale:** If a skill exists as a separate pipeline phase, its responsibility is worth enforcing. The "skip-with-warning" pattern is a code smell — it delegates a design decision to the user at runtime. A strict pipeline makes the discipline explicit and non-negotiable.

**Consequences:**
- Specs at status `drafting` or `specified` must pass through the full remaining pipeline from that status.
- `/maxi:migrate-from-speckit` is an **explicit exception**: it infers status from pre-existing spec-kit artefacts (`planned`, `tasked`, `done`). Trust is delegated to the spec-kit history. From the inferred status forward, the strict pipeline applies without exception.
- Migrated specs with status above `specified` have a `## Migration Notes` section appended, documenting which maxi pipeline phases were not run. This section is informational — it records provenance, not a mandate to re-run phases.
