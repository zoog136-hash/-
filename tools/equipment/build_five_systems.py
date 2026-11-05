#!/usr/bin/env python3
"""Build a private 523 mechanics pack; never write source tables into Git.

The complete source archive stays private. The pack carries exact rows and
explicit effect support metadata, and is pinned to the validated 523 archive.
"""
import argparse
import hashlib
import importlib
import json
from pathlib import Path
import sys
import tempfile
import zipfile

SCHEMA = 'patch523-five-systems-v1'
SOURCE_SHA = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
BASE_TABLES = ['ItemClass', 'ItemBonus', 'Bonus', 'BonusType', 'DescData_Korean',
               'Grade', 'ItemCategory', 'ItemEquipSlot', 'ItemEnchantEquipGroupMapping',
               'EquipSlot', 'ItemBlessCode']
MODULES = ['five_smith_smelt', 'five_alchemy', 'five_set_invoke']

# key, source unit, divisor. Fractional host fields (XP/HP%) are distinguished
# from percentage-point fields. No Korean-name or same-integer namespace join.
FIELDS = {
    'Strength':('strFlat',1,1), 'Dexterity':('dexFlat',1,1),
    'Constitution':('conFlat',1,1), 'Intelligence':('intFlat',1,1),
    'Wisdom':('wisFlat',1,1), 'Charisma':('chaFlat',1,1),
    'ArmorClass':('def',1,1), 'HPPlus':('hpFlat',1,1), 'MPPlus':('mpFlat',1,1),
    'WeaponDamageBonus':('additionalDamage',1,1), 'WeaponHitBonus':('hit',1,1),
    'MeleeDamage':('meleeDamage',1,1), 'RangeDamage':('rangedDamage',1,1),
    'MagicDamage':('magicDamage',1,1), 'MeleeHit':('meleeHit',1,1),
    'RangeHit':('rangedHit',1,1), 'MagicHit':('magicHit',1,1),
    'MagicResist':('mr',1,1), 'SpellPower':('sp',1,1),
    'DamageReduction':('damage_reduction',1,1),
    'PVEDamageReduction':('pve_damage_reduction',1,1),
    'PVPDamageReduction':('pve_damage_reduction',1,1),
    'PVPDamageReductionPercent':('pve_damage_reduction_pct',3,10000),
    'PVPPierceDamageReductionPercent':('damage_amp_pct',3,10000),
    'PVEDamageReductionPercent':('pve_damage_reduction_pct',3,10000),
    'PVEPierceDamageReductionPercent':('damage_amp_pct',3,10000),
    'HPPotionIncreaseStatic':('potionHealFlat',1,1),
    'HPPotionIncreasePercent':('potionHealPct',3,10000),
    'ExperienceAdditionPercent':('xp',3,1000000),
    'CarryPlus':('weightBonus',44,100),
    'AttackSpeedBonus':('attackSpeed',3,10000),
    'MoveSpeedBonus':('speedBonusPct',3,10000),
    'PierceDamageReduction':('damage_reduction_ignore',1,1),
    'HPPlusPercent':('hpPct',211,100), 'MPPlusPercent':('mpPct',211,100),
    'ElementalCriticalProbability':('equipment523_element_crit_pct',3,10000),
    'ElementalCriticalResistance':('equipment523_element_crit_resist_pct',3,10000),
    'ElementalDamageReduction':('equipment523_element_reduction',1,1),
    'MeleeCriticalResist':('equipment523_melee_crit_resist_pct',3,10000),
    'RangeCriticalResist':('equipment523_ranged_crit_resist_pct',3,10000),
    'CriticalDamageReduction':('equipment523_critical_reduction',1,1),
    'HPHealIncreasePercent':('equipment523_heal_pct',3,10000),
    'RegenHP':('equipment523_regen_hp',1,1),
    'RegenMP':('equipment523_regen_mp',1,1),
    'KarmaLife':('equipment523_lfe',1,1),
    'KarmaDeath':('equipment523_dth',1,1),
}
ELEMENTS = {1:'fire', 2:'water', 3:'wind', 4:'earth'}
SELECTORS = {'WeaponType', 'EnchantEquipGroupID', 'ItemInvokeReplacementID',
             'ScrollElementalSmith', 'ScrollElementalType', 'SpiritSmelt',
             'SmeltExpireDate', 'DeleteTime', 'GuaranteeBlessProb'}


