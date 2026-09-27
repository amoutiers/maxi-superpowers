#!/usr/bin/env python3
"""Regression checks for the installed upgrade evidence gate."""
import json
import importlib.util
import hashlib
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile
import unittest


CHECKER = Path(__file__).with_name("check-evidence.py")
SKILLS = CHECKER.parents[3] / "skills"
SPEC = importlib.util.spec_from_file_location("upgrade_checker", CHECKER)
sys.dont_write_bytecode = True
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def run(*args, cwd=None):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def status_file(path, status):
    text = path.read_text()
    for old in ("planned", "tasked", "analyzed", "implementing", "done"):
        text = text.replace(f"status: {old}", f"status: {status}")
    path.write_text(text)


def record_stage(root, installed, name, owners, thread, review=None, proof=None,
                 reviewer_paths=()):
    stage_dir = root / "stages" / name
    fixture = root / ("migration-fixture" if name == "migration" else "fixture")
    stage_dir.mkdir(parents=True, exist_ok=True)
    root_events = []
    cli = [{"type": "thread.started", "thread_id": thread}, {"type": "turn.started"}]
    for owner in owners:
        skill = installed / owner / "SKILL.md"
        command = ["/bin/zsh", "-lc", f"cat {skill}"]
        item = {"type": "CommandExecution", "command": command, "exit_code": 0,
                "aggregated_output": skill.read_text()}
        root_events.append({"type": "event_msg", "payload": {"item": item, "completed_at_ms": 1}})
        cli.append({"type": "item.completed", "item": {"type": "command_execution",
                    "status": "completed", "exit_code": 0, "command": command,
                    "aggregated_output": skill.read_text()}})
    sessions = [{"agent": "/root", "cwd": str(fixture), "events": root_events}]
    if review:
        context, spec, plan, final = review
        root_events.extend([
            {"type": "response_item", "timestamp": "2026-09-27T11:00:00.000Z", "payload": {"type": "function_call", "name": "spawn_agent",
                "call_id": "alloc", "arguments": json.dumps({"task_name": context.rsplit("/", 1)[1],
                                                     "message": "Identity only"})}},
            {"type": "response_item", "timestamp": "2026-09-27T11:00:01.000Z", "payload": {"type": "function_call_output",
                "call_id": "alloc", "output": json.dumps({"task_name": context})}},
            {"type": "response_item", "timestamp": "2026-09-27T11:00:02.000Z", "payload": {"type": "function_call", "name": "followup_task",
                "call_id": "review", "arguments": json.dumps({"target": context,
                    "message": f"Review this spec:\n{spec}\nThis plan:\n{plan}"})}},
            {"type": "response_item", "timestamp": "2026-09-27T11:00:03.000Z", "payload": {"type": "function_call_output",
                "call_id": "review", "output": ""}},
        ])
        child_events = [
            {"type": "event_msg", "timestamp": "2026-09-27T10:59:59.000Z", "payload": {"type": "item_completed", "turn_id": "identity-turn",
                "completed_at_ms": 1, "item": {"type": "AgentMessage", "phase": "final_answer",
                    "content": [{"type": "Text", "text": "Identity ready"}]}}},
            {"type": "event_msg", "timestamp": "2026-09-27T10:59:59.500Z", "payload": {"type": "task_complete", "turn_id": "identity-turn",
                "last_agent_message": "Identity ready"}},
        ]
        for path, content in reviewer_paths:
            child_events.append({"type": "event_msg", "payload": {"item": {
                "type": "CommandExecution", "command": ["/bin/zsh", "-lc", f"cat {path}"],
                "exit_code": 0, "aggregated_output": content}, "completed_at_ms": 2}})
        child_events.extend([
            {"type": "event_msg", "timestamp": "2026-09-27T11:00:04.000Z", "payload": {"type": "item_completed", "turn_id": "review-turn",
                "completed_at_ms": 2, "item": {"type": "AgentMessage", "phase": "final_answer",
                    "content": [{"type": "Text", "text": final}]}}},
            {"type": "event_msg", "timestamp": "2026-09-27T11:00:05.000Z", "payload": {"type": "task_complete", "turn_id": "review-turn",
                "last_agent_message": final}},
        ])
        sessions.append({"agent": context, "cwd": str(fixture), "events": child_events})
    if proof:
        command, output = proof
        command = ["/bin/zsh", "-lc", shlex.join(command)]
        cli.append({"type": "item.completed", "item": {"type": "command_execution",
                    "status": "completed", "exit_code": 0, "command": command,
                    "aggregated_output": output}})
        root_events.append({"type": "event_msg", "payload": {"item": {
            "type": "CommandExecution", "command": command, "exit_code": 0,
            "aggregated_output": output}, "completed_at_ms": 3}})
    if name == "resume":
        spec_path = root / "fixture/docs/maxi/specs/0001-upgrade/spec.md"
        root_events.append({"type": "event_msg", "payload": {"item": {
            "type": "CommandExecution",
            "command": ["/bin/zsh", "-lc", f"grep '^status: done$' {spec_path}"],
            "exit_code": 0, "aggregated_output": "status: done\n"}, "completed_at_ms": 4}})
        root_events.append({"type": "event_msg", "payload": {"type": "task_complete",
            "turn_id": "resume-turn", "last_agent_message": "Git outcome: **deliberately retained**"}})
    cli.extend([{"type": "item.completed", "item": {"type": "agent_message",
                "text": "Git outcome: **deliberately retained**" if name == "resume" else "Stage complete"}},
                {"type": "turn.completed"}])
    (stage_dir / "cli.jsonl").write_text("".join(json.dumps(item) + "\n" for item in cli))
    (stage_dir / "sessions.json").write_text(json.dumps(sessions))


