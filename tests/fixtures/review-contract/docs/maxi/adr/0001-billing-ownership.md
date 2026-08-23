---
adr: 0001
slug: 0001-billing-ownership
status: accepted
created: 2026-08-23
updated: 2026-08-23
decider: "Fixture"
supersedes: null
superseded_by: null
---

# ADR-0001: Billing owns entitlement

## Decision

The billing module is the sole owner of subscription entitlement decisions.
Routing may consume a billing decision but must not read subscription records or decide entitlement.
