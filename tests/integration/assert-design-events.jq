# Input is a runner-collected snapshot, never an assistant's outcome summary.
def require($ok; $why): if $ok then . else error($why) end;
def commands:
  [.events[] | .payload | select(.completed_at_ms != null)
   | .item | select(.type == "CommandExecution" and .exit_code == 0)];
def python_path_names($command; $base):
  [$command | scan("(?m)(?:^|[;\\n])[[:space:]]*([a-z][a-z0-9_]*)=Path\\((['\"])([^'\"]+)\\2\\)") |
    .[0] as $name | select(.[2] == $base and
      ([$command | scan("(?m)(?:^|[[:space:];])" + $name + "=")] | length) == 1) | $name];
# These complete native forms are retained installed-run observations, not shell evaluation.
def complete_shell_read:
  .command[0:-1] == ["/bin/zsh", "-lc"] and .status == "completed" and
  (.aggregated_output | type == "string" and length > 0 and
    (test("(?i)tokens? truncated|output truncated|truncated output|\\[\\.\\.\\.") | not));
def safe_relative_reads($names; $relative):
  ($names | length) > 0 and ($names | index($relative) != null) and
  all($names[]; test("^[a-z][a-z0-9-]*(?:/[a-z][a-z0-9-]*)*/[A-Za-z][A-Za-z0-9.-]*$"));
def observed_installed_loop($path):
  ($path | split("/")) as $parts |
  ($parts[0:-2] | join("/")) as $base |
  ($parts[-2:] | join("/")) as $relative |
  .command[-1] as $command |
  complete_shell_read and
  (any([$command | scan("(?m)^for f in \\[(('[A-Za-z0-9_./-]+')(?:,'[A-Za-z0-9_./-]+')*)\\]:$")][];
    .[0] as $list |
    ($list | split(",") | map(ltrimstr("'") | rtrimstr("'"))) as $names |
    safe_relative_reads($names; $relative) and
    any(["assert p.is_file() and not p.is_symlink()", "assert not p.is_symlink() and p.is_file()"][];
      $command == ("python3 - <<'PY'\nfrom pathlib import Path\nr=Path('" + $base +
        "')\nfor f in [" + $list + "]:\n p=r/f\n " + . +
        "\n print('\\nFILE '+str(p.resolve())+'\\n'+p.read_text())\nPY"))) or
   any([$command | scan("(?m)^for f in ([A-Za-z0-9_./ -]+); do$")][];
     .[0] as $list | ($list | split(" ") | map(select(length > 0))) as $names |
     safe_relative_reads($names; $relative) and
     $command == ("s=" + $base + "\nfor f in " + $list +
       "; do\ntest -f \"$s/$f\" && test ! -L \"$s/$f\" && test -r \"$s/$f\" || exit 1\ncat \"$s/$f\"\ndone\ngit status --short\nls -R docs/maxi")));
def observed_filename_braces($path):
  ($path | split("/") | .[0:-2] | join("/")) as $base |
  .command[-1] as $command |
  ($command | split(" ")) as $words |
  complete_shell_read and $words[0] == "cat" and ($words | length) > 1 and
  ([$words[1:][] |
    if startswith($base + "/") then
      ltrimstr($base + "/") |
      if test("^[a-z][a-z0-9-]*/\\{[A-Za-z][A-Za-z0-9.-]*(?:,[A-Za-z][A-Za-z0-9.-]*)+\\}$") then
        (split("/{")) as $parts |
        ($parts[1] | rtrimstr("}") | split(",")[]) as $file |
        $base + "/" + $parts[0] + "/" + $file
      elif test("^[a-z][a-z0-9-]*/[A-Za-z][A-Za-z0-9.-]*$") then $base + "/" + .
      else null end
    else null end] as $paths |
   all($paths[]; . != null) and ($paths | index($path) != null));
