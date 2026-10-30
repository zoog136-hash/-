#!/usr/bin/env python3
"""Build typed identity pointers from verified SQL/DESC, without importing gameplay."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
from verify_source3_item_identities import (IdentityError, digest, guarded_path,
                                          identify_display, load_desc_evidence, record_digest)

WEAPONS = {'dagger': '단검', 'sword': '한손검', 'tohandsword': '양손검',
           'spear': '창', 'singlespear': '창', 'axe': '도끼', 'singleaxe': '도끼',
           'bow': '활', 'staff': '지팡이', 'edoryu': '이도류', 'claw': '크로우',
           'gauntlet': '건틀렛', 'chainsword': '체인 소드'}
ARMOR = {'armor': 'body', 'helm': 'helmet', 'shield': 'offhand', 'glove': 'gloves',
         'boots': 'boots', 'cloak': 'cloak', 'T': 'tshirt', 'tshirt': 'tshirt',
         'ring': 'ring', 'amulet': 'necklace', 'belt': 'belt', 'earring': 'earring'}


def build(root, source_input, desc_input):
    manifest = json.loads((root / 'data/l1j/source3_item_identities.json').read_text())
    for relative, expected in manifest['input_file_guards'].items():
        if digest(guarded_path(source_input, relative).read_bytes()) != expected:
            raise IdentityError('Pinned source input changed: ' + relative)
    items = [json.loads(line) for line in (source_input / 'source_items.jsonl').read_text().splitlines()]
    tables = load_desc_evidence(manifest, desc_input, source_input, items)
    catalog_path = root / 'data/catalog_v19.json'
    catalog = json.loads(catalog_path.read_text())['아이템']
    by_name = defaultdict(list)
    for row in catalog:
        by_name[row['name']].append(row)
    pending, reasons = [], Counter()
    snapshots = {}
    for source in items:
        raw = source['raw_fields']
        if not source['eligible_for_identity_mapping'] or source['excluded_feature_reasons']:
            reasons['excluded_feature'] += 1
            continue
        if raw.get('bless') != '1' or raw.get('trade') != '0':
            reasons['unreviewed_variant'] += 1
            continue
        try:
            name = identify_display(source, tables, 'k')
            chinese = identify_display(source, tables, 'c')
        except IdentityError:
            reasons['complex_name_token'] += 1
            continue
        # The verified S_IdentifyDesc path displays the name token, not the
        # server's internal label. For plain materials only, retain both labels
        # explicitly when they differ; equipment still requires strict agreement.
        internal_label_differs = chinese != source['name_source']
        if internal_label_differs and not (source['table'] == 'etcitem' and raw.get('item_type') == 'material'):
            reasons['source_display_disagrees'] += 1
            continue
        matches = by_name.get(name, [])
        if len(matches) != 1:
            reasons['game_name_absent_or_ambiguous'] += 1
            continue
        game = matches[0]
        kind = raw.get('type', raw.get('item_type'))
        if source['table'] == 'weapon':
            typed = game.get('slot') == 'weapon' and WEAPONS.get(kind) == game.get('type')
        elif source['table'] == 'armor':
            typed = ARMOR.get(kind) == game.get('slot')
        else:
            typed = kind == 'material' and game.get('slot') == 'material' and game.get('type') == '재료'
        if not typed:
            reasons['type_unreviewed_or_mismatch'] += 1
            continue
        provenance = source['source_row']['provenance']
        relative = 'source_snapshots/' + provenance['path']
        if relative not in snapshots:
            data = guarded_path(source_input, relative).read_bytes()
            if digest(data) != provenance['file_sha256']:
                raise IdentityError('Source SQL hash mismatch')
            snapshots[relative] = data
        data = snapshots[relative]
        chunk = data[provenance['byte_offset']:provenance['byte_offset'] + provenance['byte_length']]
        if digest(chunk) != provenance['tuple_sha256'] or chunk.decode() != source['source_row']['raw_sql_row']:
            raise IdentityError('Source SQL tuple mismatch')
        pending.append((source, game))
    counts = Counter(game['sourceId'] for _, game in pending)
    bindings = []
    for source, game in pending:
        if counts[game['sourceId']] != 1:
            reasons['reverse_identity_ambiguous'] += 1
            continue
        bindings.append({'source_item_key': source['source_item_key'], 'source_table': source['table'],
                         'source_item_id': source['source_item_id'], 'source_name': source['name_source'],
                         'source_type': source['raw_fields'].get('type', source['raw_fields'].get('item_type')),
                         'source_variant': source['source_variant'], 'source_provenance': source['source_row']['provenance'],
                         'desc_token': source['raw_fields']['identified_name_id'],
                         'identified_client_name_c': identify_display(source, tables, 'c'),
                         'server_internal_label_differs': identify_display(source, tables, 'c') != source['name_source'],
                         'game_name': game['name'], 'game_source_id': str(game['sourceId']),
                         'game_type': game['type'], 'game_slot': game['slot'],
                         'game_record_sha256': record_digest(game)})
    return {'schema': 1, 'policy': 'Typed bijective identity pointers only. No stats, art, prices, crafting, source drop odds or NPC functions imported.',
            'catalog_sha256': digest(catalog_path.read_bytes()),
            'source_items_sha256': digest((source_input / 'source_items.jsonl').read_bytes()),
            'source_input_library_id': manifest['source_library_file_id'],
            'source_records_total': len(items), 'excluded_or_unresolved': dict(reasons),
            'unmatched_game_catalog_records': len(catalog) - len(bindings), 'bindings': bindings}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--source-input', type=Path, required=True)
    parser.add_argument('--desc-input', type=Path, required=True)
    args = parser.parse_args()
    document = build(args.root, args.source_input, args.desc_input)
    (args.root / 'data/l1j/source3_item_links.json').write_text(json.dumps(document, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'verified_links': len(document['bindings']), 'unresolved': document['excluded_or_unresolved']}))


if __name__ == '__main__':
    main()
