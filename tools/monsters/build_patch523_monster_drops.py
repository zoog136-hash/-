#!/usr/bin/env python3
"""Compile private 523 drop membership; source rows are never drop rates."""
from __future__ import annotations
import argparse
import collections
import gzip
import hashlib
import json
from pathlib import Path
import zipfile
import zlib

TABLES = ('NpcClass', 'NpcCategory', 'ItemClass', 'NpcItemDropView',
          'ItemBlessCode', 'DescData_Korean')
KIND = 'patch523_monster_drop_membership'

def digest(data):
    return hashlib.sha256(data).hexdigest()

def compile_pack(source: Path, catalog: Path):
    index = {r['path']: r for r in json.loads((source/'index.json').read_text(encoding='utf-8-sig'))}
    tables, provenance = {}, {}
    for name in TABLES:
        path = 'content/'+name+'.json'
        raw = (source/path).read_bytes()
        entry = index[path]
        rows = json.loads(raw.decode('utf-8-sig'))['rows']
        if (len(raw) != entry['bytes'] or digest(raw) != entry['sha256'] or
                f'{zlib.crc32(raw):08x}' != entry['crc32'] or len(rows) != entry['row_count']):
            raise ValueError('source index mismatch: '+name)
        if len({r['ID'] for r in rows}) != len(rows):
            raise ValueError('duplicate source ID: '+name)
        tables[name] = rows
        provenance[name] = entry
    npcs = {r['ID']: r for r in tables['NpcClass']}
    items = {r['ID']: r for r in tables['ItemClass']}
    categories = {r['ID']: r for r in tables['NpcCategory']}
    descriptions = {r['ID']: r['Description'].strip() for r in tables['DescData_Korean']}
    bless = {r['ID']: r for r in tables['ItemBlessCode']}
    game = json.loads(catalog.read_text(encoding='utf-8-sig'))['아이템']
    by_id = collections.defaultdict(list)
    by_name = collections.Counter(r['name'] for r in game)
    for r in game:
        if r.get('source') == 'inven' and str(r.get('sourceId', '')).isdigit():
            by_id[int(r['sourceId'])].append(r)
    bindings, unresolved = {}, {}
    for item_id in sorted({r['ItemClassID'] for r in tables['NpcItemDropView']}):
        native = items[item_id]
        candidates = by_id[item_id]
        reason = ''
        if len(candidates) != 1:
            reason = 'no_unique_exact_native_ID_in_existing_catalog'
        else:
            item = candidates[0]
            if item.get('sourceUrl') != 'https://lineagem.inven.co.kr/db/item/'+str(item_id):
                reason = 'source_URL_ID_mismatch'
            elif item['name'].strip() not in {descriptions.get(native[k], '') for k in ('DescID', 'IdentifiedDescID')}:
                reason = 'exact_ID_localized_descriptor_mismatch'
            elif by_name[item['name']] != 1:
                reason = 'inventory_name_key_has_multiple_source_IDs'
        if reason:
            unresolved[str(item_id)] = reason
            continue
        bindings[str(item_id)] = {k: item.get(k, '') for k in ('name', 'source', 'sourceId', 'sourceUrl', 'slot', 'type', 'grade')}
    drops = collections.defaultdict(list)
    payloads = collections.Counter()
    pairs = collections.defaultdict(set)
    for number, row in enumerate(tables['NpcItemDropView'], 1):
        if row['NpcClassID'] not in npcs or row['ItemClassID'] not in items or row['Bless'] not in bless:
            raise ValueError('dangling source drop: '+str(row['ID']))
        drops[str(row['NpcClassID'])].append({**row, 'source_row_1based': number})
        payloads[tuple(row[k] for k in ('NpcClassID', 'ItemClassID', 'Bless', 'RequiredQuestID'))] += 1
        pairs[row['NpcClassID'], row['ItemClassID']].add((row['Bless'], row['RequiredQuestID']))
    document = {
        'schema': 1, 'kind': KIND, 'source_snapshot': 'patch523',
        'policy': 'Source membership only. Existing host rates, roll counts and quantity=1. No inferred source rates/quantities. Quest rows blocked; no quest reintroduction. Exact duplicate payloads do not add weight. Bless and quest variants remain distinct.',
        'source_tables': provenance, 'catalog_sha256': digest(catalog.read_bytes()),
        'npcs': {str(i): {'sprite_id': r['Sprite'], 'source_name': r['Name'],
                           'display_name': descriptions.get(r['DescId'], ''),
                           'test_npc': r['TestNPC'], 'category_id': r['Category'],
                           'show_drop_info': categories[r['Category']]['IsShowDropInfo'],
                           'attackable': categories[r['Category']]['IsAttackable']}
                 for i, r in npcs.items()},
        'drops': dict(drops), 'bindings': bindings, 'unresolved_item_ids': unresolved,
        'bless_codes': {str(i): r['Name'].lower() for i, r in bless.items()},
        'counts': {'rows': len(tables['NpcItemDropView']), 'npc_classes': len(drops),
                   'item_classes': len(bindings)+len(unresolved), 'verified_item_bindings': len(bindings),
                   'unresolved_item_bindings': len(unresolved),
                   'rows_with_verified_binding': sum(str(r['ItemClassID']) in bindings for r in tables['NpcItemDropView']),
                   'quest_conditional_rows': sum(r['RequiredQuestID'] != 0 for r in tables['NpcItemDropView']),
                   'distinct_payloads': len(payloads), 'duplicate_extra_rows': sum(n-1 for n in payloads.values()),
                   'pairs_with_condition_variants': sum(len(v)>1 for v in pairs.values())}}
    return document

def write_pack(document, output: Path):
    output.mkdir(parents=True, exist_ok=True)
    raw = (json.dumps(document, ensure_ascii=False, separators=(',', ':'))+'\n').encode()
    packed = gzip.compress(raw, mtime=0)
    (output/'monster_drops.bin').write_bytes(packed)
    header = {'schema': 1, 'kind': KIND, 'source_snapshot': 'patch523',
              'sha256': digest(packed), 'bytes': len(packed), 'counts': document['counts']}
    (output/'manifest.json').write_text(json.dumps(header, ensure_ascii=False, indent=2)+'\n')
    with zipfile.ZipFile(output/'TWILIGHT_patch523_monster_drops.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, value in [('pack.json', json.dumps(header).encode()), ('payload/monster_drops.bin', packed)]:
            entry = zipfile.ZipInfo(name, (2026, 11, 4, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, value)
    return header

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source', type=Path, required=True, help='validated 523 directory containing index.json/content')
    p.add_argument('--catalog', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True, help='private directory outside public Git')
    a = p.parse_args()
    print(json.dumps(write_pack(compile_pack(a.source, a.catalog), a.output), ensure_ascii=False))

if __name__ == '__main__':
    main()
