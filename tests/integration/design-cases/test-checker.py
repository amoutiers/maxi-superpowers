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
            'thread_id': 'child-id', 'turn_id': 'builder-turn',
            'item': {'type': 'CommandExecution', 'command': ['/bin/zsh', '-lc', text],
                     'cwd': 'file:///fixture', 'status': 'completed', 'exit_code': 0,
                     'aggregated_output': output}}}


def builder_completion(message='nothing important left'):
    return [
        {'type': 'event_msg', 'payload': {'type': 'item_completed', 'thread_id': 'child-id',
         'turn_id': 'builder-turn', 'completed_at_ms': 3, 'item': {'type': 'AgentMessage',
          'phase': 'final_answer', 'content': [{'type': 'Text', 'text': message}]}}},
        {'type': 'event_msg', 'payload': {'type': 'task_complete', 'turn_id': 'builder-turn',
         'completed_at': 1, 'last_agent_message': message}}]


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
                   command('cat /fixture/' + SPEC, SPECIFIED)] + builder_completion()})
    return data


class BuilderEvidence(unittest.TestCase):
    def test_reservation_literal_python_helper_binding_is_exact_and_unambiguous(self):
        helper = '/installed/review/design-contract.sh'
        observed = ("python3 - <<'PY'\nimport json,subprocess\nfrom pathlib import Path\n"
            "c=json.loads(Path('/private/tmp/review-context.json').read_text()); r=Path.cwd(); "
            "d=r/'docs/maxi/specs/0001-line-counter'; h='" + helper + "'\n"
            "p=subprocess.run(['bash',h,'reserve',str(d/'reviews/design-review.md'),str(d/'spec.md'),"
            "str(d/'plan.md'),str(r),c['operation_id'],c['request_sha'],'coordinated',"
            "'/root/design_reviewer','absent'],capture_output=True,text=True); print(p.stdout,p.stderr); p.check_returncode()\n"
            "c['reserved_sha']=p.stdout.strip().split('report_sha256=')[1]; "
            "Path('/private/tmp/review-context.json').write_text(json.dumps(c))\nPY")
        definitions = CHECKER.read_text().split('\n. as $input |', 1)[0]
        for label, text, accepted in [
            ('observed', observed, True),
            ('wrong-helper', observed.replace(helper, '/other/design-contract.sh'), False),
            ('reassigned', observed.replace("p=subprocess.run", "h='/other/helper'\np=subprocess.run"), False),
            ('duplicate-call', observed.replace("p=subprocess.run", "subprocess.run(['bash',h,'reserve'])\np=subprocess.run"), False),
            ('echo', 'echo ' + observed, False),
            ('traversal', observed.replace('/private/tmp/review-context.json', '/private/tmp/../review-context.json'), False),
        ]:
            with self.subTest(label=label):
                result = subprocess.run(['jq', '-e', '--arg', 'helper', helper,
                    definitions + '\npython_reservation_call($helper)'],
                    input=json.dumps(command(text, 'DESIGN_REVIEW_RESERVED')['payload']['item']),
                    capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, accepted, result.stderr)

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

    def test_builder_completion_must_follow_reads_and_join_unique_native_message(self):
        mutations = ('missing-both', 'missing-terminal', 'missing-message', 'failed',
                     'inconsistent', 'duplicate-terminal', 'duplicate-message', 'wrong-turn',
                     'wrong-thread', 'pending-message', 'unfinished-terminal',
                     'result-before-reads', 'read-after-message', 'foreign-turn-read',
                     'foreign-thread-read', 'terminal-before-message')
        for mutation in mutations:
            with self.subTest(mutation=mutation):
                data = fixture()
                events = data['sessions'][-1]['events']
                if mutation == 'missing-both': del events[2:]
                elif mutation == 'missing-terminal': events.pop()
                elif mutation == 'missing-message': events.pop(2)
                elif mutation == 'failed': events[-1]['payload']['type'] = 'task_failed'
                elif mutation == 'inconsistent': events[-1]['payload']['last_agent_message'] = 'different answer'
                elif mutation == 'duplicate-terminal': events.append(copy.deepcopy(events[-1]))
                elif mutation == 'duplicate-message': events.insert(3, copy.deepcopy(events[2]))
                elif mutation == 'wrong-turn': events[-1]['payload']['turn_id'] = 'foreign-turn'
                elif mutation == 'wrong-thread': events[2]['payload']['thread_id'] = 'foreign-child'
                elif mutation == 'pending-message': events[2]['payload']['completed_at_ms'] = None
                elif mutation == 'unfinished-terminal': events[-1]['payload'].pop('completed_at')
                elif mutation == 'result-before-reads': events[:] = events[2:] + events[:2]
                elif mutation == 'read-after-message': events.insert(3, events.pop(1))
                elif mutation == 'foreign-turn-read': events[1]['payload']['turn_id'] = 'foreign-turn'
                elif mutation == 'foreign-thread-read': events[1]['payload']['thread_id'] = 'foreign-child'
                else: events[2]['payload']['completed_at_ms'] = 2000
                self.check(data, 'unclassified allocation')

    def test_builder_questions_are_a_valid_completed_result(self):
        data = fixture()
        data['sessions'][-1]['events'][2:] = builder_completion(
            'Should unreadable files report their path? This changes CLI error output.')
        self.assertEqual(self.check(data)['builder_checks'], 1)

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

    def test_cat_operands_share_bounded_absolute_relative_resolution(self):
        absolute = '/fixture/' + SPEC
        for prefix in ('cat ', 'cat -- '):
            for operand in (absolute, SPEC):
                for quote in ('', "'", '"'):
                    with self.subTest(prefix=prefix, operand=operand, quote=quote):
                        data = fixture()
                        data['sessions'][-1]['events'][1] = command(prefix + quote + operand + quote, SPECIFIED)
                        self.check(data)
                        data['sessions'][-1]['events'] = [command(
                            prefix + quote + PROMPT + quote + ' ' + quote + operand + quote,
                            data['installed'][PROMPT] + SPECIFIED)] + builder_completion()
                        self.check(data)
        for text in ('cat ' + PROMPT + ' ' + SPEC,
                     'cat ' + PROMPT + ' /fixture/docs/../docs/maxi/specs/0001-line-counter/spec.md'):
            for cwd in ('file:///foreign', None):
                data = fixture()
                event = command(text, data['installed'][PROMPT] + SPECIFIED)
                event['payload']['item']['cwd'] = cwd
                data['sessions'][-1]['events'] = [event] + builder_completion()
                self.check(data, 'unclassified allocation')
        for operand in ('../fixture/' + SPEC, './' + SPEC, 'docs//maxi/specs/0001-line-counter/spec.md',
                        '$PWD/' + SPEC, '$(pwd)/' + SPEC, SPEC + '*', SPEC + '; true',
                        'docs/%2e%2e/' + SPEC):
            for joined in (False, True):
                data = fixture()
                if joined:
                    data['sessions'][-1]['events'] = [command('cat ' + PROMPT + ' ' + operand,
                        data['installed'][PROMPT] + SPECIFIED)] + builder_completion()
                else:
                    data['sessions'][-1]['events'][1] = command('cat ' + operand, SPECIFIED)
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

    def test_joined_builder_prompt_and_canonical_cat(self):
        data = fixture()
        prompt = data['installed'][PROMPT]
        text = 'cat ' + PROMPT + ' /fixture/' + SPEC
        data['sessions'][-1]['events'] = [command(text, prompt + SPECIFIED)] + builder_completion()
        self.assertEqual(self.check(data)['builder_checks'], 1)
        for wrong in ('printf ' + text, text.replace('/installed/', '/foreign/'),
                      text.replace('/fixture/', '/foreign/'),
                      'cat /fixture/' + SPEC + ' ' + PROMPT,
                      text + '; printf done'):
            bad = copy.deepcopy(data)
            bad['sessions'][-1]['events'][0]['payload']['item']['command'][-1] = wrong
            self.check(bad, 'unclassified allocation')
        for output in (SPECIFIED, prompt[:-1] + SPECIFIED, prompt + SPECIFIED[:60],
                       prompt + SPECIFIED + '\n... tokens truncated ...\n'):
            bad = copy.deepcopy(data)
            bad['sessions'][-1]['events'][0]['payload']['item']['aggregated_output'] = output
            self.check(bad, 'unclassified allocation')
        for mutate in ('parent', 'identity', 'echo-argv', 'failed', 'pending'):
            bad = copy.deepcopy(data)
            event = bad['sessions'][-1]['events'][0]
            if mutate == 'parent':
                bad['sessions'][0]['events'].append(bad['sessions'][-1]['events'].pop())
                bad['sessions'][-1]['events'] = [command('true', '')]
            elif mutate == 'identity':
                bad['sessions'][-1]['source']['subagent']['thread_spawn']['parent_thread_id'] = 'foreign'
            elif mutate == 'echo-argv':
                event['payload']['item']['command'][:2] = ['printf', '%s']
            elif mutate == 'failed':
                event['payload']['item']['exit_code'] = 1
            else:
                event['payload']['completed_at_ms'] = None
            self.check(bad, 'unclassified allocation')

    def test_observed_installed_owner_loops(self):
        python = "python3 - <<'PY'\nfrom pathlib import Path\nr=Path('/installed')\nfor f in ['brainstorming/SKILL.md','brainstorming/builder-check-prompt.md','clarify/SKILL.md','plan/SKILL.md']:\n p=r/f\n assert p.is_file() and not p.is_symlink()\n print('\\nFILE '+str(p.resolve())+'\\n'+p.read_text())\nPY"
        shell = 's=/installed\nfor f in brainstorming/SKILL.md brainstorming/builder-check-prompt.md clarify/SKILL.md; do\ntest -f "$s/$f" && test ! -L "$s/$f" && test -r "$s/$f" || exit 1\ncat "$s/$f"\ndone\ngit status --short\nls -R docs/maxi'
        for text, owner in ((python, 'plan'), (shell, 'clarify')):
            with self.subTest(form=text.splitlines()[0]):
                data = fixture()
                data['owners'] = [owner]
                data['sessions'][0]['events'][0] = command(text, 'PLAN OWNER\nCLARIFY OWNER\n')
                self.check(data)
                mutations = [text.replace('/installed', '/foreign'),
                             text.replace('plan/SKILL.md', 'other/SKILL.md') if owner == 'plan' else
                             text.replace('clarify/SKILL.md', 'other/SKILL.md')]
                if owner == 'plan':
                    mutations += [text.replace('p=r/f', 'p=other/f'),
                                  text.replace('p=r/f', "r=Path('/foreign'); p=r/f"),
                                  text.replace('p=r/f', 'p=r/rel'),
                                  text.replace('p.read_text()', 'p.name'),
                                  text.replace('p.read_text()', 'p.read_text()[:30]')]
                else:
                    mutations += [text.replace('cat "$s/$f"', 'printf "$s/$f"'),
                                  text.replace('cat "$s/$f"', 'cat "$other/$f"'),
                                  text.replace('cat "$s/$f"', 's=/foreign; cat "$s/$f"'),
                                  text.replace('clarify/SKILL.md; do', 'clarify/SKILL.md ../outside.md; do')]
                for wrong in mutations:
                    bad = copy.deepcopy(data)
                    bad['sessions'][0]['events'][0]['payload']['item']['command'][-1] = wrong
                    self.check(bad, 'absent completed installed-owner read')
                for mutate in ('bytes', 'truncated', 'failed', 'pending', 'argv'):
                    bad = copy.deepcopy(data)
                    event = bad['sessions'][0]['events'][0]
                    if mutate == 'bytes':
                        event['payload']['item']['aggregated_output'] = 'incomplete'
                    elif mutate == 'truncated':
                        event['payload']['item']['aggregated_output'] += '... tokens truncated ...'
                    elif mutate == 'failed':
                        event['payload']['item']['exit_code'] = 1
                    elif mutate == 'pending':
                        event['payload']['completed_at_ms'] = None
                    else:
                        event['payload']['item']['command'][:2] = ['printf', '%s']
                    self.check(bad, 'absent completed installed-owner read')

    def test_observed_filename_braces_read_owner(self):
        data = fixture()
        data['owners'] = ['plan']
        text = 'cat /installed/plan/{SKILL.md,plan-template.md} /installed/specify/{spec-author.md,spec-template.md} /installed/using-maxi/skill-resolution.md'
        data['sessions'][0]['events'][0] = command(text, 'PLAN OWNER\n')
        self.check(data)
        for wrong in ('printf ' + text, text.replace('/installed/plan/', '/foreign/plan/'),
                      text.replace('SKILL.md,', 'OTHER.md,'), text + '; printf done',
                      text.replace('plan-template.md', '../outside.md'),
                      text.replace('/installed/using-maxi/', '/foreign/using-maxi/')):
            bad = copy.deepcopy(data)
            bad['sessions'][0]['events'][0]['payload']['item']['command'][-1] = wrong
            self.check(bad, 'absent completed installed-owner read')
        bad = copy.deepcopy(data)
        bad['sessions'][0]['events'][0]['payload']['item']['aggregated_output'] = 'partial'
        self.check(bad, 'absent completed installed-owner read')

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
