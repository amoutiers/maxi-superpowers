# maxi-superpowers Architecture

## Plugin Overview

maxi-superpowers is a tri-harness plugin (Claude Code · OpenCode · Antigravity; see Harness Strategy below) with two layers:

1. **spec-kit pipeline** — 18 maxi-native skills: 12 user-facing commands, 2 internal pipeline skills (`x-adr`, `x-develop`), 1 session skill (`using-maxi`), and 3 migration utilities (`migrate-from-speckit`, `migrate-from-brownfield`, `migrate-adr`). Each reads artifacts from `docs/maxi/constitution.md` and `docs/maxi/` and refuses to run if prerequisites are missing.

2. **superpowers implementation engine** — vendored superpowers v6.0.3 skills (`brainstorming`, `writing-plans`, `executing-plans`, etc.) that do the heavy lifting. Pipeline skills delegate to them at the right moments.

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
│   ├── constitution/        # maxi-native pipeline commands
│   ├── specify/
│   ├── clarify/
│   ├── plan/
│   ├── tasks/
│   ├── analyze/
│   ├── implement/
│   ├── board/               # maxi-native lifecycle commands
│   ├── park/
│   ├── resume/
│   ├── cancel/
│   ├── revise/
│   ├── x-adr/                # internal ADR capture skill (invoked by plan + implement)
│   ├── x-develop/            # internal SDD wrapper skill (invoked by implement)
│   ├── using-maxi/          # maxi-native session skill
│   ├── migrate-from-speckit/ # maxi-native migration utilities
│   ├── migrate-from-brownfield/
│   ├── migrate-adr/
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
│   # Each artifact template lives in its owning skill's directory:
│   #   constitution/constitution-template.md, specify/spec-template.md,
│   #   plan/plan-template.md, tasks/tasks-template.md, x-adr/adr-template.md
├── scripts/
│   ├── sync-superpowers.sh  # re-sync vendored skills from vendor/superpowers/
│   └── bump-superpowers.sh  # pull new superpowers tag into vendor/
├── vendor/
│   └── superpowers/         # git subtree of superpowers upstream
├── tests/
│   ├── run-all.sh
│   ├── check-*.sh           # fast-tier checks (see CLAUDE.md for the authoritative list)
│   ├── integration/         # opt-in integration tier
│   └── fixtures/
├── docs/
│   ├── architecture.md      # this file
│   ├── delegation-map.md    # forward + lifecycle skill tables
│   ├── pipeline-flow.md     # Mermaid diagram + FSM
│   └── maxi/                # per-project artifacts (constitution, adr/, specs/)
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
| `specify` | `/maxi:brainstorming` |
| `clarify` | (none — interactive dialogue) |
| `plan` | `/maxi:writing-plans`, then `/maxi:x-adr` per detected architectural choice |
| `tasks` | (none — extraction only) |
| `analyze` | (none — reads artifacts + ADRs, writes analysis.md with 7-pass audit) |
| `implement` | `/maxi:x-develop`, then `/maxi:x-adr` on unplanned forks, then `/maxi:requesting-code-review` |
| `x-adr` | (internal — invoked by plan + implement; never invoked by user directly) |

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

**Trigger points:** `/maxi:plan` scans the produced plan for tech-stack and architecture choices; `/maxi:implement` watches for unplanned forks reported by subagents. Both invoke `/maxi:x-adr`, which drafts the ADR, shows it to the user, and writes only on explicit consent.

**Append-only:** ADR body is immutable after creation. Only `status`, `supersedes`, and `superseded_by` frontmatter fields may change. To revise a decision, create a new ADR that supersedes the old one. ADRs no longer carry cross-reference fields (`related_specs`/`related_principles`/`related_requirements`); spec→ADR traceability is recorded spec-side via the spec's `related_adrs` frontmatter (ADR-0012).

**Pass G (analyze):** `/maxi:analyze` runs a 7th detection pass — ADR Alignment — that flags missing ADRs for consequential tech choices (G1, MEDIUM), ADRs contradicting constitution MUST rules (G2, CRITICAL), stale ADR references (G3, HIGH), and cyclic supersede chains (G4, HIGH). It reads the spec-side `related_adrs` link to associate a spec with its ADRs. If `docs/maxi/adr/` is empty or absent, Pass G is skipped and the metrics note "no ADRs recorded."

## Phase Gating

Every `spec.md` carries a `status:` field in its YAML frontmatter:

```
drafting → specified → clarified → planned → tasked → analyzed → implementing → done
```

Each skill checks this field at startup:

- If the spec is **behind** the required status, the skill stops with a message directing the user to the missing step.
- If the spec is **ahead** of the status (e.g., already `planned` when calling `/maxi:plan`), the skill stops to prevent accidental re-runs.

Skills update `status:` in-place at the end of their process. The frontmatter is the single source of truth for pipeline position. The spec frontmatter also carries `related_adrs` — a list of full ADR slugs — recording the spec→ADR link (written by `x-adr` when an ADR is accepted).

### Phase Gating Philosophy

Each pipeline phase has its own responsibility — that is why it exists as a separate skill. Allowing a phase to be bypassed contradicts the premise that each phase deserves a dedicated step. The pipeline is therefore strict: every feature passes through every phase, in order.

Skills are designed to be cheap when there is nothing to do. `/maxi:clarify` can resolve to "no ambiguities found" in a single step. `/maxi:analyze` produces a clean `analysis.md` with zero findings instantly. The ceremony cost is real but bounded; the value of the discipline is not.

## Vendoring Mechanics

superpowers is vendored as a git subtree at `vendor/superpowers/`:

```bash
# Initial add (one-time bootstrap; current pin is v6.0.3 — see VENDORED.md):
git subtree add --prefix=vendor/superpowers https://github.com/obra/superpowers v6.0.3 --squash

# Bump to a new version:
bash scripts/bump-superpowers.sh <new-tag>

# Re-sync skills/ from vendor/:
bash scripts/sync-superpowers.sh
```

`sync-superpowers.sh` copies skills from `vendor/superpowers/skills/` into `skills/` and updates `VENDORED.md`. The `check-sync-invariant.sh` test verifies that `skills/` and `vendor/superpowers/skills/` are in sync — it fails if they diverge.

## Harness Strategy

maxi ships its session bootstrap to three supported agent harnesses:

| Harness | Mechanism |
|---|---|
| Claude Code | `hooks/hooks.json` (`${CLAUDE_PLUGIN_ROOT}`) + `.claude-plugin/` manifest + marketplace |
| OpenCode | `.opencode/plugins/maxi.js` (transforms the first user message) |
| Antigravity | root `hooks.json` + `plugin.json` (`${extensionPath}`); `agy plugin install .` |

All three are validated by the fast tier (`check-hooks.sh`, `check-plugin-manifest.sh`, `check-opencode-plugin.sh`, `check-bootstrap-parity.sh`). The bootstrap preamble is identical across the bash hook and the OpenCode plugin (parity-guarded).

**Not supported:** Cursor (its `.cursor/hooks.json` / `sessionStart` mechanism differs from this plugin's hook model; real support deferred to a future ADR) and Copilot CLI. The legacy Gemini CLI install is documented for historical use only; Antigravity (`agy`) is its successor.

## Design Decisions

### Strict pipeline — no skips (2026-05-24)

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
