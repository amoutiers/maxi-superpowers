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
5. For an explicit draft-only request, invoke only spec-author with that destination and return. Draft-only creation bypasses brainstorming, builder and successor phases. Otherwise load [skill-resolution.md](../using-maxi/skill-resolution.md), set `maxi_owner_skill` to this exact loaded specify skill, run `brainstorming="$(bash "$maxi_skills_root/using-maxi/resolve-skill.sh" "$maxi_owner_skill" brainstorming)"` and read the complete returned skill. Derive `brainstorming_dir="$(cd -P "$(dirname "$brainstorming")" && pwd)"`. Require its adjacent `builder-check-prompt.md` to be a readable regular, non-symlink file and read it fully. Missing or unsafe brainstorming or builder support stops before authoring; no co-installed engine or client-repository fallback is allowed.
6. Invoke the bound brainstorming instructions in the current agent with the canonical spec path, actual request, already settled answers/approval, requested destination and return-to-owner boundary. Reuse unchanged approved design without a second interview or approval. Apply its intent-driven conversation only to real unresolved choices; distinguish user decisions from agent assumptions and significant implementation choices. All exits, including a quick request, interview opt-out and size changes, return to the author. Accepted exploratory prototypes also return to the author with findings; they remain throwaway and never authorize retained implementation. The delegated output belongs in this canonical spec through the author, with no duplicate Superpowers design, independent builder dispatch inside brainstorming, or nested planning/execution handoff. The coordinator owns the single check below.
7. Run the installed spec-author brief in create mode, passing the approved design, canonical target, destination and owner-only context. It returns after `specified`.
8. Before actual clarification, dispatch one fresh independent read-only builder using the complete bundled `builder-check-prompt.md`. Supply the complete canonical spec once by its path and the appropriate domain in one dispatch. Require the builder itself to read the complete bound prompt at its installed path and that document, then return questions only, with no approval, writes, planning or successor authorization. If independent dispatch is unavailable, stop at `specified` and report the limitation. Retain the actual result on continuation; do not repeat a completed check or reset its single question round on resume.
9. Resolve builder questions from the conversation and project evidence first. Settle minor choices as explicit agent decisions. Bring only material unresolved user choices in one ranked message, then route all answers and corrections to the same spec-author in new-spec builder correction mode. That author updates the just-created canonical artifact; the builder never writes. The check grants no design-review count or approval and never replaces the fixed spec/plan design review.
10. Run the actual `/maxi:clarify` scan, even for an approved complete brief. When clean, return `clarified` without questions. For explicit design validation, continue with owner-only `/maxi:plan`, then the bounded review round in design-operation.md. Existing-spec revisions retain their own owner boundaries and never enter this creation-only builder check.
11. Report the canonical artifact, actual status, unresolved questions or verdict. Never invoke tasks, analyze, or implement as a consequence of completing this operation.

## Artifact reference links

When this skill emits prose that references another maxi artifact (an ADR, spec, plan, tasks, constitution, or repo file) — in an artifact body or in a chat report — render it as a **relative Markdown link**, not a bare slug/number/code span:
- **Visible text** = the target filename without `.md` (an ADR slug like `0003-constitution-decoupled-from-claudemd`; for generic spec artifacts use `<feature-dir>/<name>`, e.g. `0002-migrate-adr-review-fixes/spec`; non-`.md` files keep their full name).
- **URL** = a relative path from the referencing file's directory (workspace-root-relative for chat reports).
- **Do NOT** link frontmatter data values (`related_adrs` entries stay bare slugs) or within-document IDs (`FR-012`, section names).
- Applies **forward-only** — do not retro-edit existing artifacts.
