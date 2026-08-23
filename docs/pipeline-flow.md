# Pipeline Flow

Visual map of the maxi command pipeline: phase sequence, status transitions, re-run loops, and delegations to vendored superpowers skills.

For the authoritative source on delegation and gating rules, see [delegation-map.md](delegation-map.md).

```mermaid
flowchart TD
    subgraph row1[" "]
        direction LR

        subgraph lifecycle["Lifecycle Skills (maxi-native)"]
            PARK["/maxi:park\n─────────────\nany active → parked\n(stores parked_from:)"]
            RESUME["/maxi:resume\n─────────────\nparked → parked_from\n(clears parked_from:)"]
            CANCEL["/maxi:cancel\n─────────────\nany active → cancelled\n(terminal)"]
            REVISE["/maxi:revise\n─────────────\nrollback to earlier phase\n(A+ picker, consent-gated)"]
            BOARD["/maxi:board\n─────────────\nread-only kanban\n(no state change)"]
            PARKED(["⏸ parked\n(non-terminal)"])
            CANCELLED(["✗ cancelled\n(terminal)"])
        end

        subgraph pipeline["Main Pipeline (maxi-native)"]
            CONSTITUTION["/maxi:constitution\n─────────────\nwrites docs/maxi/constitution.md"]
            SPECIFY["/maxi:specify\n─────────────\ndrafting → specified"]
            CLARIFY["/maxi:clarify\n─────────────\nspecified → clarified\n(interactive Q&A)"]
            PLAN["/maxi:plan\n─────────────\nclarified → planned"]
            DESIGN_REVIEW{{"design review\ndedicated artifact brief;\ninitially plan-owned"}}
            TASKS["/maxi:tasks\n─────────────\nplanned → tasked\n(extraction only)"]
            ANALYZE["/maxi:analyze\n─────────────\ntasked → analyzed\n(7-pass audit)"]
            IMPLEMENT["/maxi:implement\n─────────────\nanalyzed → implementing → done"]
            DEVELOP["/maxi:x-develop\n─────────────\nprojection + upstream SDD\n+ terminal receipt"]
            READY{{"READY_TO_FINISH\nvalidated receipt gate"}}
            ADR["x-adr\n─────────────\n(internal ADR\ncreate/amend)"]
            REVIEW["/maxi:review\n─────────────\n(explicit re-review;\nno status change)"]
            DONE(["✓ done"])
        end
    end

    subgraph vendored["Superpowers (vendored)"]
        BRAINSTORMING["/maxi:brainstorming"]
        WRITING_PLANS["/maxi:writing-plans"]
        CODE_REVIEW["/maxi:requesting-code-review"]
        BRANCH_FINISH["/maxi:finishing-a-development-branch"]
    end

    %% Main pipeline transitions (thick arrows)
    CONSTITUTION ==> SPECIFY
    SPECIFY ==>|"specified → clarified"| CLARIFY
    CLARIFY ==>|"clarified → planned"| PLAN
    PLAN ==>|"planned; one design review"| DESIGN_REVIEW
    DESIGN_REVIEW ==>|"approved current spec + plan"| TASKS
    TASKS ==>|"tasked → analyzed"| ANALYZE
    ANALYZE ==>|"analyzed → implementing"| IMPLEMENT
    IMPLEMENT ==>|"delegates execution"| DEVELOP
    DEVELOP ==>|"hash-bound terminal evidence"| READY
    READY ==>|"implement persists done"| DONE
    DONE -.->|"after done only"| BRANCH_FINISH

    %% Analyze re-run loop
    ANALYZE -->|"Pass G CRITICAL →\nre-run after fix"| ANALYZE

    %% Lifecycle transitions (thin arrows)
    PARK -->|"any active status"| PARKED
    PARKED -->|"restores parked_from status"| RESUME
    RESUME -->|"back into pipeline\nat prior status"| CLARIFY
    CANCEL -->|"any active status"| CANCELLED
    REVISE -->|"rollback: clarified/planned/\ntasked/analyzed; specified\nfor source-spec gaps"| CLARIFY

    %% Invisible links to anchor vendored below both blocks
    DONE ~~~ BRAINSTORMING
    DONE ~~~ WRITING_PLANS
    CANCELLED ~~~ CODE_REVIEW

    %% Delegations to superpowers (dashed arrows)
    SPECIFY -.->|"delegates"| BRAINSTORMING
    PLAN -.->|"delegates"| WRITING_PLANS
    PLAN -.->|"arch choice detected"| ADR
    IMPLEMENT -.->|"unplanned fork"| ADR
    DEVELOP -.->|"upstream SDD final review"| CODE_REVIEW
    REVIEW -->|"explicit fresh artifact review"| DESIGN_REVIEW
    PLAN -->|"explicit correction\nreturns to planned"| PLAN
    TASKS -->|"explicit correction\nreturns to tasked"| TASKS
```

## Legend

