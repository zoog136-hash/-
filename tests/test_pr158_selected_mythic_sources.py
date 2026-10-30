"""The source ledger must identify the art actually selected by SpriteFrames."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SelectedMythicSources(unittest.TestCase):
    def test_current_tracks_have_one_exact_source_selection(self):
        manifest = json.loads((ROOT / 'docs/remake/evidence/pr122-mythic-detailed/batch01/source-manifest.json').read_text())
        register = json.loads((ROOT / 'data/pr122_native_locomotion_staging.json').read_text())
        tables = [manifest['selected_locomotion_sheets'], manifest['selected_detailed_action_sheets']]
        raws = {(r.get('key'), r.get('direction'), r.get('role'), r.get('source')): r for r in manifest['raw_images']}
        for key, actor in register['actors'].items():
            if actor.get('grade') != '신화':
                continue
            for track in actor['tracks']:
                slot = ':'.join((key, track['direction'], track['role']))
                with self.subTest(slot=slot):
                    self.assertEqual([t[slot] for t in tables if slot in t], [track['source']])
                    table = tables[0 if track['role'] in ('idle', 'walk', 'run') else 1]
                    self.assertEqual(table[slot], track['source'])
                    raw = raws[(key, track['direction'], track['role'], track['source'])]
                    self.assertEqual(raw['sha256'], track['source_sha256'])
                    self.assertEqual(raw['geometry']['status'], 'GEOMETRY_PASS')
                    self.assertEqual(hashlib.sha256((ROOT / track['texture'].removeprefix('res://')).read_bytes()).hexdigest(), raw['sha256'])


if __name__ == '__main__':
    unittest.main()
