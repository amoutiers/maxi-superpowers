---
name: using-maxi
description: Use at session start to understand the maxi spec-driven pipeline — phases, commands, artifact locations, and how to get started
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, skip this skill.
</SUBAGENT-STOP>

# maxi — Spec-Driven Development Pipeline

maxi grafts a structured spec-driven workflow onto superpowers' implementation engine. Every feature goes through a pipeline of phases, each gated by the previous one.

## The Pipeline

```
/maxi:constitution  →  establish project principles (REQUIRED FIRST)
/maxi:specify       →  brainstorm & write spec.md (status: specified)
/maxi:clarify       →  answer open questions in spec.md (status: clarified)
/maxi:plan          →  write plan.md + design docs (status: planned)
/maxi:tasks         →  extract tasks.md from plan (status: tasked)
/maxi:analyze       →  7-pass cross-artifact audit → analysis.md (status: analyzed)
/maxi:implement     →  execute tasks, write code (status: implementing → done)
/maxi:develop       →  dispatch subagents to implement tasks (called by /maxi:implement)
/maxi:board         →  kanban overview of all specs grouped by status (read-only)
/maxi:migrate-adr   →  import existing ADRs (Nygard/MADR/plain) + discover undocumented decisions from source code

ADRs are captured automatically during /maxi:plan and /maxi:implement — the pipeline proposes ADRs for architectural choices and asks for your consent before writing.
```

## Artifact Locations

Per-project artifacts:

```
docs/
└── maxi/
    ├── constitution.md          # project principles (mandatory before any spec work)
    ├── adr/                     # Architecture Decision Records (auto-captured)
    │   ├── README.md            # auto-maintained index
    │   └── NNNN-slug.md
    └── specs/
        └── NNNN-feature-slug/
            ├── spec.md          # status/updated/slug in YAML frontmatter
            ├── plan.md
            ├── tasks.md
            ├── analysis.md      # written by /maxi:analyze (read-only audit)
            ├── research.md
            ├── data-model.md
            └── contracts/
```

## Status State Machine

Every `spec.md` carries `status:` in its YAML frontmatter:

```
drafting → specified → clarified → planned → tasked → analyzed → implementing → done
```

Skills read and enforce this. Running a skill out of order gives a friendly message — not a crash.

## Phase Gating

- **Constitution is mandatory.** All workflow skills (except `constitution` itself) will refuse to run if `docs/maxi/constitution.md` is missing.

Each skill enforces the required status strictly:

| Skill | Required status | Tolerance | Produces |
|---|---|---|---|
| `/maxi:specify` | constitution exists | — | `specified` |
| `/maxi:clarify` | `specified` | none | `clarified` |
| `/maxi:plan` | `clarified` | none | `planned` |
| `/maxi:tasks` | `planned` | none | `tasked` |
| `/maxi:analyze` | `tasked`+ | re-run ok on `analyzed`/`implementing`/`done` | `analyzed` |
| `/maxi:implement` | `analyzed` | none | `implementing` → `done` |

Lifecycle skills act on a spec's status outside the forward flow:

| Skill | Required status | Produces |
|---|---|---|
| `/maxi:board` | any (read-only) | — |
| `/maxi:park` | any active (not `parked`/`cancelled`/`done`) | `parked` |
| `/maxi:resume` | `parked` | restores `parked_from` |
| `/maxi:cancel` | any active (not `parked`/`cancelled`/`done`) | `cancelled` |
| `/maxi:revise` | `clarified` through `implementing` | rolls back to `clarified`/`planned`/`tasked`/`analyzed` |

> **Note:** Skills are designed to be cheap when there is nothing to do. `/maxi:clarify` completes in seconds if the spec has no ambiguities. `/maxi:analyze` produces a clean report instantly if there are no issues. The discipline cost is bounded; the value is not.

## Vendored Superpowers Skills

maxi bundles superpowers skills. They're available as `maxi:<skill>` (e.g., `/maxi:brainstorming`, `/maxi:writing-plans`, `/maxi:test-driven-development`). You do not need a separate superpowers installation.

## Getting Started

**Migrating from github-spec-kit?** Run `/maxi:migrate-from-speckit` first — it copies your existing specs and constitution into the maxi layout, non-destructively.
**Bootstrapping your ADR log?** Run `/maxi:migrate-adr` to import existing ADRs from other formats and/or discover undocumented architectural decisions from your codebase.

1. Run `/maxi:constitution` to establish your project's principles.
2. Run `/maxi:specify "your feature description"` to start a new spec.
3. Follow the pipeline from there. Each skill tells you what comes next.

## Key Rules

- Never skip the constitution step.
- Never hand-edit the `status:` frontmatter — let skills manage it.
- **Invariant — `updated:` field:** Every write to a maxi artifact (`spec.md`, `plan.md`, `tasks.md`, ADR file) must include bumping its `updated:` frontmatter field to today's ISO date (`YYYY-MM-DD`) in the same operation. Never bump in a separate step.
- `/maxi:analyze` is read-only. It writes `analysis.md` but never modifies source artifacts.
- The `analyze` skill requires constitution to be present — constitution principles inform 2 of the 7 audit passes.
- ADRs are append-only. To revise a past decision, create a new ADR that supersedes the old one.
- Existing specs that predate the `updated:`, `spec_slug:`, or `decider:` fields will not have them — skills should tolerate absent optional fields rather than failing.
