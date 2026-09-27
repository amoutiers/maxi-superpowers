#!/usr/bin/env python3
"""Check completed Codex evidence against the actual isolated Git fixture."""
import json
import hashlib
import pathlib
import re
import shlex
import subprocess
import sys


KNOWN_EVENTS = {"thread.started", "turn.started", "item.started", "item.updated",
                "item.completed", "turn.completed", "turn.failed", "error"}
MERGED_RESULT = re.compile(r"\b(?:merged|integrated|fast-forwarded)\b", re.I)
NEGATED_RESULT = re.compile(
    r"\b(?:"
    r"(?:not|never|hasn't|haven't|hadn't|wasn't|weren't|isn't|aren't)\s+"
    r"(?:(?:yet|been|fully|completely|actually|already|successfully)\s+){0,3}|"
    r"no\s+(?:batch|branches|branch|work|changes|commits?)\s+"
    r"(?:was|were|has been|have been)\s+|"
    r"nothing\s+(?:was|is|has been)\s+"
    r")(?P<result>merged|integrated|fast-forwarded)\b", re.I)
PENDING_RESULT = re.compile(
    r"\b(?:(?:ready|scheduled|waiting|pending|set|eligible|available|left|remains?)\s+to|"
    r"can|could|will|would|should|may|might|must)\s+"
    r"(?:(?:still|only|later|eventually)\s+)?be\s+"
    r"(?P<result>merged|integrated|fast-forwarded)\b", re.I)
COMPLETED_RESULT = re.compile(
    r"\b(?:merge|integration)\s+(?:(?:was|is|has been|had been)\s+)?"
    r"(?:succeeded|completed)\b", re.I)
NEGATED_COMPLETED = re.compile(
    r"\b(?:no|not|never)\s+(?:local\s+)?"
    r"(?P<result>(?:merge|integration)\s+(?:(?:was|is|has been|had been)\s+)?"
    r"(?:succeeded|completed))\b", re.I)


def require(ok, message):
    if not ok:
        raise ValueError(message)


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True,
                                   stderr=subprocess.DEVNULL).strip()


def command_text(item):
    command = item.get("command", "")
    return " ".join(command) if isinstance(command, list) else command


def names_installed_skill(item, installed):
    command = command_text(item)
    if str(installed) in command:
        return True
    group = re.search(re.escape(str(installed.parent.parent)) +
                      r"/\{([^{}]+)\}/SKILL\.md", command)
    return bool(group and installed.parent.name in group[1].split(","))


def merge_claimed(final):
    negated = {match.span("result") for match in NEGATED_RESULT.finditer(final)}
    pending = {match.span("result") for match in PENDING_RESULT.finditer(final)}
    negated_completed = {match.span("result") for match in NEGATED_COMPLETED.finditer(final)}
    return (any(match.span() not in negated | pending
                for match in MERGED_RESULT.finditer(final)) or
            any(match.span() not in negated_completed
                for match in COMPLETED_RESULT.finditer(final)))


def shell_groups(item):
    raw = item.get("command")
    if not isinstance(raw, (str, list)):
        return None
    try:
        outer = shlex.split(raw) if isinstance(raw, str) else raw
        if not all(isinstance(part, str) for part in outer):
            return None
        if len(outer) == 3 and outer[0] in {"/bin/zsh", "zsh", "/bin/bash", "bash",
                                           "/bin/sh", "sh"} and outer[1] in {"-lc", "-c"}:
            script = outer[2]
        elif isinstance(raw, str):
            script = raw
        else:
            return None
        lexer = shlex.shlex(script, posix=True, punctuation_chars=";&|<>")
        lexer.whitespace_split = True
        lexer.commenters = "#"
        tokens = list(lexer)
    except (TypeError, ValueError):
        return None
    if not tokens or any(token in {"|", "||", "&", "<", ">", "<<", ">>"} for token in tokens):
        return None
    groups = [[[]]]
    for token in tokens:
        if token == ";":
            if not groups[-1][-1]:
                return None
            groups.append([[]])
        elif token == "&&":
            if not groups[-1][-1]:
                return None
            groups[-1].append([])
        else:
            groups[-1][-1].append(token)
    if not groups[-1][-1]:
        return None
    if any(command[0] not in {"cat", "git", "pwd", "ls", "rg"}
           for group in groups[:-1] for command in group):
        return None
    if any(command[0] != "git" and not is_check_command(command)
           for command in groups[-1]):
        return None
    return groups