def add_task_review(root, stage, context, package):
    path = root / "stages" / stage / "sessions.json"
    sessions = json.loads(path.read_text())
    root_events = next(item for item in sessions if item["agent"] == "/root")["events"]
    root_events.extend([
        {"type": "response_item", "payload": {"type": "function_call", "name": "spawn_agent",
            "call_id": "task-review", "arguments": json.dumps({"task_name": context.rsplit("/", 1)[1],
                                                       "message": "Review task package"})}},
        {"type": "response_item", "payload": {"type": "function_call_output",
            "call_id": "task-review", "output": json.dumps({"task_name": context})}},
    ])
    report = ("### Spec Compliance\n\n- ✅ Spec compliant\n\n### Strengths\n\n"
              "The file matches the task.\n\n### Issues\n\nNone.\n\n"
              "### Assessment\n\n**Task quality:** Approved\n")
    sessions.append({"agent": context, "cwd": str(root / "fixture"), "events": [
        {"type": "event_msg", "payload": {"item": {
            "type": "CommandExecution", "command": ["/bin/zsh", "-lc", f"cat {package}"],
            "exit_code": 0, "aggregated_output": package.read_text()}, "completed_at_ms": 1}},
        {"type": "event_msg", "payload": {"type": "item_completed", "turn_id": "task-review-turn",
            "completed_at_ms": 2, "item": {"type": "AgentMessage", "phase": "final_answer",
                "content": [{"type": "Text", "text": report}]}}},
        {"type": "event_msg", "payload": {"type": "task_complete", "turn_id": "task-review-turn",
            "last_agent_message": report}},
    ]})
    path.write_text(json.dumps(sessions))
    return {"stage": stage, "context": context, "package": str(package),
            "package_sha256": sha(package)}


def add_task_execution(root, stage, fixture, workspace, number, endpoint):
    brief = workspace / f"task-{number}-brief.md"
    brief.write_text(f"### Task {number}: fixture implementation brief\n")
    sessions_path = root / "stages" / stage / "sessions.json"
    sessions = json.loads(sessions_path.read_text())
    root_events = next(item["events"] for item in sessions if item["agent"] == "/root")
    context = f"/root/task{number}_implementer"
    allocation = [
        {"type": "response_item", "timestamp": "2026-09-27T10:58:00.000Z",
         "payload": {"type": "function_call", "name": "spawn_agent", "call_id": f"task{number}",
                     "arguments": json.dumps({"task_name": context.rsplit("/", 1)[1],
                                              "message": "Implement fixture task"})}},
        {"type": "response_item", "timestamp": "2026-09-27T10:58:01.000Z",
         "payload": {"type": "function_call_output", "call_id": f"task{number}",
                     "output": json.dumps({"task_name": context})}},
    ]
    index = next((index for index, event in enumerate(root_events)
                  if event.get("payload", {}).get("name") == "spawn_agent"), len(root_events))
    root_events[index:index] = allocation
    relative = brief.relative_to(fixture)
    child = {"agent": context, "cwd": str(fixture), "events": [
        {"type": "event_msg", "timestamp": "2026-09-27T10:58:02.000Z",
         "payload": {"completed_at_ms": 2, "item": {"type": "CommandExecution", "exit_code": 0,
                     "command": ["/bin/zsh", "-lc", f"cat {relative}"],
                     "aggregated_output": brief.read_text()}}},
        {"type": "event_msg", "timestamp": "2026-09-27T10:58:03.000Z",
         "payload": {"completed_at_ms": 3, "item": {"type": "CommandExecution", "exit_code": 0,
                     "command": ["/bin/zsh", "-lc", "git commit -m fixture"],
                     "aggregated_output": f"[main {endpoint[:7]}] fixture task\n"}}},
    ]}
    sessions.append(child)
    sessions_path.write_text(json.dumps(sessions))


def make_migration(root, installed):
    fixture = root / "migration-fixture"
    spec_dir = fixture / "docs/maxi/specs/adapter-sample"
    spec_dir.mkdir(parents=True)
    spec = spec_dir / "spec.md"
    plan = spec_dir / "plan.md"
    tasks = spec_dir / "tasks.md"
    spec.write_text("---\nslug: adapter-sample\nstatus: implementing\n"
                    "design_cycle: 0\n---\n# Historical work\n")
    plan.write_text("# Historical plan\n\n## Global Constraints\n\n- Keep history.\n\n"
                    "## Review Focus\n\n- Check both historical files.\n\n"
                    "### Task 1: First historical file\n\nWrite historical-one.txt.\n\n"
                    "### Task 2: Second historical file\n\nWrite historical-two.txt.\n")
    tasks.write_text("---\nspec_slug: adapter-sample\n---\n"
                     "- [ ] T001 First historical file (plan Task 1)\n"
                     "- [ ] T002 Second historical file (plan Task 2)\n")
    (fixture / ".gitignore").write_text(".superpowers/\n")
    run("git", "init", "-q", "-b", "main", str(fixture))
    run("git", "-C", str(fixture), "config", "user.name", "Upgrade Test")
    run("git", "-C", str(fixture), "config", "user.email", "upgrade@example.invalid")
    run("git", "-C", str(fixture), "add", ".")
    run("git", "-C", str(fixture), "commit", "-qm", "historical base")
    base = run("git", "-C", str(fixture), "rev-parse", "HEAD")
    previous = base
    completions = []
    for number in (1, 2):
        (fixture / f"historical-{number}.txt").write_text(f"historical {number}\n")
        run("git", "-C", str(fixture), "add", f"historical-{number}.txt")
        run("git", "-C", str(fixture), "commit", "-qm", f"historical task {number}")
        current = run("git", "-C", str(fixture), "rev-parse", "HEAD")
        completions.append(f"Task {number}: complete (commits {previous[:7]}..{current[:7]}, review clean)")
        previous = current
    head = previous
    emitter = SKILLS.parent / "tests/fixtures/x-develop-adapter/emit-v1.sh"
    old_projection = run("bash", str(emitter), str(fixture))
    old_ledger = fixture / ".superpowers/sdd" / Path(old_projection).stem / "progress.md"
    with old_ledger.open("a") as stream:
        stream.write("\n".join(completions) + "\n")
    tasks.write_text(tasks.read_text().replace("- [ ]", "- [x]"))
    projection = run("bash", str(installed / "x-develop/project-tasks.sh"),
                     "--spec", str(spec), "--plan", str(plan), "--tasks", str(tasks),
                     "--output", str(fixture / ".superpowers/sdd/projections/requested.md"),
                     "--state-file", str(fixture / ".superpowers/sdd/active-adapter-sample"),
                     cwd=fixture)
    workspace = fixture / ".superpowers/sdd" / Path(projection).stem
    ledger = workspace / "progress.md"
    package = workspace / "review-full.diff"
    run("bash", str(installed / "subagent-driven-development/scripts/review-package"),
        projection, base, head, str(package), cwd=fixture)
    context = "/root/migration_reviewer"
    (workspace / "final-reviewer-dispatch.identity").write_text(f"reviewer_context: {context}\n")
    final = "### Assessment\n\nThe historical range is complete.\n\n**Ready to merge?** Yes\n"
    final_review = workspace / "maxi-final-review.md"
    final_review.write_text("---\n" + "\n".join((
        f"worktree: {fixture}", f"merge_base: {base}", f"reviewed_head: {head}",
        f"reviewed_tree: {run('git', '-C', str(fixture), 'rev-parse', 'HEAD^{tree}')}",
        f"projection: {projection}", f"projection_sha256: {sha(Path(projection))}",
        f"full_review_package: {package}", f"full_review_package_sha256: {sha(package)}",
        "fix_review_package: null", "fix_review_package_sha256: null",
        f"spec: {spec}", f"spec_sha256: {sha(spec)}", f"tasks: {tasks}",
        f"tasks_sha256: {sha(tasks)}", f"reviewer_context: {context}", "outcome: finish",
    )) + "\n---\n\n" + final)
    receipt = workspace / "terminal-receipt.md"
    run("bash", str(installed / "x-develop/record-terminal.sh"), "--worktree", str(fixture),
        "--merge-base", base, "--projection", projection, "--ledger", str(ledger),
        "--final-review", str(final_review), "--spec", str(spec), "--tasks", str(tasks),
        "--output", str(receipt), cwd=fixture)
    result = run("bash", str(installed / "x-develop/result-contract.sh"), "--tasks", str(tasks),
                 "--receipt", str(receipt), cwd=fixture)
    assert "READY_TO_FINISH" in result.splitlines()
    boundary = root / "migration-pre-done-fixture"
    shutil.copytree(fixture, boundary)
    # The historical seed has no live task verdict. Its new final review is
    # represented as a recorded-shape reviewer event only in this checker test.
    record_stage(root, installed, "migration", ["x-develop"], "migration-thread",
                 (context, spec.read_text(), plan.read_text(), final),
                 (["bash", str(installed / "x-develop/result-contract.sh"),
                   "--tasks", str(tasks), "--receipt", str(receipt)], result + "\n"),
                 reviewer_paths=((spec, spec.read_text()), (plan, plan.read_text())))
    shutil.copytree(fixture / "docs", root / "stages/migration/snapshot/docs")
    return {"fixture": str(fixture), "old_projection": old_projection,
            "projection": projection, "base": base, "head": head,
            "old_ledger": str(old_ledger), "ledger": str(ledger),
            "receipt": str(receipt), "final_review": str(final_review),
            "context": context, "tasks": str(tasks), "pre_done_fixture": str(boundary)}


