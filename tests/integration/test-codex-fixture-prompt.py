from pathlib import Path
import subprocess
import json
import shutil
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
RENDERER = HERE / 'render-codex-fixture-prompt.py'
SOURCE = HERE.parents[1]


class RendererTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.installed = self.root / 'installed skills'
        self.installed.mkdir()
        target = self.installed / 'using-maxi/SKILL.md'
        target.parent.mkdir()
        target.write_text('Exact installed example\n')

    def render(self, original, installed=None):
        input_path, output = self.root / 'original.txt', self.root / 'rendered.txt'
        input_path.write_bytes(original)
        result = subprocess.run([sys.executable, str(RENDERER), str(installed or self.installed),
                                 str(input_path), str(output)], capture_output=True)
        self.assertEqual(input_path.read_bytes(), original)
        return result, output

    def test_original_prefix_is_byte_exact_for_all_lf_endings(self):
        for original in (b'Original prompt', b'Original prompt\n', b'Original prompt\n\n',
                         'Précis UTF-8: $HOME `literal`\r\n'.encode(), b''):
            with self.subTest(original=original):
                result, output = self.render(original)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(output.read_bytes().startswith(original + b'\n\n'))
                self.assertFalse(output.read_bytes().endswith(b'\n'))

    def test_shell_substitution_transmits_exact_rendered_bytes(self):
        for original in (b'No LF', b'One LF\n', b'Many LF\n\n\n'):
            result, output = self.render(original)
            self.assertEqual(result.returncode, 0, result.stderr)
            transmitted = subprocess.check_output(['bash', '-c',
                'prompt="$(cat "$1")"; printf "%s" "$prompt"', 'fixture', str(output)])
            self.assertEqual(transmitted, output.read_bytes())

    def test_literal_example_executes_exact_installed_target(self):
        special = self.root / "installed space ' $HOME `literal`"
        self.installed.rename(special)
        result, output = self.render(b'Original', special)
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = output.read_text().splitlines()
        example = next(line for line in lines if line.startswith('cat '))
        actual = subprocess.run(['bash', '-c', example], capture_output=True)
        self.assertEqual(actual.returncode, 0, actual.stderr)
        self.assertEqual(actual.stdout, b'Exact installed example\n')
        self.assertIn(str(special), output.read_text())

    def test_contract_covers_delegates_individual_reads_and_tool_batches(self):
        result, output = self.render(b'Keep original requirements')
        self.assertEqual(result.returncode, 0, result.stderr)
        text = output.read_text()
        for fragment in ('one standalone native shell command per file', 'literal absolute pathname',
                         'complete file output', 'exit code 0', 'separate commands',
                         'batch of tool calls', 'each cat has its own complete successful result',
                         'Pass this same read-evidence instruction to every delegate',
                         'builder prompt', 'canonical spec', 'canonical plan', 'review packages',
                         'owner-bound installed resolver', 'Read the path returned by that resolver',
                         'does not replace skill resolution', 'no fallback',
                         'does not authorize changing snapshots'):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, text)
        self.assertNotIn('source checkout', text)

    def test_noncanonical_or_unavailable_roots_fail_without_fallback(self):
        link = self.root / 'alias'
        link.symlink_to(self.installed, target_is_directory=True)
        invalid = (str(link), str(self.installed) + '/.', str(self.installed) + '/../installed skills',
                   str(self.root / 'missing'), 'relative/skills')
        for installed in invalid:
            with self.subTest(installed=installed):
                output = self.root / 'rendered.txt'
                output.unlink(missing_ok=True)
                result, output = self.render(b'Original', installed)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(output.exists())

    def test_actual_design_and_upgrade_preparation_preserves_sent_bytes(self):
        source_root = self.root / 'source with spaces'
        target = source_root / 'tests/integration/render-codex-fixture-prompt.py'
        target.parent.mkdir(parents=True)
        shutil.copyfile(RENDERER, target)
        for kind, marker, length in (('design', "  jq -r '.prompt'", 2),
                                     ('upgrade', "  printf '%s'", 3)):
            source = (SOURCE / f'tests/integration/run-codex-{kind}-test.sh').read_text()
            lines = source.splitlines()
            start = next(i for i, line in enumerate(lines) if line.startswith(marker))
            block = '\n'.join(lines[start:start + length])
            self.assertIn('render-codex-fixture-prompt.py', block)
            self.assertLess(source.index('diff -rq "$ROOT/skills" "$INSTALLED"'),
                            source.index('render-codex-fixture-prompt.py'))
            if kind == 'design':
                self.assertIn('--cd "$FIXTURE" "$(cat "$DIR/prompt.txt")"', source)
            else:
                self.assertIn('--cd "$repo" "$prompt")', source)
                self.assertIn('"$THREAD" "$prompt")', source)
            for prompt in ('UTF-8 précision $HOME', 'One LF\n', 'Many LF\n\n\n'):
                with self.subTest(kind=kind, prompt=prompt):
                    directory = self.root / f'{kind}-render'
                    directory.mkdir(exist_ok=True)
                    (directory / 'case.json').write_text(json.dumps({'prompt': prompt}))
                    setup = ('set -euo pipefail\nROOT="$1"; INSTALLED="$2"; DIR="$3"; '
                             'dir="$3"; prompt="$4"\n')
                    argument = '"$(cat "$DIR/prompt.txt")"' if kind == 'design' else '"$prompt"'
                    script = setup + block + '\nprintf "%s" ' + argument
                    sent = subprocess.check_output(['bash', '-c', script, 'fixture', str(source_root),
                                                     str(self.installed), str(directory), prompt])
                    original = (directory / 'prompt-original.txt').read_bytes()
                    expected = (prompt + ('\n' if kind == 'design' else '')).encode()
                    self.assertEqual(original, expected)
                    rendered = (directory / 'prompt.txt').read_bytes()
                    self.assertTrue(rendered.startswith(original + b'\n\n'))
                    self.assertEqual(sent, rendered)

    def test_fast_wiring_invokes_renderer_tests(self):
        source = (SOURCE / 'tests/check-integration-harness.sh').read_text()
        self.assertEqual(source.count('python3 "$ROOT/tests/integration/test-codex-fixture-prompt.py"'), 1)
        self.assertIn('FAIL [Codex fixture prompt rendering and wiring]', source)

    def test_original_and_rendered_paths_must_be_distinct(self):
        original = self.root / 'same.txt'
        original.write_bytes(b'Unchanged original\n')
        result = subprocess.run([sys.executable, str(RENDERER), str(self.installed),
                                 str(original), str(original)], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(original.read_bytes(), b'Unchanged original\n')

    def test_unrepresentable_argv_input_rejects(self):
        for original in (b'contains\0nul', b'invalid utf8 \xff'):
            with self.subTest(original=original):
                output = self.root / 'rendered.txt'
                output.unlink(missing_ok=True)
                result, output = self.render(original)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
