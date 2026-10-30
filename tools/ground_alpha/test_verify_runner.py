#!/usr/bin/env python3
"""Controlled-process checks for the alpha runner, not a Godot substitute."""
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
from unittest.mock import patch

import verify


class AlphaRunnerTests(unittest.TestCase):
    def response(self, *, importing=False, script=None, code=0, stdout='out', stderr='err'):
        completed = subprocess.CompletedProcess(['engine'], code, stdout, stderr)
        with patch.object(verify, 'run_isolated', return_value=completed) as isolated:
            result = verify.run_engine(['engine'], {}, importing=importing, script=script)
            return result, isolated.call_args

    def test_import_has_1800_second_bound(self):
        result, args = self.response(importing=True)
        self.assertEqual(result, ('outerr', 0, 1800))
        self.assertEqual(args.kwargs['timeout'], 1800)

    def test_explicit_import_timeout_override_keeps_strict_deadline(self):
        with patch.object(verify, 'run_isolated', return_value=subprocess.CompletedProcess(['engine'], 0, 'ok', '')) as isolated:
            text, code, budget = verify.run_engine(['engine'], {}, importing=True, import_timeout=900)
        self.assertEqual((text, code, budget), ('ok', 0, 900))
        self.assertEqual(isolated.call_args.kwargs['timeout'], 900)

    def test_normal_stage_retains_240_second_bound(self):
        result, args = self.response(script='ground_alpha_test')
        self.assertEqual(result[2], 240)
        self.assertEqual(args.kwargs['timeout'], 240)

    def test_existing_exhaustive_budgets_are_preserved(self):
        for name in ('ground_loot_system_test', 'eight_interactions_test'):
            with self.subTest(name=name):
                result, args = self.response(script=name)
                self.assertEqual(result[2], 300)
                self.assertEqual(args.kwargs['timeout'], 300)

    def test_stderr_and_failure_code_are_not_hidden(self):
        result, _ = self.response(code=7, stdout='normal\n', stderr='ERROR: real failure\n')
        self.assertEqual(result[:2], ('normal\nERROR: real failure\n', 7))

    def test_correct_working_directory(self):
        _, args = self.response(importing=True)
        self.assertEqual(args.kwargs['cwd'], str(verify.ROOT))

    def test_timeout_preserves_both_streams_and_fails(self):
        error = subprocess.TimeoutExpired(['engine'], 1800, output=b'progress\xff', stderr=b'error detail')
        with patch.object(verify, 'run_isolated', side_effect=error):
            text, code, budget = verify.run_engine(['engine'], {}, importing=True)
        self.assertEqual((code, budget), (124, 1800))
        self.assertIn('progress', text); self.assertIn('error detail', text); self.assertIn('TIMEOUT', text)

    def test_text_timeout_output(self):
        error = subprocess.TimeoutExpired(['engine'], 240, output='out', stderr='err')
        with patch.object(verify, 'run_isolated', side_effect=error):
            text, code, _ = verify.run_engine(['engine'], {})
        self.assertEqual(code, 124); self.assertIn('outerr', text)

    def test_process_start_error_fails(self):
        with patch.object(verify, 'run_isolated', side_effect=FileNotFoundError('missing engine')):
            text, code, _ = verify.run_engine(['engine'], {})
        self.assertEqual(code, 125); self.assertIn('PROCESS_START_FAILED', text)

    def test_real_controlled_process_preserves_exit_and_output(self):
        command = [sys.executable, '-c', "import sys; print('CONTROLLED_PROCESS'); print('diagnostic', file=sys.stderr); sys.exit(3)"]
        text, code, _ = verify.run_engine(command, dict(os.environ))
        self.assertEqual(code, 3)
        self.assertIn('CONTROLLED_PROCESS', text); self.assertIn('diagnostic', text)

    def test_real_controlled_timeout_does_not_wait_for_descendant(self):
        program = "import subprocess,sys,time; subprocess.Popen([sys.executable,'-c','import time;time.sleep(20)']); print('STARTED',flush=True); time.sleep(20)"
        started = time.monotonic()
        with patch.object(verify, 'timeout_budget', return_value=0.5):
            text, code, _ = verify.run_engine([sys.executable, '-c', program], dict(os.environ))
        self.assertEqual(code, 124); self.assertIn('TIMEOUT', text)
        self.assertLess(time.monotonic() - started, 4)


if __name__ == '__main__':
    unittest.main()
