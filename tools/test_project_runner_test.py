"""Real subprocess tests of the Python runner. No Godot/game checks are emulated as PASS.

Run: python3 tools/test_project_runner_test.py
An isolated disposable project and a controlled executable test runner behavior only.
"""
from __future__ import annotations

import json
import copy
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import unittest
from test_project_support import classify_result, failure_annotation, timeout_budget


PR122_TRANSFORM_SCOPE = ('PR122_TRANSFORM_RUN_ONLY_SCOPE_PASS cases=7 slow,fast,stationary '
                         'unique,boss,class,unknown_preserved approvals_added=0')


class PR122ResultContracts(unittest.TestCase):
    def test_existing_pr122_pass_producers(self):
        cases = {
            'pr122_transform_run_only_scope_test': PR122_TRANSFORM_SCOPE,
            'pr122_monster_run_only_scope_test': 'PR122_MONSTER_RUN_ONLY_SCOPE_PASS monsters=318 run_cases=33 existing_walk=preserved transform_unknown=7 approvals_added=0',
        }
        for name, output in cases.items():
            with self.subTest(name=name):
                self.assertEqual(classify_result(name, 0, output + '\n'), (True, False))
                self.assertEqual(classify_result('unrelated_test', 0, output), (False, False))
                self.assertEqual(classify_result(name, 1, output), (False, False))
                self.assertEqual(classify_result(name, 0, output + '\nERROR: failed assertion'), (False, False))
                self.assertEqual(classify_result(name, 0, output + '\n' + output), (False, False))
                self.assertEqual(classify_result(name, 0, output + '\nCASE_SKIP: unavailable'), (False, False))
                self.assertEqual(classify_result(name, 0, 'CASE_OK\n'), (False, False))

    def test_png_runtime_budget_is_bounded_and_does_not_reduce_requested_time(self):
        self.assertEqual(timeout_budget('aden_faith_png_runtime_test', 150, 900), 300)
        self.assertEqual(timeout_budget('aden_faith_png_runtime_test', 450, 900), 450)
        self.assertEqual(timeout_budget('unrelated_test', 150, 900), 150)


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
print("RUNNER_CONTEXT=" + json.dumps({{k: os.environ.get(k) for k in ["XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "TWILIGHT_PR100_BATCH_ISOLATED", "TWILIGHT_PR100_BATCH_CONFIG", "TWILIGHT_PR100_BATCH_REPORT", "TWILIGHT_NATIVE_TEST_KEYS", "TWILIGHT_NATIVE_MAIN_KEY"]}}), flush=True)
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
        env.pop('TWILIGHT_NATIVE_TEST_KEYS', None)
        env.pop('TWILIGHT_NATIVE_MAIN_KEY', None)
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

    def test_pr122_terminal_pass_through_real_runner(self):
        name = 'pr122_transform_run_only_scope_test'
        (self.root / 'tests/case_test.gd').rename(self.root / 'tests' / (name + '.gd'))
        process, summary = self.run_case(output=PR122_TRANSFORM_SCOPE + '\n')
        self.assertEqual(process.returncode, 0)
        self.assertEqual(summary['passed'], 4)
        self.assertEqual(summary['failed'], [])
        self.assertEqual(summary['skipped'], [])

    def test_pr122_terminal_pass_does_not_hide_process_error(self):
        name = 'pr122_transform_run_only_scope_test'
        (self.root / 'tests/case_test.gd').rename(self.root / 'tests' / (name + '.gd'))
        process, summary = self.run_case(output=PR122_TRANSFORM_SCOPE + '\nERROR: bad source\n')
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual(summary['failed'], [name])
        self.assertEqual(summary['passed'], 3)
        self.assertEqual(summary['skipped'], [])

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
            # Some isolated executors expose host /proc with namespace-local
            # getpid()/kill(). Reading /proc/<child pid> there can inspect an
            # unrelated host service. Probe the child's own namespace first.
            try:
                os.kill(pid, 0)
                state = 'present'
            except ProcessLookupError:
                state = 'gone'
            same_pid_namespace = int(Path('/proc/self/stat').read_text().split(' ', 1)[0]) == os.getpid()
            if state != 'gone' and same_pid_namespace:
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



class FailureAnnotationTests(unittest.TestCase):
    def test_annotation_names_check_and_first_causes_on_one_line(self):
        line = failure_annotation('import', '[ 60% ] reimport a.png\nERROR: Missing 100%\nSCRIPT ERROR: Parse Error: x\nok\n')
        self.assertTrue(line.startswith('::error title=TWILIGHT check failed: import::'))
        self.assertIn('ERROR: Missing 100%25', line)
        self.assertIn('SCRIPT ERROR: Parse Error: x', line)
        self.assertNotIn('\n', line)
        self.assertNotIn('reimport', line)

    def test_annotation_falls_back_to_last_lines_and_is_bounded(self):
        self.assertTrue(failure_annotation('boot', 'a\nb\nlast\n').endswith('::a | b | last'))
        self.assertLessEqual(len(failure_annotation('x', 'ERROR: ' + 'y' * 5000)), 1000)



class SourceRuntimeCountedReceiptTests(unittest.TestCase):
    """Retain strict failure detection for existing Godot scalar receipts."""

    CASES = {
        'source_npc_live_placement_test': 'SOURCE_NPC_LIVE_RESULT checks=124 failures=0 actual_placement=6/6',
        'reviewed_existing_monster_visuals_test': 'EXISTING_MONSTER_SOURCE_RESULT checks=256 errors=0 replaced=2',
        'source3_drop_extensions_main_test': 'SOURCE3_DROP_EXTENSIONS_MAIN_RESULT checks=115 errors=0',
        'source3_drop_extensions_test': 'SOURCE3_DROP_EXTENSIONS_RESULT identities=24 rows=41 checks=200 errors=0',
        'source3_item_links_test': 'SOURCE3_ITEM_LINK_RESULT checks=760 errors=0 links=252 stats_imported=0',
        'source3_reviewed_drop_main_test': 'SOURCE3_DROP_MAIN_RESULT phase=write checks=30 failures=0',
        'source_npc_six_test': 'SOURCE_NPC_SIX checks=112 failures=0 placement=checked_by_live_test',
        'source_npc_six_render_test': 'SOURCE_NPC_RENDER slots=8 actors=6 failures=0 placement=diagnostic_only',
        'reviewed_source_monsters_test': 'REVIEWED_SOURCE_MONSTERS checks=50259 failures=0',
        'source3_reviewed_drop_test': 'SOURCE3_DROP_TEST phase=write failures=0',
    }

    def test_exact_positive_receipts_pass_only_their_own_suites(self):
        for name, output in self.CASES.items():
            with self.subTest(name=name):
                self.assertEqual(classify_result(name, 0, output), (True, False))
                self.assertEqual(classify_result('unrelated_test', 0, output), (False, False))
                self.assertEqual(classify_result(name, 1, output), (False, False))
                self.assertEqual(classify_result(name, 0, output + '\nSCRIPT ERROR: broken'), (False, False))
                self.assertEqual(classify_result(name, 0, output + '\nCASE_SKIP: skipped'), (False, False))
                self.assertEqual(classify_result(name, 0, output.replace('=0', '=1')), (False, False))
                self.assertEqual(classify_result(name, 0, output.replace(' checks=', ' checks=0')), (False, False)
                                 if ' checks=' in output else (True, False))

    def test_only_one_render_or_npc_six_terminal_receipt(self):
        for name in ('source_npc_six_test', 'source_npc_six_render_test',
                     'reviewed_source_monsters_test', 'source3_reviewed_drop_test'):
            with self.subTest(name=name):
                value = self.CASES[name]
                self.assertEqual(classify_result(name, 0, value + '\n' + value), (False, False))
                self.assertEqual(classify_result(name, 0, 'CASE_OK'), (False, False))

    def test_npc_child_restart_alone_cannot_authorize_live_placement(self):
        name = 'source_npc_live_placement_test'
        child = 'SOURCE_NPC_LIVE_RESULT checks=3 failures=0 actual_placement=6/6'
        self.assertEqual(classify_result(name, 0, child), (False, False))
        self.assertEqual(classify_result(name, 0, child + '\n' + self.CASES[name]), (True, False))
        self.assertEqual(classify_result(name, 0, child + '\n' + self.CASES[name] +
                                         '\nCASE_RESULT {"failures":["hidden problem"]}'), (False, False))

class ZeroFailureSummaryContracts(unittest.TestCase):
    CASES = {
        'EQUIPMENT_CATEGORY: 39 checks, 0 failures': (True, False),
        'EQUIPMENT_CATEGORY: 39 checks, 2 failures': (False, False),
        'SYMBOL523_TEST {"checks":754,"failures":[]}': (True, False),
        'SYMBOL523_TEST {"checks":754,"failures":["x"]}': (False, False),
        'SKILL_GROUND_WORLD {"checks":3}': (False, False),
        'CURRENCY_DROP_PASS': (True, False),
        'MASTERY523_PASS checks=8153 failures=0 source=synthetic': (True, False),
        'MASTERY523_PASS checks=8153 failures=1 source=synthetic': (False, False),
        'DUNGEON523_RUNTIME: 3 checks / 0 failures': (True, False),
        'A: 3 checks, 0 failures\nB: 4 checks, 1 failures': (False, False),
        'X: 0 checks, 0 failures': (False, False),
        'SKILL_EFFECT_EXPORT_INVENTORY checks=12 resources=3 errors=0': (True, False),
        'nothing here': (False, False),
    }

    def test_explicit_zero_counts_pass_and_any_nonzero_fails(self):
        for output, expected in self.CASES.items():
            with self.subTest(output=output):
                self.assertEqual(classify_result('generic_summary_test', 0, output), expected)
                self.assertEqual(classify_result('generic_summary_test', 1, output), (False, False))
                self.assertEqual(classify_result('generic_summary_test', 0, output + '\nSCRIPT ERROR: x'), (False, False))


class ScriptErrorFailFast(unittest.TestCase):
    def run_child(self, code, **kw):
        from test_project_support import run_isolated
        return run_isolated([sys.executable, '-c', code], env=dict(os.environ), **kw)

    def test_hang_after_script_error_stops_after_grace_and_still_fails(self):
        import time as _t
        began = _t.monotonic()
        result = self.run_child("import sys,time;print('SCRIPT ERROR: x',flush=True);time.sleep(60)",
                                timeout=30, script_error_grace=0.5)
        self.assertLess(_t.monotonic() - began, 15)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('STOPPED_AFTER_SCRIPT_ERROR', result.stderr)
        self.assertEqual(classify_result('any_test', result.returncode, result.stdout + result.stderr), (False, False))

    def test_clean_exit_is_unchanged(self):
        result = self.run_child("print('X_OK')", timeout=30, script_error_grace=0.5)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout.strip(), 'X_OK')
        self.assertNotIn('STOPPED_AFTER_SCRIPT_ERROR', result.stderr)

    def test_error_then_prompt_exit_keeps_real_return_code(self):
        result = self.run_child("import sys;print('SCRIPT ERROR: y',flush=True);sys.exit(3)",
                                timeout=30, script_error_grace=5)
        self.assertEqual(result.returncode, 3)
        self.assertNotIn('STOPPED_AFTER_SCRIPT_ERROR', result.stderr)

    def test_plain_hang_still_times_out(self):
        with self.assertRaises(subprocess.TimeoutExpired):
            self.run_child("import time;time.sleep(60)", timeout=1, script_error_grace=0.5)


ROOT = Path(__file__).resolve().parents[1]


class PrivateInputContracts(unittest.TestCase):
    def test_missing_private_inputs_are_named_and_whitespace_counts_as_missing(self):
        from test_project_support import missing_private_inputs, PRIVATE_INPUT_REQUIREMENTS
        self.assertEqual(missing_private_inputs('base508_pack_test', {}), ['TWILIGHT_BASE508_PACK'])
        self.assertEqual(missing_private_inputs('base508_pack_test', {'TWILIGHT_BASE508_PACK': '  '}), ['TWILIGHT_BASE508_PACK'])
        self.assertEqual(missing_private_inputs('base508_pack_test', {'TWILIGHT_BASE508_PACK': '/p'}), [])
        self.assertEqual(missing_private_inputs('job_smoke_test', {}), [])
        for name, keys in PRIVATE_INPUT_REQUIREMENTS.items():
            with self.subTest(name=name):
                self.assertTrue((ROOT / 'tests' / (name + '.gd')).is_file(), name)
                source = (ROOT / 'tests' / (name + '.gd')).read_text(encoding='utf-8')
                for key in keys:
                    self.assertIn(key, source, 'requirement must be read by the test itself')

    def test_runner_never_counts_unavailable_private_input_as_pass(self):
        runner = (ROOT / 'tools/test_project.py').read_text(encoding='utf-8')
        self.assertIn("private_unavailable[name]=missing", runner)
        self.assertIn("skipped.append(name)", runner)
        self.assertIn("'private_input_unavailable':private_unavailable", runner)


class RetiredLegacyMapContracts(unittest.TestCase):
    def test_retired_tests_exist_and_are_never_counted_as_passed(self):
        from test_project_support import RETIRED_LEGACY_MAP_TESTS, PRIVATE_INPUT_REQUIREMENTS
        for name in RETIRED_LEGACY_MAP_TESTS:
            with self.subTest(name=name):
                self.assertTrue((ROOT / 'tests' / (name + '.gd')).is_file())
                self.assertNotIn(name, PRIVATE_INPUT_REQUIREMENTS)
        self.assertNotIn('world_regions_test', RETIRED_LEGACY_MAP_TESTS)
        self.assertNotIn('native_png_teleport_test', RETIRED_LEGACY_MAP_TESTS)
        runner = (ROOT / 'tools/test_project.py').read_text(encoding='utf-8')
        self.assertIn("'legacy_map_retired':retired_legacy", runner)
        source = (ROOT / 'scripts/maps/source_map_runtime.gd').read_text(encoding='utf-8')
        self.assertIn('mid=="aden_world" or not LEGACY_LAYOUT.active("--legacy-map-layouts")', source,
                      'retirement relies on aden_world always using the source map runtime')


if __name__ == '__main__':
    unittest.main(verbosity=2)
