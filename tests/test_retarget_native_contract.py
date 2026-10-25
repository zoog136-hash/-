"""Reuse accepts a complete larger gait, never an inflated pose total."""
from copy import deepcopy
import hashlib
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from retarget_original_motion import validated_native_contract


def fixture(walk):
    directions = ['E', 'SE', 'S', 'SW', 'W', 'NW', 'N', 'NE']
    counts = {'idle': 2, 'walk': walk, 'attack': 3, 'hit': 2, 'death': 3}
    total = sum(counts.values()) * 8
    return {'directions': directions, 'distinct_pixel_frames': total,
            'frames': [{'rgba_sha256': hashlib.sha256(str(i).encode()).hexdigest()} for i in range(total)],
            'tracks': {role: {'source_frames_per_direction': count,
                              'unique_frames_per_direction': count,
                              'direction_unique_frames': dict.fromkeys(directions, count)}
                       for role, count in counts.items()}}


class RetargetContractTest(unittest.TestCase):
    def test_preserved_and_new_complete_gaits(self):
        for walk, total in [(3, 104), (4, 112), (6, 128), (8, 144)]:
            with self.subTest(walk=walk):
                proof = fixture(walk)
                original = deepcopy(proof)
                self.assertEqual(validated_native_contract(proof), total)
                self.assertEqual(proof, original)

    def test_inflated_or_duplicate_or_incomplete_matrix_is_rejected(self):
        for fault in ['duplicate', 'missing_direction', 'lost_phase', 'missing_role', 'inflated_total']:
            with self.subTest(fault=fault):
                proof = fixture(6)
                if fault == 'duplicate':
                    proof['frames'][-1] = deepcopy(proof['frames'][0])
                elif fault == 'missing_direction':
                    del proof['tracks']['walk']['direction_unique_frames']['NE']
                elif fault == 'lost_phase':
                    proof['tracks']['walk']['direction_unique_frames']['N'] = 5
                elif fault == 'missing_role':
                    del proof['tracks']['hit']
                else:
                    proof['distinct_pixel_frames'] = 144
                    proof['frames'].extend(fixture(8)['frames'][128:])
                with self.assertRaises(ValueError):
                    validated_native_contract(proof)


if __name__ == '__main__':
    unittest.main()
