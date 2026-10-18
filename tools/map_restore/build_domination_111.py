"""Adapt the user-selected original Oman summit PNG to TWILIGHT's existing
domination_summit ID. Source map 111 is explicit; 12862 is never substituted.
Existing Oman navigation shards and effective gameplay records are preserved.
"""
import argparse
import json
from pathlib import Path
import shutil
import struct
import zipfile

import numpy as np

from build_remake import ARCHIVE_SHA, ROOT, distances, placements, select_entry, strict_masks, write
from convert_world import Pack
from formats import move_masks, sha

GRID_SHA = '2fde4743bc2b6edc5551c62ef458a60298c9f2a099fba59094373a2e7e35c565'


def build(a3, layouts, base, output):
    if output.resolve().is_relative_to(ROOT):
        raise ValueError('Keep the source-derived local review pack outside the public checkout')
    if output.exists():
        raise ValueError('Output exists; reuse it or choose a new output instead of regenerating')
    if sha(a3.read_bytes()) != ARCHIVE_SHA:
        raise ValueError('A3 archive identity mismatch')
    legacy = json.loads(layouts.read_text())['domination_summit']
    with zipfile.ZipFile(a3) as z:
        raw = z.read('data/mapcache/111.map')
    if struct.unpack('>5i', raw[:20]) != (111, 32576, 32768, 256, 256):
        raise ValueError('Source 111 header mismatch')
    grid = np.frombuffer(raw[20:], np.uint8).reshape(256, 256).T.copy()
    if sha(grid.tobytes()) != GRID_SHA:
        raise ValueError('Source 111 grid mismatch')
    raw_masks = move_masks(grid)
    masks = strict_masks(raw_masks)
    # A provisional landing in the largest original connected component.
    # Never import PC monsters or invent a walkable cell to accommodate a portal.
    entry, reach, observations = select_entry(grid, raw_masks, [32576, 32768], [])
    if not np.array_equal(reach, distances(masks, entry)):
        raise ValueError('Cardinal connectivity changed')
    gameplay = placements(legacy, grid, masks, [32576, 32768], entry, reach)
    shutil.copytree(base, output)
    index = json.loads((output/'index.json').read_text())
    pack = Pack(output, 'navigation')
    pack.shard = max(int(p.stem.rsplit('-', 1)[1]) for p in output.glob('navigation-*.bin'))
    chunks = []
    try:
        for y in range(0, 256, 64):
            for x in range(0, 256, 64):
                a, m = grid[y:y+64, x:x+64], raw_masks[y:y+64, x:x+64]
                chunks.append([x//64, y//64, 64, 64, *pack.add(a.tobytes()+m.tobytes())])
    finally:
        pack.close()
    value = dict(schema=2, map_id='domination_summit', source_map_id=111,
        map_name=legacy['map_name'], origin=[32576, 32768], dimensions=[256, 256],
        source_sha256=GRID_SHA, source_archive_sha256=ARCHIVE_SHA,
        navigation=dict(profile='A3_STATIC_EDGES', chunks=chunks), corner_policy='no_corner_cut',
        coordinate_mapping=dict(basis_x=[24, -12], basis_y=[24, 12], translation=[0, 3072]),
        pack_root='res://data/map_remake/private', spawn_source=[entry[0]+32576, entry[1]+32768],
        playable=True, layout_revision=2026101804, rules={}, npc_spawns=[], monster_spawns=[],
        portals=[], getback=[], doors=[], terrain_chunks=[], remake_gameplay=gameplay,
        render_profile='domination', legacy_layout_revision=legacy['layout_revision'],
        source_identity='OMAN_SUMMIT_111', adaptation='USER_SELECTED_AS_TWILIGHT_DOMINATION',
        art_status='ORIGINAL_111_PNG_LOCAL_PACK', edition_status='PNG_ALIGNMENT_REVIEW_REQUIRED')
    write(output/'definitions/domination_summit.json', value)
    index['maps']['domination_summit'] = dict(path='res://data/map_remake/private/definitions/domination_summit.json',
        sha256=sha((output/'definitions/domination_summit.json').read_bytes()), grid_sha256=GRID_SHA)
    write(output/'index.json', index)
    report = dict(source_map_id=111, game_map_id='domination_summit', user_selected_png='111.png',
        source_grid_sha256=GRID_SHA, source_cache_sha256=sha(raw), source_archive_sha256=ARCHIVE_SHA,
        walkable_cells=int(np.count_nonzero(raw_masks)), reachable_cells=int(np.count_nonzero(reach >= 0)),
        source_navigation_chunks=len(chunks), existing_navigation_shards='COPIED_BYTE_IDENTICAL',
        legacy_layout_sha256=sha(layouts.read_bytes()), regions=len(gameplay['monster_spawn']),
        portals=len(gameplay['portal']), npc_count=len(gameplay['npc_spawn']),
        source_spawn=list(map(int, value['spawn_source'])), collision_from_image_colors=False,
        placement='CURRENT_TWILIGHT_GAMEPLAY_RELOCATED_TO_ORIGINAL_CONNECTED_CELLS',
        png_alignment='REVIEW_REQUIRED', source_identity_12862=False)
    write(output/'domination_111_report.json', report)
    print(json.dumps(report))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for name in ['a3', 'layouts', 'base', 'output']:
        p.add_argument('--'+name, type=Path, required=True)
    a = p.parse_args()
    build(a.a3, a.layouts, a.base, a.output)
