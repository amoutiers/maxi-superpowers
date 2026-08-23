---
slug: 0001-mechanical-closure
spec_slug: 0001-mechanical-closure
created: 2026-08-23
updated: 2026-08-23
---

# Routing Service Implementation Plan

**Goal:** Add route evaluation owned by the routing module.

**Architecture:** A small routing service evaluates validated navigation inputs. It does not read or decide subscription entitlement.

## Global Constraints

- Preserve routing ownership from the constitution.
- Add no billing or subscription behavior.
- Task `Files` entries identify expected primary edits, not an implementation allowlist.

### Task 1: Implement route evaluation

**Files:**

- Create: `src/routing/service.rs`
- Create: `tests/routing_service.rs`

1. Write a failing behavior test for viable route evaluation.
2. Implement the minimal routing service needed to pass it.
3. Run the focused test and the project check.
