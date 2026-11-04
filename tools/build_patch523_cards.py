"""Project current523 metadata; retain existing m508 IDs and use m523 for new cards."""
import argparse, collections, copy, hashlib, json, pathlib, zipfile
from build_base508_card_collections import CATEGORIES, FLAT, PERCENT

FLAT={**FLAT,'MeleeDamageReduction':'melee_damage_reduction','RangeDamageReduction':'ranged_damage_reduction','MagicDamageReduction':'magic_damage_reduction','CriticalDamageReduction':'critical_damage_reduction','PoisonDamageReduction':'poison_damage_reduction'}
PERCENT={**PERCENT,'MeleeDamageReductionPercent':'melee_damage_reduction','RangeDamageReductionPercent':'ranged_damage_reduction','MagicDamageReductionPercent':'magic_damage_reduction','PoisonDamageReductionPercent':'poison_damage_reduction'}

# Current main's explicit single-player PvP-to-PvE rule also covers collections.
PVP_FLAT={'PVPDamageReduction':'pve_damage_reduction','PVPMeleeAdditionDamage':'pve_melee_damage','PVPRangeAdditionDamage':'pve_ranged_damage','PVPMagicAdditionDamage':'pve_magic_damage','PiercePVPDamageReduction':'damage_reduction_ignore','PVPPierceMeleeEvasion':'melee_evasion_ignore','PVPPierceRangeEvasion':'ranged_evasion_ignore','PVPMeleeEvasion':'melee_evasion','PVPRangeEvasion':'er'}
PVP_PERCENT={'PVPDamageReductionPercent':'pve_damage_reduction','IgnorePVPDamageReductionPercent':'damage_reduction_ignore','PVPPierceDamageReductionPercent':'pve_damage_amplification'}
FLAT={**FLAT,**PVP_FLAT,'PierceDamageReduction':'damage_reduction_ignore','PierceMeleeDamageReduction':'melee_reduction_ignore','PierceRangeDamageReduction':'ranged_reduction_ignore','PierceMagicDamageReduction':'magic_reduction_ignore','PierceMeleeEvasion':'melee_evasion_ignore','PierceRangeEvasion':'ranged_evasion_ignore','AbsoluteRegenMP':'absolute_mp_regeneration','FinalBlowAdditionalDmg':'final_blow_damage'}
PERCENT={**PERCENT,**PVP_PERCENT,'IgnoreDamageReductionPercent':'damage_reduction_ignore','IgnoreMeleeDamageReductionPercent':'melee_reduction_ignore','IgnoreRangeDamageReductionPercent':'ranged_reduction_ignore','IgnoreMagicDamageReductionPercent':'magic_reduction_ignore','PVEPierceDamageReductionPercent':'pve_damage_amplification','MeleeCriticalResist':'melee_critical_resistance','RangeCriticalResist':'ranged_critical_resistance','MagicCriticalResist':'magic_critical_resistance','ElementalCriticalResistance':'elemental_critical_resistance','HPHealIncreasePercent':'magic_heal','WeaponBlock':'weapon_block','EinasadBlessAbsolutePercent':'blessing_charge','FinalBlowProbability':'final_blow_probability','FinalBlowAdditionalScale':'final_blow_amplification'}

FLAT={**FLAT,'KarmaLife':'life','KarmaDeath':'death'}
PERCENT={**PERCENT,'PierceMagicShieldPercent':'magic_penetration','ResistIgnoreDamageReductionPercent':'reduction_efficiency','MeleeDmgSpellDefensivePowerPercent':'physical_magic_defense','FinalBlowResistance':'final_blow_resistance'}
ESTIMATED={'KarmaLife':'twilight_life_healing','KarmaDeath':'twilight_death_damage','PierceMagicShieldPercent':'twilight_magic_mr_penetration','ResistIgnoreDamageReductionPercent':'twilight_ignore_counter','MeleeDmgSpellDefensivePowerPercent':'twilight_physical_magic_guard','FinalBlowResistance':'twilight_final_blow_defense','WeaponBlock':'twilight_weapon_block','FinalBlowProbability':'twilight_final_blow','FinalBlowAdditionalDmg':'twilight_final_blow','FinalBlowAdditionalScale':'twilight_final_blow'}

