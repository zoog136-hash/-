"""Staging preserves inputs and rejects missing/escaping required resources."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
import contextlib
import io
import os
import sys
import json

SPEC = importlib.util.spec_from_file_location('ci_core', Path(__file__).parents[1]/'tools/ci_core.py')
CORE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CORE)

class CoreStageTest(unittest.TestCase):
    def test_current_source_placement_identities_join_actor_scope(self):
        files = {
            'data/maps/source_map_runtime.json': {'maps':{'aden_world':{'gameplay_snapshot':'res://data/current.json'}}},
            'data/current.json': {'gameplay':{'monster_spawn':[{'monster_types':['Authored']}] }},
            'data/combat_animation_profiles.json': {'profiles':{}},
            'data/game_db_v17.json': {'몬스터':[]},
            'data/monsters/source3_map_spawns.json': {'rows':[{'map_id':'aden_world','game_source_id':'source:current'}, {'map_id':'other','game_source_id':'source:other'}]},
            'data/monsters/reviewed_source_monsters.json': {'records':[
                {'sourceId':'source:current','name':'Current NPC','source_portrait':'res://assets/monsters/reviewed_source/current/portrait.png'},
                {'sourceId':'source:other','name':'Other NPC','source_portrait':'res://assets/monsters/reviewed_source/other/portrait.png'}]},
        }
        result=CORE.current_actor_scope(lambda p:json.dumps(files[p]).encode(), lambda p:p in files)
        self.assertIn('assets/monsters/reviewed_source/current/portrait.png',result['paths'])
        self.assertNotIn('assets/monsters/reviewed_source/other/portrait.png',result['paths'])
        self.assertIn('Current NPC',result['monster_names'])

    def fixture(self, root):
        files = {
            'project.godot':'config_version=5\n',
            'Main.tscn':'[ext_resource type="Texture2D" path="res://assets/live.png"]\n[ext_resource path="res://docs/runtime.txt"]\n',
            'scripts/main.gd':'const DATA = "res://data/live.json"\nconst FLAGS = "res://data/pr122_transform_motion_scope.json"\nconst SHADER = preload("res://shaders/live.gdshader")\n',
            'shaders/live.gdshader':'shader_type canvas_item;\n',
            'data/live.json':'{"frames":"res://assets/live.tres"}',
            'data/unused-review.json':'{"review":"res://assets/review.png"}',
            'data/pr122_transform_motion_scope.json':'{"schema":"pr122-transform-motion-scope-v1","actor_kind":"transform","review":"res://data/unused-review.json"}',
            'assets/live.tres':'[gd_resource type="SpriteFrames" format=3]\n[ext_resource type="Texture2D" path="res://assets/pose.png"]\n[resource]\nmetadata/review="res://data/unused-review.json"\n',
            'assets/live.png':'opaque test byte fixture, never game art',
            'assets/pose.png':'second immutable test byte fixture',
            'assets/review.png':'unused review fixture',
            'docs/runtime.txt':'runtime-linked document fixture',
            'addons/production/plugin.gd':'extends EditorPlugin\n',
            'tests/qa_class_selection.gd':'extends RefCounted\n',
        }
        files.update({'tests/'+name+'.gd':'extends SceneTree\n' for name,_ in CORE.CHECKS})
        for path,data in files.items():
            p=root/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(data)
        subprocess.run(['git','init','-q',str(root)],check=True)
        subprocess.run(['git','-C',str(root),'add','.'],check=True)
        subprocess.run(['git','-C',str(root),'-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-qm','fixture'],check=True)

    def test_reachable_inputs_preserved_without_unused_review_art(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'repo';root.mkdir();self.fixture(root)
            result=CORE.stage(root,Path(temporary)/'stage')
            selected={r['path'] for r in result['files']}
            self.assertTrue({'assets/live.png','assets/live.tres','assets/pose.png'}<=selected)
            self.assertIn('docs/runtime.txt',selected)
            self.assertIn('addons/production/plugin.gd',selected)
            self.assertIn('shaders/live.gdshader',selected)
            self.assertNotIn('assets/review.png',selected)
            self.assertEqual((root/'data/pr122_transform_motion_scope.json').read_bytes(),(Path(temporary)/'stage/data/pr122_transform_motion_scope.json').read_bytes())
            self.assertEqual((root/'assets/pose.png').read_bytes(),(Path(temporary)/'stage/assets/pose.png').read_bytes())

    def test_linux_import_profile_never_edits_production_settings(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'repo';root.mkdir();self.fixture(root)
            original='config_version=5\n[rendering]\ntextures/vram_compression/import_etc2_astc=true\n'
            (root/'project.godot').write_text(original)
            result=CORE.stage(root,Path(temporary)/'stage')
            self.assertEqual((root/'project.godot').read_text(),original)
            self.assertIn('import_etc2_astc=false',(Path(temporary)/'stage/project.godot').read_text())
            self.assertEqual(len(result['validation_overrides']),1)

    def test_current_map_appended_source_ids_include_real_art(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'repo';root.mkdir();self.fixture(root)
            inputs={
                'data/maps/source_map_runtime.json': {'maps':{'aden_world':{'gameplay_snapshot':'res://data/maps/current.json'}}},
                'data/maps/current.json': {'gameplay':{'monster_spawn':[]}},
                'data/game_db_v17.json': {'몬스터':[]},
                'data/combat_animation_profiles.json': {'profiles':{}},
                'data/monsters/source3_map_spawns.json': {'rows':[{'map_id':'aden_world','game_source_id':'source:1'},{'map_id':'another','game_source_id':'source:2'}]},
                'data/monsters/reviewed_source_monsters.json': {'records':[{'sourceId':'source:1','source_portrait':'res://assets/monsters/reviewed_source/current/portrait.png','animation_profile':{'frames_path':'res://assets/monsters/reviewed_source/current/frames.tres'}},{'sourceId':'source:2','source_portrait':'res://assets/unused.png'}]},
            }
            for path,value in inputs.items():
                p=root/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value))
            scope=CORE.current_actor_scope(lambda p:(root/p).read_bytes(),lambda p:(root/p).is_file())
            self.assertEqual(scope['source_spawn_ids'],['source:1'])
            self.assertIn('assets/monsters/reviewed_source/current/portrait.png',scope['paths'])
            self.assertIn('assets/monsters/reviewed_source/current/frames.tres',scope['paths'])
            self.assertNotIn('assets/unused.png',scope['paths'])

    def test_current_map_roster_and_classes_import_without_inactive_actor_banks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'repo';root.mkdir();self.fixture(root)
            live='assets/actors/eight_direction/current/SpriteFrames.tres'
            inactive='assets/actors/eight_direction/inactive/SpriteFrames.tres'
            records={
                'data/maps/source_map_runtime.json':{'maps':{'aden_world':{'gameplay_snapshot':'res://data/maps/current.json','grid_sha256':'current-grid','layout_revision':7}}},
                'data/maps/current.json':{'gameplay':{'monster_spawn':[{'monster_types':['Scout']}]}},
                'data/game_db_v17.json':{'몬스터':[{'name':'Scout'}]},
                'data/monsters/reviewed_source_monsters.json':{'records':[{'name':'Appended','source_portrait':'res://assets/monsters/reviewed_source/current-extra/portrait.png'}]},
                'data/monsters/source3_map_spawns.json':{'rows':[{'map_id':'aden_world','grid_sha256':'current-grid','layout_revision':7,'name':'Appended'}, {'map_id':'aden_world','grid_sha256':'old-grid','layout_revision':7,'name':'Inactive'}]},
                'data/monsters/local_source_habitats.json':{'rows':[{'map_id':'other-map','grid_sha256':'current-grid','layout_revision':7,'monster_types':['Inactive']}]},
                'data/combat_animation_profiles.json':{'profiles':{'class:0':{'frames_path':'res://'+live},'monster:Scout':{'frames_path':'res://'+live},'monster:Inactive':{'frames_path':'res://'+inactive}}},
            }
            for name,value in records.items():
                p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value))
            extra=root/'assets/monsters/reviewed_source/current-extra/portrait.png'
            extra.parent.mkdir(parents=True,exist_ok=True);extra.write_bytes(b'immutable current appended population fixture')
            (root/'scripts/main.gd').write_text('const DATA="res://data/combat_animation_profiles.json"\nconst DB="res://data/game_db_v17.json"\nconst REVIEWED="res://data/monsters/reviewed_source_monsters.json"')
            for path in [live,inactive]:
                p=root/path;p.parent.mkdir(parents=True,exist_ok=True)
                image=str(p.parent.relative_to(root))+'/idle.png'
                p.write_text('[gd_resource type="SpriteFrames" format=3]\n[ext_resource type="Texture2D" path="res://'+image+'"]\n')
                (root/image).write_bytes(b'unchanged fixture pixels')
            result=CORE.stage(root,Path(temporary)/'stage')
            selected={row['path'] for row in result['files']}
            self.assertTrue({live,live.replace('SpriteFrames.tres','idle.png')} <= selected)
            self.assertNotIn(inactive,selected)
            self.assertEqual(result['current_actor_scope']['monster_names'],['Appended','Scout'])
            self.assertIn(str(extra.relative_to(root)),selected)
            self.assertIn(inactive,{row['path'] for row in result['deferred_actor_imports']})
            self.assertEqual((root/'data/combat_animation_profiles.json').read_bytes(),(Path(temporary)/'stage/data/combat_animation_profiles.json').read_bytes())

    def test_missing_scene_dependency_fails_before_staging(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'repo';root.mkdir();self.fixture(root)
            (root/'Main.tscn').write_text('[ext_resource path="res://assets/not-committed.png"]')
            with self.assertRaises(FileNotFoundError):CORE.stage(root,Path(temporary)/'stage')
            self.assertFalse((Path(temporary)/'stage').exists())

    def test_current_source_spawn_portraits_and_animation_are_in_scope(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'repo';root.mkdir();self.fixture(root)
            live='assets/monsters/reviewed_source/source-live/'
            inactive='assets/monsters/reviewed_source/source-stale/'
            records={
                'data/maps/source_map_runtime.json':{'maps':{'aden_world':{'gameplay_snapshot':'res://data/maps/current.json','grid_sha256':'pinned-grid','layout_revision':523}}},
                'data/maps/current.json':{'gameplay':{'monster_spawn':[]}},
                'data/monsters/source3_map_spawns.json':{'rows':[
                    {'map_id':'aden_world','grid_sha256':'pinned-grid','layout_revision':523,'name':'Live','game_source_id':'source-live'},
                    {'map_id':'aden_world','grid_sha256':'stale-grid','layout_revision':523,'name':'Stale','game_source_id':'source-stale'}]},
                'data/game_db_v17.json':{'몬스터':[]},
                'data/combat_animation_profiles.json':{'profiles':{}},
                'data/monsters/reviewed_source_monsters.json':{'records':[
                    {'name':'Live','sourceId':'source-live','source_portrait':'res://'+live+'portrait.png','animation_profile':{'frames_path':'res://'+live+'frames.tres'}},
                    {'name':'Stale','sourceId':'source-stale','source_portrait':'res://'+inactive+'portrait.png','animation_profile':{'frames_path':'res://'+inactive+'frames.tres'}}]},
            }
            for name,value in records.items():
                p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value))
            for prefix in [live,inactive]:
                p=root/(prefix+'frames.tres');p.parent.mkdir(parents=True,exist_ok=True)
                p.write_text('[gd_resource type="SpriteFrames" format=3]\n[ext_resource type="Texture2D" path="res://'+prefix+'idle.png"]\n')
                for image in ['portrait.png','idle.png']:(root/(prefix+image)).write_bytes(b'unchanged fixture art')
            # Production code resolves these catalogs dynamically.
            (root/'scripts/main.gd').write_text('const SOURCES="res://data/monsters/reviewed_source_monsters.json"')
            result=CORE.stage(root,Path(temporary)/'stage')
            selected={row['path'] for row in result['files']}
            self.assertTrue({live+'portrait.png',live+'frames.tres',live+'idle.png'}<=selected)
            self.assertNotIn(inactive+'portrait.png',selected)
            self.assertEqual(result['current_actor_scope']['monster_names'],['Live'])

    def test_missing_shader_preload_fails_before_engine_import(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'repo';root.mkdir();self.fixture(root)
            for source in [
                    'const SHADER = preload("res://shaders/missing.gdshader")',
                    "const SHADER = preload('res://shaders/missing.gdshader')",
                    'const SHADER = preload(\n  "res://shaders/missing.gdshader"\n)',
                    "const SHADER = preload (\n  'res://shaders/missing.gdshader'\n)"]:
                with self.subTest(source=source):
                    (root/'scripts/main.gd').write_text(source)
                    with self.assertRaisesRegex(FileNotFoundError,'shaders/missing.gdshader'):
                        CORE.stage(root,Path(temporary)/'stage')
                    self.assertFalse((Path(temporary)/'stage').exists())

    def test_escape_and_existing_project_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'repo';root.mkdir();self.fixture(root)
            (root/'scripts/main.gd').write_text('const BAD = "res://assets/../../other.png"')
            with self.assertRaises(ValueError):CORE.stage(root,Path(temporary)/'stage')
            existing=Path(temporary)/'existing';existing.mkdir();(existing/'save.json').write_text('keep')
            with self.assertRaises(ValueError):CORE.stage(root,existing)
            self.assertEqual((existing/'save.json').read_text(),'keep')

    def test_zero_exit_without_completion_or_with_engine_error_fails(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            for output in ['ERROR: controlled negative fixture', 'exited without running the test']:
                with self.subTest(output=output), contextlib.redirect_stdout(io.StringIO()):
                    with self.assertRaises(RuntimeError):
                        CORE.run([sys.executable,'-c','print('+repr(output)+')'],root,root/'log.txt',os.environ.copy(),5,'DONE')

if __name__=='__main__':unittest.main()
