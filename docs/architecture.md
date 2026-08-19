# maxi-superpowers Architecture

## Plugin Overview

maxi-superpowers is a multi-harness plugin aligned 1:1 with the superpowers v6.3.0 harness model (Claude Code · Codex · OpenCode · Antigravity · Cursor · Pi; plus Kimi Code, Factory Droid, and GitHub Copilot CLI via marketplace docs; see Harness Strategy below) with two layers:

1. **spec-kit pipeline** — 19 maxi-native skills: 12 user-facing commands, 3 internal pipeline skills (`x-adr`, `x-develop`, `x-review`), 1 session skill (`using-maxi`), and 3 migration utilities (`migrate-from-speckit`, `migrate-from-brownfield`, `migrate-adr`). Each reads artifacts from `docs/maxi/constitution.md` and `docs/maxi/` and refuses to run if prerequisites are missing.

2. **superpowers implementation engine** — vendored superpowers v6.3.0 skills (`brainstorming`, `writing-plans`, `executing-plans`, etc.) that do the heavy lifting. Pipeline skills delegate to them at the right moments.

The result: a project goes from blank slate to shipped code through a reproducible, auditable sequence. Nothing skips the queue.

## Repo Layout

```
maxi-superpowers/
├── .claude-plugin/          # Claude Code plugin manifest (+ marketplace)
├── .codex-plugin/           # Codex plugin manifest (hooks: {}, native skill discovery)
├── .agents/plugins/         # Codex marketplace manifest
├── .opencode/               # OpenCode plugin (maxi.js) + INSTALL.md
├── .pi/                     # Pi extension (maxi.ts)
├── hooks/                   # Session-start hooks
│   ├── hooks.json           # Claude Code + Antigravity root manifest (session-start)
│   ├── hooks-cursor.json    # Cursor manifest (sessionStart + additional_context)
│   ├── run-hook.cmd          # Cross-platform polyglot wrapper
│   └── session-start         # Unified hook (env-aware JSON output, gated on docs/maxi/)
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
│   │   └── replay-plan.sh    # read-only bounded replay planner
│   ├── x-adr/                # internal ADR capture skill (invoked by plan + implement)
│   ├── x-develop/            # internal SDD wrapper skill (invoked by implement)
│   ├── x-review/             # internal independent handoff-review owner
│   │   └── review-template.md # persisted versioned review-record template
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
├── plugins/
│   └── maxi -> ..           # Codex marketplace source path back to this plugin root
├── vendor/
│   └── superpowers/         # git subtree of superpowers upstream
├── tests/
│   ├── run-all.sh
│   ├── check-*.sh           # fast-tier checks (see AGENTS.md for the authoritative list)
│   ├── check-x-review.sh     # independent review-record contract
│   ├── integration/         # opt-in integration tier
│   └── fixtures/
├── docs/
│   ├── architecture.md      # this file
│   ├── delegation-map.md    # forward + lifecycle skill tables
│   ├── pipeline-flow.md     # Mermaid diagram + FSM
│   └── maxi/                # per-project artifacts (constitution, adr/, specs/)
├── AGENTS.md                # shared contributor guidelines
├── CLAUDE.md                # Claude Code adapter that imports AGENTS.md
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
| `x-review` | `/maxi:requesting-code-review`; persists the approved handoff record and never changes status |

For a marker-bound root, `reviews/spec-review.md` gates `plan`; `reviews/plan-review.md` gates `tasks`. The records are persisted and versioned by `x-review`. These external review handoffs are gates, not statuses or automatic replay phases. `skills/revise/replay-plan.sh` is a read-only planner that calculates a bounded stale-descendant continuation, stops at the first required review, and never writes artifacts or executes phases.

Bounded replay is future-only. Eligible roots carry exactly one `replay_contract: bounded-v1`; only `/maxi:specify` writes this marker, during normal forward-spec creation. An unmarked existing, migrated, or reverse-engineered spec returns `UNSUPPORTED_LEGACY`; revision metadata alone never opts it in.

For a marker-bound root, `reviewed_sha256` hashes the canonical structural projection, which omits only root-frontmatter `status:` and `updated:`, preserves every other line in order, and hashes one LF after each retained line. The exact ten-field review envelope is `revision`, `writer_context`, `structural_contributors`, `derived_from`, `reviewed_document`, `reviewed_revision`, `reviewed_sha256`, `reviewer_context`, `reviewer_context_matches_harness`, and `verdict`. Before delegation, artifact write, or status/timestamp change, `plan` and `tasks` require positive record and reviewed revisions, exactly one mapped direct input, the exact current subject/revision/digest, canonical unique contributors and contexts, writer equals reviewer and appears in contributors, harness equality exactly `true`, verdict exactly `approved`, and reviewer independence from the subject contributors.

The persisted continuation is `replay_continuation: clarify@<current-spec-revision>` after the exceptional source rollback; `/maxi:clarify` can re-present it with `--resume-current-source` after rejection, ambiguity, or interruption. `--resume-current-source` is legal only for `spec.md`, start phase `clarify`, and that matching current marker. Clarification replaces it with `replay_continuation: plan@<current-spec-revision>`. After `x-review` writes the matching spec review, `/maxi:plan` can re-present the spec review continuation with `--resume-current-review`; a consented plan write persists `replay_continuation: tasks@<current-plan-revision>`. After the matching plan review, `/maxi:tasks` can re-present the plan review continuation with `--resume-current-review`. `--resume-current-review` accepts exactly two combinations: `reviews/spec-review.md` with `plan`, or `reviews/plan-review.md` with `tasks`; both require the current subject and review plus every transitive `derived_from` ancestor. Each displayed executable segment requires its own fresh literal `yes`.

Before plan resume, a stale `spec.md`, support artifact, or specification review is rejected before any continuation output or write, even when `plan.md` and its plan review still match.

An explicit owner-managed plan correction is available only when explicitly requested at `planned`, `tasked`, `analyzed`, or `implementing`; it preserves the current spec-review gate, writes `replay_continuation: tasks@<current-plan-revision>` with the corrected plan, and returns only to `planned`. An explicit owner-managed tasks correction is available only when explicitly requested at `tasked`, `analyzed`, or `implementing`; it preserves the current plan-review gate and returns only to `tasked`. After `x-review` writes a marker-bound approved plan review, it immediately invokes the read-only planner with the predecessor review revision and displays the current approved `tasks -> analyze` continuation. `x-review` never executes a phase or obtains consent. For that marker-bearing corrected plan, `/maxi:tasks` is only the later no-write resume presenter: it invokes the read-only planner with `--resume-current-review`, redisplays that continuation, and requires a fresh literal `yes` before extraction. Rejection, ambiguity, or session interruption changes nothing and the same current review can be presented again.

Only new specs created through the normal forward pipeline receive this revision and replay behavior; existing, migrated, and reverse-engineered specs remain untouched. For an unmarked root, plan and tasks use the ordinary pipeline: no review record, x-review handoff, review provenance, review reporting, or replay planner is required. This mechanism never creates or writes `workflow.md` or `.maxi-ops`.

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

The 10-state FSM remains unchanged. Review handoffs and replay proposals are external control gates around existing phases, not additional phases or status transitions. `revise` reserves the exceptional `specified` rollback for a demonstrated source-spec gap; its replay starts at `clarify` and never invokes `specify`.

Every `spec.md` carries a `status:` field in its YAML frontmatter:

```
drafting → specified → clarified → planned → tasked → analyzed → implementing → done
```

Each skill checks this field at startup:

- If the spec is **behind** the required status, the skill stops with a message directing the user to the missing step.
- If the spec is **ahead** of the normal creation status, the skill stops to prevent accidental re-runs. `plan` and `tasks` enter their separate correction modes only after an explicit structural correction request at one of the statuses documented above.

Skills update `status:` in-place at the end of their process. The frontmatter is the single source of truth for pipeline position. The spec frontmatter also carries `related_adrs` — a list of full ADR slugs — recording the spec→ADR link (written by `x-adr` when an ADR is accepted).

### Phase Gating Philosophy

Each pipeline phase has its own responsibility — that is why it exists as a separate skill. Allowing a phase to be bypassed contradicts the premise that each phase deserves a dedicated step. The pipeline is therefore strict: every feature passes through every phase, in order.

Skills are designed to be cheap when there is nothing to do. `/maxi:clarify` can resolve to "no ambiguities found" in a single step. `/maxi:analyze` produces a clean `analysis.md` with zero findings instantly. The ceremony cost is real but bounded; the value of the discipline is not.

## Vendoring Mechanics

superpowers is vendored as a git subtree at `vendor/superpowers/`:

```bash
# Initial add (one-time bootstrap; current pin is v6.3.0 — see VENDORED.md):
git subtree add --prefix=vendor/superpowers https://github.com/obra/superpowers v6.3.0 --squash

