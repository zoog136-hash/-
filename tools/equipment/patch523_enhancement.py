"""Translate exact 523 level rows; retain conditional/proc rows as evidence.

Only host numeric consumers with matching units are emitted. Raw source tables
remain in the private pack. Level rows are alternatives, never summed by rank.
"""
from collections import defaultdict
import json
from pathlib import Path

# stat key, host +0 property, denominator. Core keys use original_enhancement;
# extra keys feed the existing typed equipment option consumers.
FIELDS = {
    'WeaponDamageBonus':('damage',None,1), 'WeaponHitBonus':('accuracy',None,1),
    'ArmorClass':('defense',None,1), 'HPPlus':('hp','hpFlat',1),
    'MPPlus':('mp','mpFlat',1), 'CarryPlus':('capacity','weightBonus',100),
    'MagicResist':('mr','mr',1), 'SpellPower':('sp','sp',1),
    'MeleeDamage':('melee_damage','meleeDamage',1), 'RangeDamage':('ranged_damage','rangedDamage',1),
    'MeleeHit':('melee_accuracy','meleeHit',1), 'RangeHit':('ranged_accuracy','rangedHit',1),
    'MagicHit':('magic_accuracy','magicHit',1), 'DamageReduction':('reduction','damage_reduction',1),
    'HPPotionIncreaseStatic':('potion_heal_flat','potionHealFlat',1),
    'HPPotionIncreasePercent':('potion_heal_pct','potionHealPct',10000),
    'ExperienceAdditionPercent':('xp_pct','xp',10000),
    'EinasadSavingPercent':('ain_saving_pct','blessing_consumption_reduction_pct',10000),
    'PotionConsumeDelayDecreasePercent':('potion_cooldown_pct','potionCooldownPct',10000),
    '_stun':('stun_resistance','stun_resistance',10000),
}
EXTRA = {
    'PierceMagicShieldPercent':('magic_penetration_pct',1),
    'ElementalCriticalResistance':('equipment523_element_crit_resist_pct',10000),
    'Strength':('strFlat',1), 'Dexterity':('dexFlat',1), 'Intelligence':('intFlat',1),
    'RangeEvasion':('er',1), 'MeleeEvasion':('dg',1), 'RegenMP':('mpRecoveryTick',1),
    'MagicDamage':('magicDamage',1), 'AttackSpeedBonus':('attackSpeed',10000),
    'MoveSpeedBonus':('speedBonusPct',10000),
    'PVEDamageReduction':('pve_damage_reduction',1), 'PVPDamageReduction':('pve_damage_reduction',1),
    'PVEDamageReductionPercent':('pve_damage_reduction_pct',10000),
    'MeleeCritical':('melee_crit',1), 'RangeCritical':('ranged_crit',1), 'MagicCritical':('magic_crit',1),
    'PierceDamageReduction':('damage_reduction_ignore',1),
    'PierceMeleeDamageReduction':('source_melee_flat_reduction_ignore',1),
    'PierceRangeDamageReduction':('source_ranged_flat_reduction_ignore',1),
    'PierceMagicDamageReduction':('source_magic_flat_reduction_ignore',1),
    'PiercePVPDamageReduction':('source_pvp_flat_reduction_ignore',1),
    'PVPSpellByLevelAdditionLevel':('source_pvp_status_success_level',1),
    '_fear_flat_ignore':('source_fear_flat_reduction_ignore',1),
    'PVPMeleeAdditionDamage':('pve_melee_damage',1), 'PVEMeleeAdditionDamage':('pve_melee_damage',1),
    'PVPRangeAdditionDamage':('pve_ranged_damage',1), 'PVERangeAdditionDamage':('pve_ranged_damage',1),
    'PVPMagicAdditionDamage':('pve_magic_damage',1), 'PVEMagicAdditionDamage':('pve_magic_damage',1),
    'PierceMeleeEvasion':('melee_evasion_ignore',1), 'PierceRangeEvasion':('ranged_evasion_ignore',1),
    # DescData_Korean calls these 대미지 증가 / PVE 대미지 증가,
    # not a new NPC defensive stat. Use the existing damage amplifier.
    'PierceDamageReductionPercent':('damage_amp_pct',10000),
    'PVEPierceDamageReductionPercent':('damage_amp_pct',10000),
    'DamageReductionPercent':('pve_damage_reduction_pct',10000),
    # Unit211 ValuePercent already stores percentage points (divisor1).
    '_adena_drop':('adena_drop_pct',1),
    'HPHealIncreasePercent':('healing_magic_pct',10000),
    'CastSpeedBonus':('castSpeed',10000),
    'MeleeCriticalResist':('melee_critical_resistance',10000),
    'RangeCriticalResist':('ranged_critical_resistance',10000),
    'MeleeDamageReductionPercent':('melee_damage_reduction_pct',10000),
    'RangeDamageReductionPercent':('ranged_damage_reduction_pct',10000),
    'MagicDamageReductionPercent':('magic_damage_reduction_pct',10000),
    'PoisonDamageReductionPercent':('dot_damage_reduction_pct',10000),
    'StrengthScale':('strPercent',10000), 'DexterityScale':('dexPercent',10000),
    'IntelligenceScale':('intPercent',10000),
    'AttackDrainHP':('source_attack_drain_hp',1),
    'AttackDrainMP':('source_attack_drain_mp',1),
    'UndeadAdditionalMaxDamage':('source_undead_damage_max',1),
    'FinalBlowProbability':('source_final_blow_chance_pct',10000),
    'FinalBlowAdditionalScale':('source_final_blow_amp_pct',10000),
    '_final_blow_stun':('source_final_blow_stun_chance_pct',10000),
    '_stun_magic':('source_stun_magic_damage',1),
}
for _channel in ['fire','water','wind','earth']:
    EXTRA['_elemental_'+_channel]=('source_elemental_flat_'+_channel,1)

