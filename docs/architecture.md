# maxi-superpowers Architecture

## Plugin Overview

maxi-superpowers is a multi-harness plugin aligned 1:1 with the superpowers v6.3.0 harness model: Claude Code, Antigravity, Codex App, Codex CLI, Cursor, Devin CLI, Factory Droid, Gemini CLI, GitHub Copilot CLI, Grok Build CLI, Kimi Code, OpenCode, Pi, and Hermes Agent. It has two layers:

1. **Spec-driven pipeline**: 19 Maxi-native skills: 13 user-facing, 2 internal, 1 session, and 3 migration skills. The forward pipeline reads project artifacts and enforces its documented prerequisites; lifecycle and migration skills use only the prerequisites named by their own contracts.
2. **Superpowers implementation engine**: vendored superpowers v6.3.0 skills (`brainstorming`, `writing-plans`, `executing-plans`, and others) perform the delegated implementation work.

The result is a reproducible, auditable route from a feature request to shipped code.

## Repo Layout

```
maxi-superpowers/
├── .claude-plugin/          # Claude Code plugin manifest (+ marketplace)
├── .codex-plugin/           # Codex plugin manifest (hooks: {}, native skill discovery)
├── .agents/plugins/         # Codex marketplace manifest
├── .cursor-plugin/          # Cursor manifest (skills + hooks path)
├── .devin-plugin/           # Devin CLI metadata-only manifest
├── .kimi-plugin/            # Kimi Code declarative skill/bootstrap manifest
├── .hermes-plugin/          # Hermes manifest + gated Python adapter
├── .opencode/               # OpenCode plugin (maxi.js) + INSTALL.md
├── .pi/                     # Pi extension (maxi.ts)
├── hooks/                   # Session-start hooks
│   ├── hooks.json           # Claude Code + Antigravity root manifest (session-start)
│   ├── hooks-cursor.json    # Cursor manifest (sessionStart + additional_context)
│   ├── run-hook.cmd         # Cross-platform polyglot wrapper
│   └── session-start        # Unified hook (env-aware JSON output, gated on docs/maxi/)
├── skills/
│   ├── constitution/        # maxi-native pipeline commands
│   ├── specify/
│   ├── clarify/
│   ├── plan/
│   ├── review/              # explicit design-review owner
│   │   ├── design-reviewer.md # dedicated artifact-review brief
│   │   ├── design-contract.sh # candidate-based design stamp/verify
│   │   ├── approval-guard.sh # shared approval path and alias validation
│   │   └── review-inputs.sh # canonical decision-input digest
│   ├── tasks/
│   ├── analyze/
│   │   └── readiness-contract.sh # readiness evidence stamp/verify
│   ├── implement/
│   ├── board/               # maxi-native lifecycle commands
│   ├── park/
│   ├── resume/
│   ├── cancel/
│   ├── revise/
│   ├── x-adr/               # internal ADR creation, amendment, and supersession skill
│   ├── x-develop/           # internal SDD adapter (invoked by implement)
│   │   ├── project-tasks.sh # immutable TNNN → Task N projection
│   │   ├── projection-headings.awk # version-aware native heading map
│   │   ├── reconcile-tasks.sh # upstream ledger → Maxi checkbox reconciliation
│   │   ├── record-terminal.sh # hash-bound terminal receipt writer
│   │   └── result-contract.sh # READY_TO_FINISH validation gate
│   ├── using-maxi/          # session skill
│   ├── migrate-from-speckit/
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
│   ├── _update-vendored-md.sh # VENDORED.md pin updater
│   ├── sync-superpowers.sh  # re-sync vendored skills from vendor/superpowers/
│   └── bump-superpowers.sh  # pull new superpowers tag into vendor/
├── plugins/
│   └── maxi -> ..           # Codex marketplace source path back to this plugin root
├── vendor/
│   └── superpowers/         # git subtree of superpowers upstream
├── tests/
│   ├── run-all.sh
│   ├── check-*.sh           # fast-tier checks (see AGENTS.md for the authoritative list)
│   ├── check-review-boundaries.sh # fixed review-boundary contract
│   ├── integration/         # opt-in integration tier
│   └── fixtures/
├── docs/
│   ├── architecture.md      # this file
│   ├── delegation-map.md    # forward + lifecycle skill tables
│   ├── pipeline-flow.md     # Mermaid diagram + FSM
│   └── maxi/                # per-project artifacts (constitution, adr/, specs/)
├── AGENTS.md                # shared contributor guidelines
├── CLAUDE.md                # Claude Code adapter that imports AGENTS.md
├── GEMINI.md                # Gemini declarative context imports
├── gemini-extension.json    # Gemini CLI extension manifest
├── VENDORED.md              # vendored dependency record
└── package.json
```

