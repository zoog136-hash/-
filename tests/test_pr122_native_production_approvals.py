"""Small isolated approval/freeze fixtures; no Godot, assets, Git or CI runs."""
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import pr122_native_production_approvals as gate


class ApprovalFixture:
    def __init__(self, root, approved=True):
        self.root = Path(root)
        self.key = 'transform:393'
        self.manifest = dict(approved_history_preserved=405, mythic_detail_complete=int(approved),
                             mythic_detail_total=31, raw_images=[], selected_locomotion_sheets={},
                             selected_detailed_action_sheets={})
        self.actor = dict(production_connected=approved, detailed_completed=approved,
                          completed_added=int(approved), native_track_count=48, native_pose_count=288,
                          status='APPROVED_DETAILED_PRODUCTION' if approved else 'HOLD',
                          visual_review='PASS' if approved else 'HOLD', timing_review='PASS' if approved else 'HOLD',
                          verification={'actual_Main_default_catalog': 'PASS' if approved else 'NOT_ENABLED'}, tracks=[])
        self.register = dict(approved_history_preserved=405, detailed_complete=int(approved), detailed_total=31,
                             actors={self.key: self.actor})
        for n, (direction, role) in enumerate(sorted(gate.TRACK_KEYS)):
            source = f'sources/{direction}-{role}.png'
            self.write(source, f'fixture source {n}'.encode())
            source_sha = self.digest(source)
            rgba = [hashlib.sha256(f'actual frame {n}-{p}'.encode()).hexdigest() for p in range(6)]
            geometry = dict(distinct_pixel_frames=6,
                            frames=[dict(row=p, rgba_sha256=h, region=[p, 0, 1, 1]) for p, h in enumerate(rgba)])
            self.actor['tracks'].append(dict(direction=direction, role=role, source=source,
                                              source_sha256=source_sha, texture=source, geometry=geometry))
            table = 'selected_locomotion_sheets' if role in ('walk', 'run') else 'selected_detailed_action_sheets'
            self.manifest[table][f'{self.key}:{direction}:{role}'] = source
            self.manifest['raw_images'].append(dict(key=self.key, direction=direction, role=role, source=source,
                                                    sha256=source_sha, bytes=(self.root / source).stat().st_size,
                                                    requested_poses=6, geometry={'status': 'GEOMETRY_PASS'}))
        self.actor['frames'] = 'res://production/SpriteFrames.tres'
        self.write('production/SpriteFrames.tres', b'fixture production frames')
        self.actor['frames_sha256'] = self.digest('production/SpriteFrames.tres')
        self.actor['native_profile'] = 'res://production/NativeMotionProfile.tres'
        self.write('production/NativeMotionProfile.tres',
                   b'[resource]\nframes_path = "res://production/SpriteFrames.tres"\n')
        self.actor['native_profile_sha256'] = self.digest('production/NativeMotionProfile.tres')
        self.default_catalog = {'변신': [dict(sourceId=393, name='fixture boss', animation_profile={})]}
        self.profiles = {'profiles': {self.key: dict(frames_path=self.actor['frames'], layout='directional8')}}
        self.write_json(gate.DEFAULT_CATALOG, self.default_catalog)
        self.write_json(gate.PROFILE_CATALOG, self.profiles)
        self.write('scripts/world.gd', b'const CATALOG_PATH: String = "res://data/catalog_v19.json"\n')
        self.write('scripts/animation/animation_catalog.gd',
                   b'const PROFILE_PATH = "res://data/combat_animation_profiles.json"\n')
        self.flush_data()
        if approved:
            description = gate.describe_actor(self.root, self.key, manifest=self.manifest, register=self.register)
            pins, selection = description['pins'], description['tracks']
            self.quality = dict(schema='pr122-native-independent-quality-v1', key=self.key, status='PASS',
                                independent=True, reviewer='independent fixture reviewer',
                                source_selection_sha256=pins['source_selection_sha256'],
                                production_frames=pins['production_frames'], production_profile=pins['production_profile'],
                                effective_profile_sha256=pins['effective_profile_sha256'],
                                checks={c: 'PASS' for c in gate.QUALITY_CHECKS}, tracks=[])
            for track in selection:
                row = {k: track[k] for k in ('direction', 'role', 'source_sha256', 'source_geometry_sha256',
                                            'geometry_sha256', 'frame_rgba_sha256')}
                row.update(status='PASS', visual_findings=['Fixture reviewed this exact source/geometry.'])
                self.quality['tracks'].append(row)
            self.write('evidence/main.log', (gate.default_main_marker(self.key) + '\n').encode())
            self.main = dict(schema='pr122-native-default-main-v1', key=self.key, status='PASS',
                             entrypoint='ACTUAL_MAIN_DEFAULT_CATALOG', scene='res://Main.tscn',
                             candidate_injection=False, runtime_profile_override=False,
                             engine_version='4.7.2.stable.official.ed1daf0bf', pins=pins,
                             checks={c: 'PASS' for c in gate.MAIN_CHECKS}, log=self.pin('evidence/main.log'))
            self.certificate = dict(schema='pr122-native-production-certificate-v1', key=self.key,
                                    status='APPROVED', approved_history_preserved=405, pins=pins)
            self.flush_evidence()

    def write(self, path, data):
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)

    def write_json(self, path, value):
        self.write(path, (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode())

    def digest(self, path):
        return hashlib.sha256((self.root / path).read_bytes()).hexdigest()

    def pin(self, path):
        return dict(path=path, sha256=self.digest(path))

    def flush_data(self):
        self.write_json(gate.MANIFEST, self.manifest)
        self.write_json(gate.REGISTER, self.register)

    def flush_evidence(self):
        self.write_json('evidence/quality.json', self.quality)
        self.write_json('evidence/main.json', self.main)
        self.certificate.update(quality_evidence=self.pin('evidence/quality.json'),
                                default_main_evidence=self.pin('evidence/main.json'))
        self.write_json('evidence/certificate.json', self.certificate)
        self.write_json(gate.APPROVALS, dict(schema='pr122-native-production-approvals-v1',
                                             approved_history_preserved=405,
                                             approved_actors={self.key: self.pin('evidence/certificate.json')}))

    def load(self):
        return gate.load_state(self.root, manifest=self.manifest, register=self.register)


class CompletionGateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='twilight-approval-guard-')
        self.root = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def test_missing_and_empty_registry_are_strict_zero_baseline(self):
        fixture = ApprovalFixture(self.root, approved=False)
        self.assertEqual(fixture.load().completed_count, 0)
        fixture.write_json(gate.APPROVALS, {})
        self.assertEqual(fixture.load().approved_keys, frozenset())
        fixture.actor['production_connected'] = True
        with self.assertRaisesRegex(gate.ApprovalError, 'Unbacked'):
            fixture.load()

    def test_history_and_counts_are_not_relaxed(self):
        fixture = ApprovalFixture(self.root, approved=False)
        for document, field, value in ((fixture.manifest, 'approved_history_preserved', 404),
                                        (fixture.register, 'detailed_complete', 1),
                                        (fixture.manifest, 'mythic_detail_complete', True)):
            prior = document[field]
            document[field] = value
            with self.assertRaises(gate.ApprovalError):
                fixture.load()
            document[field] = prior

    def test_valid_proof_freezes_actor_and_skips_it_only_for_default_bind(self):
        fixture = ApprovalFixture(self.root)
        state = fixture.load()
        self.assertEqual(state.completed_count, 1)
        fixture.register['actors']['transform:267'] = dict(production_connected=False, detailed_completed=False,
                                                          completed_added=0, frames='candidate/new.tres')
        self.assertEqual(state.bind_keys(fixture.register), ('transform:267',))
        with self.assertRaisesRegex(gate.ApprovalError, 'frozen'):
            state.require_mutable(fixture.key)
        with self.assertRaisesRegex(gate.ApprovalError, 'rebind'):
            state.bind_keys(fixture.register, fixture.key)
        fixture.register['actors']['transform:267']['frames'] = 'candidate/next.tres'
        state.assert_preserved(fixture.manifest, fixture.register)
        fixture.actor['visual_review'] = 'HOLD'
        with self.assertRaisesRegex(gate.ApprovalError, 'changed while staging'):
            state.assert_preserved(fixture.manifest, fixture.register)

    def test_bare_certificate_claim_without_pinned_pass_evidence_rejected(self):
        fixture = ApprovalFixture(self.root)
        fixture.certificate['quality_evidence'] = {'status': 'PASS'}
        fixture.write_json('evidence/certificate.json', fixture.certificate)
        fixture.write_json(gate.APPROVALS, dict(schema='pr122-native-production-approvals-v1',
                                             approved_history_preserved=405,
                                             approved_actors={fixture.key: fixture.pin('evidence/certificate.json')}))
        with self.assertRaisesRegex(gate.ApprovalError, 'file/SHA pin'):
            fixture.load()

    def test_quality_requires_all48_actual_track_findings_and_matching_pixels(self):
        fixture = ApprovalFixture(self.root)
        fixture.quality['tracks'][0]['frame_rgba_sha256'][0] = '0' * 64
        fixture.flush_evidence()
        with self.assertRaisesRegex(gate.ApprovalError, 'different pixels'):
            fixture.load()
        fixture.quality['tracks'].pop()
        fixture.flush_evidence()
        with self.assertRaisesRegex(gate.ApprovalError, 'all 48'):
            fixture.load()

    def test_actual_main_candidate_injection_or_old_candidate_log_is_rejected(self):
        fixture = ApprovalFixture(self.root)
        fixture.main['candidate_injection'] = True
        fixture.flush_evidence()
        with self.assertRaisesRegex(gate.ApprovalError, 'actual Main DEFAULT'):
            fixture.load()
        fixture.main['candidate_injection'] = False
        fixture.write('evidence/main.log', b'PR122_NATIVE_MAIN_PASS candidate injection\n')
        fixture.main['log'] = fixture.pin('evidence/main.log')
        fixture.flush_evidence()
        with self.assertRaisesRegex(gate.ApprovalError, 'actual default-catalog PASS marker'):
            fixture.load()

    def test_changed_source_profile_and_inline_catalog_are_rejected(self):
        fixture = ApprovalFixture(self.root)
        state = fixture.load()
        path = fixture.actor['tracks'][0]['source']
        original = (self.root / path).read_bytes()
        fixture.write(path, b'changed source')
        with self.assertRaises(gate.ApprovalError):
            state.assert_preserved(fixture.manifest, fixture.register)
        fixture.write(path, original)
        profile = 'production/NativeMotionProfile.tres'
        original_profile = (self.root / profile).read_bytes()
        fixture.write(profile, original_profile + b'# changed\n')
        with self.assertRaisesRegex(gate.ApprovalError, 'Changed pinned file'):
            state.assert_preserved(fixture.manifest, fixture.register)
        fixture.write(profile, original_profile)
        fixture.default_catalog['변신'][0]['animation_profile']['pixel_scale'] = 0.25
        fixture.write_json(gate.DEFAULT_CATALOG, fixture.default_catalog)
        with self.assertRaisesRegex(gate.ApprovalError, 'drift'):
            state.assert_preserved(fixture.manifest, fixture.register)

    def test_unrelated_catalog_record_may_advance_without_unfreezing_approved_actor(self):
        fixture = ApprovalFixture(self.root)
        state = fixture.load()
        fixture.default_catalog['변신'].append(dict(sourceId=267, animation_profile={'frames_path': 'res://new.tres'}))
        fixture.profiles['profiles']['transform:267'] = {'frames_path': 'res://new.tres'}
        fixture.write_json(gate.DEFAULT_CATALOG, fixture.default_catalog)
        fixture.write_json(gate.PROFILE_CATALOG, fixture.profiles)
        state.assert_preserved(fixture.manifest, fixture.register)

    def test_selected_source_and_duplicate_frame_hashes_cannot_be_certified(self):
        fixture = ApprovalFixture(self.root)
        fixture.manifest['selected_detailed_action_sheets']['transform:393:E:idle'] = 'sources/W-idle.png'
        with self.assertRaisesRegex(gate.ApprovalError, 'Selected source drift'):
            fixture.load()
        fixture.manifest['selected_detailed_action_sheets']['transform:393:E:idle'] = 'sources/E-idle.png'
        fixture.actor['tracks'][1]['geometry']['frames'][0]['rgba_sha256'] = fixture.actor['tracks'][0]['geometry']['frames'][0]['rgba_sha256']
        with self.assertRaisesRegex(gate.ApprovalError, '288 distinct'):
            fixture.load()

    def test_approval_file_pin_and_symlink_evidence_rejected(self):
        fixture = ApprovalFixture(self.root)
        fixture.write('evidence/certificate.json', b'{"status":"APPROVED"}')
        with self.assertRaisesRegex(gate.ApprovalError, 'Changed pinned file'):
            fixture.load()
        fixture.flush_evidence()
        real = self.root / 'evidence/quality.json'
        saved = real.read_bytes()
        real.unlink()
        self.root.joinpath('evidence/elsewhere.json').write_bytes(saved)
        real.symlink_to('elsewhere.json')
        with self.assertRaisesRegex(gate.ApprovalError, 'Symlinks'):
            fixture.load()

    def test_registry_change_and_unpinned_geometry_drift_are_rejected(self):
        fixture = ApprovalFixture(self.root)
        state = fixture.load()
        fixture.manifest['raw_images'][0]['geometry']['unreviewed_region'] = [0, 1, 2, 3]
        with self.assertRaisesRegex(gate.ApprovalError, 'drift'):
            state.assert_preserved(fixture.manifest, fixture.register)
        fixture.manifest['raw_images'][0]['geometry'].pop('unreviewed_region')
        fixture.write_json(gate.APPROVALS, {})
        with self.assertRaisesRegex(gate.ApprovalError, 'registry changed'):
            state.assert_preserved(fixture.manifest, fixture.register)

    def test_actual_runtime_catalog_path_drift_is_rejected(self):
        fixture = ApprovalFixture(self.root)
        state = fixture.load()
        fixture.write('scripts/world.gd', b'const CATALOG_PATH: String = "res://data/other.json"\n')
        with self.assertRaisesRegex(gate.ApprovalError, 'runtime catalog source path drift'):
            state.assert_preserved(fixture.manifest, fixture.register)

    def test_quality_cannot_be_transferred_to_different_production_profile(self):
        fixture = ApprovalFixture(self.root)
        fixture.quality['production_profile'] = {'path': 'unreviewed/Profile.tres', 'sha256': '0' * 64}
        fixture.flush_evidence()
        with self.assertRaisesRegex(gate.ApprovalError, 'actual production frames/profile/globals'):
            fixture.load()


if __name__ == '__main__':
    unittest.main()
