# Pipeline Flow

Visual map of the maxi command pipeline: phase sequence, status transitions, re-run loops, and delegations to vendored superpowers skills.

For the authoritative source on delegation and gating rules, see [delegation-map.md](delegation-map.md).

```mermaid
flowchart TD
    subgraph row1[" "]
        direction LR

        subgraph pipeline["Main Pipeline (maxi-native)"]
            CONSTITUTION["/maxi:constitution\n─────────────\nwrites docs/maxi/constitution.md"]
            SPECIFY["/maxi:specify\n─────────────\ndrafting → specified"]
            CLARIFY["/maxi:clarify\n─────────────\nspecified → clarified\n(interactive Q&A)"]
            PLAN["/maxi:plan\n─────────────\nclarified → planned"]
            TASKS["/maxi:tasks\n─────────────\nplanned → tasked\n(extraction only)"]
            ANALYZE["/maxi:analyze\n─────────────\ntasked → analyzed\n(7-pass audit)"]
            IMPLEMENT["/maxi:implement\n─────────────\nanalyzed → implementing → done"]
            ADR["maxi:adr\n─────────────\n(internal — never\ninvoked by user)"]
            DONE(["✓ done"])
        end

        subgraph lifecycle["Lifecycle Skills (maxi-native)"]
            PARK["/maxi:park\n─────────────\nany active → parked\n(stores parked_from:)"]
            RESUME["/maxi:resume\n─────────────\nparked → parked_from\n(clears parked_from:)"]
            CANCEL["/maxi:cancel\n─────────────\nany active → cancelled\n(terminal)"]
            REVISE["/maxi:revise\n─────────────\nrollback to earlier phase\n(A+ picker, consent-gated)"]
            BOARD["/maxi:board\n─────────────\nread-only kanban\n(no state change)"]
            PARKED(["⏸ parked\n(non-terminal)"])
            CANCELLED(["✗ cancelled\n(terminal)"])
        end
    end

    subgraph vendored["Superpowers (vendored)"]
        BRAINSTORMING["maxi:brainstorming"]
        WRITING_PLANS["maxi:writing-plans"]
        EXECUTING_PLANS["maxi:executing-plans"]
        CODE_REVIEW["maxi:requesting-code-review"]
    end

    %% Main pipeline transitions (thick arrows)
    CONSTITUTION ==> SPECIFY
    SPECIFY ==>|"specified → clarified"| CLARIFY
    CLARIFY ==>|"clarified → planned"| PLAN
    PLAN ==>|"planned → tasked"| TASKS
    TASKS ==>|"tasked → analyzed"| ANALYZE
    ANALYZE ==>|"analyzed → implementing"| IMPLEMENT
    IMPLEMENT ==> DONE

    %% Analyze re-run loop
    ANALYZE -->|"Pass G CRITICAL →\nre-run after fix"| ANALYZE

    %% Lifecycle transitions (thin arrows)
    PARK -->|"any active status"| PARKED
    PARKED -->|"restores parked_from status"| RESUME
    RESUME -->|"back into pipeline\nat prior status"| CLARIFY
    CANCEL -->|"any active status"| CANCELLED
    REVISE -->|"rollback: clarified/planned/\ntasked/analyzed"| CLARIFY

    %% Invisible links to anchor vendored below both blocks
    DONE ~~~ BRAINSTORMING
    DONE ~~~ WRITING_PLANS
    CANCELLED ~~~ EXECUTING_PLANS
    CANCELLED ~~~ CODE_REVIEW

    %% Delegations to superpowers (dashed arrows)
    SPECIFY -.->|"delegates"| BRAINSTORMING
    PLAN -.->|"delegates"| WRITING_PLANS
    PLAN -.->|"arch choice detected"| ADR
    IMPLEMENT -.->|"delegates"| EXECUTING_PLANS
    IMPLEMENT -.->|"unplanned fork"| ADR
    IMPLEMENT -.->|"delegates"| CODE_REVIEW
```

## Legend

| Arrow style | Meaning |
|---|---|
| `==>` thick arrow | Main pipeline transition (label = status change) |
| `-->` thin arrow | Re-run loop or lifecycle state transition |
| `-.->` dashed arrow | Delegation to a vendored superpowers skill or internal ADR skill |

## Notes

- `/maxi:constitution` has no status prerequisite — it can run at any time.
- Every forward phase is mandatory and must run in order — no phase may be skipped.
- `/maxi:analyze` is non-destructive and can be re-run at any status from `tasked` onward; status does not change after the first run.
- `maxi:adr` is internal and is never invoked directly by the user.
- **Lifecycle skills** (`park`, `resume`, `cancel`, `revise`) operate on any in-flight spec — they are orthogonal to the main forward pipeline.
- `/maxi:revise` is the only skill that makes `status:` go backwards. `RESUME` restores to the exact prior status stored in `parked_from:` — the `CLARIFY` node in the diagram is illustrative.
- `/maxi:board` is read-only — it never changes status.

## FSM Status Set

```
drafting → specified → clarified → planned → tasked → analyzed → implementing → done
                                                                         ↕             ↕
                                                                      parked      cancelled
```

`parked` is reachable from any active status (via `/maxi:park`) and restores to its prior status (via `/maxi:resume`). `cancelled` is terminal.
