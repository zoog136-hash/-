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
from test_project_support import classify_result, timeout_budget, native_fixture_environment, run_native_fixture_cases


PR122_REACTION = ('PR122_NATIVE_REACTION_PASS actors=2 hit_cases=48 fps=30,60,120 '
                  'headings=E,N catalog_candidate_without_profile_metadata=true '
                  'moving_and_stationary=true all_six_phases=true '
                  'hit_clock_combat_marker_collision_class_preserved=true '
                  'turn_idle_death=true engine=4.7.2-stable (official) approvals_added=0')
PR122_TRANSFORM_SCOPE = ('PR122_TRANSFORM_RUN_ONLY_SCOPE_PASS cases=7 slow,fast,stationary '
                         'unique,boss,class,unknown_preserved approvals_added=0')
PR122_DEATH = ('PR122_S_ONLY_DEATH_MAIN_RESULT directions=8 poses=6 '
               'actual_staged=false art_approvals=0 failures=0')


class PR122ResultContracts(unittest.TestCase):
    def test_existing_pr122_pass_producers(self):
        cases = {
            'pr122_native_reaction_test': PR122_REACTION,
            'pr122_transform_run_only_scope_test': PR122_TRANSFORM_SCOPE,
            'pr122_monster_run_only_scope_test': 'PR122_MONSTER_RUN_ONLY_SCOPE_PASS monsters=318 run_cases=33 existing_walk=preserved transform_unknown=7 approvals_added=0',
            'pr122_girtas_native_default_main_connection_test': 'PR122_NATIVE_DEFAULT_MAIN_PASS key=transform:267 tracks=48 poses=288 candidate_injection=0',
            'pr122_native_default_main_connection_test': 'PR122_NATIVE_DEFAULT_MAIN_PASS key=transform:393 tracks=48 poses=288 candidate_injection=0',
            'pr122_native_action_test': 'PR122_NATIVE_ACTION_PASS clips=32 all_six_phases=true attack_marker_frame=3 authoritative_clock_preserved=true native_foot_collision_class_preserved=true engine=4.7.2-stable (official) approvals_added=0',
            'pr122_native_batch_candidate_test': 'PR122_BATCH_CANDIDATE_INTEGRATION_PASS actors=15 clips=278 death_directions=80 unsized_frame_fixtures=1 production_switches=0 approvals_added=0',
            'pr122_native_locomotion_resource_test': 'PR122_NATIVE_RESOURCE_PASS tracks=419 poses=2514 approvals_added=0 engine=4.7.2-stable (official)',
            'pr122_native_main_connection_test': 'PR122_NATIVE_MAIN_PASS key=transform:393 native_clips=48 directional_cases=40 plus_death=true authoritative_clock_inventory_collision_preserved=true catalog_replacements=0 approvals_added=0',
            'pr122_native_player_connection_test': 'PR122_NATIVE_PLAYER_CONNECTION_PASS actors=17 clips=16 native_phases=96 position_collision_class_combat_sequence_preserved=true engine=4.7.2-stable (official) production_catalog_switches=0 approvals_added=0',
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

    def test_pr122_incomplete_or_wrong_actor_summary_fails_closed(self):
        name = 'pr122_native_reaction_test'
        for output in [PR122_REACTION.replace('actors=2', 'actors=0'),
                       PR122_REACTION.replace('hit_cases=48', 'hit_cases=0'),
                       PR122_REACTION.replace('approvals_added=0', 'approvals_added=1'),
                       PR122_REACTION.replace('_PASS ', '_PASS_EXTRA '),
                       PR122_REACTION + '\nCASE_RESULT {"failures":["missing phase"]}',
                       PR122_REACTION + '\nCASE_RESULT {not-json}',
                       PR122_REACTION + '\nCASE_RESULT {"checks":48}',
                       'prefix ' + PR122_REACTION, 'PR122_NATIVE_REACTION_PASS']:
            with self.subTest(output=output):
                self.assertEqual(classify_result(name, 0, output), (False, False))
        self.assertEqual(classify_result('pr122_native_default_main_connection_test', 0,
            'PR122_NATIVE_DEFAULT_MAIN_PASS key=transform:267 tracks=48 poses=288 candidate_injection=0'), (False, False))

    def test_counted_death_summary_requires_all_directions_and_zero_failures(self):
        name = 'pr122_s_only_death_main_test'
        for staged in ('true', 'false'):
            self.assertEqual(classify_result(name, 0, PR122_DEATH.replace('actual_staged=false', 'actual_staged=' + staged)), (True, False))
        for output in [PR122_DEATH.replace('failures=0', 'failures=1'),
                       PR122_DEATH.replace('directions=8', 'directions=7'),
                       PR122_DEATH.replace('poses=6', 'poses=0'),
                       PR122_DEATH.replace('actual_staged=false', 'actual_staged=unknown'),
                       PR122_DEATH.replace('art_approvals=0', 'art_approvals=1'),
                       PR122_DEATH.replace(' failures=0', ''),
                       PR122_DEATH + '\n' + PR122_DEATH,
                       PR122_DEATH + '\nCASE_SKIP: unavailable',
                       PR122_DEATH + '\nSCRIPT ERROR: Assertion failed.',
                       PR122_DEATH + '\nCASE_RESULT {"failures":["broken"]}',
                       'CASE_OK\n', 'CASE_RESULT {"failures":[]}']:
            with self.subTest(output=output):
                self.assertEqual(classify_result(name, 0, output), (False, False))
        self.assertEqual(classify_result(name, 1, PR122_DEATH), (False, False))
        self.assertEqual(classify_result('unrelated_test', 0, PR122_DEATH), (False, False))

    def test_native_summary_must_match_the_requested_actor_scope(self):
        main = ('PR122_NATIVE_MAIN_PASS key=transform:393 native_clips=48 directional_cases=40 '
                'plus_death=true authoritative_clock_inventory_collision_preserved=true '
                'catalog_replacements=0 approvals_added=0')
        name = 'pr122_native_main_connection_test'
        self.assertEqual(classify_result(name, 0, main,
            expected_native_keys=['transform:393']), (True, False))
        self.assertEqual(classify_result(name, 0, main,
            expected_native_keys=['transform:267']), (False, False))
        for name, output in [
            ('pr122_native_player_connection_test',
             'PR122_NATIVE_PLAYER_CONNECTION_PASS actors=1 clips=8 native_phases=48 position_collision_class_combat_sequence_preserved=true engine=4.7.2 production_catalog_switches=0 approvals_added=0'),
            ('pr122_native_batch_candidate_test',
             'PR122_BATCH_CANDIDATE_INTEGRATION_PASS actors=1 clips=8 death_directions=8 unsized_frame_fixtures=0 production_switches=0 approvals_added=0'),
        ]:
            with self.subTest(name=name):
                self.assertEqual(classify_result(name, 0, output,
                    expected_native_keys=['transform:130']), (True, False))
                self.assertEqual(classify_result(name, 0, output,
                    expected_native_keys=['transform:130', 'transform:413']), (False, False))
                self.assertEqual(classify_result(name, 0, output.replace('actors=1', 'actors=17'),
                    expected_native_keys=['transform:130']), (False, False))

    def test_png_runtime_budget_is_bounded_and_does_not_reduce_requested_time(self):
        self.assertEqual(timeout_budget('aden_faith_png_runtime_test', 150, 900), 300)
        self.assertEqual(timeout_budget('aden_faith_png_runtime_test', 450, 900), 450)
        self.assertEqual(timeout_budget('unrelated_test', 150, 900), 150)


class PR122NativeFixtureContracts(unittest.TestCase):
    def setUp(self):
        def actor(tracks, *, approved=False, profile=True):
            value = {'tracks': [{'role': role, 'direction': direction} for role, direction in tracks],
                     'production_connected': approved, 'detailed_completed': approved,
                     'native_track_count': len(tracks), 'native_pose_count': len(tracks) * 6}
            if profile:
                value['native_profile'] = 'res://fixture-profile.tres'
            return value
        full = [(role, direction) for role in ('idle', 'walk', 'run', 'attack', 'hit', 'death')
                for direction in ('E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE')]
        self.registry = {'actors': {
            'transform:393': actor(full, approved=True),
            'transform:267': actor(full, approved=True),
            'transform:413': actor([('walk', 'E'), ('run', 'E'), ('death', 'S'), ('death', 'E')]),
            'transform:130': actor([('idle', 'E'), ('run', 'E'), ('death', 'S')]),
            'transform:399': actor([('idle', 'E')], profile=False),
        }}

    def test_each_contract_selects_all_compatible_registered_actors(self):
        before = copy.deepcopy(self.registry)
        expectations = {
            'pr122_native_locomotion_resource_test': ['transform:130', 'transform:399', 'transform:413'],
            'pr122_native_batch_candidate_test': ['transform:130', 'transform:399'],
            'pr122_native_action_test': ['transform:130', 'transform:267', 'transform:393', 'transform:413'],
            'pr122_native_player_connection_test': ['transform:130', 'transform:267', 'transform:393', 'transform:413'],
            'pr122_native_main_connection_test': ['transform:393'],
        }
        for name, keys in expectations.items():
            with self.subTest(name=name):
                updates, audit = native_fixture_environment(name, self.registry, {})
                variable = 'TWILIGHT_NATIVE_MAIN_KEY' if name == 'pr122_native_main_connection_test' else 'TWILIGHT_NATIVE_TEST_KEYS'
                self.assertEqual(updates, {variable: ','.join(keys)})
                self.assertEqual(audit['keys'], keys)
                self.assertEqual(audit['frame_only_batch_actors'], ['transform:399'])
                self.assertEqual(audit['approved_default_main_actors'], ['transform:267', 'transform:393'])
                self.assertEqual(audit['registry_actors'], 5)
        self.assertEqual(self.registry, before)

    def test_explicit_scope_is_preserved_exactly(self):
        env = {'TWILIGHT_NATIVE_TEST_KEYS': 'transform:413,transform:130', 'UNCHANGED': 'value'}
        before = dict(env)
        updates, audit = native_fixture_environment('pr122_native_player_connection_test', self.registry, env)
        self.assertEqual(updates, {})
        self.assertEqual(env, before)
        self.assertEqual(audit['keys'], ['transform:413', 'transform:130'])
        self.assertEqual(audit['scope_origin'], 'explicit')
        updates, audit = native_fixture_environment('pr122_native_main_connection_test', self.registry,
                                                   {'TWILIGHT_NATIVE_MAIN_KEY': 'transform:267'})
        self.assertEqual(updates, {})
        self.assertEqual(audit['keys'], ['transform:267'])

    def test_invalid_explicit_scope_never_falls_back_or_drops_keys(self):
        for value in ['transform:399', 'transform:130,missing', 'transform:130,transform:130',
                      '', ' transform:130', ',', 'transform:130,']:
            with self.subTest(value=value), self.assertRaises(ValueError):
                native_fixture_environment('pr122_native_player_connection_test', self.registry,
                                           {'TWILIGHT_NATIVE_TEST_KEYS': value})
        with self.assertRaises(ValueError):
            native_fixture_environment('pr122_native_locomotion_resource_test', self.registry,
                                       {'TWILIGHT_NATIVE_TEST_KEYS': 'transform:393'})
        with self.assertRaises(ValueError):
            native_fixture_environment('pr122_native_main_connection_test', self.registry,
                                       {'TWILIGHT_NATIVE_MAIN_KEY': 'transform:413'})
        with self.assertRaises(ValueError):
            native_fixture_environment('pr122_native_main_connection_test', self.registry,
                                       {'TWILIGHT_NATIVE_MAIN_KEY': ''})

    def test_no_registry_actor_can_disappear_from_runtime_coverage(self):
        self.registry['actors']['transform:399']['tracks'][0]['role'] = 'walk'
        with self.assertRaisesRegex(ValueError, 'no compatible runtime fixture'):
            native_fixture_environment('pr122_native_player_connection_test', self.registry, {})

    def test_corrupt_approval_or_track_counts_fail_before_launch(self):
        for field, value in [('production_connected', True), ('native_track_count', 99),
                             ('detailed_completed', None)]:
            registry = copy.deepcopy(self.registry)
            registry['actors']['transform:130'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                native_fixture_environment('pr122_native_batch_candidate_test', registry, {})
        del self.registry['actors']['transform:267']
        with self.assertRaisesRegex(ValueError, 'lost default-Main coverage'):
            native_fixture_environment('pr122_native_action_test', self.registry, {})

    def test_unknown_suite_gets_no_native_environment(self):
        self.assertEqual(native_fixture_environment('unrelated_test', {}, {}), ({}, {}))


class PR122NativeIsolationContracts(unittest.TestCase):
    marker = ('PR122_NATIVE_PLAYER_CONNECTION_PASS actors=1 clips=8 native_phases=48 '
              'position_collision_class_combat_sequence_preserved=true engine=4.7.2 '
              'production_catalog_switches=0 approvals_added=0\n')

    def run_children(self, first=None, first_code=0, delay=0, total=5):
        self.tmp = tempfile.TemporaryDirectory(prefix='twilight-native-runner-unit-')
        self.addCleanup(self.tmp.cleanup)
        folder = Path(self.tmp.name)
        code = ('import os,time,sys,json\n'
                'key=os.environ["TWILIGHT_NATIVE_TEST_KEYS"]\n'
                'print("CONTEXT="+json.dumps({"key":key,"save":os.environ["XDG_DATA_HOME"]}),flush=True)\n'
                'if key=="transform:130":\n'
                f' print({self.marker if first is None else first!r},end="",flush=True)\n'
                f' time.sleep({delay!r})\n'
                f' sys.exit({first_code!r})\n'
                f'print({self.marker!r},end="",flush=True)\n')
        return run_native_fixture_cases([sys.executable, '-c', code],
            name='pr122_native_player_connection_test', keys=['transform:130', 'transform:413'],
            env=os.environ, timeout=total, case_timeout=1, cwd=str(folder), logs=folder / 'cases')

    def test_all_actors_run_with_independent_saves_and_individual_evidence(self):
        passed, output, rows = self.run_children()
        self.assertTrue(passed)
        self.assertEqual([row['key'] for row in rows], ['transform:130', 'transform:413'])
        saves = []
        for row in rows:
            self.assertTrue(row['passed'])
            line = next(s for s in Path(row['log']).read_text().splitlines() if s.startswith('CONTEXT='))
            context = json.loads(line.removeprefix('CONTEXT='))
            self.assertEqual(context['key'], row['key'])
            saves.append(context['save'])
            self.assertFalse(Path(context['save']).exists())
        self.assertEqual(len(set(saves)), 2)
        self.assertIn('"actors_passed": 2', output)

    def test_later_success_cannot_hide_first_error_skip_or_incomplete_output(self):
        for first, code in [(self.marker, 7),
                            (self.marker + 'SCRIPT ERROR: bad source\n', 0),
                            (self.marker.replace('actors=1', 'actors=17'), 0),
                            ('NATIVE_SKIP: missing source\n', 0),
                            ('CASE_OK\n', 0)]:
            with self.subTest(first=first, code=code):
                passed, output, rows = self.run_children(first, code)
                self.assertFalse(passed)
                self.assertFalse(rows[0]['passed'])
                self.assertTrue(rows[1]['passed'])
                self.assertIn('"failures": ["transform:130"]', output)

    def test_total_deadline_cannot_report_unrun_actors_as_completed(self):
        passed, output, rows = self.run_children(delay=1, total=.15)
        self.assertFalse(passed)
        self.assertEqual(rows[0]['status'], 'TIMEOUT')
        self.assertEqual(rows[1]['status'], 'NOT_RUN_TOTAL_TIMEOUT')
        self.assertIn('"actors_completed": 0', output)
        self.assertIn('"actors_passed": 0', output)


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

    def prepare_native_fixture(self, name='pr122_native_player_connection_test'):
        fixture = PR122NativeFixtureContracts()
        fixture.setUp()
        (self.root / 'data').mkdir()
        (self.root / 'data/pr122_native_locomotion_staging.json').write_text(json.dumps(fixture.registry))
        (self.root / 'tests/case_test.gd').rename(self.root / 'tests' / (name + '.gd'))
        return name

    def test_native_scope_defaults_reach_child_and_durable_summary(self):
        name = self.prepare_native_fixture()
        output = ('PR122_NATIVE_PLAYER_CONNECTION_PASS actors=1 clips=8 native_phases=48 '
                  'position_collision_class_combat_sequence_preserved=true engine=4.7.2 '
                  'production_catalog_switches=0 approvals_added=0\n')
        process, summary = self.run_case(output=output)
        self.assertEqual(process.returncode, 0)
        expected = ['transform:130', 'transform:267', 'transform:393', 'transform:413']
        audit = summary['native_fixture_scopes'][name]
        self.assertEqual(audit['keys'], expected)
        self.assertEqual(audit['scope_origin'], 'registry_default')
        self.assertEqual(audit['frame_only_batch_actors'], ['transform:399'])
        self.assertEqual([case['key'] for case in audit['cases']], expected)
        for case in audit['cases']:
            self.assertTrue(case['passed'])
            lines = Path(case['log']).read_text().splitlines()
            context = json.loads(next(line.removeprefix('RUNNER_CONTEXT=')
                                      for line in lines if line.startswith('RUNNER_CONTEXT=')))
            self.assertEqual(context['TWILIGHT_NATIVE_TEST_KEYS'], case['key'])

    def test_explicit_native_scope_reaches_child_unchanged(self):
        name = self.prepare_native_fixture()
        output = ('PR122_NATIVE_PLAYER_CONNECTION_PASS actors=2 clips=8 native_phases=48 '
                  'position_collision_class_combat_sequence_preserved=true engine=4.7.2 '
                  'production_catalog_switches=0 approvals_added=0\n')
        explicit = 'transform:413,transform:130'
        process, summary = self.run_case(output=output, extra_env={'TWILIGHT_NATIVE_TEST_KEYS': explicit})
        self.assertEqual(process.returncode, 0)
        lines = (self.logs / (name + '.log')).read_text().splitlines()
        context = json.loads(next(line.removeprefix('RUNNER_CONTEXT=')
                                  for line in lines if line.startswith('RUNNER_CONTEXT=')))
        self.assertEqual(context['TWILIGHT_NATIVE_TEST_KEYS'], explicit)
        self.assertEqual(summary['native_fixture_scopes'][name]['scope_origin'], 'explicit')
        self.assertNotIn('cases', summary['native_fixture_scopes'][name])

    def test_invalid_native_scope_cannot_run_controlled_child(self):
        name = self.prepare_native_fixture()
        process, summary = self.run_case(extra_env={'TWILIGHT_NATIVE_TEST_KEYS': 'transform:399'})
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual(summary['failed'], [name])
        self.assertEqual(summary['passed'], 3)
        self.assertEqual(summary['skipped'], [])
        log = (self.logs / (name + '.log')).read_text()
        self.assertIn('TEST_FIXTURE_FAILED', log)
        self.assertNotIn('RUNNER_CONTEXT=', log)

    def test_explicit_native_summary_cannot_claim_a_different_scope(self):
        name = self.prepare_native_fixture()
        output = ('PR122_NATIVE_PLAYER_CONNECTION_PASS actors=1 clips=8 native_phases=48 '
                  'position_collision_class_combat_sequence_preserved=true engine=4.7.2 '
                  'production_catalog_switches=0 approvals_added=0\n')
        process, summary = self.run_case(output=output,
            extra_env={'TWILIGHT_NATIVE_TEST_KEYS': 'transform:413,transform:130'})
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual(summary['failed'], [name])
        self.assertEqual(summary['native_fixture_scopes'][name]['keys'], ['transform:413', 'transform:130'])

    def test_injected_main_summary_must_name_the_selected_actor(self):
        name = self.prepare_native_fixture('pr122_native_main_connection_test')
        output = ('PR122_NATIVE_MAIN_PASS key=transform:393 native_clips=48 directional_cases=40 '
                  'plus_death=true authoritative_clock_inventory_collision_preserved=true '
                  'catalog_replacements=0 approvals_added=0\n')
        process, summary = self.run_case(output=output,
            extra_env={'TWILIGHT_NATIVE_MAIN_KEY': 'transform:267'})
        self.assertNotEqual(process.returncode, 0)
        self.assertEqual(summary['failed'], [name])
        self.assertEqual(summary['native_fixture_scopes'][name]['keys'], ['transform:267'])

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


if __name__ == '__main__':
    unittest.main(verbosity=2)