def effect(raw, kind, descriptions):
    name, unit = kind['Name'], kind['UnitID']
    application, target = raw['BonusApplicationTypeID'], raw['BonusApplicationTargetID']
    record, supported = {}, False
    if name == 'None' and raw['Value'] == 0:
        supported = True
    elif name in FIELDS and application == 0 and target == 0:
        key, expected_unit, divisor = FIELDS[name]
        if unit == expected_unit:
            record[key] = raw['Value'] / divisor
            supported = True
    elif name in ('OptionalElementalDamage', 'ElementalDamage', 'ElementalResistance','ElementalPierce') and application == 3 and target in ELEMENTS:
        expected = 3 if name in ('ElementalResistance','ElementalPierce') else 1
        if unit == expected:
            prefix = 'element_resist_' if name == 'ElementalResistance' else 'equipment523_element_pierce_' if name == 'ElementalPierce' else 'equipment523_element_flat_'
            key = prefix + ELEMENTS[target]
            record[key] = raw['Value'] / (10000 if unit == 3 else 1)
            supported = True
    elif name in ('SpecialResistance', 'HitSpecialResistance') and application == 2 and target == 6 and unit == 3:
        record['stun_resistance' if name == 'SpecialResistance' else 'stun_accuracy'] = raw['Value'] / 10000
        supported = True
    return {'raw':raw, 'type':kind, 'name':name,
            'description':descriptions.get(kind.get('DescID', 0), name),
            'record':record, 'supported':supported}


def read_tables(content, names):
    tables = {}
    for name in sorted(names):
        path = content / (name + '.json')
        value = json.loads(path.read_text(encoding='utf-8-sig'))
        if not isinstance(value, dict) or not isinstance(value.get('rows'), list):
            raise ValueError('invalid original table: ' + name)
        tables[name] = value['rows']
    return tables


