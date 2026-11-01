"""Produce a small, exact original-address request for first source NPC contexts.

This is an extraction request, never a legacy-name identity approval or spawn patch.
"""
import argparse
import gzip
import json
from pathlib import Path

def read(path):
    if path.suffix in ('.gz', '.bin'):
        with gzip.open(path, 'rt', encoding='utf-8') as stream: return json.load(stream)
    return json.loads(path.read_text(encoding='utf-8-sig'))

def build(contexts, npcs, inventory, supplied, transfers, npc_ids, land_id=4):
    npcs = {row['ID']: row for row in npcs['rows']}
    tables = contexts['tables']
    territories = {row['ID']: row for row in tables['Territories']}
    links = {}
    for link in tables['NpcSpawnPackTerritory']:
        if territories.get(link['TerritoriesID'], {}).get('LandID') == land_id:
            links.setdefault(link['NpcSpawnPackID'], []).append(link)
    assets_by_id = {}
    for asset in inventory['assets']:
        assets_by_id.setdefault(asset['id'], []).append(asset)
    source_rows = {row['id']: row for row in inventory['rows']}
    supplied_by_name = {row['name']: row for row in supplied['assets']}
    transfer_by_group = {row['file_name'].removesuffix('.zip'): row for row in transfers['files']}
    requested = {}
    selections = []
    for npc_id in npc_ids:
        npc = npcs[npc_id]
        candidates = [row for row in tables['NpcSpawnPackNpcClassView']
                      if row['NpcClassID'] == npc_id and row['IsSpawn'] == 1
                      and row['ServerLimitSetID'] == 0 and row['NpcSpawnPackID'] in links]
        if not candidates:
            selections.append({'npc_id': npc_id, 'status': 'no_unrestricted_context_for_requested_land'})
            continue
        spawn = min(candidates, key=lambda row: row['ID'])
        link = min(links[spawn['NpcSpawnPackID']], key=lambda row: row['ID'])
        sprite_id = npc['Sprite']
        source = source_rows.get(sprite_id, {})
        dependency_ids = source.get('dependency_ids', [sprite_id])
        names = []
        for dependency_id in dependency_ids:
            for asset in assets_by_id.get(dependency_id, []):
                key = (asset['archive'], asset['name'])
                value = {field: asset[field] for field in ('archive', 'name', 'size', 'crc32', 'id', 'suffix')}
                existing = supplied_by_name.get(asset['name'])
                if existing and existing['size'] == asset['size'] and existing['crc32'] == asset['crc32']:
                    transfer = transfer_by_group.get(existing['group'])
                    if transfer:
                        value['available_library_package'] = {field: transfer[field] for field in ('library_file_id', 'file_name', 'bytes', 'sha256')}
                requested[key] = value
                names.append(asset['name'])
        selections.append({'npc_id': npc_id, 'source_internal_name': npc['Name'], 'sprite_id': sprite_id,
                           'spawn_view_id': spawn['ID'], 'territory_link_id': link['ID'],
                           'land_id': land_id, 'land_asset_path': next(row['AssetPath'] for row in tables['Land'] if row['ID'] == land_id), 'npc_level': spawn['NpcLevel'],
                           'source_dependency_ids': dependency_ids, 'original_members': sorted(set(names)),
                           'legacy_binding': None, 'world_replacement_enabled': False})
    files = [requested[key] for key in sorted(requested)]
    return {'schema': 1, 'source_snapshot': 'base508',
            'contract': 'Small first extraction scope, source IDs joined to their own spawn and land only. No correspondence to TWILIGHT legacy records or geographic coordinates approved.',
            'selections': selections, 'files': files,
            'counts': {'selected_source_contexts': sum('spawn_view_id' in row for row in selections),
                       'original_files': len(files), 'original_bytes': sum(row['size'] for row in files),
                       'files_in_existing_library_packages': sum('available_library_package' in row for row in files),
                       'files_requiring_original_extraction': sum('available_library_package' not in row for row in files)},
            'world_replacement_enabled': False}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['contexts', 'npcs', 'inventory', 'supplied', 'transfers', 'output']:
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--npc-ids', default='90,248,249,256,281,286')
    parser.add_argument('--land-id', type=int, default=4)
    args = parser.parse_args()
    result = build(read(args.contexts), read(args.npcs), read(args.inventory), read(args.supplied), read(args.transfers), [int(n) for n in args.npc_ids.split(',')], args.land_id)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(result['counts']))
