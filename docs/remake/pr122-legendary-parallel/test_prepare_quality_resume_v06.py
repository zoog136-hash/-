import copy
import datetime
import unittest

import prepare_quality_resume_v06 as resume


SHA = 'a' * 64
NEW_SHA = 'b' * 64


class ResumeTests(unittest.TestCase):
    def test_authorization_and_quota_guards_never_allow_early_calls(self):
        plan = {'allowed_candidate_ids': ['qc033'], 'quota_not_before_utc': '2026-10-23T20:55:39+00:00'}
        job = {'id': '225', 'direction': 'SW', 'role': 'idle', 'correction_candidate_id': 'qc033', 'state': 'READY'}
        before = datetime.datetime.fromisoformat('2026-10-23T20:55:38+00:00')
        after = datetime.datetime.fromisoformat('2026-10-23T20:55:40+00:00')
        self.assertEqual(resume.authorize_claim(plan, job, after, False), 'WAIT_ROOT_IMAGE_CALL_AUTHORIZATION')
        self.assertEqual(resume.authorize_claim(plan, job, before, True), 'WAIT_QUOTA_RESET')
        self.assertIsNone(resume.authorize_claim(plan, job, after, True))

    def test_prior_twenty_and_moderation_candidate_are_inadmissible(self):
        plan = {'allowed_candidate_ids': ['qc033'], 'quota_not_before_utc': '2026-10-23T20:55:39+00:00'}
        now = datetime.datetime.fromisoformat('2026-10-23T21:00:00+00:00')
        old = {'id': '402', 'direction': 'SW', 'role': 'idle', 'correction_candidate_id': 'qc001', 'state': 'READY'}
        self.assertEqual(resume.authorize_claim(plan, old, now, True), 'WAIT_NOT_NEVER_CALLED_READY_CANDIDATE')
        bad = dict(old, id='274', direction='NE', role='attack', correction_candidate_id='qc033')
        self.assertEqual(resume.authorize_claim(plan, bad, now, True), 'WAIT_MODERATION_EXCLUDED')

    def test_wait_rows_do_not_block_ready_batch_delivery(self):
        jobs = [{'id': str(i), 'role': 'attack', 'state': 'READY'} for i in range(7)]
        wait = {'id': 'hold', 'role': 'attack', 'state': 'WAIT', 'wait_reason': 'missing-parent'}
        jobs.insert(2, wait)
        end = resume.partition_jobs(jobs, 294)
        self.assertEqual(end, 296)
        self.assertEqual(sorted(sum(x.get('batch') == batch for x in jobs) for batch in (294, 295)), [2, 5])
        self.assertNotIn('batch', wait)

    def test_last_six_split_into_three_and_three_without_singleton(self):
        jobs = [{'id': str(i), 'role': 'idle', 'state': 'READY'} for i in range(6)]
        resume.partition_jobs(jobs, 294)
        self.assertEqual([sum(x['batch'] == b for x in jobs) for b in (294, 295)], [3, 3])

    def test_rebind_preserves_exact_selected_guard_coordinates_hashes(self):
        q = {'key': 'transform:113', 'direction': 'W', 'role': 'attack', 'reference': 'catalog.png',
             'reference_sha256': SHA, 'draft_guard_reuse': {'idle_record': 'old-record.json'}}
        before = copy.deepcopy(q)
        idle = {'key': 'transform:113', 'direction': 'W', 'role': 'idle', 'source': 'isolated.png',
                'source_sha256': NEW_SHA, 'source_files': [{'path': 'res://isolated.png', 'sha256': NEW_SHA}],
                'automatic_checks': [{'index': i, 'region': [i * 20, 0, 20, 30], 'rgba_sha256': str(i) * 64} for i in range(6)]}
        frames = [{'source': 'res://isolated.png', 'region': [i * 20, 0, 20, 30],
                   'margin': [2, 3, 4, 5]} for i in range(6)]
        rev = {'record': 'res://new-record.json', 'record_sha256': SHA,
               'SpriteFrames': 'res://new.tres', 'SpriteFrames_sha256': NEW_SHA}
        rebound = resume.bind_guard_request(q, rev, idle, frames)
        self.assertEqual(q, before)
        self.assertEqual(rebound['newly_authored_poses_requested'], 4)
        self.assertEqual(rebound['reused_poses'], 2)
        self.assertEqual(rebound['draft_guard_reuse']['guards'][1]['region'], frames[5]['region'])
        self.assertEqual(rebound['draft_guard_reuse']['guards'][1]['margin'], frames[5]['margin'])
        self.assertEqual(rebound['draft_guard_reuse']['guards'][1]['rgba_sha256'], '5' * 64)
        self.assertFalse(rebound['resume_guard_binding']['intermediate_pose_inference'])

    def test_rebind_refuses_different_actor_or_unmatched_region(self):
        q = {'key': 'transform:113', 'direction': 'W', 'role': 'attack'}
        with self.assertRaisesRegex(ValueError, 'actor/direction'):
            resume.bind_guard_request(q, {}, {'key': 'transform:114', 'direction': 'W', 'role': 'idle'}, [])

    def test_previously_attempted_parent_remains_wait_even_with_evidence(self):
        obj = object.__new__(resume.Preparation)
        obj.old_by_slot = {('338', 'N', 'idle'): {'correction_candidate_id': 'qc010'}}
        obj.states = {'qc010': {'status': 'PNG_READY_PENDING_COMPILE', 'generation_attempts': 1}}
        accepted, reason = obj.accepted_parent({'id': '338', 'direction': 'N'})
        self.assertIsNone(accepted)
        self.assertEqual(reason, 'WAIT_PREVIOUSLY_ATTEMPTED_OR_HOLD_PARENT_NO_RETRY')

    def test_missing_parent_evidence_is_wait_without_accessing_art(self):
        obj = object.__new__(resume.Preparation)
        obj.old_by_slot = {('113', 'N', 'idle'): {'correction_candidate_id': 'qc104'}}
        obj.states = {'qc104': {'status': resume.NEVER, 'generation_attempts': 0}}
        obj.parent_evidence = {}
        accepted, reason = obj.accepted_parent({'id': '113', 'direction': 'N'})
        self.assertIsNone(accepted)
        self.assertEqual(reason, 'WAIT_NEW_PARENT_CAMERA_AND_HEALTHY_GUARD_EVIDENCE')

    def test_request_actual_v03_v04_stem_is_shared_by_claim_receipt_delivery(self):
        for version in ('v02', 'v03', 'v04'):
            request = 'requests/transform_113-W-attack-correction-' + version + '.json'
            paths = resume.actual_evidence_paths(request)
            self.assertEqual(paths['claim'].stem, paths['receipt'].stem)
            self.assertEqual(paths['receipt'].name, 'transform_113-W-attack-correction-' + version + '.json')
            self.assertEqual(paths['tool_result'].stem, paths['receipt'].stem + '-result')

    def test_materialization_needs_both_camera_and_healthy_guards_exact_record(self):
        slot = ['transform:113', 'N', 'idle']
        row = {'slot': slot, 'record_sha256': SHA, 'camera_result': 'RESOLVED_STATIC',
               'idle_guard_result': 'HEALTHY_STATIC', 'reviewed_guard_phases': [0, 5]}
        self.assertTrue(resume.valid_parent_review({'records': [row]}, slot, SHA))
        self.assertFalse(resume.valid_parent_review({'records': [row]}, slot, NEW_SHA))
        self.assertFalse(resume.valid_parent_review({'records': [dict(row, idle_guard_result='HOLD_ACTION')]}, slot, SHA))
        self.assertFalse(resume.valid_parent_review({'records': [dict(row, reviewed_guard_phases=[0])]}, slot, SHA))


if __name__ == '__main__':
    unittest.main()
