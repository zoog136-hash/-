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

    def test_current_map_roster_and_classes_import_without_inactive_actor_banks(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'repo';root.mkdir();self.fixture(root)
            live='assets/actors/eight_direction/current/SpriteFrames.tres'
            inactive='assets/actors/eight_direction/inactive/SpriteFrames.tres'
            records={
                'data/maps/source_map_runtime.json':{'maps':{'aden_world':{'gameplay_snapshot':'res://data/maps/current.json'}}},
                'data/maps/current.json':{'gameplay':{'monster_spawn':[{'monster_types':['Scout']}]}},
                'data/game_db_v17.json':{'몬스터':[{'name':'Scout'}]},
                'data/combat_animation_profiles.json':{'profiles':{'class:0':{'frames_path':'res://'+live},'monster:Scout':{'frames_path':'res://'+live},'monster:Inactive':{'frames_path':'res://'+inactive}}},
            }
            for name,value in records.items():
                p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(value))
            (root/'scripts/main.gd').write_text('const DATA="res://data/combat_animation_profiles.json"')
            for path in [live,inactive]:
                p=root/path;p.parent.mkdir(parents=True,exist_ok=True)
                image=str(p.parent.relative_to(root))+'/idle.png'
                p.write_text('[gd_resource type="SpriteFrames" format=3]\n[ext_resource type="Texture2D" path="res://'+image+'"]\n')
                (root/image).write_bytes(b'unchanged fixture pixels')
            result=CORE.stage(root,Path(temporary)/'stage')
            selected={row['path'] for row in result['files']}
            self.assertTrue({live,live.replace('SpriteFrames.tres','idle.png')} <= selected)
            self.assertNotIn(inactive,selected)
            self.assertEqual(result['current_actor_scope']['monster_names'],['Scout'])
            self.assertIn(inactive,{row['path'] for row in result['deferred_actor_imports']})
            self.assertEqual((root/'data/combat_animation_profiles.json').read_bytes(),(Path(temporary)/'stage/data/combat_animation_profiles.json').read_bytes())

    def test_missing_scene_dependency_fails_before_staging(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'repo';root.mkdir();self.fixture(root)
            (root/'Main.tscn').write_text('[ext_resource path="res://assets/not-committed.png"]')
            with self.assertRaises(FileNotFoundError):CORE.stage(root,Path(temporary)/'stage')
            self.assertFalse((Path(temporary)/'stage').exists())

    def test_missing_shader_preload_fails_before_engine_import(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'repo';root.mkdir();self.fixture(root)
            (root/'scripts/main.gd').write_text('const SHADER = preload("res://shaders/missing.gdshader")')
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