for _status in ['stun','hold','fear','poison','silence']:
    EXTRA['_hit_'+_status]=(_status+'_accuracy',10000)
    if _status!='stun': EXTRA['_resist_'+_status]=(_status+'_resistance',10000)


def qualified_name(bonus, name, resistance_types, elemental_targets=None):
    application, target = bonus['BonusApplicationTypeID'], bonus['BonusApplicationTargetID']
    if not application and not target:
        # These types require an explicit target; never turn an unknown
        # resistance or drop target into a generic bonus.
        return None if name in ['HitSpecialResistance','SpecialResistance','IncreaseNpcItemDropAmount'] else name
    if name=='MagicDamage' and application==2 and resistance_types.get(target,'').lower()=='stun':
        return '_stun_magic'
    if name=='PierceDamageReduction' and application==2 and resistance_types.get(target,'').lower()=='fear':
        return '_fear_flat_ignore'
    if name=='FinalBlowProbability' and application==2 and resistance_types.get(target,'').lower()=='stun':
        return '_final_blow_stun'
    if name in ['HitSpecialResistance','SpecialResistance'] and application==2:
        status = resistance_types.get(target,'').lower()
        if status in ['stun','hold','fear','poison','silence']:
            return '_hit_'+status if name=='HitSpecialResistance' else '_stun' if status=='stun' else '_resist_'+status
    if name=='ElementalDamage' and application==3:
        channel=(elemental_targets or {}).get(str(target))
        if channel in ['fire','water','wind','earth']: return '_elemental_'+channel
    if name=='IncreaseNpcItemDropAmount' and application==5 and target==26:
        return '_adena_drop'
    return None


