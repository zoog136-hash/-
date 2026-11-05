"""Exact native damage profiles for the existing TWILIGHT skill executor.
Raw spell references are never converted into damage; unknown effect sets stay pending.
"""
DAMAGE_NAMES={'SpellDamageBase','SpellDamageDiceNumber','SpellDamageDiceSpotCount'}
FLAGS={'FixedMagicDamage','IgnoreMagicResistance','IgnoreDamageReductionCalculation'}

def compile_profile(profile):
    raw=profile['source_spell'];effects=profile['effects'];values={}
    if raw.get('TestSpell') or raw.get('TargettingTypeID')!=2 or raw.get('TargetKindID')!=11 or raw.get('TargetAreaRadius')!=0:
        return None
    if any(raw.get(k,0)!=0 for k in ['SiegeTargetKindID','HPCost','MPCost','VPCost','SpellMaterialTypeID','SpellMaterialItemAmount','SpellCompositionNode','CopySpellClassID','IsChargeSpell','CastingWeaponType','AlignmentChangeAmount','TargetLimitCount','BackwardPathCount']):return None
    for effect in effects:
        link,b,t=effect['link'],effect['bonus'],effect['type'];name=t['Name']
        if name not in DAMAGE_NAMES|FLAGS or name in values or link.get('MinSpellLevel')!=0 or b.get('BonusApplicationTypeID')!=0 or b.get('BonusApplicationTargetID')!=0:return None
        if t['UnitID']!=(20 if name in {'FixedMagicDamage','IgnoreMagicResistance'} else 1):return None
        if type(b['Value']) is not int or b['Value']<0:return None
        values[name]=b['Value']
    if not values or not any(n in values for n in DAMAGE_NAMES):return None
    present_flags=set(values)&FLAGS
    if present_flags and (present_flags!=FLAGS or any(values[k]!=1 for k in FLAGS)):return None
    count=values.get('SpellDamageDiceNumber',0);spots=values.get('SpellDamageDiceSpotCount',0)
    if count>100 or spots>1000000 or (count>0 and spots<1) or values.get('SpellDamageBase',0)>1000000:return None
    if raw.get('ElementalTypeID') not in [0,1,2,3,4] or raw.get('MinCastRange',0)>raw.get('CastRange',0):return None
    if values.get('SpellDamageBase',0)+count*spots<=0:return None
    if any(not isinstance(raw.get(k),int) or isinstance(raw.get(k),bool) or raw[k]<0 for k in ['CastRange','MinCastRange','CastDelay']):return None
    return {**profile,'schema':'patch523-equipment-damage-spell-v1','values':values,
            'mode':'fixed_ignore_mr_dr' if present_flags else 'source_dice_magic',
            'source_target_kind':{'ID':11,'Name':'AllButMe','RootTargetKindNodeID':41},
            'host_interpretation':'existing magic hit/element/target-flat-reduction stages; no extra skill cost/critical/drain/recursive proc'}

