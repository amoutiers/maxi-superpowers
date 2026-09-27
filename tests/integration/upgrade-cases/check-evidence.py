#!/usr/bin/env python3
"""Verify retained evidence from the installed Maxi upgrade lifecycle."""
import json
import hashlib
from datetime import datetime
from pathlib import Path
import re
import subprocess
import sys
import shutil
import shlex


STAGES = ("design", "tasks", "readiness", "first-task", "resume", "migration")
CLI_EVENTS = {"thread.started", "turn.started", "item.started", "item.updated",
              "item.completed", "turn.completed", "turn.failed", "error"}


def stage_sequence(stages):
    names = [stage.get("name") for stage in stages]
    unknown = set(names) - set(STAGES)
    if unknown:
        raise ValueError(f"unknown stage: {sorted(unknown)}")
    if names != list(STAGES) or any(stage.get("exit_code") != 0 for stage in stages):
        raise ValueError("incomplete or reordered upgrade stages")


def cli_commands(path):
    events = []
    for line in path.read_text(errors="replace").splitlines():
        if line == "Reading additional input from stdin...":
            continue
        event = json.loads(line)
        if not isinstance(event, dict) or event.get("type") not in CLI_EVENTS:
            raise ValueError("unknown CLI event shape")
        events.append(event)
    if (sum(event["type"] == "thread.started" for event in events) != 1 or
            sum(event["type"] == "turn.completed" for event in events) != 1 or
            any(event["type"] in {"turn.failed", "error"} for event in events)):
        raise ValueError("incomplete Codex turn")
    return [event["item"] for event in events
            if event["type"] == "item.completed" and
            isinstance(event.get("item"), dict) and
            event["item"].get("type") == "command_execution"]


def installed_read(sessions, installed, owner):
    # Execute the bounded owner-read rules already used by the design harness.
    source = (Path(__file__).parent.parent / "assert-design-events.jq").read_text()
    parts = source.split("\n. as $input |", 1)
    if len(parts) != 2:
        raise ValueError("installed read rule boundary changed")
    program = parts[0] + "\n. as $input | any(.sessions[]; read_owner($input.installed; $owner))"
    result = subprocess.run(["jq", "-e", "--arg", "owner", owner, program],
                            input=json.dumps({"sessions": sessions, "installed": installed}),
                            capture_output=True, text=True)
    if result.returncode != 0 or result.stdout.strip() != "true":
        raise ValueError(f"missing byte-exact installed owner read: {owner}")


def native_reads(sessions, context, paths):
    """The reviewer must have received every exact artifact in command output."""
    outputs = []
    for session in sessions:
        if session.get("agent") != context:
            continue
        for event in session.get("events", []):
            payload = event.get("payload", {})
            item = payload.get("item", {})
            if (event.get("type") != "event_msg" or payload.get("completed_at_ms") is None or
                    item.get("type") != "CommandExecution" or item.get("exit_code") != 0):
                continue
            outputs.append(item.get("aggregated_output", ""))
    require(all(any(value in output for output in outputs) for value in paths.values()),
            "reviewer did not receive complete exact artifact bytes")


def normalized_task_quality(report):
    # Codex can place the final period inside the Markdown emphasis.
    return report.replace("**Task quality: Approved.**", "**Task quality:** Approved")


def collect_task_review(sessions, stage, fixture, workspace, base, end):
    """Bind a task's real reviewer to its exact committed-range package read."""
    fixture = fixture.resolve()
    workspace = workspace.resolve()
    require(workspace.is_relative_to(fixture), "task workspace left fixture")
    package = workspace / f"review-{base[:7]}..{end[:7]}.diff"
    require(package.is_file() and package.resolve().is_relative_to(workspace),
            "task review package is missing or outside workspace")
    relative = str(package.relative_to(fixture))
    expected_commands = (["cat", relative], ["cat", str(package)])
    package_bytes = package.read_bytes()
    matches = []
    for child in sessions:
        context = child.get("agent")
        if context == "/root":
            continue
        if child.get("cwd") != str(fixture):
            continue
        reports = [event.get("payload", {}).get("last_agent_message", "")
                   for event in child.get("events", [])
                   if event.get("type") == "event_msg" and
                   event.get("payload", {}).get("type") == "task_complete"]
        if not any("### Spec Compliance" in report and
                   "**Task quality:**" in normalized_task_quality(report)
                   for report in reports):
            continue
        for event in child.get("events", []):
            payload = event.get("payload", {})
            item = payload.get("item") or {}
            command = item.get("command")
            if (event.get("type") != "event_msg" or payload.get("completed_at_ms") is None or
                    item.get("type") != "CommandExecution" or
                    item.get("exit_code") != 0 or not isinstance(command, list) or
                    len(command) != 3 or command[0] not in {"/bin/zsh", "/bin/bash"} or
                    command[1] != "-lc"):
                continue
            try:
                words = shlex.split(command[2])
            except ValueError:
                continue
            output = item.get("aggregated_output")
            if (words in expected_commands and isinstance(output, str) and
                    package_bytes in output.encode("utf-8")):
                matches.append({"stage": stage, "context": context,
                                "package": str(package), "package_sha256": digest(package)})
    require(len(matches) == 1, f"missing or duplicate observed {stage} task reviewer/package")
    return matches[0]


