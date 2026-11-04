#!/usr/bin/env python3
"""Build a small, auditable guardian projection from the validated cumulative 523 tables.
No web scraping or source archive changes. Unknown mechanics remain raw metadata.
"""
import argparse
import hashlib
import json
from pathlib import Path

GROUPS = {222: ('joe', '조우'), 232: ('atun', '아툰'), 244: ('gillian', '질리언'),
          262: ('christ', '크리스터'), 273: ('isilote', '이실로테'), 288: ('kerenis', '케레니스')}
# Only existing TWILIGHT capabilities with explicit source units. Weight (Unit44),
# PvP, target-conditioned bonuses and undefined formulas intentionally stay raw.
STATS = {1:'melee_damage:flat',2:'melee_hit:flat',3:'melee_critical_rate:percent',
         4:'magic_damage:flat',10:'ranged_damage:flat',11:'ranged_hit:flat',
         12:'ranged_critical_rate:percent',17:'max_hp:flat',18:'max_mp:flat',21:'ac:flat',
         37:'magic_hit:flat',41:'str:flat',42:'int:flat',43:'wis:flat',44:'dex:flat',
         45:'con:flat',85:'sp:flat',112:'damage_reduction:flat',4544:'pve_damage_reduction:flat',
         6612:'melee_critical_damage:flat',6622:'ranged_critical_damage:flat',6632:'magic_critical_damage:flat'}