FLAT_FIELDS={'HPPlus':'hpFlat','MPPlus':'mpFlat','Strength':'strFlat','Dexterity':'dexFlat','Intelligence':'intFlat','Wisdom':'wisFlat','Constitution':'conFlat','Charisma':'chaFlat','MagicResist':'mr','DamageReduction':'damage_reduction'}
EXPECTED_SHA='d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'

def read_source(path):
    if hashlib.sha256(path.read_bytes()).hexdigest()!=EXPECTED_SHA:raise ValueError('current523 source SHA mismatch')
    names=['BuffCard','BuffCardDeck','BuffCardByClass','BuffBonus','Bonus','BonusType','Unit','UIUnit','AssetView','AssetType','Grade','DescData_Korean','PolymorphEntityForSet','PolymorphEntity','NpcClass','SpriteRun','SpriteSeparatedWalk','BuffCardCollection','BuffCardForCollection','BuffCardCollectionBonus','BonusApplicationType','SpecialResistanceType','SpellClass','SpellTag','ServerLimit','IntervalBonusCategory','IntervalBonus']
    tables={};hashes={}
    with zipfile.ZipFile(path) as z:
        for name in names:
            raw=z.read('content/'+name+'.json');tables[name]=json.loads(raw.decode('utf-8-sig'))['rows'];hashes[name]=hashlib.sha256(raw).hexdigest()
    return tables,hashes

def indices(tables):
    return {n:{r['ID']:r for r in rows} for n,rows in tables.items() if rows and all('ID' in r for r in rows) and len({r['ID'] for r in rows})==len(rows)}

