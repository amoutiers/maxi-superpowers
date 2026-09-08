---
name: specify
description: Use when the user invokes /maxi:specify or wants to create a new feature specification in a maxi-managed project
---

# specify

Coordinate one canonical specification through the user's requested design destination. Read the constitution first; if absent, stop for `/maxi:constitution`.

## Process

1. Reuse the actual request, approved design and settled answers. Bare specify and spec-only creation finish at `clarified`; explicit design validation finishes at `planned` plus the current verdict. Draft-only or phase-only requests stop at that narrower owner boundary.
2. Load `/maxi:review` by registered skill name for support discovery without invoking its public process. Use the exact loaded `review/SKILL.md` directory, canonicalized with `cd -P`; require adjacent `design-operation.md` to be a readable regular, non-symlink file. Missing or unsafe installed support stops before writing; never use client-project skills as fallback. Read it fully.
3. Resolve adjacent `spec-author.md` and `spec-template.md` from this exact loaded `specify/SKILL.md` directory using the same canonical regular, non-symlink checks. Never fall back to client-project copies.
4. Scan `docs/maxi/specs/NNNN-*`, take max + 1 (or `0001`), derive a lowercase kebab-case suffix of at most five words. An exact existing suffix requires a disambiguating user choice; never create a second spec for the same operation on resume.
5. For an explicit draft-only request, invoke only spec-author with that destination and return. Otherwise invoke `/maxi:brainstorming` with the canonical `docs/maxi/specs/NNNN-slug/spec.md` path, actual request, already settled answers/approval, up to three independent questions per turn and the return-to-owner boundary. Reuse unchanged approved design without a second interview or approval. Consider real unresolved product choices; do not manufacture questions. The delegated output belongs in this canonical spec through the author, with no duplicate Superpowers spec or nested planning/execution handoff.
6. Run the installed spec-author brief in create mode, passing the approved design, canonical target, destination and owner-only context. It returns after `specified`; the coordinator runs the actual `/maxi:clarify` scan, even for an approved complete brief. When clean, return `clarified` without questions. For explicit design validation, continue with owner-only `/maxi:plan`, then the bounded review round in design-operation.md.
7. Report the canonical artifact, actual status, unresolved questions or verdict. Never invoke tasks, analyze, or implement as a consequence of completing this operation.

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.
