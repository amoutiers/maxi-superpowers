# Design Review Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remediate 10 design findings from the 2026-05-24 global review: fix documentation drift (F1, F3), strengthen the sync test (F2), fix slug semantics (F7, F10), document the migration exception (F6), add lifecycle management skills and statuses (F4, F5), and gate session injection on project context (F9-A).

**Architecture:** Three-layer plugin — skills (SKILL.md prose), hooks (bash), tests (bash fast-tier + integration). P0 fixes are pure edits to existing files, committable as one unit. P1 involves new SKILL.md files (authored via `superpowers:writing-skills` per CLAUDE.md) and bash modifications. New SKILL.md files require `superpowers:writing-skills` — do NOT hand-write them.

**Tech Stack:** Bash 5.x, SKILL.md (YAML frontmatter + Markdown), Claude Code plugin hooks, `diff -r` (coreutils).

**⚠ ADR proposals flagged:** Two architectural changes in this plan warrant ADRs (see end of document).

---

## Phase 1 — P0 Fixes (commit as one unit, ~1 h)

---

### Task 1 — Fix using-maxi phase gating table (F1)

**Files:**
- Modify: `skills/using-maxi/SKILL.md` lines 67–74

**Context:** The Phase Gating table still shows pre-strict-pipeline tolerances. `hooks/session-start` injects this file verbatim at every session start, so Claude gets a wrong map from turn 0.

- [ ] **Step 1: Read the current table**

  Open `skills/using-maxi/SKILL.md` lines 60–80. Confirm lines 71 and 74 read:
  ```
  | /maxi:plan      | clarified  | accepts `specified` (warns) | planned          |
  | /maxi:implement | tasked or analyzed | none                | implementing→done |
  ```

- [ ] **Step 2: Replace the table**

  Replace lines 67–74 (the full table including header) with:
  ```markdown
  | Skill | Required status | Tolerance | Produces |
  |---|---|---|---|
  | `/maxi:specify` | none | — | `specified` |
  | `/maxi:clarify` | `specified` | none | `clarified` |
  | `/maxi:plan` | `clarified` | none | `planned` |
  | `/maxi:tasks` | `planned` | none | `tasked` |
  | `/maxi:analyze` | `tasked`+ | re-run ok on `analyzed`/`implementing`/`done` | `analyzed` |
  | `/maxi:implement` | `analyzed` | none | `implementing` → `done` |
  ```

  Then add this note immediately after the table (before `## Vendored Superpowers Skills`):
  ```markdown
  > **Note:** Skills are designed to be cheap when there is nothing to do. `/maxi:clarify` completes in seconds if the spec has no ambiguities. `/maxi:analyze` produces a clean report instantly if there are no issues. The discipline cost is bounded; the value is not.
  ```

- [ ] **Step 3: Run fast-tier tests**

  ```bash
  bash tests/run-all.sh
  ```
  Expected: all fast-tier checks pass.

---

### Task 2 — Fix CLAUDE.md skills inventory (F3)

**Files:**
- Modify: `CLAUDE.md` (line 5 area)
- Modify: `tests/check-skills-present.sh` (line 2 comment)
- Modify: `CLAUDE.md` (integration test count, line 60 area)

**Context:** `CLAUDE.md` says "10 maxi-native skills, 7 user-facing commands" and "7 naive prompts". Reality is 11 skills, 8 user-facing. `board.txt` integration prompt already exists.

- [ ] **Step 1: Fix CLAUDE.md skills inventory**

  Find the line in `CLAUDE.md` that reads:
  ```
  It vendors superpowers' skills via git subtree and adds 10 maxi-native skills: 7 user-facing commands (`constitution`, `specify`, `clarify`, `plan`, `tasks`, `analyze`, `implement`), 1 internal pipeline skill (`adr`), 1 session skill (`using-maxi`), and 1 migration utility (`migrate-from-speckit`).
  ```
  Replace with:
  ```
  It vendors superpowers' skills via git subtree and adds 11 maxi-native skills: 8 user-facing commands (`constitution`, `specify`, `clarify`, `plan`, `tasks`, `analyze`, `implement`, `board`), 1 internal pipeline skill (`adr`), 1 session skill (`using-maxi`), and 1 migration utility (`migrate-from-speckit`).
  ```

- [ ] **Step 2: Fix integration test count in CLAUDE.md**

  Find the line that mentions "7 naive prompts" in the Testing section. Change `7` to `8`. The line should reference all 8 skills: `specify, clarify, plan, tasks, analyze, implement, constitution, board`.

