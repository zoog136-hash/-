"""Guard legacy visual scope without masking active source-map failures.

Run: python3 -m unittest discover -s tools -p 'test_pr120_legacy_scope.py' -v
These are runner-contract unit tests, not Godot runtime evidence.
"""
import unittest

from test_project_support import LEGACY_GEOMETRY_TESTS, classify_result


class AdenLegacyScopeTests(unittest.TestCase):
    def test_only_reviewed_aden_layout1_fixtures_are_legacy(self):
        previous = {
            'reference_object_placement_test', 'road_surface_render_test',
            'terrain_surface_render_test', 'world_region_portals_test',
            'world_regions_test', 'world_structure_test', 'world_terrain_coverage_test',
        }
        expected = {
            'aden_building_test', 'aden_courtyard_test',
            'aden_shoreline_test', 'aden_terrain_polish_test',
            'field_world_test',
        }
        self.assertEqual(LEGACY_GEOMETRY_TESTS - previous, expected)
        self.assertTrue(previous <= LEGACY_GEOMETRY_TESTS)

    def test_active_aden_suites_do_not_use_legacy_geometry(self):
        active = {
            'aden_giran_review_test', 'aden_remake_runtime_test',
            'aden_source_routes_test', 'aden_world_systems_test',
            'aden_world_visuals_test', 'remake_source_runtime_test',
        }
        self.assertFalse(active & LEGACY_GEOMETRY_TESTS)

    def test_generic_gameplay_is_not_reclassified_to_hide_failures(self):
        gameplay = {
            'monster_world_test', 'animation_restore_test',
            'remake_world_lifecycle_test', 'eight_interactions_test',
        }
        self.assertFalse(gameplay & LEGACY_GEOMETRY_TESTS)

    def test_layout1_field_fixture_and_unflagged_active_source_coexist(self):
        from pathlib import Path
        root = Path(__file__).resolve().parents[1]
        self.assertIn('legacy_aden_fixture.gd',
                      (root / 'tests/field_world_test.gd').read_text(encoding='utf-8'))
        for name in ('aden_remake_runtime_test', 'aden_world_systems_test',
                     'aden_source_routes_test', 'aden_world_visuals_test',
                     'remake_world_lifecycle_test', 'monster_world_test'):
            self.assertNotIn(name, LEGACY_GEOMETRY_TESTS)
            self.assertTrue((root / 'tests' / (name + '.gd')).is_file())

    def test_success_marker_cannot_hide_nonzero_process_exit(self):
        self.assertEqual(classify_result('aden_building_test', 1, 'ADEN_BUILDING_OK'),
                         (False, False))

    def test_success_marker_cannot_hide_failure_or_script_error(self):
        for error in ('COURTYARD_FAIL: old placement missing', 'SCRIPT ERROR: invalid node',
                      'ERROR: resource missing'):
            with self.subTest(error=error):
                self.assertEqual(classify_result('aden_courtyard_test', 0,
                                                error + '\nCOURTYARD_OK'), (False, False))

    def test_unreachable_entry_report_still_fails(self):
        output = 'ADEN_WORLD_RESULT {"checks":200,"failures":["entry has no source landing"]}\nADEN_WORLD_OK'
        self.assertEqual(classify_result('aden_world_visuals_test', 0, output), (False, False))

    def test_renderer_skip_is_not_recorded_as_a_pass(self):
        self.assertEqual(classify_result('aden_building_test', 0,
                                        'ADEN_BUILDING_SKIP: requires real OpenGL display'),
                         (True, True))

    def test_counted_success_still_passes(self):
        output = 'COURTYARD_RESULT {"checks":12,"failures":[]}'
        self.assertEqual(classify_result('aden_courtyard_test', 0, output), (True, False))


if __name__ == '__main__':
    unittest.main()
