"""Runner/sharding contract tests using controlled executables, NOT Godot/game PASS."""
from __future__ import annotations
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from test_project_support import select_checks, PREPARATION


def checks(count=246):
    return [(n, []) for n in PREPARATION] + [(f'case_{i:03}_test', ['--script', str(i)]) for i in range(count)]


class SelectionTests(unittest.TestCase):
    def test_default_preserved(self):
        source=checks(); selected,_=select_checks(source)
        self.assertEqual(selected, source)
    def test_every_test_exactly_once(self):
        for count in (1,2,4,8):
            source=checks(); seen=[]
            for index in range(count):
                selected,plan=select_checks(source,shard_index=index,shard_count=count)
                self.assertEqual([n for n,_ in selected[:3]],list(PREPARATION))
                self.assertEqual(plan['discovered_tests'],[n for n,_ in source[3:]])
                seen += plan['selected_tests']
            self.assertEqual(sorted(seen), [n for n,_ in source[3:]])
            self.assertEqual(len(seen),len(set(seen)))
    def test_invalid_count(self):
        for count in (-1,0):
            with self.assertRaises(ValueError):select_checks(checks(),shard_count=count)
    def test_invalid_index(self):
        for index in (-1,4):
            with self.assertRaises(ValueError):select_checks(checks(),shard_count=4,shard_index=index)
    def test_empty_shard_rejected(self):
        with self.assertRaises(ValueError):select_checks(checks(1),shard_index=3,shard_count=4)
    def test_no_runtime_rejected_for_audit(self):
        with self.assertRaises(ValueError):select_checks(checks(0),shard_count=4)
    def test_only_keeps_original_order(self):
        selected,_=select_checks(checks(3),'case_002_test,boot,case_000_test')
        self.assertEqual([n for n,_ in selected],['boot','case_000_test','case_002_test'])
    def test_only_unknown_rejected(self):
        with self.assertRaises(ValueError):select_checks(checks(),'unknown')
    def test_only_and_shard_rejected(self):
        with self.assertRaises(ValueError):select_checks(checks(),'boot',0,4)
    def test_duplicate_names_rejected(self):
        with self.assertRaises(ValueError):select_checks(checks()+[('boot',[])])
    def test_preparation_order_required(self):
        with self.assertRaises(ValueError):select_checks(checks()[1:])
    def test_input_unchanged(self):
        source=checks(5); before=[(n,list(a)) for n,a in source]
        select_checks(source,shard_index=1,shard_count=2)
        self.assertEqual(source,before)
    def test_deterministic(self):
        self.assertEqual(select_checks(checks(),shard_index=2,shard_count=4),select_checks(checks(),shard_index=2,shard_count=4))
    def test_new_discovery_not_omitted(self):
        source=checks()+[('newly_added_test',[])]
        seen=[n for i in range(4) for n,_ in select_checks(source,shard_index=i,shard_count=4)[0][3:]]
        self.assertIn('newly_added_test',seen)


