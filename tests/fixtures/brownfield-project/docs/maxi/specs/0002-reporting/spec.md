---
slug: 0002-reporting
created: 2026-05-02
updated: 2026-05-02
status: done
parked_from: null
---

# Feature Specification: Reporting

A forward-pipeline (NOT reverse-engineered) spec with no `origin:` marker and no
`file:line` references. Used to test the name token-set fallback (FR-005): a
candidate named "reporting" must be excluded by name even though there are no
code refs to match on.

## Requirements

### Functional Requirements

- **FR-001**: System MUST produce monthly reports.
- **FR-002**: Users MUST be able to export reports as CSV.
