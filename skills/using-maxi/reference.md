# using-maxi — Reference Detail

Loaded on demand. The session-injected `SKILL.md` carries the turn-0 essentials (pipeline,
status machine, phase gating, key rules); this file holds the fuller detail that does not need
to be in every session's context.

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

## Vendored Superpowers Skills

maxi bundles superpowers skills. They're available as `maxi:<skill>` (e.g., `/maxi:brainstorming`,
`/maxi:writing-plans`, `/maxi:test-driven-development`). You do not need a separate superpowers
installation.

## Migration Entry Points

- **Migrating from github-spec-kit?** Run `/maxi:migrate-from-speckit` first — it copies your
  existing specs and constitution into the maxi layout, non-destructively.
- **Adopting maxi on an existing codebase with no specs?** Run `/maxi:migrate-from-brownfield` to
  reverse-engineer your code into `spec.md` baselines (at `status: done`, marked
  `origin: reverse-engineered`) so future changes flow through the pipeline.
- **Bootstrapping your ADR log?** Run `/maxi:migrate-adr` to import existing ADRs from other
  formats and/or discover undocumented architectural decisions from your codebase.
