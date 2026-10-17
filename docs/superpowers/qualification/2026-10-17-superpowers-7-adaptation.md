# Superpowers v7.0.0 adaptation: local qualification

The four installed v7 intake cases, initial design validation, revision and execution-continuity qualification pass on the source identities below. Antigravity CLI discovery probes also pass within their observed scope. Native validators, deterministic adapter checks and installed-agent behavior are reported separately.

## Candidate and installed identities

The import contains 15 upstream skills from Superpowers v7.0.0, subtree split `bb92a77741419a4ab5f06e711a283343f1ada0c3`, alongside 19 Maxi-native skills. The vendored tree is `4ac675daa3415bc836f707c7e60237ac7b66c7d5`. The ten FSM states and three fixed review boundaries remain unchanged.

Actual runs used Codex CLI 0.163.0 on Darwin 27.0.0 arm64. Each runner installed a separate byte-checked local marketplace snapshot and used external Git fixtures with retained native sessions. Initial source was `b583984e34670bc5505033946eb84ac9a9be56a9`; the first collector correction was `6c1c007a1a890417aaf72ab182b9129c4c8d4d6c`. The runtime clarification source is `d67f87495b9e6b4eebb4eace3d856053ffa5b8cc`; the collection-protocol candidate is `3c866334156bf5f15bba0d7a3f59cea9197f82de`.

The first two sources have the same 122 skill/support files, with sorted manifest SHA-256 `d5f4f1e71147257b9ad359e068f3bb211a5623ef6e38078c7e12016579ba8b22`. Source d67 changes only `using-maxi/SKILL.md` and `x-develop/SKILL.md` in that runtime tree. The resulting 122-file manifest SHA-256 is `01e70f50958d7336dae0158d58219ddad36966f7ab239d58efd68ba3ec60dac3`. The manifest encoding is sorted `sha256  relative-path\n` lines.

The collection-protocol candidate changes five test-harness files from d67. All 122 runtime files equal the retained revision installation, the pre-cleanup comparison found both 124-file Antigravity candidate packages equal to the final candidate, and Codex/native manifests and assets are unchanged. The [byte comparison](../../../.superpowers/sdd/integration/20261017093852-task5-native/protocol-candidate-identity-comparison.json) justifies retaining successful revision and native results under their original d67 source identity. All prior sources and [runtime transitions](../../../.superpowers/sdd/integration/20261017093852-task5-native/final-candidate-runtime-transition.json) remain separate.

## Actual installed behavior

The final Codex fixtures use an explicit evidence-collection protocol: each required instruction, prompt and canonical document is read through a separate successful native command containing only `cat` with a literal absolute operand. Delegates receive the same recording instruction, and searches/diagnostics run separately. This guided collection bounds what is qualified. Shell read forms outside the finite checker remain an instrumentation limit; prior rejected traces keep their original failed outcomes.

| Command or case | Source and actual exit | Retained evidence |
|---|---|---|
| `bash tests/integration/run-codex-design-test.sh v7` | `3c866334`: exit 0; intent, builder, skip and draft-only all verified | [v7](../../../.superpowers/sdd/integration/20261017110937-79676/design-v7) |
| `bash tests/integration/run-codex-design-test.sh design-validation` | `3c866334`: exit 0; approved, one builder, one reviewer and one reservation | [initial design](../../../.superpowers/sdd/integration/20261017110937-79675/design-design-validation/design-validation) |
| `bash tests/integration/run-codex-design-test.sh revision` | `d67f8749`: exit 0; approved, one reservation and one reviewer | [revision](../../../.superpowers/sdd/integration/20261017104114-68977/design-revision/revision) |
| `bash tests/integration/run-codex-upgrade-test.sh` | `3c866334`: exit 0; installed upgrade lifecycle verified | [upgrade](../../../.superpowers/sdd/integration/20261017110937-79677/upgrade) |

The upgrade's six native stages exit 0: design, tasks, readiness, first task, resume and migration. Its independent checker verifies first-task pause, pending-only same-session resume, actual task/final reviewer identities, byte-exact Git packages, terminal proof before done, local branch retention and completed-v1 continuation with a fresh final review over the original history. The main fixture reviewed range is `172fa132d4445df81431ffc8633ee0e040e3defb..b4c3d2a19ea1026bafd4dd87bfeac5a40bbfe041`; migration retains `b28c516a8023acbb059e83b403f2d3cf13cca716..1bee70942e8ec5264acfacc543977b4b225f1dd6`.

