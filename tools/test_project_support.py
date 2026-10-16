"""Fail-closed result parsing and bounded process execution for test_project.py.

The subprocess tests for this module use controlled programs, not the Godot engine.
"""
from __future__ import annotations

import json
import os
import re
import signal
import subprocess
from collections.abc import Mapping, Sequence

ERROR = re.compile(
    r'SCRIPT ERROR:|ERROR:|FAIL:|^\s*(?:[A-Z][A-Z0-9_]*_)?FAIL(?:ED)?(?=[:\s]|$)',
    re.MULTILINE,
)
REPORT = re.compile(r'\b[A-Z][A-Z0-9_]*_RESULT\s+(.+)$')
SUCCESS = re.compile(r'\b[A-Z][A-Z0-9_]*_OK\b')
SKIP = re.compile(r'\b[A-Z][A-Z0-9_]*_SKIP:')
OPTIONAL_RENDER_ENV = re.compile(
    r'^\s*#\s*TWILIGHT_OPTIONAL_RENDER_ENV:\s*([A-Z][A-Z0-9_]*)\s*$',
    re.MULTILINE,
)
# Fixed, existing TWILIGHT geometry contracts; not source-grid acceptance.
# Do not add generic gameplay tests here to hide source regressions.
LEGACY_GEOMETRY_TESTS = frozenset({
    'reference_object_placement_test', 'road_surface_render_test',
    'terrain_surface_render_test', 'world_region_portals_test',
    'world_regions_test', 'world_structure_test', 'world_terrain_coverage_test',
})
# This existing producer writes a counted summary rather than an _OK marker.
# Accept only its exact, positive-check, zero-failure report, for that test only.
RENEWED_SPAWN_SUMMARY = re.compile(
    r'^RENEWED MAP SPAWN TEST: ([1-9][0-9]*) checks, ([0-9]+) failures$',
    re.MULTILINE,
)


def requires_renderer(source: str, env: Mapping[str, str]) -> bool:
    """Only explicitly annotated, environment-gated captures may use headless."""
    if 'RenderingServer.frame_post_draw' not in source:
        return False
    optional = OPTIONAL_RENDER_ENV.findall(source)
    if len(optional) == 1:
        return bool(env.get(optional[0], '').strip())
    # Missing/ambiguous annotations retain mandatory real-render validation.
    return True


def timeout_budget(name: str, requested: int, import_timeout: int) -> int:
    """Keep exhaustive real-save audits bounded without dropping assertions."""
    if name == 'import':
        return max(requested, import_timeout)
    if name == 'world_regions_test':
        # Five isolated family shards (360 seconds each by default), not one
        # 540-second timer shared by all 24 maps. The child enforces deadlines.
        return max(requested, 1860)
    if name == 'remake_source_runtime_test':
        # Ten live boss/save lifecycles plus 50 real portal transitions and
        # rendered captures. Keep every floor and assertion in the private-pack
        # audit; installations without that pack still explicitly SKIP it.
        return max(requested, 480)
    if name == 'original_skill_learning_conditions_test':
        return max(requested, 540)
    if name == 'eight_interactions_test':
        # Real UI events plus repeated complete floor/inventory save-load cycles.
        return max(requested, 300)
    if name == 'ground_loot_system_test':
        # The unchanged 166-check full GUI/physics/save/loot suite completed
        # in ~112 seconds in its dedicated workflow, but exceeded the generic
        # 150-second subprocess cap in the concurrently loaded integration job.
        # Give only this exhaustive real-play suite bounded CI headroom.
        return max(requested, 300)
    if name in {'original_based_mummy_lord_gameplay_test',
                'original_based_seer_boss_gameplay_test',
                'original_based_raziel_watcher_gameplay_test',
                'original_based_salah_gameplay_test'}:
        # Preserve PR100's original-HP boss lifecycle budget.
        return max(requested, 450)
    if name == 'original_based_transform_temporal_main_test':
        # This inherited 10-case Main/120Hz audit runs all original gameplay,
        # save/drop checks and continuous pose playback, not a short smoke.
        return max(requested, 2400)
