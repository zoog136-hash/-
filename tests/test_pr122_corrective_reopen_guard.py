import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import pr122_corrective_reopen_guard as guard


class ReopenedSourceHoldTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.request = dict(key='transform:267', direction='NW', role='idle')
        self.slot = 'transform:267:NW:idle'
        self.source = 'docs/remake/evidence/pr122-mythic-detailed/batch03/current.png'
        self.output = 'docs/remake/evidence/pr122-mythic-detailed/batch03/new.png'
        self.evidence_path = 'docs/remake/evidence/pr122-mythic-detailed/reviews/new-HOLD.json'
        for value, data in ((self.source, b'old private source fixture'), (self.output, b'new private source fixture')):
            path = self.root / value
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        self.source_sha = guard.digest(self.root / self.source)
        self.hold = dict(key='transform:267', status='HOLD', scope='all_native_clips', corrections=[
            dict(slot=self.slot, previous_source='old.png', replacement_source=self.source,
                 source_visual_status='PASS', geometry_and_actual_Player='PASS', actor_approval_added=0,
                 source_review_sha256='a' * 64)])
        self.manifest = dict(selected_detailed_action_sheets={self.slot: self.source},
                             visual_quality_holds=[self.hold], approved_history_preserved=405,
                             mythic_detail_complete=0)
        self.evidence = dict(status='CONFIRMED_NEW_SOURCE_CAMERA_HOLD_REOPEN_PRIOR_PASS_HISTORY_PRESERVED',
                             **self.request, source=self.source, source_sha256=self.source_sha,
                             phase=0, visual_findings=['A new source-camera defect, not an earlier PASS review.'],
                             no_actor_approval=True, no_prior_pass_deleted=True)
        self.write_evidence()

    def write_evidence(self):
        path = self.root / self.evidence_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.evidence) + '\n')
        self.evidence_sha = guard.digest(path)

    def entry(self):
        return guard.build_reopened_source_hold(self.root, self.manifest, self.request,
                                                evidence=self.evidence_path, evidence_sha256=self.evidence_sha,
                                                reason='Confirmed new NW camera defect')

    def register(self):
        entry = self.entry()
        self.hold['reopened_source_holds'] = [entry]
        return entry

    def authorize(self):
        return guard.authorize_selected_replacement(self.root, self.manifest, self.request, self.hold, self.source)

    def resolution_fixture(self):
        entry = self.register()
        self.request['reopened_source_hold'] = self.authorize()
        self.request.update(replaces_selected_source=self.source, output_source=self.output,
                            output_sha256=guard.digest(self.root / self.output),
                            status='GENERATED_GEOMETRY_PASS_NOT_APPROVED')
        self.manifest['selected_detailed_action_sheets'][self.slot] = self.output
        actor = dict(production_connected=False, detailed_completed=False, completed_added=0,
                     verification={key: 'PASS' for key in
                                   ('source_sha256_and_saved_geometry', 'spriteframes_parse_and_all_frame_cycles',
                                    'required_engine_4_7_2', 'actual_Player_scene_form_api')},
                     tracks=[dict(direction='NW', role='idle', source=self.output,
                                  source_sha256=self.request['output_sha256'],
                                  geometry=dict(distinct_pixel_frames=6,
                                                frames=[dict(row=phase) for phase in range(6)]))])
        correction = dict(slot=self.slot, previous_source=self.source, replacement_source=self.output,
                          source_visual_status='PASS', geometry_and_actual_Player='PASS',
                          actor_approval_added=0, source_review_sha256='b' * 64)
        return entry, actor, correction

    def resolve(self, actor, correction):
        return guard.resolve_reopened_source_hold(self.root, self.manifest, self.hold,
                                                  self.request, actor, correction)

    def test_registration_is_additive_and_does_not_change_manifest(self):
        before = copy.deepcopy(self.manifest)
        entry = self.entry()
        self.assertEqual(before, self.manifest)
        self.assertEqual(entry['prior_corrections_count'], 1)
        self.assertEqual(entry['source_sha256'], self.source_sha)
        self.assertEqual(entry['status'], 'HOLD')

    def test_absent_reopen_keeps_existing_repeat_guard(self):
        with self.assertRaisesRegex(ValueError, 'NEW evidence-pinned HOLD'):
            self.authorize()

    def test_exact_reopen_authorizes_and_pins_request(self):
        entry = self.register()
        token = self.authorize()
        self.assertEqual(token, {key: entry[key] for key in guard.PIN_FIELDS})
        self.request['reopened_source_hold'] = token
        self.assertEqual(token, self.authorize())
        self.request['reopened_source_hold']['evidence_sha256'] = 'f' * 64
        with self.assertRaisesRegex(ValueError, 'authorization differs'):
            self.authorize()

    def test_changed_evidence_bytes_and_source_bytes_are_rejected(self):
        self.register()
        path = self.root / self.evidence_path
        original = path.read_bytes()
        path.write_bytes(original + b' ')
        with self.assertRaisesRegex(ValueError, 'evidence bytes/hash changed'):
            self.authorize()
        path.write_bytes(original)
        (self.root / self.source).write_bytes(b'changed source')
        with self.assertRaisesRegex(ValueError, 'source bytes/hash changed'):
            self.authorize()

    def test_other_actor_slot_or_source_evidence_is_rejected(self):
        for field, replacement in (('key', 'transform:393'), ('direction', 'NE'),
                                   ('role', 'run'), ('source', 'different.png'),
                                   ('source_sha256', 'd' * 64)):
            with self.subTest(field=field):
                original = self.evidence[field]
                self.evidence[field] = replacement
                self.write_evidence()
                with self.assertRaisesRegex(ValueError, 'identity/source pins differ'):
                    self.entry()
                self.evidence[field] = original
        self.write_evidence()

    def test_pass_old_review_or_nonconfirming_evidence_cannot_reopen(self):
        self.hold['corrections'][0]['source_review_sha256'] = self.evidence_sha
        with self.assertRaisesRegex(ValueError, 'previous PASS review'):
            self.entry()
        self.hold['corrections'][0]['source_review_sha256'] = 'a' * 64
        for field, value in (('status', 'PASS'), ('no_actor_approval', False),
                             ('no_prior_pass_deleted', False), ('visual_findings', []), ('phase', True)):
            with self.subTest(field=field):
                original = self.evidence[field]
                self.evidence[field] = value
                self.write_evidence()
                with self.assertRaises(ValueError):
                    self.entry()
                self.evidence[field] = original
        self.write_evidence()

    def test_history_changed_deleted_or_slot_advanced_is_rejected(self):
        self.register()
        original = copy.deepcopy(self.hold['corrections'])
        self.hold['corrections'][0]['source_review_sha256'] = 'c' * 64
        with self.assertRaisesRegex(ValueError, 'history was changed or removed'):
            self.authorize()
        self.hold['corrections'] = original + [copy.deepcopy(original[0])]
        with self.assertRaisesRegex(ValueError, 'slot has already advanced'):
            self.authorize()
        self.hold['corrections'] = []
        with self.assertRaisesRegex(ValueError, 'retained earlier'):
            self.authorize()

    def test_later_unrelated_slot_keeps_original_authorization_and_history_pin(self):
        entry = self.register()
        token = self.authorize()
        original_entry = copy.deepcopy(entry)
        unrelated = dict(self.hold['corrections'][0], slot='transform:267:N:run',
                         previous_source='N-run-old.png', replacement_source='N-run-new.png')
        self.hold['corrections'].append(unrelated)
        self.request['reopened_source_hold'] = token
        self.assertEqual(self.authorize(), token)
        self.assertEqual(entry, original_entry)
        self.assertEqual(entry['prior_corrections_count'], 1)
        self.assertEqual(self.hold['corrections'][-1], unrelated)

    def test_pinned_prefix_reorder_or_removal_rejects_unrelated_suffix(self):
        earlier = dict(self.hold['corrections'][0], slot='transform:267:E:hit',
                       previous_source='E-hit-old.png', replacement_source='E-hit-new.png')
        self.hold['corrections'].append(earlier)
        self.register()
        pinned = copy.deepcopy(self.hold['corrections'])
        unrelated = dict(earlier, slot='transform:267:N:run')
        self.hold['corrections'] = list(reversed(pinned)) + [unrelated]
        with self.assertRaisesRegex(ValueError, 'history was changed or removed'):
            self.authorize()
        self.hold['corrections'] = pinned[:1] + [unrelated]
        with self.assertRaisesRegex(ValueError, 'history was changed or removed'):
            self.authorize()

    def test_appended_history_requires_another_valid_slot_of_the_same_actor(self):
        self.register()
        for invalid in (None, {}, {'slot': 'transform:393:N:run'},
                        {'slot': 'transform:267:N:unknown'}, {'slot': 'transform:267:bad:run'}):
            with self.subTest(record=invalid):
                self.hold['corrections'].append(invalid)
                with self.assertRaisesRegex(ValueError, 'invalid actor/slot'):
                    self.authorize()
                self.hold['corrections'].pop()

    def test_duplicate_active_or_consumed_evidence_is_rejected(self):
        entry = self.register()
        with self.assertRaisesRegex(ValueError, 'already has an active'):
            self.entry()
        self.hold['reopened_source_holds'] = [copy.deepcopy(entry), copy.deepcopy(entry)]
        with self.assertRaisesRegex(ValueError, 'one NEW evidence-pinned HOLD'):
            self.authorize()
        self.hold['reopened_source_holds'][0]['status'] = 'RESOLVED'
        self.hold['reopened_source_holds'].pop()
        with self.assertRaisesRegex(ValueError, 'previously consumed'):
            self.entry()

    def test_durable_path_only_and_no_symlinks(self):
        for invalid in ('/tmp/review.json', '../review.json', 'docs//review.json',
                        'scratch/review.json', self.source):
            with self.subTest(path=invalid), self.assertRaises(ValueError):
                guard.build_reopened_source_hold(self.root, self.manifest, self.request,
                                                  evidence=invalid, evidence_sha256=self.evidence_sha, reason='new')
        path = self.root / self.evidence_path
        saved = path.with_suffix('.saved.json')
        path.rename(saved)
        path.symlink_to(saved)
        with self.assertRaisesRegex(ValueError, 'symlinks'):
            self.entry()

    def test_source_selection_and_actor_hold_must_still_match(self):
        self.register()
        self.manifest['selected_detailed_action_sheets'][self.slot] = self.output
        with self.assertRaisesRegex(ValueError, 'Selected source or visual HOLD changed'):
            self.authorize()
        self.manifest['selected_detailed_action_sheets'][self.slot] = self.source
        self.hold['key'] = 'transform:393'
        with self.assertRaisesRegex(ValueError, 'one unresolved visual HOLD'):
            self.authorize()

    def test_original_uncorrected_source_requires_no_reopen(self):
        self.hold['corrections'] = []
        self.assertIsNone(self.authorize())
        self.request['reopened_source_hold'] = {}
        with self.assertRaisesRegex(ValueError, 'Unexpected reopened'):
            self.authorize()

    def test_resolution_preserves_history_approval_and_all_other_fields(self):
        entry, actor, correction = self.resolution_fixture()
        before_history, before_actor = copy.deepcopy(self.hold['corrections']), copy.deepcopy(actor)
        result = self.resolve(actor, correction)
        self.assertEqual(entry['status'], 'RESOLVED')
        self.assertEqual(result['replacement_sha256'], self.request['output_sha256'])
        self.assertEqual(self.hold['corrections'], before_history)
        self.assertEqual(actor, before_actor)
        self.assertEqual(self.manifest['approved_history_preserved'], 405)
        self.assertEqual(self.manifest['mythic_detail_complete'], 0)
        with self.assertRaises(ValueError):
            self.resolve(actor, correction)

    def test_resolution_preserves_later_unrelated_correction_records(self):
        entry, actor, correction = self.resolution_fixture()
        unrelated = dict(self.hold['corrections'][0], slot='transform:267:N:run',
                         previous_source='N-run-old.png', replacement_source='N-run-new.png')
        self.hold['corrections'].append(unrelated)
        history_before = copy.deepcopy(self.hold['corrections'])
        token_before = copy.deepcopy(self.request['reopened_source_hold'])
        self.resolve(actor, correction)
        self.assertEqual(entry['status'], 'RESOLVED')
        self.assertEqual(self.hold['corrections'], history_before)
        self.assertEqual(self.hold['corrections'][-1], unrelated)
        self.assertEqual(self.request['reopened_source_hold'], token_before)

    def test_resolution_needs_strict_geometry_actual_player_and_exact_track(self):
        entry, actor, correction = self.resolution_fixture()
        for field in actor['verification']:
            with self.subTest(check=field):
                actor['verification'][field] = 'NOT_RUN'
                before = copy.deepcopy(self.hold)
                with self.assertRaisesRegex(ValueError, 'strict geometry, engine, frame cycles and actual Player'):
                    self.resolve(actor, correction)
                self.assertEqual(before, self.hold)
                actor['verification'][field] = 'PASS'
        actor['tracks'][0]['geometry']['distinct_pixel_frames'] = 5
        with self.assertRaisesRegex(ValueError, 'six distinct'):
            self.resolve(actor, correction)
        actor['tracks'][0]['geometry']['distinct_pixel_frames'] = 6
        actor['tracks'][0]['source_sha256'] = 'c' * 64
        with self.assertRaisesRegex(ValueError, 'Player track'):
            self.resolve(actor, correction)
        self.assertEqual(entry['status'], 'HOLD')

    def test_resolution_rejects_missing_pins_changed_output_and_actor_approval(self):
        entry, actor, correction = self.resolution_fixture()
        token = self.request.pop('reopened_source_hold')
        with self.assertRaisesRegex(ValueError, 'pinned reopened authorization'):
            self.resolve(actor, correction)
        self.request['reopened_source_hold'] = token
        correction['actor_approval_added'] = 1
        with self.assertRaisesRegex(ValueError, 'add no actor approval'):
            self.resolve(actor, correction)
        correction['actor_approval_added'] = 0
        (self.root / self.output).write_bytes(b'changed replacement')
        with self.assertRaisesRegex(ValueError, 'Replacement source bytes/hash changed'):
            self.resolve(actor, correction)
        self.assertEqual(entry['status'], 'HOLD')


if __name__ == '__main__':
    unittest.main()