| Arrow style | Meaning |
|---|---|
| `==>` thick arrow | Main forward route (label states a status change or gate condition) |
| `-->` thin arrow | Re-run loop or lifecycle state transition |
| `-.->` dashed arrow | Delegation to a vendored superpowers skill or internal skill |
| `{...}` gate | Required external review handoff; no status transition |

## Notes

- `/maxi:constitution` has no status prerequisite — it can run at any time.
- Every forward phase is mandatory and must run in order — no phase may be skipped.
- `/maxi:analyze` is non-destructive and can be re-run at any status from `tasked` onward; status does not change after the first run.
- `x-adr` is internal and is never invoked directly by the user. Every new ADR records its creating spec through a direct `spec` link or uses `spec: null`. At every active status (`drafting` through `implementing`), a detected change to an accepted ADR linked to the current spec triggers an agent-proposed active-spec amendment: `x-adr` shows the full amended ADR and exact diff, then writes only after explicit approval. Missing or null links and specs at `done`, `parked`, or `cancelled` use closed-spec supersession instead. This cross-cutting route does not add a status or transition.
- The initial design review is invoked once by `/maxi:plan` after its first normal write. `/maxi:review` is only for an explicit re-review after a correction or stale record. It dispatches the dedicated `skills/review/design-reviewer.md` artifact brief with the exact current `spec.md`, `plan.md`, and accepted ADRs named by `related_adrs`, then writes `reviews/design-review.md` only for one exact terminal verdict; `/maxi:tasks` stops without writing when that approval is missing or stale. Task `Files` lists are expected primary edits, not implementation allowlists, so mechanical closure is nonblocking unless the reviewed design itself must change.
- The 19 Maxi-native skills: 13 user-facing, 2 internal, 1 session, and 3 migration skills. The 10-state FSM remains unchanged. `/maxi:x-develop` maps canonical Maxi `TNNN` tasks to an immutable SDD `Task N` projection. Upstream SDD owns task review, fix rounds, and the final implementation review. `/maxi:x-develop` is the sole incremental Maxi checkbox owner; `/maxi:implement` validates that every task is checked and alone persists `implementing → done`. Branch finishing starts only after Maxi has recorded `done`.
- Upstream SDD owns the only whole-branch review. Before dispatch, `/maxi:x-develop` persists the immutable initial task-selection anchor in the ordinary SDD ledger. It also persists the harness-issued final-reviewer identity, regenerates the Git review package byte-for-byte, and returns `READY_TO_FINISH` only with a valid hash-bound terminal receipt. `/maxi:implement` alone then persists `done`; it never dispatches a duplicate final review.
- Only canonical annotated upstream completion records acquit tasks; bare or malformed completion lines fail closed. The accepted annotations are `review clean` or a positive `K parked`, with exactly two seven-hex commit IDs.
- A null fix package requires exactly `**Ready to merge?** Yes`; a non-null byte-exact fix package requires the initial `**Ready to merge?** With fixes` plus exactly `**Fix round:** All findings addressed, no new Critical/Important breakage`.
- Every projection's exact distributed bytes are SHA-256-bound by its ordinary SDD ledger; missing, duplicate, malformed, or mismatched projection-byte anchors fail closed across the current and predecessor lineage.
- Removing an anchored incomplete `TNNN` during structural correction fails before successor creation and leaves the active-projection pointer unchanged.
- Complete ledger lines containing `Ruling:` are preserved byte-for-byte in lineage order and hash-bound by the terminal receipt.
- The three fixed boundaries are design review after the normal plan write, readiness review in `/maxi:analyze` before implementation, and the upstream SDD final implementation review. They are gates, not statuses or automatic phase transitions.
- **Lifecycle skills** (`park`, `resume`, `cancel`, `revise`) operate on any in-flight spec — they are orthogonal to the main forward pipeline.
- `/maxi:revise` is the only skill that makes `status:` go backwards. `RESUME` restores to the exact prior status stored in `parked_from:` — the `CLARIFY` node in the diagram is illustrative.
- `/maxi:revise` offers the exceptional `specified` rollback only for a demonstrated missing or ambiguous requirement in the source spec; it resumes at `clarify` and never reruns `specify`.
- `/maxi:board` is read-only — it never changes status.
- **Ingress skills** (`migrate-from-speckit`, `migrate-from-brownfield`) document already-implemented code, so they create specs at a terminal/advanced status on creation rather than walking the forward pipeline. They mark provenance (`origin:` / inferred status) and never alter forward-spec gating — sanctioned by the constitution's migration-ingress clause and [ADR-0011](maxi/adr/0011-migration-ingress-terminal-status.md). No new FSM status is introduced.

## FSM Status Set

The 10-state FSM remains unchanged. Review boundaries do not add states or transitions.

```
drafting → specified → clarified → planned → tasked → analyzed → implementing → done
                                                                         ↕             ↕
                                                                      parked      cancelled
```

`parked` is reachable from any active status (via `/maxi:park`) and restores to its prior status (via `/maxi:resume`). `cancelled` is terminal.
