"""Real subprocess tests of the Python runner. No Godot/game checks are emulated as PASS.

Run: python3 tools/test_project_runner_test.py
An isolated disposable project and a controlled executable test runner behavior only.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest


@unittest.skipUnless(os.name == 'posix', 'Executable fixture uses a POSIX shebang')
class RunnerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='twilight-runner-unit-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / 'tools').mkdir()
        (self.root / 'tests').mkdir()
        self.source = Path(os.environ.get('TWILIGHT_RUNNER_TEST_TARGET', Path(__file__).with_name('test_project.py')))
        shutil.copy2(self.source, self.root / 'tools/test_project.py')
        helper = self.source.with_name('test_project_support.py')
        if helper.exists():
            shutil.copy2(helper, self.root / 'tools' / helper.name)
        (self.root / 'tests/case_test.gd').write_text('extends SceneTree\n', encoding='utf-8')
        self.logs = self.root / 'logs'

    def run_case(self, output='CASE_OK\n', code=0, import_output='', missing=False,
                 raw=False, hang=False, child=False, extra_env=None, bake_output='NAV_BAKE_OK 1\n',
                 bake_code=0, bake_files=True, bake_hang=False):
        engine = self.root / 'controlled_engine'
        if not missing:
            content = f'''#!{sys.executable}
import json, os, pathlib, subprocess, sys, time
print("DATA_DIRS=" + repr([os.environ.get(k) for k in ["XDG_DATA_HOME", "APPDATA", "LOCALAPPDATA"]]), flush=True)
print("RUNNER_CONTEXT=" + json.dumps({{k: os.environ.get(k) for k in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "TWILIGHT_PR100_BATCH_ISOLATED", "TWILIGHT_PR100_BATCH_CONFIG", "TWILIGHT_PR100_BATCH_REPORT"]}}), flush=True)
print("ENGINE_ARGS=" + repr(sys.argv[1:]), flush=True)
if "--import" in sys.argv:
    print({import_output!r}, flush=True)
elif "--script" in sys.argv and sys.argv[sys.argv.index("--script") + 1] == "res://tools/bake_hunting_navigation.gd":
    # Synthetic bytes exercise artifact preservation, not real Godot navigation.
    if {bake_files!r}:
        navigation = pathlib.Path({str(self.root / 'data/maps/navigation')!r})
        navigation.mkdir(parents=True, exist_ok=True)
        (navigation / "fixture.nav").write_bytes(b"controlled-navigation-fixture")
        (navigation / "catalog.json").write_text('{{"fixture": "unit-test-only"}}')
    print({bake_output!r}, end="", flush=True)
    if {bake_hang!r}: time.sleep(60)
    sys.exit({bake_code})
elif "--script" in sys.argv:
    print({output!r}, end="", flush=True)
    if {raw!r}: os.write(2, b"non-utf8: \\xff\\n")
    if {child!r}:
        worker = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"])
        pathlib.Path({str(self.root / 'child.pid')!r}).write_text(str(worker.pid))
    if {hang!r}: time.sleep(60)
    sys.exit({code})
'''
            engine.write_text(content, encoding='utf-8')
            engine.chmod(0o755)
        env = os.environ.copy()
        env.pop('GITHUB_ACTIONS', None)
        env.pop('TWILIGHT_RUNNER_CAPTURE_DIR', None)
        if extra_env:
            env.update(extra_env)
        process = subprocess.run(
            [sys.executable, str(self.root / 'tools/test_project.py'), '--godot', str(engine),
             '--logs', str(self.logs), '--timeout', '1', '--import-timeout', '1'],
            cwd=self.root, env=env, capture_output=True, text=True, timeout=15,
        )
        summary_path = self.logs / 'summary.json'
        self.assertTrue(summary_path.exists(), 'runner must preserve summary on failure: ' + process.stderr)
        return process, json.loads(summary_path.read_text(encoding='utf-8'))

    def assert_failed_case(self, **kwargs):
        process, summary = self.run_case(**kwargs)
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual(summary['failed'], ['case_test'])
        self.assertEqual(summary['passed'], 3)
        self.assertEqual(summary['skipped'], [])
        return summary

    def test_normal_success(self):
        process, summary = self.run_case()
        self.assertEqual(process.returncode, 0)
        self.assertEqual(summary['passed'], 4)

    def test_transform_temporal_child_gets_isolation_and_durable_report(self):
        name = 'original_based_transform_temporal_main_test'
        (self.root / 'tests/case_test.gd').rename(self.root / 'tests' / (name + '.gd'))
        process, summary = self.run_case(extra_env={
            'TWILIGHT_PR100_BATCH_ISOLATED': '0',
            'TWILIGHT_PR100_BATCH_CONFIG': 'unrelated-caller-fixture',
        })
        self.assertEqual(process.returncode, 0)
        self.assertEqual(summary['checks'], ['import', 'bake_navigation', 'boot', name])
        lines = (self.logs / (name + '.log')).read_text().splitlines()
        context = json.loads(next(line.removeprefix('RUNNER_CONTEXT=')
                                  for line in lines if line.startswith('RUNNER_CONTEXT=')))
        self.assertEqual(context['TWILIGHT_PR100_BATCH_ISOLATED'], '1')
        self.assertEqual(context['TWILIGHT_PR100_BATCH_CONFIG'],
                         'res://tests/fixtures/pr100_transform_regression.json')
        self.assertEqual(Path(context['TWILIGHT_PR100_BATCH_REPORT']),
                         self.logs / (name + '.batch.json'))
        data = Path(context['XDG_DATA_HOME'])
        self.assertEqual(Path(context['XDG_CONFIG_HOME']), data / 'config')
        self.assertEqual(Path(context['XDG_CACHE_HOME']), data / 'cache')

    def assert_bake_blocked(self, **kwargs):
        process, summary = self.run_case(**kwargs)
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual(summary['failed'], ['bake_navigation'])
        self.assertEqual(summary['passed'], 1)
        self.assertEqual(summary['skipped'], [])
        self.assertEqual(summary['not_run'], ['boot', 'case_test'])
        self.assertEqual(summary['total'], 4)
        self.assertFalse((self.logs / 'boot.log').exists())
        self.assertFalse((self.logs / 'case_test.log').exists())
        self.assertFalse((self.logs / 'navigation').exists())
        self.assertIn('BLOCKED_BY_BAKE_NAVIGATION 2', process.stdout)

    def test_preparation_order_and_baked_evidence(self):
        process, summary = self.run_case()
        self.assertEqual(process.returncode, 0)
        self.assertEqual(summary['checks'], ['import', 'bake_navigation', 'boot', 'case_test'])
        self.assertEqual(summary['total'], 4)
        self.assertEqual(summary['failed'], [])
        self.assertEqual(summary['not_run'], [])
        pass_lines = [line for line in process.stdout.splitlines() if line.startswith('PASS ')]
        self.assertEqual(pass_lines, ['PASS ' + name for name in summary['checks']])
        source = self.root / 'data/maps/navigation'
        evidence = self.logs / 'navigation'
        self.assertEqual(sorted(p.name for p in evidence.iterdir()), ['catalog.json', 'fixture.nav'])
        for name in ['catalog.json', 'fixture.nav']:
            self.assertEqual((evidence / name).read_bytes(), (source / name).read_bytes())

    def test_bake_nonzero_exit_blocks_remaining(self):
        self.assert_bake_blocked(bake_code=7)

    def test_bake_error_overrides_success(self):
        self.assert_bake_blocked(bake_output='NAV_BAKE_OK 1\nERROR: broken cache\n')

    def test_bake_skip_is_not_preparation(self):
        self.assert_bake_blocked(bake_output='NAV_SKIP: no maps\n')

    def test_bake_missing_success_blocks_remaining(self):
        self.assert_bake_blocked(bake_output='')

    def test_bake_missing_artifacts_blocks_remaining(self):
        self.assert_bake_blocked(bake_files=False)
        self.assertIn('PROCESS_START_FAILED', (self.logs / 'bake_navigation.log').read_text())

    def test_bake_timeout_preserves_partial_log(self):
        self.assert_bake_blocked(bake_hang=True)
        log = (self.logs / 'bake_navigation.log').read_text()
        self.assertIn('TIMEOUT', log)
        self.assertIn('NAV_BAKE_OK', log)

    def test_nonzero_exit_overrides_ok(self):
        self.assert_failed_case(code=7)

    def test_structured_failure_overrides_ok(self):
        self.assert_failed_case(output='CASE_OK\nCASE_RESULT {"failures":["broken"]}\n')

    def test_failed_marker_overrides_ok(self):
        self.assert_failed_case(output='CASE_OK\nCASE_FAILED 1 assertion\n')

    def test_failure_overrides_skip(self):
        self.assert_failed_case(output='CASE_SKIP: unavailable\nCASE_RESULT {"failures":["broken"]}\n')

    def test_malformed_json_overrides_ok(self):
        self.assert_failed_case(output='CASE_OK\nCASE_RESULT {not-json}\n')

    def test_missing_failure_field_overrides_ok(self):
        self.assert_failed_case(output='CASE_OK\nCASE_RESULT {"checks":3}\n')

    def test_transform_batch_result_keeps_strict_failure_array(self):
        process, summary = self.run_case(output='PR100_TRANSFORM_BATCH_RESULT {"cases":10,"checks":606718,"failure_count":0,"failures":[]}\nPR100_TRANSFORM_BATCH_OK\n')
        self.assertEqual(process.returncode, 0)
        self.assertEqual(summary['passed'], 4)

    def test_transform_batch_count_alone_cannot_pass(self):
        self.assert_failed_case(output='PR100_TRANSFORM_BATCH_RESULT {"cases":10,"failure_count":0}\nPR100_TRANSFORM_BATCH_OK\n')

    def test_transform_batch_failure_overrides_ok(self):
        self.assert_failed_case(output='PR100_TRANSFORM_BATCH_RESULT {"cases":10,"failure_count":1,"failures":["missing phase"]}\nPR100_TRANSFORM_BATCH_OK\n')

    def test_digit_result_marker(self):
        process, summary = self.run_case(output='PR93_RESULT {"failures":[]}\n')
        self.assertEqual(process.returncode, 0)
        self.assertEqual(summary['passed'], 4)

    def test_no_success_marker_is_failure(self):
        self.assert_failed_case(output='process completed but did not finish its assertions\n')

    def test_clean_skip_is_not_pass(self):
        process, summary = self.run_case(output='CASE_SKIP: optional fixture missing\n')
        self.assertEqual(process.returncode, 0)
        self.assertEqual(summary['passed'], 3)
        self.assertEqual(summary['skipped'], ['case_test'])

    def test_import_error_blocks_remaining(self):
        process, summary = self.run_case(import_output='ERROR: cannot import')
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual(summary['failed'], ['import'])
        self.assertEqual(summary['not_run'], ['bake_navigation', 'boot', 'case_test'])

    def test_missing_engine_preserves_evidence(self):
        process, summary = self.run_case(missing=True)
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual(summary['failed'], ['import'])
        self.assertEqual(summary['not_run'], ['bake_navigation', 'boot', 'case_test'])
        self.assertIn('PROCESS_START_FAILED', (self.logs / 'import.log').read_text())

    def test_non_utf8_output_preserved(self):
        process, summary = self.run_case(raw=True)
        self.assertEqual(process.returncode, 0)
        self.assertIn('non-utf8: \ufffd', (self.logs / 'case_test.log').read_text())
        self.assertEqual(summary['passed'], 4)

    def test_each_process_gets_its_own_save_directory(self):
        import ast
        self.run_case()
        paths = []
        for name in ['import', 'bake_navigation', 'boot', 'case_test']:
            line = next(s for s in (self.logs / (name + '.log')).read_text().splitlines() if s.startswith('DATA_DIRS='))
            values = ast.literal_eval(line.split('=', 1)[1])
            self.assertEqual(len(set(values)), 1)
            paths.append(values[0])
            self.assertFalse(Path(values[0]).exists())
        self.assertEqual(len(set(paths)), 4)

    def case_engine_args(self):
        import ast
        log = (self.logs / 'case_test.log').read_text()
        line = next(s for s in log.splitlines() if s.startswith('ENGINE_ARGS='))
        return ast.literal_eval(line.split('=', 1)[1])

    def test_optional_capture_defaults_to_headless(self):
        (self.root / 'tests/case_test.gd').write_text(
            '# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_RUNNER_CAPTURE_DIR\n'
            'extends SceneTree\n# environment-gated RenderingServer.frame_post_draw\n')
        process, summary = self.run_case()
        self.assertEqual(process.returncode, 0)
        self.assertEqual(summary['passed'], 4)
        self.assertIn('--headless', self.case_engine_args())
        self.assertNotIn('--rendering-driver', self.case_engine_args())

    def test_requested_optional_capture_requires_real_renderer(self):
        (self.root / 'tests/case_test.gd').write_text(
            '# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_RUNNER_CAPTURE_DIR\n'
            'extends SceneTree\n# environment-gated RenderingServer.frame_post_draw\n')
        process, _ = self.run_case(extra_env={
            'TWILIGHT_RUNNER_CAPTURE_DIR': str(self.root / 'captures'),
            'DISPLAY': ':controlled-runner-only',
        })
        self.assertEqual(process.returncode, 0)
        self.assertIn('--rendering-driver', self.case_engine_args())
        self.assertNotIn('--headless', self.case_engine_args())

    def test_unannotated_draw_still_requires_real_renderer(self):
        (self.root / 'tests/case_test.gd').write_text(
            'extends SceneTree\n# required RenderingServer.frame_post_draw\n')
        process, _ = self.run_case(extra_env={'DISPLAY': ':controlled-runner-only'})
        self.assertEqual(process.returncode, 0)
        self.assertIn('--rendering-driver', self.case_engine_args())
        self.assertNotIn('--headless', self.case_engine_args())

    def test_ambiguous_annotation_keeps_real_renderer(self):
        (self.root / 'tests/case_test.gd').write_text(
            '# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_RUNNER_CAPTURE_DIR\n'
            '# TWILIGHT_OPTIONAL_RENDER_ENV: OTHER_CAPTURE_DIR\n'
            'extends SceneTree\n# RenderingServer.frame_post_draw\n')
        process, _ = self.run_case(extra_env={'DISPLAY': ':controlled-runner-only'})
        self.assertEqual(process.returncode, 0)
        self.assertIn('--rendering-driver', self.case_engine_args())
        self.assertNotIn('--headless', self.case_engine_args())

    def test_timeout_preserves_partial_log(self):
        self.assert_failed_case(hang=True)
        log = (self.logs / 'case_test.log').read_text()
        self.assertIn('TIMEOUT', log)
        self.assertIn('CASE_OK', log)

    @unittest.skipUnless(sys.platform.startswith('linux'), 'Uses /proc to distinguish dead zombies')
    def test_timeout_stops_descendant(self):
        try:
            self.assert_failed_case(hang=True, child=True)
            pid = int((self.root / 'child.pid').read_text())
            stat = Path(f'/proc/{pid}/stat')
            state = stat.read_text().split(') ', 1)[1].split()[0] if stat.exists() else 'gone'
            self.assertIn(state, ['Z', 'gone'], 'timed-out child remains live')
        finally:
            # Baseline intentionally leaves a worker alive; never leak our own fixture.
            path = self.root / 'child.pid'
            if path.exists():
                try:
                    os.kill(int(path.read_text()), signal.SIGKILL)
                except ProcessLookupError:
                    pass


if __name__ == '__main__':
    unittest.main(verbosity=2)
