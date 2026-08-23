---
adr: 0001
slug: 0001-use-sqlite-for-local-store
spec: 0001-sample-feature
status: accepted
created: 2026-05-08
updated: 2026-05-08
decider: "Maxi Project Team"
supersedes: null
superseded_by: null
---

# ADR-0001: Use SQLite for local store

## Context

The CSV-to-JSON CLI tool processes files on a single user's machine with no
network requirement and no concurrent writers. We need lightweight persistent
storage for intermediate query results.

## Decision Drivers

- No external server dependency (single-user local CLI, no provisioning)
- Zero-configuration install (aligns with "II. Simplicity Over Cleverness")
- SQL query capability required for filtering and aggregation (FR-003)

## Considered Options

- **SQLite** — embedded relational database, zero external dependencies, ships
  with Python stdlib
  - ✅ Satisfies driver: no server to provision or maintain
  - ✅ Satisfies driver: ships with Python stdlib, zero extra install
  - ✅ Satisfies driver: full SQL support for filtering and aggregation
  - ❌ Single-writer concurrency model (acceptable for local CLI)
- **Redis** — fast key-value store requiring a running server process
  - ✅ Fast, widely known
  - ❌ Violates driver: requires running server (no zero-config install)
  - ❌ No SQL query capability
- **In-memory dict + JSON file** — simple but no query capability
  - ✅ Trivially simple, zero dependencies
  - ❌ Violates driver: no SQL query capability for filtering and aggregation

## Decision

Chose SQLite because the tool is a local CLI with no server dependency,
users must install it without provisioning infrastructure, and SQL query
support is needed for filtering and aggregation over CSV-derived data.

## Consequences

- Good: zero-dependency install (stdlib `sqlite3`)
- Good: zero configuration (single `.db` file)
- Good: full SQL query capability
- Bad: single-writer concurrency model would bottleneck multi-process access

## Confirmation

No direct import of any external database driver outside `src/storage/`.
Any proposal to add a server-side database must create a new ADR that
supersedes this one.