BUFF_FIELDS={
 'ArmorClassBonus':('ac',1,-1),'MagicResist':('mr',1,1),'DamageReduction':('reduction',1,1),
 'PVPDamageReduction':('reduction',1,1),'RangeDamageReduction':('source_ranged_reduction',1,1),
 'MeleeHit':('source_melee_hit',1,1),'RangeHit':('source_ranged_hit',1,1),
 'MeleeDamage':('source_melee_damage',1,1),'RangeDamage':('source_ranged_damage',1,1),
 'MeleeEvasion':('source_melee_evasion',1,1),'RangeEvasion':('source_ranged_evasion',1,1),
 'AttackSpeedBonus':('source_attack_speed_pct',3,1/10000),
 'HPHealDecreasePercent':('source_hp_heal_decrease_raw',3,1),'HPPotionDecreasePercent':('source_potion_heal_decrease_raw',3,1),
 'MeleeDamageReductionPercent':('source_melee_reduction_pct',3,1/10000),
 'RangeDamageReductionPercent':('source_ranged_reduction_pct',3,1/10000),
 'MagicDamageReductionPercent':('source_magic_reduction_pct',3,1/10000),
}
PROB_FIELDS={'SpellHitProbabilityBase':3,'SpellHitProbabilityMin':3,'SpellHitProbabilityMax':3,'SpellHitProbabilityMultiplier':1,'SpellHitProbabilityByLevel':20}
def compile_buff_profile(profile,buffs):
 raw=profile['source_spell'];values={}
 if raw.get('TestSpell') or raw.get('TargettingTypeID')!=2 or raw.get('TargetKindID') not in [10,11,422] or raw.get('TargetAreaRadius')!=0:return None
 if any(raw.get(k,0)!=0 for k in ['SiegeTargetKindID','HPCost','MPCost','VPCost','SpellMaterialTypeID','SpellMaterialItemAmount','SpellCompositionNode','CopySpellClassID','IsChargeSpell','CastingWeaponType','AlignmentChangeAmount','TargetLimitCount','BackwardPathCount']):return None
 allowed={'BuffClassID':16,'SpellDebuffMinDuration':17,'SpellDebuffMaxDuration':17,**PROB_FIELDS}
 for e in profile['effects']:
  link,b,t=e['link'],e['bonus'],e['type'];name=t['Name']
  if name not in allowed or name in values or t['UnitID']!=allowed[name] or link['MinSpellLevel'] or b['BonusApplicationTypeID'] or b['BonusApplicationTargetID']:return None
  values[name]=b['Value']
 if not {'BuffClassID','SpellDebuffMinDuration','SpellDebuffMaxDuration'}<=values.keys():return None
 if not 0<values['SpellDebuffMinDuration']<=values['SpellDebuffMaxDuration']<=86400:return None
 if 'SpellHitProbabilityMultiplier' in values and not {'SpellHitProbabilityBase','SpellHitProbabilityMax'}<=values.keys():return None
 buff=buffs.get(str(values['BuffClassID']))
 if not buff:return None
 br=buff['source_buff'];modifiers={}
 if not br.get('IsEraseOnTimeEnd') or br.get('MaxStackCount') or br.get('IsBuffGroup') or br.get('IsAbsoluteTimeBuff'):return None
 if any(v for k,v in br.items() if k.startswith('IsEraseOn') and k!='IsEraseOnTimeEnd'):return None
 for e in buff['effects']:
  link,b,t=e['link'],e['bonus'],e['type'];name=t['Name']
  if any(link.get(k,0) for k in ['CharacterLevel','CharacterClass','MinSpellLevel']):return None
  if name=='SpecialResistance' and t['UnitID']==3 and b['BonusApplicationTypeID']==2 and b['BonusApplicationTargetID']==6:
   key,amount='source_stun_resistance',b['Value']/10000
  elif name in BUFF_FIELDS and t['UnitID']==BUFF_FIELDS[name][1] and not b['BonusApplicationTypeID'] and not b['BonusApplicationTargetID']:
   key,_,factor=BUFF_FIELDS[name];amount=b['Value']*factor
  elif name=='CannotMove' and t['UnitID']==20 and b['Value']==1 and not b['BonusApplicationTypeID'] and not b['BonusApplicationTargetID']:
   key,amount='source_hold',1
  else:return None
  modifiers[key]=modifiers.get(key,0)+amount
 if not modifiers:return None
 return {**profile,'schema':'patch523-equipment-damage-spell-v1','mode':'source_buff_modifiers','values':values,'buff':buff,'modifiers':modifiers,
         'source_target_kind':{'ID':raw['TargetKindID'],'Name':{10:'TargetNEnemy',11:'AllButMe',422:'AttackableNPC'}[raw['TargetKindID']]},
         'host_interpretation':'existing life-scoped status owner; source duration/stat units, native buff-group priority; labelled configurable MR/level chance formula'}