def reviewer_reads(sessions, context, spec_path, plan_path, spec_bytes, plan_bytes):
    native_reads(sessions, context, {spec_path: spec_bytes, plan_path: plan_bytes})


def review_dispatch(sessions, context, spec, plan, final):
    if not re.fullmatch(r"/root(?:/[a-z][a-z0-9_]{0,127})+", context):
        raise ValueError("invalid reviewer context")
    roots = [session for session in sessions if session.get("agent") == "/root"]
    if len(roots) != 1:
        raise ValueError("missing root session")
    calls = {}
    state = "start"
    followups = []
    followup_times = []
    aliases = {context, context.removeprefix("/root/")}
    for event in roots[0].get("events", []):
        if event.get("type") != "response_item":
            continue
        payload = event.get("payload", {})
        call_id = payload.get("call_id")
        if payload.get("type") == "function_call":
            name = payload.get("name", "")
            if re.search("spawn|followup", name) and name not in {"spawn_agent", "followup_task"}:
                raise ValueError("unknown reviewer dispatch shape")
            if call_id in calls:
                raise ValueError("duplicate reviewer dispatch call")
            arguments = json.loads(payload.get("arguments", "{}"))
            calls[call_id] = (name, arguments)
            if name == "followup_task" and arguments.get("target") in aliases:
                message = arguments.get("message", "")
                if (state not in {"allocated", "dispatched"} or
                        not isinstance(message, str) or not message or
                        (not message.startswith("gAAAA") and
                         (spec not in message or plan not in message))):
                    raise ValueError("reviewer follow-up identity or context mismatch")
                followups.append(call_id)
                followup_times.append(event.get("timestamp"))
                state = "followup-pending"
        elif payload.get("type") == "function_call_output" and call_id in calls:
            name, arguments = calls[call_id]
            output = payload.get("output", "")
            if name == "spawn_agent" and json.loads(output).get("task_name") == context:
                if state != "start" or spec in arguments.get("message", "") or plan in arguments.get("message", ""):
                    raise ValueError("reviewer allocation was not an identity handshake")
                state = "allocated"
            elif name == "followup_task" and arguments.get("target") in aliases:
                if state != "followup-pending" or output not in {
                        "", '{"status":"running"}', '{"status":"completed"}'}:
                    raise ValueError("missing reviewer follow-up result")
                state = "dispatched"
    if state != "dispatched" or not 1 <= len(followups) <= 2:
        raise ValueError("missing reviewer dispatch")
    children = [session for session in sessions if session.get("agent") == context]
    if len(children) != 1:
        raise ValueError("missing independent reviewer session")
    completed = {}
    terminal = []
    for event in children[0].get("events", []):
        if event.get("type") != "event_msg":
            continue
        payload = event.get("payload", {})
        item = payload.get("item", {})
        if (payload.get("type") == "item_completed" and payload.get("completed_at_ms") is not None and
                item.get("type") == "AgentMessage" and item.get("phase") == "final_answer"):
            completed[payload.get("turn_id")] = "".join(part.get("text", "") for part in item.get("content", [])
                                                         if part.get("type") == "Text")
        elif payload.get("type") == "task_complete":
            terminal.append((payload.get("turn_id"), payload.get("last_agent_message"),
                             event.get("timestamp")))
    if (not 1 <= len(terminal) <= len(followups) + 1 or
            len(completed) != len(terminal) or
            len({turn for turn, _, _ in terminal}) != len(terminal) or
            any(completed.get(turn) != message for turn, message, _ in terminal) or
            terminal[-1][1] != final):
        raise ValueError("missing or inconsistent reviewer native terminal")
    def native_time(stamp):
        try:
            parsed = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
        except (AttributeError, ValueError):
            raise ValueError("missing or invalid native reviewer timestamp") from None
        if parsed.tzinfo is None:
            raise ValueError("native reviewer timestamp has no timezone")
        return parsed
    followup_times = [native_time(stamp) for stamp in followup_times]
    terminals = [(message, native_time(stamp)) for _, message, stamp in terminal]
    if followup_times != sorted(followup_times):
        raise ValueError("reviewer follow-ups out of order")
    reviews = [(message, stamp) for message, stamp in terminals
               if stamp > followup_times[0]]
    if (not reviews or any(not any(start < stamp <= end for _, stamp in reviews)
                           for start, end in zip(followup_times, followup_times[1:])) or
            not any(stamp > followup_times[-1] for _, stamp in reviews)):
        raise ValueError("reviewer terminal preceded its follow-up")
    return [message for message, _ in reviews]


