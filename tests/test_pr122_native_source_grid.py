"""Explicit authored grids preserve whole poses without changing default layouts."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from PIL import Image, ImageDraw
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import import_original_based_motion as importer
import pr122_reviewed_runtime_layout as layout
import stage_pr122_native_locomotion as stage
import numpy as np
import pr122_reviewed_source_regions as regions

class NativeSourceGridTest(unittest.TestCase):
    def fixture(self, root, columns):
        image = Image.new('RGBA', (columns * 160, (6 // columns) * 160))
        draw = ImageDraw.Draw(image)
        for i in range(6):
            x, y = i % columns * 160, i // columns * 160
            draw.rectangle((x+40, y+30, x+120, y+125+i), fill=(40+i*20, 70, 100, 255))
        path = root / 'source.png'
        image.save(path)
        geometry = importer.analyze(path, rows_count=6, reference_rows=[0, 3], directions_axis=f'phase_grid{columns}', canvas_size=1024, directions=['S'])
        importer.require_complete_pose_regions(path, geometry)
        path.with_suffix('.geometry.json').write_text(json.dumps(geometry))
        review = dict(status='REVIEWED_LAYOUT_PROPOSAL', review_basis='Exact test source layout', source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), canvas_size=1024, direction='S')
        return path, geometry, review

    def test_legacy_default_is_identical(self):
        with tempfile.TemporaryDirectory() as folder:
            path, base, review = self.fixture(Path(folder), 2)
            derived, _ = layout.apply_reviewed_layout(path, base, review)
            self.assertEqual(derived, base)

    def test_declared_three_column_source_keeps_whole_rgba_regions(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            path, base, review = self.fixture(root, 3)
            review['directions_axis'] = 'phase_grid3'
            derived, _ = layout.apply_reviewed_layout(path, base, review)
            self.assertEqual(derived, base)
            record = dict(sha256=review['source_sha256'], directions_axis='phase_grid3', geometry=dict(canvas=1024))
            checked, _ = stage._analyze_source_geometry(path, record, dict(reviewed_runtime_layouts={'source.png':review}), 'source.png', 'S')
            self.assertEqual(checked, base)

    def test_mismatched_source_and_layout_grid_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            path, _, review = self.fixture(Path(folder), 3)
            record = dict(sha256=review['source_sha256'], directions_axis='phase_grid3', geometry=dict(canvas=1024))
            with self.assertRaisesRegex(ValueError, 'phase grids differ'):
                stage._analyze_source_geometry(path, record, dict(reviewed_runtime_layouts={'source.png':review}), 'source.png', 'S')

    def test_both_grids_expand_only_owned_detached_original_pixels(self):
        for columns in (2, 3):
            with tempfile.TemporaryDirectory() as folder:
                path, _, review = self.fixture(Path(folder), columns)
                image = Image.open(path).convert('RGBA')
                ImageDraw.Draw(image).rectangle((130, 70, 132, 72), fill=(90, 80, 70, 255))
                image.save(path)
                base = importer.analyze(path, rows_count=6, reference_rows=[0, 3], directions_axis=f'phase_grid{columns}', canvas_size=1024, directions=['S'])
                with self.assertRaisesRegex(ValueError, 'outside pose regions'):
                    importer.require_complete_pose_regions(path, base)
                _, owner = regions._foreground_owners(np.asarray(image)[:, :, 3], base['frames'])
                rects = [list(f['region']) for f in base['frames']]
                rects[0][2] = 133 - rects[0][0]
                region_review = dict(status=regions.STATUS, source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), base_geometry_sha256=regions._digest(base), direction='S', review_basis='Explicit detached-pixel ownership fixture', regions=rects, nearest_owner_sha256=owner['nearest_owner_sha256'], directions_axis=f'phase_grid{columns}')
                expanded, proof = regions.apply_reviewed_regions(path, base, region_review)
                self.assertGreater(expanded['frames'][0]['region'][2], base['frames'][0]['region'][2])
                importer.require_complete_pose_regions(path, expanded)
                review.update(source_sha256=region_review['source_sha256'], directions_axis=f'phase_grid{columns}')
                derived, _ = layout.apply_reviewed_layout(path, expanded, review, source_region_review=region_review)
                self.assertEqual(derived, expanded)
                region_review['directions_axis'] = 'phase_grid2' if columns == 3 else 'phase_grid3'
                with self.assertRaisesRegex(ValueError, 'phase grids differ'):
                    layout.apply_reviewed_layout(path, expanded, review, source_region_review=region_review)


    def test_unknown_grid_cannot_bypass_canonical_checks(self):
        with tempfile.TemporaryDirectory() as folder:
            path, base, review = self.fixture(Path(folder), 3)
            review['directions_axis'] = 'automatic'
            with self.assertRaisesRegex(ValueError, 'explicit phase grid'):
                layout.apply_reviewed_layout(path, base, review)

if __name__ == '__main__':
    unittest.main()
