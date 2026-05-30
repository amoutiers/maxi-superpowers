# maxi-superpowers

![maxi-superpowers](assets/logo.svg)

A spec-driven workflow plugin that combines structured feature design (spec-kit) with superpowers' battle-tested implementation engine. You write features through a structured pipeline — constitution, spec, clarification, plan, tasks, analysis, implementation — and maxi enforces phase gating so nothing ships without the artifacts to back it.

## Installation

### For Claude Code
```bash
# From the plugin marketplace (plugin name: maxi):
claude plugin install maxi

# Or install locally:
git clone https://github.com/amoutiers/maxi-superpowers
cd maxi-superpowers
claude plugin install .
```

### For Antigravity CLI
```bash
# Install locally:
git clone https://github.com/amoutiers/maxi-superpowers
cd maxi-superpowers
agy plugin install .

# Or import your legacy Gemini extensions:
agy plugin import gemini
```

### For OpenCode
Add to your `opencode.json`:
```json
{
  "plugin": ["maxi-superpowers@git+https://github.com/amoutiers/maxi-superpowers.git"]
}
```
Then restart OpenCode. See [`.opencode/INSTALL.md`](.opencode/INSTALL.md) for details.

### For Legacy Gemini CLI
```bash
# Install from the GitHub repository:
gemini extensions install https://github.com/amoutiers/maxi-superpowers

# Or install locally:
git clone https://github.com/amoutiers/maxi-superpowers
cd maxi-superpowers
gemini extensions install .
```

## Pipeline Commands

| Command | Description |
|---|---|
| `/maxi:constitution` | Establish or amend project principles — required before any other command |
| `/maxi:specify` | Create a new feature spec via guided design dialogue |
| `/maxi:clarify` | Resolve open questions in a spec before planning |
| `/maxi:plan` | Generate a technical implementation plan from the spec |
| `/maxi:tasks` | Extract a structured checkbox task list from the plan |
| `/maxi:analyze` | Run a 7-pass quality audit across all artifacts (includes ADR alignment) |
| `/maxi:implement` | Execute the task list and transition the spec to `done` |

## Quick Start

```
1. /maxi:constitution        → creates docs/maxi/constitution.md
2. /maxi:specify <feature>   → creates docs/maxi/specs/001-feature/spec.md  (status: specified)
3. /maxi:clarify             → resolves open questions                   (status: clarified)
4. /maxi:plan                → writes plan.md                            (status: planned)
5. /maxi:tasks               → writes tasks.md                           (status: tasked)
6. /maxi:analyze             → writes analysis.md                        (status: analyzed)
7. /maxi:implement           → executes tasks, code review, done         (status: done)
```

Each command reads the previous artifacts and refuses to run if the spec is in the wrong phase.

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

maxi-superpowers vendors [superpowers v5.1.0](https://github.com/obra/superpowers) via git subtree. All superpowers skills are available as `maxi:<skill>` (e.g., `/maxi:brainstorming`, `/maxi:writing-plans`, `/maxi:test-driven-development`). The pipeline skills delegate to them at the right moments — you don't invoke them directly.

## Onboarding an existing project

maxi has three **non-destructive** paths to adopt spec-driven development on a codebase that already exists. Establish principles first with `/maxi:constitution` (or let `/maxi:migrate-from-speckit` bring yours over), then use whichever paths fit:

- **From [github-spec-kit](https://github.com/github/spec-kit)** — `/maxi:migrate-from-speckit` does a one-shot migration: copies specs to `docs/maxi/specs/`, adds YAML frontmatter, infers status, and migrates your constitution. Originals in `specs/` and `.specify/` are never touched.
- **From code with no specs (brownfield)** — `/maxi:migrate-from-brownfield` reverse-engineers your existing code into faithful `spec.md` baselines (status `done`, marked `origin: reverse-engineered`), every functional requirement carrying a `file:line` reference. It discovers feature boundaries, lets you select which to document (in waves), drafts an as-built spec per boundary, and adversarially verifies each draft against the code before you accept it.
- **Bootstrapping the ADR log** — `/maxi:migrate-adr` imports existing ADRs (Nygard / MADR / plain Markdown) and/or discovers undocumented architectural decisions from your code, config, and git history.

These compose. A typical brownfield onboarding is:

```
/maxi:constitution           → establish principles
/maxi:migrate-from-brownfield → reverse-engineer code into spec baselines
/maxi:migrate-adr            → capture/discover the ADR log
```

Reverse-engineered baselines land at `done`; to change a documented feature later, run `/maxi:revise` on its spec to roll it back into the forward pipeline.

## Contributing

See [CLAUDE.md](CLAUDE.md) for contributor guidelines. Key rules:

- All new skills must be authored via `superpowers:writing-skills` — do not hand-write SKILL.md files.
- Do not hand-edit files under `skills/` that originate from superpowers. Run `scripts/sync-superpowers.sh` to re-sync after a version bump.
- Run `bash tests/run-all.sh` before committing — all checks must pass.

## License

MIT
