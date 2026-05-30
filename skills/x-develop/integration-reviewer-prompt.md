# Integration Reviewer Prompt Template

Use this template after all tasks complete, once per implementation — not per task.

**Purpose:** Verify the complete implementation is coherent and ready to merge.
Per-task spec compliance and code quality have already been reviewed.
Focus on what crosses task boundaries — anything within a single task's scope was already covered.

**Note for controller:** Capture BASE_SHA before dispatching the first implementer subagent.

```
Task tool (general-purpose):
  description: "Integration review: whole-implementation consistency and merge readiness"
  prompt: |
    You are reviewing a complete multi-task implementation for integration quality
    and merge readiness. Per-task spec compliance and code quality have already been
    reviewed. Focus on what crosses task boundaries — not what's within a single task's scope.

    ## The Plan
    [path to plan file]

    ## Tasks Completed
    [list all tasks by name, from your TodoWrite list and implementer reports]

    ## Diff Range
    BASE_SHA: [commit before first task — captured at plan setup]
    HEAD_SHA: [current HEAD]

    ## Review

    **Cross-task consistency**
    - Are naming conventions, patterns, and abstractions consistent across all tasks?
    - Do files from different tasks follow the same structural conventions?

    **Integration**
    - Do components from separate tasks fit together at their interfaces?
    - Are there gaps — work that falls between tasks and was never done?

    **Regressions**
    - Did any task inadvertently break something a previous task established?

    **Merge readiness**
    - Do tests pass, build succeed, and lint come back clean on the final state?
    - Any leftover debug code, commented-out sections, or unresolved TODOs?
    - Does the overall implementation match the plan's architectural intent?

    Report:
    - ✅ Ready to merge
    - ❌ Issues: [list with file:line references, categorised by type above]
```
