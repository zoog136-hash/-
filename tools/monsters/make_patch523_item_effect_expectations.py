#!/usr/bin/env python3
"""Independent source-row expectations for the full runtime item effect test.

This creates private test input, not a replacement source or fixture catalog.
Every distinct normal equipment enchant-group combination, original level,
bless code, ammunition definition and supported passive item is covered.
"""
import argparse
import collections
import gzip
import json
from pathlib import Path
import zipfile
from build_patch523_item_catalog import read_tables
from verify_patch523_item_catalog import verify

STATS = {'WeaponHitBonus':'accuracy','WeaponDamageBonus':'damage','ArmorClass':'defense',
    'ArmorClassBonus':'defense','HPPlus':'hp','MPPlus':'mp','MagicResist':'mr','SpellPower':'sp',
    'DamageReduction':'reduction','MeleeDamage':'melee_damage','RangeDamage':'ranged_damage',
    'MeleeHit':'melee_accuracy','RangeHit':'ranged_accuracy','MagicHit':'magic_accuracy',
    'Strength':'str','Dexterity':'dex','Constitution':'con','Intelligence':'int',
    'Wisdom':'wis','Charisma':'cha','HPPotionIncreaseStatic':'potion_heal_flat'}
PASSIVES = {'RegenHP','RegenMP','AbsoluteRegenHP','AbsoluteRegenMP','AttackDrainHP',
            'AttackDrainMP','HPMPRegenOverWeight'}

def build(source, pack):
    verify(pack,source)
    tables,_=read_tables(source)
    with zipfile.ZipFile(pack) as archive:
        document=json.loads(gzip.decompress(archive.read('payload/monster_drops.bin')))
    bonuses={row['ID']:row for row in tables['Bonus']}
    types={row['ID']:row for row in tables['BonusType']}
    units={row['ID']:row['Name'] for row in tables['Unit']}
    links=collections.defaultdict(list);enchants=collections.defaultdict(list)
    for row in tables['ItemBonus']: links[row['ItemClassID']].append(row)
    for row in tables['ItemEnchantBonus']: enchants[row['ItemEnchantBonusGroupID']].append(row)
    ammo,passives,cases,seen=[],[],[],set()
    for key in document['native_item_ids']:
        record=document['item_definitions'][key]['native_record'];item_id=int(key)
        rows=links[item_id]
        if record['source_category_name'] in ('Arrow','Bullet','Sting'):
            values={types[bonuses[row['BonusID']]['BonusTypeID']]['Name']:bonuses[row['BonusID']]['Value'] for row in rows}
            supported=(values.get('WeaponSmallDamage',0)>0 and values.get('WeaponLargeDamage',0)>0
                and set(values)<={'WeaponSmallDamage','WeaponLargeDamage','AmmoEffectSpriteID','AmmoExplosionSpriteID'}
                and all(not row['IsPossession'] and bonuses[row['BonusID']]['BonusApplicationTypeID']==bonuses[row['BonusID']]['BonusApplicationTargetID']==0 for row in rows))
            ammo.append({'id':item_id,'category_id':record['source_category_id'],'supported':supported,'values':values})
        if record['slot'] in ('material','currency','consumable',''): continue
        amounts={}
        for row in rows:
            bonus=bonuses[row['BonusID']];kind=types[bonus['BonusTypeID']]
            if kind['Name'] in PASSIVES and not row['IsPossession'] and bonus['BonusApplicationTypeID']==bonus['BonusApplicationTargetID']==0 and units[kind['UnitID']] in ('Value','TrueFalse'):
                amounts[kind['Name']]=amounts.get(kind['Name'],0)+bonus['Value']
        if amounts: passives.append({'id':item_id,'effects':amounts,'expired':bool(record.get('source_delete_time_raw'))})
        groups=tuple(record.get('source_enchant_group_ids',[]))
        if not groups or groups in seen: continue
        seen.add(groups)
        levels={0,21}|{row['EnchantLevel'] for group in groups for row in enchants[group]}
        for level in sorted(levels):
            for bless in (1,2,3):
                expected={}
                for group in groups:
                    for row in enchants[group]:
                        bonus=bonuses[row['BonusID']];kind=types[bonus['BonusTypeID']];unit=units[kind['UnitID']]
                        if row['EnchantLevel']!=level or row['BlessCode'] not in (0,bless) or bonus['BonusApplicationTypeID'] or bonus['BonusApplicationTargetID']: continue
                        field=STATS.get(kind['Name']) if unit=='Value' else None;value=bonus['Value']
                        if kind['Name']=='HPPotionIncreasePercent' and unit=='Percentage':field='potion_heal_pct';value/=10000
                        if field:expected[field]=expected.get(field,0)+value
                cases.append({'id':item_id,'level':level,'bless':bless,'expected':expected})
    active=set(document['native_item_ids'])
    variants={(row['ItemClassID'],row['ItemBlessCodeID'])
        for table in ('MerchantGoods','ItemCraftInput','ItemCraftOutputView')
        for row in tables[table] if str(row['ItemClassID']) in active and row['ItemBlessCodeID'] in (2,3)}
    supplier=[{'item_class_id':item,'amount':1,'bless_raw':bless,'enchant':0}
              for item,bless in sorted(variants)]
    return {'ammo':ammo,'passives':passives,'enchantment':cases,
            'group_combinations':len(seen),'supplier_bless_grants':supplier}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('source','zip','output'):p.add_argument('--'+name,type=Path,required=True)
    args=p.parse_args()
    if args.output.resolve().is_relative_to(Path(__file__).resolve().parents[2]):p.error('private source expectations must stay outside the repository')
    value=build(args.source,args.zip)
    args.output.write_text(json.dumps(value,separators=(',',':'))+'\n')
    print(json.dumps({key:len(data) if isinstance(data,list) else data for key,data in value.items()}))

if __name__=='__main__':main()