def reviewer_terminal(sessions, context):
    messages = [event.get("payload", {}).get("last_agent_message")
                for session in sessions if session.get("agent") == context
                for event in session.get("events", [])
                if event.get("type") == "event_msg" and
                event.get("payload", {}).get("type") == "task_complete"]
    require(1 <= len(messages) <= 3 and isinstance(messages[-1], str),
            "missing reviewer terminal message")
    return messages[-1]


def verified_design(snapshot, installed):
    spec_dir = snapshot / "docs/maxi/specs/0001-upgrade"
    result = subprocess.run(["bash", str(installed / "review/design-contract.sh"), "verify",
                             str(spec_dir / "reviews/design-review.md"), str(spec_dir / "spec.md"),
                             str(spec_dir / "plan.md"), str(snapshot)],
                            capture_output=True, text=True)
    if result.returncode != 0 or result.stdout != "DESIGN_REVIEW_VERIFIED\n":
        raise ValueError("design approval is missing or stale")


def verified_readiness(snapshot, installed):
    spec_dir = snapshot / "docs/maxi/specs/0001-upgrade"
    result = subprocess.run(["bash", str(installed / "analyze/readiness-contract.sh"), "verify",
                             str(spec_dir / "analysis.md"), str(spec_dir / "spec.md"),
                             str(spec_dir / "plan.md"), str(spec_dir / "tasks.md"), str(snapshot)],
                            capture_output=True, text=True)
    if result.returncode != 0 or result.stdout != "READINESS_VERIFIED\n":
        raise ValueError("readiness evidence is missing or stale")


def require(ok, message):
    if not ok:
        raise ValueError(message)


def git(root, *args):
    result = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)
    require(result.returncode == 0, f"invalid Git evidence: {' '.join(args)}")
    return result.stdout.strip()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def tree_digest(root):
    require(root.is_dir() and not root.is_symlink(), "missing boundary fixture")
    stream = hashlib.sha256()
    for path in sorted(root.rglob("*")):
        require(not path.is_symlink(), "symlink in boundary fixture")
        if path.is_file():
            stream.update(str(path.relative_to(root)).encode() + b"\0")
            stream.update(bytes.fromhex(digest(path)))
    return stream.hexdigest()


def run_boundary_verifier(fixture, boundary, installed, tasks, receipt, source):
    """Runner-only: reconstruct its external fixture after Codex has exited."""
    fixture, boundary, source = (path.resolve(strict=True) for path in
                                 (fixture, boundary, source))
    require(fixture.name == "fixture" and boundary.parent == fixture.parent and
            boundary.name == "pre-done-fixture" and
            source != fixture and source not in fixture.parents and
            source != boundary and source not in boundary.parents,
            "boundary paths are not runner-owned siblings outside source")
    snapshot_sha256 = tree_digest(boundary)
    final_sha256 = tree_digest(fixture)
    saved = fixture.with_name(fixture.name + ".final-held")
    require(not saved.exists(), "final fixture hold path is occupied")
    fixture.rename(saved)
    try:
        shutil.copytree(boundary, fixture)
        result = subprocess.run(["bash", str(installed / "x-develop/result-contract.sh"),
                                 "--tasks", str(tasks), "--receipt", str(receipt)],
                                cwd=fixture, capture_output=True, text=True)
    finally:
        if fixture.exists():
            shutil.rmtree(fixture)
        saved.rename(fixture)
    require(tree_digest(fixture) == final_sha256, "final fixture restoration failed")
    return {"snapshot_sha256": snapshot_sha256, "exit_code": result.returncode,
            "stdout": result.stdout, "stderr": result.stderr,
            "final_sha256": final_sha256}