- [ ] **Step 3: Fix check-skills-present.sh comment**

  In `tests/check-skills-present.sh` line 2, change:
  ```bash
  # Check that all 10 maxi-native skills exist as skills/<name>/SKILL.md
  ```
  to:
  ```bash
  # Check that all 11 maxi-native skills exist as skills/<name>/SKILL.md
  ```

- [ ] **Step 4: Run fast-tier tests**

  ```bash
  bash tests/run-all.sh
  ```
  Expected: all checks pass.

- [ ] **Step 5: Verify grep returns zero results**

  ```bash
  grep -r "10 maxi-native" . --include="*.md" --include="*.sh"
  ```
  Expected: no output.

---

### Task 3 — Extend check-sync-invariant.sh to full-directory diff (F2)

**Files:**
- Modify: `tests/check-sync-invariant.sh`

**Context:** The test currently only diffs `SKILL.md`, missing drift in auxiliary files (e.g. `brainstorming/visual-companion.md`). Replace with `diff -r` on the full skill directory.

- [ ] **Step 1: Write the modified test (full replacement of loop body)**

  Replace the content of `tests/check-sync-invariant.sh` starting from `for vendor_dir in` through `done` with:
  ```bash
  for vendor_dir in "$VENDOR"/*/; do
    name=$(basename "$vendor_dir")

    if [ ! -f "$vendor_dir/SKILL.md" ]; then
      echo "SKIP [$name]: no SKILL.md in vendor (unusual)" >&2
      continue
    fi

    skills_dir="$SKILLS/$name"

    if [ ! -d "$skills_dir" ]; then
      echo "FAIL [$name: skills/ copy]: directory missing" >&2
      failures=$((failures + 1))
      continue
    fi

    diff_output=$(diff -r "$vendor_dir" "$skills_dir" 2>&1 || true)
    if [ -n "$diff_output" ]; then
      echo "FAIL [$name: skill dir in sync with vendor]:" >&2
      echo "$diff_output" >&2
      failures=$((failures + 1))
    else
      echo "OK  [$name: skill dir in sync with vendor]"
    fi
  done
  ```

- [ ] **Step 2: Verify test catches a real drift (manual canary)**

  ```bash
  echo "# drift" >> skills/brainstorming/SKILL.md
  bash tests/check-sync-invariant.sh
  ```
  Expected: FAIL with diff output mentioning `brainstorming/SKILL.md`.

- [ ] **Step 3: Restore and verify pass**

  ```bash
  git checkout skills/brainstorming/SKILL.md
  bash tests/check-sync-invariant.sh
  ```
  Expected: all OK lines, exit 0.

- [ ] **Step 4: Run full fast-tier suite**

  ```bash
  bash tests/run-all.sh
  ```
  Expected: all checks pass.

- [ ] **Step 5: Commit P0 block**

  ```bash
  git add skills/using-maxi/SKILL.md CLAUDE.md tests/check-skills-present.sh tests/check-sync-invariant.sh
  git commit -m "fix(p0): strict-pipeline table in using-maxi, board doc + integration count, full-dir sync invariant"
  ```

---

## Phase 2 — P1 Slug Fixes (F7, F10)

---

### Task 4 — Fix slug stop-word example (F10)

**Files:**
- Modify: `skills/specify/SKILL.md` (example line ~70)

**Context:** Rule says "to" is a stop-word; example preserves "to". Fix the example to match the rule.

- [ ] **Step 1: Read the relevant section**

  Read `skills/specify/SKILL.md` lines 65–75. Confirm line ~70 contains:
  ```
  - "build a CSV to JSON converter" → `csv-to-json-converter`
  ```

- [ ] **Step 2: Fix the example**

  Replace:
  ```
  - "build a CSV to JSON converter" → `csv-to-json-converter`
  ```
  with:
  ```
  - "build a CSV to JSON converter" → `csv-json-converter`
  ```

- [ ] **Step 3: Run fast-tier tests**

  ```bash
  bash tests/run-all.sh
  ```
  Expected: all checks pass.

---

### Task 5 — Add slug collision detection to specify (F7)

**Files:**
- Modify: `skills/specify/SKILL.md` (Step 3 — Derive slug)

**Context:** Two features with different descriptions can derive the same slug-suffix. Add a post-derivation collision check with disambiguation prompt. Collision = exact suffix match (character-for-character, no fuzzy matching).

- [ ] **Step 1: Read Step 3 in specify/SKILL.md**

  Read `skills/specify/SKILL.md` around lines 65–80 (Step 3 — Derive slug). Note where the step ends.

