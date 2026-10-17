#!/usr/bin/env python3
"""Exercise durable receipts/Git capture with disposable real Git fixtures."""
from pathlib import Path
import importlib.util
import json
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
CAPTURE = HERE / 'retain-evidence.py'
sys.dont_write_bytecode = True

loader = importlib.util.spec_from_file_location('upgrade_test_fixture', HERE / 'test-checker.py')
fixtures = importlib.util.module_from_spec(loader)
loader.loader.exec_module(fixtures)


class Retention(unittest.TestCase):
    def prepare(self, base):
        root = base / 'qualification'
        root.mkdir()
        fixtures.make_complete(root)
        data = json.loads((root / 'evidence.json').read_text())
        (root / 'source-head.txt').write_text(fixtures.run('git', '-C', str(fixtures.SKILLS.parent), 'rev-parse', 'HEAD') + '\n')
        (root / 'installed-plugin.json').write_text('{"name":"maxi","version":"unit-fixture"}\n')
        # Complete the recorded-shape unit fixture with each reviewer's real package read.
        for entry, stage in ((data, 'resume'), (data['migration'], 'migration')):
            report = Path(entry['final_review']).read_text()
            package = next(line.split(': ', 1)[1] for line in report.splitlines()
                           if line.startswith('full_review_package: '))
            sessions_path = root / 'stages' / stage / 'sessions.json'
            sessions = json.loads(sessions_path.read_text())
            child = next(c for c in sessions if c['agent'] == entry['context'])
            child['events'].insert(2, {'type': 'event_msg', 'payload': {'type': 'item_completed',
                'completed_at_ms': 2, 'item': {'type': 'CommandExecution', 'status': 'completed',
                    'command': ['/bin/zsh', '-lc', 'cat ' + package], 'exit_code': 0,
                    'aggregated_output': Path(package).read_text()}}})
            sessions_path.write_text(json.dumps(sessions))
        # Runtime-home material must never be part of proof capture.
        (root / 'auth.json').write_text('PRIVATE AUTH SENTINEL')
        (root / 'config.toml').write_text('PRIVATE CONFIG SENTINEL')
        return root, data

    def capture(self, root):
        result = subprocess.run([sys.executable, str(CAPTURE), 'capture', str(root)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        loader = importlib.util.spec_from_file_location('retention', CAPTURE)
        module = importlib.util.module_from_spec(loader)
        loader.loader.exec_module(module)
        return module

    def test_archived_receipts_packages_and_git_verify_after_external_roots_disappear(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp).resolve()
            root, data = self.prepare(base)
            module = self.capture(root)
            expected = [Path(data['receipt']).read_bytes(), Path(data['migration']['receipt']).read_bytes()]
            for name in ('fixture', 'pre-done-fixture', 'migration-fixture', 'migration-pre-done-fixture'):
                shutil.rmtree(root / name)
            result = module.verify(root)
            self.assertEqual(len(result['receipts']), 2)
            self.assertEqual(result['packages_verified'], 4)
            for role, content in zip(('main-terminal', 'migration'), expected):
                restored = module.restore(root, role, root)
                entry = data if role == 'main-terminal' else data['migration']
                receipt = Path(entry['receipt'])
                self.assertEqual(receipt.read_bytes(), content)
                check = subprocess.run(['bash', str(root / 'installed-skills/x-develop/result-contract.sh'),
                                        '--tasks', entry['tasks'], '--receipt', str(receipt)],
                                       cwd=restored, capture_output=True, text=True)
                self.assertEqual(check.returncode, 0, check.stderr)
                self.assertIn('READY_TO_FINISH', check.stdout.splitlines())
            for file in (root / 'retained-proof').rglob('*'):
                if file.is_file():
                    self.assertNotIn(b'PRIVATE AUTH SENTINEL', file.read_bytes())
                    self.assertNotIn(b'PRIVATE CONFIG SENTINEL', file.read_bytes())

    def test_missing_or_changed_dependency_fails_closed_and_restore_never_overwrites(self):
        with tempfile.TemporaryDirectory() as temp:
            root, data = self.prepare(Path(temp).resolve())
            module = self.capture(root)
            with self.assertRaises(ValueError): module.restore(root, 'main-terminal', root)
            with self.assertRaises(ValueError): module.restore(root, 'main-terminal', root.parent)
            manifest = json.loads((root / 'retained-proof/manifest.json').read_text())
            for name in ('main-terminal/history.bundle',
                         next(k for k in manifest['files'] if k.endswith('terminal-receipt.md'))):
                path = root / 'retained-proof' / name
                original = path.read_bytes()
                path.write_bytes(original + b'tampered')
                with self.assertRaises(ValueError): module.verify(root)
                path.write_bytes(original)
            with self.assertRaises(ValueError): module.capture(root)
            shutil.rmtree(root / 'fixture')
            (root / 'fixture').symlink_to(root.parent, target_is_directory=True)
            with self.assertRaises(ValueError): module.restore(root, 'main-terminal', root)

    def test_capture_rejects_symlinked_project_proof(self):
        with tempfile.TemporaryDirectory() as temp:
            root, data = self.prepare(Path(temp).resolve())
            receipt = Path(data['receipt'])
            saved = receipt.with_name('outside-receipt')
            receipt.rename(saved)
            receipt.symlink_to(saved)
            result = subprocess.run([sys.executable, str(CAPTURE), 'capture', str(root)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('symlink', result.stderr)


if __name__ == '__main__':
    unittest.main()