def boundary_proof(fixture, boundary, projection, expected):
    lines = expected["stdout"].splitlines()
    require(tree_digest(boundary) == expected["snapshot_sha256"] and
            tree_digest(fixture) == expected["final_sha256"] and
            expected["exit_code"] == 0 and expected["stderr"] == "" and
            lines.count("READY_TO_FINISH") == 1 and lines[-1] == "READY_TO_FINISH" and
            f"LINEAGE: {projection}" in lines,
            "independent terminal boundary proof is incomplete")


def field(path, name):
    lines = path.read_text().splitlines()
    require(lines and lines[0] == "---", f"missing {name} frontmatter")
    found = [line.split(": ", 1)[1] for line in lines[1:lines.index("---", 1)]
             if line.startswith(name + ": ")]
    require(len(found) == 1, f"missing or duplicate {name}")
    return found[0]


def same_tree(source, installed):
    def files(root):
        require(root.is_dir() and not root.is_symlink(), "missing skill snapshot")
        found = {}
        for path in root.rglob("*"):
            require(not path.is_symlink(), "symlinked skill snapshot")
            if path.is_file():
                found[str(path.relative_to(root))] = digest(path)
        return found
    require(files(source) == files(installed), "installed skill bytes differ from source")


def stage_data(directory, name):
    stage = directory / "stages" / name
    commands = cli_commands(stage / "cli.jsonl")
    sessions = json.loads((stage / "sessions.json").read_text())
    require(isinstance(sessions, list) and sessions and
            all(isinstance(item, dict) and item.get("events") for item in sessions),
            f"missing native sessions: {name}")
    cli = [json.loads(line) for line in (stage / "cli.jsonl").read_text().splitlines()
           if line.startswith("{")]
    threads = [event.get("thread_id") for event in cli if event["type"] == "thread.started"]
    require(len(threads) == 1 and isinstance(threads[0], str) and threads[0],
            f"missing thread identity: {name}")
    return {"commands": commands, "sessions": sessions, "thread": threads[0],
            "snapshot": stage / "snapshot"}


def status(snapshot, expected, checks):
    spec_dir = snapshot / "docs/maxi/specs/0001-upgrade"
    require(field(spec_dir / "spec.md", "status") == expected,
            f"wrong spec status at {expected}")
    tasks = (spec_dir / "tasks.md").read_text() if checks else ""
    for number, checked in checks.items():
        require(len(re.findall(rf"(?m)^- \[{checked}\] T{number:03d} ", tasks)) == 1,
                f"wrong T{number:03d} checkbox")
    return spec_dir


def ancestral_range(root, base, head):
    require(re.fullmatch(r"[0-9a-f]{40}", base) and re.fullmatch(r"[0-9a-f]{40}", head),
            "invalid Git endpoint")
    require(git(root, "rev-parse", "--verify", f"{base}^{{commit}}") == base and
            git(root, "rev-parse", "--verify", f"{head}^{{commit}}") == head,
            "review endpoints are not commits")
    result = subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor", base, head])
    require(result.returncode == 0 and int(git(root, "rev-list", "--count", f"{base}..{head}")) > 0,
            "empty or nonancestor review range")


def terminal_proof(sessions, installed, tasks, receipt, fixture):
    helper = str(installed / "x-develop/result-contract.sh")
    require(fixture.is_absolute() and str(fixture.resolve(strict=True)) == str(fixture),
            "terminal fixture cwd is not physical")
    task_relative = tasks.relative_to(fixture)
    receipt_relative = receipt.relative_to(fixture)
    expected = ["bash", helper, "--tasks", str(tasks), "--receipt", str(receipt)]
    pwd_bound = ["bash", helper, "--tasks", f"$PWD/{task_relative}",
                 "--receipt", f"$PWD/{receipt_relative}"]
    for session in sessions:
        if session.get("agent") != "/root":
            continue
        require(session.get("cwd") == str(fixture), "terminal proof session cwd changed")
        for index, event in enumerate(session.get("events", [])):
            payload = event.get("payload", {})
            item = payload.get("item", {})
            raw = item.get("command")
            if (event.get("type") != "event_msg" or
                    payload.get("completed_at_ms") is None or
                    item.get("type") != "CommandExecution" or
                    item.get("exit_code") != 0 or not isinstance(raw, list)):
                continue
            try:
                words = (raw if raw == expected else
                         shlex.split(raw[2]) if len(raw) == 3 and
                         raw[:2] == ["/bin/zsh", "-lc"] else [])
            except ValueError:
                continue
            if words in (expected, pwd_bound) and item.get("aggregated_output", "").splitlines().count(
                    "READY_TO_FINISH") == 1:
                return index
    raise ValueError("missing exact installed terminal verifier result")


