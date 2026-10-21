#!/usr/bin/env python3
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import exact_ref_ci as audit

SHA = 'a' * 40
BASE = 'b' * 40
REF = 'fix/pr144'


def report():
    return {'sha': SHA, 'base_sha': BASE, 'ref': REF, 'pr': 144,
            'errors': [], 'workflows': [], 'excluded': []}


def run(run_id=10, workflow_id=1, event='pull_request', status='completed', conclusion='success'):
    return {'id': run_id, 'workflow_id': workflow_id, 'head_sha': SHA, 'head_branch': REF,
            'event': event, 'status': status, 'conclusion': conclusion, 'run_attempt': 1,
            'pull_requests': [{'number': 144, 'head': {'sha': SHA}, 'base': {'sha': BASE}}]}


def row(workflow_id=1, name='test.yml'):
    return {'file': name, 'name': name, 'dispatchable': True, 'blockers': []}


class VerdictTests(unittest.TestCase):
    def verdict(self, value):
        r = report(); r['workflows'] = [{'run': value, 'blockers': []}]
        return audit.verdict(r)

    def test_success_only(self):
        self.assertEqual(self.verdict(run()), 'PASS')

    def test_missing_coverage(self):
        self.assertEqual(audit.verdict(report()), 'BLOCKED')
        self.assertEqual(self.verdict(None), 'INCOMPLETE')

    def test_unfinished_not_pass(self):
        for status in ('queued', 'in_progress', 'waiting'):
            with self.subTest(status=status):
                self.assertEqual(self.verdict(run(status=status, conclusion=None)), 'INCOMPLETE')

    def test_unsuccessful_conclusions(self):
        for conclusion in (*audit.BAD, 'skipped', 'neutral', None):
            with self.subTest(conclusion=conclusion):
                self.assertEqual(self.verdict(run(conclusion=conclusion)), 'FAIL')

    def test_wrong_identity(self):
        for key, value in (('head_sha', BASE), ('head_branch', 'main')):
            r = run(); r[key] = value
            self.assertEqual(self.verdict(r), 'BLOCKED')

    def test_error_and_blocker(self):
        r = report(); r['workflows'] = [{'run': run(), 'blockers': ['missing']}]
        self.assertEqual(audit.verdict(r), 'BLOCKED')
        r['workflows'][0]['blockers'] = []; r['errors'] = ['API failure']
        self.assertEqual(audit.verdict(r), 'BLOCKED')

    def test_failure_with_other_running(self):
        r = report(); r['workflows'] = [{'run': run(conclusion='failure')}, {'run': run(status='queued', conclusion=None)}]
        self.assertEqual(audit.verdict(r), 'FAIL')