# Only finite comma-separated installed skill names; never evaluate shell text.
def reads_path($installed; $path):
  (.command | join(" ")) as $command |
  ($command | contains($path)) or
  observed_installed_loop($path) or observed_filename_braces($path) or
  (($path | sub("/[a-z][a-z-]*/SKILL.md$"; "")) as $base |
   ($path | split("/") | .[-2:] | join("/")) as $relative |
   ($command | contains("python3 - <<") and test("(?m)^for rel in \\[") and contains("'" + $relative + "'") and
     contains("p.read_text()") and
     any(python_path_names($command; $base)[];
       . as $name | ($command | contains("p=" + $name + "/rel")))) or
  (any([$command | scan("(?m)(?:^|[[:space:];])([a-z][a-z0-9_]*)=(/[^[:space:];]+)")][];
    .[0] as $name | .[1] == $base and
    ([$command | scan("(?m)(?:^|[[:space:];])" + $name + "=")] | length) == 1 and
    any($command | split("\n")[]; startswith("cat ") and
      contains("\"$" + $name + "/" + $relative + "\""))))) or
  (($path | sub("/[a-z][a-z-]*/SKILL.md$"; "")) as $base |
   ($path | split("/") | .[-2:] | join("/")) as $relative |
   any([$command | scan("(?s)for f in ([A-Za-z0-9_./ -]+); do (.*?) done")][];
      . as $loop |
      ($loop[0] | split(" ") | map(select(length > 0))) as $names |
      $loop[1] == ("p=" + $base + "/$f; test -f \"$p\" && test ! -L \"$p\" && cat \"$p\";") and
      ($names | length) > 0 and
      all($names[]; test("^[a-z][a-z0-9-]*(?:/[a-z][a-z0-9-]*)*/[A-Za-z][A-Za-z0-9.-]*$")) and
      ($names | index($relative) != null))) or
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
def python_helper_expressions($command; $helper):
  ($helper | rtrimstr("/design-contract.sh")) as $review_dir |
  ($helper | rtrimstr("/review/design-contract.sh")) as $skills_dir |
  (["\"" + $helper + "\"", "'" + $helper + "'"] +
   [python_path_names($command; $review_dir)[] | "str(" + . + "/'design-contract.sh')"] +
   [python_path_names($command; $skills_dir)[] | "str(" + . + "/'review/design-contract.sh')"]);
def python_reservation_call($helper):
  (.command | join(" ")) as $command |
  any(python_helper_expressions($command; $helper)[]; . as $expression |
    any(["subprocess.run(['bash',", "subprocess.check_output(['bash',"][]; . as $prefix |
      $command | contains($prefix + $expression + ",'reserve',")));
def reservation_lines:
  (.aggregated_output | try fromjson catch null) as $decoded |
  (if ($decoded | type) == "object" and
       ($decoded | has("result") or has("code") or has("error")) then
     ($decoded | select(.code == 0 and .error == "") | .result)
   elif ($decoded | type) == "object" and ($decoded | has("reservation")) then
     $decoded.reservation
   else .aggregated_output end) |
  select(type == "string") |
  split("\n")[] | select(test("^DESIGN_REVIEW_RESERVED operation_id=[a-f0-9]{64} pass=[12] report_sha256=[a-f0-9]{64}$"));
def invokes_reservation($helper):
  python_reservation_call($helper) or
  (invokes_helper($helper) and
   (.command | join(" ") | test("[[:space:]]reserve[[:space:]]|[[:space:]]reserve$")));
def read_owner($installed; $owner):
  commands as $cmds |
  any($installed | to_entries[]; . as $skill |
    (($skill.key | endswith("/" + $owner + "/SKILL.md")) or
     ($owner == "specify" and ($skill.key | endswith("/specify/spec-author.md")))) and
    any($cmds[]; reads_path($installed; $skill.key) and
      (.aggregated_output | contains($skill.value))));