def finish_order(sessions, ready_index, spec):
    roots = [session for session in sessions if session.get("agent") == "/root"]
    require(len(roots) == 1, "missing completion owner session")
    events = roots[0]["events"]
    observed = []
    for index, event in enumerate(events):
        payload = event.get("payload", {})
        item = payload.get("item", {})
        command = item.get("command")
        if (index > ready_index and event.get("type") == "event_msg" and
                payload.get("completed_at_ms") is not None and
                item.get("type") == "CommandExecution" and item.get("exit_code") == 0 and
                isinstance(command, list) and
                (str(spec) in " ".join(command) or "docs/maxi/specs/0001-upgrade/spec.md" in
                 " ".join(command)) and
                "status: done" in item.get("aggregated_output", "").splitlines()):
            observed.append(index)
    require(observed, "done status was not observed after terminal verification")
    require(any(index > observed[-1] and event.get("type") == "event_msg" and
                event.get("payload", {}).get("type") == "task_complete" and
                re.search(r"Git outcome:\s*(?:\*\*)?deliberately retained(?:\*\*)?",
                          event.get("payload", {}).get("last_agent_message", ""))
                for index, event in enumerate(events)),
            "Git closure was not reported after done")


def task_review(stage, review, annotation, ledger, task_number):
    context = review["context"]
    package = Path(review["package"])
    require(package.is_file() and digest(package) == review["package_sha256"],
            "task review package bytes changed")
    sessions = stage["sessions"]
    roots = [session for session in sessions if session.get("agent") == "/root"]
    children = [session for session in sessions if session.get("agent") == context]
    require(len(roots) == len(children) == 1, "missing task reviewer session")
    calls = {}
    allocated = False
    for event in roots[0]["events"]:
        payload = event.get("payload", {})
        if event.get("type") != "response_item":
            continue
        call_id = payload.get("call_id")
        if payload.get("type") == "function_call" and payload.get("name") == "spawn_agent":
            calls[call_id] = json.loads(payload.get("arguments", "{}"))
        elif payload.get("type") == "function_call_output" and call_id in calls:
            if json.loads(payload.get("output", "{}" )).get("task_name") == context:
                require(not allocated, "duplicate task reviewer allocation")
                allocated = True
    require(allocated, "task reviewer identity is not harness-issued")
    reports = [event.get("payload", {}).get("last_agent_message", "")
               for event in children[0]["events"]
               if event.get("type") == "event_msg" and
               event.get("payload", {}).get("type") == "task_complete"]
    require(len(reports) == 1 and "### Spec Compliance" in reports[0] and
            "**Task quality:**" in normalized_task_quality(reports[0]),
            "task reviewer gave no spec and quality verdict")
    if annotation == "review clean":
        require("✅ Spec compliant" in reports[0] and
                "**Task quality:** Approved" in normalized_task_quality(reports[0]),
                "clean completion contradicts task reviewer")
    else:
        parked = int(annotation.split()[0])
        rulings = [line for line in ledger.splitlines()
                   if line.startswith(f"Task {task_number}: parked") and "Ruling:" in line]
        require(len(rulings) >= parked and "Needs fixes" in reports[0],
                "parked completion lacks reviewer finding or recorded rulings")
    native_reads(sessions, context, {package: package.read_text()})