- [ ] **Step 2: Append collision-check paragraph to Step 3**

  After the stop-word examples and before Step 4, insert:

  ```markdown
  **Slug collision check:** After deriving the slug-suffix, scan `docs/maxi/specs/` for any directory whose name (after the `NNNN-` prefix) is exactly equal to the derived suffix. If a match is found, stop and ask:

  > "The slug `<suffix>` already exists (used by `<MMMM-suffix>`). Please provide a disambiguating suffix. Suggested: `<suffix>-v2`."

  Wait for the user's input. Use the user-supplied suffix as the final slug-suffix for the new spec. Do not proceed until the collision is resolved. If no collision exists, continue directly to Step 4.
  ```

- [ ] **Step 3: Run fast-tier tests**

  ```bash
  bash tests/run-all.sh
  ```
  Expected: all checks pass.

- [ ] **Step 4: Commit Phase 2**

  ```bash
  git add skills/specify/SKILL.md
  git commit -m "fix(specify): stop-word example consistency (F10) + slug collision detection (F7)"
  ```

---

## Phase 3 — P1 Migration Exception (F6)

---

### Task 6 — Document migration exception + add Migration Notes to migrated specs (F6)

**Files:**
- Modify: `docs/architecture.md` (strict-pipeline section, ~line 162)
- Modify: `skills/migrate-from-speckit/SKILL.md` (post-migration reporting step)
- Modify: `skills/migrate-from-speckit/migrate.sh` (append Migration Notes to spec.md)

**Context:** The migration script infers statuses `specified/planned/tasked/done` from artefacts, bypassing strict-pipeline phases. This is intentional but undocumented for statuses above `specified`. Chosen approach: document as explicit exception (option B) + add Migration Notes to migrated specs.

- [ ] **Step 1: Extend architecture.md — amend strict-pipeline ADR**

  Read `docs/architecture.md` lines 148–165. Find the **Consequences** section of the strict-pipeline ADR (around line 162). Extend it:

  Replace the current single-sentence consequence:
  ```
  **Consequences:** Specs migrated via `migrate-from-speckit` at status `specified` must pass through `/maxi:clarify` before `/maxi:plan`. This is intentional.
  ```
  with:
  ```
  **Consequences:**
  - Specs at status `drafting` or `specified` must pass through the full remaining pipeline from that status.
  - `/migrate-from-speckit` is an **explicit exception**: it infers status from pre-existing artefacts (`planned`, `tasked`, `done`). Trust is delegated to the spec-kit history. From the inferred status forward, the strict pipeline applies without exception.
  - Migrated specs append a `## Migration Notes` section documenting which maxi pipeline phases were not run. This section is informational — it records provenance, not a mandate to re-run phases.
  ```

- [ ] **Step 2: Read migrate.sh status-inference section**

  Read `skills/migrate-from-speckit/migrate.sh` lines 90–115. Identify:
  - The line(s) that set the `status` variable based on artefact presence
  - The line that writes the final `spec.md` frontmatter

- [ ] **Step 3: Add Migration Notes generation to migrate.sh**

  After the spec.md frontmatter is written (after the status is set), add a block that appends `## Migration Notes` to the spec.md. The block should:

  1. Build a list of which phases were NOT run in maxi, based on inferred status:
     - `specified` → phases not run: none yet (all remain)
     - `planned` → phases not run: `clarify`
     - `tasked` → phases not run: `clarify`, `plan`, `tasks`
     - `done` → phases not run: `clarify`, `plan`, `tasks`, `analyze`, `implement`

  2. Append to `spec.md`:
  ```bash
  # Determine skipped phases based on inferred status
  case "$inferred_status" in
    specified) skipped_phases="" ;;
    planned)   skipped_phases="- \`/maxi:clarify\` (spec considered clarified from spec-kit history)" ;;
    tasked)    skipped_phases="- \`/maxi:clarify\` (spec considered clarified from spec-kit history)\n- \`/maxi:plan\` (plan.md found in spec-kit)\n- \`/maxi:tasks\` (tasks.md found in spec-kit)" ;;
    done)      skipped_phases="- \`/maxi:clarify\`, \`/maxi:plan\`, \`/maxi:tasks\`, \`/maxi:analyze\`, \`/maxi:implement\` (retrospective/shipped spec)" ;;
    *)         skipped_phases="" ;;
  esac

  if [ -n "$skipped_phases" ]; then
    printf '\n## Migration Notes\n\n**Migrated from spec-kit on %s.** Status inferred as `%s` from artefacts found.\n\nPipeline phases not run in maxi (trusted from spec-kit history):\n%b\n\nFrom this status forward, the strict maxi pipeline applies.\n' \
      "$(date +%Y-%m-%d)" "$inferred_status" "$skipped_phases" >> "$target_spec"
  fi
  ```

  Adapt variable names to match the actual script variables (read in Step 2).

