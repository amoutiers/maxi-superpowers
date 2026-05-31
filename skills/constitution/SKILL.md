---
name: constitution
description: Use when the user invokes /maxi:constitution, wants to establish or amend project principles, or when docs/maxi/constitution.md does not yet exist and needs to be created
---

# constitution

Establish or amend the project constitution — the non-negotiable principles that all future `/maxi:*` skills will check against.

**Constitution is the mandatory first step.** All other maxi workflow skills (`/maxi:specify`, `/maxi:plan`, `/maxi:analyze`, etc.) will refuse to run until `docs/maxi/constitution.md` exists.

## Canonical Locations

| What | Where |
|------|-------|
| Constitution file | `<project-root>/docs/maxi/constitution.md` |
| Template | `constitution-template.md` (in this skill's directory) |

**Never put the constitution in the project root, `docs/constitution.md`, or any other path.** It must be at `docs/maxi/constitution.md` exactly — that is the path every downstream skill checks.

## Process

```dot
digraph constitution {
    "Check docs/maxi/constitution.md" [shape=diamond];
    "Load existing, show principles" [shape=box];
    "Amend or confirm?" [shape=diamond];
    "Copy template to docs/maxi/constitution.md" [shape=box];
    "Elicit principles via Q&A" [shape=box];
    "Write/update constitution.md" [shape=box];
    "Verify file exists, summarize" [shape=box];
    "Tell user: ready for /maxi:specify" [shape=box];

    "Check docs/maxi/constitution.md" -> "Load existing, show principles" [label="exists"];
    "Check docs/maxi/constitution.md" -> "Copy template to docs/maxi/constitution.md" [label="missing"];
    "Load existing, show principles" -> "Amend or confirm?";
    "Amend or confirm?" -> "Elicit principles via Q&A" [label="amend"];
    "Amend or confirm?" -> "Tell user: ready for /maxi:specify" [label="confirm"];
    "Copy template to docs/maxi/constitution.md" -> "Elicit principles via Q&A";
    "Elicit principles via Q&A" -> "Write/update constitution.md";
    "Write/update constitution.md" -> "Verify file exists, summarize";
    "Verify file exists, summarize" -> "Tell user: ready for /maxi:specify";
}
```

## Elicitation Protocol

Ask one question at a time. Elicit 3–7 principles. Stop at 7.

**Core Principles (non-negotiable invariants)** — ask:
- "What is the single most important constraint this project must never violate?"
- "If a new developer breaks this rule, what should they be told?"
- "What trade-off has your team made that might surprise an outsider?"
- If an answer names a specific technology or a reversible choice, note that it is an architectural decision for an ADR (the pipeline captures these via `/maxi:x-adr` during `/maxi:plan`/`/maxi:implement` — not here) and steer the principle toward the underlying invariant instead.

**Development Conventions (preferred practices)** — ask:
- "What's your testing philosophy? TDD, test-after, integration-focused?"
- "Any strong preferences on code style, language version, or framework usage?"

**Constraints (external requirements)** — ask:
- "Any compliance, security, or deployment requirements that constrain the design?"
- "Third-party dependencies that are locked in or forbidden?" (A dependency *mandated* or *banned* with no real alternative is a Constraint; one *chosen* among viable options is a decision → ADR, not the constitution.)

## Critical Rules

- **Template check first.** Before copying the template, verify `constitution-template.md` exists (Read tool); if missing, stop: *"Cannot proceed — `constitution-template.md` is missing. Please reinstall the maxi plugin."*
- **Copy template first.** When creating a new constitution, copy `constitution-template.md` into `docs/maxi/constitution.md` before writing anything. Use the template's section structure. After elicitation, set the YAML frontmatter: `version: 1.0.0`, `created: [today's ISO date]`, `updated: [today's ISO date]`. When amending, bump the version (MAJOR.MINOR.PATCH) and set `updated` to today.
- **Elicit, don't generate.** Never write principles before the user has answered elicitation questions. This applies even if: (a) the user says they're in a hurry, (b) the user says to use "reasonable defaults", (c) the user points to an existing file like `CLAUDE.md` or `README.md`, or (d) the user says to infer from the codebase. In every case, ask the elicitation questions first and write only from the user's answers.
- **CLAUDE.md is not a constitution.** If the user says "use my CLAUDE.md" or points to any existing file, explain that the constitution must follow the template format and be verified through elicitation. You may use the existing file as context for asking better questions, but never copy its content verbatim or use it as a substitute for elicitation.
- **No codebase inference.** Never generate principles by reading source files, configs, or commit history. Principles must come from the user's stated values, not from what you observe in the code.
- **Keep categories separate.** Core Principles ≠ Development Conventions ≠ Constraints. Conflating them makes the constitution unactionable for `/maxi:analyze`.
- **Principles, not decisions.** A constitution holds *invariants that constrain all future decisions* — not the decisions themselves. Route each candidate by the litmus test:
  - **Decision → ADR, not here.** It names a specific technology, is contestable (real alternatives exist), or could be reversed by a later choice. The pipeline captures these via `/maxi:x-adr` during `/maxi:plan`/`/maxi:implement`.
  - **Principle → here.** A durable rule every future decision must satisfy.
  - **Constraint → here.** An externally-imposed requirement with no real alternative (e.g. a compliance-mandated platform) is *not* contestable, so it stays in the constitution.
  - Example: *"Every storage choice must be justified against data-durability needs"* is a principle; *"We use PostgreSQL"* is a decision (ADR).
- **Minimum 3, maximum 7.** Fewer than 3 is incomplete. More than 7 is noise.
- **Verify on write.** After writing, confirm the file exists at `docs/maxi/constitution.md`. If it doesn't, diagnose and retry.

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.

## Red Flags

- Writing to any path other than `docs/maxi/constitution.md` → **wrong path, redo**
- Generating content before asking any questions → **delete draft, elicit first**
- User said "I'm in a hurry / just use reasonable defaults" and you skipped questions → **elicitation is never optional; ask anyway**
- User pointed to `CLAUDE.md` or another file and you copied its content → **delete draft, explain format mismatch, elicit first**
- You read source files or configs to infer principles without asking the user → **delete draft, elicit first**
- Mixing "use TypeScript strict mode" (convention) with "never store PII unencrypted" (constraint) in the same section → **separate them**
- Writing a concrete tech/tool choice ("we use PostgreSQL", "deploy on Vercel", "MAJOR.MINOR.BUILD versioning") as a Core Principle → **that's a decision, not a principle; record the underlying invariant here — the concrete choice is destined for an ADR, captured later during `/maxi:plan`/`/maxi:implement`**
- Writing 10+ principles → **consolidate to 7 maximum**
