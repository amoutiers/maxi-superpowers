# Convergent design operation

Shared coordination instructions, loaded from the installed review skill. This is not a new command or artifact owner. Context consists of the actual initiating user request and message identity, canonical target, destination, settled choices/approval and owner-only returns. Never persist transient context in spec frontmatter or plan Global Constraints.

## Destination and ownership

| Request | Sequence | Destination |
| --- | --- | --- |
| Bare specify or spec-only creation | approved design → spec-author → actual clarify scan | clarified |
| Initial design validation | author → clarify → owner-only plan → bounded review round | planned plus current verdict |
| Explicit design revision | reuse change → authorized rollback/note → affected author/clarify → owner-only plan → bounded review round | planned plus current verdict |
| Draft-only, edit-only or phase-only | requested owner only | explicit narrower stop |
| Public review | report-only review once | report only, no correction |
| Standalone initial plan | plan owner → one initial report-only review | planned plus verdict, no correction |

The coordinator invokes owners and does not take over their writes. Spec-author creates or explicitly edits requirements; clarify resolves real ambiguities; plan delegates to writing-plans; review alone writes the report through design-contract.sh. Revise alone owns its rollback/note and monotone reopening watermark. Owners receive the actual request, canonical paths, destination, settled choices and an instruction to return after their own write. They never recursively start a coordinator. Suppress plan's nested initial review only under the outer coordinator. Never invoke tasks, analyze, or implement as a consequence of completing this operation.

Before requesting review, check the whole changed flow: every producer, mutation, persisted representation, reload, consumer and verification path. Reconcile all affected findings together. An empty clarification scan asks zero questions; real independent choices are grouped up to three per turn, dependent choices wait. Reuse unchanged approval without suppressing real new choices. ADR changes still require separate explicit approval through x-adr.

## Bounded round and continuity

1. Establish the actual initiating user order and destination from the conversation, then hash the exact request bytes as `request_sha256`. Prefer an actual native message ID, or an actual session ID plus stable initiating user-turn position, for `operation_id` (hash the identity and request with an unambiguous separator). No hidden UUID is mandatory. When native identity is unavailable, only for an established new user order use a local discriminator: hash the canonical target path, exact request bytes and the exact pre-reservation report SHA-256 (or `absent` for a missing report), with unambiguous separators. This discriminator records a local order; it does not authenticate the user. Never invent a narrative ordinal or treat an agent-written authorization claim as a fresh request. If the actual order or destination cannot be established, stop for that specific missing information. On resume always reuse the stored operation ID; never recompute the fallback from the changed report. Missing continuation evidence stops and cannot be reconstructed or reset through this fallback.
2. Read existing report state through the loaded helper's `operation` mode before continuation. Prior to first reservation there is no consumed pass. After reservation the canonical report is mandatory evidence: missing, malformed or incompatible state stops; never rebuild it from chat or Git. A matching `reserved` pass may only recover/wait for its recorded reviewer result, never redispatch. If unrecoverable, ask the review owner to stop it.
3. Invoke the report owner in `coordinated` mode for one pass. Only successful reservation permits dispatch. Pass one uses a fresh independent reviewer with identity-only handshake before reservation and review payload afterward. The handshake is not a review. Save the harness-returned identity, not an invented alias.
4. An approved verified pass finishes. A rejected first pass returns all findings to the affected owners once. Correct the complete flow, preserving report and previous findings. Invoke the report owner for the same operation's second pass, reusing the original reviewer where supported. If that reviewer is unavailable after completed rejection, allocate a fresh reviewer for the unused second slot and supply the complete new snapshot plus all prior findings. Never replace a reviewer whose reserved pass may already have run.
5. A rejected second pass stops. Malformed output, freshness failure or unrecoverable reserved reviewer also stops through the report owner; no automatic replacement review. Report unresolved blockers and changed strategy needed. Interruption never resets the two-pass allowance.
6. Public review has `report-only` mode and one pass with no correction. A different explicit user request may stop an old active operation before starting a new one; never infer replacement from agent desire to obtain more slots. A new operation after terminal failure requires an actual new request and a stated changed strategy.

All report mutations belong to review and use the installed helper with exact expected report hashes. The existing report preserves prior findings with byte-length-framed history, not a new ledger. Existing exact hashes, complete decision-input digest, atomic candidate publication, nineteen skills, ten FSM states and three review gates remain unchanged. A current approval is useful evidence, not authorization for downstream work.
