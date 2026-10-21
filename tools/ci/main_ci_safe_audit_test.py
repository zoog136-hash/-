#!/usr/bin/env python3
import copy
import unittest
from main_ci_safe_audit import safe_inventory, REQUIRED_REPAIRS, PUBLISHING_WORKFLOWS


def rows():
    return [{'file': name, 'name': name, 'blockers': []}
            for name in sorted(REQUIRED_REPAIRS | set(PUBLISHING_WORKFLOWS))]


class SafetyTests(unittest.TestCase):
    def test_publishers_are_not_dispatched(self):
        selected, excluded = safe_inventory((rows(), []))
        self.assertEqual({r['file'] for r in selected}, REQUIRED_REPAIRS)
        self.assertEqual({r['file'] for r in excluded}, set(PUBLISHING_WORKFLOWS))

    def test_reasons_are_explicit(self):
        _, excluded = safe_inventory((rows(), []))
        self.assertTrue(all('git push to main' in r['reason'] for r in excluded))
        self.assertTrue(all(r['category'] == 'publishing_not_ci' for r in excluded))

    def test_old_exclusions_remain(self):
        old = [{'file': 'apply.yml', 'reason': 'manual apply'}]
        _, excluded = safe_inventory((rows(), old))
        self.assertEqual(excluded[0], old[0])

    def test_input_is_not_mutated(self):
        original = (rows(), [])
        before = copy.deepcopy(original)
        selected, excluded = safe_inventory(original)
        selected[0]['blockers'].append('test')
        excluded[0]['reason'] = 'changed'
        self.assertEqual(original, before)

    def test_each_repaired_workflow_is_mandatory(self):
        for missing in REQUIRED_REPAIRS:
            with self.subTest(missing=missing), self.assertRaises(ValueError):
                safe_inventory(([r for r in rows() if r['file'] != missing], []))

    def test_other_ci_preserved(self):
        extra = {'file': 'other-validation.yml', 'blockers': ['not registered']}
        selected, _ = safe_inventory((rows() + [extra], []))
        self.assertIn(extra, selected)

    def test_required_ci_blocker_is_preserved(self):
        original = rows()
        row = next(r for r in original if r['file'] in REQUIRED_REPAIRS)
        row['blockers'] = ['missing dispatch']
        selected, _ = safe_inventory((original, []))
        self.assertEqual(next(r for r in selected if r['file'] == row['file'])['blockers'], ['missing dispatch'])

    def test_failed_result_is_preserved(self):
        original = rows()
        row = next(r for r in original if r['file'] in REQUIRED_REPAIRS)
        row['run'] = {'conclusion': 'failure'}
        selected, _ = safe_inventory((original, []))
        self.assertEqual(next(r for r in selected if r['file'] == row['file'])['run'], {'conclusion': 'failure'})

    def test_empty_inventory_fails(self):
        with self.assertRaises(ValueError):
            safe_inventory(([], []))


if __name__ == '__main__':
    unittest.main()