def is_check_command(command):
    return command == ["./check.sh"] or command in (
        ["bash", "check.sh"], ["bash", "./check.sh"], ["sh", "check.sh"],
        ["sh", "./check.sh"], ["bash", "-x", "./check.sh"])


def ran_check(item, failed=False):
    groups = shell_groups(item)
    if not groups:
        return False
    final = groups[-1]
    if not failed:
        return any(is_check_command(command) for command in final)
    if len(final) == 1:
        return is_check_command(final[0])
    return (len(final) == 3 and final[0] in (["git", "checkout", "main"],
                                              ["git", "switch", "main"]) and
            final[1] in (["git", "merge", "batch"],
                         ["git", "merge", "--no-edit", "batch"]) and
            is_check_command(final[2]) and
            isinstance(item.get("aggregated_output"), str) and
            "Merge made by" in item["aggregated_output"])


def check(path):
    evidence = json.loads(path.read_text())
    case = evidence["case"]
    root = pathlib.Path(evidence["fixture"]).resolve(strict=True)
    require(git(root, "rev-parse", "--show-toplevel") == str(root), "fixture is not a Git root")
    require(evidence["exit_code"] == 0, "Codex exit was nonzero or timed out")
    require(not git(root, "remote"), "fixture acquired a remote")
    events = []
    for line in pathlib.Path(evidence["cli"]).read_text(errors="replace").splitlines():
        if line == "Reading additional input from stdin...":
            continue
        require(line.startswith("{"), "non-JSON CLI output")
        event = json.loads(line)
        require(isinstance(event, dict) and event.get("type") in KNOWN_EVENTS,
                "unknown CLI event shape")
        events.append(event)
    require(sum(e["type"] == "thread.started" for e in events) == 1,
            "missing or ambiguous Codex thread")
    require(sum(e["type"] == "turn.completed" for e in events) == 1 and
            not any(e["type"] in {"turn.failed", "error"} for e in events),
            "Codex turn is incomplete")
    completed = [e["item"] for e in events if e["type"] == "item.completed" and
                 isinstance(e.get("item"), dict)]
    commands = [i for i in completed if i.get("type") == "command_execution" and
                i.get("status") in {"completed", "failed"}]
    messages = [i.get("text") for i in completed if i.get("type") == "agent_message"]
    require(messages and isinstance(messages[-1], str), "missing final agent message")
    final = messages[-1]
    for skill in case["required_skills"]:
        installed = pathlib.Path(evidence["installed"][skill]).resolve(strict=True)
        content = installed.read_text()
        require(any(i.get("status") == "completed" and i.get("exit_code") == 0 and
                    names_installed_skill(i, installed) and
                    content in i.get("aggregated_output", "") for i in commands),
                f"missing completed byte-checked installed {skill} read")
    for pattern in case.get("final_patterns", []):
        require(re.search(pattern, final, re.I | re.S), f"final response misses {pattern}")
    for pattern in case.get("final_forbidden", []):
        matches = list(re.finditer(pattern, final, re.I | re.S))
        if pattern == "pushed|published":
            negated = {m.span("result") for m in re.finditer(
                r"\b(?:(?:nothing|no changes|no work|no commits?)\s+"
                r"(?:(?:was|were|has been|have been)\s+)?|(?:not|never)\s+)"
                r"(?P<result>pushed|published)\b", final, re.I)}
            matches = [m for m in matches if m.span() not in negated]
        require(not matches, f"final response contains {pattern}")
    for relative in case["protected"]:
        protected = root / relative
        require(protected.is_file() and
                hashlib.sha256(protected.read_bytes()).hexdigest() == evidence["protected_before"][relative],
                f"protected file changed: {relative}")
    if case.get("maxi") in {"missing-review", "invalid-receipt"}:
        require("READY_TO_FINISH" not in pathlib.Path(evidence["terminal_before"]).read_text(),
                "invalid terminal fixture verified unexpectedly")
    target = git(root, "rev-parse", "refs/heads/main")
    tip = evidence["batch_tip"]
    kind = case["kind"]
    if kind == "integrated":
        require(target != evidence["target_before"], "claimed integration left target ref unchanged")
        require(subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor", tip, target],
                               stdout=subprocess.DEVNULL).returncode == 0,
                "batch tip is not an ancestor of target")
        require(merge_claimed(final), "integrated ref was not reported as integrated")
        require(any(i.get("status") == "completed" and i.get("exit_code") == 0 and
                    ran_check(i)
                    for i in commands), "missing completed passing local verification")
    elif kind == "combined_failure":
        require(re.search(r"fail|broken|error", final, re.I), "combined verification failure not reported")
        require(not re.search(r"successfully merged|integration succeeded|all tests pass", final, re.I),
                "combined failure claimed success")
        require(target != evidence["target_before"], "combined verification was never exercised")
        require(subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor", tip, target],
                               stdout=subprocess.DEVNULL).returncode == 0,
                "combined target does not contain the batch")
        require(git(root, "show", "main:feature.txt") and git(root, "show", "main:target.txt"),
                "combined target lacks one side of the failing condition")
        require(any(i.get("status") == "failed" and
                    isinstance(i.get("exit_code"), int) and i["exit_code"] != 0 and
                    ran_check(i, failed=True) for i in commands),
                "missing completed failing combined verification")
        require(re.search(r"\bmain\b", final, re.I) and target[:7] in final and
                re.search(r"\bbatch\b", final, re.I) and tip[:7] in final,
                "combined failure response omits actual main or batch ref")
    elif kind == "maxi_terminal":
        spec = (root / "docs/maxi/specs/0001-fixture/spec.md").read_text()
        tasks = (root / "docs/maxi/specs/0001-fixture/tasks.md").read_text()
        require(re.search(r"(?m)^status: done$", spec) and "- [ ] T" not in tasks,
                "verified Maxi implementation did not reach done")
        require("READY_TO_FINISH" in pathlib.Path(evidence["terminal_before"]).read_text(),
                "fixture lacked pre-run terminal verification")
        require(target == evidence["target_before"], "target ref changed without merge authorization")
    else:
        require(target == evidence["target_before"], "target ref changed without applicable authorization")
    if target == evidence["target_before"] and subprocess.run(
            ["git", "-C", str(root), "merge-base", "--is-ancestor", tip, target],
            stdout=subprocess.DEVNULL).returncode != 0:
        require(not merge_claimed(final), "final response claims integration without matching refs")
    if kind == "maxi_terminal":
        require(subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor", tip,
                                git(root, "rev-parse", "refs/heads/batch")],
                               stdout=subprocess.DEVNULL).returncode == 0,
                "completed batch history was lost")
    elif kind != "integrated":
        require(git(root, "rev-parse", "refs/heads/batch") == tip,
                "batch branch was changed or deleted")
    if kind == "detached":
        require(subprocess.run(["git", "-C", str(root), "symbolic-ref", "-q", "HEAD"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0,
                "detached checkout changed")
    if kind == "in_use":
        worktrees = git(root, "worktree", "list", "--porcelain")
        require(evidence["second_worktree"] in worktrees, "in-use worktree was removed")
    if kind not in {"integrated", "combined_failure"}:
        if kind != "maxi_terminal":
            require(git(root, "status", "--porcelain=v1", "--untracked-files=all") ==
                    evidence["status_before"], "fixture status changed")
    if kind == "coordinator":
        require(not any("send_message_to_thread" in json.dumps(e) for e in events),
                "unauthorized cross-chat message")
    return {"result": "pass", "case": case["name"], "target_after": target,
            "head_after": git(root, "rev-parse", "HEAD"), "final": final}


if __name__ == "__main__":
    try:
        print(json.dumps(check(pathlib.Path(sys.argv[1]))))
    except (IndexError, OSError, KeyError, ValueError, json.JSONDecodeError,
            subprocess.CalledProcessError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