def build_catalog(t,idx,baseline,hashes):
    by_card={r['source_card_id']:r for rows in baseline['catalog'].values() for r in rows}
    links=collections.defaultdict(list)
    for r in t['BuffBonus']:links[r['BuffClassID']].append(r)
    entities=collections.defaultdict(list)
    for r in t['PolymorphEntityForSet']:entities[r['PolymorphSetID']].append(idx['PolymorphEntity'][r['PolymorphEntityID']])
    assets={r['AssetId']:r for r in t['AssetView']}
    assert len(assets)==len(t['AssetView'])
    types={r['ID']:r for r in t['AssetType']}
    runs={r['WalkSpriteID']:r for r in t['SpriteRun']};walk={r['SpriteId']:r for r in t['SpriteSeparatedWalk']}
    variants=collections.defaultdict(list)
    for r in t['BuffCardByClass']:variants[r['BuffCardID']].append(r)
    def desc(identity,fallback=''):return idx['DescData_Korean'].get(identity,{}).get('Description') or fallback
    out={category:[] for category in CATEGORIES.values()}
    for raw in t['BuffCard']:
        deck=raw['BuffCardDeckID']
        if deck not in CATEGORIES:continue
        card_id=raw['ID'];record=copy.deepcopy(by_card.get(card_id,{}));is_new=card_id not in by_card
        # Source IDs are an existing save protocol, not a claim that these bytes came from508.
        record.update(name=desc(raw['DescID'],raw['Name']),grade=desc(idx['Grade'][raw['GradeID']]['DescID'],idx['Grade'][raw['GradeID']]['Name']),type='공통',source='lineagem_patch523' if is_new else 'lineagem_base508',sourceId=f"{'m523' if is_new else 'm508'}:{deck}:{card_id}",source_card_id=card_id,source_deck_id=deck,source_grade_id=raw['GradeID'],source_grade_tier_id=raw['GradeTierID'],source_internal_name=raw['Name'],source_display_sprite_id=raw['DisplaySpriteID'],source_original_card=raw,source_content_snapshot='patch523',source_class_variants=variants[card_id],source_merge_out_disabled=raw['IsNoMergeOut'],source_swap_out_disabled=raw['IsNoSwapOut'])
        ui={}
        for role in ['DisplayBaseAssetID','DisplayScreenAssetID','DisplayDecoAssetID','IllustrationAssetID','HidedIllustrationAssetID']:
            asset=assets.get(raw[role]) if raw[role] else None;ui[role]=dict(asset_id=asset['AssetId'],asset_type_id=asset['AssetTypeId'],asset_type=types[asset['AssetTypeId']]['Name'],path=types[asset['AssetTypeId']]['Path']+asset['FilePath']) if asset else None
        record['source_ui_assets']=ui
        if is_new:
            record['source_snapshot']='patch523';record['source_draw_pool_pending']=True;record['source_visual_status']='patch523_original_pack_required'
        for field in FLAT_FIELDS.values():record.pop(field,None)
        record['source_bonuses']=[];record['source_stat_application']=[];options=[];sprites=[]
        for link in links[raw['BuffClassID']]:
            bonus=idx['Bonus'][link['BonusID']];typ=idx['BonusType'][bonus['BonusTypeID']];unit=idx['Unit'][typ['UnitID']]
            text=desc(typ['DescID']);direct=all(link.get(k,0)==0 for k in ['CharacterLevel','CharacterClass','MinSpellLevel']) and bonus['BonusApplicationTypeID']==0 and bonus['BonusApplicationTargetID']==0
            detail=dict(buff_bonus=link,bonus=bonus,bonus_type=typ,unit=unit,localized_description=text,application='raw_preserved_pending_semantics')
            if unit['ID']==1 and direct:
                detail['application']='unconditional_native_value';options.append(f"{text or typ['Name']} {bonus['Value']:+d}")
                if typ['Name'] in FLAT_FIELDS:
                    field=FLAT_FIELDS[typ['Name']];record[field]=record.get(field,0)+bonus['Value'];record['source_stat_application'].append(dict(field=field,source_bonus_id=bonus['ID'],rule='Unit1_Value_direct'))
            # Explicit Bonus unit joins only. DisplaySpriteID is never substituted for an actor.
            if unit['Name']=='PolymorphSetID':sprites.extend(e['SpriteID'] for e in entities.get(bonus['Value'],[]))
            elif unit['Name']=='NPCClassID' and bonus['Value'] in idx['NpcClass']:sprites.append(idx['NpcClass'][bonus['Value']]['Sprite'])
            record['source_bonuses'].append(detail)
        record.update(desc=' · '.join(options),sourceOptions=options,sourceOptionsRaw=[dict(type_id=d['bonus_type']['ID'],value=d['bonus']['Value'],unit_id=d['unit']['ID']) for d in record['source_bonuses']],image_path='')
        record['source_declared_patch523_sprite_ids']=sorted(set(sprites))
        if is_new:record['source_inworld_sprite_ids']=sorted(set(sprites))
        record.setdefault('source_inworld_sprite_ids',[])
        record.setdefault('source_sprite_bindings',[dict(sprite_id=s,run_sprite_id=runs.get(s,{}).get('RunSpriteID'),walk_action_hint=walk.get(s,{}).get('WalkActionType')) for s in record['source_inworld_sprite_ids']])
        record.setdefault('source_original',dict(source_snapshot='patch523',card_id=card_id,deck_id=deck,server_limit_set_id=raw['ServerLimitSetID'],start_datetime_id=raw['StartDateTimeID'],end_datetime_id=raw['EndDateTimeID']))
        record.setdefault('source_visual_status','pending_native_pack')
        out[CATEGORIES[deck]].append(record)
    assert {k:len(v) for k,v in out.items()}=={'변신':402,'마법인형':171,'성물':147}
    return dict(schema=1,source_snapshot='patch523',existing_identity_namespace='m508',new_identity_namespace='m523',source_zip_sha256=EXPECTED_SHA,source_table_sha256=hashes,catalog=out,limits=['Definitions do not prove original pixels or animation installation.','Existing source:m508 save IDs remain unchanged.','Class variants are display/effect contexts, not separately owned cards.'])

