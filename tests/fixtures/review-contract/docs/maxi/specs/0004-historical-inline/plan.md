---
slug: 0004-historical-inline
spec_slug: 0004-historical-inline
created: 2026-08-23
updated: 2026-08-23
---

# Route Metrics Implementation Plan

**Goal:** Expose route evaluation metrics.

**Historical context:** ADR-0002 previously assigned entitlement to routing and is now superseded. It is not an input to this design.

### Task 1: Add route metrics

1. Write a failing behavior test for one route metric.
2. Add the metric to route evaluation.
3. Run the focused tests and the project check.
