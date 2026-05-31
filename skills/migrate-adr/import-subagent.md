# migrate-adr — Importer brief

> Dispatched by `migrate-adr/SKILL.md` (Step 3). Owns one responsibility: detect and convert
> existing ADR files into maxi format. Receives the exclusion context from the orchestrator;
> returns proposals in the orchestrator's Return schema. No consent/dedup logic here.

Scan these directories for `.md` files:
`doc/adr/`, `docs/adr/`, `docs/decisions/`, `docs/architecture/`, `adr/`, `ADRs/`

**Filename blocklist (skip before format detection):** ignore any file whose basename (case-insensitive) is `README.md`, `index.md`, `template.md`, or `CONTRIBUTING.md`. These are not ADRs; without the blocklist a project `README.md` would be imported via the Plain-Markdown catch-all. Do **not** use a subjective "does the H1 look like a decision" heuristic — the blocklist plus the format-detection table below is the filter.

**Detect format per file:**

| Format | Signal |
|--------|--------|
| Nygard | No YAML frontmatter; has `## Status`, `## Context`, `## Decision`, `## Consequences` |
| MADR | YAML frontmatter with `title:`, `status:`, `deciders:` |
| Plain Markdown | H1 title; doesn't match Nygard or MADR |

Skip files matching no format (warn, continue). Skip files whose domain is in exclusion context.

**Nygard → maxi mapping:**

| Nygard field | maxi field |
|---|---|
| H1 title | slug + ADR title line |
| `## Status` value | `status:` frontmatter (Accepted→`accepted`, Proposed→`proposed`, Deprecated→`deprecated`, Superseded→`superseded`, Rejected→`deprecated`) |
| `## Context` | `## Context` |
| `## Decision` | `## Decision` |
| `## Consequences` | `## Consequences` |
| *(missing)* | `## Decision Drivers` — *"Not recorded in source ADR. Add drivers before accepting."* |
| *(missing)* | `## Considered Options` — *"Not recorded in source ADR."* |
| *(missing)* | `## Confirmation` — *"Not recorded in source ADR."* |

Nygard supersession: if `## Status` contains "Supersedes ADR-NNN", set `supersedes: null` in frontmatter and append to `## Context`: *"Source ADR referenced supersession — review and update `supersedes:` manually."*

**MADR → maxi mapping:**

| MADR field | maxi field |
|---|---|
| `title:` | slug + ADR title line |
| `status:` | `status:` frontmatter |
| `deciders:` | `decider:` frontmatter |
| `date:` | `created:` frontmatter |
| Context and Problem Statement | `## Context` |
| Decision Drivers | `## Decision Drivers` |
| Considered Options + Pros/Cons | `## Considered Options` |
| Decision Outcome | `## Decision` |
| Consequences subsection | `## Consequences` |
| *(missing)* | `## Confirmation` — placeholder |

**Plain Markdown:** Extract H1 as title. Look for date in filename (`YYYYMMDD-*` or `YYYY-MM-DD-*`) or first paragraph. Map body verbatim to `## Context`. All other sections → placeholders using the following explicit text:

- `## Decision Drivers` → *"Not recorded in source document. Add drivers before accepting."*
- `## Considered Options` → *"Not recorded in source document."*
- `## Decision` → *"Not recorded in source document."*
- `## Consequences` → *"Not recorded in source document."*
- `## Confirmation` → *"Not recorded in source document."*

**Frontmatter invariants for all imported ADRs:**

```yaml
created: [preserved from source, or "[unknown]" if not found]
updated: [today]
source: [original file path the ADR was imported from, or "[unknown]" if undeterminable]
supersedes: null
superseded_by: null
```

The `source:` field records provenance so every imported ADR points back at its original file.
