---
slug: 0001-auth
created: 2026-05-01
updated: 2026-05-01
status: done
origin: reverse-engineered
source_sha: deadbeef
parked_from: null
---

# Feature Specification: Auth

A reverse-engineered baseline used to test the exclusion (idempotency) logic.

## Requirements

### Functional Requirements

- **FR-001**: Validates credentials (src/auth/login.js:6)
- **FR-002**: Issues a session token (src/auth/login.js:10)
