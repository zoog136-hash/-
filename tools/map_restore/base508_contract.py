"""Source-space contract shared by map rendering and geographic NPC placement."""
import argparse
import json
import math
from pathlib import Path

SPACE = 'LINEAGEM_WORLD_SOURCE_CELLS_V1'


def contract(manifest):
    if manifest.get('edition') != 'LineageM_base508' or not manifest.get('geometry'):
        raise ValueError('Actual base508 source geometry is required')
    land_id = manifest['land']['ID']
    if type(land_id) not in (int,float) or not math.isfinite(land_id) or land_id != int(land_id):
        raise ValueError('LandID must be an exact integer identifier')
    land_id = int(land_id)
    origins = [row['origin'] for row in manifest['geometry']]
    return {'schema':1, 'edition':'LineageM_base508', 'map_key':f"base508_land_{land_id}",
            'land_id':land_id, 'asset_path':manifest['land']['AssetPath'],
            'coordinate_space':SPACE, 'source_cell_bounds':[min(p[0] for p in origins), min(p[1] for p in origins), max(p[0] for p in origins)+63, max(p[1] for p in origins)+63],
            'terrain_encoding':'S32_INTERLEAVED_U16_HALF_CELL_ATTRIBUTES; not L1J per-cell direction bytes',
            'supplied_chunk_origins':origins,
            'source_half_cell_rule':'half_x = 2 * source_x + half_index; half_index is 0 or 1; y is source_y',
            'display_grid_transform':manifest['art'].get('source_to_png_transform'),
            'display_visual_cell_center_offset':[24,12],
            'original_engine_actor_foot_anchor':'UNVERIFIED; explicit renderer policy required',
            'height':'UNKNOWN; do not interpret a raw attribute as height',
            'terrain_collision':'UNKNOWN_BLOCKED',
            'spawn_territories':'Preserve original points/regions and contextual view row; no region center or actual instance is inferred',
            'portal_regions':'Preserve all Start/End coordinates; trigger shape, activation and arrival selection remain unverified',
            'legacy_map_aliases':[], 'legacy_navigation_transform':'UNVERIFIED_DO_NOT_APPLY'}


def supplied_cell(spec, point):
    if len(point) != 2 or any(type(v) not in (int,float) or not math.isfinite(v) or v != int(v) for v in point):
        return False
    return [math.floor(point[0]/64)*64,math.floor(point[1]/64)*64] in spec['supplied_chunk_origins']


def spawn_record(spec, view, reference):
    territory = reference['Territory']
    if view['NpcSpawnPackID'] != reference['NpcSpawnPackID']:
        raise ValueError('Spawnpack relation mismatch')
    if territory['LandID'] != spec['land_id'] or territory.get('IsNoneSentinel'):
        raise ValueError('Wrong LandID or None territory; AssetPath is not a LandID')
    bounds = [territory[k] for k in ['StartX','StartY','EndX','EndY']]
    point = bounds[:2] == bounds[2:]
    return {'schema':1, 'edition':spec['edition'], 'map_key':spec['map_key'], 'land_id':spec['land_id'],
            'asset_path':spec['asset_path'], 'coordinate_space':SPACE,
            'npc_class_id':view['NpcClassID'], 'spawn_pack_id':view['NpcSpawnPackID'], 'class_view_row_id':view['ID'],
            'npc_level_contextual':view['NpcLevel'], 'is_spawn_raw':view['IsSpawn'], 'server_limit_set_id_raw':view['ServerLimitSetID'],
            'territory_reference_row_id':reference['ID'], 'territory_id':territory['ID'], 'probability_raw':reference['Probability'],
            'position_kind':'point' if point else 'region', 'source_bounds':bounds,
            'source_point':bounds[:2] if point else None, 'boundary_convention':'UNVERIFIED',
            'placement_status':'CLIENT_TERRITORY_ONLY', 'runtime_confirmed_source_cell':None,
            'terrain_status':'UNKNOWN', 'actual_occupancy_instantiated':False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pack',type=Path)
    parser.add_argument('--out',type=Path,required=True)
    args = parser.parse_args()
    spec = contract(json.loads((args.pack/'map.json').read_text()))
    args.out.write_text(json.dumps(spec,indent=2)+'\n')
    print(json.dumps(spec))