Skills that originate from Superpowers are synchronized from `vendor/superpowers/skills/` by `scripts/sync-superpowers.sh`; do not hand-edit them.

## Delegation and Review Boundaries

See [delegation-map.md](delegation-map.md) for the complete mapping and [pipeline-flow.md](pipeline-flow.md) for the status diagram. Summary:

| maxi skill | Delegates to |
|---|---|
| `constitution` | writes directly |
| `specify` | `/maxi:brainstorming` |
| `clarify` | interactive dialogue |
| `plan` | `/maxi:writing-plans`, then `/maxi:x-adr` for detected architectural choices |
| `review` | dedicated `review/design-reviewer.md`; writes the design-review record |
| `tasks` | extraction from `plan.md` |
| `analyze` | reads artifacts and ADRs, writes and stamps `analysis.md` |
| `implement` | requires a current `maxi-readiness-v2` contract, then `/maxi:x-develop` and `/maxi:x-adr` for returned unplanned rulings |
| `x-develop` | `superpowers:subagent-driven-development` |
| `x-adr` | internal ADR creation and active-spec amendment workflow |

Every newly written `plan.md` carries exactly one `Global Constraints` section containing only applicable durable cross-task constraints from the spec and constitution; transient execution state and individual mutation authority are excluded, while a durable rule requiring fresh authorization is allowed.

The 10-state FSM remains unchanged. The three fixed review boundaries are design review after the normal plan write, readiness review in `/maxi:analyze` before implementation, and the upstream SDD final implementation review. They are gates, not statuses or automatic phase transitions.

A passing readiness review is valid only when `analysis.md` carries `maxi-readiness-v2` and its recorded structural spec/tasks hashes, exact plan hash, and `review_inputs_sha256` match the current artifacts and decision inputs; `/maxi:implement` verifies this with an explicit project root before every new or resumed dispatch and otherwise stops for `/maxi:analyze`.

Design approval uses `maxi-design-review-v1` with exact spec/plan hashes and the same decision-input digest: exact constitution bytes and names/bytes of every direct ADR Markdown file except generated README.md, regardless of status. Owners capture original hashes before reading, review the complete decision-input snapshot, and compare before report/status writes. Candidate-based stamping atomically publishes only after comparing the original supplied digest; failure preserves prior evidence. Tasks and implement resolve verifiers from loaded installed skills, never client fallbacks; legacy evidence requires a new actual review or analysis. Only `DESIGN_REVIEW_VERIFIED` permits extraction, and only `READINESS_VERIFIED` permits new/resumed implementation.

The public `/maxi:review` command dispatches `review/design-reviewer.md` with the complete exact current `spec.md`, `plan.md`, and accepted ADRs named by `spec.md`'s `related_adrs`. It writes `reviews/design-review.md`, bound to the spec/plan pair, only after one exact terminal verdict. Task `Files` lists are expected primary edits rather than implementation allowlists; mechanical closure does not block unless the design must change. `/maxi:tasks` stops before any write if that approval is missing or stale. A correction stops after its owner write and never starts a review or successor phase; request `/maxi:review` explicitly when a new design review is wanted.

`/maxi:x-develop` maps canonical Maxi `TNNN` tasks to an immutable SDD `Task N` projection. Upstream SDD owns task review, fix rounds, and the final implementation review. `/maxi:x-develop` is the sole incremental Maxi checkbox owner; `/maxi:implement` validates that every task is checked and alone persists `implementing → done`. Branch finishing starts only after Maxi has recorded `done`.

Upstream SDD owns the only whole-branch review. Before final-review work, `x-develop` persists the immutable initial task-selection anchor in the ordinary SDD ledger. On Codex it allocates a fresh reviewer for an identity handshake, persists the harness-returned canonical task path, then sends the review through a follow-up to that reviewer. It adapts canonical Maxi tasks into an immutable SDD projection, reconciles exact ledger completions, binds the reviewer identity, regenerates review packages from their Git ranges, and returns `READY_TO_FINISH` only after the hash-bound receipt validates. `implement` is the sole owner of the later `done` write and does not dispatch a second final review.

