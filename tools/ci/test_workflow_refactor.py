"""Guard against hiding changed CI coverage behind a shared setup action."""
import copy
import unittest
from validate_workflow_refactor import expand, assert_preserved_workflow, STALE_POLICY, assert_new_cleanup


class RefactorContractTest(unittest.TestCase):
    def setUp(self):
        self.action = {'runs': {'using': 'composite', 'steps': [{'shell': 'bash', 'run': 'curl --fail pinned.zip\n'}]}}
        self.before = {'name': 'stable check', 'on': {'pull_request': None}, 'jobs': {'regression': {'runs-on': 'ubuntu-latest', 'steps': [{'name': 'engine', 'run': 'curl --fail pinned.zip\n'}, {'run': 'run-test && grep -q EXPECTED evidence.log\n'}]}}}
        self.after = copy.deepcopy(self.before)
        self.after['jobs']['regression']['steps'][0] = {'name': 'engine', 'uses': './.github/actions/setup'}

    def test_exact_expansion(self):
        self.assertEqual(self.before, expand(self.after, lambda _: self.action))

    def test_changed_install_command_is_visible(self):
        self.action['runs']['steps'][0]['run'] = 'true\n'
        self.assertNotEqual(self.before, expand(self.after, lambda _: self.action))

    def test_assertion_and_check_name_and_filter_changes_are_visible(self):
        for kind in ('assertion', 'name', 'filter'):
            with self.subTest(kind=kind):
                changed = copy.deepcopy(self.after)
                if kind == 'assertion':
                    changed['jobs']['regression']['steps'][1]['run'] = 'run-test\n'
                elif kind == 'name':
                    changed['jobs']['other'] = changed['jobs'].pop('regression')
                else:
                    changed['on']['pull_request'] = {'paths': ['docs/**']}
                self.assertNotEqual(self.before, expand(changed, lambda _: self.action))

    def test_conditional_or_parameterized_extraction_is_rejected(self):
        for key in ('if', 'with', 'env', 'continue-on-error'):
            with self.subTest(key=key):
                changed = copy.deepcopy(self.after)
                changed['jobs']['regression']['steps'][0][key] = 'unexpected'
                with self.assertRaises(AssertionError):
                    expand(changed, lambda _: self.action)

    def test_multi_step_action_is_rejected(self):
        self.action['runs']['steps'].append({'shell': 'bash', 'run': 'unexpected'})
        with self.assertRaises(AssertionError):
            expand(self.after, lambda _: self.action)


class SupersededCIContractTest(unittest.TestCase):
    def test_only_allowlisted_pr_cancel_field_can_change(self):
        name = '.github/workflows/twilight-shop-buyback.yml'
        before = {'concurrency': {'group': 'one-pr', 'cancel-in-progress': False},
                  'jobs': {'check': {'steps': [{'run': 'run-tests'}]}}}
        after = copy.deepcopy(before)
        after['concurrency']['cancel-in-progress'] = STALE_POLICY
        assert_preserved_workflow(name, before, after, lambda _: None)
        for modification in ('command', 'global_cancel', 'group'):
            changed = copy.deepcopy(after)
            if modification == 'command':
                changed['jobs']['check']['steps'][0]['run'] = 'true'
            if modification == 'global_cancel':
                changed['concurrency']['cancel-in-progress'] = True
            if modification == 'group':
                changed['concurrency']['group'] = 'all-prs'
            with self.subTest(modification=modification), self.assertRaises(AssertionError):
                assert_preserved_workflow(name, before, changed, lambda _: None)

    def test_other_workflow_cannot_change_concurrency(self):
        name = '.github/workflows/resource-integrity.yml'
        before = {'concurrency': {'cancel-in-progress': False}, 'jobs': {}}
        after = copy.deepcopy(before)
        after['concurrency']['cancel-in-progress'] = STALE_POLICY
        with self.assertRaises(AssertionError):
            assert_preserved_workflow(name, before, after, lambda _: None)


if __name__ == '__main__':
    unittest.main()