- [ ] **Step 4: Update migrate-from-speckit/SKILL.md — post-migrate reporting**

  Add a sentence to the reporting step (final step of the skill):
  > "If the inferred status is above `specified`, the migrated spec will have a `## Migration Notes` section documenting which pipeline phases were trusted from the spec-kit history."

- [ ] **Step 5: Run fast-tier tests**

  ```bash
  bash tests/run-all.sh
  ```
  Expected: all checks pass (no new frontmatter format tested; migration script is integration-tested separately).

- [ ] **Step 6: Commit**

  ```bash
  git add docs/architecture.md skills/migrate-from-speckit/SKILL.md skills/migrate-from-speckit/migrate.sh
  git commit -m "fix(migrate): document strict-pipeline exception + append Migration Notes to migrated specs (F6)"
  ```

---

## Phase 4 — P1 FSM Expansion: parked + cancelled (F5)

---

### Task 7 — Expand status set in template + fixture test

**Files:**
- Modify: `templates/spec-template.md`
- Modify: `tests/check-spec-fixture.sh`
- Modify: `tests/fixtures/sample-spec.md`

**Context:** Add `parked` and `cancelled` to the allowed-values comment and add `parked_from: null` frontmatter field. Update the round-trip test to validate the 2 new statuses.

- [ ] **Step 1: Update spec-template.md frontmatter**

  In `templates/spec-template.md`, the frontmatter block currently reads:
  ```yaml
  ---
  slug: NNNN-feature-slug
  created: YYYY-MM-DD
  updated: YYYY-MM-DD
  status: drafting
  # Allowed values: drafting | specified | clarified | planned | tasked | analyzed | implementing | done
  ---
  ```
  Replace with:
  ```yaml
  ---
  slug: NNNN-feature-slug
  created: YYYY-MM-DD
  updated: YYYY-MM-DD
  status: drafting
  # Allowed values: drafting | specified | clarified | planned | tasked | analyzed | implementing | done | parked | cancelled
  parked_from: null
  # parked_from: set by /maxi:park to the pre-park status; cleared to null by /maxi:resume
  ---
  ```

- [ ] **Step 2: Update sample-spec.md fixture**

  In `tests/fixtures/sample-spec.md`, apply the same frontmatter change (add `parked_from: null` line after `status:`):
  ```yaml
  ---
  slug: 0001-sample-feature
  created: "2026-05-08"
  updated: "2026-05-08"
  status: drafting
  # Allowed values: drafting | specified | clarified | planned | tasked | analyzed | implementing | done | parked | cancelled
  parked_from: null
  ---
  ```

- [ ] **Step 3: Update check-spec-fixture.sh to include new statuses**

  In `tests/check-spec-fixture.sh` line 9, change:
  ```bash
  VALID_STATUSES=(drafting specified clarified planned tasked analyzed implementing done)
  ```
  to:
  ```bash
  VALID_STATUSES=(drafting specified clarified planned tasked analyzed implementing done parked cancelled)
  ```

- [ ] **Step 4: Run fast-tier tests**

  ```bash
  bash tests/run-all.sh
  ```
  Expected: all checks pass, including 10 round-trip status checks (8 existing + parked + cancelled).

---

### Task 8 — Add parked/cancelled buckets to board skill (F5)

**Files:**
- Modify: `skills/board/SKILL.md`

**Context:** Add `parked` and `cancelled` to the bucket order and rendering rules. `parked` appears between `implementing` and `done` (frozen active work). `cancelled` appears after `done` (terminal, quiet). Both show `_empty_` when no specs have that status. No staleness for `cancelled` (terminal).

- [ ] **Step 1: Update Step 3 — Group by Status**

  In `skills/board/SKILL.md`, find Step 3's bucket list:
  ```
  drafting → specified → clarified → planned → tasked → analyzed → implementing → done
  ```
  Replace with:
  ```
  drafting → specified → clarified → planned → tasked → analyzed → implementing → parked → done → cancelled
  ```
  Add a note: "`parked` = spec frozen in progress (non-terminal, resumable). `cancelled` = terminal, not actionable. Both always shown; `unknown` bucket appears last if any spec has an unrecognized status."

- [ ] **Step 2: Update Step 5 — Compute Staleness**

  Add: "Skip staleness computation for specs at `cancelled` status — terminal status, quiet by design."

