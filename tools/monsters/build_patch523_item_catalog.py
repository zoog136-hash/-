#!/usr/bin/env python3
"""Full ItemClass replacement: compact runtime index + exact private sidecars.

Membership/rates are still the existing drop compiler's responsibility. An item
being catalogued never creates a new monster drop, shop price or recipe.
"""
from __future__ import annotations
import argparse
import collections
from datetime import datetime
from copy import deepcopy
import gzip
import hashlib
import json
from pathlib import Path
import zipfile
import zlib
try:
    from .build_patch523_monster_drops import TABLES, compile_pack as compile_drops
    from .patch523_item_definitions import compile_items
    from .patch523_item_icons import compile_icon_links, attach_icon_links, compact_icon_index
except ImportError:
    from build_patch523_monster_drops import TABLES, compile_pack as compile_drops
    from patch523_item_definitions import compile_items
    from patch523_item_icons import compile_icon_links, attach_icon_links, compact_icon_index

ACQUISITION_TABLES = ('MerchantGoods', 'ItemCraftInput', 'ItemCraftOutputView')
EXTRA_TABLES = (*ACQUISITION_TABLES, 'DateTimes_Korean', 'ItemEnchantBonus', 'Icon', 'AssetView')
KIND = 'patch523_monster_drop_membership'
IDENTITY = ('name', 'source', 'sourceId', 'sourceUrl', 'slot', 'type', 'grade')
OMIT = {'source_mapped_bonuses', 'source_unhandled_bonuses',
        'source_unhandled_bonus_ids', 'source_effect_scope', 'source_use_spec',
        'source_acquisition_policy', 'source_weight_unit', 'desc', 'source_icon_identity'}

def encoded(value):
    return (json.dumps(value, ensure_ascii=False, separators=(',', ':'))+'\n').encode()

def sha(value):
    return hashlib.sha256(value).hexdigest()

EXTERNAL_DOMAINS = {'CastleClassID','ClanMemberRankID','ClanRewardOnItemUseID',
                    'CompetitionDungeonID','QuestID'}
REFERENCE_ALIASES = {'DescID':('DescData_Korean','ID'),
    'BuffDeckID':('BuffCardDeck','ID'),
    'CategoryID':('ItemCategory','ID'),
    'IdentifiedDescID':('DescData_Korean','ID'),
    'StoryDescID':('DescData_Korean','ID'), 'UseDescID':('DescData_Korean','ID'),
    'ProductTitleDescID':('DescData_Korean','ID'), 'ProductDescID':('DescData_Korean','ID'),
    'EnchantBonusGroupID':('ItemEnchantBonus','ItemEnchantBonusGroupID'),
    'ItemEnchantEquipGroupID':('ItemEnchantEquipGroupMapping','ItemEnchantEquipGroupID'),
    'ItemConsumeRateGourpID':('ItemConsumeRate','ItemConsumeRateGroupID')}

def read_tables(source):
    index = {r['path']: r for r in json.loads((source/'index.json').read_text(encoding='utf-8-sig'))}
    tables, provenance = {}, {}
    for name in dict.fromkeys((*TABLES, *EXTRA_TABLES)):
        path = 'content/'+name+'.json'
        entry = index[path]
        raw = (source/path).read_bytes()
        rows = json.loads(raw.decode('utf-8-sig'))['rows']
        if (len(raw) != entry['bytes'] or sha(raw) != entry['sha256']
                or f'{zlib.crc32(raw):08x}' != entry['crc32'] or len(rows) != entry['row_count']):
            raise ValueError('source index mismatch: '+name)
        tables[name], provenance[name] = rows, entry
    units = {r['ID']:r['Name'] for r in tables['Unit']}
    kinds = {r['ID']:units[r['UnitID']] for r in tables['BonusType']}
    bonuses = {r['ID']:kinds[r['BonusTypeID']] for r in tables['Bonus']}
    used_units = {bonuses[r['BonusID']] for r in tables['ItemBonus']}
    used_units.update(k for row in tables['ItemClass'] for k in row if k.endswith('ID'))
    available = {Path(path).stem.lower():Path(path).stem for path in index}
    for unit in sorted(used_units):
        if not unit.endswith('ID') or unit in EXTERNAL_DOMAINS: continue
        table = REFERENCE_ALIASES.get(unit, (available.get(unit[:-2].lower()),'ID'))[0]
        if not table or table in tables: continue
        path = 'content/'+table+'.json'
        entry = index[path];raw = (source/path).read_bytes()
        rows = json.loads(raw.decode('utf-8-sig'))['rows']
        if (len(raw) != entry['bytes'] or sha(raw) != entry['sha256']
                or f'{zlib.crc32(raw):08x}' != entry['crc32'] or len(rows) != entry['row_count']):
            raise ValueError('source index mismatch: '+table)
        tables[table], provenance[table] = rows, entry
    return tables, provenance

