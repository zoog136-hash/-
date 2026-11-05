#!/usr/bin/env python3
"""Join exact native IDs. Read-only source ZIP; no save migration or art generation."""
import argparse, collections, hashlib, json, pathlib, zipfile

CATEGORIES = {1: '변신', 2: '마법인형', 98: '성물'}
# Exact existing local capabilities, never translate PvP into PvE.
FLAT = dict(zip(
    ['HPPlus','MPPlus','MeleeDamage','RangeDamage','MagicDamage','MeleeHit','RangeHit','MagicHit','ArmorClass','MagicResist','RangeEvasion','DamageReduction','SpellPower','Strength','Dexterity','Constitution','Intelligence','Wisdom','Charisma','RegenHP','RegenMP','HPPotionIncreaseStatic','PVEDamageReduction','PVEMeleeAdditionDamage','PVERangeAdditionDamage','PVEMagicAdditionDamage','PVEMeleeHit','PVERangeHit','PVEMagicHit','CriticalMeleeDamage','CriticalRangeDamage','CriticalMagicDamage'],
    ['max_hp','max_mp','melee_damage','ranged_damage','magic_damage','melee_hit','ranged_hit','magic_hit','ac','mr','er','damage_reduction','sp','str','dex','con','int','wis','cha','hp_regeneration','mp_regeneration','potion_heal','pve_damage_reduction','pve_melee_damage','pve_ranged_damage','pve_magic_damage','pve_melee_hit','pve_ranged_hit','pve_magic_hit','melee_critical_damage','ranged_critical_damage','magic_critical_damage']))
FLAT['MeleeEvasion']='melee_evasion'
PERCENT = {'MagicCritical':'magic_critical_rate','PVEDamageReductionPercent':'pve_damage_reduction','ExperienceAdditionPercent':'experience_bonus','AttackSpeedBonus':'attack_speed','MoveSpeedBonus':'movement_speed','HPPotionIncreasePercent':'potion_heal','MeleeCritical':'melee_critical_rate','RangeCritical':'ranged_critical_rate'}