| Review role | Harness-issued identity |
|---|---|
| Design | `/root/design_reviewer` |
| Task 1 / Task 2 | `/root/task1_reviewer` / `/root/task_two_reviewer` |
| Main final review | `/root/whole_branch_reviewer` |
| Completed-v1 final review | `/root/final_reviewer` |

For both final reviews, successful native commands resolve full commit IDs and generate and compare the persisted package and a separate candidate before the first substantive dispatch. The first native package read already contains the unchanged canonical full-ID package, and each complete native review output appears verbatim in its final-review report. The [first-read and preparation evidence](../../../.superpowers/sdd/integration/20261017093852-task5-native/protocol-first-canonical-package-read-proof.json) supplies behavioral GREEN for this x-develop clarification. Each reviewer has one identity handshake and one substantive review; no repair dispatch is needed. Task-review packages retain the upstream `BASE HEAD` invocation and are separately verified byte-for-byte.

## Final fix verification and durable retention

The final review identified two evidence gaps: the builder checker accepted reads without a returned result, and cleanup had removed dependencies needed to inspect both historical upgrade receipts autonomously. Candidate `0e8fd72fef0a6541eee9c7cdf3e212f554a54667` strengthens builder completion and adds durable proof capture. Its fresh installed runs used unchanged product/runtime bytes. Revision and native Antigravity evidence retain their actual d67 identity; the [130-file comparison](../../../.superpowers/sdd/0027-superpowers-v7-adaptation-v2-p-cbb06daaf353-t-991c9e6f30ee-sdd/final-fix-r16-runtime-comparison.json) confirms consumed runtime/config equality with both d67 and 0e8, including all 122 skill/support files.

A required builder now has one completed native final message joined to its one matching `task_complete`, in the same identified child and turn, after both complete required reads. Missing, failed, inconsistent, duplicated, foreign-thread or reordered results reject. The upstream free-form questions/results remain valid; the checker adds no builder verdict format.

| Fresh native group on `0e8fd72` | Original result, preserved | New strict checker replay |
|---|---|---|
| [Four v7 cases](../../../.superpowers/sdd/integration/20261017121134-94943/design-v7) | Native and collector exit 0 for all four | All pass, including three completed required builders |
| [Design validation](../../../.superpowers/sdd/integration/20261017121134-94942/design-design-validation/design-validation) | Native exit 0, collector exit 1: successful reservation uses a literal Python helper binding outside the recognized form | Passes after recognition of that exact finite program, with reassignment, wrong-helper and ambiguous-call rejection |
| [Upgrade lifecycle](../../../.superpowers/sdd/integration/20261017121134-94944/upgrade) | Six native stages exit 0, collector exit 1: task/final actors are children of the root-allocated SDD controller | Passes after native allocation/result joins use the real emitter, unique returned identities and retained parent/thread metadata |

These are new offline verifications of unchanged native traces, not new native runs or rewritten exits. The [checker identity](../../../.superpowers/sdd/0027-superpowers-v7-adaptation-v2-p-cbb06daaf353-t-991c9e6f30ee-sdd/final-fix-r16-checker-identity.json) binds its three consuming files with manifest SHA-256 `eedb44c9525eb6032d555127cd06a56bcd742ee55161dcf2076eef9bd789a4a2`. [Original outcomes](../../../.superpowers/sdd/0027-superpowers-v7-adaptation-v2-p-cbb06daaf353-t-991c9e6f30ee-sdd/final-fix-frozen-native-results.json), [design replays](../../../.superpowers/sdd/0027-superpowers-v7-adaptation-v2-p-cbb06daaf353-t-991c9e6f30ee-sdd/final-fix-r16-design-replays.json) and the [upgrade replay](../../../.superpowers/sdd/0027-superpowers-v7-adaptation-v2-p-cbb06daaf353-t-991c9e6f30ee-sdd/final-fix-r16-upgrade-replay.log) remain distinct. No native retry was needed for these complete traces.

The upgrade runner rejected before automatic capture. A separately recorded conservatory capture then retained the full proof without changing that outcome. Its initial archive verification also rejected the nested dispatch join. The corrected shared join now makes `python3 tests/integration/upgrade-cases/retain-evidence.py verify .superpowers/sdd/integration/20261017121134-94944/upgrade` return `archive_verified`, exit 0, with both receipts and four Git packages verified. The [verification result](../../../.superpowers/sdd/0027-superpowers-v7-adaptation-v2-p-cbb06daaf353-t-991c9e6f30ee-sdd/final-fix-r16-archive-replay.log) records these complete receipt SHA-256 values:

- Main pre-done receipt: `7fb359c5868a257fef53fa27b460a0249316acc4c710df0f4611ce251a26aa37`.
- Completed-v1 migration receipt: `6b138fd5ab576e858f4c3962d0f17dccb61492495d03ced01730810853070d0f`.

The durable inspection unit is the complete [upgrade output directory](../../../.superpowers/sdd/integration/20261017121134-94944/upgrade), including `retained-proof/`, native stages and the byte-checked installed snapshot. Its [manifest](../../../.superpowers/sdd/integration/20261017121134-94944/upgrade/retained-proof/manifest.json), SHA-256 `69809a2b34bacd710f3465d824b96a50458b7103122f6bfef6e8ba78e35b6ac3`, binds 86 captured project/Git artifacts and 207 adjacent dependencies. Three bundles preserve main-final, main-terminal and migration Git objects/refs; canonical paths and event-time docs, projections, ledgers, final reports, packages and receipts retain their exact bytes. Runtime homes, authentication files and Git config are excluded. Hash verification and byte-exact regeneration use only archived dependencies. Disposable-fixture tests remove the external roots, verify the archive, restore only missing controlled paths and observe both unchanged installed terminal contracts returning `READY_TO_FINISH`; outside-root paths, overwrite, symlinks and changed dependencies reject. Fresh native fixtures remain preserved through archive validation. No missing historical receipt was reconstructed.

The final source fast-tier and documentation checks are recorded in the [final fix report](../../../.superpowers/sdd/0027-superpowers-v7-adaptation-v2-p-cbb06daaf353-t-991c9e6f30ee-sdd/final-fix-report.md). This closes the two evidence corrections for the controller's one scoped re-review; it does not claim review approval, release readiness or publication.

## Preserved failed runs

All original exits and raw outputs remain unchanged. No unchanged retry or synthetic proof repair was used.

| Source and command | Original exit and cause | Evidence |
|---|---|---|
| `b583984e`, v7 | 1; intent and builder rejected by collection, skip and draft-only pass | [original v7](../../../.superpowers/sdd/integration/20261017093832-8047/design-v7) |
| `b583984e`, initial design-validation | 1 after native exit 0; finite installed-owner read syntax not recognized | [original design](../../../.superpowers/sdd/integration/20261017093833-8195/design-design-validation/design-validation) |
| `b583984e`, upgrade | 1 at assembly after six native stages exit 0; joined task-package read not recognized, plus genuinely absent successful read proofs and excess final-review follow-ups | [original upgrade](../../../.superpowers/sdd/integration/20261017093835-8857/upgrade) |
| `6c1c007`, builder and design-validation | 1 each after native exit 0; absolute prompt plus cwd-bound relative canonical spec not recognized | [builder](../../../.superpowers/sdd/integration/20261017100722-39573/design-v7-builder/v7-builder), [design](../../../.superpowers/sdd/integration/20261017100723-39997/design-design-validation/design-validation) |
| `6c1c007`, upgrade | 1 at assembly after six native stages exit 0; task verdict presentation not recognized and migration report omits a line from a native confirmation | [second upgrade](../../../.superpowers/sdd/integration/20261017100724-40215/upgrade) |
| `d67f8749`, v7 | 1 after native exits 0; builder and draft-only pass, intent successful-read evidence absent after a compound command exits 1, skip uses an unrecognized cwd-changing form | [third v7](../../../.superpowers/sdd/integration/20261017104111-68348/design-v7) |
| `d67f8749`, design-validation | 1 after native exit 0; successful variable-bound full reads are outside the finite collection grammar | [third design](../../../.superpowers/sdd/integration/20261017104113-68479/design-design-validation) |
| `d67f8749`, upgrade | 1 after six native stages exit 0; first-task and resume owner reads use variable-bound forms outside the collection grammar | [third upgrade](../../../.superpowers/sdd/integration/20261017104115-69458/upgrade) |

The b583 and 6c upgrade runs failed before publishing `evidence.json`. The d67 run published `evidence.json`, then the independent checker rejected its installed owner-read proof; its empty `result.json` is not a success. The initial missing successful `using-maxi` and canonical reviewer reads and bounded final-review dispatch were verified in later runs. Each original failure keeps its actual outcome.