def make_complete(directory):
    root = directory.resolve()
    fixture = root / "fixture"
    spec_dir = fixture / "docs/maxi/specs/0001-upgrade"
    reviews = spec_dir / "reviews"
    reviews.mkdir(parents=True)
    installed = root / "installed-skills"
    shutil.copytree(SKILLS, installed)
    constitution = fixture / "docs/maxi/constitution.md"
    constitution.write_text("# Constitution\n\nUse the complete Maxi pipeline.\n")
    spec = spec_dir / "spec.md"
    plan = spec_dir / "plan.md"
    tasks = spec_dir / "tasks.md"
    spec.write_text("---\nslug: 0001-upgrade\ncreated: 2026-09-27\nupdated: 2026-09-27\n"
                    "status: planned\ndesign_cycle: 0\nrelated_adrs: []\n---\n# Upgrade fixture\n"
                    "\nCreate core.py and line_counter.py in separate tasks.\n")
    plan.write_text("# Plan\n\n## Global Constraints\n\n- No network.\n\n## Review Focus\n\n"
                    "- Task 1 checks core.py with test-one.sh.\n\n"
                    "### Task 1: First file\n\nCreate core.py and verify it.\n\n"
                    "### Task 2: Second file\n\nCreate line_counter.py and verify it.\n")
    design_context = "/root/design_reviewer"
    report = reviews / "design-review.md"
    design_candidate = reviews / "candidate.md"
    operation = sha(spec)
    request = sha(plan)
    run("bash", str(installed / "review/design-contract.sh"), "reserve", str(report),
        str(spec), str(plan), str(fixture), operation, request, "coordinated",
        design_context, "absent")
    design_candidate.write_text(report.read_text().replace("phase: reserved", "phase: approved", 1)
                                + "\nVERDICT: approved\n")
    inputs = run("bash", str(installed / "review/review-inputs.sh"), "hash", str(fixture))
    run("bash", str(installed / "review/design-contract.sh"), "stamp-operation",
        str(design_candidate), str(report), str(spec), str(plan), "approved",
        str(fixture), inputs, operation, sha(report))
    design_snapshot = root / "stages/design/snapshot"
    shutil.copytree(fixture / "docs", design_snapshot / "docs")
    tasks.write_text("---\nspec_slug: 0001-upgrade\nupdated: 2026-09-27\n---\n"
                     "- [ ] T001 Create core.py (plan Task 1)\n"
                     "- [ ] T002 Create line_counter.py (plan Task 2)\n")
    status_file(spec, "tasked")
    tasks_snapshot = root / "stages/tasks/snapshot"
    shutil.copytree(fixture / "docs", tasks_snapshot / "docs")
    readiness_candidate = spec_dir / "readiness-candidate.md"
    readiness_candidate.write_text("# Readiness review\n\nNo critical issues.\n")
    run("bash", str(installed / "analyze/readiness-contract.sh"), "stamp",
        str(readiness_candidate), str(spec_dir / "analysis.md"), str(spec), str(plan),
        str(tasks), "pass", "0", str(fixture), inputs)
    status_file(spec, "analyzed")
    readiness_snapshot = root / "stages/readiness/snapshot"
    shutil.copytree(fixture / "docs", readiness_snapshot / "docs")
    design_candidate.unlink()
    readiness_candidate.unlink()
    (fixture / ".gitignore").write_text(".superpowers/\n")
    run("git", "init", "-q", "-b", "main", str(fixture))
    run("git", "-C", str(fixture), "config", "user.name", "Upgrade Test")
    run("git", "-C", str(fixture), "config", "user.email", "upgrade@example.invalid")
    run("git", "-C", str(fixture), "add", ".")
    run("git", "-C", str(fixture), "commit", "-qm", "fixture base")
    base = run("git", "-C", str(fixture), "rev-parse", "HEAD")
    status_file(spec, "implementing")
    projection = run("bash", str(installed / "x-develop/project-tasks.sh"), "--spec", str(spec),
                     "--plan", str(plan), "--tasks", str(tasks), "--output",
                     str(fixture / ".superpowers/sdd/projections/requested.md"), "--state-file",
                     str(fixture / ".superpowers/sdd/active-0001-upgrade"), cwd=fixture)
    workspace = fixture / ".superpowers/sdd" / Path(projection).stem
    ledger = workspace / "progress.md"
    for number in (1, 2):
        (workspace / f"task-{number}-brief.md").write_text(
            f"### Task {number}: fixture implementation brief\n")
    (fixture / "core.py").write_text("def count_nonempty(text):\n    return 1\n")
    run("git", "-C", str(fixture), "add", "core.py")
    run("git", "-C", str(fixture), "commit", "-qm", "first task")
    first = run("git", "-C", str(fixture), "rev-parse", "HEAD")
    task_one_package = workspace / "review-task-1.diff"
    run("bash", str(installed / "subagent-driven-development/scripts/review-package"),
        projection, base, first, str(task_one_package), cwd=fixture)
    with ledger.open("a") as stream:
        stream.write(f"Task 1: complete (commits {base[:7]}..{first[:7]}, review clean)\n")
    run("bash", str(installed / "x-develop/reconcile-tasks.sh"), "--projection", projection,
        "--ledger", str(ledger), "--tasks", str(tasks), cwd=fixture)
    first_snapshot = root / "stages/first-task/snapshot"
    shutil.copytree(fixture / "docs", first_snapshot / "docs")
    (first_snapshot / "progress.md").write_bytes(ledger.read_bytes())
    (first_snapshot / "head.txt").write_text(first + "\n")
    (fixture / "line_counter.py").write_text("from core import count_nonempty\n")
    run("git", "-C", str(fixture), "add", "line_counter.py")
    run("git", "-C", str(fixture), "commit", "-qm", "second task")
    head = run("git", "-C", str(fixture), "rev-parse", "HEAD")
    task_two_package = workspace / "review-task-2.diff"
    run("bash", str(installed / "subagent-driven-development/scripts/review-package"),
        projection, first, head, str(task_two_package), cwd=fixture)
    with ledger.open("a") as stream:
        stream.write(f"Task 2: complete (commits {first[:7]}..{head[:7]}, review clean)\n")
    run("bash", str(installed / "x-develop/reconcile-tasks.sh"), "--projection", projection,
        "--ledger", str(ledger), "--tasks", str(tasks), cwd=fixture)
    package = workspace / "review-full.diff"
    run("bash", str(installed / "subagent-driven-development/scripts/review-package"),
        projection, base, head, str(package), cwd=fixture)
    context = "/root/final_reviewer"
    (workspace / "final-reviewer-dispatch.identity").write_text(f"reviewer_context: {context}\n")
    final = "### Strengths\n\nComplete.\n\n### Issues\n\nNone.\n\n### Assessment\n\n**Ready to merge?** Yes\n"
    final_review = workspace / "maxi-final-review.md"
    final_review.write_text("---\n" + "\n".join((
        f"worktree: {fixture}", f"merge_base: {base}", f"reviewed_head: {head}",
        f"reviewed_tree: {run('git', '-C', str(fixture), 'rev-parse', 'HEAD^{tree}')}",
        f"projection: {projection}", f"projection_sha256: {sha(Path(projection))}",
        f"full_review_package: {package}", f"full_review_package_sha256: {sha(package)}",
        "fix_review_package: null", "fix_review_package_sha256: null",
        f"spec: {spec}", f"spec_sha256: {sha(spec)}", f"tasks: {tasks}",
        f"tasks_sha256: {sha(tasks)}", f"reviewer_context: {context}", "outcome: finish",
    )) + "\n---\n\n" + final)
    receipt = workspace / "terminal-receipt.md"
    run("bash", str(installed / "x-develop/record-terminal.sh"), "--worktree", str(fixture),
        "--merge-base", base, "--projection", projection, "--ledger", str(ledger),
        "--final-review", str(final_review), "--spec", str(spec), "--tasks", str(tasks),
        "--output", str(receipt), cwd=fixture)
    result_output = run("bash", str(installed / "x-develop/result-contract.sh"),
                        "--tasks", str(tasks), "--receipt", str(receipt), cwd=fixture)
    assert "READY_TO_FINISH" in result_output.splitlines()
    pre_done = root / "pre-done-fixture"
    shutil.copytree(fixture, pre_done)
    status_file(spec, "done")
    postturn_verifier = checker.run_boundary_verifier(
        fixture, pre_done, installed, tasks, receipt, SKILLS.parent)
    resume_snapshot = root / "stages/resume/snapshot"
    shutil.copytree(fixture / "docs", resume_snapshot / "docs")
    (resume_snapshot / "progress.md").write_bytes(ledger.read_bytes())
    (resume_snapshot / "receipt.md").write_bytes(receipt.read_bytes())
    design_spec = (design_snapshot / "docs/maxi/specs/0001-upgrade/spec.md").read_text()
    design_plan = (design_snapshot / "docs/maxi/specs/0001-upgrade/plan.md").read_text()
    resume_spec = (pre_done / "docs/maxi/specs/0001-upgrade/spec.md").read_text()
    resume_plan = (resume_snapshot / "docs/maxi/specs/0001-upgrade/plan.md").read_text()
    record_stage(root, installed, "design", ["plan", "review"], "ordinary-thread",
                 (design_context, design_spec, design_plan, "VERDICT: approved\n"),
                 reviewer_paths=((spec, design_spec), (plan, design_plan)))
    record_stage(root, installed, "tasks", ["tasks"], "ordinary-thread")
    record_stage(root, installed, "readiness", ["analyze"], "ordinary-thread")
    record_stage(root, installed, "first-task", ["implement", "x-develop"], "ordinary-thread")
    record_stage(root, installed, "resume", ["implement", "x-develop", "using-maxi",
                                              "finishing-a-development-branch"], "ordinary-thread",
                 (context, resume_spec, resume_plan, final),
                 (["bash", str(installed / "x-develop/result-contract.sh"), "--tasks", str(tasks),
                   "--receipt", str(receipt)], result_output + "\n"),
                 reviewer_paths=((spec, resume_spec), (plan, resume_plan)))
    add_task_execution(root, "first-task", fixture, workspace, 1, first)
    add_task_execution(root, "resume", fixture, workspace, 2, head)
    task_reviews = [
        add_task_review(root, "first-task", "/root/task_one_reviewer", task_one_package),
        add_task_review(root, "resume", "/root/task_two_reviewer", task_two_package),
    ]
    migration = make_migration(root, installed)
    (root / "evidence.json").write_text(json.dumps({
        "version": 1, "fixture": str(fixture), "installed": str(installed),
        "source_skills": str(SKILLS), "base": base, "first": first, "head": head,
        "projection": projection, "ledger": str(ledger), "receipt": str(receipt),
        "final_review": str(final_review), "tasks": str(tasks), "context": context,
        "design_context": design_context,
        "pre_done_fixture": str(pre_done), "postturn_verifier": postturn_verifier,
        "task_reviews": task_reviews,
        "migration": migration,
        "stages": [{"name": name, "exit_code": 0}
            for name in checker.STAGES]}))
    return {"fixture": fixture, "installed": installed, "base": base, "first": first,
            "head": head, "context": context, "final": final, "receipt": receipt,
            "spec": spec, "plan": plan, "tasks": tasks}