def build_collections(t,idx,catalog,hashes,evidence):
    proof={r['set']['raw']['ID']:r for r in evidence['sets']}
    records={r['source_card_id']:(category,r) for category,rows in catalog['catalog'].items() for r in rows}
    members=collections.defaultdict(list);rewards=collections.defaultdict(list)
    for r in t['BuffCardForCollection']:members[r['BuffCardCollectionID']].append(r)
    for r in t['BuffCardCollectionBonus']:rewards[r['BuffCardCollectionID']].append(r)
    ui={r['UnitID']:r for r in t['UIUnit']}
    def desc(identity,fallback=''):return idx['DescData_Korean'].get(identity,{}).get('Description') or fallback
    def effect(link,verified):
        bonus=idx['Bonus'][link['BonusID']];typ=idx['BonusType'][bonus['BonusTypeID']];unit=idx['Unit'][typ['UnitID']];application=idx['BonusApplicationType'][bonus['BonusApplicationTypeID']]
        assert verified['link']['raw']==link and verified['bonus']['raw']==bonus and verified['type']['raw']==typ and verified['unit']['raw']==unit and verified['application']['raw']==application
        target_raw=(verified.get('target_definition') or {}).get('raw')
        target=dict(BonusApplicationTypeID=application['ID'],target_id=bonus['BonusApplicationTargetID'],target_table=application['Name'],target_row=target_raw,resolved=application['ID']==0 or target_raw is not None)
        typ_name=typ['Name'];unit_name=unit['Name'];denom=ui.get(unit['ID'],{}).get('Denominator',0)
        key='native_'+typ_name;local_unit='raw';amount=bonus['Value'];supported=False;policy=''
        target_name=(target_raw or {}).get('Name','')
        scoped=None
        if application['ID']==2 and target_name in ['Stun','Hold','Fear']:
            suffix={'SpecialResistance':'resistance','HitSpecialResistance':'hit'}.get(typ_name)
            if suffix:scoped=target_name.lower()+'_'+suffix
        if application['Name']=='SpellClass' and target_raw is not None and typ_name=='SpellDamageBase' and unit_name=='Value':
            key,local_unit,supported='spell_'+str(bonus['BonusApplicationTargetID'])+'_damage','flat',True;policy='local_exact_spell_identity'
        elif application['Name']=='SpellClass' and target_raw is not None and typ_name=='SpellHitProbabilityBase' and unit_name=='Percentage' and denom>0:
            key,local_unit,amount,supported='spell_'+str(bonus['BonusApplicationTargetID'])+'_hit','percent',amount/denom,True;policy='local_exact_spell_identity'
        elif application['Name']=='SpellTag' and bonus['BonusApplicationTargetID']==1 and typ_name=='DamageReductionForSpellAttackWeapon' and unit_name=='Value':
            key,local_unit,supported='ranged_burst_reduction','flat',True;policy='twilight_ranged_burst_tag1'
        elif application['ID']==2 and target_name in ['Stun','Fear'] and typ_name=='DamageReductionForSpecialDebuff' and unit_name=='Value':
            key,local_unit,supported='while_'+target_name.lower()+'_damage_reduction','flat',True;policy='live_exact_source_status'
        elif typ_name=='DamageDampOption' and application['Name']=='DamageDampOption' and bonus['BonusApplicationTargetID']==13 and unit_name=='Percentage' and denom>0:
            key,local_unit,amount,supported='stacked_damage_reduction','percent',amount/denom,True;policy='twilight_target13_stacked_reduction_v1'
        elif scoped and unit_name=='Percentage' and denom>0:key,local_unit,amount,supported=scoped,'percent',amount/denom,True
        elif application['ID']==0 and bonus['BonusApplicationTargetID']==0:
            if typ_name in FLAT and unit_name=='Value':key,local_unit,supported=FLAT[typ_name],'flat',True
            elif typ_name in PERCENT and unit_name in ['Percentage','ValuePercent'] and denom>0:key,local_unit,amount,supported=PERCENT[typ_name],'percent',amount/denom,True
            elif typ_name=='CarryPlus' and unit_name=='Weight' and denom>0:key,local_unit,amount,supported='weight_bonus','flat',amount/denom,True
        if supported and typ_name in ESTIMATED:policy=ESTIMATED[typ_name]
        if supported and (typ_name in PVP_FLAT or typ_name in PVP_PERCENT):policy='existing_single_player_pvp_to_pve'
        if key=='ac' and local_unit=='flat':amount=-amount
        if (local_unit=='flat' or key=='potion_heal' and local_unit=='percent') and int(amount)!=amount:supported=False
        if isinstance(amount,float) and amount.is_integer():amount=int(amount)
        display_amount=amount;display_unit=local_unit
        if not supported and unit_name in ['Percentage','ValuePercent','Weight'] and denom>0:display_amount=bonus['Value']/denom;display_unit='percent' if unit_name in ['Percentage','ValuePercent'] else 'flat'
        target_label=desc((target_raw or {}).get('DescID'),target_name)
        label=((target_label+' · ') if target_label else '')+f"{desc(typ['DescID'],typ_name)} {display_amount:+g}"+('%' if display_unit=='percent' else '')
        if policy=='existing_single_player_pvp_to_pve':label=label.replace('PVP','PVE').replace('PvP','PvE')
        nested=[]
        if unit_name=='IntervalBonusCategoryID':
            label=desc(typ['DescID'],typ_name)+' · 원본 구간 조건: '+idx['IntervalBonusCategory'].get(bonus['Value'],{}).get('Name',str(bonus['Value']))
            for interval in t['IntervalBonus']:
                if interval['IntervalBonusCategory']!=bonus['Value']:continue
                b=idx['Bonus'][interval['BonusID']];bt=idx['BonusType'][b['BonusTypeID']];a=idx['BonusApplicationType'][b['BonusApplicationTypeID']];target_table=idx.get(a['Name'],{})
                nested.append(dict(interval,bonus=b,bonus_type=bt,unit=idx['Unit'][bt['UnitID']],ui_unit=ui.get(bt['UnitID'],{}),application_type=a,application_target=target_table.get(b['BonusApplicationTargetID'])))
        return dict(key=key,unit=local_unit,value=amount,label=label,native_supported=supported,runtime_policy=policy,source_original=dict(link=link,bonus=bonus,bonus_type=typ,application_type=application,unit=unit,ui_unit=ui.get(unit['ID'],{}),application_target=target,nested_intervals=nested))
    result=[]
    for row in t['BuffCardCollection']:
        if row['BuffCardDeckID'] not in CATEGORIES:continue
        evidence_row=proof[row['ID']];assert evidence_row['set']['raw']==row
        requirements=[]
        for m,verified in zip(members[row['ID']],evidence_row['members'],strict=True):
            assert m==verified['raw'];category,card=records[m['BuffCardID']];raw=idx['BuffCard'][m['BuffCardID']]
            requirements.append(dict(category=category,id='source:'+card['sourceId'],name=card['name'],catalog_name=card['name'],grade=card['grade'],awakened=m['IsAwaken'],source_original=m,source_card_availability={k:raw[k] for k in ['ServerLimitSetID','StartDateTimeID','EndDateTimeID']}))
        effects=[effect(link,verified) for link,verified in zip(rewards[row['ID']],evidence_row['effects'],strict=True)]
        grade=idx['Grade'][row['GradeID']]
        result.append(dict(id='base508:collection:'+str(row['ID']),name=desc(row['DescID'],row['Name']),category=CATEGORIES[row['BuffCardDeckID']],grade=desc(grade['DescID'],grade['Name']),source_grade=grade,requirements=requirements,effects=effects,raw_effects='\n'.join(e['label'] for e in effects),server_note='원본 서버 조건 '+str(row['ServerLimitSetID']) if row['ServerLimitSetID'] else '',source=dict(snapshot='patch523',url='patch523/BuffCardCollection:'+str(row['ID']),table_sha256=hashes['BuffCardCollection']),source_original=row,source_deck=idx['BuffCardDeck'][row['BuffCardDeckID']]))
    assert len(result)==1793 and sum(len(r['requirements']) for r in result)==5059 and sum(len(r['effects']) for r in result)==2052
    return dict(schema_version=1,source_snapshot='patch523',identity_namespace='base508:collection',ownership_policy='permanent_acquisition_exact_native_ID; no_registration_or_consumption',source_zip_sha256=EXPECTED_SHA,source_table_sha256=hashes,collections=result,excluded_test_deck_collections=[r for r in t['BuffCardCollection'] if r['BuffCardDeckID'] not in CATEGORIES],source_server_limits=t['ServerLimit'],source_card_date_rows=[r for r in t['BuffCard'] if r['BuffCardDeckID'] in CATEGORIES and (r['StartDateTimeID'] or r['EndDateTimeID'])])

def main():
    p=argparse.ArgumentParser();p.add_argument('--source',type=pathlib.Path,required=True);p.add_argument('--baseline',type=pathlib.Path,required=True);p.add_argument('--evidence',type=pathlib.Path,required=True);p.add_argument('--catalog-output',type=pathlib.Path,required=True);p.add_argument('--collections-output',type=pathlib.Path,required=True);a=p.parse_args()
    t,hashes=read_source(a.source);idx=indices(t)
    catalog=build_catalog(t,idx,json.loads(a.baseline.read_text()),hashes)
    collections_data=build_collections(t,idx,catalog,hashes,json.loads(a.evidence.read_text()))
    for path,data in [(a.catalog_output,catalog),(a.collections_output,collections_data)]:
        path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n');print(path.name,path.stat().st_size)
if __name__=='__main__':main()
