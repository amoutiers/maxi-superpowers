---
slug: 0003-adr-blocker
spec_slug: 0003-adr-blocker
created: 2026-08-23
updated: 2026-08-23
---

# Premium Routing Implementation Plan

**Goal:** Add route evaluation for premium users.

**Architecture:** The routing service reads the subscription record and decides whether the current account is entitled before evaluating a route.

### Task 1: Implement premium route evaluation

**Files:**

- Create: `src/routing/service.rs`
- Create: `tests/routing_service.rs`

1. Write failing behavior tests for entitled and non-entitled accounts.
2. Implement subscription entitlement checks inside the routing service.
3. Run the focused tests and the project check.