# Recognize full-file reads only, never dispatch text, echoes, slices or shell evaluation.
# Canonical output is the event-time snapshot: later author corrections are allowed.
# Parse only literal cat operands, then compare resolved paths with the exact targets.
# Relative operands require the fixture cwd; dot segments and expansions are unsupported.
def cat_read_paths($fixture):
  . as $read |
  if complete_shell_read then
    try (
      (.command[-1] | capture("^cat(?: --)? (?<operands>.+)$").operands // "") as $args |
      ([$args | scan("(\"[^\"\\n]+\"|'[^'\\n]+'|[A-Za-z0-9_./-]+)") | .[0]]) as $tokens |
      if ($tokens | length) > 0 and ($tokens | join(" ")) == $args then
        [$tokens[] |
          (if startswith("\"") or startswith("'") then .[1:-1] else . end) as $path |
          if ($path | test("^/?[A-Za-z0-9_./ -]+$") and
              (ltrimstr("/") | split("/") | all(.[]; length > 0 and . != "." and . != ".."))) then
            if $path | startswith("/") then $path
            elif $read.cwd == ("file://" + $fixture) then $fixture + "/" + $path
            else null end
          else null end] as $paths |
        if all($paths[]; . != null) then $paths else null end
      else null end
    ) catch null
  else null end;
def full_file_read($path; $relative; $fixture):
  (.command[-1] // "") as $command |
  ([ $path ] + (if .cwd == ("file://" + $fixture) then [$relative] else [] end)) as $paths |
  (cat_read_paths($fixture) == [$path]) or
  (complete_shell_read and
   (any($paths[]; . as $file |
      any(["'", "\""][]; . as $quote |
        any(["p", "path", "spec"][]; . as $name |
          $command == ("python3 - <<'PY'\nfrom pathlib import Path\n" + $name + "=Path(" +
            $quote + $file + $quote + ")\nprint(" + $name + ".read_text())\nPY") or
          $command == ("python3 - <<'PY'\nfrom pathlib import Path\nprint(Path(" +
            $quote + $file + $quote + ").read_text())\nPY")))) or
    (($path | split("/")) as $parts |
     ($parts[0:-2] | join("/")) as $base |
     ($parts[-2:] | join("/")) as $relative |
     any(["base", "b"][]; . as $name |
       any(["'", "\""][]; . as $quote |
         $command == ("python3 - <<'PY'\nfrom pathlib import Path\n" + $name + "=Path(" +
           $quote + $base + $quote + ")\nfor rel in [" + $quote + $relative + $quote +
           "]:\n p=" + $name + "/rel\n print(p.read_text())\nPY"))))));
def canonical_spec_output($slug):
  startswith("---\n") and endswith("\n") and
  contains("\nslug: " + $slug + "\n") and contains("\nstatus: specified\n") and
  test("(?m)^# Feature Specification:") and test("(?m)^## User Scenarios & Testing") and
  test("(?m)^## Requirements") and test("(?m)^## Success Criteria") and
  test("(?m)^## Assumptions");
def builder_read($input; $parent; $identity):
  [$input.sessions[] | select(.agent == $identity)] as $children |
  ($children | length) == 1 and
  any($children[]; . as $child |
    (.id | type == "string" and length > 0) and .id != $parent.id and
    ($parent.id | type == "string" and length > 0) and
    .source.subagent.thread_spawn.parent_thread_id == $parent.id and
    .source.subagent.thread_spawn.agent_path == $identity and
    any($input.installed | to_entries[];
      . as $prompt | (.key | endswith("/brainstorming/builder-check-prompt.md")) and
      any($input.files | keys[] | select(endswith("/spec.md")); . as $relative |
        ($relative | split("/") | .[-2]) as $slug |
        (any($child | commands[];
           full_file_read($prompt.key; $prompt.key; $input.fixture) and
           (.aggregated_output | contains($prompt.value))) and
         any($child | commands[];
           full_file_read($input.fixture + "/" + $relative; $relative; $input.fixture) and
           (.aggregated_output | canonical_spec_output($slug)))) or
        any($child | commands[];
          cat_read_paths($input.fixture) == [$prompt.key, $input.fixture + "/" + $relative] and
          (.aggregated_output | startswith($prompt.value) and
            (ltrimstr($prompt.value) | canonical_spec_output($slug)))))));

. as $input |
require(.exit_code == 0 and .head_unchanged and .source_unchanged; "incomplete execution or changed Git HEAD/source") |
require(any(.cli[]; .type == "turn.completed") and
  all(.cli[]; .type != "turn.failed" and .type != "error"); "incomplete CLI turn") |
require((.sessions | length) > 0 and all(.sessions[]; (.events | length) > 0); "missing session evidence") |
[.cli[] | select(.type == "item.completed" and .item.type == "agent_message") | .item.text] as $messages |
[.sessions[] | select(.agent == "/root") | .events[] | select(.type == "event_msg" and .payload.type == "task_complete") | .payload] as $final_turns |
[.sessions[] | select(.agent == "/root") | .events[] | select(.type == "turn_context") | .payload.turn_id] as $turn_ids |
(if (.answers // [] | length) > 0 then ([$final_turns[].last_agent_message | scan("\\?")] | length)
 else ([$messages[] | scan("\\?")] | length) end) as $question_count |
require(if (.answers // [] | length) > 0 then
  ($final_turns | length) == ([.cli[] | select(.type == "turn.completed")] | length) and
  ($final_turns | length) == ((.answers | length) + 1) and
  $turn_ids == ($final_turns | map(.turn_id)) and
  ($turn_ids | unique | length) == ($turn_ids | length) and
  all($final_turns[]; (.turn_id | type) == "string" and (.turn_id | length) > 0 and
    (.last_agent_message | type) == "string" and (.last_agent_message | length) > 0) and
  ($final_turns[-1].last_agent_message | test("\\?") | not)
  else true end; "incomplete scripted final-turn evidence") |
require(if (.answers // [] | length) > 0 then
  (.answer_question_patterns | type == "array") and
  (.answer_question_patterns | length) == (.answers | length) and
  all(range(0; .answers | length); . as $i |
    ($input.answer_question_patterns[$i] | type == "string" and length > 0) and
    ($final_turns[$i].last_agent_message | test($input.answer_question_patterns[$i]; "i")))
  else true end; "scripted answer question mismatch") |
require($question_count <= .max_questions; "unexpected user questions; inspect transcript") |
require(all(.changes[]; . as $path | $input.allowed | index($path)); "unauthorized write or successor") |
require(all(.files | keys[]; . as $path | $input.allowed | index($path)); "duplicate or unauthorized artifact") |
require(all(.required | to_entries[]; . as $required |
  ($input.files[$required.key] != null) and
  all($required.value[]; . as $pattern | $input.files[$required.key] | test($pattern; "i"))); "fixture output mismatch") |
require(if .name == "lean-plan-only" or .name == "settled-sdd-design" then
  (.files["docs/maxi/specs/0001-line-counter/plan.md"] // "") as $plan |
  ([$plan | scan("(?m)^## Global Constraints$")] | length) == 1 and
  ([$plan | scan("(?m)^## Review Focus$")] | length) == 1 and
  ($plan | split("## Review Focus\n")[1] | split("\n## ")[0] | split("\n### Task ")[0]) as $focus |
  ([$focus | scan("(?m)^- .+")] | length) as $focus_count |
  $focus_count >= 1 and $focus_count <= 5 and
  (if $focus | test("(?i)No review focus.*after scan") then $focus_count == 1
   else all([$focus | scan("(?m)^- .+")][]; test("(?i)Task [1-9]") and test("(?i)test")) end) and
  ($plan | test("(?im)^#{1,3} .*execution (handoff|options|menu)|^ready to execute|^choose (an )?execution" ) | not)
  else true end; "lean plan has duplicate/missing sections or nested execution menu") |
require(if .name == "lean-plan-only" or .name == "settled-sdd-design" then
  all($messages[]; test("(?i)which execution (approach|method)|subagent-driven.{0,300}native|ready to execute|choose (an )?execution" ) | not)
  else true end; "duplicate execution handoff in assistant messages") |
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
 ([$input.sessions[] | select(.agent == $call.agent)]) as $parents |
 {identity:$identity, builder:(($parents | length) == 1 and
    any($parents[]; builder_read($input; .; $identity))), reviewer:($reviewers | index($identity) != null),
 owner:any($input.sessions[]; .agent == $identity and
   (any(["specify","clarify","plan","revise"][]; . as $owner |
      any($input.sessions[] | select(.agent == $identity); read_owner($input.installed; $owner))) or
    (read_owner($input.installed; "review") and any(commands[];
      invokes_reservation($input.helper) and any(reservation_lines; startswith("DESIGN_REVIEW_RESERVED "))))))} end end] as $allocations |
require(all($allocations[]; .reviewer or .owner or .builder); "unclassified allocation: incomplete review count") |
require((.expected_builder_checks | type == "number") and .expected_builder_checks >= 0 and
  (.expected_builder_checks | floor) == .expected_builder_checks; "invalid expected builder checks") |
[$allocations[] | select(.builder)] as $builders |
require(all($builders[]; (.reviewer or .owner) | not); "builder identity overlaps reviewer or owner") |
require(($builders | length) == .expected_builder_checks; "builder check count mismatch") |
require(all($reviewers[]; . as $id | any($allocations[]; .identity == $id)); "report reviewer is not a returned harness identity") |
[$calls[] | select(.name == "followup_task") |
 . as $call | (if (.args.target | startswith("/")) then .args.target else .agent + "/" + .args.target end) as $target |
 require(any($allocations[]; .identity == $target); "unmatched follow-up target") |
 require(any($outputs[]; .call_id == $call.call_id); "missing follow-up result") |
 select($reviewers | index($target))] as $reviews |
[.sessions[] | commands[] | select(invokes_reservation($input.helper)) | reservation_lines] as $reservations |
require(($reservations | length) <= (.max_reviews // 2) and ($reviews | length) == ($reservations | length); "review dispatch/reservation mismatch or excess") |
require(if .review then ($reviews | length) > 0 else ($reviews | length) == 0 end; "missing or unauthorized review") |
require(if .review then .verified else true end; "unverified outcome; final assistant claims are not proof") |
require(if .name == "design-validation" or .name == "revision" or .name == "settled-sdd-design" then .outcome == "approved"
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
{result:(if .review then .outcome else "verified" end), review_dispatches:($reviews | length), builder_checks:($builders | length), reservations:($reservations | length),
 user_turns:([.cli[] | select(.type == "turn.completed")] | length),
 questions:$question_count, duplicate_documents:0}