def compact(definition):
    record = {k: deepcopy(v) for k, v in definition['native_record'].items() if k not in OMIT}
    spec = definition['native_record'].get('source_use_spec', {})
    if spec:
        record['source_use_summary'] = {k: deepcopy(spec[k]) for k in
            ('kind', 'activation_status', 'blocked_reasons', 'card_kind',
             'card_id', 'spell_class_id', 'local_rule_required') if k in spec}
    record['source_unhandled_count'] = len(definition['native_record'].get('source_unhandled_bonuses', []))
    return {'native_record': record,
            'original_item': {k: definition['original_item'][k] for k in ('TestItem',)}}

def compile_full(source: Path, catalog: Path):
    document = compile_drops(source, catalog)
    tables, provenance = read_tables(source)
    descriptions = {r['ID']: r['Description'].strip() for r in tables['DescData_Korean']}
    item_rows = {r['ID']: r for r in tables['ItemClass']}
    date_rows = {r['ID']: r for r in tables['DateTimes_Korean']}
    def normalized_date(row):
        stamp = datetime(row['Year'], row['Month'], row['Day'], row['Hour'], row['Minute'])
        return int(stamp.strftime('%Y%m%d%H%M'))
    definitions = compile_items(tables, descriptions, set(item_rows), {}, preserve_unresolved=True)
    icon_links = compile_icon_links(tables)
    attach_icon_links(definitions, icon_links)
    document["source_icon_index"] = compact_icon_index(icon_links)
    references = collections.defaultdict(collections.Counter)
    for name in ('NpcItemDropView', *ACQUISITION_TABLES):
        for row in tables[name]:
            references[str(row['ItemClassID'])][name] += 1
    states = collections.defaultdict(set)
    for row in tables['NpcItemDropView']:
        states[str(row['ItemClassID'])].add(row['Bless'])
    # Shop and crafting suppliers carry their own exact blessing codes. A
    # non-drop variant must remain addressable without changing its identity.
    for name in ACQUISITION_TABLES:
        for row in tables[name]:
            if row.get('ItemBlessCodeID') in (1,2,3):
                states[str(row['ItemClassID'])].add(row['ItemBlessCodeID'])
    uses, readiness, excluded, issues = collections.Counter(), collections.Counter(), {}, {}
    ready_reward_ids = set()
    for key, definition in definitions.items():
        original, record = definition['original_item'], definition['native_record']
        dates = [row for row in definition.get('item_bonus', [])
                 if row['bonus_type']['Name'] == 'DeleteTime']
        if dates:
            try:
                encoded_dates, joined = [], []
                for row in dates:
                    value = row['bonus']['Value']
                    if row.get('IsPossession') is not False or row['unit']['Name'] != 'Time':
                        raise ValueError('unsupported_delete_time_unit_or_possession')
                    application = row['bonus'].get('BonusApplicationTypeID')
                    target = row['bonus'].get('BonusApplicationTargetID')
                    if application == 298 and value == 0:
                        calendar = date_rows.get(target)
                        if calendar is None: raise ValueError('missing_korean_date_time')
                        encoded_dates.append(normalized_date(calendar))
                        joined.append({'item_bonus_id':row['ID'], 'date_time_id':target,
                                       'date_time_korean':deepcopy(calendar)})
                    elif application == 0 and target == 0 and type(value) is int and len(str(value)) == 10:
                        encoded_dates.append(int(datetime.strptime(str(value), '%Y%m%d%H').strftime('%Y%m%d%H%M')))
                        joined.append({'item_bonus_id':row['ID'],'source_literal_time':value})
                    else:
                        raise ValueError('unsupported_delete_time_reference')
                record['source_delete_time_raw'] = min(encoded_dates)
                definition['source_deadline_definitions'] = joined
            except ValueError:
                record['source_delete_time_unresolved'] = True
        spec = record.get('source_use_spec', {})
        reasons = spec.get('blocked_reasons', [])
        resolved_reasons = set()
        if dates and not record.get('source_delete_time_unresolved'):
            resolved_reasons.update({'source_item_lifetime_unresolved',
                                    'conditional_or_possession_item_bonus:DeleteTime'})
        window_ids = [('start_datetime_id','source_start_time_raw'),
                      ('end_datetime_id','source_end_time_raw')]
        if any(spec.get(key,0) for key,_ in window_ids):
            window = {}
            for key,field in window_ids:
                date_id = spec.get(key,0)
                if date_id:
                    if date_id not in date_rows: break
                    record[field] = normalized_date(date_rows[date_id])
                    window[key] = deepcopy(date_rows[date_id])
            else:
                resolved_reasons.add('source_date_window_unresolved')
                definition['source_card_window_definitions'] = window
                if spec.get('activation_status') == 'source_date_window_unresolved':
                    spec['activation_status'] = ('server_context_required' if spec.get('server_limit_set_id')
                                                 else 'unrestricted')
        if reasons and set(reasons) <= resolved_reasons:
            spec['activation_status'] = 'unrestricted'
            spec['blocked_reasons'] = []
            spec['deadline_evaluated_at_use'] = True
            record['source_unhandled_bonuses'] = []
            record['source_unhandled_bonus_ids'] = []
            record['source_effect_status'] = 'represented_source_fields'
        record['source_acquisition_tables'] = sorted(references[key])
        record['source_catalog_eligible'] = int(key) != 0 and not original['TestItem']
        record['source_acquisition_policy'] = 'verified_supplier_only_no_fabricated_supply'
        if not record['source_catalog_eligible']:
            excluded[key] = 'source_none_sentinel' if int(key) == 0 else 'source_TestItem_true'
        if definition.get('unresolved_source_reference'):
            issues[key] = definition['unresolved_source_reference']
        spec = record.get('source_use_spec', {})
        if not original['TestItem']:
            readiness[spec.get('kind', 'none')+':'+spec.get('activation_status', 'none')] += 1
            if spec.get('activation_status') == 'unrestricted':
                uses[spec['kind']] += 1
        for reward in spec.get('rewards', []):
            if spec.get('activation_status') == 'unrestricted':
                states[str(reward['item_class_id'])].add(reward['bless_raw'])
                ready_reward_ids.add(str(reward['item_class_id']))
    bonus_index = {r['ID']:r for r in tables['Bonus']}
    type_index = {r['ID']:r for r in tables['BonusType']}
    unit_index = {r['ID']:r['Name'] for r in tables['Unit']}
    enchant_groups, enchant_types = {}, {}
    stat_names = {'WeaponHitBonus':'accuracy', 'WeaponDamageBonus':'damage',
                  'ArmorClass':'defense', 'ArmorClassBonus':'defense',
                  'HPPlus':'hp', 'MPPlus':'mp', 'MagicResist':'mr', 'SpellPower':'sp',
                  'DamageReduction':'reduction', 'MeleeDamage':'melee_damage',
                  'RangeDamage':'ranged_damage', 'MeleeHit':'melee_accuracy',
                  'RangeHit':'ranged_accuracy', 'MagicHit':'magic_accuracy',
                  'Strength':'str', 'Dexterity':'dex', 'Constitution':'con',
                  'Intelligence':'int', 'Wisdom':'wis', 'Charisma':'cha',
                  'HPPotionIncreaseStatic':'potion_heal_flat'}
    for row in tables['ItemEnchantBonus']:
        bonus = bonus_index[row['BonusID']]
        kind = type_index[bonus['BonusTypeID']]
        unit = unit_index[kind['UnitID']]
        stat = stat_names.get(kind['Name'],'') if unit == 'Value' else ''
        divisor = 1
        if kind['Name'] == 'HPPotionIncreasePercent' and unit == 'Percentage':
            stat, divisor = 'potion_heal_pct', 10000
        enchant_types[str(kind['ID'])] = {'name':kind['Name'],'unit':unit,'stat':stat,'divisor':divisor}
        group = enchant_groups.setdefault(str(row['ItemEnchantBonusGroupID']),{})
        group.setdefault(str(row['EnchantLevel']),[]).append([
            row['ID'], row['BonusID'], row['BlessCode'], kind['ID'], bonus['Value'],
            bonus['BonusApplicationTypeID'], bonus['BonusApplicationTargetID']])
    for definition in definitions.values():
        ids = [row['bonus']['Value'] for row in definition.get('item_bonus',[])
               if row['bonus_type']['Name'] == 'EnchantBonusGroupID'
               and row['unit']['Name'] == 'EnchantBonusGroupID'
               and row.get('IsPossession') is False
               and row['bonus']['BonusApplicationTypeID'] == 0
               and row['bonus']['BonusApplicationTargetID'] == 0]
        if ids: definition['native_record']['source_enchant_group_ids'] = ids
    units = {r['ID']:r['Name'] for r in tables['Unit']}
    available = {name.lower():name for name in tables}
    reference_indexes = {}
    reference_summary = collections.Counter()
    for definition in definitions.values():
        links = []
        for row in definition.get('item_bonus',[]):
            unit, value = row['unit']['Name'], row['bonus']['Value']
            if not unit.endswith('ID'): continue
            edge = {'item_bonus_id':row['ID'],'bonus_id':row['BonusID'],
                    'unit':unit,'value':value}
            if unit in EXTERNAL_DOMAINS:
                edge['status'] = 'external_owner_or_excluded_domain_preserved'
            else:
                table, field = REFERENCE_ALIASES.get(unit,(available.get(unit[:-2].lower()),'ID'))
                if not table:
                    edge['status'] = 'opaque_typed_reference_preserved'
                else:
                    token = (table,field)
                    if token not in reference_indexes:
                        lookup = collections.defaultdict(list)
                        for original in tables[table]:
                            if field in original: lookup[original[field]].append(original)
                        reference_indexes[token] = lookup
                    edge.update(table=table,target_field=field,
                                rows=deepcopy(reference_indexes[token].get(value,[])))
                    edge['status'] = 'source_rows_joined' if edge['rows'] else 'source_target_not_defined'
            reference_summary[edge['status']] += 1
            links.append(edge)
        definition['source_direct_references'] = links
        definition['source_descriptions'] = {
            field:{'id':definition['original_item'][field],
                   'text':descriptions.get(definition['original_item'][field],'')}
            for field in ('DescID','IdentifiedDescID','StoryDescID','UseDescID',
                          'ProductTitleDescID','ProductDescID')}
        original_links = []
        for field,value in definition['original_item'].items():
            if not field.endswith('ID') or field in definition['source_descriptions']: continue
            table,target_field = REFERENCE_ALIASES.get(field,(available.get(field[:-2].lower()),'ID'))
            edge = {'field':field,'value':value}
            if not table:
                edge['status'] = 'external_resource_identifier' if field in ('IconID','SpriteID') else 'opaque_source_identifier_preserved'
            else:
                token = (table,target_field)
                if token not in reference_indexes:
                    lookup = collections.defaultdict(list)
                    for original in tables[table]:
                        if target_field in original: lookup[original[target_field]].append(original)
                    reference_indexes[token] = lookup
                edge.update(table=table,target_field=target_field,
                            rows=deepcopy(reference_indexes[token].get(value,[])))
                edge['status'] = 'source_rows_joined' if edge['rows'] else 'source_target_not_defined'
            original_links.append(edge)
        definition['source_item_field_references'] = original_links
    # Reviewed exact ID + URL + original localized descriptor; no name-only join.
    aliases, unbound = {}, {}
    game = json.loads(catalog.read_text(encoding='utf-8-sig'))['아이템']
    names = collections.Counter(r['name'] for r in game)
    ids = collections.Counter(str(r.get('sourceId', '')) for r in game)
    for old in game:
        key = str(old.get('sourceId', ''))
        source = item_rows.get(int(key)) if key.isdigit() else None
        if (old.get('source') != 'inven' or not source or ids[key] != 1 or names[old['name']] != 1
                or old.get('sourceUrl') != 'https://lineagem.inven.co.kr/db/item/'+key
                or old['name'].strip() not in {descriptions.get(source['DescID'], ''),
                                              descriptions.get(source['IdentifiedDescID'], '')}
                or source['TestItem']):
            unbound[key or old['name']] = 'no_reviewed_exact_source_identity_preserve_owned_legacy'
            continue
        canonical = definitions[key]['native_record']
        alias = {k: canonical.get(k, '') for k in IDENTITY}
        alias.update(name=old['name'], sourceId=key, sourceUrl=old['sourceUrl'])
        aliases[key] = {'original_identity': {k: old.get(k, '') for k in IDENTITY},
                        'identity': alias}
        definitions[key]['existing_binding'] = deepcopy(aliases[key]['original_identity'])
        if key in document['bindings']:
            document['bindings'][key] = deepcopy(alias)
    document.update(schema=3, source_tables=provenance,
                    item_definitions={k: compact(v) for k, v in definitions.items()},
                    native_item_ids=[k for k, v in definitions.items() if v['native_record']['source_catalog_eligible']],
                    native_reward_item_ids=[], catalog_aliases=aliases,
                    legacy_unresolved_catalog=unbound,
                    source_exclusions=excluded, source_reference_issues=issues,
                    needed_bless_states={k: sorted(s & {1, 2, 3}) for k, s in states.items()},
                    item_use_counts=dict(uses), item_use_readiness=dict(readiness),
                    acquisition_reference_counts={k: dict(v) for k, v in references.items()},
                    full_item_catalog=True, source_reference_summary=dict(reference_summary),
                    source_enchant_groups=enchant_groups,
                    source_enchant_bonus_types=enchant_types,
                    source_acquisition_policy='verified_supplier_only_no_fabricated_supply')
    document['counts'].update(item_definitions=len(definitions),
        source_item_class_rows=len(item_rows),
        full_catalog_non_drop_rows=len(set(definitions)-set(document['bindings'])),
        reward_definition_closure=len(ready_reward_ids-set(document['bindings'])),
        catalog_items=len(document['native_item_ids']),
        source_test_items=sum(r['TestItem'] for r in item_rows.values()),
        source_is_trash_items=sum(r['IsTrash'] for r in item_rows.values()),
        non_test_is_trash_preserved=sum(r['IsTrash'] and not r['TestItem'] for r in item_rows.values()),
        original_none_sentinels=1 if 0 in item_rows else 0,
        exact_legacy_aliases=len(aliases), preserved_unresolved_legacy=len(unbound),
        unresolved_source_references=len(issues), source_enchant_bonus_rows=len(tables['ItemEnchantBonus']))
    return document, definitions

