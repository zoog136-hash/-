"""Focused selection regressions; fixtures are not original-art delivery proof."""
import copy
import json
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/lineagem_original'))
from weapon_action_selection import HALPAS_ACTORS, select_family


class WeaponFamilySelectionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        data = json.loads((ROOT / 'data/lineagem_base508/source_weapon_actions.json').read_text())
        cls.rows = list(data['source_action_rows'].values())

    def test_exact_primary_family_is_order_independent(self):
        for actor in HALPAS_ACTORS:
            for weapon, expected in ((3, [20, 21, 23]), (10, [62, 63, 65])):
                for rows in (self.rows, list(reversed(self.rows))):
                    family = select_family(rows, actor, weapon, {})
                    self.assertEqual([family[k]['ID'] for k in ('walk', 'attack', 'idle')], expected)
                    self.assertEqual(family['attack']['WeaponAlterType'], 1)
                    self.assertTrue(all(any(row is source for source in rows) for row in family.values()))

    def test_scope_preserves_other_actors_and_weapons(self):
        legacy = {'attack': {'ID': 130}}
        for actor, weapon in ((999, 3), (999, 10), (28439, 74), (28439, 1)):
            self.assertIs(select_family(self.rows, actor, weapon, legacy), legacy)

    def test_special_attack_is_never_a_missing_primary_substitute(self):
        for weapon, action in ((3, 21), (10, 63)):
            rows = [r for r in self.rows if r['ID'] != action]
            with self.assertRaisesRegex(ValueError, f'source action {action}'):
                select_family(rows, 28439, weapon, {})

    def test_duplicate_primary_row_is_rejected(self):
        rows = self.rows + [next(r for r in self.rows if r['ID'] == 21)]
        with self.assertRaisesRegex(ValueError, 'expected one row, got 2'):
            select_family(rows, 28439, 3, {})

    def test_wrong_source_identity_is_rejected(self):
        for field, value in (('Name', 'SpecialAttackBow'), ('WeaponType', 10),
                             ('MotionType', 4), ('WeaponAlterType', 0)):
            rows = copy.deepcopy(self.rows)
            next(r for r in rows if r['ID'] == 21)[field] = value
            with self.assertRaisesRegex(ValueError, 'identity mismatch'):
                select_family(rows, 28439, 3, {})


if __name__ == '__main__':
    unittest.main()
