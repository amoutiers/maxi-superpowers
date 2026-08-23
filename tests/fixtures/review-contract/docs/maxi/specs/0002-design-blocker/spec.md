---
slug: 0002-design-blocker
created: 2026-08-23
updated: 2026-08-23
status: planned
parked_from: null
related_adrs: []
---

# Feature Specification: Entitled Routing

## Requirements

- **FR-001**: The routing module MUST expose route evaluation from navigation inputs.
- **FR-002**: The billing module MUST remain the sole owner of subscription entitlement decisions.

## Success Criteria

- **SC-001**: A behavior test proves that valid navigation inputs produce a viable route result.
- **SC-002**: Routing delegates entitlement decisions to billing rather than owning them.
