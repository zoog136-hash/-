import unittest

import active_findings_projection_v04 as active


class AuthoredPhaseTests(unittest.TestCase):
    def test_four_new_middle_poses_keep_author_phases_one_through_four(self):
        sequence = [{'phase': 0, 'idle_phase': 0}] + [
            {'phase': i, 'new_sheet_cell': i - 1} for i in range(1, 5)] + [{'phase': 5, 'idle_phase': 5}]
        clip = {'selected_poses': [{'source': 'new.png', 'source_sha256': 'a' * 64,
                                   'source_phase': i - 1} for i in range(6)]}
        active.authored_phase_mapping(clip, {'source_pose_sequence': sequence}, set())
        self.assertEqual([x['source_phase'] for x in clip['selected_poses']], list(range(6)))
        self.assertEqual([x['source_sheet_cell_ordinal'] for x in clip['selected_poses'][1:5]], list(range(4)))

    def test_reordered_native_clip_refers_to_original_author_phase(self):
        original = [{'phase': i, 'new_sheet_cell': i // 2} for i in range(6)]
        reordered = [{'phase': i, 'original_phase': original_phase} for i, original_phase in enumerate([0, 1, 2, 3, 5, 4])]
        clip = {'selected_poses': [{'source': 'new.png', 'source_sha256': 'a' * 64} for _ in range(6)]}
        active.authored_phase_mapping(clip, {'source_pose_sequence': original, 'revision_source_pose_sequence': reordered}, set())
        self.assertEqual(clip['selected_poses'][5]['source_phase'], 4)

    def test_exact_derivative_proof_phase_is_not_overwritten(self):
        clip = {'selected_poses': [{'source': 'derivative.png', 'source_sha256': 'a' * 64, 'source_phase': 1} for _ in range(6)]}
        active.authored_phase_mapping(clip, {'source_pose_sequence': [{'phase': i} for i in range(6)]}, {('derivative.png', 'a' * 64)})
        self.assertEqual([x['source_phase'] for x in clip['selected_poses']], [1] * 6)


if __name__ == '__main__':
    unittest.main()
