---
name: doc-consistency
description: Use when reviewing maxi-superpowers' own authored docs for factual drift — before committing pipeline/skill changes, after editing AGENTS.md/README/architecture.md, or when asked to check whether docs are consistent, in sync, or contradict each other
---

# doc-consistency

## Overview

maxi-superpowers documents a "Mandatory Sync" rule in `AGENTS.md`, but prose-level drift still needs review. Docs drift: skill counts go stale, test lists fall behind, the five sync-locked files disagree. This skill makes the review **systematic and reproducible** — an unguided pass catches some drift by luck and misses table-level mismatches.

**Core split:** *mechanical* facts have one ground truth (compute it, compare). *Semantic* findings need judgment (verify before asserting; never auto-fix).

Run from repo root.

## When to Use

- Before committing any change to the pipeline, a skill, the test suite, or the FSM
- After editing `AGENTS.md`, `README.md`, `docs/architecture.md`, or any Mandatory-Sync-5 file
- When asked to check docs are consistent / in sync / not contradictory

**Scope (authored docs only):** `AGENTS.md`, `CLAUDE.md`, `README.md`, `VENDORED.md`, `docs/architecture.md`, `docs/pipeline-flow.md`, `docs/delegation-map.md`, `skills/using-maxi/SKILL.md`. **Exclude** `docs/maxi/specs/**` and `docs/maxi/adr/**` — those are point-in-time artifacts that intentionally drift.

## Step 1 — Mechanical checks (anchored facts)

Each fact has exactly ONE ground truth. Compute it, then grep every authored doc that *states* it. A doc that doesn't mention the fact is fine; a doc that states a *different* value is drift.

```bash
# 1. maxi-native skill count (native = skills/ minus vendored superpowers skills)
comm -23 <(ls skills | sort) <(ls vendor/superpowers/skills | sort) | tee /tmp/native-skills.txt | wc -l
# Expected: a single number N. Check every doc stating "N maxi-native skills" agrees
# (AGENTS.md overview, docs/architecture.md, README). Also verify the breakdown
# (user-facing commands + adr + using-maxi + migration utils + ...) sums to N.

# 2. fast-tier test list — ground truth = check-*.sh invoked by run-all.sh (non-integration)
grep -oE 'check-[a-z-]+\.sh' tests/run-all.sh | sort -u
# Compare this exact set to the bullet list in AGENTS.md's "Fast tier" section.

# 3. FSM status values — the canonical set is 10:
#    drafting specified clarified planned tasked analyzed implementing done parked cancelled
# Confirm the SAME set (and sequence, where shown) in AGENTS.md, skills/using-maxi/SKILL.md,
# docs/pipeline-flow.md, docs/delegation-map.md.
grep -hoE 'drafting|specified|clarified|planned|tasked|analyzed|implementing|done|parked|cancelled' \
  AGENTS.md skills/using-maxi/SKILL.md docs/pipeline-flow.md docs/delegation-map.md | sort -u

# 4. superpowers version — ground truth = VENDORED.md
grep -iE 'version|v[0-9]' VENDORED.md
# Confirm any doc citing a version (README, architecture.md, delegation-map.md) matches.
```

## Step 2 — Semantic cross-checks (judgment)

These can't be reduced to a count. Read both sides and compare meaning.

- **Gating-table equivalence** — the phase-gating table in `skills/using-maxi/SKILL.md` vs `docs/delegation-map.md`: same skills (rows), same required-status, same transitions. The naive pass misses this; do it explicitly, row by row. (Known drift class: a missing `constitution` row; "none" vs "constitution exists" for `/maxi:specify`.)
- **Mandatory-Sync-5 coherence** — `docs/pipeline-flow.md`, `docs/delegation-map.md`, `skills/using-maxi/SKILL.md`, `AGENTS.md`, and `docs/architecture.md` must tell the same story: every skill, status, and transition appears consistently across all five.
- **README command completeness** — the command reference tables vs the actual command skills under `skills/`.
- **Illustrative trees** — the `skills/`, `tests/`, and `docs/` file trees in `docs/architecture.md` vs the actual filesystem (`ls`). These drift silently when files are added.
- **Prose-contradiction sweep** — any claim in one doc that another doc or the code contradicts.

**For each semantic finding: verify against the code/files before asserting it.** Do not report a contradiction you haven't confirmed is actually wrong (e.g. a README harness claim may be intentional, not drift).

## Step 3 — Report

One consolidated report. For each finding: the claim, `file:line`, the ground truth, and which files disagree. Separate **Mechanical (confirmed)** from **Semantic (advisory)** — they get handled differently in Step 4.

## Step 4 — Fix on consent

- **Mechanical findings:** offer to fix (update the stale number/list to match ground truth). Apply only after the user approves. Re-run Step 1 to confirm.
- **Semantic findings:** stay advisory. Present them; let the user decide. Do not rewrite prose to "resolve" a contradiction without explicit direction — you might be erasing intent rather than fixing an error.

When a fix touches a Mandatory-Sync-5 file, remind the user the other four may need the same edit.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Eyeballing instead of computing ground truth | Run the Step 1 commands. A number you didn't compute is a guess. |
| Skipping the gating-table row diff | It's the check the unguided pass always misses. Do it explicitly. |
| Asserting a semantic contradiction without checking the code | Verify first. Unconfirmed contradictions are noise. |
| Auto-fixing semantic findings | Mechanical only. Semantic stays advisory. |
| Reviewing specs/ADRs | Out of scope — they intentionally drift from current state. |
| Fixing one Mandatory-Sync-5 file, forgetting the other four | Drift across the five is the original bug this guards against. |
