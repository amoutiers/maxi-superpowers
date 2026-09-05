---
slug: adapter-sample
spec_slug: adapter-sample
created: 2026-08-19
updated: 2026-08-19
revision: 7
writer_context: plan-writer
structural_contributors:
  - plan-writer
derived_from:
  - spec.md@3
---

# Adapter sample implementation plan

**Spec:** `spec.md`

**Goal:** Exercise deterministic Maxi-to-SDD projection.

**Architecture:** One projection adapter with immutable workspaces.

## Global Constraints

- Keep the implementation Bash 3.2 compatible.
- Keep all artifacts in one physical Git worktree.

### Task 1: Preserve fenced headings

**Files:**
- Create: `src/one.txt`

Write the complete first task body.

    ```markdown
### Task 99: T099 Example
    ```

Keep this line after the backtick fence.

### Task 2: Normalize tilde fences

**Files:**
- Create: `src/two.txt`

  ~~~markdown
### Task 88: This tilde-fenced heading is not executable
  ~~~

Keep this line after the tilde fence.

### Task 3: Preserve the final body

**Files:**
- Create: `src/three.txt`

Write the complete third task body through end of file.