Current execution uses complete-body `maxi-v2` projections; immutable `maxi-v1` files remain verifiable historical predecessors. New projections retain the preamble and render each selected TNNN heading, canonical checkbox line, and complete mapped plan-task body in tasks-file order. Every canonical task, including checked tasks, requires exactly one terminal `(plan Task N)` mapping, bijective with the positive executable plan headings; missing, duplicate, non-positive, unknown, or unmapped entries require owner correction before publication. Plans must end with LF so extraction preserves the final payload line. Closed three-character backtick or tilde fences, optionally indented, normalize to column-zero triple backticks in the preamble and task bodies while preserving payload bytes. Longer or unclosed delimiters and payload lines that would toggle upstream fence state reject; fenced Task-like headings never enter native selection or completion maps. A validated active v1 projection upgrades only through an ordinary projection call to a new `<slug>-v2-p-<plan12>-t-<tasks12>-sdd.md` successor; its file and ledger remain unchanged. `--verify-only` requires an existing current v2 identity and never creates project directories, evidence, or upgrades. Only an unchanged-source v1 upgrade completed by validated ledgers may create an empty successor, which still requires a fresh final review; all-completed structural changes reject.

Only canonical annotated upstream completion records acquit tasks; bare or malformed completion lines fail closed. The accepted annotations are `review clean` or a positive `K parked`, with exactly two seven-hex commit IDs.

A null fix package requires exactly `**Ready to merge?** Yes`; a non-null byte-exact fix package requires the initial `**Ready to merge?** With fixes` plus exactly `**Fix round:** All findings addressed, no new Critical/Important breakage`.

Every projection's exact distributed bytes are SHA-256-bound by its ordinary SDD ledger; missing, duplicate, malformed, or mismatched projection-byte anchors fail closed across the current and predecessor lineage. Removing an anchored incomplete `TNNN` during structural correction fails before successor creation and leaves the active-projection pointer unchanged. Complete ledger lines containing `Ruling:` are preserved byte-for-byte in lineage order and hash-bound by the terminal receipt.

## Architecture Decision Records

ADRs live in each user's project under `docs/maxi/adr/`. Every new ADR records its creating spec through a direct `spec` link, or `spec: null` when standalone; `related_adrs` remains the spec-side review and analysis index. During an initial active lifecycle that lacks the monotone `reopened_from: done` watermark, a detected change to an accepted ADR whose `spec` matches the current spec invokes an agent-proposed active-spec amendment through internal `x-adr`. It shows the full amended ADR and exact diff and writes only after explicit approval. Existing ADRs are not migrated, and missing or null links, `done`, `parked`, or `cancelled` specs, and reopened specs marked `reopened_from: done` use closed-spec supersession instead. `/maxi:analyze` includes the ADR-alignment pass for missing decisions, constitution conflicts, stale links, and cyclic supersession chains.

## Phase Gating

Every `spec.md` carries this status progression:

```
drafting → specified → clarified → planned → tasked → analyzed → implementing → done
```

Skills stop when a spec is behind their prerequisite, and avoid accidental ordinary re-runs when it is ahead. `plan` and `tasks` accept explicit correction requests only in their documented correction modes. Spec frontmatter is the single source of truth for pipeline position; `related_adrs` records accepted ADRs for review and analysis, while each new ADR's scalar `spec` field records its creating spec for amendment eligibility.

### Strict Pipeline Philosophy

Each phase has one responsibility and remains mandatory in order. There is no skip path for forward development. Migration and reverse-engineering ingress can create artifacts at an appropriate later status because they document pre-existing work; from that point, the ordinary forward pipeline is strict.

## Vendoring Mechanics

superpowers is vendored as a git subtree at `vendor/superpowers/`:

```bash
# Current pin: v6.3.0 (see VENDORED.md)
git subtree add --prefix=vendor/superpowers https://github.com/obra/superpowers v6.3.0 --squash
bash scripts/bump-superpowers.sh <new-tag>
bash scripts/sync-superpowers.sh
```

`sync-superpowers.sh` copies the pinned upstream skills; `bump-superpowers.sh` and `_update-vendored-md.sh` own the `VENDORED.md` pin update. `check-sync-invariant.sh` rejects a divergence between the vendored tree and copied skills.

