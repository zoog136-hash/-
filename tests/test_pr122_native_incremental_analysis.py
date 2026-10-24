"""Changed inputs must miss the clip cache; exact inputs must avoid PNG decoding."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import stage_pr122_native_locomotion as stage


class IncrementalAnalysisTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.key = 'transform:413'
        self.versions = {'analysis': 'a1', 'importer': 'i1', 'reviewed_regions': 'r1',
                         'runtime_layout': 'l1', 'clip_preserver': 'g1'}
        self.manifest = {'raw_images': [], 'selected_locomotion_sheets': {},
                         'selected_detailed_action_sheets': {}}
        self.actor = {'tracks': []}
        self.records = {}
        for direction in ('E', 'W'):
            source = direction + '-run.png'
            data = ('synthetic-bytes-' + direction).encode()
            (self.root / source).write_bytes(data)
            geometry = {'image_size': [8, 12], 'distinct_pixel_frames': 6,
                        'canvas_size': [1024, 1024], 'foot': [512, 640],
                        'frames': [{'row': i, 'direction': direction,
                                    'rgba_sha256': direction + str(i)} for i in range(6)]}
            (self.root / source).with_suffix('.geometry.json').write_text(json.dumps(geometry))
            record = {'key': self.key, 'source': source, 'direction': direction, 'role': 'run',
                      'version': 'v1', 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data),
                      'requested_poses': 6, 'geometry': {'status': 'GEOMETRY_PASS'}}
            self.records[self.key, source] = record
            self.manifest['raw_images'].append(record)
            self.manifest['selected_locomotion_sheets'][self.key + ':' + direction + ':run'] = source
            self.actor['tracks'].append({'direction': direction, 'role': 'run',
                'animation': 'run_' + str(stage.importer.DIRECTIONS.index(direction)),
                'source': source, 'source_sha256': record['sha256'],
                'texture': 'existing/' + source, 'geometry': geometry})
        self.context = {'key': self.key, 'versions': self.versions, 'entries': {}}
        self.refresh_context()

    def refresh_context(self):
        for track in self.actor['tracks']:
            source = track['source']
            self.context['entries'][source] = {
                'input_sha256': stage._source_input_sha(self.root, self.records[self.key, source], None, self.versions),
                'track_sha256': stage._json_sha(track), 'track': copy.deepcopy(track)}

    def prepare(self, fresh=None, versions=None):
        def analyze(path, record, manifest, source, direction):
            return json.loads(path.with_suffix('.geometry.json').read_text()), None
        with patch.object(stage, '_analysis_versions', return_value=versions or self.versions), \
                patch.object(stage.subprocess, 'run'), \
                patch.object(stage, '_analyze_source_geometry', side_effect=analyze) as decoder:
            tracks, stats = stage._prepare_tracks(self.root, self.key, Path('new/r1'),
                self.manifest, self.records, self.actor, self.context, fresh)
            return tracks, stats, decoder.call_count

    def test_exact_inputs_reuse_both_clips_without_decoding(self):
        tracks, stats, calls = self.prepare()
        self.assertEqual(stats, {'reused': 2, 'fresh': 0, 'analyzed': 0})
        self.assertEqual(calls, 0)
        self.assertEqual(tracks, self.actor['tracks'])

    def test_same_filename_with_new_source_reanalyzes_only_that_clip(self):
        data = b'changed-rendered-source'
        (self.root / 'W-run.png').write_bytes(data)
        self.records[self.key, 'W-run.png'].update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
        _, stats, calls = self.prepare()
        self.assertEqual((stats['reused'], stats['analyzed'], calls), (1, 1, 1))

    def test_source_tampering_stops_before_any_cached_result(self):
        (self.root / 'E-run.png').write_bytes(b'corruption')
        with self.assertRaises(AssertionError):
            self.prepare()

    def test_joint_and_generator_metadata_invalidate_only_one_clip(self):
        for field, value in [('joint_settings', {'knee': [7, 9]}), ('version', 'new-generator')]:
            with self.subTest(field=field):
                record = self.records[self.key, 'W-run.png']
                old = copy.deepcopy(record)
                record[field] = value
                _, stats, calls = self.prepare()
                self.assertEqual((stats['reused'], stats['analyzed'], calls), (1, 1, 1))
                record.clear()
                record.update(old)

    def test_changed_part_settings_file_invalidates_its_clip(self):
        settings = self.root / 'W-parts.json'
        settings.write_text('{"sleeve":477}')
        self.records[self.key, 'W-run.png']['authoring_dependencies'] = [
            {'path': 'W-parts.json', 'sha256': stage.digest(settings)}]
        self.refresh_context()
        settings.write_text('{"sleeve":478}')
        _, stats, calls = self.prepare()
        self.assertEqual((stats['reused'], stats['analyzed'], calls), (1, 1, 1))

    def test_frame_order_change_invalidates_its_clip(self):
        sidecar = (self.root / 'W-run.png').with_suffix('.geometry.json')
        geometry = json.loads(sidecar.read_text())
        geometry['frames'][0], geometry['frames'][1] = geometry['frames'][1], geometry['frames'][0]
        sidecar.write_text(json.dumps(geometry))
        _, stats, calls = self.prepare()
        self.assertEqual((stats['reused'], stats['analyzed'], calls), (1, 1, 1))

    def test_validator_change_invalidates_every_affected_clip(self):
        _, stats, calls = self.prepare(versions={**self.versions, 'importer': 'i2'})
        self.assertEqual((stats['reused'], stats['analyzed'], calls), (0, 2, 2))

    def test_cached_result_tampering_is_not_reused(self):
        self.context['entries']['W-run.png']['track']['geometry']['frames'].reverse()
        _, stats, calls = self.prepare()
        self.assertEqual((stats['reused'], stats['analyzed'], calls), (1, 1, 1))

    def test_current_invocation_result_avoids_duplicate_analysis(self):
        record = self.records[self.key, 'W-run.png']
        record['version'] = 'new-render'
        geometry = self.actor['tracks'][1]['geometry']
        with patch.object(stage, '_analysis_versions', return_value=self.versions):
            fresh = stage.preserved_source_analysis(self.root, record, geometry)
        _, stats, calls = self.prepare({'W-run.png': fresh})
        self.assertEqual((stats['reused'], stats['fresh'], stats['analyzed'], calls), (1, 1, 0, 0))

    def test_three_argument_wrapper_keeps_scoped_inputs_and_restores_context(self):
        def guarded_stage(root, key, revision=None):
            scope = stage._SOURCE_ANALYSIS_CONTEXT.get()
            self.assertEqual((scope['root'], scope['key']), (root.resolve(), key))
            return scope['reuse']
        with stage.source_analysis_context(self.root, self.key, self.context, None):
            self.assertIs(guarded_stage(self.root, self.key, 'r1'), self.context)
        self.assertIsNone(stage._SOURCE_ANALYSIS_CONTEXT.get())


if __name__ == '__main__':
    unittest.main()
