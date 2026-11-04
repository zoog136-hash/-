"""Translate exact 523 level rows; retain conditional/proc rows as evidence.

Only host numeric consumers with matching units are emitted. Raw source tables
remain in the private pack. Level rows are alternatives, never summed by rank.
"""
from collections import defaultdict

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
}
EXTRA = {
    'Strength':('strFlat',1), 'Dexterity':('dexFlat',1), 'Intelligence':('intFlat',1),
    'RangeEvasion':('er',1), 'MeleeEvasion':('dg',1), 'RegenMP':('mpRecoveryTick',1),
    'MagicDamage':('magicDamage',1), 'AttackSpeedBonus':('attackSpeed',10000),
    'MoveSpeedBonus':('speedBonusPct',10000),
    'PVEDamageReduction':('pve_damage_reduction',1), 'PVPDamageReduction':('pve_damage_reduction',1),
    'PVEDamageReductionPercent':('pve_damage_reduction_pct',10000),
    'MeleeCritical':('melee_crit',1), 'RangeCritical':('ranged_crit',1), 'MagicCritical':('magic_crit',1),
    'PierceDamageReduction':('damage_reduction_ignore',1),
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
}


def compile_equipment(tables, bound_items, bonuses):
    types = {r['ID']:r for r in tables['BonusType']}
    invoke_options = {r['ID']:r for r in tables.get('InvokeOption',[])}
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
                        # Fully numeric source contracts only. Spell/formula,
                        # material, weapon/shield and chained hooks stay typed
                        # evidence until their authoritative execution contract.
                        if (kind in [3,5] and types[b['BonusTypeID']]['UnitID']==3 and 0<=b['Value']<=1000000
                            and all(option.get(k,0)==0 for k in ['Param2','Param3','Param4','Param5','Param6','MaterialTypeID','MaterialAmount','IsAmmoAttack','WeaponGroupID','ShieldTypeID','SuccessedInvokeOptionID','TargetKind','SiegeTargetKind'])
                            and option.get('AttackTypeID') in [0,1,2,3] and option.get('Param1',-1)>=0):
                            live_invokes.append({'row_id':row['ID'],'probability':b['Value'],'option':option,
                                                 'kind':'attack_fixed_damage' if kind==3 else 'defence_flat_reduction'})
                            continue
                    if b['BonusApplicationTypeID'] or b['BonusApplicationTargetID']:
                        if name == 'SpecialResistance' and b['BonusApplicationTypeID']==2 and b['BonusApplicationTargetID']==6:
                            name = '_stun'
                        elif name == 'IncreaseNpcItemDropAmount' and b['BonusApplicationTypeID']==5 and b['BonusApplicationTargetID']==26:
                            # Original ItemClass26 is Adena, not every item.
                            name = '_adena_drop'
                        else:
                            skipped.add(row['ID']); continue
                    spec = FIELDS.get(name)
                    if name == '_stun': spec = ('stun_resistance','stun_resistance',10000)
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
                        n=types[bonuses[str(row['BonusID'])]['BonusTypeID']]['Name']
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
                    b=bonuses[str(row['BonusID'])]; name=types[b['BonusTypeID']]['Name']
                    adena = name=='IncreaseNpcItemDropAmount' and b['BonusApplicationTypeID']==5 and b['BonusApplicationTargetID']==26
                    if adena: name='_adena_drop'
                    if name in EXTRA and (adena or (b['BonusApplicationTypeID']==0 and b['BonusApplicationTargetID']==0)):
                        key,_=EXTRA[name]
                        if key in extra and not isinstance(extra[key],dict): extra[key]={'total':extra[key],'base_key':key,'scale':1}
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
