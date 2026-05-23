# Pipeline Flow

Visual map of the maxi command pipeline: phase sequence, status transitions, re-run loops, and delegations to vendored superpowers skills.

For the authoritative source on delegation and gating rules, see [delegation-map.md](delegation-map.md).

```mermaid
flowchart TD
    subgraph pipeline["Pipeline (maxi-native)"]
        CONSTITUTION["/maxi:constitution\n─────────────\nwrites docs/constitution.md"]
        SPECIFY["/maxi:specify\n─────────────\ndrafting → specified"]
        CLARIFY["/maxi:clarify\n─────────────\nspecified → clarified\n(interactive Q&A)"]
        PLAN["/maxi:plan\n─────────────\nclarified → planned"]
        TASKS["/maxi:tasks\n─────────────\nplanned → tasked\n(extraction only)"]
        ANALYZE["/maxi:analyze\n─────────────\ntasked → analyzed\n(7-pass audit)"]
        IMPLEMENT["/maxi:implement\n─────────────\nanalyzed → implementing → done"]
        ADR["maxi:adr\n─────────────\n(internal — never\ninvoked by user)"]
        DONE(["✓ done"])
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
| `-->` thin arrow | Re-run loop (analyze only — non-destructive) |
| `-.->` dashed arrow | Delegation to a vendored superpowers skill or internal ADR skill |

## Notes

- `/maxi:constitution` has no status prerequisite — it can run at any time.
- Every other phase is mandatory and must run in order — no phase may be skipped.
- `/maxi:analyze` is non-destructive and can be re-run at any status from `tasked` onward; status does not change after the first run.
- `maxi:adr` is internal and is never invoked directly by the user.