class MatchingTests(unittest.TestCase):
    def test_exact_pr_match(self):
        self.assertTrue(audit.matching_run(run(), 1, report()))

    def test_dispatch_match(self):
        r = run(event='workflow_dispatch'); r['pull_requests'] = []
        self.assertTrue(audit.matching_run(r, 1, report()))

    def test_pr_base_and_number_required(self):
        for field, value in (('number', 145), ('base', {'sha': 'c' * 40}), ('head', {'sha': BASE})):
            r = run(); r['pull_requests'][0][field] = value
            self.assertFalse(audit.matching_run(r, 1, report()))

    def test_missing_pr_metadata_rejected(self):
        r = run(); r['pull_requests'] = []
        self.assertFalse(audit.matching_run(r, 1, report()))

    def test_other_identity_rejected(self):
        for field, value in (('workflow_id', 2), ('head_sha', BASE), ('head_branch', 'main'), ('event', 'push')):
            r = run(); r[field] = value
            self.assertFalse(audit.matching_run(r, 1, report()))

    def test_new_failure_cannot_be_replaced_with_old_green(self):
        old, new = run(10), run(11, conclusion='failure')
        self.assertEqual(audit.choose_run([old, new], 1, report())['id'], 11)

    def test_pending_reused(self):
        current = run(status='in_progress', conclusion=None)
        self.assertEqual(audit.choose_run([current], 1, report()), current)


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.directory = self.root / '.github/workflows'
        self.directory.mkdir(parents=True)
        for name in audit.REQUIRED:
            self.write(name)

    def write(self, name, triggers='  pull_request:\n    branches: [main]\n  workflow_dispatch:\n'):
        (self.directory / name).write_text('name: check\non:\n' + triggers + 'jobs:\n  validate:\n    runs-on: ubuntu-latest\n')

    def test_required_coverage(self):
        selected, excluded = audit.inventory(self.root)
        self.assertEqual({r['file'] for r in selected}, audit.REQUIRED)
        self.assertFalse(excluded)

    def test_path_filters_do_not_hide_ci(self):
        self.write('filtered.yml', "  pull_request:\n    branches: [main]\n    paths: [never/changed]\n  workflow_dispatch:\n")
        rows, _ = audit.inventory(self.root)
        self.assertIn('filtered.yml', {r['file'] for r in rows})

    def test_publishers_and_apply_excluded(self):
        for name in audit.PUBLISHERS: self.write(name)
        self.write('apply.yml', '  workflow_dispatch:\n')
        rows, excluded = audit.inventory(self.root)
        self.assertEqual({r['file'] for r in excluded}, audit.PUBLISHERS | {'apply.yml'})
        self.assertEqual(len(rows), len(audit.REQUIRED))

    def test_other_branch_omitted(self):
        self.write('private.yml', '  push:\n    branches: [feature/pr122]\n  workflow_dispatch:\n')
        rows, _ = audit.inventory(self.root)
        self.assertNotIn('private.yml', {r['file'] for r in rows})

    def test_missing_required_is_error(self):
        (self.directory / 'godot-validate.yml').unlink()
        with self.assertRaises(ValueError): audit.inventory(self.root)

    def test_missing_dispatch_retained_for_possible_pr_reuse(self):
        self.write('pr-only.yml', '  pull_request:\n    branches: [main]\n')
        rows, _ = audit.inventory(self.root)
        self.assertFalse(next(r for r in rows if r['file'] == 'pr-only.yml')['dispatchable'])

    def test_required_input_without_default(self):
        self.write('input.yml', '  pull_request:\n  workflow_dispatch:\n    inputs:\n      pack:\n        required: true\n')
        rows, _ = audit.inventory(self.root)
        self.assertFalse(next(r for r in rows if r['file'] == 'input.yml')['dispatchable'])

    def test_branch_order(self):
        self.assertTrue(audit.targets_main({'branches': ['*', '!main', 'main']}))
        self.assertFalse(audit.targets_main({'branches': ['*', '!main']}))
        self.assertFalse(audit.targets_main({'branches-ignore': ['main']}))


class FakeAPI:
    def __init__(self, runs=None, registered=True, missing=False, ambiguous=False, move=False, post_error=False):
        self.runs = copy.deepcopy(runs or [])
        self.posts = []
        self.registered, self.missing, self.ambiguous = registered, missing, ambiguous
        self.move, self.post_error = move, post_error
        self.workflows = [{'path': '.github/workflows/test.yml', 'id': 1, 'state': 'active'}] if registered else []

    def request(self, path, data=None):
        if path == '/git/ref/heads/main': return {'object': {'sha': 'c' * 40 if self.move else BASE}}
        if path == '/git/ref/heads/' + REF: return {'object': {'sha': SHA}}
        if path == '/pulls/144': return {'state': 'open', 'merged': False, 'base': {'ref': 'main', 'sha': BASE}, 'head': {'sha': SHA}}
        if path.endswith('/dispatches'):
            self.posts.append((path, data))
            if self.post_error: raise OSError('ambiguous POST')
            if not self.missing:
                self.runs.append(run(100, event='workflow_dispatch', status='queued', conclusion=None))
                if self.ambiguous: self.runs.append(run(101, event='workflow_dispatch', status='queued', conclusion=None))
            return None
        if path.startswith('/actions/runs/'):
            return next(r for r in self.runs if str(r['id']) == path.split('/')[-1])
        raise AssertionError(path)

    def pages(self, path, key):
        if key == 'workflows': return self.workflows
        if key == 'workflow_runs': return copy.deepcopy(self.runs)
        raise AssertionError((path, key))


