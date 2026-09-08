# Input is a runner-collected snapshot, never an assistant's outcome summary.
def require($ok; $why): if $ok then . else error($why) end;
def commands:
  [.events[] | .payload | select(.completed_at_ms != null)
   | .item | select(.type == "CommandExecution" and .exit_code == 0)];
def read_owner($installed; $owner):
  commands as $cmds |
  any($installed | to_entries[]; . as $skill |
    (($skill.key | endswith("/" + $owner + "/SKILL.md")) or
     ($owner == "specify" and ($skill.key | endswith("/specify/spec-author.md")))) and
    any($cmds[]; ((.command | join(" ")) | contains($skill.key)) and
      (.aggregated_output | contains($skill.value))));
. as $input |
require(.exit_code == 0 and .head_unchanged and .source_unchanged; "incomplete execution or changed Git HEAD/source") |
require(any(.cli[]; .type == "turn.completed") and
  all(.cli[]; .type != "turn.failed" and .type != "error"); "incomplete CLI turn") |
require((.sessions | length) > 0 and all(.sessions[]; (.events | length) > 0); "missing session evidence") |
[.cli[] | select(.type == "item.completed" and .item.type == "agent_message") | .item.text] as $messages |
require(([$messages[] | scan("\\?")] | length) <= .max_questions; "unexpected user questions; inspect transcript") |
require(all(.changes[]; . as $path | $input.allowed | index($path)); "unauthorized write or successor") |
require(all(.files | keys[]; . as $path | $input.allowed | index($path)); "duplicate or unauthorized artifact") |
require(all(.required | to_entries[]; . as $required |
  ($input.files[$required.key] != null) and
  all($required.value[]; . as $pattern | $input.files[$required.key] | test($pattern; "i"))); "fixture output mismatch") |
require(all(.owners[]; . as $owner | any($input.sessions[]; read_owner($input.installed; $owner))); "absent completed installed-owner read evidence") |
[.sessions[] | . as $session | .events[] | select(.type == "response_item") | .payload |
 select(.type == "function_call") | . + {agent:$session.agent, args:(.arguments | fromjson)}] as $calls |
[.sessions[].events[] | select(.type == "response_item") | .payload | select(.type == "function_call_output")] as $outputs |
# Explicitly fail unfamiliar coordination names instead of treating them as zero reviews.
require(all($calls[]; if (.name | test("spawn|followup")) then (.name == "spawn_agent" or .name == "followup_task") else true end); "unknown coordination event") |
[.files | to_entries[] | select(.key | endswith("/reviews/design-review.md")) | .value | scan("(?m)^reviewer: ([^\\n]+)$") | .[0]] | unique as $reviewers |
$input |
[$calls[] | select(.name == "spawn_agent") | . as $call |
 [$outputs[] | select(.call_id == $call.call_id)] as $out |
 if ($out | length) != 1 then error("missing/duplicate allocation result") else
 ($out[0].output | fromjson | .task_name) as $identity |
 if ($identity | type) != "string" or ($identity | startswith("/root/")) == false then error("unknown allocation identity") else
 {identity:$identity, reviewer:($reviewers | index($identity) != null),
 owner:any($input.sessions[]; .agent == $identity and
   (any(["specify","clarify","plan","revise"][]; . as $owner |
      any($input.sessions[] | select(.agent == $identity); read_owner($input.installed; $owner))) or
    (read_owner($input.installed; "review") and any(commands[];
      (.command | join(" ") | contains($input.helper)) and
      (.aggregated_output | test("^DESIGN_REVIEW_RESERVED "))))))} end end] as $allocations |
require(all($allocations[]; .reviewer or .owner); "unclassified allocation: incomplete review count") |
require(all($reviewers[]; . as $id | any($allocations[]; .identity == $id)); "report reviewer is not a returned harness identity") |
[$calls[] | select(.name == "followup_task") |
 . as $call | (if (.args.target | startswith("/")) then .args.target else .agent + "/" + .args.target end) as $target |
 require(any($allocations[]; .identity == $target); "unmatched follow-up target") |
 require(any($outputs[]; .call_id == $call.call_id); "missing follow-up result") |
 select($reviewers | index($target))] as $reviews |
[.sessions[] | commands[] | select((.command | join(" ") | contains($input.helper)) and
 (.command | join(" ") | test("[[:space:]]reserve[[:space:]]|[[:space:]]reserve$"))) |
 .aggregated_output | split("\n")[] | select(test("^DESIGN_REVIEW_RESERVED operation_id=[a-f0-9]{64} pass=[12] report_sha256=[a-f0-9]{64}$"))] as $reservations |
require(($reservations | length) <= (.max_reviews // 2) and ($reviews | length) == ($reservations | length); "review dispatch/reservation mismatch or excess") |
require(if .review then ($reviews | length) > 0 else ($reviews | length) == 0 end; "missing or unauthorized review") |
require(if .review then .verified else true end; "unverified outcome; final assistant claims are not proof") |
{result:"verified", review_dispatches:($reviews | length), reservations:($reservations | length),
 user_turns:([.cli[] | select(.type == "turn.completed")] | length),
 questions:([$messages[] | scan("\\?")] | length), duplicate_documents:0}