The d67 [23 diagnostic subgates](../../../.superpowers/sdd/integration/20261017093852-task5-native/d67-upgrade-remaining-gate-inventory.json) pass separately. All four [first substantive native package reads](../../../.superpowers/sdd/integration/20261017093852-task5-native/d67-first-canonical-package-read-proof.json) contain the complete byte-exact canonical package with full commit IDs, and the complete native final-review outputs are retained. This supplies partial behavioral evidence for the production clarification, without converting the rejected d67 run into an aggregate pass. Raw traces and [exhaustive diagnostics](../../../.superpowers/sdd/integration/20261017093852-task5-native) remain local.

## Native hosts and deterministic checks

| Check | Actual result | Scope |
|---|---|---|
| `agy plugin validate . --json` | Exit 0; 34 skills, no findings | Native package validator only |
| Two flattened workspace-local native packages | Byte-identical candidate skills/assets/manifest, validator exit 0 | Separate project and nonproject fixtures |
| Two actual `agy --sandbox --mode plan --output-format stream-json --print-timeout 90s --print` probes | Exit 0/SUCCESS | Completed native `view_file` calls report line and byte counts for candidate `using-maxi` and other instruction files; returned byte counts match the source, and native directory checks observe presence/absence of `docs/maxi/` |
| `bash tests/check-hooks.sh` | Exit 0 | Full root/wrapper bootstraps with empty and ordinary PATH, host precedence, outside-project silence and argument/status preservation |
| `bash tests/check-hermes-plugin.sh` | Exit 0 | Adapter behavior through test contexts in clone/flat layouts; no native Hermes runtime is available |
| `bash tests/run-all.sh` on candidate `3c866334` | Exit 0; 37 groups | [Fast log](../../../.superpowers/sdd/0027-superpowers-v7-adaptation-v2-p-cbb06daaf353-t-991c9e6f30ee-sdd/task-5-recording-protocol-fast.log), separate from installed behavior |

Both native Antigravity conversations use source d67. Their identities are `578d1e9a-5c6f-486d-b962-b25b13e476b1` (project) and `37a63278-8c94-4cca-9ab8-5adb9fff7b5e` (nonproject). The prompts contain no candidate skill paths. Both native conversations inspect the workspace candidate. Five completed `view_file` calls per conversation identify candidate files and return matching line/byte counts; the stream does not expose the full file contents. The probes left the older global user installation in place. Their recorded before/after user plugin registry is identical, and both candidate packages remained byte-identical through the probes. This qualifies the observed local CLI discovery and project check during a conventions-inspection conversation. It does not qualify automatic activation in every conversation, Antigravity IDE behavior or an end-to-end development lifecycle. The native CLI binary SHA-256 is `a4502aaf310b2fd6eb657fcfec2fcc31a690fbbd0c2d14c8eefbb556409024ce`.

Native observations, exact commands/exits, file hashes and conversation identities are retained under source d67 in [native evidence](../../../.superpowers/sdd/integration/20261017104116-task5-final-native/results.json) and [completed tools](../../../.superpowers/sdd/integration/20261017104116-task5-final-native/native-observed-outcomes.json). No native Windows execution was performed; the `cmd.exe` regression explicitly skips on this host. Other supported hosts were not newly qualified by this task. Deterministic mutations and previously recorded host results are not new live evidence.

## Documentation and closure

The documentation consistency review computed 19 native skills, 15 upstream skills, the ten statuses and matching inventories of 36 `check-*.sh` scripts (the timeout supervisor makes 37 fast groups); it compared all nine phase-gating rows, the Mandatory Sync five, public command inventory and maintained architecture paths. The source-bound semantic review and deterministic checks agree. The qualification links add no gate, transition or ownership change. Historical specifications, ADRs and the earlier v6.4 qualification remain unchanged.

The evidence links above refer to retained local ignored directories, not portable published artifacts. For historical runs through 3c, external temporary runtime homes and Git fixtures were removed by cleanup. Retained installed snapshots, prompts, native JSONL, document snapshots, command exits and checker results still establish the observations made during those runs. The main resume snapshot includes its progress ledger and receipt; the creation and successful verification of the final-review files and migration receipt are recorded in native events and checker results, but their full file contents are not all retained as autonomous copies. Those original external Git histories and pre-done copies are unavailable, so their full historical checker cannot now be rerun from its original absolute paths. The fresh 0e8 proof archive above addresses retention for its own dated run; it does not recover the old missing bytes. The [post-cleanup inventory](../../../.superpowers/sdd/integration/20261017093852-task5-native/post-cleanup-retention-inventory.json) distinguishes retained evidence from missing external paths. No native result was reconstructed or requalified after cleanup. This task does not establish release readiness or remote publication. Upstream SDD owns whole-branch review; `implement` owns the Maxi completion transition after valid terminal evidence.
