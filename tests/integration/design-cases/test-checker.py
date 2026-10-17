#!/usr/bin/env python3
"""Mutation regressions for native builder reads and guarded v7 answer replay."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
CHECKER = HERE.parent / 'assert-design-events.jq'
SPEC = 'docs/maxi/specs/0001-line-counter/spec.md'
PROMPT = '/installed/brainstorming/builder-check-prompt.md'
SPECIFIED = ('---\nslug: 0001-line-counter\nstatus: specified\n---\n'
             '# Feature Specification: Counter\n\n## User Scenarios & Testing\nA user counts lines.\n'
             '## Requirements\n### Functional Requirements\n- **FR-001**: Count lines.\n'
             '## Clarifications\n## Success Criteria\n- **SC-001**: Exact counts.\n'
             '## Assumptions\n- Standard library.\n')


def command(text, output):
    return {'type': 'event_msg', 'payload': {'type': 'item_completed', 'completed_at_ms': 2,
            'item': {'type': 'CommandExecution', 'command': ['/bin/zsh', '-lc', text],
                     'cwd': 'file:///fixture', 'status': 'completed', 'exit_code': 0,
                     'aggregated_output': output}}}


def fixture():
    data = json.loads((HERE / 'checker-pass.json').read_text())
    data.update(expected_builder_checks=1, fixture='/fixture', answers=[])
    data['sessions'][0]['id'] = 'parent-id'
    data['installed'][PROMPT] = '# Builder Check Prompt\nRead the canonical design.\n'
    data['sessions'][0]['events'] += [
        {'type': 'response_item', 'payload': {'type': 'function_call', 'name': 'spawn_agent',
         'call_id': 'builder', 'arguments': '{"task_name":"builder"}'}},
        {'type': 'response_item', 'payload': {'type': 'function_call_output', 'call_id': 'builder',
         'output': '{"task_name":"/root/builder"}'}}]
    data['sessions'].append({'agent': '/root/builder', 'id': 'child-id',
        'source': {'subagent': {'thread_spawn': {'parent_thread_id': 'parent-id', 'depth': 1,
                                              'agent_path': '/root/builder'}}},
        'events': [command('cat ' + PROMPT, data['installed'][PROMPT]),
                   command('cat /fixture/' + SPEC, SPECIFIED)]})
    return data


class BuilderEvidence(unittest.TestCase):
    def check(self, data, error=None):
        result = subprocess.run(['jq', '-e', '-f', str(CHECKER)], input=json.dumps(data),
                                capture_output=True, text=True)
        if error:
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn(error, result.stderr)
        else:
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout)

    def test_valid_builder_is_separate_from_design_review(self):
        result = self.check(fixture())
        self.assertEqual(result['builder_checks'], 1)
        self.assertEqual(result['review_dispatches'], 1)
        self.assertEqual(result['reservations'], 1)

    def test_event_time_spec_can_differ_from_final_clarified_body(self):
        data = fixture()
        data['files'][SPEC] = 'status: planned\nwhitespace-only lines are empty\nCorrected body.\n'
        self.check(data)

    def test_relative_canonical_read_requires_fixture_cwd(self):
        data = fixture()
        data['sessions'][-1]['events'][1]['payload']['item']['command'][-1] = 'cat ' + SPEC
        self.check(data)
        data['sessions'][-1]['events'][1]['payload']['item']['cwd'] = 'file:///foreign'
        self.check(data, 'unclassified allocation')

    def test_missing_partial_echo_failed_or_truncated_reads_are_unclassified(self):
        for slot in (0, 1):
            for mutation in ('missing', 'partial', 'echo', 'failed', 'pending', 'truncated', 'foreign'):
                with self.subTest(slot=slot, mutation=mutation):
                    data = fixture()
                    event = data['sessions'][-1]['events'][slot]
                    item = event['payload']['item']
                    if mutation == 'missing':
                        del data['sessions'][-1]['events'][slot]
                    elif mutation == 'partial':
                        item['command'][-1] = item['command'][-1].replace('cat ', "sed -n '1,4p' ")
                        item['aggregated_output'] = item['aggregated_output'][:30]
                    elif mutation == 'echo':
                        item['command'][-1] = 'printf ' + item['command'][-1]
                    elif mutation == 'failed':
                        item['exit_code'] = 1
                    elif mutation == 'pending':
                        event['payload']['completed_at_ms'] = None
                    elif mutation == 'truncated':
                        item['aggregated_output'] = item['aggregated_output'][:20] + '\n... tokens truncated ...\n'
                    elif mutation == 'foreign':
                        item['command'][-1] = item['command'][-1].replace('/installed/', '/foreign/').replace('/fixture/', '/foreign/')
                    self.check(data, 'unclassified allocation')

    def test_complete_python_reads_and_rejects_names_slices_or_echoes(self):
        for slot, path in ((0, PROMPT), (1, '/fixture/' + SPEC)):
            data = fixture()
            item = data['sessions'][-1]['events'][slot]['payload']['item']
            text = "python3 - <<'PY'\nfrom pathlib import Path\np=Path('" + path + "')\nprint(p.read_text())\nPY"
            item['command'][-1] = text
            self.check(data)
            for wrong in ('print(p.name)', 'print(p.read_text()[:30])', 'print("p.read_text()")'):
                item['command'][-1] = text.replace('print(p.read_text())', wrong)
                self.check(data, 'unclassified allocation')

    def test_finite_python_loop_full_reads(self):
        data = fixture()
        item = data['sessions'][-1]['events'][0]['payload']['item']
        text = "python3 - <<'PY'\nfrom pathlib import Path\nbase=Path('/installed')\nfor rel in ['brainstorming/builder-check-prompt.md']:\n p=base/rel\n print(p.read_text())\nPY"
        item['command'][-1] = text
        self.check(data)
        for wrong in ("p=other/rel", "print(p.name)", "print(p.read_text()[:30])"):
            item['command'][-1] = text.replace('p=base/rel' if wrong.startswith('p=') else 'print(p.read_text())', wrong)
            self.check(data, 'unclassified allocation')

    def test_echo_argv_cannot_masquerade_as_shell_read(self):
        data = fixture()
        item = data['sessions'][-1]['events'][0]['payload']['item']
        item['command'] = ['printf', '%s', item['command'][-1]]
        self.check(data, 'unclassified allocation')

    def test_parent_prompt_read_does_not_count_for_child(self):
        data = fixture()
        data['sessions'][0]['events'].append(data['sessions'][-1]['events'].pop(0))
        self.check(data, 'unclassified allocation')

    def test_wrong_parent_or_child_identity_rejects(self):
        for mutation in ('parent', 'child', 'same-session', 'duplicate-session'):
            with self.subTest(mutation=mutation):
                data = fixture()
                child = data['sessions'][-1]
                if mutation == 'parent':
                    child['source']['subagent']['thread_spawn']['parent_thread_id'] = 'foreign'
                elif mutation == 'child':
                    child['agent'] = '/root/other'
                elif mutation == 'same-session':
                    child['id'] = 'parent-id'
                else:
                    data['sessions'].append(copy.deepcopy(child))
                self.check(data, 'unclassified allocation')

    def test_count_mismatch_and_invalid_expectations_reject(self):
        for count in (0, 2, -1, 0.5, None):
            with self.subTest(count=count):
                data = fixture()
                data['expected_builder_checks'] = count
                self.check(data, 'builder')

    def test_draft_accepts_zero_and_rejects_one_builder(self):
        data = fixture()
        data.update(name='v7-draft-only', expected_builder_checks=0)
        data['sessions'].pop()
        data['sessions'][0]['events'] = data['sessions'][0]['events'][:-2]
        self.assertEqual(self.check(data)['builder_checks'], 0)
        data = fixture()
        data.update(name='v7-draft-only', expected_builder_checks=0)
        self.check(data, 'builder check count')

    def test_unknown_allocations_still_fail(self):
        data = fixture()
        data['sessions'][-1]['events'] = [command('true', '')]
        self.check(data, 'unclassified allocation')


class GuardedReplay(unittest.TestCase):
    def test_runner_replays_only_the_declared_completed_question(self):
        runner = (HERE.parent / 'run-codex-design-test.sh').read_text()
        function = runner.split('question_allows_answer() {', 1)[1].split('\n}', 1)[0]
        shell = 'question_allows_answer() {' + function + '\n}\nquestion_allows_answer "$@"'
        case = {'answers': ['Intent answer'], 'answer_question_patterns': ['moment.*wish']}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / 'case.json').write_text(json.dumps(case))
            for text, terminal, accepted in (
                    ('What is the moment you wish this existed?', 'turn.completed', True),
                    ('What JSON key?', 'turn.completed', False),
                    ('What is the moment you wish this existed?', 'turn.failed', False),
                    ('The moment you wish this existed.', 'turn.completed', False)):
                events = [{'type': terminal}, {'type': 'item.completed', 'item':
                          {'type': 'agent_message', 'text': text}}]
                (path / 'turn.jsonl').write_text('\n'.join(map(json.dumps, events)))
                result = subprocess.run(['bash', '-c', shell, 'replay', str(path / 'turn.jsonl'),
                                         str(path / 'case.json'), '0'], capture_output=True)
                self.assertEqual(result.returncode == 0, accepted, text)

    def test_cases_declare_bounded_builders_and_question_patterns(self):
        cases = json.loads((HERE / 'cases.json').read_text())
        for case in cases:
            count = case['expected_builder_checks']
            self.assertIs(type(count), int)
            self.assertGreaterEqual(count, 0)
            self.assertEqual(len(case['answers']), len(case['answer_question_patterns']))
        selected = {case['name']: case for case in cases if case['group'] == 'v7'}
        self.assertEqual(set(selected), {'v7-intent', 'v7-builder', 'v7-skip', 'v7-draft-only'})
        self.assertEqual(selected['v7-draft-only']['expected_builder_checks'], 0)


if __name__ == '__main__':
    unittest.main()