- [ ] **Step 3: Update the render example in Step 6**

  After the `## implementing` block and before `## done`, add:
  ```
  ## parked (1)
  - 006-ml-pipeline        — ML pipeline             (updated 03-10, stale 79d)

  ## done (12) — showing 2 from last 30d
  ...

  ## cancelled (1)
  - 002-old-feature        — Old feature             (updated 01-05)
  ```
  And in Rendering rules, add:
  - "`cancelled` bucket: no staleness suffix (terminal status); entries shown with `updated` date only."
  - "`parked` bucket: staleness applies normally (parked specs can go stale)."

- [ ] **Step 4: Run fast-tier tests**

  ```bash
  bash tests/run-all.sh
  ```
  Expected: all checks pass.

---

### Task 9 — Write /maxi:cancel skill (F5)

**Files:**
- Create: `skills/cancel/SKILL.md` (via `superpowers:writing-skills`)
- Modify: `tests/check-skills-present.sh` (MAXI_SKILLS array)
- Create: `tests/integration/prompts/cancel.txt`
- Modify: `tests/integration/run-all.sh` (add "cancel" to SKILLS array)
- Modify: `CLAUDE.md` (add cancel/park/resume to skills count and list, update to 14 skills)

**⚠ Note:** After writing cancel/park/resume/revise, the skill count becomes 15 (11 + 4). Update CLAUDE.md in Task 13 after all new skills are written.

- [ ] **Step 1: Write behavioral spec for /maxi:cancel**

  Invoke `superpowers:writing-skills` with this specification:

  ```
  Skill name: cancel
  Plugin prefix: maxi

  TRIGGER: When user invokes /maxi:cancel, says "cancel this spec", "abandon this feature", or "this spec is dead".

  PREREQS:
  - docs/maxi/constitution.md must exist (hard stop if missing, same message as other skills).
  - Locate the target spec in docs/maxi/specs/. If multiple active specs, ask which one.
  - If spec is already at status: cancelled → stop: "Spec is already cancelled."
  - If spec is at status: parked → stop: "Spec is parked, not active. To cancel a parked spec, run /maxi:resume first, then /maxi:cancel."
  - If spec is at status: done → stop: "Spec is done (shipped). Cancellation is for in-progress work."

  PROCESS:
  1. Display spec summary: slug, title, current status, updated date.
  2. Ask: "Reason for cancellation?" — require a non-empty answer.
  3. Confirm: show "About to mark <slug> as CANCELLED (terminal — cannot be un-cancelled). Reason: <reason>. Proceed? (yes/no)"
  4. On yes: write spec.md — set status: cancelled, updated: today's ISO date. Append to ## Clarifications:
     "**Cancelled (YYYY-MM-DD):** <reason>"
  5. Report: "Spec <slug> cancelled. It will appear in the `cancelled` bucket of /maxi:board."

  INVARIANTS:
  - Consent-gated (reason + explicit yes/no confirmation required).
  - NEVER write without explicit "yes" — ambiguous responses ("ok", "sure") = no.
  - Terminal: no /maxi:resume for cancelled specs.
  - The ## Clarifications entry is append-only.
  - Never modify any other file (plan.md, tasks.md, constitution.md, ADRs).
  - If user says "cancel" without a target spec, ask which spec before proceeding.

  RATIONALIZATION COUNTERS:
  - "User said ok" → not explicit yes, ask again.
  - "The spec is obviously dead, just cancel it" → still need explicit reason + yes.
  ```

- [ ] **Step 2: Run fast-tier tests to validate frontmatter**

  ```bash
  bash tests/run-all.sh
  ```
  Expected: `check-frontmatter` passes for the new skill.

- [ ] **Step 3: Register cancel in check-skills-present.sh**

  Add `cancel` to the `MAXI_SKILLS` array in `tests/check-skills-present.sh`. Update the comment to reflect the new count (will finalize in Task 13).

- [ ] **Step 4: Add cancel integration test prompt**

  Create `tests/integration/prompts/cancel.txt`:
  ```
  I want to cancel the current spec for this project.
  ```

---

### Task 10 — Write /maxi:park and /maxi:resume skills (F5)

**Files:**
- Create: `skills/park/SKILL.md` (via `superpowers:writing-skills`)
- Create: `skills/resume/SKILL.md` (via `superpowers:writing-skills`)
- Modify: `tests/check-skills-present.sh`
- Create: `tests/integration/prompts/park.txt`
- Create: `tests/integration/prompts/resume.txt`

