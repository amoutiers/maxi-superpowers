---
name: migrate-adr
description: Use when the user invokes /maxi:migrate-adr or wants to bootstrap a project's maxi ADR log — imports existing ADR files (Nygard, MADR, plain Markdown) and/or discovers undocumented architectural decisions from source code, config files, manifests, and git history
user-invocable: true
---

# migrate-adr

## Overview

Bootstraps `docs/maxi/adr/` from two parallel subagents:

1. **Importer** — scans known ADR directories, detects Nygard/MADR/plain-Markdown format, converts to maxi format
2. **Discoverer** — analyzes manifests, config files, directory structure, and git history to surface undocumented decisions

Non-destructive: originals are never deleted or moved. Standalone: no spec status required. `--import-only` skips the Discoverer.

**Trigger:** `/maxi:migrate-adr [--import-only]`

---

## Iron Rule: Never Write Without Consent

**Show every proposed ADR draft to the user and wait for explicit approval before writing any file. No exceptions.**

Rationalizations that are NEVER valid:

| Rationalization | Reality |
|----------------|---------|
| "The source format made the decision clear" | Still show draft. Still ask. |
| "The user already ran this command" | Still show draft. Still ask. |
| "Discovery produced too many proposals" | Show each one individually. Still ask. |
| "The user said 'go ahead'" | That applies only to the proposals already shown. Still ask per draft. |

---

## Process

```dot
digraph migrate_adr {
    "Check constitution" [shape=diamond];
    "STOP: run /maxi:constitution first" [shape=box];
    "Read exclusion context from docs/maxi/adr/*.md" [shape=box];
    "Dispatch subagents in parallel" [shape=box];
    "Subagent A: Importer" [shape=box];
    "Subagent B: Discoverer\n(skip if --import-only)" [shape=box];
    "Collect + deduplicate proposals" [shape=box];
    "Nothing to propose?" [shape=diamond];
    "Report: nothing found, exit" [shape=box];
    "Display summary table" [shape=box];
    "Consent gate: next proposal?" [shape=diamond];
    "Show full draft + ask yes/no/edit" [shape=box];
    "Accept amendments inline" [shape=box];
    "Write ADR + regenerate README.md" [shape=box];
    "Discard (discovered)" [shape=box];
    "Write as deprecated (imported)" [shape=box];
    "Done" [shape=box];

    "Check constitution" -> "STOP: run /maxi:constitution first" [label="missing"];
    "Check constitution" -> "Read exclusion context from docs/maxi/adr/*.md" [label="exists"];
    "Read exclusion context from docs/maxi/adr/*.md" -> "Dispatch subagents in parallel";
    "Dispatch subagents in parallel" -> "Subagent A: Importer";
    "Dispatch subagents in parallel" -> "Subagent B: Discoverer\n(skip if --import-only)";
    "Subagent A: Importer" -> "Collect + deduplicate proposals";
    "Subagent B: Discoverer\n(skip if --import-only)" -> "Collect + deduplicate proposals";
    "Collect + deduplicate proposals" -> "Nothing to propose?";
    "Nothing to propose?" -> "Report: nothing found, exit" [label="yes"];
    "Nothing to propose?" -> "Display summary table" [label="no"];
    "Display summary table" -> "Consent gate: next proposal?";
    "Consent gate: next proposal?" -> "Show full draft + ask yes/no/edit" [label="yes"];
    "Show full draft + ask yes/no/edit" -> "Write ADR + regenerate README.md" [label="yes"];
    "Show full draft + ask yes/no/edit" -> "Accept amendments inline" [label="edit"];
    "Accept amendments inline" -> "Write ADR + regenerate README.md";
    "Show full draft + ask yes/no/edit" -> "Discard (discovered)" [label="no (discovered)"];
    "Show full draft + ask yes/no/edit" -> "Write as deprecated (imported)" [label="no (imported)"];
    "Write ADR + regenerate README.md" -> "Consent gate: next proposal?";
    "Discard (discovered)" -> "Consent gate: next proposal?";
    "Write as deprecated (imported)" -> "Consent gate: next proposal?";
    "Consent gate: next proposal?" -> "Done" [label="no more"];
}
```

---

## Step 1 — Prerequisites

Check `docs/maxi/constitution.md` exists.

- **Missing:** Stop immediately. Output: *"No constitution found. Run `/maxi:constitution` first."*
- **Present:** Continue.

---

## Step 2 — Read Exclusion Context

If `docs/maxi/adr/` exists and contains `NNNN-*.md` files: read each one and extract domain labels (primary technology/category) from titles and Decision sections.

Matching is case-insensitive substring: a new proposal's domain label matches an exclusion entry if either contains the other as a substring (e.g., "Tokio" matches "Use Tokio for async runtime").

Pass this exclusion list to both subagents. Neither subagent may propose a domain already in the list.

---

## Step 3 — Dispatch Subagents in Parallel

Use `maxi:dispatching-parallel-agents`. Pass exclusion context to both. With `--import-only`, dispatch only Subagent A.

### Subagent A — Importer