# Bump to a new version:
bash scripts/bump-superpowers.sh <new-tag>

# Re-sync skills/ from vendor/:
bash scripts/sync-superpowers.sh
```

`sync-superpowers.sh` copies skills from `vendor/superpowers/skills/` into `skills/` and updates `VENDORED.md`. The `check-sync-invariant.sh` test verifies that `skills/` and `vendor/superpowers/skills/` are in sync — it fails if they diverge.

## Harness Strategy

maxi adopts the superpowers v6.3.0 harness model 1:1 (ADR-0016). Ten harnesses are addressed, six with in-repo packaging and four via marketplace docs only:

| Harness | Mechanism |
|---|---|
| Claude Code | `.claude-plugin/plugin.json` + marketplace; `hooks/hooks.json` (root) is the SessionStart manifest using `${CLAUDE_PLUGIN_ROOT}` and runs the unified `hooks/session-start` |
| Antigravity | `agy plugin install <repo>`; reads the root `hooks/hooks.json` and runs `hooks/session-start` (no dedicated package directory) |
| Cursor | `hooks/hooks-cursor.json` (Cursor `sessionStart` event, `additional_context` shape) running `hooks/session-start` |
| Codex | `.codex-plugin/plugin.json` declares `"hooks": {}` so Codex relies on native skill discovery (no SessionStart hook); `.agents/plugins/marketplace.json` + `plugins/maxi` |
| OpenCode | `.opencode/plugins/maxi.js` transforms the first user message and registers the skills directory via the `config` hook |
| Pi | `package.json` `pi` section + `.pi/extensions/maxi.ts` injects the bootstrap via the Pi extension API |
| Kimi Code, Factory Droid, GitHub Copilot CLI | Marketplace install only (no in-repo packaging); documented in README |

Hook ownership:

- `hooks/hooks.json`: root manifest for Claude Code and Antigravity. Runs the unified `hooks/session-start`.
- `hooks/hooks-cursor.json`: Cursor manifest (Cursor `sessionStart` event, `additional_context` snake_case). Runs the unified `hooks/session-start`.
- `hooks/session-start`: the single env-aware hook. Detects `CURSOR_PLUGIN_ROOT` (`additional_context`), `CLAUDE_PLUGIN_ROOT` without `COPILOT_CLI` (`hookSpecificOutput.additionalContext`), and falls back to the SDK-standard top-level `additionalContext`. Gated on `docs/maxi/` (silent outside a maxi project).
- `hooks/run-hook.cmd`: cross-platform polyglot wrapper for the hook scripts.

The package is validated by the fast tier (`check-hooks.sh`, `check-plugin-manifest.sh`, `check-codex-plugin.sh`, `check-opencode-plugin.sh`, `check-bootstrap-parity.sh`, `check-cursor-hooks.sh`, `check-pi-extension.sh`). The bootstrap preamble is identical across the bash hook, the OpenCode plugin, and the Pi extension (parity-guarded).

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
