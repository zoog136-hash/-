"""Portable schema/invariant checks. Runtime/terrain coverage lives in the Godot test."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class RenewedMapSpawnRulesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rules = json.loads((ROOT / 'data/monsters/renewed_map_spawn_rules.json').read_text(encoding='utf-8'))

    def test_exact_25_authored_maps_not_original_pack_maps(self):
        expected = {'aden_world', 'domination_summit'}
        for family, count in [('oman', 10), ('faith', 4), ('escaros', 5), ('albino', 4)]:
            expected.update(f'{family}_{index:02}' for index in range(1, count + 1))
        self.assertEqual(set(self.rules['map_ids']), expected)
        self.assertEqual(len(self.rules['map_ids']), 25)
        self.assertNotIn('l1_4', self.rules['map_ids'])

    def test_population_stats_and_current_wall_clock_policy(self):
        self.assertIs(self.rules['preserve_normal_total'], True)
        self.assertIs(self.rules['preserve_monster_stats_and_drops'], True)
        # Original monster rewards stay untouched; boss respawns intentionally
        # follow the newer wall-clock policy, not historical 600s timers.
        self.assertIs(self.rules['preserve_respawn_times'], False)
        self.assertEqual(self.rules['boss_respawn_policy'], 'device_wall_clock')
        self.assertEqual(self.rules['boss_respawn_seconds'], {'aden_world': 28800, 'other_maps': 86400})
        self.assertLess(self.rules['progression_weights'][0], self.rules['progression_weights'][1])
        self.assertGreater(self.rules['progression_weights'][0], 0)

    def test_aden_normal_budget_stays_132(self):
        counts = self.rules['maps']['aden_world']['normal_counts']
        self.assertEqual(len(counts), 11)
        self.assertEqual(sum(counts.values()), 132)
        self.assertTrue(all(0 < count <= 14 for count in counts.values()))

    def test_only_existing_named_field_bosses_are_added(self):
        bosses = self.rules['maps']['aden_world']['additional_bosses']
        self.assertEqual({boss['name'] for boss in bosses}, {'흑장로', '데스나이트'})
        self.assertEqual(len({boss['id'] for boss in bosses}), len(bosses))
        for boss in bosses:
            self.assertIn(boss['habitat'], self.rules['maps']['aden_world']['normal_counts'])
            self.assertEqual(boss['respawn_time'], self.rules['boss_respawn_seconds']['aden_world'])
            self.assertTrue(all(0 < value < 1 for value in boss['fraction']))
            self.assertTrue(all(0 < value <= 300 for value in boss['half_size']))

    def test_dense_hotspots_preserve_full_capacity_and_actor_clearance(self):
        profiles = json.loads((ROOT / 'data/monsters/world_spawn_profiles.json').read_text(encoding='utf-8'))['maps']
        for map_id in ('oman_03', 'oman_07'):
            with self.subTest(map=map_id):
                dense, = [row for row in profiles[map_id]['monster_spawn'] if row['id'] == 'dense_hotspot']
                self.assertEqual(dense['max_count'], 24)
                self.assertGreaterEqual(dense['min_spacing'], 38)  # diameter of Monster.tscn 19px collider
                self.assertGreaterEqual(dense['spawn_radius'], 240)
                self.assertEqual(dense['mode'], 'dense')

    def test_boss_anchor_is_relative_to_new_map(self):
        boss = self.rules['maps']['oman_01']
        self.assertEqual(boss['boss_review_anchor'], 'boss')
        self.assertNotIn('position', boss)
        self.assertNotIn('rect', boss)
        self.assertLess(4 * boss['boss_half_size'][0] * boss['boss_half_size'][1], 1_000_000)

    def test_albino_four_uses_existing_rosters_not_an_invented_boss(self):
        policy = self.rules['maps']['albino_04']
        self.assertIs(policy['boss_to_hunting'], True)
        self.assertEqual(policy['roster_sources'], ['albino_01', 'albino_02', 'albino_03'])
        self.assertNotIn('additional_bosses', policy)

    def test_protected_spawn_buffers_are_positive(self):
        distances = self.rules['exclusion_distances']
        self.assertEqual(set(distances), {'entry', 'portal', 'npc', 'safe_margin', 'road_half_width', 'boss_margin', 'dense_margin'})
        self.assertTrue(all(0 < value <= 400 for value in distances.values()))


if __name__ == '__main__':
    unittest.main()
