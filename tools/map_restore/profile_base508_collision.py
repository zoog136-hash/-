"""Cross-check original attributes against portal/NPC coordinates, not pixels.

This emits evidence only. It never assigns passability or changes navigation.
Rectangle samples use closed integer cell bounds for profiling, not an assertion
about original engine territory boundary conventions or actual NPC instances.
"""
import argparse
import base64
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import struct


def rows(root, name):
    return json.loads((root/'content'/f'{name}.json').read_text(encoding='utf-8-sig'))['rows']


def profile(root, tables):
    manifest = json.loads((root/'map.json').read_text())
    attributes, floors = {}, {}
    for entry in manifest['geometry']:
        payload = (root/entry['file']).read_bytes()
        if hashlib.sha256(payload).hexdigest() != entry['sha256']:
            raise ValueError('Geometry SHA mismatch')
        chunk = json.loads(payload)
        words = struct.unpack('<8192H', base64.b64decode(chunk['attribute_u16le']))
        refs = struct.unpack('<8192I', base64.b64decode(chunk['floor_u32le']))
        ox, oy = chunk['origin']
        for i, value in enumerate(words):
            key = (ox*2+i % 128, oy+i//128)
            attributes[key], floors[key] = value, refs[i] >> 8
    def pair(x, y):
        return [attributes.get((x*2,y)), attributes.get((x*2+1,y))]
    def sample(territory):
        sx, ex, sy, ey = (territory[k] for k in ['StartX','EndX','StartY','EndY'])
        histogram = Counter(v for (hx,y),v in attributes.items() if sx*2 <= hx <= ex*2+1 and sy <= y <= ey)
        return {'raw_bounds': [sx,sy,ex,ey], 'sampled_half_words': sum(histogram.values()), 'raw_word_counts': dict(sorted(histogram.items()))}
    portals = []
    for portal in json.loads((root/manifest['portals_file']).read_text()):
        x,y = portal['SourceX'],portal['SourceY']
        portals.append({'ID': portal['ID'], 'source': [x,y], 'source_half_words': pair(x,y),
                        'neighbor_half_word_pairs': [[pair(x+dx,y+dy) for dx in [-1,0,1]] for dy in [-1,0,1]],
                        'target_land_id': portal['TargetTerritory']['LandID'],
                        'target_region': sample(portal['TargetTerritory'])})
    npc = json.loads((root/manifest['npc_occupancy_file']).read_text())
    classes = {r['ID']:r for r in rows(tables,'NpcClass')}
    categories = {r['ID']:r for r in rows(tables,'NpcCategory')}
    class_ids = sorted({c['view']['NpcClassID'] for p in npc for c in p['classes']})
    class_flags = [{'class_id': cid, 'class_flag': classes[cid]['IsOccupyLandTile'], 'category_id': classes[cid]['Category'], 'category_flag': categories[classes[cid]['Category']]['IsOccupyLandTile']} for cid in class_ids]
    npc_regions = [{'pack_id': p['NpcSpawnPackID'], 'territory_id': t['Territory']['ID'], 'point': t['Territory']['StartX']==t['Territory']['EndX'] and t['Territory']['StartY']==t['Territory']['EndY'], **sample(t['Territory'])} for p in npc for t in p['TerritoryReferences']]
    pairs = Counter(tuple(pair(hx//2,y)) for hx,y in attributes if hx % 2 == 0)
    by_tile = defaultdict(Counter)
    for key,value in attributes.items(): by_tile[floors[key]][value] += 1
    land_rules = [r for r in rows(tables,'LandAttribute') if r['LandID']==manifest['land']['ID']]
    types = {r['ID']:r for r in rows(tables,'LandAttributeType')}
    return {'schema':1, 'land_id':manifest['land']['ID'], 'asset_path':manifest['land']['AssetPath'],
            'raw_word_counts':dict(sorted(Counter(attributes.values()).items())),
            'source_cell_half_word_pair_counts':{str(k):v for k,v in sorted(pairs.items())},
            'floor_tile_id_word_counts':{str(k):dict(sorted(v.items())) for k,v in sorted(by_tile.items())},
            'portals':portals, 'npc_class_category_flags':class_flags, 'npc_territory_samples':npc_regions,
            'land_rules':[dict(r, TypeName=types[r['LandAttributeTypeID']]['Name']) for r in land_rules],
            'sampling_convention':'closed integer bounds for profiling only; engine boundary semantics unverified',
            'confirmed_terrain_cells_added':0, 'confirmed_static_npc_cells_added':0,
            'interpretation':'Word values and coordinates are observations. Portal anchors are not movement traces. Spawn regions are not actual positions. NoTeleport is not assumed to disable table portals. No terrain bit is assigned a meaning.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pack',type=Path)
    parser.add_argument('--tables',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    args = parser.parse_args()
    result = profile(args.pack,args.tables)
    args.out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ['land_id','raw_word_counts','source_cell_half_word_pair_counts','confirmed_terrain_cells_added','confirmed_static_npc_cells_added']}))
