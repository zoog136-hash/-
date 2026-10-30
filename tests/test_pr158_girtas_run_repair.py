"""Bound the live Girtas repair to its two confirmed airborne poses."""
import hashlib
import json
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from compose_pr122_inherited_reaper import parse_frames
import import_original_based_motion as importer


class GirtasRunRepair(unittest.TestCase):
    def test_original_tracks_and_combat_contract_preserved(self):
        base = ROOT / 'assets/actors/eight_direction/native_production/girtas_267'
        old_tex, old_atlas, old_anim = parse_frames((base / 'r001/SpriteFrames.tres').read_text())
        new_tex, new_atlas, new_anim = parse_frames((base / 'r002/SpriteFrames.tres').read_text())
        self.assertEqual(old_anim, new_anim)
        self.assertEqual(len(new_anim), 48)
        for key, value in old_atlas.items():
            if not key.startswith('track_16_'):
                self.assertEqual(value, new_atlas[key])
        for key, value in old_tex.items():
            if key != '17':
                self.assertEqual(value, new_tex[key])
        old_profile = (base / 'r001/NativeMotionProfile.tres').read_text()
        new_profile = (base / 'r002/NativeMotionProfile.tres').read_text()
        self.assertEqual(old_profile.replace('/r001/', '/r002/').replace(
            'twilight_detailed_completed = true', 'twilight_detailed_completed = false'), new_profile)
        for phase in (0, 1, 3, 4):
            key = f'track_16_{phase}'
            self.assertEqual(old_atlas[key]['margin'], new_atlas[key]['margin'])
            pixels = []
            for tex, atlas in ((old_tex, old_atlas), (new_tex, new_atlas)):
                frame = atlas[key]
                image = Image.open(ROOT / tex[frame['texture']]['path'].removeprefix('res://')).convert('RGBA')
                x, y, w, h = frame['region']
                pixels.append(image.crop((x, y, x + w, y + h)).tobytes())
            self.assertEqual(*pixels)

    def test_complete_source_and_actual_default_binding(self):
        register = json.loads((ROOT / 'data/pr122_native_locomotion_staging.json').read_text())
        actor = register['actors']['transform:267']
        track = next(t for t in actor['tracks'] if (t['direction'], t['role']) == ('NE', 'run'))
        source = ROOT / track['source']
        self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), track['source_sha256'])
        geometry = importer.analyze(source, rows_count=6, reference_rows=list(range(6)),
                                    directions_axis='phase_grid2', canvas_size=2048, directions=['NE'])
        importer.require_complete_pose_regions(source, geometry)
        importer.require_complete_pose_regions(source, track['geometry'])
        catalog = json.loads((ROOT / 'data/catalog_v19.json').read_text())
        record = next(r for r in catalog['변신'] if str(r.get('sourceId')) == '267')
        self.assertEqual(record['animation_profile']['frames_path'], actor['frames'])
        self.assertIn('/r002/', actor['frames'])
        # A local RUN repair must not silently reinstate whole-actor approval.
        self.assertFalse(actor['detailed_completed'])
        self.assertEqual(actor['status'], 'PRODUCTION_QUALITY_REGRESSION')


if __name__ == '__main__':
    unittest.main()