- [ ] **Step 1: Write behavioral spec for /maxi:park**

  Invoke `superpowers:writing-skills` with this specification:

  ```
  Skill name: park
  Plugin prefix: maxi

  TRIGGER: /maxi:park, "park this spec", "put this on hold", "pause this feature", "this is blocked".

  PREREQS:
  - docs/maxi/constitution.md must exist.
  - Locate target spec. If multiple active specs, ask which one.
  - If already parked → stop: "Spec is already parked. Use /maxi:resume to resume it."
  - If cancelled → stop: "Spec is cancelled. Cannot park a cancelled spec."
  - If done → stop: "Spec is done (shipped). No need to park."

  PROCESS:
  1. Display spec summary: slug, title, current status.
  2. Ask: "Reason for parking?" — require a non-empty answer.
  3. Confirm: "About to park <slug> (currently <status>). Reason: <reason>. Proceed? (yes/no)"
  4. On yes: write spec.md —
     - status: parked
     - parked_from: <current_status>
     - updated: today's ISO date
     Append to ## Clarifications: "**Parked (YYYY-MM-DD):** <reason> (was: <current_status>)"
  5. Report: "<slug> is now parked. Run /maxi:resume to pick it back up."

  INVARIANTS:
  - Consent-gated (reason + explicit yes).
  - parked_from MUST be set to the current status before writing.
  - Non-terminal: /maxi:resume restores from parked_from.
  - Never modify plan.md, tasks.md, constitution.md, or ADRs.
  ```

- [ ] **Step 2: Write behavioral spec for /maxi:resume**

  Invoke `superpowers:writing-skills` with this specification:

  ```
  Skill name: resume
  Plugin prefix: maxi

  TRIGGER: /maxi:resume, "resume a spec", "unpause", "pick up the parked spec".

  PREREQS:
  - docs/maxi/constitution.md must exist.
  - Locate target spec. If multiple parked specs, list them and ask which one.
  - If no spec at status: parked → stop: "No parked spec found. Use /maxi:board to see current statuses."
  - If spec is cancelled → stop: "Spec is cancelled (terminal). It cannot be resumed."
  - If spec is not parked → stop: "Spec is at status <status>, not parked."

  PROCESS:
  1. Display spec: slug, title, parked_from field (the status to restore).
  2. Confirm: "Resume <slug>? It will return to status <parked_from>. (yes/no)"
  3. On yes: write spec.md —
     - status: <parked_from>
     - parked_from: null
     - updated: today's ISO date
     Append to ## Clarifications: "**Resumed (YYYY-MM-DD):** returning to <parked_from>"
  4. Report: "<slug> resumed at status <parked_from>. Next: /maxi:<parked_from-next-skill>."
     (e.g. if parked_from was clarified → next is /maxi:plan)

  INVARIANTS:
  - Consent-gated (explicit yes).
  - parked_from MUST be read from spec.md frontmatter — do NOT ask the user what status to restore.
  - On resume, parked_from is cleared to null.
  - If parked_from is missing or null on a parked spec → warn: "parked_from field is missing. Ask the user what status to restore, then set it manually."
  - Never modify plan.md, tasks.md, constitution.md, or ADRs.
  ```

- [ ] **Step 3: Run fast-tier tests**

  ```bash
  bash tests/run-all.sh
  ```
  Expected: all checks pass.

- [ ] **Step 4: Register park and resume in check-skills-present.sh**

  Add `park` and `resume` to the `MAXI_SKILLS` array.

- [ ] **Step 5: Add integration test prompts**

  Create `tests/integration/prompts/park.txt`:
  ```
  I need to put the current feature on hold for a while.
  ```

  Create `tests/integration/prompts/resume.txt`:
  ```
  Resume the spec that's currently parked.
  ```

- [ ] **Step 6: Commit Phase 4 (F5 full)**

  ```bash
  git add templates/spec-template.md tests/fixtures/sample-spec.md tests/check-spec-fixture.sh skills/board/SKILL.md skills/cancel/SKILL.md skills/park/SKILL.md skills/resume/SKILL.md tests/check-skills-present.sh tests/integration/prompts/cancel.txt tests/integration/prompts/park.txt tests/integration/prompts/resume.txt
  git commit -m "feat(f5): add parked/cancelled statuses + /maxi:cancel, /maxi:park, /maxi:resume skills"
  ```

---

## Phase 5 — P1 Backflow: /maxi:revise (F4)

---

### Task 11 — Write /maxi:revise skill (F4)

**Files:**
- Create: `skills/revise/SKILL.md` (via `superpowers:writing-skills`)
- Modify: `tests/check-skills-present.sh`
- Create: `tests/integration/prompts/revise.txt`