def build(source):
    source = Path(source)
    provenance = {}
    originals = {}
    def rows(name):
        if name not in originals:
            raw = (source / (name+'.json')).read_bytes()
            originals[name] = json.loads(raw.decode('utf-8-sig'))['rows']
            provenance[name] = {'sha256':hashlib.sha256(raw).hexdigest(), 'bytes':len(raw)}
        return originals[name]
    def index(name): return {r['ID']:r for r in rows(name)}
    selected = {}
    def keep(name, row):
        selected.setdefault(name, {})[row.get('ID',row.get('TextDesc'))] = row
        return row
    def get(name, ident): return keep(name,index(name)[ident])
    desc = index('DescData_Korean')
    def description(ident):
        if not ident: return ''
        keep('DescData_Korean',desc[ident]); return desc[ident]['Description']
    bonus_index=index('Bonus'); invoke_index=index('InvokeOption'); type_index=index('BonusType')
    rewards=rows('SkillTreeSlotReward'); prerequisites=rows('SkillTreeSlotPrerequisite')
    slots=rows('SkillTreeSlot'); enchants=rows('SkillTreeSlotEnchant')
    ui_units={r["UnitID"]:r for r in rows("UIUnit")}
    groups=[]
    for category in rows('SkillTreeCategory'):
        cid=category['ID']; gid,name=GROUPS[cid];keep('SkillTreeCategory',category)
        group={'id':gid,'name':name,'category_id':cid,'server_limit_set_id':category['ServerLimitSetID'],'nodes':[]}
        for slot in slots:
            if slot['CategoryID']!=cid:continue
            keep('SkillTreeSlot',slot);sid=slot['ID']; node_rewards=[];effects={};labels=[]
            for reward in rewards:
                if reward['SlotID']!=sid:continue
                keep('SkillTreeSlotReward',reward)
                bonus=keep('Bonus',bonus_index[reward['RewardBonusID']]);bt=keep('BonusType',type_index[bonus['BonusTypeID']]);get('Unit',bt['UnitID'])
                entry={'row':reward,'bonus':bonus,'bonus_type':bt,'label':description(bt['DescID']), 'status':'deferred'}
                if reward['RewardTypeID']==14 and bonus['BonusApplicationTypeID']==0 and bonus['BonusApplicationTargetID']==0 and bonus['BonusTypeID'] in STATS and bt['UnitID'] in [1,211]:
                    key=STATS[bonus['BonusTypeID']];value=bonus['Value']*(-1 if bonus['BonusTypeID']==21 else 1)
                    entry.update({'effect_key':key,'effect_value':value,'status':'applied'})
                    if reward['Level']==0:effects[key]=effects.get(key,0)+value
                if reward['RewardTypeID']==14:
                    unit=get('Unit',bt['UnitID']);ui=keep('UIUnit',ui_units[bt['UnitID']])
                    divisor=ui['Denominator'] if unit['Name'] in ['Percentage','ValuePercent','Weight'] else 1
                    assert divisor>0
                    entry['value']=bonus['Value']/divisor
                    entry['unit']=unit
                    if bt['Name']=='CarryPlus':
                        entry.update({'effect_key':'weight_bonus:flat','effect_value':entry['value'],'status':'applied'})
                        if reward['Level']==0:effects['weight_bonus:flat']=effects.get('weight_bonus:flat',0)+entry['value']
                    elif entry['status']=='deferred':entry['status']='conditional'
                    if bonus['BonusApplicationTypeID']==2:entry['scope']=get('SpecialResistanceType',bonus['BonusApplicationTargetID'])
                    if bonus['BonusApplicationTypeID']==221:entry['scope']=get('SpellTag',bonus['BonusApplicationTargetID'])
                if reward['RewardTypeID']==24:
                    entry['status']='invoke'
                    invoke=keep('InvokeOption',invoke_index[bonus['BonusApplicationTargetID']]);it=get('InvokeOptionType',invoke['InvokeOptionTypeID'])
                    entry.update({'invoke':invoke,'invoke_type':it})
                    # Param2 of Type5 is NOT a declared spell FK. Keep it only as
                    # an explicitly labelled description candidate, never execute it.
                    spell_id=invoke['Param1'] if it['ID'] in [1,2,27] else 0
                    if it['ID']==5 and invoke['Param2'] in index('SpellClass'):
                        entry['description_spell_candidate']=get('SpellClass',invoke['Param2'])
                        entry['label']=description(entry['description_spell_candidate']['DescID'])
                    if spell_id:
                        spell=get('SpellClass',spell_id);entry['spell']=spell
                        entry['label']=description(spell['DescID'])
                elif reward['RewardTypeID']==34:
                    entry['status']='active'
                    spell=get('SpellClass',bonus['BonusApplicationTargetID']);entry['spell']=spell;entry['label']=description(spell['DescID'])
                    get('SpellMaterialType',spell['SpellMaterialTypeID'])
                if reward['Level']==0 and reward['RewardTypeID'] in [24,34]:labels.append(entry['label'])
                node_rewards.append(entry)
            parents=[]
            for pre in prerequisites:
                if pre['SlotID']==sid:
                    keep('SkillTreeSlotPrerequisite',pre);parents.append('source523_'+str(pre['PrerequisiteSlotID']))
            upgrades=[]
            for upgrade in enchants:
                if upgrade['SlotID']==sid:keep('SkillTreeSlotEnchant',upgrade);upgrades.append(upgrade)
            kind='invoke' if any(r['row']['RewardTypeID']==24 for r in node_rewards) else 'active' if any(r['row']['RewardTypeID']==34 for r in node_rewards) else 'stat'
            label=next((s for s in labels if s),' / '.join(dict.fromkeys(r['label'] for r in node_rewards if r['row']['Level']==0 and r['label'])) or name+' 능력치')
            group['nodes'].append({'id':'source523_'+str(sid),'name':label,'kind':kind,'source_slot_id':sid,'category_id':cid,'server_limit_set_id':category['ServerLimitSetID'],'ui_x':slot['UIPosX'],'ui_y':slot['UIPosY'],'prerequisites':parents,'cost':slot['ActiveCost'],'currency_id':slot['ActiveCurrencyID'],'cards':slot['ActiveCardCount'],'max_level':slot['MaxLevel'],'card_rule':'single_winner_without_replacement','effects':effects,'rewards':node_rewards,'upgrades':upgrades})
        groups.append(group)
    # Spell/temporary-buff execution uses the complete original bonus closure.
    def effect(link, table):
        keep(table,link);bonus=get('Bonus',link['BonusID']);typ=get('BonusType',bonus['BonusTypeID']);unit=get('Unit',typ['UnitID']);ui=ui_units.get(typ['UnitID'],{})
        if ui:keep('UIUnit',ui)
        divisor=ui.get('Denominator',0) if unit['Name'] in ['Percentage','ValuePercent','Weight'] else 1
        assert divisor>0
        return {'link':link,'bonus':bonus,'type':typ,'unit':unit,'ui_unit':ui,'value':bonus['Value']/divisor}
    spells={};buff_ids=set()
    for sid in list(selected['SpellClass']):
        if sid not in {e['spell']['ID'] for g in groups for n in g['nodes'] for e in n['rewards'] if 'spell' in e}:continue
        spell=get('SpellClass',sid);effects=[effect(link,'SpellBonus') for link in rows('SpellBonus') if link['SpellClassID']==sid]
        spells[str(sid)]={'source':spell,'effects':effects,'values':{e['type']['Name']:e['value'] for e in effects}}
        buff_ids.update(int(e['bonus']['Value']) for e in effects if e['type']['Name']=='BuffClassID')
        get('TargettingType',spell['TargettingTypeID']);get('TargetKind',spell['TargetKindID'])
    buffs={str(bid):{'source':get('BuffClass',bid),'effects':[effect(link,'BuffBonus') for link in rows('BuffBonus') if link['BuffClassID']==bid]} for bid in sorted(buff_ids)}
    for row in rows('SkillTreeConstant'):keep('SkillTreeConstant',row)
    get('Currency',4);get('IntangibleItemClass',2)
    for row in rows('CurrencyUnitClass'):
        if row['CurrencyID']==4:keep('CurrencyUnitClass',row)
    for row in rows('UIStaticTextData_Korean'):
        if row['TextDesc'].startswith('SKILLTREE_TOOLTIP'):keep('UIStaticTextData_Korean',row)
    for row in rows('ServerLimit'):
        if row.get('SetID',row.get('ServerLimitSetID'))==1294:keep('ServerLimit',row)
    # Tower prohibitions are map/spell metadata, never unlock/ownership prerequisites.
    get('TrialTowerBanConditionType',31);get('LandAttributeType',164)
    for unit in [4,12,11491]:get('Unit',unit)
    for bonus in list(selected['Bonus'].values()):get('BonusApplicationType',bonus['BonusApplicationTypeID'])
    for row in rows('TrialTowerBanCondition'):
        if row['TrialTowerBanConditionType']!=31:continue
        keep('TrialTowerBanCondition',row)
        attr_id=row['LandGroupAttributeID'];seen=set()
        while attr_id:
            assert attr_id not in seen
            seen.add(attr_id);attr=get('LandGroupAttribute',attr_id)
            assert attr['LandAttributeType']==164
            get('SpellClass',attr['Value'])
            attr_id=attr['LinkLandGroupAttrID']
    get('Currency',822);get('Currency',21)
    for row in rows('CurrencyUnitClass'):
        if row['CurrencyID'] in [822,21]:
            keep('CurrencyUnitClass',row);get('ItemClass',row['ClassID'])
    result={'schema':1,'source_version':523,'source_library_file_id':'libfile_f3e9e5b322cc8191ae441565bbd24c27','guardians':groups,'spells':spells,'buffs':buffs,
            'source_tables':{n:list(r.values()) for n,r in sorted(selected.items())},
            'table_provenance':{n:provenance[n] for n in sorted(selected)},
            'local_policy':{'fixed_card_deck':'Existing local save model retained; server reshuffle/reconnect rules are unverified.',
                            'server_limits':'0 preserves no nonzero list reference; 1294 remains unavailable without verified region/world semantics.',
                            'combat':'Source SpellBonus/BuffBonus and UIUnit values execute through TWILIGHT combat; no claim of original server formula equivalence.',
                            'time':'Existing TWILIGHT source-spell CastDelay convention: milliseconds. Source duration unit Seconds stays seconds.',
                            'reset':'Per-category reset costs source Currency4/1200 and refunds recorded stone spending only. Missing historical failed-enchant receipts are never fabricated.'}}
    nodes=[n for g in groups for n in g['nodes']];by_id={n['id']:n for n in nodes}
    assert len(groups)==6 and len(nodes)==172 and len(by_id)==172
    assert {g['category_id']:g['server_limit_set_id'] for g in groups}=={222:0,232:0,244:0,262:0,273:1294,288:1294}
    assert sum(len(n['upgrades']) for n in nodes)==27
    for node in nodes:
        assert {u['Level'] for u in node['upgrades']} == set(range(1,node['max_level']+1))
        for u in node['upgrades']:
            assert u['CurrencyID']==822 and u['CurrencyCost']>0 and 0<=u['Probability']<=1000000
    assert sum(len(n['rewards']) for n in nodes)==274
    for node in nodes:
        assert node['currency_id']==822 and node['cost']>0 and node['cards']>=2
        seen=set();at=node
        while at['prerequisites']:
            assert len(at['prerequisites'])==1
            at=by_id[at['prerequisites'][0]]
            assert at['category_id']==node['category_id'] and at['id'] not in seen
            seen.add(at['id'])
    # Verify every retained row equals the indexed original, with its 1-based row.
    evidence={}
    for name,chosen in selected.items():
        key='ID' if 'ID' in next(iter(chosen.values())) else 'TextDesc'
        positions={r[key]:i+1 for i,r in enumerate(rows(name))}
        evidence[name]=[{'id':r[key],'row_1based':positions[r[key]]} for r in chosen.values()]
        assert all(rows(name)[positions[r[key]]-1]==r for r in chosen.values())
    result['source_rows']=evidence
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source-dir',required=True);parser.add_argument('--output',required=True);parser.add_argument('--check',action='store_true');args=parser.parse_args()
    result=json.dumps(build(args.source_dir),ensure_ascii=False,indent=2)+'\n'
    if args.check:assert Path(args.output).read_text()==result,'projection differs from original 523 rows'
    else:Path(args.output).write_text(result)
    print('GUARDIAN_SOURCE523_OK: 6 categories, 172 slots, 274 non-sentinel rewards, 27 enchants; retained rows exact')
