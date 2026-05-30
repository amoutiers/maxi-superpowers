# migrate-adr — Discoverer brief

> Dispatched by `migrate-adr/SKILL.md` (Step 3) unless `--import-only`. Owns one responsibility:
> surface undocumented architectural decisions from manifests, config, structure, and git history.
> Receives the exclusion context and the constitution's principles from the orchestrator; returns
> proposals in the orchestrator's Return schema. No consent/dedup logic here.

Analyze these layers:

| Layer | Examples |
|-------|---------|
| Package manifests | `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `requirements.txt`, `pom.xml`, `build.gradle` |
| Config files | `Dockerfile`, `docker-compose.yml`, `.github/workflows/`, `.gitlab-ci.yml`, `tsconfig.json`, `eslint.config.*`, `.prettierrc`, `.env.example` |
| Directory structure | monorepo vs. polyrepo, layered/hexagonal/feature-based layout, test strategy |
| Git history | `git log -n 200 --format="%H %s%n%b"` — scan the output for commits whose subject OR body contains any of: `chose`, `decided`, `switched`, `migrated`, `replaced`, `adopted`, `dropped`, `moved to`; the full message body is already available in the output |

Skip domains in exclusion context.

**Significance rubric.** Propose a decision only if it meets at least one of: it is **costly to reverse**, it **constrains future choices**, or it **was contested** (a real alternative was weighed). A bare dependency in a manifest or a git-log keyword hit is **not** sufficient on its own — drop easily-reversible, uncontested choices (e.g. a code formatter). The consent gate is the user's filter, not the only filter; do not flood it with trivia.

**Constitution linkage.** You are given the constitution's principles (Step 3). When a discovered decision relates to a named principle, set `related_principles` to that principle and note the link in the draft's `## Context`. If no principle relates, leave `related_principles: []` — never fabricate a link.

**Default frontmatter for all discovered ADRs:**

```yaml
decider: "[unknown — inferred from code analysis]"
related_specs: []
related_principles: []
related_requirements: []
supersedes: null
superseded_by: null
created: [today]
updated: [today]
```

Mark uncertain fields with `[inferred]` prefix.