- [ ] **Step 1: Write behavioral spec for /maxi:revise**

  Invoke `superpowers:writing-skills` with this specification:

  ```
  Skill name: revise
  Plugin prefix: maxi

  TRIGGER: /maxi:revise, "revise the spec", "requirements changed", "update the spec", "go back to planning", "the plan needs to change".

  PREREQS:
  - docs/maxi/constitution.md must exist.
  - Locate target spec. If multiple in-flight specs, ask which one.
  - If spec is at status: drafting or specified → stop: "Spec is at <status> — use /maxi:specify or /maxi:clarify instead."
  - If spec is at status: parked → stop: "Spec is parked. Use /maxi:resume first, then /maxi:revise."
  - If spec is at status: cancelled → stop: "Spec is cancelled. Cannot revise."
  - If spec is at status: done → stop: "Spec is done (shipped). To revise, create a new spec."
  - Valid for: clarified, planned, tasked, analyzed, implementing.

  PROCESS:
  1. Ask: "Describe the change that requires revision." — require a non-empty answer.
  2. Infer target rollback status (A+ picker with suggested default):
     - "clarified" if the description mentions requirements change, new FR, dropped FR, user story change, success criteria change, scope change.
     - "planned" if the description mentions plan change, architecture change, technical decision change, new component.
     - "tasked" if the description mentions task extraction error, missing tasks, wrong phasing.
     - "analyzed" if the description mentions a finding needs revisiting.
     Propose: "Based on your description, I suggest rolling back to `<target>` — this means <N> phases will need to re-run (<list of phases>). Accept this, or choose a different target: [clarified | planned | tasked | analyzed]"
  3. Confirm: "About to roll back <slug> from <current_status> to <target>. Artefacts from later phases (plan.md, tasks.md, analysis.md as applicable) will remain on disk but are stale — /maxi:<target-skill> will regenerate them. Proceed? (yes/no)"
  4. On yes: write spec.md —
     - status: <target>
     - updated: today's ISO date
     Append to ## Clarifications:
     "**Revised (YYYY-MM-DD):** Rolled back from `<current_status>` to `<target>`. Change: <description>. Note: artefacts from phases after `<target>` (if any) are stale."
  5. Report: "Spec <slug> is now at `<target>`. Next: /maxi:<target-next-skill>."
     (e.g. target=clarified → next is /maxi:plan; target=planned → next is /maxi:tasks)

  INVARIANTS:
  - Consent-gated (explicit yes — ambiguous = no).
  - A+ picker: always show the suggested target with justification BEFORE showing full options. Do not silently apply the inferred target.
  - Artefacts downstream of rollback are NEVER deleted or renamed. They stay on disk. The ## Clarifications entry flags them as stale.
  - NEVER roll back below `clarified` — use /maxi:specify for requirement rewrites.
  - The skill never touches plan.md, tasks.md, analysis.md content — only the spec.md status and Clarifications section.
  - Constitution check: read constitution.md; if the revised requirements would violate a principle, flag the violation before asking for confirmation (do not silently proceed).

  RATIONALIZATION COUNTERS:
  - "The user said 'just go back to planned'" → still show the A+ picker with justification and require explicit yes.
  - "The change is small, no need to roll back far" → present the inferred target; user can override.
  - "Artefacts are stale, let me clean them up" → NEVER delete or rename downstream artefacts.
  ```

- [ ] **Step 2: Run fast-tier tests**

  ```bash
  bash tests/run-all.sh
  ```
  Expected: all checks pass.

- [ ] **Step 3: Register revise in check-skills-present.sh**

  Add `revise` to the `MAXI_SKILLS` array.

- [ ] **Step 4: Add integration test prompt**

  Create `tests/integration/prompts/revise.txt`:
  ```
  The requirements for the current spec have changed and we need to revise it.
  ```

- [ ] **Step 5: Update CLAUDE.md skills inventory (final count)**

  After Tasks 9, 10, 11, there are now 15 maxi-native skills (11 + cancel + park + resume + revise). Update CLAUDE.md:
  - Change "11 maxi-native skills: 8 user-facing commands" → "15 maxi-native skills: 12 user-facing commands"
  - Add `cancel`, `park`, `resume`, `revise` to the user-facing list.
  - Update `check-skills-present.sh:2` comment to "15".

- [ ] **Step 6: Commit Phase 5**

  ```bash
  git add skills/revise/SKILL.md tests/check-skills-present.sh tests/integration/prompts/revise.txt CLAUDE.md
  git commit -m "feat(f4): add /maxi:revise skill for spec backflow + update skills inventory to 15"
  ```

---

## Phase 6 — P2 Conditional Session Injection (F9-A)

---

