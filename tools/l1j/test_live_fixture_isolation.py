"""Regression: synthetic CI generation must preserve shipped original images."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

class FixtureIsolation(unittest.TestCase):
    def test_preserves_originals_and_rebinds_only_fixture_manifest(self):
        project=Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            manifest=json.loads((project/'data/l1j/live_visual_bindings.json').read_text())
            path=root/'data/l1j/live_visual_bindings.json'
            path.parent.mkdir(parents=True);path.write_text(json.dumps(manifest))
            fields=[('items',['inventory_texture','ground_texture']),('monsters',['texture'])]
            originals={}
            for section,keys in fields:
                for row in manifest[section]:
                    for key in keys:
                        dest=root/row[key].removeprefix('res://')
                        dest.parent.mkdir(parents=True,exist_ok=True)
                        dest.write_bytes(b'preserved original')
                        originals[dest]=dest.read_bytes()
            subprocess.run([sys.executable,str(project/'tools/l1j/make_live_fixture.py'),'--root',str(root)],check=True,capture_output=True)
            for original,data in originals.items():self.assertEqual(original.read_bytes(),data)
            updated=json.loads(path.read_text());self.assertTrue(updated['synthetic_fixture_only'])
            for section,keys in fields:
                for row in updated[section]:
                    for key in keys:
                        self.assertIn('/_ci_fixture/',row[key])
                        self.assertTrue((root/row[key].removeprefix('res://')).is_file())
if __name__=='__main__':unittest.main()
