"""Regression coverage for the actual PR #99 CI log and fail-closed parsing."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from test_project_support import classify_result, timeout_budget


class CIResultRegressionTests(unittest.TestCase):
    SUMMARY = 'RENEWED MAP SPAWN TEST: 8899 checks, 0 failures\n'

    def test_actual_successful_spawn_summary(self):
        output = 'Godot Engine v4.7.2.stable.official\nRENEWED MAP CHECKED: faith_04\n' + self.SUMMARY
        self.assertEqual(classify_result('renewed_map_spawn_test', 0, output), (True, False))

    def test_spawn_summary_is_test_specific(self):
        self.assertEqual(classify_result('unrelated_test', 0, self.SUMMARY), (False, False))

    def test_nonzero_exit_never_passes(self):
        self.assertEqual(classify_result('renewed_map_spawn_test', 1, self.SUMMARY), (False, False))

    def test_errors_override_success_summary(self):
        for error in ('SCRIPT ERROR: invalid key', 'ERROR: bad resource',
                      'RENEWED SPAWN FAIL: capacity', 'SOME_TEST_FAILED 1'):
            with self.subTest(error=error):
                self.assertEqual(classify_result('renewed_map_spawn_test', 0, self.SUMMARY + error), (False, False))

    def test_missing_zero_duplicate_or_failing_summaries_are_rejected(self):
        for output in ('', 'RENEWED MAP SPAWN TEST: 0 checks, 0 failures\n',
                       'RENEWED MAP SPAWN TEST: 8899 checks, 1 failures\n',
                       self.SUMMARY * 2,
                       self.SUMMARY + 'RENEWED_SKIP: incomplete\n',
                       self.SUMMARY + 'RENEWED MAP SPAWN TEST: 8899 checks, 1 failures\n',
                       self.SUMMARY + 'PROBE_RESULT {"failures":["capacity"]}\n'):
            with self.subTest(output=output):
                self.assertEqual(classify_result('renewed_map_spawn_test', 0, output), (False, False))

    def test_existing_success_and_skip_contracts_are_preserved(self):
        self.assertEqual(classify_result('ordinary_test', 0, 'ORDINARY_OK\n'), (True, False))
        self.assertEqual(classify_result('optional_test', 0, 'OPTIONAL_SKIP: no source\n'), (True, True))
        self.assertEqual(classify_result('ordinary_test', 0, 'PROBE_RESULT {"failures":[]}\n'), (True, False))
        self.assertEqual(classify_result('ordinary_test', 0, 'PROBE_RESULT invalid\n'), (False, False))

    def test_full_ground_loot_suite_remains_fail_closed(self):
        # Extra time must not turn nonzero exits, emitted errors or missing
        # completion markers into success.
        name = 'ground_loot_system_test'
        self.assertEqual(classify_result(name, 0, 'GROUND_LOOT_SYSTEM_OK: movement, GUI input, effects, IDs, AUTO, save and maps\n'), (True, False))
        self.assertEqual(classify_result(name, 1, 'GROUND_LOOT_SYSTEM_OK\n'), (False, False))
        self.assertEqual(classify_result(name, 0, 'GROUND_LOOT FAIL: collected twice\nGROUND_LOOT_SYSTEM_OK\n'), (False, False))
        self.assertEqual(classify_result(name, 0, 'GROUND_LOOT_SYSTEM checks=166\n'), (False, False))

    def test_setup_cannot_skip(self):
        for name in ('import', 'boot', 'bake_navigation'):
            with self.subTest(name=name):
                self.assertEqual(classify_result(name, 0, 'SETUP_SKIP: missing\n'), (False, False))
        self.assertEqual(classify_result('bake_navigation', 0, 'NAV_BAKE_OK 25\n'), (True, False))
        self.assertEqual(classify_result('bake_navigation', 0, ''), (False, False))

    def test_only_exhaustive_audits_receive_extended_budget(self):
        self.assertEqual(timeout_budget('import', 150, 900), 900)
        for name in ('world_regions_test', 'original_skill_learning_conditions_test'):
            with self.subTest(name=name):
                self.assertEqual(timeout_budget(name, 150, 900), 540)
                self.assertEqual(timeout_budget(name, 600, 900), 600)
        self.assertEqual(timeout_budget('ground_loot_system_test', 150, 900), 300)
        self.assertEqual(timeout_budget('ground_loot_system_test', 250, 900), 300)
        self.assertEqual(timeout_budget('ground_loot_system_test', 450, 900), 450)
        self.assertEqual(timeout_budget('ordinary_test', 150, 900), 150)
        self.assertEqual(timeout_budget('bake_navigation', 150, 900), 150)


if __name__ == '__main__':
    unittest.main()
