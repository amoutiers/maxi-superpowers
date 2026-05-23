---
name: clarify
description: Use when the user invokes /maxi:clarify or when a spec.md has open questions, [NEEDS CLARIFICATION] markers, or ambiguous FRs — status must be "specified"
---

# clarify

Resolve open questions in an existing spec without rewriting it. Appends a `## Clarifications` section and updates FRs in place.

## Prereqs

- `docs/constitution.md` must exist — if missing, stop: *"No constitution found. Run `/maxi:constitution` first."*
- Locate the in-flight spec in `docs/maxi/specs/`. Find `spec.md` with `status: specified`.
  - If multiple specs at `status: specified`: ask user which one to clarify.
  - If none at `status: specified`: stop with *"No spec at status `specified` found. Run `/maxi:specify` to create one, or check that the target spec is in the right phase."*
  - If spec is `drafting`: stop with *"Spec is still `drafting` — run `/maxi:specify` to complete it first."*
  - If spec is `clarified` or later: stop with *"Spec is already `clarified`. No further clarification needed; proceed to `/maxi:plan`."*

## Process

1. **Read spec.md** — scan for: `[NEEDS CLARIFICATION: ...]` markers, questions in FR descriptions, vague adjectives ("fast", "robust", "user-friendly", "simple"), and missing acceptance criteria
2. **Build question list** — collect all ambiguities found; prioritize by impact (blocking FRs first)
3. **Ask one question at a time** — present context, ask one focused question, wait for answer before next
4. **Record each answer** — after each answer, note how it resolves the ambiguity
5. **Update spec.md** — three updates in the same write operation:
   a. In-place: replace `[NEEDS CLARIFICATION: ...]` markers with the resolved text in the relevant FRs
   b. Append: add/update `## Clarifications` section at the end of spec.md with Q&A pairs
   c. Frontmatter: set `updated: [today's ISO date]` (`YYYY-MM-DD`)
6. **Transition status** — change `status: specified` → `status: clarified` in spec.md frontmatter
7. **Report** — tell user: spec clarified at `docs/maxi/specs/NNNN-slug/spec.md` (status: `clarified`). Next: `/maxi:plan`.

## Clarifications Section Format

```markdown
## Clarifications

**Q: [question asked]**
A: [user's answer — verbatim or paraphrased accurately]

**Q: [next question]**
A: [answer]
```

## Critical Rules

- **Read before asking.** Identify ALL ambiguities first; then ask questions in priority order.
- **One question at a time.** Never dump a list of questions. Ask → wait → record → ask next.
- **Narrow scope.** Only resolve existing open questions. Do NOT add new requirements, expand scope, or introduce new user stories. If the user's answer suggests a scope change, note it as a potential follow-up spec.
- **No rewriting.** Do not rewrite sections for polish, style, or clarity. Only touch text that directly resolves an open question.
- **Update spec in place.** Remove `[NEEDS CLARIFICATION: ...]` markers when resolved. Don't leave them as-is.
- **Status: clarified only when complete.** Transition status only after all identified open questions are resolved or explicitly deferred.
- **User says "no open questions"?** You still MUST scan spec.md yourself before accepting this. If you find ambiguities after scanning, ask about them. If the spec is genuinely clean after your own review, you may set status: clarified and report this to the user.

## Red Flags

- No questions asked; skill just rewrites sections → narrow scope, resolve open Qs only
- Asking 5+ questions in one message → one at a time, always
- `[NEEDS CLARIFICATION: ...]` markers still in spec.md after clarification → must update in place
- Running on a spec with `status: planned` or later → wrong phase, stop immediately
- Adding new FR-### items not in the original spec → scope creep, defer to new `/maxi:specify`
- "Cleaning up" or "polishing" prose that isn't tied to an open question → out of scope
- User suggests a new feature mid-Q&A → note it as a follow-up spec, do NOT add to current spec
- Skipping self-scan because user says spec is fine → always scan yourself first
