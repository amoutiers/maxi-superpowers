---
adr: 001
slug: 001-use-sqlite-for-local-store
status: accepted
date: 2026-05-08
related_specs: [001-csv-to-json]
related_principles: ["II. Simplicity Over Cleverness"]
related_requirements: [FR-003, SC-002]
supersedes: null
superseded_by: null
---

# ADR-001: Use SQLite for local store

## Context

The CSV-to-JSON CLI tool processes files on a single user's machine with no
network requirement and no concurrent writers. We need lightweight persistent
storage for intermediate query results.

## Considered Options

- **SQLite** — embedded relational database, zero external dependencies, ships
  with Python stdlib
- **Redis** — fast key-value store requiring a running server process
- **In-memory dict + JSON file** — simple but no query capability

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
