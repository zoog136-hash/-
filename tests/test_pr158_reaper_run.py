"""Keep the inherited reaper core intact when installing genuine RUN tracks."""
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from compose_pr122_inherited_reaper import parse_frames
import import_original_based_motion as importer


class ReaperRun(unittest.TestCase):
    def test_core_and_actual_binding(self):
        folder = ROOT / 'assets/actors/eight_direction/original_based'
        old = parse_frames((folder / 'reaper_male/SpriteFrames.tres').read_text())
        new = parse_frames((folder / 'reaper_male_run/r006/SpriteFrames.tres').read_text())
        for prior, current in zip(old, new):
            for key, value in prior.items():
                self.assertEqual(value, current[key], key)
        self.assertEqual(set(new[2]) - set(old[2]), {f'run_{i}' for i in range(8)})
        catalog = json.loads((ROOT / 'data/catalog_v19.json').read_text())
        actor = next(r for r in catalog['변신'] if str(r.get('sourceId')) == '258')
        self.assertEqual(actor['animation_profile']['frames_path'],
                         'res://assets/actors/eight_direction/original_based/reaper_male_run/r006/SpriteFrames.tres')
        self.assertEqual(set(actor['animation_profile']), {'frames_path', 'movement_fps'})

    def test_whole_source_extraction(self):
        folder = ROOT / 'assets/actors/eight_direction/original_based/reaper_male_run/r006'
        for direction in importer.DIRECTIONS:
            with self.subTest(direction=direction):
                source = folder / f'{direction}-run.png'
                geometry = importer.analyze(source, rows_count=6,
                    reference_rows=list(range(6)), canvas_size=2048,
                    directions=[direction], directions_axis='phase_grid2')
                importer.require_complete_pose_regions(source, geometry)
                self.assertEqual(geometry['distinct_pixel_frames'], 6)


if __name__ == '__main__':
    unittest.main()
