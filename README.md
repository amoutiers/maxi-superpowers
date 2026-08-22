# maxi-superpowers

![maxi-superpowers](assets/logo.svg)

A spec-driven development plugin for Claude Code, Antigravity, Codex App, Codex CLI, Cursor, Devin CLI, Factory Droid, Gemini CLI, GitHub Copilot CLI, Grok Build CLI, Kimi Code, OpenCode, Pi, and Hermes Agent. Its 19 maxi-native skills turn "build me X" into a disciplined pipeline — **constitution → spec → clarify → plan → tasks → analyze → implement** — and gate each phase so nothing ships without the design artifacts to back it. Under the hood it delegates implementation to [superpowers](https://github.com/obra/superpowers) (TDD, subagents, code review).

**Why maxi?**

- **Design before code** — every feature gets a written spec, plan, and task list, not just a prompt and a diff.
- **Phase gating** — skills refuse to run out of order, so you can't skip clarification and discover the gap at implementation time.
- **Decisions are recorded** — architectural choices become ADRs automatically (with your consent), so the *why* survives.
- **Greenfield or brownfield** — start a fresh project, or reverse-engineer an existing codebase into spec baselines.

## Installation

### Supported harness surfaces

| Harness | Maxi packaging or distribution path |
|---|---|
| Claude Code | `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and gated `hooks/hooks.json` → `hooks/session-start` |
| Antigravity | Repository-root install using `.claude-plugin/plugin.json` and gated `hooks/hooks.json`; no dedicated package directory |
| Codex App | `.agents/plugins/marketplace.json` → `plugins/maxi` → `.codex-plugin/plugin.json`; native skill discovery with `hooks: {}` |
| Codex CLI | Same Codex marketplace and `.codex-plugin/plugin.json` path as the app; native skill discovery, no SessionStart hook |
| Cursor | `.cursor-plugin/plugin.json` → `skills/` plus `hooks/hooks-cursor.json` → gated `hooks/session-start` |
| Devin CLI | Metadata-only `.devin-plugin/plugin.json` |
| Factory Droid | Marketplace-only distribution path; no dedicated in-repo manifest or adapter |
| Gemini CLI | `gemini-extension.json` → declarative `GEMINI.md` imports |
| GitHub Copilot CLI | Marketplace-only distribution path using the shared root `hooks/hooks.json` → gated `hooks/session-start` |
| Grok Build CLI | Marketplace-only distribution path; no dedicated in-repo manifest or adapter |
| Kimi Code | Declarative `.kimi-plugin/plugin.json` with `sessionStart.skill: using-maxi` and inline tool mapping |
| OpenCode | `package.json` → `.opencode/plugins/maxi.js`, with executable `docs/maxi/` gating |
| Pi | `package.json` `pi` section → `.pi/extensions/maxi.ts`, gated at session start and after compaction |
| Hermes Agent | `.hermes-plugin/plugin.yaml` → `.hermes-plugin/__init__.py`, with a short gated first-turn bootstrap |

Gemini and Kimi are declarative surfaces. Their manifests cannot inspect the current working directory before loading `GEMINI.md` or `using-maxi`, so the bootstrap may load outside projects containing `docs/maxi/`. Executable adapters remain gated.

Hermes keeps its injected context below 10,000 characters by asking its native loader for `skill_view("maxi:using-maxi")` and including only the Hermes tool mapping. Hermes has no post-compaction hook; if a long session compacts away the first-turn bootstrap, start a fresh session.

### For Claude Code
```bash
# From the plugin marketplace (plugin name: maxi):
claude plugin install maxi

# Or install locally:
git clone https://github.com/amoutiers/maxi-superpowers
cd maxi-superpowers
claude plugin install .
```

### For Codex App and Codex CLI
```bash
# Install this repository as a Codex marketplace, then install the maxi plugin:
git clone https://github.com/amoutiers/maxi-superpowers
codex plugin marketplace add ./maxi-superpowers
codex plugin add maxi@maxi-superpowers
```

Codex App users can install the same `maxi` entry from the Plugins sidebar. Both Codex surfaces load the Maxi skills natively from `.codex-plugin/plugin.json`. Its empty `hooks: {}` object prevents SessionStart auto-discovery, so start by invoking the relevant skill directly (for example, ask Codex to use `maxi:constitution`).

### For Antigravity
```bash
# Install from this repository:
agy plugin install https://github.com/amoutiers/maxi-superpowers

# Or install locally:
git clone https://github.com/amoutiers/maxi-superpowers
cd maxi-superpowers
agy plugin install .
```

Antigravity runs the plugin's session-start hook (the root `hooks/hooks.json`), so maxi is active from the first message. Reinstall with the same command to update.

### For Cursor
Install from Cursor's plugin marketplace. `.cursor-plugin/plugin.json` points Cursor to the skills directory and `hooks/hooks-cursor.json`; the hook emits Cursor's `additional_context` shape.

### For OpenCode
Add to your `opencode.json`:
```json
{
  "plugin": ["maxi-superpowers@git+https://github.com/amoutiers/maxi-superpowers.git"]
}
```
Then restart OpenCode. See [`.opencode/INSTALL.md`](.opencode/INSTALL.md) for details.

### For Pi
Install maxi as a Pi package from this repository:
```bash
pi install git:github.com/amoutiers/maxi-superpowers
```

For local development, run Pi with this checkout loaded as a temporary package:
```bash
pi -e /path/to/maxi-superpowers
```

### For Devin CLI, Gemini CLI, Kimi Code, and Hermes Agent

These repository installs consume the dedicated surfaces listed above:

```bash
devin plugins install amoutiers/maxi-superpowers
gemini extensions install https://github.com/amoutiers/maxi-superpowers
hermes plugins install amoutiers/maxi-superpowers --enable
```

These commands follow the repository-install forms exposed by the v6.3 harness model. This update validates the local packaging surfaces, not a live remote install.

For Kimi Code, open `/plugins` and install from its marketplace, or install this repository with `/plugins install https://github.com/amoutiers/maxi-superpowers`. Start a fresh session after changing the Kimi plugin.

### For Factory Droid, GitHub Copilot CLI, and Grok Build CLI

These remain marketplace-only distribution paths. This repository has no dedicated Maxi manifest for them; use the corresponding harness marketplace. Marketplace publication is external and is not verified by this repository's fast tier.

## Start here

- **New project?** Follow the [Quick Start](#quick-start) below — `/maxi:constitution`, then `/maxi:specify <feature>`.
- **Existing codebase?** Jump to [Onboarding an existing project](#onboarding-an-existing-project) — migrate your spec-kit specs, or reverse-engineer your code into spec baselines.

You don't have to memorize commands: describe what you want and maxi routes you to the right skill, or type the `/maxi:*` command explicitly. A constitution is required before the pipeline and the brownfield/ADR migrations, so **run `/maxi:constitution` first** — with one exception: spec-kit migrants run `/maxi:migrate-from-speckit`, which brings their existing constitution over.

## Quick Start

Your first feature, end to end:

```
/maxi:constitution                         # one-time: establish your project's principles
/maxi:specify add email + password login   # start a spec via guided Q&A      (→ specified)
/maxi:clarify                              # answer any open questions         (→ clarified)
# internal x-review persists the fresh specification review handoff
/maxi:plan                                 # technical plan + ADR proposals    (→ planned)
# internal x-review persists the fresh plan review handoff
/maxi:tasks                                # checkbox task list                (→ tasked)
/maxi:analyze                              # 7-pass quality audit              (→ analyzed)
/maxi:implement                            # TDD execution + code review       (→ done)
```

Each command reads the previous artifacts and refuses to run if the spec is in the wrong phase — so the path is hard to get wrong. Artifacts land in `docs/maxi/` (see [Artifact Structure](#artifact-structure)).

## Pipeline Commands

Full reference for the forward pipeline:

| Command | Description |
|---|---|
| `/maxi:constitution` | Establish or amend project principles — required before any other command |
| `/maxi:specify` | Create a new feature spec via guided design dialogue |
| `/maxi:clarify` | Resolve open questions in a spec before planning |
| `/maxi:plan` | Generate a technical implementation plan from the spec |
| `/maxi:tasks` | Extract a structured checkbox task list from the plan |
| `/maxi:analyze` | Run a 7-pass quality audit across all artifacts (includes ADR alignment) |
| `/maxi:implement` | Execute the task list and transition the spec to `done` |

> Beyond the forward pipeline there are lifecycle commands (`/maxi:board`, `/maxi:park`, `/maxi:resume`, `/maxi:cancel`, `/maxi:revise`) and the migration utilities covered under [Onboarding an existing project](#onboarding-an-existing-project).

## Independent Review Handoffs and Bounded Replay

`/maxi:x-develop` maps canonical Maxi `TNNN` tasks to an immutable SDD `Task N` projection. Upstream SDD owns task review, fix rounds, and the final implementation review. `/maxi:x-develop` is the sole incremental Maxi checkbox owner; `/maxi:implement` validates that every task is checked and alone persists `implementing → done`. Branch finishing starts only after Maxi has recorded `done`.

For marker-bound newly versioned forward artifacts, a current approved `reviews/spec-review.md` gates `/maxi:plan`, and a current approved `reviews/plan-review.md` gates `/maxi:tasks`. The public owner invokes internal `x-review` automatically; the user never invokes it or provides `yes` for it. It delegates each fresh external review, verifies reviewer independence, then makes the approved record persisted and versioned.

These review handoffs are gates, not statuses or automatic replay phases. The 10-state FSM remains unchanged. When an owner changes a versioned artifact, the read-only `skills/revise/replay-plan.sh` planner can calculate the shortest stale-descendant continuation and stop it at the next review handoff; it never writes artifacts, creates or approves reviews, or executes phases.

Bounded replay is future-only. Eligible roots carry exactly one `replay_contract: bounded-v1`; only `/maxi:specify` writes this marker, during normal forward-spec creation. An unmarked existing, migrated, or reverse-engineered spec returns `UNSUPPORTED_LEGACY`; revision metadata alone never opts it in.

For a marker-bound root, `reviewed_sha256` hashes the canonical structural projection, which omits only root-frontmatter `status:` and `updated:`, preserves every other line in order, and hashes one LF after each retained line. The exact ten-field review envelope is `revision`, `writer_context`, `structural_contributors`, `derived_from`, `reviewed_document`, `reviewed_revision`, `reviewed_sha256`, `reviewer_context`, `reviewer_context_matches_harness`, and `verdict`. Before delegation, artifact write, or status/timestamp change, `plan` and `tasks` require positive record and reviewed revisions, exactly one mapped direct input, the exact current subject/revision/digest, canonical unique contributors and contexts, writer equals reviewer and appears in contributors, harness equality exactly `true`, verdict exactly `approved`, and reviewer independence from the subject contributors.

The persisted continuation is `replay_continuation: clarify@<current-spec-revision>` after the exceptional source rollback; `/maxi:clarify` can re-present it with `--resume-current-source` after rejection, ambiguity, or interruption. `--resume-current-source` is legal only for `spec.md`, start phase `clarify`, and that matching current marker. Clarification replaces it with `replay_continuation: plan@<current-spec-revision>`. After `x-review` writes the matching spec review, `/maxi:plan` can re-present the spec review continuation with `--resume-current-review`; a consented plan write persists `replay_continuation: tasks@<current-plan-revision>`. After the matching plan review, `/maxi:tasks` can re-present the plan review continuation with `--resume-current-review`. `--resume-current-review` accepts exactly two combinations: `reviews/spec-review.md` with `plan`, or `reviews/plan-review.md` with `tasks`; both require the current subject and review plus every transitive `derived_from` ancestor. Each displayed executable segment requires its own fresh literal `yes`.

Before plan resume, a stale `spec.md`, support artifact, or specification review is rejected before any continuation output or write, even when `plan.md` and its plan review still match.

An explicit owner-managed plan correction is available only when explicitly requested at `planned`, `tasked`, `analyzed`, or `implementing`; it preserves the current spec-review gate, writes `replay_continuation: tasks@<current-plan-revision>` with the corrected plan, and returns only to `planned`. An explicit owner-managed tasks correction is available only when explicitly requested at `tasked`, `analyzed`, or `implementing`; it preserves the current plan-review gate and returns only to `tasked`. After `x-review` writes a marker-bound approved plan review, it immediately invokes the read-only planner with the predecessor review revision and displays the current approved `tasks -> analyze` continuation. `x-review` never executes a phase or obtains consent. For that marker-bearing corrected plan, `/maxi:tasks` is only the later no-write resume presenter: it invokes the read-only planner with `--resume-current-review`, redisplays that continuation, and requires a fresh literal `yes` before extraction. Rejection, ambiguity, or session interruption changes nothing and the same current review can be presented again.

Only new specs created through the normal forward pipeline receive this revision and replay behavior; existing, migrated, and reverse-engineered specs remain untouched. For an unmarked root, plan and tasks use the ordinary pipeline: no review record, x-review handoff, review provenance, review reporting, or replay planner is required. This mechanism never creates or writes `workflow.md` or `.maxi-ops`.

`/maxi:revise` offers the exceptional `specified` rollback only for a demonstrated source-spec gap. The resulting replay begins at `clarify` and never reruns `specify`.

## Artifact Structure

```
docs/
  maxi/
    constitution.md        # project principles (required by all skills)
    adr/                   # Architecture Decision Records (auto-captured during plan + implement)
      README.md            # auto-maintained index
      0001-slug.md         # NNNN-slug.md format
    specs/
      0001-my-feature/
        spec.md            # requirements, user stories, success criteria
        plan.md            # technical design and approach
        reviews/
          spec-review.md   # persisted external review of the current specification revision
          plan-review.md   # persisted external review of the current plan revision
        tasks.md           # checkbox task list extracted from plan
        analysis.md        # 7-pass quality audit output
```

## Architecture Decision Records

ADRs are captured automatically — you don't create them manually. During `/maxi:plan`, the skill scans the produced plan for architectural choices (tech stack, storage, framework) and proposes an ADR for each. During `/maxi:implement`, unplanned forks that surface mid-implementation also trigger a proposal. In both cases you see the full draft and choose yes/no/edit before anything is written.

ADRs are append-only: once accepted, only status/supersede fields can change. To revise a decision, create a new ADR that supersedes the old one. `/maxi:analyze` includes a Pass G that cross-checks ADRs against the constitution and each other.

## Status State Machine

Every `spec.md` carries a `status:` field in its YAML frontmatter. Skills enforce this order:

```
drafting → specified → clarified → planned → tasked → analyzed → implementing → done
```

Skipping or reversing a status is blocked by the skill that owns each transition.

## Vendored Superpowers Skills

maxi-superpowers vendors [superpowers v6.3.0](https://github.com/obra/superpowers) via git subtree. All superpowers skills are available as `maxi:<skill>` (e.g., `/maxi:brainstorming`, `/maxi:writing-plans`, `/maxi:test-driven-development`). The pipeline skills delegate to them at the right moments — you don't invoke them directly.

## Onboarding an existing project

Two **non-destructive** paths bring an existing project onto maxi, depending on what you already have:

- **You use [github-spec-kit](https://github.com/github/spec-kit)** — `/maxi:migrate-from-speckit` does a one-shot migration: it copies your specs to `docs/maxi/specs/`, adds YAML frontmatter, infers status, and brings your constitution over. Originals in `specs/` and `.specify/` are never touched. (No separate `/maxi:constitution` needed — this provides it.)
- **You have code but no specs (brownfield)** — first run `/maxi:constitution` to establish principles (**required** — the next step refuses to run without it), then `/maxi:migrate-from-brownfield` reverse-engineers your code into faithful `spec.md` baselines (status `done`, `origin: reverse-engineered`), every requirement carrying a `file:line` reference. It discovers feature boundaries, lets you select which to document in waves, drafts an as-built spec per boundary, and adversarially verifies each draft against the code before you accept it.

After **either** path, optionally run `/maxi:migrate-adr` to bootstrap your ADR log — it imports existing ADRs (Nygard / MADR / plain Markdown) and discovers undocumented architectural decisions from your code, config, and git history.

Reverse-engineered baselines land at `done`; to change a documented feature later, run `/maxi:revise` on its spec to roll it back into the forward pipeline.

## Contributing

See [AGENTS.md](AGENTS.md) for contributor guidelines. Key rules:

- All new skills must be authored via `superpowers:writing-skills` — do not hand-write SKILL.md files.
- Do not hand-edit files under `skills/` that originate from superpowers. Run `scripts/sync-superpowers.sh` to re-sync after a version bump.
- Run `bash tests/run-all.sh` before committing — all checks must pass.

## License

MIT