Scan these directories for `.md` files:
`doc/adr/`, `docs/adr/`, `docs/decisions/`, `docs/architecture/`, `adr/`, `ADRs/`

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
| `date:` | `date:` frontmatter |
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
date: [preserved from source, or "[unknown]" if not found]
updated: [today]
related_specs: []
related_principles: []
related_requirements: []
supersedes: null
superseded_by: null
```

### Subagent B — Discoverer

Analyze these layers:

| Layer | Examples |
|-------|---------|
| Package manifests | `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `requirements.txt`, `pom.xml`, `build.gradle` |
| Config files | `Dockerfile`, `docker-compose.yml`, `.github/workflows/`, `.gitlab-ci.yml`, `tsconfig.json`, `eslint.config.*`, `.prettierrc`, `.env.example` |
| Directory structure | monorepo vs. polyrepo, layered/hexagonal/feature-based layout, test strategy |
| Git history | `git log -200 --format="%H %s%n%b"` — scan the output for commits whose subject OR body contains any of: `chose`, `decided`, `switched`, `migrated`, `replaced`, `adopted`, `dropped`, `moved to`; the full message body is already available in the output |

Skip domains in exclusion context.

**Default frontmatter for all discovered ADRs:**

```yaml
decider: "[unknown — inferred from code analysis]"
related_specs: []
related_principles: []
related_requirements: []
supersedes: null
superseded_by: null
date: [today]
updated: [today]
```

Mark uncertain fields with `[inferred]` prefix.

---

## Step 4 — Collect and Deduplicate

For each proposal, identify its primary domain label.

If Importer and Discoverer both propose the same domain:
- **Imported draft wins** as the base.
- Append discovery evidence to imported draft's `## Context` under `### Additional evidence`.
- Drop the discovered proposal.

When uncertain whether two proposals share a domain: **keep both**.

Import-only and discover-only proposals are kept as-is.

---

## Step 5 — Display Summary Table

```
Found N imported ADRs + M discovered decisions (K already covered by existing ADRs).

| #  | Source    | Topic                        | Tentative ADR |
|----|-----------|------------------------------|---------------|
|  1 | import    | PostgreSQL as primary store  | ADR-0003 (t)  |
|  2 | discover  | TypeScript strict mode       | ADR-0004 (t)  |
(t) = tentative number, assigned at write time
```

If nothing to propose: output *"Nothing to migrate and no architectural decisions detected. Use `/maxi:adr` to record decisions manually."* — exit cleanly.

---

## Step 6 — Consent Gate (One Proposal at a Time)

Process imported proposals first, then discovered proposals.

For each proposal: show the **full draft** and ask:

**Imported:**
> *"Import this as ADR-NNNN? (yes / no = import as deprecated / edit)"*

| Response | Action |
|----------|--------|
| `yes` | Write with `status: accepted` |
| `no` | Write with `status: deprecated` (the historical decision is preserved even when you decline to adopt it — you can always supersede it later with `/maxi:adr`) |
| `edit` | Accept amendments inline, write with `status: accepted` |

**Discovered:**
> *"Record this as ADR-NNNN? (yes / no = discard / edit)"*

| Response | Action |
|----------|--------|
| `yes` | Write with `status: accepted` |
| `no` | Discard — no file written |
| `edit` | Accept amendments inline, write with `status: accepted` |

**Ambiguous responses** ("ok", "sure", "looks good", "cancel", "skip", silence): treat as `no`. Re-ask once with a context-specific prompt:

- For **imported** proposals: *"To confirm: import as ADR-NNNN with status deprecated? (yes to import as deprecated / no to discard entirely)"*
- For **discovered** proposals: *"To confirm: skip recording this decision? (yes to record / no to discard)"*

If still ambiguous: treat as `no`.

**NNNN is computed from the current max in `docs/maxi/adr/` at write time** — not at proposal time.

After each write: regenerate `docs/maxi/adr/README.md` as a table with columns: ADR number, title, status, date, related specs.

---

## Guards

| Condition | Behaviour |
|-----------|-----------|
| No `docs/maxi/constitution.md` | Stop: *"No constitution found. Run `/maxi:constitution` first."* |
| No ADRs found + no codebase signals | Report + exit cleanly |
| Importer finds nothing | Report; Discoverer still runs (unless `--import-only`) |
| Discoverer finds nothing | Report; Importer results still presented |
| Unsupported file format | Skip with warning, continue |
| `docs/maxi/adr/` non-empty | Read first → build exclusion context; then append new ADRs |
| `--import-only` flag | Subagent B not dispatched |

---

## Out of Scope

- Deleting or moving original ADR files
- Migrating ADRs between two maxi projects
- Bulk-accepting all proposals without consent
- Retroactively editing existing `docs/maxi/adr/` files (append-only)

---

## Common Mistakes

| Mistake | Correct behaviour |
|---------|-------------------|
| Writing any file before showing the draft | Always show draft first, wait for yes/no/edit |
| Skipping a proposal without asking | Every proposal must go through the consent gate |
| Treating "ok" or silence as yes | Ambiguous = no; re-ask once |
| Computing NNNN at proposal time | Compute NNNN from current max **at write time** |
| Forgetting to regenerate README.md | Regenerate after every write |
| Proposing a domain already in exclusion context | Check exclusion list before proposing |
| Dispatching subagents without exclusion context | Pass exclusion list to both A and B |