def write_full(document, definitions, output: Path, chunk_size: int = 256):
    output.mkdir(parents=True, exist_ok=True)
    blobs, index, locations = {}, {}, {}
    keys = sorted(definitions, key=int)
    for start in range(0, len(keys), chunk_size):
        subset = {k: definitions[k] for k in keys[start:start+chunk_size]}
        relative = 'items/%04d.bin' % (start//chunk_size)
        raw = encoded({'schema': 1, 'kind': 'patch523_item_definitions', 'items': subset})
        if len(raw) > 16*1024*1024: raise ValueError('item shard exceeds bounded raw size')
        packed = gzip.compress(raw, mtime=0)
        blobs[relative] = packed
        index[relative] = {'sha256': sha(packed), 'bytes': len(packed), 'raw_bytes': len(raw), 'count': len(subset)}
        locations.update({k: relative for k in subset})
    document.update(item_shards=index, item_shard_index=locations)
    raw = encoded(document)
    if len(raw) > 64*1024*1024: raise ValueError('catalog index exceeds 64MiB')
    root = gzip.compress(raw, mtime=0)
    if len(root) > 8*1024*1024: raise ValueError('catalog compressed index exceeds 8MiB')
    (output/'monster_drops.bin').write_bytes(root)
    for name, packed in blobs.items():
        path = output/name
        path.parent.mkdir(exist_ok=True)
        path.write_bytes(packed)
    header = {'schema': 3, 'kind': KIND, 'source_snapshot': 'patch523',
              'sha256': sha(root), 'bytes': len(root), 'raw_bytes': len(raw),
              'counts': document['counts'], 'item_shards': index}
    (output/'manifest.json').write_bytes(encoded(header))
    with zipfile.ZipFile(output/'TWILIGHT_patch523_monster_drops.zip', 'w') as archive:
        for name, blob in [('pack.json', encoded(header)), ('payload/monster_drops.bin', root),
                           *[('payload/'+name, value) for name, value in blobs.items()]]:
            entry = zipfile.ZipInfo(name, (2026, 11, 4, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, blob)
    return header

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for key in ('source', 'catalog', 'output'): parser.add_argument('--'+key, type=Path, required=True)
    args = parser.parse_args()
    if args.output.resolve().is_relative_to(Path(__file__).resolve().parents[2]):
        parser.error('private source-derived item pack must stay outside the repository')
    document, definitions = compile_full(args.source, args.catalog)
    header = write_full(document, definitions, args.output)
    print(json.dumps({k: v for k, v in header.items() if k != 'item_shards'}, ensure_ascii=False))

if __name__ == '__main__': main()
