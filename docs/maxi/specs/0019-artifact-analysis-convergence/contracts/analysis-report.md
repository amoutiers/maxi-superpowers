---
slug: 0019-artifact-analysis-convergence
spec_slug: 0019-artifact-analysis-convergence
created: 2026-08-01
updated: 2026-08-01
---

# Contract: Analysis Report and Reviewer Handoff

## Result rules

| Condition | Result | May set `analyzed`? |
|---|---|---|
| Deterministic validation failed | `failed` | no |
| Any CRITICAL/HIGH finding open | `failed` | no |
| Any MEDIUM/LOW finding open or invalidly disposed | `failed` | no |
| All findings resolved | `pass-clean` | only with independent review |
| No blocking finding open and at least one MEDIUM/LOW validly accepted or deferred | `pass-with-exceptions` | only with independent review |
| Passing self-review | `pass-clean` or `pass-with-exceptions` with `review_mode: self-review` | no |
| Deterministic validation stops before semantic review | `failed` with `review_mode: not-run` | no |

Constitution findings are always blocking and cannot be accepted or deferred.

## Reviewer packet

The coordinator sends an independent reviewer:

- immutable copies or exact contents of constitution, spec, plan, support artifacts, tasks, current workflow ledger, prior analysis registry, and accepted ADRs;
- the current revision map;
- the author/corrector context identifier that the reviewer must differ from;
- required passes: ambiguity, contradiction, missing requirements, unjustified decisions, constitution/ADR alignment, testability, feasibility, and codebase gaps;
- instruction to return findings only and never edit artifacts.

Reviewer response must include:

```text
review_mode: independent
reviewer_ref: <opaque context identifier>
independence_declaration: I did not author or correct the reviewed artifacts.
```

If no isolated context exists, `review_mode: self-review` and a complete copyable packet are written under `## Independent Review Handoff`.

An identifier is evidence for reconciliation, not proof of isolation. The coordinator may set `independent` only after it actually created a fresh reviewer context or consumed a separate-session handoff carrying the declaration. If deterministic validation stopped first, it sets `review_mode: not-run`, omits reviewer identity, and does not produce a semantic finding-set hash.

When `review_origin: separate-session`, that session returns a structured finding response and correction handoff but writes no project artifact. An authoring coordinator writes `analysis.md` from the response and verifies its hash. After correction, the same reviewer session is preferred for the next review because it has remained read-only with respect to every artifact in the reviewer packet.

## Reviewed finding-set integrity

Independent and self-review reports include one fenced `tsv` block immediately under `## Reviewed Finding Set`. The hashed bytes exclude the fence lines and consist of the exact header `ID<TAB>Fingerprint<TAB>Category<TAB>Severity<TAB>Owner<TAB>Locations<TAB>Summary<LF>`, followed by rows sorted by numeric finding ID and exactly one final LF. The file and block use UTF-8 without BOM and LF endings. Raw TAB, CR, LF, and NUL are forbidden inside fields. Backslash is permitted only in `\\`, `\t`, `\n`, or `\r` escapes, so decoding is unique. State, disposition evidence, delta, and Markdown fences are outside the hash.

The validator rejects malformed escapes, raw forbidden bytes, duplicate or out-of-order IDs, a missing or repeated header, CRLF, a missing final LF, or extra bytes in the hashed block. Cross-platform fixtures use one published byte sequence and expected digest with both supported SHA-256 tools.

A disposition-only update may keep the reviewer evidence only if recomputing the block yields the same SHA-256. Changing any hashed semantic field requires another semantic review. This prevents a coordinator from retaining an `independent` label after altering the reviewed findings.

## Stable findings

- Reuse an ID for an exact fingerprint match.
- Reuse an ID when the reviewer explicitly maps semantic equivalence to a prior ID.
- Allocate `max(previous IDs) + 1` for every genuinely new finding.
- Never delete registry rows. Resolved findings remain present.
- Each run labels findings `new`, `unchanged`, or `resolved` relative to the preceding report.

`## Classification Disagreements` is a separate required section with `ID`, `Prior category/severity/owner`, `Current category/severity/owner`, and `Reviewer rationale`. A disagreement exists when the reviewer maps a semantically equivalent finding to an existing ID but changes category, severity, or owner. Location-only changes are not disagreements. After a correction cycle ends in a second failed independent analysis, the report groups still-open prior IDs under `Original Unresolved`, newly allocated IDs under `Newly Discovered`, and every classification disagreement under this section; an item may appear in the first or second group and also in the disagreement section.

## Correction proposal

A failed independent report lists:

1. the complete current finding inventory;
2. each finding owner;
3. the earliest owner and rollback status;
4. every descendant that becomes stale;
5. whether a correction cycle remains available;
6. the exact batch that one explicit user `yes` will authorize.

Before finalizing a result, `analyze` asks for dispositions only for open MEDIUM/LOW findings. `accepted` records a non-empty rationale; `deferred` records an existing non-terminal follow-up spec. These fields are outside the reviewed semantic hash, so a disposition-only update may produce `pass-with-exceptions` without relabeling or altering the independent finding set. `resolved` requires a content correction and a new semantic review.

After one authorized cycle is consumed, another failed independent analysis records `correction-stopped` and performs no rollback. The coordinator appends that workflow event before writing the final failed report, then computes `validated_workflow` from the updated correction section. A new direct decision can authorize only one additional cycle.

The replay coordinator records each completed pre-analysis phase in `workflow.md`. On interruption it resumes the existing cycle from the first missing phase. It may not repeat a completed producer, ask for a second confirmation, or allocate another cycle from automatic continuation. The final passing analysis itself closes the cycle; the coordinator performs no later workflow write that would stale that report.