## Harness Strategy

maxi adopts the superpowers v6.3.0 harness model 1:1 (ADR-0021). Fourteen harnesses are addressed through executable adapters, declarative manifests, native discovery, or marketplace-only distribution:

| Harness | Mechanism |
|---|---|
| Claude Code | `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`; root `hooks/hooks.json` runs the gated unified `hooks/session-start` |
| Antigravity | Repository-root install reads `.claude-plugin/plugin.json` and root `hooks/hooks.json`; no `.antigravity-plugin/` directory |
| Codex App | `.agents/plugins/marketplace.json` resolves `plugins/maxi` to `.codex-plugin/plugin.json`; native skill discovery with `hooks: {}` |
| Codex CLI | Same `.agents/plugins/marketplace.json` → `plugins/maxi` → `.codex-plugin/plugin.json` path as Codex App; native skill discovery, no SessionStart hook |
| Cursor | `.cursor-plugin/plugin.json` points to `skills/` and `hooks/hooks-cursor.json`, which runs the gated `hooks/session-start` |
| Devin CLI | `.devin-plugin/plugin.json` is metadata-only; it declares no skills, hooks, commands, or bootstrap field |
| Factory Droid | Marketplace-only distribution path; no dedicated Maxi root manifest or runtime adapter in this repository |
| Gemini CLI | `gemini-extension.json` loads `GEMINI.md`, which imports `using-maxi` and the Gemini tool mapping declaratively |
| GitHub Copilot CLI | Marketplace-only distribution path; the installed root uses `hooks/hooks.json` and the `COPILOT_CLI` branch of `hooks/session-start` |
| Grok Build CLI | Marketplace-only distribution path; no dedicated Maxi root manifest or runtime adapter in this repository |
| Kimi Code | `.kimi-plugin/plugin.json` exposes `skills/`, loads `using-maxi` through `sessionStart.skill`, and carries the Kimi tool mapping inline |
| OpenCode | `package.json` points to `.opencode/plugins/maxi.js`, which registers `skills/` and injects only when `docs/maxi/` exists |
| Pi | `package.json` `pi` section loads `.pi/extensions/maxi.ts`, which gates first-session and post-compaction injection on `docs/maxi/` |
| Hermes Agent | `.hermes-plugin/plugin.yaml` loads `.hermes-plugin/__init__.py`; the adapter registers every skill and injects a short first-turn bootstrap only when `docs/maxi/` exists |

Gemini and Kimi are declarative bootstrap surfaces: their manifests cannot inspect the current working directory before loading `GEMINI.md` or `using-maxi`, so installation may expose that bootstrap outside Maxi projects. All executable adapters retain the `docs/maxi/` gate.

Hermes keeps the injected context below its 10,000-character limit by directing its native loader to `skill_view("maxi:using-maxi")` and adding only the Hermes tool mapping. Hermes has no post-compaction hook; after a sufficiently long session compacts away the first-turn bootstrap, start a fresh session to restore it.

Hook ownership:

- `hooks/hooks.json`: root manifest for Claude Code and Antigravity, and the shared marketplace hook path used by GitHub Copilot CLI. Runs the unified `hooks/session-start`.
- `hooks/hooks-cursor.json`: Cursor manifest (Cursor `sessionStart` event, `additional_context` snake_case). Runs the unified `hooks/session-start`.
- `hooks/session-start`: the single env-aware hook. Detects `CURSOR_PLUGIN_ROOT` (`additional_context`), `CLAUDE_PLUGIN_ROOT` without `COPILOT_CLI` (`hookSpecificOutput.additionalContext`), and falls back to the SDK-standard top-level `additionalContext`. Gated on `docs/maxi/` (silent outside a maxi project).
- `hooks/run-hook.cmd`: cross-platform polyglot wrapper for the hook scripts.

The package is validated by the fast tier (`check-plugin-manifest.sh`, `check-declarative-harnesses.sh`, `check-hermes-plugin.sh`, `check-codex-plugin.sh`, `check-hooks.sh`, `check-cursor-hooks.sh`, `check-opencode-plugin.sh`, `check-bootstrap-parity.sh`, `check-pi-extension.sh`). The bootstrap preamble is identical across the bash hook, the OpenCode plugin, and the Pi extension (parity-guarded).

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
