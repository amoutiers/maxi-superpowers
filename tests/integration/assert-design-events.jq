# Input is a runner-collected snapshot, never an assistant's outcome summary.
def require($ok; $why): if $ok then . else error($why) end;
def commands:
  [.events[] | .payload | select(.completed_at_ms != null)
   | .item | select(.type == "CommandExecution" and .exit_code == 0)];
# Only finite comma-separated installed skill names; never evaluate shell text.
def reads_path($installed; $path):
  (.command | join(" ")) as $command |
  ($command | contains($path)) or
  (if ($path | endswith("/SKILL.md")) then
    ($path | split("/")) as $parts |
    (($parts[0:-2] | join("/")) + "/") as $prefix |
    any($command | split(" ")[] | rtrimstr(";");
      if startswith($prefix + "{") and endswith("}/SKILL.md") then
        (ltrimstr($prefix + "{") | rtrimstr("}/SKILL.md") | split(",")) as $names |
        ($names | length) > 1 and
        all($names[]; test("^[a-z][a-z-]*$") and $installed[$prefix + . + "/SKILL.md"] != null) and
        ($names | index($parts[-2]) != null)
      else false end)
   else false end);
# The observed relative invocation starts in the recorded cwd, one directory up.
# Do not interpret shell commands, cd, URI escapes, or other relative-path forms.
def invokes_helper($helper):
  (.command | join(" ")) as $command |
  any($command | split(" ")[]; . == $helper or . == ("\"" + $helper + "\"") or . == ("'" + $helper + "'")) or
  (if (.cwd // "" | test("^file:///[^%]+$")) then
    (.command[-1] | split(" ")) as $words |
    ($words[0] == "bash" and ($words[1] // "" | startswith("../")) and
     $words[2] == "reserve" and
     (((.cwd | ltrimstr("file://") | split("/") | .[0:-1] | join("/")) +
       "/" + ($words[1] | ltrimstr("../"))) == $helper))
   else false end);
def read_owner($installed; $owner):
  commands as $cmds |
  any($installed | to_entries[]; . as $skill |
    (($skill.key | endswith("/" + $owner + "/SKILL.md")) or
     ($owner == "specify" and ($skill.key | endswith("/specify/spec-author.md")))) and
    any($cmds[]; reads_path($installed; $skill.key) and
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
      invokes_helper($input.helper) and
      (.aggregated_output | test("^DESIGN_REVIEW_RESERVED "))))))} end end] as $allocations |
require(all($allocations[]; .reviewer or .owner); "unclassified allocation: incomplete review count") |
require(all($reviewers[]; . as $id | any($allocations[]; .identity == $id)); "report reviewer is not a returned harness identity") |
[$calls[] | select(.name == "followup_task") |
 . as $call | (if (.args.target | startswith("/")) then .args.target else .agent + "/" + .args.target end) as $target |
 require(any($allocations[]; .identity == $target); "unmatched follow-up target") |
 require(any($outputs[]; .call_id == $call.call_id); "missing follow-up result") |
 select($reviewers | index($target))] as $reviews |
[.sessions[] | commands[] | select(invokes_helper($input.helper) and
 (.command | join(" ") | test("[[:space:]]reserve[[:space:]]|[[:space:]]reserve$"))) |
 .aggregated_output | split("\n")[] | select(test("^DESIGN_REVIEW_RESERVED operation_id=[a-f0-9]{64} pass=[12] report_sha256=[a-f0-9]{64}$"))] as $reservations |
require(($reservations | length) <= (.max_reviews // 2) and ($reviews | length) == ($reservations | length); "review dispatch/reservation mismatch or excess") |
require(if .review then ($reviews | length) > 0 else ($reviews | length) == 0 end; "missing or unauthorized review") |
require(if .review then .verified else true end; "unverified outcome; final assistant claims are not proof") |
require(if .name == "design-validation" or .name == "revision" then .outcome == "approved"
  else true end; "full design case requires approval, stopped is incomplete") |
# Keep the independently checked machine outcome distinct from untrusted prose.
[.files | to_entries[] | select(.key | endswith("/reviews/design-review.md")) | .value] as $reports |
require(if .review then
  (.outcome == "approved" or .outcome == "stopped") and ($reports | length) == 1 and
  ([$reports[0] | scan("(?m)^phase: ([a-z]+)$") | .[0]][0] == .outcome)
  else .outcome == "none" end; "missing or contradictory operation outcome") |
require(if .outcome == "stopped" then
  ([$reports[0] | scan("(?m)^VERDICT: ([a-z]+)$") | .[0]][-1] != "approved") and
  all($messages[]; test("(?m)^VERDICT: approved$|^DESIGN_REVIEW_VERIFIED$") | not)
  else true end; "stopped operation contradicts structured approval") |
require(if .outcome == "approved" then
  ([$reports[0] | scan("(?m)^VERDICT: ([a-z]+)$") | .[0]][-1] == "approved") and
  ([$reports[0] | scan("(?m)^reviewer: ([^\\n]+)$") | .[0]][0]) as $reviewer |
  any(.sessions[]; .agent == $reviewer and
    any(.events[].payload; . as $terminal |
      .type == "task_complete" and
      (.last_agent_message // "" | test("VERDICT: approved\\s*$")) and
      ([.last_agent_message | scan("(?m)^VERDICT: ([a-z]+)$")] == [["approved"]]) and
      any($input.sessions[] | select(.agent == $reviewer) | .events[].payload;
        .type == "item_completed" and .completed_at_ms != null and .turn_id == $terminal.turn_id and
        .item.type == "AgentMessage" and .item.phase == "final_answer" and
        ([.item.content[] | select(.type == "Text") | .text] | join("")) == $terminal.last_agent_message)))
  else true end; "absent or inconsistent completed independent reviewer verdict") |
{result:(if .review then .outcome else "verified" end), review_dispatches:($reviews | length), reservations:($reservations | length),
 user_turns:([.cli[] | select(.type == "turn.completed")] | length),
 questions:([$messages[] | scan("\\?")] | length), duplicate_documents:0}
