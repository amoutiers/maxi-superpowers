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

ADRs are captured automatically during /maxi:plan and /maxi:implement — the pipeline proposes ADRs for architectural choices and asks for your consent before writing.
```

## Artifact Locations

Per-project artifacts:

```
docs/
├── constitution.md              # project principles (mandatory before any spec work)
└── maxi/
    ├── adr/                     # Architecture Decision Records (auto-captured)
    │   ├── README.md            # auto-maintained index
    │   └── NNN-slug.md
    └── specs/
        └── NNN-feature-slug/
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

- **Constitution is mandatory.** All workflow skills (except `constitution` itself) will refuse to run if `docs/constitution.md` is missing.
- **Soft gating.** If you try to run `/maxi:tasks` when the status is `specified`, you get: *"Cannot run /maxi:tasks — current spec status is `specified`. Run `/maxi:clarify` or `/maxi:plan` first."*
- **Some phases accept the previous.** `/maxi:plan` accepts both `specified` and `clarified` (with a warning if `specified`). `/maxi:implement` accepts both `tasked` and `analyzed`.

## Vendored Superpowers Skills

maxi bundles superpowers skills. They're available as `maxi:<skill>` (e.g., `maxi:brainstorming`, `maxi:writing-plans`, `maxi:executing-plans`, `maxi:test-driven-development`). You do not need a separate superpowers installation.

## Getting Started

**Migrating from github-spec-kit?** Run `/maxi:migrate-from-speckit` first — it copies your existing specs and constitution into the maxi layout, non-destructively.

1. Run `/maxi:constitution` to establish your project's principles.
2. Run `/maxi:specify "your feature description"` to start a new spec.
3. Follow the pipeline from there. Each skill tells you what comes next.

## Key Rules

- Never skip the constitution step.
- Never hand-edit the `status:` frontmatter — let skills manage it.
- Every skill that mutates an artifact bumps its `updated:` field to today's ISO date.
- `/maxi:analyze` is read-only. It writes `analysis.md` but never modifies source artifacts.
- The `analyze` skill requires constitution to be present — constitution principles inform 2 of the 7 audit passes.
- ADRs are append-only. To revise a past decision, create a new ADR that supersedes the old one.
- Existing specs that predate the `updated:`, `spec_slug:`, or `decider:` fields will not have them — skills should tolerate absent optional fields rather than failing.