def compile_equipment(tables, bound_items, bonuses):
    types = {r['ID']:r for r in tables['BonusType']}
    invoke_options = {r['ID']:r for r in tables.get('InvokeOption',[])}
    resistance_types = {r['ID']:r['Name'] for r in tables.get('SpecialResistanceType',[])}
    policy=json.loads((Path(__file__).resolve().parents[2]/'data/crafting/patch523_enhancement_policy.json').read_text())
    elemental_targets=policy.get('source_elemental_target_channels',{}) if all(r['UnitID']==1 for r in tables['BonusType'] if r['Name']=='ElementalDamage') else {}
    result = {}
    for iid, item in bound_items.items():
        raw, canonical = item['item_class'], item['catalog_record']
        if raw.get('TestItem') or canonical.get('slot') in ['consumable','material','currency','']:
            continue
        options, extras, invokes, skipped = {}, {}, {}, set()
        for bless in [1,2]:
            by_rank, extra_rank, invoke_rank = {}, {}, {}
            # Blessed2 overrides the default0 family within each group, not
            # normal1. Default0 is selected only where no state family exists.
            groups = defaultdict(list)
            for row in item['enchant_effects']:
                groups[row['ItemEnchantBonusGroupID']].append(row)
            selected = []
            for rows in groups.values():
                codes = {r['BlessCode'] for r in rows}
                selected += [r for r in rows if r['BlessCode'] == (bless if bless in codes else 0)]
            for level in range(22):
                totals, extra, live_invokes = {}, {}, []
                for row in selected:
                    if row['EnchantLevel'] != level:
                        continue
                    b = bonuses[str(row['BonusID'])]
                    name = types[b['BonusTypeID']]['Name']
                    if name == 'InvokeOption' and b['BonusApplicationTypeID']==10:
                        option=invoke_options.get(b['BonusApplicationTargetID'],{})
                        kind=option.get('InvokeOptionTypeID')
                        # Full native profile is owned by the existing skill executor.
                        profile=tables.get('EquipmentSpellProfiles',{}).get(str(option.get('Param1')))
                        common_zero=['MaterialTypeID','MaterialAmount','IsAmmoAttack','WeaponGroupID','ShieldTypeID','SuccessedInvokeOptionID','TargetKind','SiegeTargetKind']
                        source_weight=types[b['BonusTypeID']]['UnitID']==3 and 0<=b['Value']<=1000000
                        if (kind==1 and profile and source_weight and option.get('AttackTypeID') in [0,1,2,3]
                            and all(option.get(k,0)==0 for k in common_zero+['Param2','Param3','Param4','Param5','Param6'])):
                            live_invokes.append({'row_id':row['ID'],'probability':b['Value'],'option_id':option['ID'],'kind':'attack_source_spell'})
                            continue
                        if (kind==61 and source_weight and option.get('AttackTypeID') in [0,1,2,3]
                            and all(option.get(k,0)==0 for k in common_zero+['Param5','Param6'])
                            and 0<=option.get('Param1',-1)<=1000000 and 0<=option.get('Param2',-1)<=1000000
                            and 0<=option.get('Param3',-1)<=1000000 and isinstance(option.get('Param4'),bool)):
                            live_invokes.append({'row_id':row['ID'],'probability':b['Value'],'option_id':option['ID'],'kind':'defence_fixed_counter'})
                            continue
                        # Fully numeric source contracts only. Spell/formula,
                        # material, weapon/shield and chained hooks stay typed
                        # evidence until their authoritative execution contract.
                        if (kind in [3,5,6] and types[b['BonusTypeID']]['UnitID']==3 and 0<=b['Value']<=1000000
                            and (kind!=6 or (option.get('BySpellAttack') is False and option.get('AttackTypeID') in [0,1,2] and option.get('Param1',0)>=1000000))
                            and all(option.get(k,0)==0 for k in ['Param2','Param3','Param4','Param5','Param6','MaterialTypeID','MaterialAmount','IsAmmoAttack','WeaponGroupID','ShieldTypeID','SuccessedInvokeOptionID','TargetKind','SiegeTargetKind'])
                            and option.get('AttackTypeID') in [0,1,2,3] and option.get('Param1',-1)>=0):
                            live_invokes.append({'row_id':row['ID'],'probability':b['Value'],'option':option,
                                                 'kind':{3:'attack_fixed_damage',5:'defence_flat_reduction',6:'attack_weapon_scale'}[kind]})
                            continue
                    if name in ['PierceMeleeDamageReduction','PierceRangeDamageReduction','PierceMagicDamageReduction','PiercePVPDamageReduction','PVPSpellByLevelAdditionLevel','PierceDamageReduction'] and types[b['BonusTypeID']]['UnitID']!=1:
                        skipped.add(row['ID']); continue
                    if name in ['FinalBlowProbability','FinalBlowAdditionalScale'] and types[b['BonusTypeID']]['UnitID']!=3:
                        skipped.add(row['ID']); continue
                    if name=='PierceMagicShieldPercent' and types[b['BonusTypeID']]['UnitID']!=211:
                        skipped.add(row['ID']); continue
                    if name=='ElementalCriticalResistance' and types[b['BonusTypeID']]['UnitID']!=3:
                        skipped.add(row['ID']); continue
                    if name=='MagicDamage' and b['BonusApplicationTypeID']==2 and types[b['BonusTypeID']]['UnitID']!=1:
                        name=None
                    else:
                        name = qualified_name(b,name,resistance_types,elemental_targets)
                    if name is None:
                        skipped.add(row['ID']); continue
                    spec = FIELDS.get(name)
                    if spec:
                        key, _, divisor = spec
                        totals[key] = totals.get(key,0)+b['Value']/divisor
                    elif name in EXTRA:
                        key, divisor = EXTRA[name]
                        extra[key] = extra.get(key,0)+b['Value']/divisor
                    else:
                        skipped.add(row['ID'])
                # +0 rows of accessories are complete values already present
                # in the host base catalog. Subtract that base exactly once.
                zero_keys = set()
                for row in selected:
                    if row['EnchantLevel']==0:
                        b=bonuses[str(row['BonusID'])]
                        n=qualified_name(b,types[b['BonusTypeID']]['Name'],resistance_types,elemental_targets)
                        if n in FIELDS: zero_keys.add(n)
                for name in zero_keys:
                    key, host, _ = FIELDS[name]
                    if key in totals and host:
                        base = canonical.get(host,0)
                        # Inven typed options may still reside in sourceOptions;
                        # runtime subtracts the actual annotated base instead.
                        totals[key] = {'total':totals[key],'base_key':host,'scale':100 if host=='xp' else 1}
                for row in selected:
                    if row['EnchantLevel']!=0: continue
                    b=bonuses[str(row['BonusID'])]
                    name=qualified_name(b,types[b['BonusTypeID']]['Name'],resistance_types,elemental_targets)
                    if name in EXTRA:
                        key,_=EXTRA[name]
                        base_key={'AttackDrainHP':'hpAbsorption','AttackDrainMP':'mpAbsorption'}.get(name,key)
                        if key in extra and not isinstance(extra[key],dict): extra[key]={'total':extra[key],'base_key':base_key,'scale':1}
                by_rank[str(level)] = totals
                extra_rank[str(level)] = extra
                invoke_rank[str(level)] = live_invokes
            options[str(bless)], extras[str(bless)], invokes[str(bless)] = by_rank, extra_rank, invoke_rank
        blessing = {}
        for b in tables.get('ItemBlessBonus',[]):
            if b['ItemCategoryID']==raw['CategoryID'] and b['GradeID']==raw['GradeID'] and not b['IsTest'] and not b['IsPossession'] and b['BonusApplicationTypeID']==0 and b['BonusApplicationTargetID']==0:
                name=types[b['BonusTypeID']]['Name']
                if name=='ArmorClassBonus': name='ArmorClass'
                if name in FIELDS:
                    key,_,divisor=FIELDS[name];blessing[key]=b['Value']/divisor
        result[iid]={'options':options,'extra_options':extras,'invokes':invokes,'blessing':blessing,
                     'category_id':raw.get('CategoryID',0),'grade_id':raw.get('GradeID',0),
                     'material_id':raw.get('MaterialID',0), 'unconnected_effect_row_ids':sorted(skipped)}
    return result
