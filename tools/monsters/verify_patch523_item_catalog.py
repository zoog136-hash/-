#!/usr/bin/env python3
"""Verify every private ItemClass and relationship, not a sample of a shard."""
from __future__ import annotations
import argparse
import collections
from datetime import datetime
import gzip
import hashlib
import json
from pathlib import Path
import zipfile
try:
    from .build_patch523_item_catalog import read_tables
except ImportError:
    from build_patch523_item_catalog import read_tables

def sha(data): return hashlib.sha256(data).hexdigest()

def verify(path: Path, source: Path):
    tables, provenance = read_tables(source)
    originals = {str(r['ID']): r for r in tables['ItemClass']}
    groups = {}
    for name in ('ItemBonus', 'ItemEquipSlot', 'ItemClassLimit'):
        groups[name] = collections.defaultdict(list)
        for row in tables[name]: groups[name][str(row['ItemClassID'])].append(row)
    relation_counts, use_counts, problems = collections.Counter(), collections.Counter(), {}
    reference_counts, calendar_count = collections.Counter(), 0
    foreign_indexes = {}
    descriptions = {r['ID']: r['Description'].strip() for r in tables['DescData_Korean']}
    calendars = {r['ID']: r for r in tables['DateTimes_Korean']}
    def foreign_rows(table, field, value):
        token = (table, field)
        if token not in foreign_indexes:
            lookup = collections.defaultdict(list)
            for row in tables[table]:
                if field in row: lookup[row[field]].append(row)
            foreign_indexes[token] = lookup
        return foreign_indexes[token].get(value, [])
    def verify_edge(edge):
        if 'table' in edge:
            rows = foreign_rows(edge['table'], edge['target_field'], edge['value'])
            assert edge['rows'] == rows
            assert edge['status'] == ('source_rows_joined' if rows else 'source_target_not_defined')
        else:
            assert 'rows' not in edge
    seen = set()
    source_enchant = {r['ID']:r for r in tables['ItemEnchantBonus']}
    bonuses = {r['ID']:r for r in tables['Bonus']}
    with zipfile.ZipFile(path) as archive:
        assert archive.testzip() is None
        header = json.loads(archive.read('pack.json'))
        packed = archive.read('payload/monster_drops.bin')
        assert sha(packed) == header['sha256'] and len(packed) == header['bytes']
        document = json.loads(gzip.decompress(packed))
        assert document['source_tables'] == provenance
        assert document['item_shards'] == header['item_shards']
        for name, info in document['item_shards'].items():
            blob = archive.read('payload/'+name)
            assert len(blob) == info['bytes'] and sha(blob) == info['sha256']
            raw = gzip.decompress(blob)
            assert len(raw) == info['raw_bytes']
            items = json.loads(raw)['items']
            assert len(items) == info['count']
            for key, definition in items.items():
                assert key not in seen
                seen.add(key)
                assert definition['original_item'] == originals[key]
                assert document['item_shard_index'][key] == name
                summary = document['item_definitions'][key]
                record = definition['native_record']
                assert int(record['source_item_class_id']) == int(key)
                assert record['source_test_item'] == originals[key]['TestItem']
                assert record['source_is_trash'] == originals[key]['IsTrash']
                assert summary['native_record']['source_catalog_eligible'] == (int(key) != 0 and not originals[key]['TestItem'])
                item_bonuses = {row['ID']: row for row in definition.get('item_bonus', [])}
                typed = [row for row in item_bonuses.values() if row['unit']['Name'].endswith('ID')]
                edges = definition['source_direct_references']
                assert {edge['item_bonus_id'] for edge in edges} == {row['ID'] for row in typed}
                assert len(edges) == len(typed)
                for edge in edges:
                    row = item_bonuses[edge['item_bonus_id']]
                    assert (edge['bonus_id'], edge['unit'], edge['value']) == (row['BonusID'], row['unit']['Name'], row['bonus']['Value'])
                    verify_edge(edge)
                    reference_counts[edge['status']] += 1
                source_descriptions = definition['source_descriptions']
                assert set(source_descriptions) == {'DescID','IdentifiedDescID','StoryDescID','UseDescID','ProductTitleDescID','ProductDescID'}
                for field, value in source_descriptions.items():
                    source_id = originals[key][field]
                    assert value == {'id':source_id, 'text':descriptions.get(source_id,'')}
                item_edges = definition['source_item_field_references']
                assert {edge['field'] for edge in item_edges} == {field for field in originals[key] if field.endswith('ID') and field not in source_descriptions}
                for edge in item_edges:
                    assert edge['value'] == originals[key][edge['field']]
                    verify_edge(edge)
                deadline_values = []
                for joined in definition.get('source_deadline_definitions', []):
                    source_bonus = item_bonuses[joined['item_bonus_id']]['bonus']
                    if 'date_time_id' in joined:
                        assert source_bonus['Value'] == 0 and source_bonus['BonusApplicationTypeID'] == 298
                        assert joined['date_time_id'] == source_bonus['BonusApplicationTargetID']
                        assert joined['date_time_korean'] == calendars[joined['date_time_id']]
                        row = joined['date_time_korean']
                        stamp = datetime(row['Year'],row['Month'],row['Day'],row['Hour'],row['Minute'])
                        calendar_count += 1
                    else:
                        assert joined['source_literal_time'] == source_bonus['Value']
                        assert source_bonus['BonusApplicationTypeID'] == 0 and source_bonus['BonusApplicationTargetID'] == 0
                        stamp = datetime.strptime(str(source_bonus['Value']), '%Y%m%d%H')
                    deadline_values.append(int(stamp.strftime('%Y%m%d%H%M')))
                if deadline_values:
                    assert record['source_delete_time_raw'] == min(deadline_values)
                    assert summary['native_record']['source_delete_time_raw'] == min(deadline_values)
                for field, row in definition.get('source_card_window_definitions',{}).items():
                    assert row == calendars[record['source_use_spec'][field]]
                    stamp = datetime(row['Year'],row['Month'],row['Day'],row['Hour'],row['Minute'])
                    target = 'source_start_time_raw' if field == 'start_datetime_id' else 'source_end_time_raw'
                    assert record[target] == int(stamp.strftime('%Y%m%d%H%M'))
                    calendar_count += 1
                if definition.get('unresolved_source_reference'):
                    assert originals[key]['TestItem']
                    assert definition['raw_item_bonus'] == groups['ItemBonus'][key]
                    problems[key] = definition['unresolved_source_reference']
                    continue
                for table, field in [('ItemBonus','item_bonus'),('ItemEquipSlot','equip_rows'),('ItemClassLimit','class_rows')]:
                    actual = definition[field]
                    expected = groups[table][key]
                    assert len(actual) == len(expected), (key,table)
                    for row, original in zip(actual, expected):
                        assert {k:row[k] for k in original} == original
                    relation_counts[table] += len(actual)
                expected_groups = [row['bonus']['Value'] for row in definition['item_bonus']
                    if row['bonus_type']['Name']=='EnchantBonusGroupID'
                    and row['unit']['Name']=='EnchantBonusGroupID' and row['IsPossession'] is False
                    and row['bonus']['BonusApplicationTypeID']==0 and row['bonus']['BonusApplicationTargetID']==0]
                assert record.get('source_enchant_group_ids',[]) == expected_groups
                assert summary['native_record'].get('source_enchant_group_ids',[]) == expected_groups
                if not originals[key]['TestItem']:
                    spec = record.get('source_use_spec',{})
                    use_counts[spec.get('kind','none')+':'+spec.get('activation_status','none')] += 1
        enchant_seen = set()
        for group,levels in document['source_enchant_groups'].items():
            for level,rows in levels.items():
                for row in rows:
                    original = source_enchant[row[0]]
                    bonus = bonuses[row[1]]
                    assert original['ItemEnchantBonusGroupID'] == int(group)
                    assert original['EnchantLevel'] == int(level)
                    assert [original['ID'],original['BonusID'],original['BlessCode'],
                            bonus['BonusTypeID'],bonus['Value'],bonus['BonusApplicationTypeID'],
                            bonus['BonusApplicationTargetID']] == row
                    enchant_seen.add(row[0])
        assert enchant_seen == set(source_enchant)
        active = {key for key,row in originals.items() if int(key) != 0 and not row['TestItem']}
        supplier_variants = set()
        for table in ('MerchantGoods','ItemCraftInput','ItemCraftOutputView'):
            for row in tables[table]:
                if row['ItemBlessCodeID'] not in (1,2,3): continue
                key = str(row['ItemClassID'])
                assert row['ItemBlessCodeID'] in document['needed_bless_states'].get(key,[]), (table,row['ID'],'supplier_bless_variant')
                if key in active and row['ItemBlessCodeID'] in (2,3): supplier_variants.add((key,row['ItemBlessCodeID']))
        assert seen == set(originals) == set(document['item_definitions'])
        assert set(document['native_item_ids']) == active
        assert set(document['source_exclusions']) == set(originals)-active
        assert problems == document['source_reference_issues']
        assert use_counts == document['item_use_readiness']
        assert reference_counts == document['source_reference_summary']
        drop_rows = [r for rows in document['drops'].values() for r in rows]
        assert len(drop_rows) == len(tables['NpcItemDropView'])
        by_drop_id = {r['ID']:r for r in drop_rows}
        for row in tables['NpcItemDropView']:
            assert {k:by_drop_id[row['ID']][k] for k in row} == row
    return {'result':'PASS','source_tables_verified':len(provenance),
            'all_source_item_rows_verified':len(seen),'normal_catalog_rows':len(active),
            'test_rows_preserved':len(originals)-len(active),
            'normal_IsTrash_preserved':sum(originals[k]['IsTrash'] for k in active),
            'relationship_rows_verified':dict(relation_counts),
            'all_ItemBonus_rows_accounted_including_preserved_test_refs':len(tables['ItemBonus']),
            'all_enchantment_rows_verified':len(enchant_seen),
            'typed_reference_edges_verified':dict(reference_counts),
            'korean_calendar_joins_verified':calendar_count,
            'localized_description_fields_verified':6*len(seen),
            'source_supplier_nondefault_bless_variants_verified':len(supplier_variants),
            'unresolved_test_reference_count':len(problems),
            'all_original_drop_rows_verified':len(drop_rows),
            'runtime_readiness_by_source_definition':dict(use_counts),
            'zip_bytes':path.stat().st_size,'zip_sha256':sha(path.read_bytes()),
            'root_bin_sha256':header['sha256'],'shards':len(header['item_shards'])}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--zip',type=Path,required=True)
    p.add_argument('--source',type=Path,required=True)
    p.add_argument('--output',type=Path)
    a=p.parse_args(); result=verify(a.zip,a.source)
    if a.output: a.output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result,ensure_ascii=False))

if __name__ == '__main__': main()
