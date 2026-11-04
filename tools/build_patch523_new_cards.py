#!/usr/bin/env python3
"""Add exact new awakening-card identities without rewriting the base508 catalog."""
import argparse
import collections
import hashlib
import json
from pathlib import Path
import zipfile
from build_base508_awakenings import MAP

SOURCE_SHA256 = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'
CATEGORIES = {1: '변신', 2: '마법인형', 98: '성물'}
FLAT = {'HPPlus':'hpFlat','MPPlus':'mpFlat','Strength':'strFlat','Dexterity':'dexFlat',
        'Intelligence':'intFlat','Wisdom':'wisFlat','Constitution':'conFlat',
        'Charisma':'chaFlat','MagicResist':'mr','DamageReduction':'damage_reduction',
        'ArmorClass':'def','ArmorClassBonus':'def','PVEDamageReduction':'pve_damage_reduction',
        'MeleeEvasion':'dg','RangeEvasion':'er','PVEMeleeAdditionDamage':'pve_melee_damage'}
PRIMARY_PERCENT = {'MeleeCritical':'meleeCrit','RangeCritical':'rangedCrit','MagicCritical':'magicCrit'}

def build(source, base, output):
    if hashlib.sha256(source.read_bytes()).hexdigest() != SOURCE_SHA256:
        raise ValueError('Unreviewed source archive')
    archive = zipfile.ZipFile(source)
    hashes = {}
    def table(name):
        raw = archive.read('content/' + name + '.json')
        hashes[name] = hashlib.sha256(raw).hexdigest()
        return json.loads(raw.decode('utf-8-sig'))['rows']
    def indexed(name, key='ID'):
        rows = table(name)
        result = {r[key]: r for r in rows}
        if len(result) != len(rows): raise ValueError('Nonunique ' + name)
        return result
    cards = indexed('BuffCard'); bonuses = indexed('Bonus'); types = indexed('BonusType')
    units = indexed('Unit'); ui = indexed('UIUnit', 'UnitID')
    desc = {r['ID']:r['Description'] for r in table('DescData_Korean')}
    grades = indexed('Grade'); decks = indexed('BuffCardDeck'); assets = indexed('AssetView', 'AssetId'); asset_types = indexed('AssetType')
    entities = indexed('PolymorphEntity'); npcs = indexed('NpcClass')
    members = collections.defaultdict(list)
    for r in table('PolymorphEntityForSet'): members[r['PolymorphSetID']].append(entities[r['PolymorphEntityID']])
    buffs = collections.defaultdict(list)
    for r in table('BuffBonus'): buffs[r['BuffClassID']].append(r)
    groups = table('BuffCardOptionAwakenGroup'); links = collections.defaultdict(list)
    for r in table('BuffCardOptionAwakenLevelBonus'): links[r['BuffCardOptionAwakenGroupID']].append(r)
    known = {r['source_card_id'] for rows in json.loads(base.read_text())['catalog'].values() for r in rows}
    additions = sorted({r['BuffCardID'] for r in groups} - known)
    if len(additions) != 16: raise ValueError('New awakening card count changed')
    def effect(link):
        b = bonuses[link['BonusID']]; t = types[b['BonusTypeID']]
        return {'link':link,'bonus':b,'type':t,'unit':units[t['UnitID']],'ui_unit':ui.get(t['UnitID'],{})}
    def asset(value):
        if not value: return None
        row = assets[value]; kind = asset_types[row['AssetTypeId']]
        return {'asset_id':value,'asset_type_id':kind['ID'],'asset_type':kind['Name'],'path':kind['Path']+row['FilePath']}
    catalog = {category:[] for category in CATEGORIES.values()}
    option_defs, skill_cards, primary, secondary, bindings = [], {}, {}, {}, {}
    for card_id in additions:
        card = cards[card_id]; deck = card['BuffCardDeckID']; category = CATEGORIES[deck]
        identity = f'm523:{deck}:{card_id}'; name = desc.get(card['DescID']) or card['Name']
        grade = desc.get(grades[card['GradeID']]['DescID']) or grades[card['GradeID']]['Name']
        raw_effects = [effect(r) for r in buffs[card['BuffClassID']]]
        sprites, inworld, details, options = [], [], [], []
        record = {'name':name,'grade':grade,'type':'공통','source':'lineagem_patch523','source_snapshot':'patch523',
                  'sourceId':identity,'source_card_id':card_id,'source_deck_id':deck,'source_grade_id':card['GradeID'],
                  'source_grade_tier_id':card['GradeTierID'],'source_internal_name':card['Name'],
                  'source_display_sprite_id':card['DisplaySpriteID'],'source_original_card':card,
                  'source_stat_application':[],'sourceOptions':options,'image_path':'',
                  'source_visual_status':'patch523_original_pack_required','source_draw_pool_pending':True,
                  'source_merge_out_disabled':card['IsNoMergeOut'],'source_swap_out_disabled':card['IsNoSwapOut']}
        for e in raw_effects:
            b,t,u,link = e['bonus'],e['type'],e['unit'],e['link']
            direct = all(link[k] == 0 for k in ('CharacterLevel','CharacterClass','MinSpellLevel')) and b['BonusApplicationTypeID'] == b['BonusApplicationTargetID'] == 0
            detail = {'buff_bonus':link,'bonus':b,'bonus_type':t,'unit':u,'localized_description':desc.get(t['DescID'],''),'application':'raw_preserved_pending_semantics'}
            if direct and u['Name'] == 'Value':
                detail['application'] = 'unconditional_native_value'
                display = -b['Value'] if t['Name'] in ('ArmorClass','ArmorClassBonus') else b['Value']
                options.append((desc.get(t['DescID']) or t['Name']) + f" {display:+d}")
                if t['Name'] in FLAT:
                    key=FLAT[t['Name']];record[key]=record.get(key,0)+b['Value']
                    record['source_stat_application'].append({'field':key,'source_bonus_id':b['ID'],'rule':'Unit1_Value_direct'})
            # Reuse existing typed stat channels. HP/XP consumers store
            # fractions; the other supported percentage channels store points.
            field = PRIMARY_PERCENT.get(t['Name'], MAP.get(t['Name']))
            if direct and field and t['Name'] not in FLAT:
                amount = b['Value']; denominator = e['ui_unit'].get('Denominator', 0)
                supported = u['Name'] == 'Value'
                if u['Name'] in ('Percentage','ValuePercent','Weight') and denominator > 0:
                    amount /= denominator; supported = True
                if supported:
                    target = 'speedBonusPct' if field == 'moveSpeedPct' else field
                    stored = amount / 100 if field in ('xp','hpPct') else amount
                    record[target] = record.get(target, 0) + stored
                    record['source_stat_application'].append({'field':target,'source_bonus_id':b['ID'],
                            'rule':'typed_UIUnit_direct_fraction' if field in ('xp','hpPct') else 'typed_UIUnit_direct'})
                    if u['Name'] != 'Value':
                        options.append((desc.get(t['DescID']) or t['Name'])+f' {amount:g}'+('%' if u['Name'] in ('Percentage','ValuePercent') else ''))
            if direct and t['Name'] == 'PolymorphSetID':
                rows = members[b['Value']];sprites.extend(r['SpriteID'] for r in rows)
                inworld.append({'buff_bonus_id':link['ID'],'bonus_id':b['ID'],'bonus_type_id':t['ID'],'bonus_type_name':t['Name'],'value':b['Value'],'entities':rows})
            if t['Name'] == 'BuffCardSummonNPCClassID':
                npc = npcs[b['Value']];sprites.append(npc['Sprite'])
                inworld.append({'buff_bonus_id':link['ID'],'bonus_id':b['ID'],'bonus_type_id':t['ID'],'bonus_type_name':t['Name'],'value':b['Value'],'npc_class':npc,'conditions':{'application_type':b['BonusApplicationTypeID'],'target':b['BonusApplicationTargetID']}})
            details.append(detail)
        record['source_bonuses']=details;record['sourceOptionsRaw']=[{'type_id':e['type']['ID'],'value':e['bonus']['Value'],'unit_id':e['unit']['ID']} for e in raw_effects]
        record['source_inworld_sprite_ids']=sorted(set(sprites));record['desc']=' · '.join(options)
        record['source_ui_assets']={key:asset(card[key]) for key in ('DisplayBaseAssetID','DisplayScreenAssetID','DisplayDecoAssetID','IllustrationAssetID','HidedIllustrationAssetID')}
        record['source_original']={'source_snapshot':'patch523','card_id':card_id,'deck_id':deck,'localized_name':name,
                'grade_id':card['GradeID'],'grade_name':grade,'server_limit_set_id':card['ServerLimitSetID'],
                'start_datetime_id':card['StartDateTimeID'],'end_datetime_id':card['EndDateTimeID'],
                'buff_class_id':card['BuffClassID'],'inworld_links':inworld,'source_may_include_unused_or_event_definitions':True}
        catalog[category].append(record)
        key='source:'+identity;skill_cards[key]={'id':key,'category':category,'name':name,'grade':grade,'source_card':card,'source_snapshot':'patch523'}
        group = next(r for r in groups if r['BuffCardID']==card_id and r['SlotIndex']==1)
        effects = [effect(r) for r in links[group['ID']]];stats,applied,pending = {},[],[]
        for e in effects:
            value=e['bonus']['Value'];unit=e['unit']['Name'];den=e['ui_unit'].get('Denominator',0);field=MAP.get(e['type']['Name'])
            supported=e['link']['Level']==1 and e['bonus']['BonusApplicationTypeID']==e['bonus']['BonusApplicationTargetID']==0 and field is not None
            if unit in ('Percentage','ValuePercent','Weight') and den>0:value/=den
            elif unit!='Value':supported=False
            if isinstance(value,float) and value.is_integer():value=int(value)
            if supported:stats[field]=stats.get(field,0)+value
            e['runtime_supported']=supported
            label=(desc.get(e['type']['DescID']) or e['type']['Name'])+' '+str(value)+('%' if unit in ('Percentage','ValuePercent') else '')
            (applied if supported else pending).append(label)
        option_defs.append({'category':category,'id':key,'expected_name':name,'grade':grade,'mapping':'exact_patch523_BuffCardID_deck',
            'bonus_options':applied+pending,'applied_options':applied,'pending_options':pending,'stats':stats,
            'native_source':{'card':card,'group':group,'effects':effects,'limits':[card['ServerLimitSetID'],group['ServerLimitsetID']],
                             'secondary_groups':[r for r in groups if r['BuffCardID']==card_id and r['SlotIndex']!=1],'slot_snapshot':'patch523'}})
        if deck==2:
            primary[key]={'card':card,'effects':raw_effects}
            targets=[e for e in raw_effects if e['type']['Name']=='SubSlotBuffClassID']
            if len(targets)!=1:raise ValueError('Ambiguous new doll subslot graph')
            extra=[effect(r) for r in buffs[targets[0]['bonus']['Value']]]
            secondary[key]={'card':card,'link':targets[0],'effects':extra}
            summon=[e for e in extra if e['type']['Name']=='BuffCardSummonNPCClassID']
            if len(summon)!=1:raise ValueError('Ambiguous source subslot summon')
            npc=npcs[summon[0]['bonus']['Value']];bindings[key]={'npc_class_id':npc['ID'],'sprite_id':npc['Sprite'],'display_sprite_id':card['DisplaySpriteID'],'display_sprite_verified':npc['Sprite']==card['DisplaySpriteID']}
    limits={v for r in option_defs for v in r['native_source']['limits']}
    server=[r for r in table('ServerLimit') if r['ServerLimitSetID'] in limits]
    result={'schema':1,'source_snapshot':'patch523','source_zip_sha256':SOURCE_SHA256,'source_table_sha256':hashes,
            'catalog':catalog,'option_definitions':option_defs,'skill_cards':skill_cards,'source_server_limits':server,
            'primary_doll_buffs':primary,'subslot_buffs':secondary,'subslot_npc_bindings':bindings,
            'acquisition_policy':'registered_unowned; original gacha pool assignment remains separate',
            'visual_policy':'patch523 source pack required; no base508 pixel identity assumption'}
    output.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n')
    print(json.dumps({'cards':{k:len(v) for k,v in catalog.items()},'option_definitions':len(option_defs),'new_doll_subslots':len(secondary)}))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--source',type=Path,required=True);parser.add_argument('--base',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();build(args.source,args.base,args.output)