class LaunchTests(unittest.TestCase):
    def execute(self, api, selected=None):
        r = report()
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); output = root / 'report.json'
            with patch.object(audit, 'inventory', return_value=(selected or [row()], [])), \
                 patch.object(audit.subprocess, 'check_output', return_value=SHA + '\n'), \
                 patch.object(audit.subprocess, 'run'):
                audit.launch(api, root, r, output, sleep=lambda _: None)
            self.assertEqual(json.loads(output.read_text()), r)
        return r

    def test_reuse_without_dispatch(self):
        api = FakeAPI([run()]); r = self.execute(api)
        self.assertFalse(api.posts); self.assertEqual(r['verdict'], 'PASS')

    def test_reuse_pending_without_duplicate(self):
        api = FakeAPI([run(status='queued', conclusion=None)]); r = self.execute(api)
        self.assertFalse(api.posts); self.assertEqual(r['verdict'], 'INCOMPLETE')

    def test_reuse_failure_without_hiding_or_retry(self):
        api = FakeAPI([run(conclusion='failure')]); r = self.execute(api)
        self.assertFalse(api.posts); self.assertEqual(r['verdict'], 'FAIL')

    def test_dispatch_missing_only(self):
        api = FakeAPI(); r = self.execute(api)
        self.assertEqual(api.posts, [('/actions/workflows/1/dispatches', {'ref': REF})])
        self.assertEqual(r['workflows'][0]['run']['id'], 100)
        self.assertEqual(r['verdict'], 'INCOMPLETE')

    def test_unregistered_blocks(self):
        api = FakeAPI(registered=False); r = self.execute(api)
        self.assertFalse(api.posts); self.assertEqual(r['verdict'], 'BLOCKED')

    def test_main_move_blocks(self):
        api = FakeAPI(move=True); r = self.execute(api)
        self.assertFalse(api.posts); self.assertEqual(r['verdict'], 'BLOCKED')

    def test_ambiguous_post_not_retried(self):
        api = FakeAPI(post_error=True); r = self.execute(api)
        self.assertEqual(len(api.posts), 1); self.assertEqual(r['verdict'], 'BLOCKED')

    def test_registration_missing_not_success(self):
        api = FakeAPI(missing=True); r = self.execute(api)
        self.assertEqual(len(api.posts), 1); self.assertEqual(r['verdict'], 'INCOMPLETE')

    def test_ambiguous_new_runs_not_success(self):
        api = FakeAPI(ambiguous=True); r = self.execute(api)
        self.assertEqual(r['verdict'], 'BLOCKED')

    def test_non_dispatchable_without_run_blocks(self):
        only = row(); only['dispatchable'] = False
        api = FakeAPI(); r = self.execute(api, [only])
        self.assertFalse(api.posts); self.assertEqual(r['verdict'], 'BLOCKED')

    def test_non_dispatchable_existing_pr_is_valid(self):
        only = row(); only['dispatchable'] = False
        api = FakeAPI([run()]); r = self.execute(api, [only])
        self.assertFalse(api.posts); self.assertEqual(r['verdict'], 'PASS')

    def test_pagination_all_results(self):
        api = audit.GitHub('')
        with patch.object(api, 'request', side_effect=[{'items': list(range(100))}, {'items': [100]}]) as request:
            self.assertEqual(len(api.pages('/x', 'items')), 101)
            self.assertEqual(request.call_count, 2)

    def test_verify_uses_recorded_id(self):
        api = FakeAPI([run(10, conclusion='failure')])
        r = report(); r['workflows'] = [{'run': run(10), 'blockers': []}]
        with tempfile.TemporaryDirectory() as temporary:
            audit.verify(api, r, Path(temporary) / 'report.json')
        self.assertEqual(r['verdict'], 'FAIL')


if __name__ == '__main__':
    unittest.main()
