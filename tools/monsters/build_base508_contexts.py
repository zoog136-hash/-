"""Join base508 NPC spawn contexts and literal SPR declarations, never legacy names.

No pixels are generated or copied. The output preserves source rows, including
inactive/restricted/test contexts, for inspection; the runtime refuses those by default.
"""
import argparse
import hashlib
import gzip
import io
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lineagem_original'))
import original_spr

TABLES = ('NpcSpawnPackNpcClassView', 'NpcSpawnPackTerritory', 'Territories', 'Land',
          'NpcRepresentativeSpawnView', 'NpcCategory', 'NpcAttack', 'NpcAttribute',
          'NpcSpawnPackSchedulePeriod')

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def build(content, spr_root, output):
    tables = {name: read(content / (name + '.json'))['rows'] for name in TABLES}
    npcs = read(content / 'NpcClass.json')['rows']
    declarations = original_spr.read(spr_root.glob('*.spr'))
    sprites = {}
    for sprite_id in sorted({row['Sprite'] for row in npcs}):
        try:
            owner, actions = original_spr.resolve(declarations, sprite_id)
            refs = original_spr.resolve_references(declarations, sprite_id)
            sprites[str(sprite_id)] = {
                'status': 'source_declaration_resolved', 'body_id': owner,
                'declaration': {'file': declarations[sprite_id][0].source_file,
                                'line': declarations[sprite_id][0].source_line},
                'references': refs,
                'actions': {str(code): action for code, action in sorted(actions.items())},
                'pixel_status': 'not_proven_by_metadata',
            }
        except ValueError as error:
            sprites[str(sprite_id)] = {'status': 'source_declaration_unresolved', 'reason': str(error)}
    indexes = {name: {row['ID']: row for row in tables[name]} for name in
               ('NpcSpawnPackNpcClassView', 'NpcSpawnPackTerritory', 'Territories', 'Land')}
    npc_ids = {row['ID'] for row in npcs}
    pack_ids = {row['NpcSpawnPackID'] for row in tables['NpcSpawnPackTerritory']}
    counts = {
        'npc_rows': len(npcs), 'sprite_ids': len(sprites),
        'resolved_sprite_declarations': sum(row['status'] == 'source_declaration_resolved' for row in sprites.values()),
        **{name: len(rows) for name, rows in tables.items()},
        'spawn_rows_missing_npc': sum(row['NpcClassID'] not in npc_ids for row in tables['NpcSpawnPackNpcClassView']),
        'spawn_rows_without_territory_pack': sum(row['NpcSpawnPackID'] not in pack_ids for row in tables['NpcSpawnPackNpcClassView']),
        'territory_links_missing_territory': sum(row['TerritoriesID'] not in indexes['Territories'] for row in tables['NpcSpawnPackTerritory']),
        'territories_missing_land': sum(row['LandID'] not in indexes['Land'] for row in tables['Territories']),
        'native_geographic_map_bindings': 0,
    }
    hashes = {name + '.json': hashlib.sha256((content / (name + '.json')).read_bytes()).hexdigest()
              for name in ('NpcClass', *TABLES)}
    spr_hashes = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(spr_root.glob('*.spr'))}
    result = {'schema': 1, 'source_snapshot': 'base508',
              'contract': 'Exact source identifiers only. Land.ID is not AssetPath. IsSpawn and ServerLimitSetID are preserved, not global activation authority. MonsterBookLevel is never used. No drop probabilities or quantities inferred.',
              'source_sha256': hashes, 'source_spr_sha256': spr_hashes, 'counts': counts,
              'tables': tables, 'sprites': sprites,
              'map_bindings': [],
              'activation_blockers': ['No reviewed TWILIGHT map to base508 Land/territory coordinate binding is installed.',
                                      'SPR declarations and archive addresses do not establish installed monster pixels.']}
    output.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n').encode('utf-8')
    packed = io.BytesIO()
    with gzip.GzipFile(fileobj=packed, mode='wb', filename='', compresslevel=9, mtime=0) as stream:
        stream.write(payload)
    output.write_bytes(packed.getvalue())
    print(json.dumps(counts, sort_keys=True))
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--content', type=Path, required=True)
    parser.add_argument('--spr-root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build(args.content, args.spr_root, args.output)