### Task 12 — Gate session-start injection on docs/maxi/ presence (F9-A)

**Files:**
- Modify: `hooks/session-start`

**Context:** The hook currently injects `using-maxi` unconditionally. In non-maxi projects (no `docs/maxi/`), this wastes tokens and adds noise. Add a guard at the top of the script.

- [ ] **Step 1: Add the guard to hooks/session-start**

  After line 8 (where `PLUGIN_ROOT` is set), insert:
  ```bash
  # Only inject in maxi projects — skip in projects without docs/maxi/
  if [ ! -d "$PWD/docs/maxi" ]; then
    exit 0
  fi
  ```
  The full script beginning should read:
  ```bash
  #!/usr/bin/env bash
  # SessionStart hook for maxi plugin

  set -euo pipefail

  # Determine plugin root directory
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

  # Only inject in maxi projects — skip in projects without docs/maxi/
  if [ ! -d "$PWD/docs/maxi" ]; then
    exit 0
  fi

  # Read using-maxi content
  using_maxi_content=$(cat "${PLUGIN_ROOT}/skills/using-maxi/SKILL.md" 2>&1 || echo "Error reading using-maxi skill")
  ...
  ```

- [ ] **Step 2: Test non-maxi project (no injection)**

  ```bash
  cd /tmp && mkdir -p test-non-maxi && cd test-non-maxi
  PWD="$PWD" bash /Users/amoutiers/Projets/maxi-superpowers/hooks/session-start
  ```
  Expected: no output (exit 0, empty stdout).

- [ ] **Step 3: Test maxi project (injection present)**

  ```bash
  cd /Users/amoutiers/Projets/maxi-superpowers
  bash hooks/session-start | head -5
  ```
  Expected: JSON output starting with `{"hookSpecificOutput":...`.

- [ ] **Step 4: Run fast-tier tests (check-hooks)**

  ```bash
  bash tests/run-all.sh
  ```
  Expected: `check-hooks.sh` passes (script is still executable, exits 0 in a project without docs/maxi/).

- [ ] **Step 5: Commit Phase 6**

  ```bash
  git add hooks/session-start
  git commit -m "feat(f9-a): gate session-start injection on docs/maxi/ presence"
  ```

---

## Post-Plan: ADR Proposals

After the plan is written, `/maxi:plan` (Step 5) would normally invoke `/maxi:adr` for non-obvious architectural choices. Two choices in this plan qualify:

**ADR-1 — FSM status set expansion (parked + cancelled)**
The core contract of the pipeline (8 statuses) is being expanded to 10. This is a breaking change for any tooling that enumerates the status set. Architectural choice: `parked` is non-terminal with a `parked_from:` restoration field; `cancelled` is terminal. Alternatives considered: single `inactive` status (rejected — conflates reversible and irreversible); no lifecycle management (rejected — see F5).

**ADR-2 — Backflow in the pipeline (/maxi:revise)**
The first skill that makes `status:` go backwards. The pipeline has been strictly forward-only. Architectural choice: rollback is consent-gated + A+ picker; downstream artefacts are stale but not deleted; rollback cannot go below `clarified`. Alternatives considered: hard delete artefacts on rollback (rejected — loses context); always roll back to `clarified` (option C — rejected, loses phase granularity).

Invoke `/maxi:adr` twice, once per proposal, after the plan is written and before implementation begins.

---

## Verification Checklist

- [ ] `bash tests/run-all.sh` passes (all fast-tier checks green)
- [ ] `grep -r "10 maxi-native\|7 user-facing\|7 naive prompts" . --include="*.md" --include="*.sh"` → zero results
- [ ] Manually drift `skills/brainstorming/SKILL.md` → `check-sync-invariant` fails; restore → passes
- [ ] Start session in `/tmp/empty-project` (no `docs/maxi/`) → no using-maxi injection
- [ ] Start session in a maxi project → using-maxi injected, phase gating table shows `clarified` for plan, `analyzed` for implement
- [ ] With spec at `status: planned`: invoke `/maxi:revise "add offline mode"` → A+ picker proposes `clarified` → after yes: `status: clarified`, `## Clarifications` entry present, `plan.md` untouched
- [ ] Invoke `/maxi:park "deprioritized"` on active spec → `status: parked`, `parked_from:` set → `/maxi:resume` → status restored
- [ ] Invoke `/maxi:cancel "abandoned"` on active spec → `status: cancelled` (terminal) → `/maxi:resume` refuses
- [ ] `/maxi:board` shows `parked` and `cancelled` buckets (even when empty)
- [ ] Run `bash tests/run-all.sh --integration` → passes for all 15+ skills