def compile_pack(content, catalog, source_sha=SOURCE_SHA):
    modules = [importlib.import_module(name) for name in MODULES]
    names = set(BASE_TABLES)
    for module in modules:
        names.update(module.TABLES)
    tables = read_tables(content, names)
    original_counts = {n:len(v) for n,v in tables.items()}
    summaries = {module.__name__:module.validate(tables) for module in modules}
    descriptions = {r['ID']:r['Description'].strip() for r in tables['DescData_Korean']}
    types = {r['ID']:r for r in tables['BonusType']}
    raw_bonuses = {r['ID']:r for r in tables['Bonus']}
    # Validate complete originals above, then ship only the spell/buff graph
    # referenced by these domains. Unrelated spell catalogs stay in the source.
    direct_ids = {r['BonusID'] for name, rows in tables.items()
                  if name not in ['ItemBonus','Bonus','SpellBonus','BuffBonus']
                  for r in rows if r.get('BonusID', 0)}
    invoke_ids = {raw_bonuses[i]['BonusApplicationTargetID'] for i in direct_ids
                  if types[raw_bonuses[i]['BonusTypeID']]['Name'] == 'InvokeOption'}
    if 'InvokeOption' in tables:
        tables['InvokeOption'] = [r for r in tables['InvokeOption'] if r['ID'] in invoke_ids]
    spell_ids = {r['Param1'] for r in tables.get('InvokeOption', []) if r.get('InvokeOptionTypeID') == 1}
    if 'SpellClass' in tables:
        tables['SpellClass'] = [r for r in tables['SpellClass'] if r['ID'] in spell_ids]
        tables['SpellBonus'] = [r for r in tables['SpellBonus'] if r['SpellClassID'] in spell_ids]
    buff_ids = {raw_bonuses[i]['Value'] for i in direct_ids
                if types[raw_bonuses[i]['BonusTypeID']]['Name'] == 'BuffClassID'}
    if 'BuffClass' in tables:
        tables['BuffClass'] = [r for r in tables['BuffClass'] if r['ID'] in buff_ids]
        tables['BuffBonus'] = [r for r in tables['BuffBonus'] if r['BuffClassID'] in buff_ids]
    material_bonus_ids = {r['ID'] for r in tables['Bonus'] if types[r['BonusTypeID']]['Name'] in
                          {'ScrollElementalSmith','ScrollElementalType','SpiritSmelt'}}
    item_ids = {r['ItemClassID'] for name, values in tables.items()
                if name not in ['ItemBonus','ItemClass'] for r in values if r.get('ItemClassID', 0)}
    item_ids.update(r['ItemClassID'] for r in tables['ItemBonus'] if r['BonusID'] in material_bonus_ids)
    item_ids.update(r['ID'] for r in tables['ItemClass'] if r.get('CategoryID') == 151)
    item_ids.update({169994,170004,289162})
    retained = {r['BonusID'] for r in tables['ItemBonus'] if r['ItemClassID'] in item_ids
                and types[raw_bonuses[r['BonusID']]['BonusTypeID']]['Name'] in SELECTORS}
    for name, rows in tables.items():
        if name in ['ItemBonus', 'Bonus']:
            continue
        for row in rows:
            if row.get('BonusID', 0):
                retained.add(row['BonusID'])
    bonuses = {str(i):effect(raw_bonuses[i], types[raw_bonuses[i]['BonusTypeID']], descriptions)
               for i in sorted(retained)}
    items = {}
    # Exclude unrelated cosmetic/sales prose while retaining every eligibility,
    # level, category, stack, weight and test qualifier used by these actions.
    item_fields = ['ID','Name','DescID','IdentifiedDescID','CategoryID','GradeID','TestItem',
                   'Weight','MaxStackAmount','LevelLimitMin','LevelLimitMax','Cost',
                   'IsTradable','IsStorable','IsDeletable','IsDroppable','GradeTierID']
    for raw in tables['ItemClass']:
        if raw['ID'] not in item_ids:
            continue
        names_for_item = list(dict.fromkeys(descriptions.get(raw.get(k, 0), '') for k in ['DescID','IdentifiedDescID']))
        items[str(raw['ID'])] = {'raw':{k:raw[k] for k in item_fields if k in raw},
                                 'name':next((n for n in names_for_item if n), raw['Name']),
                                 'names':[n for n in names_for_item if n]}
    bindings = {}
    for row in catalog.get('아이템', []):
        identity = str(row.get('sourceId', ''))
        integer = identity.removeprefix('m523:item:')
        if not integer.isdecimal() or integer not in items:
            continue
        item = items[integer]
        if row.get('name') in item['names'] and not item['raw'].get('TestItem', False):
            bindings[identity] = {'source_id':int(integer), 'name':row['name']}
    excluded = {'DescData_Korean', 'UIStaticTextData_Korean', 'ItemClass', 'Bonus', 'BonusType'}
    exported = {name:rows for name, rows in tables.items() if name not in excluded}
    exported['ItemBonus'] = [r for r in tables['ItemBonus'] if r['ItemClassID'] in item_ids and r['BonusID'] in retained]
    exported['Bonus'] = [raw_bonuses[i] for i in sorted(retained)]
    used_types = {r['BonusTypeID'] for r in exported['Bonus']}
    exported['BonusType'] = [types[i] for i in sorted(used_types)]
    exported['ItemClass'] = [item['raw'] for item in items.values()]
    return {'schema':SCHEMA, 'source_sha256':source_sha, 'tables':exported,
            'items':items, 'bonuses':bonuses, 'bindings':bindings,
            'audit':{'domains':summaries, 'original_row_counts':original_counts,
                     'table_sha256':{n:hashlib.sha256((content/(n+'.json')).read_bytes()).hexdigest() for n in sorted(names)},
                     'supported_numeric_bonus_count':sum(b['supported'] for b in bonuses.values()),
                     'unsupported_bonus_count':sum(not b['supported'] for b in bonuses.values()),
                     'binding_count':len(bindings), 'source_execution_equivalent':False}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--content', type=Path, help='Optional existing extraction; every used byte is checked against the ZIP')
    parser.add_argument('--source-zip', type=Path, required=True)
    parser.add_argument('--catalog', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    if args.output.resolve().is_relative_to(root):
        raise ValueError('private pack must be outside the public repository')
    digest = hashlib.sha256(args.source_zip.read_bytes()).hexdigest()
    if digest != SOURCE_SHA:
        raise ValueError('validated 523 archive SHA mismatch')
    with zipfile.ZipFile(args.source_zip) as archive:
        if archive.testzip() is not None:
            raise ValueError('source ZIP CRC mismatch')
        modules = [importlib.import_module(name) for name in MODULES]
        names = set(BASE_TABLES)
        for module in modules:
            names.update(module.TABLES)
        with tempfile.TemporaryDirectory(prefix='equipment523-source-') as temporary:
            content = args.content or Path(temporary)
            for name in sorted(names):
                member = 'content/' + name + '.json'
                if archive.namelist().count(member) != 1:
                    raise ValueError('ambiguous or missing original table: ' + name)
                original_bytes = archive.read(member)
                if args.content:
                    if (content / (name+'.json')).read_bytes() != original_bytes:
                        raise ValueError('extracted table differs from validated ZIP: ' + name)
                else:
                    (content / (name+'.json')).write_bytes(original_bytes)
            pack = compile_pack(content, json.loads(args.catalog.read_text()))
    data = (json.dumps(pack, ensure_ascii=False, separators=(',',':'))+'\n').encode()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output.with_suffix('.tmp')
    temporary.write_bytes(data)
    temporary.replace(args.output)
    print(json.dumps({'path':str(args.output),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),
                      'bindings':len(pack['bindings']), 'source_zip_sha256':digest,
                      'source_execution_equivalent':False}, ensure_ascii=False))


if __name__ == '__main__':
    main()
