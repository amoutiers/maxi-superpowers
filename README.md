# maxi-superpowers

A Claude Code plugin that combines a spec-driven workflow (spec-kit) with superpowers' battle-tested implementation engine. You write features through a structured pipeline — constitution, spec, clarification, plan, tasks, analysis, implementation — and maxi enforces phase gating so nothing ships without the artifacts to back it.

## Prerequisites

- [Claude Code](https://claude.ai/code) with plugin support

## Installation

```bash
# From the plugin marketplace (once published):
claude plugin install maxi-superpowers

# Or install locally:
git clone https://github.com/amoutiers/maxi-superpowers
cd maxi-superpowers
claude plugin install .
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
1. /maxi:constitution        → creates docs/constitution.md
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
  constitution.md          # project principles (required by all skills)
  maxi/
    adr/                   # Architecture Decision Records (auto-captured during plan + implement)
      README.md            # auto-maintained index
      001-slug.md          # NNN-slug.md format
    specs/
      001-my-feature/
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

maxi-superpowers vendors [superpowers v5.1.0](https://github.com/obra/superpowers) via git subtree. All superpowers skills are available as `maxi:<skill>` (e.g., `maxi:brainstorming`, `maxi:writing-plans`, `maxi:executing-plans`). The pipeline skills delegate to them at the right moments — you don't invoke them directly.

## Contributing

See [CLAUDE.md](CLAUDE.md) for contributor guidelines. Key rules:

- All new skills must be authored via `superpowers:writing-skills` — do not hand-write SKILL.md files.
- Do not hand-edit files under `skills/` that originate from superpowers. Run `scripts/sync-superpowers.sh` to re-sync after a version bump.
- Run `bash tests/run-all.sh` before committing — all 3 checks must pass.

## License

MIT
