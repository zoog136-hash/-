import unittest
from spx_source_actions import parse_entry, children, role_for


class SourceActionsTest(unittest.TestCase):
    def test_out_of_order_zero_time_and_multiple_markers(self):
        text = '#21624 208 body\n 5.attack(1 4,8.3:2 8.0:0!<10827 8.2:1! 8.1:3)\n 105.clothes(2 21626 21627)\n'
        entry = parse_entry(text, '21624')
        action = entry['actions']['5']
        self.assertEqual([f['frame'] for f in action['frames']], [3, 0, 2, 1])
        self.assertEqual([f['ticks'] for f in action['frames']], [2, 0, 1, 3])
        self.assertEqual(action['total_ticks'], 6)
        self.assertEqual(action['frames'][1]['sound_ids'], ['10827'])
        self.assertEqual(children(entry), ['21626', '21627'])

    def test_run_is_distinct_and_weapon_is_explicit(self):
        self.assertEqual(role_for('runL onehand sword'), 'run_onehand')
        self.assertEqual(role_for('runR onehand sword'), 'run_right_onehand')
        self.assertEqual(role_for('walk spear'), 'walk_spear')
        self.assertIsNone(role_for('unknown'))

    def test_rejects_unmatched_or_malformed_data(self):
        for text in ['#1 a\n 0.walk(0 2,0.0:1)', '#1 a\n 0.walk(0 1,0.0:0)',
                     '#1 a\n 0.walk(0 1,0.0:1)\n 0.walk(0 1,0.0:1)']:
            with self.assertRaises(ValueError):
                parse_entry(text, '1')
        with self.assertRaises(ValueError):
            parse_entry('encrypted', '21624')


if __name__ == '__main__':
    unittest.main()
