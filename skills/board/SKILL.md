---
name: board
description: Use when the user invokes /maxi:board or wants a kanban overview of all specs and their pipeline status in the current project
---

# board

Read-only kanban view of all specs under `docs/maxi/specs/`. Scans frontmatter, groups by status, and prints to the terminal. **Writes nothing.**

## Execution Steps

### Step 1 — Locate Specs

Find all `spec.md` files: `docs/maxi/specs/*/spec.md`. If `docs/maxi/specs/` is absent or empty, print:

> *"No specs found at docs/maxi/specs/. Run /maxi:specify to create your first spec."*

...and stop.

### Step 2 — Parse Each Spec

Read each spec's YAML frontmatter and body. Extract:
- `slug` from frontmatter (fallback: directory name)
- `status` from frontmatter (fallback: group under `unknown`)
- `updated` from frontmatter (fallback: omit staleness suffix)
- Title: first `# ` H1 line in the body (fallback: use slug)

### Step 3 — Group by Status

Bucket specs into the 10 statuses. Render forward pipeline buckets first, then lifecycle buckets:

Forward buckets:

```
drafting → specified → clarified → planned → tasked → analyzed → implementing → done
```

Lifecycle buckets:

```
parked → cancelled
```

`parked` = spec frozen in progress (non-terminal, resumable via `/maxi:resume`). `cancelled` = terminal, not actionable. Specs with missing or unrecognized `status` go into a trailing `unknown` bucket.

The canonical status list is defined in `skills/specify/spec-template.md` (the `# Allowed values:` line). Specs with missing or unrecognized `status` go into a trailing `unknown` bucket.

### Step 4 — Sort Each Bucket

Within each bucket, sort by `updated` ascending (oldest first), so stale work surfaces at the top.

### Step 5 — Compute Staleness

Staleness = today's date minus `updated` in calendar days. If > 30 days, append `, stale Nd` to the entry. Skip staleness for entries missing `updated`. Skip staleness for specs at `cancelled` status — terminal status, quiet by design.

### Step 6 — Render

Print to the terminal in this format:

```
## drafting (2)
- 003-foo-feature       — Foo feature              (updated 04-10, stale 48d)
- 005-bar-feature       — Bar feature              (updated 05-25)

## specified (1)
- 001-baz               — Baz redesign             (updated 05-20)

## clarified (0)
_empty_

## planned (0)
_empty_

## tasked (0)
_empty_

## analyzed (0)
_empty_

## implementing (1)
- 004-quux              — Quux                     (updated 05-25)

## done (12) — showing 2 from last 30d
- 008-search            — Search                   (updated 05-15)
- 009-export            — Export                   (updated 05-20)

## parked (0)
_empty_

## cancelled (0)
_empty_
```

Rendering rules:
- Empty buckets print `_empty_` — never omit the heading, the pipeline shape must stay visible
- `done` heading: `## done (total) — showing K from last 30d`; body lists only entries where `updated` is within the last 30 days, oldest first; if none, print `_empty_`
- `unknown` bucket (if any): render last; flag missing field per entry, e.g. `(no status field)`
- Align `—` separators and date column within each bucket for readability
- `parked` bucket: staleness applies normally (parked specs can go stale, surfacing them for review).
- `cancelled` bucket: no staleness suffix (terminal status); entries shown with `updated` date only.

### Step 7 — Footer

Print a one-liner summary:

```
N specs across M non-empty statuses · K stale (>30d)
```

Omit `· K stale` if K = 0.

## READ-ONLY Iron Law

**Do NOT write or modify any file.** Not `spec.md`, not a `board.md`, not any artifact. This command is pure terminal output.

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.

## Red Flags

- Writing a `board.md` or any file → hard stop, this is read-only
- Omitting empty status buckets → always print all 10 headings so the pipeline shape is visible
- Listing all done specs when the project is mature → collapse to count + last-30d only
- Crashing on a spec missing `status` or `updated` → tolerate gracefully (unknown bucket / no staleness suffix)
- Silently skipping unrecognized status values → always surface them in the `unknown` bucket

## Rationalization Counters

| Rationalization | Counter |
|---|---|
| "I'll write a board.md for persistence" | READ-ONLY Iron Law. Terminal output only. No file writes. |
| "The done section is cluttered, I'll just show total count" | Show count AND last-30d entries. Recent completions signal shipping cadence. |
| "This spec has no status field, I'll infer one" | Never infer status. Group under `unknown` so the user sees the broken frontmatter. |
| "Empty sections waste space, I'll hide them" | Always print all 10 headings. Empty pipeline stages are useful information. |
| "I'll sort newest-first so recent work is visible" | Sort oldest-updated first — stale work is the highest priority to surface. |