class UpgradeEvidenceTest(unittest.TestCase):
    def test_collect_task_review_binds_relative_package_and_native_verdict(self):
        with tempfile.TemporaryDirectory() as temp:
            fixture = Path(temp).resolve() / "fixture"
            workspace = fixture / ".superpowers/sdd/task-workspace"
            workspace.mkdir(parents=True)
            package = workspace / "review-abc1234..def5678.diff"
            package.write_bytes(b"# Review package\nexact diff bytes\n")
            report = ("### Spec Compliance\n\n- ✅ Spec compliant\n\n"
                      "### Assessment\n\n**Task quality: Approved.** Clear implementation.\n")
            child = {"agent": "/root/task_reviewer", "cwd": str(fixture), "events": [
                {"type": "event_msg", "payload": {"item": {
                    "type": "CommandExecution", "command": ["/bin/zsh", "-lc",
                        f"cat {package.relative_to(fixture)}"], "exit_code": 0,
                    "aggregated_output": package.read_text()}, "completed_at_ms": 1}},
                {"type": "event_msg", "payload": {"type": "task_complete",
                                                 "last_agent_message": report}},
            ]}
            sessions = [{"agent": "/root", "cwd": str(fixture), "events": []}, child]
            observed = checker.collect_task_review(
                sessions, "first-task", fixture, workspace, "abc1234", "def5678")
            self.assertEqual(observed["package"], str(package))
            self.assertEqual(observed["package_sha256"], sha(package))
            parked = json.loads(json.dumps(sessions))
            parked[1]["events"][1]["payload"]["last_agent_message"] = report.replace(
                "**Task quality: Approved.**", "**Task quality:** Needs fixes")
            self.assertEqual(checker.collect_task_review(
                parked, "first-task", fixture, workspace, "abc1234", "def5678")["context"],
                "/root/task_reviewer")
            for label, change in (
                ("wrong cwd", lambda c: c.update(cwd=str(fixture.parent))),
                ("wrong path", lambda c: c["events"][0]["payload"]["item"].update(
                    command=["/bin/zsh", "-lc", "cat ../outside/review-abc1234..def5678.diff"])),
                ("wrong output", lambda c: c["events"][0]["payload"]["item"].update(
                    aggregated_output="# Review package\nwrong bytes\n")),
                ("missing completion", lambda c: c["events"][0]["payload"].pop(
                    "completed_at_ms")),
                ("missing verdict", lambda c: c["events"][1]["payload"].update(
                    last_agent_message=report.replace("**Task quality: Approved.**", ""))),
            ):
                with self.subTest(label=label):
                    bad = json.loads(json.dumps(sessions))
                    change(bad[1])
                    with self.assertRaises(ValueError):
                        checker.collect_task_review(
                            bad, "first-task", fixture, workspace, "abc1234", "def5678")

    def assert_rejected(self, root, label):
        result = subprocess.run([sys.executable, str(CHECKER), str(root)],
                                capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0, f"{label}: {result.stdout}")

    def test_complete_recorded_shape_is_accepted(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            make_complete(root)
            result = subprocess.run([sys.executable, str(CHECKER), str(root)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_task_review_accepts_observed_markdown_approval_variant(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            make_complete(root)
            sessions = root / "stages/resume/sessions.json"
            sessions.write_text(sessions.read_text().replace(
                "**Task quality:** Approved", "**Task quality: Approved.**"))
            result = subprocess.run([sys.executable, str(CHECKER), str(root)],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_required_evidence_mutations_fail_closed(self):
        # One genuine helper/Git fixture; recorded events are checker inputs only.
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            values = make_complete(root)
            evidence = root / "evidence.json"
            original = evidence.read_bytes()
            data = json.loads(original)
            for label, change in (
                ("missing stage", lambda e: e["stages"].pop()),
                ("timeout", lambda e: e["stages"][3].update(exit_code=124)),
                ("bad endpoint", lambda e: e.update(head="0" * 40)),
                ("bad reviewer", lambda e: e.update(context="/root/invented")),
                ("bad boundary digest", lambda e: e["postturn_verifier"].update(
                    snapshot_sha256="0" * 64)),
                ("false helper output", lambda e: e["postturn_verifier"].update(
                    stdout="READY_TO_FINISH\n")),
            ):
                with self.subTest(label=label):
                    changed = json.loads(original)
                    change(changed)
                    evidence.write_text(json.dumps(changed))
                    self.assert_rejected(root, label)
            evidence.write_bytes(original)
            installed = values["installed"] / "x-develop/SKILL.md"
            old = installed.read_bytes()
            installed.write_bytes(old + b"changed\n")
            self.assert_rejected(root, "changed installed bytes")
            installed.write_bytes(old)
            first = root / "stages/first-task/snapshot/progress.md"
            old = first.read_bytes()
            first.write_bytes(old.replace(b"review clean", b"not reviewed"))
            self.assert_rejected(root, "missing task completion")
            first.write_bytes(old)
            last = root / "stages/resume/snapshot/progress.md"
            old = last.read_bytes()
            last.write_bytes(old + b"Task 1: selected\n")
            self.assert_rejected(root, "replayed completed task")
            last.write_bytes(old)
            first_sessions = root / "stages/first-task/sessions.json"
            resume_sessions = root / "stages/resume/sessions.json"
            first_events = json.loads(first_sessions.read_text())
            resume_original = resume_sessions.read_bytes()
            resumed = json.loads(resume_original)
            resumed.append(next(item for item in first_events
                                if item["agent"] == "/root/task1_implementer"))
            resume_sessions.write_text(json.dumps(resumed))
            self.assert_rejected(root, "Task 1 execution actor replayed")
            resume_sessions.write_bytes(resume_original)
            resumed = json.loads(resume_original)
            task_two = next(item for item in resumed if item["agent"] == "/root/task2_implementer")
            task_two["events"][-1]["payload"]["item"]["aggregated_output"] = "unrelated commit\n"
            resume_sessions.write_text(json.dumps(resumed))
            self.assert_rejected(root, "Task 2 actor did not prove commit endpoint")
            resume_sessions.write_bytes(resume_original)
            sessions = root / "stages/resume/sessions.json"
            old = sessions.read_bytes()
            events = json.loads(old)
            child = next(item for item in events if item["agent"] == values["context"])
            child["events"] = [event for event in child["events"] if
                               event.get("payload", {}).get("item", {}).get("type") != "CommandExecution"]
            sessions.write_text(json.dumps(events))
            self.assert_rejected(root, "reviewer did not read full context")
            sessions.write_bytes(old)
            cli = root / "stages/resume/cli.jsonl"
            old = cli.read_bytes()
            sessions = root / "stages/resume/sessions.json"
            old_sessions = sessions.read_bytes()
            events = json.loads(old_sessions)
            root_session = next(item for item in events if item["agent"] == "/root")
            for event in root_session["events"]:
                item = event.get("payload", {}).get("item", {})
                if item.get("type") == "CommandExecution" and "READY_TO_FINISH" in item.get("aggregated_output", ""):
                    item["aggregated_output"] = "FAKE_TO_FINISH\n"
            sessions.write_text(json.dumps(events))
            self.assert_rejected(root, "missing native helper output")
            sessions.write_bytes(old_sessions)
            cli.write_bytes(old)
            boundary = root / "pre-done-fixture/line_counter.py"
            old = boundary.read_bytes()
            boundary.write_bytes(b"tampered\n")
            self.assert_rejected(root, "changed saved Git fixture")
            boundary.write_bytes(old)
            migration = json.loads(original)["migration"]
            old_projection = Path(migration["old_projection"])
            old_bytes = old_projection.read_bytes()
            old_projection.write_bytes(old_bytes.replace(b"maxi-v1", b"maxi-v0", 1))
            self.assert_rejected(root, "changed historical predecessor")
            old_projection.write_bytes(old_bytes)
            changed = json.loads(original)
            changed["migration"]["base"] = changed["migration"]["head"]
            evidence.write_text(json.dumps(changed))
            self.assert_rejected(root, "zero original migration range")
            evidence.write_bytes(original)
            migration_sessions = root / "stages/migration/sessions.json"
            old = migration_sessions.read_bytes()
            events = json.loads(old)
            events[:] = [item for item in events if item["agent"] != migration["context"]]
            migration_sessions.write_text(json.dumps(events))
            self.assert_rejected(root, "missing fresh migration reviewer")
            migration_sessions.write_bytes(old)

    def test_boundary_verifier_failure_restores_final_fixture(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            fixture = root / "fixture"
            boundary = root / "pre-done-fixture"
            fixture.mkdir()
            boundary.mkdir()
            (fixture / "status.txt").write_text("done\n")
            (boundary / "status.txt").write_text("implementing\n")
            before = checker.tree_digest(fixture)
            result = checker.run_boundary_verifier(
                fixture, boundary, root / "missing-skills", fixture / "tasks.md",
                fixture / "receipt.md", SKILLS.parent)
            self.assertNotEqual(result["exit_code"], 0)
            self.assertEqual(checker.tree_digest(fixture), before)
            self.assertEqual((fixture / "status.txt").read_text(), "done\n")
            self.assertFalse((root / "fixture.final-held").exists())

    def test_stage_sequence_is_complete_and_ordered(self):
        stages = [{"name": name, "exit_code": 0} for name in checker.STAGES]
        checker.stage_sequence(stages)
        for changed in (stages[:-1], stages[1:], stages[::-1],
                        stages + [{"name": "unknown", "exit_code": 0}],
                        stages[:-1] + [{"name": stages[-1]["name"], "exit_code": 124}]):
            with self.subTest(changed=changed), self.assertRaises(ValueError):
                checker.stage_sequence(changed)

    def test_design_proof_uses_stage_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            spec_dir = root / "docs/maxi/specs/0001-upgrade"
            review_dir = spec_dir / "reviews"
            review_dir.mkdir(parents=True)
            (root / "docs/maxi/constitution.md").write_text("# Constitution\n")
            spec = spec_dir / "spec.md"
            plan = spec_dir / "plan.md"
            report = review_dir / "design-review.md"
            candidate = review_dir / "candidate.md"
            spec.write_text("# Spec\n")
            plan.write_text("# Plan\n")
            candidate.write_text("# Review\nVERDICT: approved\n")
            inputs = subprocess.check_output(["bash", str(SKILLS / "review/review-inputs.sh"),
                                              "hash", str(root)], text=True).strip()
            subprocess.run(["bash", str(SKILLS / "review/design-contract.sh"), "stamp",
                            str(candidate), str(report), str(spec), str(plan), "approved",
                            str(root), inputs], check=True)
            checker.verified_design(root, SKILLS)
            spec.write_text("# Changed spec\n")
            with self.assertRaises(ValueError):
                checker.verified_design(root, SKILLS)

    def test_readiness_proof_uses_stage_bytes(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve()
            spec_dir = root / "docs/maxi/specs/0001-upgrade"
            spec_dir.mkdir(parents=True)
            (root / "docs/maxi/constitution.md").write_text("# Constitution\n")
            spec = spec_dir / "spec.md"
            plan = spec_dir / "plan.md"
            tasks = spec_dir / "tasks.md"
            analysis = spec_dir / "analysis.md"
            candidate = spec_dir / "candidate.md"
            spec.write_text("---\nslug: 0001-upgrade\nstatus: tasked\nupdated: 2026-09-27\n---\n# Spec\n")
            plan.write_text("# Plan\n")
            tasks.write_text("---\nspec_slug: 0001-upgrade\nupdated: 2026-09-27\n---\n"
                             "- [ ] T001 First task (plan Task 1)\n")
            candidate.write_text("# Readiness\nPass.\n")
            inputs = subprocess.check_output(["bash", str(SKILLS / "review/review-inputs.sh"),
                                              "hash", str(root)], text=True).strip()
            subprocess.run(["bash", str(SKILLS / "analyze/readiness-contract.sh"), "stamp",
                            str(candidate), str(analysis), str(spec), str(plan), str(tasks),
                            "pass", "0", str(root), inputs], check=True)
            checker.verified_readiness(root, SKILLS)
            plan.write_text("# Changed plan\n")
            with self.assertRaises(ValueError):
                checker.verified_readiness(root, SKILLS)

    def test_unknown_stage_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            evidence = Path(temp) / "evidence.json"
            evidence.write_text(json.dumps({"version": 1, "stages": [{"name": "invented"}]}))
            result = subprocess.run([sys.executable, str(CHECKER), temp],
                                    capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("unknown stage", result.stderr)

    def test_cli_requires_one_completed_turn(self):
        with tempfile.TemporaryDirectory() as temp:
            log = Path(temp) / "turn.jsonl"
            for events in ([{"type": "thread.started", "thread_id": "task"}],
                           [{"type": "turn.completed"}, {"type": "turn.completed"}],
                           [{"type": "turn.completed"}, {"type": "surprise"}]):
                log.write_text("".join(json.dumps(event) + "\n" for event in events))
                with self.subTest(events=events), self.assertRaises(ValueError):
                    checker.cli_commands(log)

    def test_installed_read_requires_exact_completed_output(self):
        with tempfile.TemporaryDirectory() as temp:
            skill = Path(temp) / "skills" / "plan" / "SKILL.md"
            skill.parent.mkdir(parents=True)
            skill.write_text("exact installed bytes\n")
            command = {"type": "CommandExecution", "exit_code": 0,
                       "command": ["/bin/zsh", "-lc", f"cat {skill}"],
                       "aggregated_output": skill.read_text()}
            session = {"agent": "/root", "events": [{"type": "event_msg", "payload": {
                "item": command, "completed_at_ms": 1}}]}
            installed = {str(skill): skill.read_text()}
            checker.installed_read([session], installed, "plan")
            for changed in ({"aggregated_output": "truncated"}, {"exit_code": 1},
                            {"command": ["/bin/zsh", "-lc", "echo exact installed bytes"]}):
                with self.subTest(changed=changed), self.assertRaises(ValueError):
                    session["events"][0]["payload"]["item"] = command | changed
                    checker.installed_read([session], installed, "plan")

    def test_installed_read_reuses_brace_and_python_rules(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp).resolve() / "skills"
            plan = base / "plan/SKILL.md"
            clarify = base / "clarify/SKILL.md"
            plan.parent.mkdir(parents=True)
            clarify.parent.mkdir(parents=True)
            plan.write_text("PLAN\n")
            clarify.write_text("CLARIFY\n")
            installed = {str(plan): plan.read_text(), str(clarify): clarify.read_text()}
            item = {"type": "CommandExecution", "exit_code": 0,
                    "command": ["/bin/zsh", "-lc", f"cat {base}/{{plan,clarify}}/SKILL.md"],
                    "aggregated_output": "PLAN\nCLARIFY\n"}
            session = {"agent": "/root", "events": [{"type": "event_msg", "payload": {
                "item": item, "completed_at_ms": 1}}]}
            checker.installed_read([session], installed, "plan")
            item["command"][2] = ("python3 - <<'PY'\nfrom pathlib import Path\n"
                                  f"base=Path('{base}')\nfor rel in ['plan/SKILL.md','clarify/SKILL.md']:\n"
                                  " p=base/rel\n print(p.read_text())\nPY")
            item["aggregated_output"] = "PLAN\n\nCLARIFY\n\n"
            checker.installed_read([session], installed, "plan")
            item["aggregated_output"] = "PLA\nCLARIFY\n"
            with self.assertRaises(ValueError):
                checker.installed_read([session], installed, "plan")

    def test_review_dispatch_binds_spawn_to_followup(self):
        root_events = [
            {"type": "response_item", "payload": {"type": "function_call", "name": "spawn_agent",
                "call_id": "a", "arguments": json.dumps({"task_name": "reviewer", "message": "Identity only"})}},
            {"type": "response_item", "payload": {"type": "function_call_output",
                "call_id": "a", "output": json.dumps({"task_name": "/root/reviewer"})}},
            {"type": "response_item", "payload": {"type": "function_call", "name": "followup_task",
                "call_id": "b", "arguments": json.dumps({"target": "/root/reviewer", "message": "Review full spec and full plan"})}},
            {"type": "response_item", "payload": {"type": "function_call_output",
                "call_id": "b", "output": ""}},
        ]
        final = "### Assessment\n\n**Ready to merge?** Yes"
        child_events = [
            {"type": "event_msg", "payload": {"type": "item_completed", "turn_id": "identity-turn",
                "completed_at_ms": 1, "item": {"type": "AgentMessage", "phase": "final_answer",
                    "content": [{"type": "Text", "text": "Identity ready"}]}}},
            {"type": "event_msg", "payload": {"type": "task_complete", "turn_id": "identity-turn",
                "last_agent_message": "Identity ready"}},
            {"type": "event_msg", "payload": {"type": "item_completed", "turn_id": "review-turn",
                "completed_at_ms": 2, "item": {"type": "AgentMessage", "phase": "final_answer",
                    "content": [{"type": "Text", "text": final}]}}},
            {"type": "event_msg", "payload": {"type": "task_complete", "turn_id": "review-turn",
                "last_agent_message": final}},
        ]
        sessions = [{"agent": "/root", "events": root_events},
                    {"agent": "/root/reviewer", "events": child_events}]
        for index, event in enumerate(root_events):
            event["timestamp"] = f"2026-09-27T11:00:0{index}.000Z"
        for index, event in enumerate(child_events):
            event["timestamp"] = (f"2026-09-27T10:59:5{index}.000Z" if index < 2 else
                                  f"2026-09-27T11:00:0{index + 2}.000Z")
        checker.review_dispatch(sessions, "/root/reviewer", "full spec", "full plan", final)
        root_events[2]["payload"]["arguments"] = json.dumps({"target": "/root/other", "message": "Review full spec and full plan"})
        with self.assertRaises(ValueError):
            checker.review_dispatch(sessions, "/root/reviewer", "full spec", "full plan", final)
        root_events[2]["payload"]["arguments"] = json.dumps({"target": "/root/reviewer", "message": "Review full spec and full plan"})
        root_events[0], root_events[2] = root_events[2], root_events[0]
        with self.assertRaises(ValueError):
            checker.review_dispatch(sessions, "/root/reviewer", "full spec", "full plan", final)
        root_events[0], root_events[2] = root_events[2], root_events[0]
        sessions.pop()
        with self.assertRaises(ValueError):
            checker.review_dispatch(sessions, "/root/reviewer", "full spec", "full plan", final)

    def test_review_dispatch_accepts_native_single_turn_relative_followup(self):
        final = "Critical: None.\n\nImportant: None.\n\nVERDICT: approved"
        root_events = [
            {"type": "response_item", "timestamp": "2026-09-27T11:00:00.000Z",
             "payload": {"type": "function_call", "name": "spawn_agent", "call_id": "a",
                         "arguments": json.dumps({"task_name": "design_reviewer", "message": "Identity only"})}},
            {"type": "response_item", "timestamp": "2026-09-27T11:00:01.000Z",
             "payload": {"type": "function_call_output", "call_id": "a",
                         "output": json.dumps({"task_name": "/root/design_reviewer"})}},
            {"type": "response_item", "timestamp": "2026-09-27T11:00:02.000Z",
             "payload": {"type": "function_call", "name": "followup_task", "call_id": "b",
                         "arguments": json.dumps({"target": "design_reviewer", "message": "Review full spec and full plan"})}},
            {"type": "response_item", "timestamp": "2026-09-27T11:00:03.000Z",
             "payload": {"type": "function_call_output", "call_id": "b", "output": ""}},
        ]
        child_events = [
            {"type": "event_msg", "timestamp": "2026-09-27T11:00:04.000Z",
             "payload": {"type": "item_completed", "turn_id": "one-turn", "completed_at_ms": 4,
                         "item": {"type": "AgentMessage", "phase": "final_answer",
                                  "content": [{"type": "Text", "text": final}]}}},
            {"type": "event_msg", "timestamp": "2026-09-27T11:00:05.000Z",
             "payload": {"type": "task_complete", "turn_id": "one-turn",
                         "last_agent_message": final}},
        ]
        sessions = [{"agent": "/root", "events": root_events},
                    {"agent": "/root/design_reviewer", "events": child_events}]
        self.assertEqual(checker.reviewer_terminal(sessions, "/root/design_reviewer"), final)
        self.assertEqual(checker.review_dispatch(sessions, "/root/design_reviewer",
                                                 "full spec", "full plan", final), [final])
        child_events[-1]["timestamp"] = "2026-09-27T10:59:59.000Z"
        with self.assertRaises(ValueError):
            checker.review_dispatch(sessions, "/root/design_reviewer",
                                    "full spec", "full plan", final)
        child_events[-1]["timestamp"] = "2026-09-27T11:00:05.000Z"
        del root_events[2]["timestamp"]
        with self.assertRaises(ValueError):
            checker.review_dispatch(sessions, "/root/design_reviewer",
                                    "full spec", "full plan", final)
        root_events[2]["timestamp"] = "2026-09-27T11:00:02.000Z"
        nested = "/root/a/design_reviewer"
        root_events[1]["payload"]["output"] = json.dumps({"task_name": nested})
        sessions[1]["agent"] = nested
        with self.assertRaises(ValueError):
            checker.review_dispatch(sessions, nested, "full spec", "full plan", final)
        root_events[2]["payload"]["arguments"] = json.dumps(
            {"target": "a/design_reviewer", "message": "Review full spec and full plan"})
        self.assertEqual(checker.review_dispatch(sessions, nested, "full spec", "full plan", final),
                         [final])

    def test_terminal_proof_accepts_native_pwd_bound_paths(self):
        with tempfile.TemporaryDirectory() as temp:
            fixture = Path(temp).resolve()
            tasks = fixture / "docs/maxi/specs/0001-upgrade/tasks.md"
            receipt = fixture / ".superpowers/sdd/example/terminal-receipt.md"
            helper = SKILLS / "x-develop/result-contract.sh"
            command = ["/bin/zsh", "-lc", f'bash {helper} '
                       '--tasks "$PWD/docs/maxi/specs/0001-upgrade/tasks.md" '
                       '--receipt "$PWD/.superpowers/sdd/example/terminal-receipt.md"']
            event = {"type": "event_msg", "payload": {"completed_at_ms": 1, "item": {
                "type": "CommandExecution", "command": command, "exit_code": 0,
                "aggregated_output": "LINEAGE: example\nREADY_TO_FINISH\n"}}}
            sessions = [{"agent": "/root", "cwd": str(fixture), "events": [event]}]
            self.assertEqual(checker.terminal_proof(sessions, SKILLS, tasks, receipt, fixture), 0)
            sessions[0]["cwd"] = str(fixture.parent)
            with self.assertRaises(ValueError):
                checker.terminal_proof(sessions, SKILLS, tasks, receipt, fixture)
            sessions[0]["cwd"] = str(fixture)
            event["payload"]["item"]["command"][-1] += " ; echo unrelated"
            with self.assertRaises(ValueError):
                checker.terminal_proof(sessions, SKILLS, tasks, receipt, fixture)


if __name__ == "__main__":
    unittest.main()