def task_execution(stage, fixture, workspace, number, endpoint):
    brief = workspace / f"task-{number}-brief.md"
    require(brief.is_file(), f"missing Task {number} brief")
    relative = str(brief.relative_to(fixture))
    body = brief.read_text()
    roots = [session for session in stage["sessions"] if session.get("agent") == "/root"]
    require(len(roots) == 1, "missing implementation controller")
    require(roots[0].get("cwd") == str(fixture), "implementation controller cwd changed")
    calls = {}
    issued = {}
    for event in roots[0]["events"]:
        if event.get("type") != "response_item":
            continue
        payload = event.get("payload", {})
        call_id = payload.get("call_id")
        if payload.get("type") == "function_call" and payload.get("name") == "spawn_agent":
            calls[call_id] = event.get("timestamp")
        elif payload.get("type") == "function_call_output" and call_id in calls:
            try:
                context = json.loads(payload.get("output", "")).get("task_name")
            except (AttributeError, ValueError):
                continue
            if isinstance(context, str):
                require(context not in issued, "duplicate implementation actor allocation")
                issued[context] = event.get("timestamp")
    matched = []
    for session in stage["sessions"]:
        context = session.get("agent")
        if context not in issued:
            continue
        require(session.get("cwd") == str(fixture), "implementation actor cwd changed")
        reads = []
        commits = []
        for event in session.get("events", []):
            payload = event.get("payload", {})
            item = payload.get("item", {})
            command = item.get("command")
            if (event.get("type") != "event_msg" or
                    payload.get("completed_at_ms") is None or
                    item.get("type") != "CommandExecution" or
                    item.get("exit_code") != 0 or not isinstance(command, list)):
                continue
            rendered = " ".join(command)
            output = item.get("aggregated_output", "")
            if relative in rendered and body in output:
                reads.append(event.get("timestamp"))
            if re.search(r"\bgit\s+commit\b", rendered) and endpoint[:7] in output:
                commits.append(event.get("timestamp"))
        if reads and commits:
            matched.append((context, issued[context], reads, commits))
    require(len(matched) == 1, f"Task {number} native execution is not bound to one actor")
    context, allocation, reads, commits = matched[0]
    def stamp(value):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except (AttributeError, ValueError):
            raise ValueError("missing or invalid task execution timestamp") from None
        require(parsed.tzinfo is not None, "task execution timestamp has no timezone")
        return parsed
    require(any(stamp(allocation) < stamp(read) < stamp(commit)
                for read in reads for commit in commits),
            f"Task {number} actor did not read brief before its commit")
    return context


def check_migration(evidence, stage, installed):
    fixture = Path(evidence["fixture"]).resolve(strict=True)
    require(git(fixture, "rev-parse", "--show-toplevel") == str(fixture) and
            not git(fixture, "remote"), "migration fixture is not isolated")
    base, head = evidence["base"], evidence["head"]
    ancestral_range(fixture, base, head)
    require(git(fixture, "rev-parse", "HEAD") == head,
            "historical fixture head changed during migration")
    old = Path(evidence["old_projection"])
    successor = Path(evidence["projection"])
    old_ledger = Path(evidence["old_ledger"])
    require(old.is_file() and successor.is_file() and old_ledger.is_file() and
            field(old, "sdd_projection") == "maxi-v1" and
            field(successor, "sdd_projection") == "maxi-v2" and
            field(successor, "predecessor_projection") == str(old) and
            field(successor, "execution_mode") == "final-review-only" and
            "### Task 1:" not in successor.read_text() and
            (fixture / ".superpowers/sdd/active-adapter-sample").read_text() == str(successor) + "\n",
            "completed-v1 migration did not produce empty linked successor")
    old_text = old_ledger.read_text()
    require(f"Maxi projection SHA256: {digest(old)}" in old_text and
            old_text.count("Task 1: complete (commits ") == 1 and
            old_text.count("Task 2: complete (commits ") == 1 and
            base[:7] in old_text and head[:7] in old_text,
            "historical v1 evidence is missing")
    spec_dir = stage["snapshot"] / "docs/maxi/specs/adapter-sample"
    require(field(spec_dir / "spec.md", "status") == "implementing" and
            (spec_dir / "tasks.md").read_text().count("- [x] T") == 2,
            "migration source snapshot is not completed")
    receipt = Path(evidence["receipt"])
    report = Path(evidence["final_review"])
    require(receipt.is_file() and report.is_file() and
            field(receipt, "merge_base") == base and
            field(receipt, "reviewed_head") == head and
            field(receipt, "reviewer_context") == evidence["context"] and
            field(receipt, "projection") == str(successor),
            "migration receipt is not bound to original history")
    terminal_proof(stage["sessions"], installed, Path(evidence["tasks"]), receipt, fixture)
    result = subprocess.run(["bash", str(installed / "x-develop/result-contract.sh"),
                             "--tasks", evidence["tasks"], "--receipt", str(receipt)],
                            cwd=fixture, capture_output=True, text=True)
    require(result.returncode == 0 and result.stdout.splitlines().count("READY_TO_FINISH") == 1,
            "installed migration terminal contract rejected fresh receipt")
    final = reviewer_terminal(stage["sessions"], evidence["context"])
    reviews = review_dispatch(stage["sessions"], evidence["context"],
                              (spec_dir / "spec.md").read_text(),
                              (spec_dir / "plan.md").read_text(), final)
    require(all(message in report.read_text() for message in reviews),
            "migration report omitted fresh native review")
    reviewer_reads(stage["sessions"], evidence["context"],
                   fixture / "docs/maxi/specs/adapter-sample/spec.md",
                   fixture / "docs/maxi/specs/adapter-sample/plan.md",
                   (spec_dir / "spec.md").read_text(),
                   (spec_dir / "plan.md").read_text())


