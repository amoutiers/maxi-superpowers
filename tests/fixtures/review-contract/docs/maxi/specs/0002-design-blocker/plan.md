---
slug: 0002-design-blocker
spec_slug: 0002-design-blocker
created: 2026-08-23
updated: 2026-08-23
---

# Entitled Routing Implementation Plan

**Goal:** Add route evaluation for subscribed users.

**Architecture:** The routing service reads the subscription record and decides whether the current account is entitled before evaluating a route.

## Global Constraints

- Keep the implementation in the routing module.
- Add a behavior test for subscribed and unsubscribed accounts.

### Task 1: Implement entitled route evaluation

**Files:**

- Create: `src/routing/service.rs`
- Create: `tests/routing_service.rs`

1. Write failing behavior tests for subscribed and unsubscribed accounts.
2. Implement subscription entitlement checks inside the routing service.
3. Run the focused tests and the project check.
