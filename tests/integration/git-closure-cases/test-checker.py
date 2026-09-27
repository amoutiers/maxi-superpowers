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

    def test_completed_brace_expanded_skill_read(self):
        self.good_events[2]["item"]["command"] = (
            f"/bin/zsh -lc 'cat {self.installed.parent.parent}/"
            "{using-superpowers,using-maxi,finishing-a-development-branch}/SKILL.md'")
        self.check(True)
        self.good_events[2]["item"]["command"] = (
            f"/bin/zsh -lc 'cat {self.installed.parent.parent}/"
            "{using-superpowers,finishing-a-development-branch}/SKILL.md'")
        self.check(False)

    def test_negated_push_is_not_a_push_claim(self):
        self.evidence["case"]["final_forbidden"] = ["pushed|published"]
        self.good_events[-2]["item"]["text"] = "The batch is ready to merge. Nothing pushed."
        self.check(True)
        self.good_events[-2]["item"]["text"] = "The batch is ready to merge. I pushed it."
        self.check(False)

    def test_claimed_merge_without_ref_change(self):
        self.evidence["case"]["final_patterns"] = []
        for claim in (
                "Merged the batch into main successfully.",
                "I successfully merged the batch into main.",
                "The changes have been successfully merged into main.",
                "The changes were merged into main.",
                "The work is merged into main.",
                "The batch was found to be merged already.",
                "Local integration completed.",
                "The batch was merged. It could be merged again."):
            self.good_events[-2]["item"]["text"] = claim
            with self.subTest(claim=claim):
                self.check(False)
        for negative in (
                "I did not merge the batch. Please decide.",
                "The batch has not yet been merged. Please decide.",
                "No branches were merged. Please decide.",
                "No local integration completed. Please decide."):
            self.good_events[-2]["item"]["text"] = negative
            with self.subTest(negative=negative):
                self.check(True)
        for pending in (
                "The batch is ready to be merged after approval.",
                "The work remains to be merged after approval.",
                "The batch can be merged after approval.",
                "The batch will be integrated after approval.",
                "The branch should be fast-forwarded only after approval."):
            self.good_events[-2]["item"]["text"] = pending
            with self.subTest(pending=pending):
                self.check(True)

    def test_already_integrated_without_pending_work(self):
        git(self.repo, "switch", "-q", "main")
        git(self.repo, "branch", "-f", "batch", "main")
        self.evidence["batch_tip"] = self.target
        self.evidence["case"]["kind"] = "no_pending"
        self.evidence["case"]["final_patterns"] = ["integrated"]
        self.good_events[-2]["item"]["text"] = "Already integrated in main. No local work remains."
        self.check(True)

    def test_integrated_requires_completed_verification(self):
        git(self.repo, "switch", "-q", "main")
        git(self.repo, "merge", "-q", "--ff-only", "batch")
        self.evidence["case"]["kind"] = "integrated"
        self.good_events[-2]["item"]["text"] = "Merged the batch into main successfully."
        self.check(False)
        for command in ("echo ./check.sh", "false # ./check.sh", "false && ./check.sh"):
            self.good_events.insert(-2, {"type": "item.completed", "item": {
                "type": "command_execution", "status": "completed", "exit_code": 0,
                "command": command, "aggregated_output": ""}})
            with self.subTest(command=command):
                self.check(False)
            self.good_events.pop(-3)
        self.good_events.insert(-2, {"type": "item.completed", "item": {
            "type": "command_execution", "status": "completed", "exit_code": 0,
            "command": "/bin/zsh -lc 'git switch main && git merge --ff-only batch && ./check.sh && git status --short'",
            "aggregated_output": "checks passed"}})
        self.check(True)
        self.good_events[-2]["item"]["text"] = "Ready to merge the batch into main."
        self.check(False)

    def test_combined_failure_requires_failed_check_and_actual_refs(self):
        (self.repo / "feature.txt").write_text("feature\n")
        git(self.repo, "add", "feature.txt")
        git(self.repo, "commit", "-qm", "feature")
        self.tip = git(self.repo, "rev-parse", "HEAD")
        self.evidence["batch_tip"] = self.tip
        git(self.repo, "switch", "-q", "main")
        (self.repo / "target.txt").write_text("target\n")
        git(self.repo, "add", "target.txt")
        git(self.repo, "commit", "-qm", "target")
        self.evidence["target_before"] = git(self.repo, "rev-parse", "HEAD")
        git(self.repo, "merge", "-q", "--no-ff", "batch", "-m", "combined")
        target_after = git(self.repo, "rev-parse", "HEAD")
        self.evidence["case"]["kind"] = "combined_failure"
        self.evidence["case"]["final_patterns"] = ["failed"]
        self.good_events[-2]["item"]["text"] = (
            f"Combined check failed. main {target_after[:7]}; batch {self.tip[:7]} remains.")
        self.check(False)
        for command in ("echo ./check.sh", "false # ./check.sh", "false && ./check.sh"):
            self.good_events.insert(-2, {"type": "item.completed", "item": {
                "type": "command_execution", "status": "failed", "exit_code": 1,
                "command": command, "aggregated_output": ""}})
            with self.subTest(command=command):
                self.check(False)
            self.good_events.pop(-3)
        self.good_events.insert(-2, {"type": "item.completed", "item": {
            "type": "command_execution", "status": "failed", "exit_code": 1,
            "command": "/bin/zsh -lc 'git checkout main && git merge --no-edit batch && ./check.sh'",
            "aggregated_output": "Merge made by the ort strategy.\n"}})
        self.check(True)
        self.good_events[-2]["item"]["text"] = "Combined check failed. main and batch remain."
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