def check(directory):
    evidence = json.loads((directory / "evidence.json").read_text())
    require(evidence.get("version") == 1, "unknown evidence version")
    stage_sequence(evidence["stages"])
    source = Path(evidence["source_skills"]).resolve(strict=True)
    installed = Path(evidence["installed"]).resolve(strict=True)
    fixture = Path(evidence["fixture"]).resolve(strict=True)
    require(git(fixture, "rev-parse", "--show-toplevel") == str(fixture),
            "fixture is not a physical Git root")
    require(not git(fixture, "remote"), "fixture acquired a remote")
    same_tree(source, installed)
    stages = {name: stage_data(directory, name) for name in STAGES}
    require(len({stages[name]["thread"] for name in STAGES[:-1]}) == 1 and
            stages["migration"]["thread"] != stages["resume"]["thread"],
            "resume changed session or migration reused its thread")
    owners = {"design": ("plan", "review"), "tasks": ("tasks",),
              "readiness": ("analyze",), "first-task": ("implement", "x-develop"),
              "resume": ("implement", "x-develop", "using-maxi", "finishing-a-development-branch"),
              "migration": ("x-develop",)}
    installed_map = {str(path): path.read_text() for path in installed.rglob("SKILL.md")}
    for name, required in owners.items():
        for owner in required:
            installed_read(stages[name]["sessions"], installed_map, owner)
    design = stages["design"]["snapshot"]
    design_spec = status(design, "planned", {})
    require(not (design_spec / "tasks.md").exists(), "task extraction preceded design approval")
    verified_design(design, installed)
    design_report = (design_spec / "reviews/design-review.md").read_text()
    design_final = reviewer_terminal(stages["design"]["sessions"], evidence["design_context"])
    operations = re.findall(r"<!-- maxi-design-operation-v1\n(.*?)\n-->",
                            design_report, flags=re.S)
    require(operations and
            operations[0].count("reviewer: " + evidence["design_context"] + "\n") == 1 and
            design_final in design_report and design_final.strip().endswith("VERDICT: approved"),
            "managed design reviewer or verdict is missing")
    review_dispatch(stages["design"]["sessions"], evidence["design_context"],
                    (design_spec / "spec.md").read_text(), (design_spec / "plan.md").read_text(),
                    design_final)
    reviewer_reads(stages["design"]["sessions"], evidence["design_context"],
                   fixture / "docs/maxi/specs/0001-upgrade/spec.md",
                   fixture / "docs/maxi/specs/0001-upgrade/plan.md",
                   (design_spec / "spec.md").read_text(),
                   (design_spec / "plan.md").read_text())
    status(stages["tasks"]["snapshot"], "tasked", {1: " ", 2: " "})
    readiness = stages["readiness"]["snapshot"]
    status(readiness, "analyzed", {1: " ", 2: " "})
    verified_readiness(readiness, installed)
    first_stage = stages["first-task"]["snapshot"]
    status(first_stage, "implementing", {1: "x", 2: " "})
    resume = stages["resume"]["snapshot"]
    resume_spec = status(resume, "done", {1: "x", 2: "x"})
    base, first, second = (evidence[key] for key in ("base", "first", "head"))
    ancestral_range(fixture, base, first)
    ancestral_range(fixture, first, second)
    require(subprocess.run(["git", "-C", str(fixture), "merge-base", "--is-ancestor",
            second, "HEAD"]).returncode == 0,
            "reviewed head is not in final fixture history")
    require((first_stage / "head.txt").read_text() == first + "\n", "first task head is missing")
    first_ledger = (first_stage / "progress.md").read_text()
    last_ledger = (resume / "progress.md").read_text()
    def completion(ledger, number, start, end):
        matches = re.findall(
            rf"(?m)^Task {number}: complete \(commits {start[:7]}\.\.{end[:7]}, "
            r"(review clean|[1-9][0-9]* parked)\)$", ledger)
        require(len(matches) == 1, f"missing canonical Task {number} completion")
        return (f"Task {number}: complete (commits {start[:7]}..{end[:7]}, "
                f"{matches[0]})", matches[0])
    first_line, first_annotation = completion(first_ledger, 1, base, first)
    second_line, second_annotation = completion(last_ledger, 2, first, second)
    require(first_ledger.count(first_line) == 1 and second_line not in first_ledger and
            last_ledger.startswith(first_ledger) and
            last_ledger[len(first_ledger):].count("Task 1: selected") == 0 and
            last_ledger[len(first_ledger):].count("Task 1: pending") == 0 and
            last_ledger.count(first_line) == 1 and last_ledger.count(second_line) == 1,
            "task completion or reconciliation evidence changed")
    reviews = evidence["task_reviews"]
    require(len(reviews) == 2 and [review["stage"] for review in reviews] ==
            ["first-task", "resume"], "task review stages are incomplete")
    for number, (review, annotation) in enumerate(
            zip(reviews, (first_annotation, second_annotation)), 1):
        task_review(stages[review["stage"]], review, annotation, last_ledger, number)
    workspace = Path(evidence["ledger"]).parent
    first_actor = task_execution(stages["first-task"], fixture, workspace, 1, first)
    second_actor = task_execution(stages["resume"], fixture, workspace, 2, second)
    require(first_actor != second_actor and
            all(session.get("agent") != first_actor for session in stages["resume"]["sessions"]),
            "Task 1 execution actor was replayed during resume")
    require(git(fixture, "show", f"{first}:core.py") == (fixture / "core.py").read_text().strip(),
            "first task core.py was modified during resume")
    receipt = Path(evidence["receipt"])
    final_review = Path(evidence["final_review"])
    require(receipt.is_file() and final_review.is_file() and
            (resume / "receipt.md").read_bytes() == receipt.read_bytes(),
            "terminal receipt is missing or changed")
    reviewed_head = field(receipt, "reviewed_head")
    require(field(receipt, "merge_base") == base and
            field(receipt, "reviewer_context") == evidence["context"] and
            field(receipt, "full_review_package_sha256") == digest(Path(field(receipt, "full_review_package"))),
            "terminal receipt binds wrong review range or package")
    ancestral_range(fixture, base, reviewed_head)
    require(subprocess.run(["git", "-C", str(fixture), "merge-base", "--is-ancestor",
                            second, reviewed_head]).returncode == 0 and
            subprocess.run(["git", "-C", str(fixture), "merge-base", "--is-ancestor",
                            reviewed_head, "HEAD"]).returncode == 0,
            "final review does not descend from task completion")
    ready_index = terminal_proof(stages["resume"]["sessions"], installed,
                                 Path(evidence["tasks"]), receipt, fixture)
    finish_order(stages["resume"]["sessions"], ready_index,
                 fixture / "docs/maxi/specs/0001-upgrade/spec.md")
    boundary_proof(fixture, Path(evidence["pre_done_fixture"]), evidence["projection"],
                   evidence["postturn_verifier"])
    final_body = final_review.read_text().split("\n---\n", 1)[1].lstrip("\n")
    boundary_spec = Path(evidence["pre_done_fixture"]) / "docs/maxi/specs/0001-upgrade"
    actual_final = reviewer_terminal(stages["resume"]["sessions"], evidence["context"])
    native_reviews = review_dispatch(stages["resume"]["sessions"], evidence["context"],
                    (boundary_spec / "spec.md").read_text(),
                    (boundary_spec / "plan.md").read_text(), actual_final)
    require(all(message in final_body for message in native_reviews),
            "final review omitted native reviewer component")
    reviewer_reads(stages["resume"]["sessions"], evidence["context"],
                   fixture / "docs/maxi/specs/0001-upgrade/spec.md",
                   fixture / "docs/maxi/specs/0001-upgrade/plan.md",
                   (boundary_spec / "spec.md").read_text(),
                   (boundary_spec / "plan.md").read_text())
    closure_messages = [event["item"].get("text", "") for event in
                        (json.loads(line) for line in (directory / "stages/resume/cli.jsonl").read_text().splitlines())
                        if event.get("type") == "item.completed" and
                        event.get("item", {}).get("type") == "agent_message"]
    require(any(re.search(r"Git outcome:\s*(?:\*\*)?deliberately retained(?:\*\*)?",
                          message) for message in closure_messages),
            "Git closure outcome is absent")
    check_migration(evidence["migration"], stages["migration"], installed)
    return {"result": "verified", "reviewed_head": reviewed_head}


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            raise ValueError("usage: check-evidence.py EVIDENCE_DIR")
        print(json.dumps(check(Path(sys.argv[1]).resolve(strict=True))))
    except (OSError, KeyError, ValueError, TypeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
