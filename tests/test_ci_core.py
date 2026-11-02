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

SPEC = importlib.util.spec_from_file_location('ci_core', Path(__file__).parents[1]/'tools/ci_core.py')
CORE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(CORE)

class CoreStageTest(unittest.TestCase):
    def fixture(self, root):
        files = {
            'project.godot':'config_version=5\n',
            'Main.tscn':'[ext_resource type="Texture2D" path="res://assets/live.png"]\n[ext_resource path="res://docs/runtime.txt"]\n',
            'scripts/main.gd':'const DATA = "res://data/live.json"\n',
            'data/live.json':'{"frames":"res://assets/live.tres"}',
            'data/unused-review.json':'{"review":"res://assets/review.png"}',
            'assets/live.tres':'[ext_resource type="Texture2D" path="res://assets/pose.png"]\n',
            'assets/live.png':'opaque test byte fixture, never game art',
            'assets/pose.png':'second immutable test byte fixture',
            'assets/review.png':'unused review fixture',
            'docs/runtime.txt':'runtime-linked document fixture',
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
            self.assertNotIn('assets/review.png',selected)
            self.assertEqual((root/'assets/pose.png').read_bytes(),(Path(temporary)/'stage/assets/pose.png').read_bytes())

    def test_missing_scene_dependency_fails_before_staging(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)/'repo';root.mkdir();self.fixture(root)
            (root/'Main.tscn').write_text('[ext_resource path="res://assets/not-committed.png"]')
            with self.assertRaises(FileNotFoundError):CORE.stage(root,Path(temporary)/'stage')
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
