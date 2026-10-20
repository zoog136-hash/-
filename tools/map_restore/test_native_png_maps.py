"""Code regression fixtures are deliberately separate from original PNG tests."""
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

from build_native_png_maps import ROOT, build, compile_chunks, compile_layers, partition, transparent_runs


class LosslessPreparation(unittest.TestCase):
    def test_irregular_partition_is_exclusive_and_lossless(self):
        rng = np.random.default_rng(19)
        pixels = rng.integers(0, 256, (91, 177, 4), dtype=np.uint8)
        pixels[:5, :, 3] = 0
        image = Image.fromarray(pixels)
        pieces, proof = partition(image, [[[29, 0], [51, 43], [39, 91]], [[113, 0], [121, 91]]])
        self.assertTrue(proof['rgba_roundtrip'])
        self.assertEqual(sum(proof['region_pixels']), np.count_nonzero(pixels[:, :, 3]))
        self.assertEqual(len(set(proof['region_pixels'])), 3)
        for crop, box in pieces:
            self.assertEqual(crop.size, (box[2]-box[0], box[3]-box[1]))

    def test_invalid_crossing_cuts_are_rejected(self):
        with self.assertRaises(ValueError):
            partition(Image.new('RGBA', (50, 40), 'white'), [[[30, 0], [5, 40]], [[20, 0], [40, 40]]])

    def test_chunk_roundtrip_and_native_positions(self):
        pixels = np.random.default_rng(9).integers(0, 256, (139, 205, 4), dtype=np.uint8)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)/'map'
            rows = compile_chunks(Image.fromarray(pixels), [41, 69, 246, 208], root, 64)
            restored = np.zeros_like(pixels)
            for row in rows:
                with Image.open(root/row['file']) as crop:
                    x, y = np.asarray(row['position'])-[41, 69]
                    restored[y:y+crop.height, x:x+crop.width] = np.asarray(crop)
                self.assertLessEqual(max(row['size']), 64)
            np.testing.assert_array_equal(restored, pixels)

    def test_source_identity_precedes_image_processing(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root/'13474.png').write_bytes(b'not an original PNG')
            plan = root/'plan.json'
            plan.write_text(json.dumps({'sources': {'13474.png': {'sha256': '0'*64, 'bytes': 22}}}))
            with self.assertRaisesRegex(ValueError, 'identity mismatch'):
                build(root, plan, root/'output')
            self.assertFalse((root/'output/index.json').exists())

    def test_public_checkout_output_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'private directory'):
            build(Path('/missing'), Path('/missing'), ROOT/'assets/forbidden-originals')

    def test_visibility_guard_does_not_classify_opaque_colours_as_floor(self):
        pixels = np.zeros((32, 48, 4), dtype=np.uint8)
        pixels[:, :32, 3] = 255  # Opaque black is as visible as opaque white.
        pixels[:, 16:32, :3] = 255
        self.assertEqual(transparent_runs(Image.fromarray(pixels)), [[0, 2, 1], [1, 2, 1]])

    def test_foreground_retains_source_pixels_and_global_foot(self):
        pixels = np.random.default_rng(61).integers(0, 256, (70, 90, 4), dtype=np.uint8)
        pixels[:, :, 3] = 255
        cut = dict(id='statue', polygon_image=[[117, 239], [131, 229], [148, 244], [128, 262]],
                   foot_image=[129, 260], collision_correspondence='statue_foot')
        with tempfile.TemporaryDirectory() as tmp:
            ground, rows = compile_layers(Image.fromarray(pixels), [100, 220, 190, 290], [cut], Path(tmp))
            self.assertEqual(rows[0]['foot_image'], [129, 260])
            self.assertEqual(rows[0]['collision_correspondence'], 'statue_foot')
            with Image.open(Path(tmp)/rows[0]['file']) as foreground:
                x, y = np.asarray(rows[0]['position'])-[100, 220]
                rebuilt = np.asarray(ground).copy()
                target = rebuilt[y:y+foreground.height, x:x+foreground.width]
                selected = np.asarray(foreground)[:, :, 3] > 0
                self.assertTrue(np.all(target[selected, 3] == 0))
                target[selected] = np.asarray(foreground)[selected]
                np.testing.assert_array_equal(rebuilt, pixels)

    def test_plan_keeps_names_and_unknown_server_ids(self):
        plan = json.loads((ROOT/'data/maps/native_png_plan.json').read_text())
        self.assertEqual(plan['maps']['balrog_temple']['name'], '발록의 시전')
        self.assertEqual(plan['maps']['yahee_temple']['name'], '야히의신전')
        self.assertEqual(len(plan['maps']), 6)
        self.assertEqual([m for m in plan['maps'] if m.startswith('escaros')], ['escaros_world'])
        for source in plan['sources'].values():
            self.assertIsNone(source['server_map_id'])
            self.assertIsNone(source['collision_data_id'])

    def test_independent_pack_compiles_without_old_albino_source(self):
        # Deliberately synthetic CODE regression; never counted as real PNG QA.
        from build_native_png_maps import digest
        from verify_native_png_pack import verify
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root/'independent.png'
            Image.new('RGBA', (70, 50), (20, 80, 140, 255)).save(source)
            plan = root/'plan.json'
            plan.write_text(json.dumps({'sources': {'independent.png': {
                'sha256': digest(source), 'bytes': source.stat().st_size, 'size': [70, 50]}},
                'maps': {'independent': {'file': 'independent.png', 'collision_scope': 'CODE_FIXTURE'}}}))
            build(root, plan, root/'pack')
            report = verify(root/'pack', plan)
            self.assertEqual(report['maps'], 1)
            self.assertTrue(report['all_chunk_sha256_verified'])
            self.assertFalse((root/'13474.png').exists())

    def test_five_new_sources_reuse_persistent_ids_without_guessed_population(self):
        plan = json.loads((ROOT/'data/maps/aden_faith_png_plan.json').read_text())
        expected = {'aden_world': 'Aden.png', 'faith_01': '13398.png',
                    'faith_02': '13401.png', 'faith_03': '13417.png', 'faith_04': '13472.png'}
        self.assertEqual({mid: row['file'] for mid, row in plan['maps'].items()}, expected)
        historical = {row['id'] for row in json.loads((ROOT/'data/maps_v18.json').read_text())}
        self.assertTrue(set(expected) <= historical)
        self.assertEqual(len({s['sha256'] for s in plan['sources'].values()}), 5)
        for row in plan['sources'].values():
            self.assertIsNone(row['server_map_id'])
            self.assertIsNone(row['collision_data_id'])
        for row in plan['maps'].values():
            self.assertTrue(row['route_checks'] and row['blocked_probes'] and row['portals'])
            self.assertNotIn('monster_spawn', row)
            self.assertFalse(row['full_terrain_collision_verified'])

    def test_legacy_regeneration_preserves_private_png_configuration(self):
        with tempfile.TemporaryDirectory() as tmp:
            checkout = Path(tmp)
            for relative in ['tools/build_world_regions.py', 'data/game_db_v17.json',
                             'data/maps/field_index.json', 'data/maps/native_png_plan.json',
                             'data/maps/native_png_pack.json', 'data/maps/native_png_review.json',
                             'data/maps/aden_faith_png_plan.json', 'data/maps/aden_faith_png_pack.json']:
                target = checkout/relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT/relative, target)
            protected = {p: (checkout/p).read_bytes() for p in
                         ['data/maps/native_png_plan.json', 'data/maps/native_png_pack.json', 'data/maps/native_png_review.json',
                          'data/maps/aden_faith_png_plan.json', 'data/maps/aden_faith_png_pack.json']}
            for family in ['albino', 'escaros']:
                subprocess.run([sys.executable, str(checkout/'tools/build_world_regions.py'),
                                '--family', family], check=True, capture_output=True)
            for path, original in protected.items():
                self.assertEqual((checkout/path).read_bytes(), original)


if __name__ == '__main__':
    unittest.main()