def build(source, canonical, evidence):
    assert hashlib.sha256(pathlib.Path(source).read_bytes()).hexdigest() == evidence["source"]["source_zip_sha256"]
    with zipfile.ZipFile(source) as z:
        tables = {}
        hashes = {}
        for name in ['BuffCardCollection','BuffCardForCollection','BuffCardCollectionBonus','BuffCard','BuffCardDeck','Bonus','BonusType','BonusApplicationType','Unit','UIUnit','DescData_Korean','ServerLimit','Grade','SpecialResistanceType','IntervalBonusCategory','IntervalBonus']:
            raw = z.read('content/'+name+'.json')
            tables[name] = json.loads(raw)['rows']
            hashes[name] = hashlib.sha256(raw).hexdigest()
    idx = {n:{r['ID']:r for r in rs} for n,rs in tables.items() if n != 'BuffCardForCollection'}
    ui_units = {r['UnitID']:r for r in tables['UIUnit']}
    cards = {}
    for category, records in canonical['catalog'].items():
        for r in records:
            native = idx['BuffCard'][r['source_card_id']]
            pair = (native['BuffCardDeckID'], native['ID'])
            assert pair not in cards
            cards[pair] = (category, r)
    targets = {(r['BonusApplicationTypeID'],r['target_id']):r for r in evidence['application_targets']}
    evidence_sets = {r['source_row']['ID']:r for r in evidence['collections1736']}
    members = collections.defaultdict(list)
    rewards = collections.defaultdict(list)
    for r in tables['BuffCardForCollection']: members[r['BuffCardCollectionID']].append(r)
    for r in tables['BuffCardCollectionBonus']: rewards[r['BuffCardCollectionID']].append(r)
    result = []
    for row in tables['BuffCardCollection']:
        deck = row['BuffCardDeckID']
        if deck not in CATEGORIES: continue
        category = CATEGORIES[deck]
        assert evidence_sets[row['ID']]['source_row'] == row
        requirements = []
        for member in members[row['ID']]:
            native_card = idx['BuffCard'][member['BuffCardID']]
            cat, card = cards[(native_card['BuffCardDeckID'],native_card['ID'])]
            assert cat == category
            requirements.append({'category':cat,'id':'source:'+card['sourceId'],'name':card['name'],'catalog_name':card['name'],'grade':card['grade'],'awakened':member['IsAwaken'],'source_original':member,'source_card_availability':{k:native_card[k] for k in ['ServerLimitSetID','StartDateTimeID','EndDateTimeID']}})
        effects = []
        for link in rewards[row['ID']]:
            bonus = idx['Bonus'][link['BonusID']]
            typ = idx['BonusType'][bonus['BonusTypeID']]
            unit = idx['Unit'].get(typ['UnitID'],{})
            ui = ui_units.get(typ['UnitID'],{})
            type_name = typ['Name']
            key = 'native_'+type_name
            local_unit = 'raw'
            amount = bonus['Value']
            target = targets.get((bonus['BonusApplicationTypeID'],bonus['BonusApplicationTargetID']),{})
            scoped_key = None
            target_name=(target.get('target_row') or {}).get('Name','')
            if bonus['BonusApplicationTypeID']==2:
                if type_name=='SpecialResistance' and target_name in ['Stun','Hold','Fear']:scoped_key={'Stun':'stun_resistance','Hold':'hold_resistance','Fear':'fear_resistance'}[target_name]
                if type_name=='HitSpecialResistance' and target_name in ['Stun','Hold','Fear']:scoped_key={'Stun':'stun_hit','Hold':'hold_hit','Fear':'fear_hit'}[target_name]
            supported = bonus['BonusApplicationTypeID']==0 and bonus['BonusApplicationTargetID']==0
            if scoped_key and unit.get('Name')=='Percentage' and ui.get('Denominator',0)>0:
                supported=True;key,local_unit=scoped_key,'percent';amount=amount/ui['Denominator']
            elif supported and type_name in FLAT and unit.get('Name')=='Value': key,local_unit=FLAT[type_name],'flat'
            elif supported and type_name in PERCENT and unit.get('Name') in ['Percentage','ValuePercent']:
                key,local_unit=PERCENT[type_name],'percent'
                divisor=ui.get('Denominator',0)
                assert divisor>0
                amount=amount/divisor
            elif supported and type_name=='CarryPlus' and unit.get('Name')=='Weight' and ui.get('Denominator',0)>0:
                key,local_unit='weight_bonus','flat';amount=amount/ui['Denominator']
            else: supported=False
            if local_unit=='raw': supported=False
            # Source ArmorClass is positive defensive power. The existing local
            # collection channel is signed displayed AC (a lower value is better).
            if key=='ac' and local_unit=='flat':amount=-amount
            # Existing flat stat consumers are integer-valued. Preserve fractions,
            # and block them explicitly rather than silently truncating them.
            if (local_unit=='flat' or key=='potion_heal' and local_unit=='percent') and int(amount)!=amount: supported=False
            if isinstance(amount,float) and amount.is_integer():amount=int(amount)
            desc=idx['DescData_Korean'].get(typ['DescID'],{}).get('Description',type_name)
            display_amount=amount
            display_unit=local_unit
            if not supported and unit.get('Name') in ['Percentage','ValuePercent','Weight'] and ui.get('Denominator',0)>0:
                display_amount=bonus['Value']/ui['Denominator'];display_unit='percent' if unit['Name'] in ['Percentage','ValuePercent'] else 'flat'
            target_row=target.get('target_row') or {}
            target_desc=idx['DescData_Korean'].get(target_row.get('DescID'),{}).get('Description') or target_row.get('Name','')
            label=((target_desc+' · ') if target_desc else '')+f'{desc or type_name} {display_amount:+g}'+('%' if display_unit=='percent' else '')
            if unit.get('Name')=='IntervalBonusCategoryID':label=(desc or type_name)+' · 원본 구간 조건: '+idx['IntervalBonusCategory'].get(bonus['Value'],{}).get('Name',str(bonus['Value']))
            effects.append({'key':key,'unit':local_unit,'value':amount,'label':label,'native_supported':supported,'source_original':{'link':link,'bonus':bonus,'bonus_type':typ,'application_type':idx['BonusApplicationType'].get(bonus['BonusApplicationTypeID'],{}),'unit':unit,'ui_unit':ui,'application_target':target,'nested_intervals':[dict(r,bonus=idx['Bonus'].get(r['BonusID'],{})) for r in tables['IntervalBonus'] if unit.get('Name')=='IntervalBonusCategoryID' and r['IntervalBonusCategory']==bonus['Value']]}})
        name=idx['DescData_Korean'].get(row['DescID'],{}).get('Description') or row['Name']
        result.append({'id':'base508:collection:'+str(row['ID']),'name':name,'category':category,'grade':idx['DescData_Korean'].get(idx['Grade'][row['GradeID']]['DescID'],{}).get('Description',idx['Grade'][row['GradeID']]['Name']),'source_grade':idx['Grade'][row['GradeID']],'requirements':requirements,'effects':effects,'raw_effects':'\n'.join(e['label'] for e in effects),'server_note':'원본 서버 조건 '+str(row['ServerLimitSetID']) if row['ServerLimitSetID'] else '', 'source':{'snapshot':'base508','url':'base508/BuffCardCollection:'+str(row['ID']),'table_sha256':hashes['BuffCardCollection']},'source_original':row,'source_deck':idx['BuffCardDeck'][deck]})
    return {'schema_version':1,'source_snapshot':'base508','ownership_policy':'permanent_acquisition_exact_native_ID; no_registration_or_consumption','source_table_sha256':hashes,'canonical_evidence_source':evidence['source'],'collections':result,'excluded_test_deck_collections':[r for r in tables['BuffCardCollection'] if r['BuffCardDeckID'] not in CATEGORIES],'source_server_limits':tables['ServerLimit'],'source_card_date_rows':evidence['card_date_rows']}

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--source',required=True);parser.add_argument('--canonical',required=True);parser.add_argument('--evidence',required=True);parser.add_argument('--output',required=True);args=parser.parse_args()
    result=build(args.source,json.loads(pathlib.Path(args.canonical).read_text()),json.loads(pathlib.Path(args.evidence).read_text()))
    path=pathlib.Path(args.output);path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(result,ensure_ascii=False,separators=(',',':'))+'\n')
    print(json.dumps({'sets':len(result['collections']),'requirements':sum(len(r['requirements']) for r in result['collections']),'effects':sum(len(r['effects']) for r in result['collections']),'bytes':path.stat().st_size},ensure_ascii=False))
