"""Compile a private, immutable inventory rule pack from the verified 523 ZIP.

No original rows are written to the public repository. Exact ID/URL/descriptor
joins follow the separately reviewed PR238 identity contract; no PR is merged.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import zipfile

SOURCE_SHA = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
SOURCE_SIZE = 25031173
FIELDS = ('name', 'source', 'sourceId', 'sourceUrl', 'slot', 'type', 'grade')
TABLES = ('StorageAutoStore', 'MerchantAutoSell', 'ItemClass', 'ItemCategory',
          'ItemEquipSlot', 'DescData_Korean', 'Grade', 'ItemBlessCode', 'ConstantData')

def sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()

def compile_pack(source: Path, catalog: Path, prices: Path) -> dict:
    if source.stat().st_size != SOURCE_SIZE or sha(source.read_bytes()) != SOURCE_SHA:
        raise ValueError('unsupported source bytes')
    tables, provenance = {}, {}
    with zipfile.ZipFile(source) as archive:
        if archive.testzip() is not None:
            raise ValueError('source CRC failure')
        for name in TABLES:
            raw = archive.read('content/'+name+'.json')
            rows = json.loads(raw.decode('utf-8-sig'))['rows']
            if rows and 'ID' in rows[0] and len({r['ID'] for r in rows}) != len(rows):
                raise ValueError('duplicate source ID: '+name)
            tables[name] = rows
            provenance[name] = {'sha256': sha(raw), 'bytes': len(raw), 'rows': len(rows)}
    items = {r['ID']: r for r in tables['ItemClass']}
    categories = {r['ID']: r for r in tables['ItemCategory']}
    grades = {r['ID']: r for r in tables['Grade']}
    desc = {r['ID']: r['Description'].strip() for r in tables['DescData_Korean']}
    game = json.loads(catalog.read_text('utf-8-sig'))['아이템']
    names = Counter(r['name'] for r in game)
    by_id = defaultdict(list)
    for record in game:
        if record.get('source') == 'inven' and str(record.get('sourceId', '')).isdigit():
            by_id[int(record['sourceId'])].append(record)
    storage = defaultdict(list)
    for row in tables['StorageAutoStore']:
        storage[row['ItemClassID']].append(row['ItemBlessCodeID'])
    selling = {r['ItemClassID'] for r in tables['MerchantAutoSell']}
    policies = json.loads(prices.read_text())['prices']
    if not set(map(int, policies)).issubset(selling):
        raise ValueError('price policy for an item outside native sell selection')
    equipment = {r['ItemClassID'] for r in tables['ItemEquipSlot']}
    definitions = {}
    for item_id in sorted(set(storage) | selling):
        original = items[item_id]
        category = categories[original['CategoryID']]
        label = desc.get(original['IdentifiedDescID']) or desc[original['DescID']]
        binding, reason = {}, 'no_unique_exact_id'
        candidates = by_id[item_id]
        if len(candidates) == 1:
            candidate = candidates[0]
            if candidate.get('sourceUrl') != 'https://lineagem.inven.co.kr/db/item/'+str(item_id):
                reason = 'source_url_id_mismatch'
            elif candidate['name'].strip() not in {desc.get(original['DescID']), desc.get(original['IdentifiedDescID'])}:
                reason = 'exact_descriptor_mismatch'
            elif names[candidate['name']] != 1:
                reason = 'ambiguous_inventory_name'
            else:
                binding = {k: candidate.get(k, '') for k in FIELDS}
                reason = ''
        policy = policies.get(str(item_id), {})
        if policy and (type(policy['adena']) is not int or policy['adena'] <= 0
                       or policy['adena'] != original['Cost']):
            raise ValueError('source/public price disagreement: '+str(item_id))
        virtual = original['Name'].startswith('[자동판매]')
        definitions[str(item_id)] = {
            'id': item_id, 'label': label, 'source_record_sha256': sha(json.dumps(original, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()),
            'is_storable': original['IsStorable'], 'player_tradable': original['IsTradable'],
            'source_cost': original['Cost'], 'grade': desc[grades[original['GradeID']]['DescID']],
            'stackable': category['IsStackable'], 'currency': category['Name'] == 'Currency',
            'equipment': item_id in equipment, 'virtual': virtual, 'test_item': original['TestItem'],
            'storage_bless': storage[item_id], 'merchant_auto': item_id in selling,
            'binding': binding, 'binding_pending': reason, 'price': policy,
        }
    constants = {r['Name']: r['Value'] for r in tables['ConstantData']}
    return {'schema': 'twilight-inventory523-v1', 'source_sha256': SOURCE_SHA,
            'source_tables': provenance, 'items': definitions,
            'storage_rows': tables['StorageAutoStore'], 'sell_rows': tables['MerchantAutoSell'],
            'bless_codes': tables['ItemBlessCode'], 'auto_sell_max': int(constants['AutoSellMaxCount']),
            'counts': {'storage_rows': len(tables['StorageAutoStore']), 'sell_rows': len(tables['MerchantAutoSell']),
                       'items': len(definitions), 'inven_storage_rows': sum(bool(definitions[str(r['ItemClassID'])]['binding']) for r in tables['StorageAutoStore']),
                       'inven_sell_rows': sum(bool(definitions[str(r['ItemClassID'])]['binding']) for r in tables['MerchantAutoSell']),
                       'confirmed_prices': len(policies), 'virtual_selectors': sum(r['virtual'] for r in definitions.values()),
                       'test_items': sum(r['test_item'] for r in definitions.values())},
            'policy': 'Native selection IDs/bless states and exact catalog identities. Publicly corroborated prices win; otherwise existing host grade rates, labelled as host policy. No virtual item grants, native activation, coordinates or NPC placements inferred.'}

def write_pack(document: dict, output: Path) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    raw = (json.dumps(document, ensure_ascii=False, sort_keys=True, separators=(',', ':'))+'\n').encode()
    (output/'inventory_rules523.json').write_bytes(raw)
    with zipfile.ZipFile(output/'TWILIGHT_inventory_rules523.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        entry = zipfile.ZipInfo('inventory_rules523.json', (2026, 11, 4, 0, 0, 0))
        entry.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(entry, raw)
    zip_raw = (output/'TWILIGHT_inventory_rules523.zip').read_bytes()
    receipt = {'payload_bytes': len(raw), 'payload_sha256': sha(raw), 'zip_bytes': len(zip_raw), 'zip_sha256': sha(zip_raw), 'counts': document['counts']}
    (output/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
    return receipt

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source_zip', type=Path)
    parser.add_argument('--catalog', type=Path, default=Path('data/catalog_v19.json'))
    parser.add_argument('--prices', type=Path, default=Path('data/automation/inventory523_prices.json'))
    parser.add_argument('--output', type=Path, required=True, help='private directory outside public Git')
    args = parser.parse_args()
    print(json.dumps(write_pack(compile_pack(args.source_zip, args.catalog, args.prices), args.output)))