@unittest.skipUnless(os.name=='posix','controlled executable uses POSIX shebang')
class RunnerContractTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name)
        for d in ['tools','tests']:(self.root/d).mkdir()
        for name in ['test_project.py','test_project_support.py']:
            shutil.copy2(Path(__file__).with_name(name),self.root/'tools'/name)
        self.engine=self.root/'controlled_engine'
        self.engine.write_text(f'''#!{sys.executable}
import json,os,pathlib,sys
print('ARGS='+json.dumps(sys.argv[1:]),flush=True)
print('ENV='+json.dumps({{k:os.environ.get(k) for k in ['XDG_DATA_HOME','APPDATA','LOCALAPPDATA','TWILIGHT_PR100_REPORT','TWILIGHT_PR100_BATCH_ISOLATED','TWILIGHT_PR100_BATCH_REPORT']}}),flush=True)
if '--import' in sys.argv:
    if os.environ.get('CONTROL_IMPORT_FAIL')=='1': print('ERROR: controlled import failure');sys.exit(1)
elif any('bake_hunting_navigation.gd' in x for x in sys.argv):
    folder=pathlib.Path('data/maps/navigation');folder.mkdir(parents=True,exist_ok=True)
    (folder/'fixture.nav').write_bytes(b'CONTROLLED, NOT GAME NAVIGATION')
    print('NAV_BAKE_OK 1')
elif '--script' in sys.argv:
    mode=os.environ.get('CONTROL_MODE','ok')
    if mode=='error': print('ERROR: controlled test error');sys.exit(1)
    elif mode=='skip': print('CONTROLLED_SKIP: private fixture absent')
    else: print('CONTROLLED_OK')
''')
        self.engine.chmod(0o755)
        (self.root/'tools/l1j_ci_make_fixture.py').write_text("raise RuntimeError('synthetic installer must not be invoked in installed-resource audit')\n")
        (self.root/'tools/world_region_shards.py').write_text("import sys\nprint('REGION_ARGS='+repr(sys.argv))\nprint('WORLD_REGIONS_OK')\n")
    def add(self,name,source='extends SceneTree\n'):
        (self.root/'tests'/(name+'.gd')).write_text(source)
    def run_checks(self,*arguments,extra_env=None):
        env=os.environ.copy();env['GITHUB_ACTIONS']='true';env['DISPLAY']='controlled-unit-display'
        env.pop('TWILIGHT_PR100_REPORT',None);env.pop('TWILIGHT_PR100_BATCH_REPORT',None)
        env.update(extra_env or {})
        p=subprocess.run([sys.executable,str(self.root/'tools/test_project.py'),
            '--godot',str(self.engine),'--logs',str(self.root/'logs'),
            '--no-ci-synthetic-fixtures',*arguments],cwd=self.root,env=env,text=True,capture_output=True,timeout=20)
        path=self.root/'logs/summary.json'
        return p,json.loads(path.read_text()) if path.exists() else None
    def log(self,name):return (self.root/'logs'/(name+'.log')).read_text()
    def test_installed_audit_does_not_install_fixtures(self):
        self.add('case_test');p,d=self.run_checks()
        self.assertEqual(p.returncode,0,p.stderr)
        self.assertEqual(d['synthetic_fixture_policy'],'DISABLED')
        self.assertEqual(d['passed'],4)
    def test_cli_shard_preserves_preparation_and_full_inventory(self):
        for i in range(8):self.add(f'case_{i}_test')
        p,d=self.run_checks('--shard-index','1','--shard-count','4')
        self.assertEqual(p.returncode,0,p.stderr)
        self.assertEqual(d['checks'],[*PREPARATION,'case_1_test','case_5_test'])
        self.assertEqual(len(d['plan']['discovered_tests']),8)
        self.assertEqual(d['selection'],'SHARDED_FULL_SUITE')
    def test_legacy_flag_preserved(self):
        self.add('field_world_test');p,d=self.run_checks()
        self.assertEqual(p.returncode,0,p.stderr)
        self.assertIn('--legacy-map-layouts',self.log('field_world_test'))
        self.assertEqual(d['validation_scopes']['field_world_test'],'EXISTING_TWILIGHT_GEOMETRY')
    def test_active_map_does_not_get_legacy_flag(self):
        self.add('aden_faith_png_monster_spawns_test');p,_=self.run_checks()
        self.assertEqual(p.returncode,0,p.stderr)
        self.assertNotIn('--legacy-map-layouts',self.log('aden_faith_png_monster_spawns_test'))
    def test_temporal_context_preserved(self):
        self.add('original_based_transform_temporal_main_test');p,_=self.run_checks()
        self.assertEqual(p.returncode,0,p.stderr)
        text=self.log('original_based_transform_temporal_main_test')
        self.assertIn('"TWILIGHT_PR100_BATCH_ISOLATED": "1"',text)
        self.assertIn('.batch.json',text);self.assertIn('.gameplay.json',text)
    def test_region_child_uses_existing_sharding(self):
        self.add('world_regions_test');p,_=self.run_checks()
        self.assertEqual(p.returncode,0,p.stderr)
        self.assertIn('--legacy-map-layouts',self.log('world_regions_test'))
        self.assertIn('REGION_ARGS=',self.log('world_regions_test'))
    def test_real_renderer_arguments_preserved(self):
        self.add('visual_test','await RenderingServer.frame_post_draw\n');p,_=self.run_checks()
        self.assertEqual(p.returncode,0,p.stderr)
        self.assertIn('opengl3',self.log('visual_test'))
    def test_optional_renderer_remains_optional(self):
        self.add('optional_test','# TWILIGHT_OPTIONAL_RENDER_ENV: TWILIGHT_PR100_REPORT\nawait RenderingServer.frame_post_draw\n')
        p,_=self.run_checks();self.assertEqual(p.returncode,0,p.stderr)
        self.assertIn('--headless',self.log('optional_test'))
    def test_failed_test_is_failure_not_omitted(self):
        self.add('case_test');p,d=self.run_checks(extra_env={'CONTROL_MODE':'error'})
        self.assertNotEqual(p.returncode,0);self.assertEqual(d['failed'],['case_test'])
        self.assertEqual(d['not_run'],[])
    def test_optional_skip_is_not_counted_as_pass(self):
        self.add('case_test');p,d=self.run_checks(extra_env={'CONTROL_MODE':'skip'})
        self.assertEqual(d['passed'],3);self.assertEqual(d['skipped'],['case_test'])
    def test_import_failure_records_all_unrun(self):
        self.add('case_test');p,d=self.run_checks(extra_env={'CONTROL_IMPORT_FAIL':'1'})
        self.assertNotEqual(p.returncode,0)
        self.assertEqual(d['not_run'],['bake_navigation','boot','case_test'])
    def test_each_check_has_isolated_save_directories(self):
        self.add('case_test');p,d=self.run_checks();self.assertEqual(p.returncode,0,p.stderr)
        homes=[]
        for name in d['checks']:
            row=json.loads(next(l[4:] for l in self.log(name).splitlines() if l.startswith('ENV=')))
            self.assertEqual(row['XDG_DATA_HOME'],row['APPDATA'])
            self.assertEqual(row['APPDATA'],row['LOCALAPPDATA']);homes.append(row['APPDATA'])
        self.assertEqual(len(homes),len(set(homes)))
    def test_bad_cli_stops_before_engine(self):
        self.add('case_test');p,d=self.run_checks('--shard-count','0')
        self.assertNotEqual(p.returncode,0);self.assertIsNone(d)
    def test_unknown_only_is_rejected(self):
        self.add('case_test');p,_=self.run_checks('--only','misspelled_test')
        self.assertNotEqual(p.returncode,0)
    def test_initial_and_final_summary_has_explicit_coverage(self):
        self.add('case_test');p,d=self.run_checks()
        self.assertEqual(p.returncode,0,p.stderr)
        self.assertEqual(d['plan']['selected_tests'],['case_test'])
        self.assertEqual(d['passed']+len(d['failed'])+len(d['skipped']),d['total'])
        self.assertEqual(d['not_run'],[])

if __name__=='__main__':unittest.main(verbosity=2)
