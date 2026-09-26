#!/usr/bin/env python3
"""Small regressions for the Git closure evidence oracle."""
import json
import hashlib
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest


CHECKER = pathlib.Path(__file__).resolve().parent / "check-evidence.py"


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


class CheckerTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="maxi-closure-check-")
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name).resolve()
        self.repo = self.root / "fixture"
        self.repo.mkdir()
        subprocess.run(["git", "init", "-q", "-b", "main", str(self.repo)], check=True)
        git(self.repo, "config", "user.name", "Integration")
        git(self.repo, "config", "user.email", "integration@example.invalid")
        (self.repo / "policy.txt").write_text("original policy\n")
        (self.repo / "evidence.txt").write_text("original evidence\n")
        (self.repo / "app.txt").write_text("base\n")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-qm", "base")
        self.target = git(self.repo, "rev-parse", "refs/heads/main")
        git(self.repo, "switch", "-qc", "batch")
        (self.repo / "app.txt").write_text("batch\n")
        git(self.repo, "add", "app.txt")
        git(self.repo, "commit", "-qm", "batch")
        self.tip = git(self.repo, "rev-parse", "HEAD")
        self.installed = self.root / "installed" / "skills" / "using-maxi" / "SKILL.md"
        self.installed.parent.mkdir(parents=True)
        self.installed.write_text("name: using-maxi\nclosure skill\n")
        self.log = self.root / "cli.jsonl"
        self.good_events = [
            {"type": "thread.started", "thread_id": "thread"},
            {"type": "turn.started"},
            {"type": "item.completed", "item": {"type": "command_execution", "status": "completed", "exit_code": 0,
              "command": f"cat {self.installed}", "aggregated_output": self.installed.read_text()}},
            {"type": "item.completed", "item": {"type": "agent_message", "text": "The local batch is ready. Please decide whether to merge it into main."}},
            {"type": "turn.completed"},
        ]
        self.evidence = {
            "case": {"name": "positive", "kind": "decision", "required_skills": ["using-maxi"],
                     "protected": ["policy.txt", "evidence.txt"], "final_patterns": ["merge"]},
            "fixture": str(self.repo), "cli": str(self.log), "exit_code": 0,
            "target_before": self.target, "batch_tip": self.tip, "status_before": "",
            "protected_before": {p: hashlib.sha256((self.repo / p).read_bytes()).hexdigest()
                                 for p in ["policy.txt", "evidence.txt"]},
            "installed": {"using-maxi": str(self.installed)},
        }
        self.write()

    def write(self):
        self.log.write_text("".join(json.dumps(e) + "\n" for e in self.good_events))
        (self.root / "evidence.json").write_text(json.dumps(self.evidence))

    def check(self, want_success):
        self.write()
        result = subprocess.run([sys.executable, str(CHECKER), str(self.root / "evidence.json")],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode == 0, want_success, result.stdout + result.stderr)

    def test_positive_control(self):
        self.check(True)

    def test_claimed_merge_without_ref_change(self):
        self.evidence["case"]["kind"] = "integrated"
        self.good_events[-2]["item"]["text"] = "Merged the batch into main successfully."
        self.check(False)

    def test_protected_file_change(self):
        (self.repo / "policy.txt").write_text("changed\n")
        self.check(False)

    def test_timeout(self):
        self.evidence["exit_code"] = 124
        self.check(False)

    def test_missing_installed_read(self):
        self.good_events.pop(2)
        self.check(False)

    def test_unknown_event_shape(self):
        self.good_events[2]["type"] = "item.forgotten"
        self.check(False)


if __name__ == "__main__":
    unittest.main()
