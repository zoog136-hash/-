"""Compile typed item effects from verified private patch523 source joins.

Drop chances/counts stay with the host. Source rows and unsupported conditions
remain intact. Missing behavior interpreted locally is explicitly labeled with
its configurable policy instead of being presented as an original formula.
"""
from __future__ import annotations

from collections import defaultdict
from copy import deepcopy


ITEM_TABLES = (
    'ItemClass', 'ItemCategory', 'Grade', 'EquipSlot', 'ItemEquipSlot',
    'ItemBonus', 'Bonus', 'BonusType', 'Unit', 'Class', 'ItemClassLimit',
    'WeaponType', 'BuffCard', 'BuffCardDeck', 'ServerLimit',
    'BuffClass', 'BuffGroup', 'BuffBonus',
    'InvokeOption', 'InvokeOptionType', 'BonusApplicationType', 'UIUnit',
    'LuckyBagClass', 'LuckyBagEntityType', 'LuckyBagEntityView',
    'LuckyBagEntityClassLimit',
    'SpellClass', 'SpellBonus', 'SpellMaterialType', 'SpecialResistanceType',
    'TargettingType', 'TargetKind', 'SpellCategory',
)

SLOT_MAP = {
    'Head': 'helmet', 'Torso': 'body', 'Shirt': 'tshirt', 'Cloak': 'cloak',
    'Leg': 'gaiters', 'Foot': 'boots', 'Hand': 'gloves',
    'WeaponHold': 'weapon', 'Finger': 'ring', 'Neck': 'necklace',
    'Waist': 'belt', 'Ear': 'earring', 'ShieldHold': 'offhand',
    'Quiver': 'offhand', 'Rune': 'rune', 'SpellRune': 'rune',
    'Badge': 'seal', 'Insignia': 'badge', 'Spaulder': 'shoulder',
    'Bangle_normal': 'bracelet', 'Bangle_BM': 'bracelet',
    'Crest': 'crystal', 'Catalyst': 'catalyst',
    'DominationStone': 'domination_stone',
}

# Source ArmorClass is a positive defense amount. The host uses positive def
# and negates total defense when presenting signed AC.
FLAT_EQUIPMENT_BONUSES = {
    'WeaponSmallDamage': 'small_damage', 'WeaponLargeDamage': 'large_damage',
    'WeaponHitBonus': 'hit', 'WeaponDamageBonus': 'additionalDamage',
    'ArmorClass': 'def', 'ArmorClassBonus': 'def',
    'Strength': 'strFlat', 'Dexterity': 'dexFlat', 'Constitution': 'conFlat',
    'Intelligence': 'intFlat', 'Wisdom': 'wisFlat', 'Charisma': 'chaFlat',
    'HPPlus': 'hpFlat', 'MPPlus': 'mpFlat', 'MagicResist': 'mr',
    'DamageReduction': 'damage_reduction', 'SpellPower': 'sp',
    'MeleeDamage': 'meleeDamage', 'RangeDamage': 'rangedDamage',
    'MagicDamage': 'magicDamage', 'MeleeHit': 'meleeHit',
    'RangeHit': 'rangedHit', 'MagicHit': 'magicHit',
}
HP_BONUSES = (
    'HPRestoration', 'HPRestorationDiceNumber', 'HPRestorationDiceSpotCount',
)
COLLECTIBLE_CARD_DECKS = {
    (1, 'PolymorphCardDeck'): '변신',
    (2, 'MagicDollCardDeck'): '마법인형',
    (98, 'HolyStuffCardDeck'): '성물',
}
FLAT_ITEM_BUFF_BONUSES = {
    'ArmorClass': 'def', 'ArmorClassBonus': 'def',
    'Strength': 'strFlat', 'Dexterity': 'dexFlat', 'Constitution': 'conFlat',
    'Intelligence': 'intFlat', 'Wisdom': 'wisFlat', 'Charisma': 'chaFlat',
    'HPPlus': 'hp_flat', 'MPPlus': 'mp_flat', 'MagicResist': 'mr',
    'DamageReduction': 'damage_reduction', 'SpellPower': 'sp',
    'MeleeDamage': 'melee_damage', 'RangeDamage': 'ranged_damage',
    'MagicDamage': 'magic_damage', 'MeleeHit': 'melee_accuracy',
    'RangeHit': 'ranged_accuracy', 'MagicHit': 'magic_accuracy',
}
BUFF_UNSUPPORTED_ACTION_FIELDS = (
    'IsEraseOnAttack', 'IsEraseOnAttacked', 'IsEraseOnMove',
    'IsEraseOnSpellCastAndShieldIt', 'IsEraseOnSkillCastAndShieldIt',
    'IsEraseOnItemUse', 'IsEraseOnSpellAttacked', 'IsEraseOnSkillAttacked',
    'IsEraseOnCast', 'IsEraseOnHealed', 'IsEraseOnTargetChanged',
    'IsEraseOnAttackedLimitations',
)


def _index(rows: list[dict], table: str) -> dict:
    result = {}
    for row in rows:
        key = row['ID']
        if key in result:
            raise ValueError(f'duplicate source ID: {table} #{key}')
        result[key] = row
    return result


def _lookup(indexes: dict, table: str, key: int, item_id: int) -> dict:
    try:
        return indexes[table][key]
    except KeyError as exc:
        raise ValueError(f'dangling source item #{item_id}: {table} #{key}') from exc


def _description(descriptions: dict, key: int) -> str:
    value = descriptions.get(key, descriptions.get(str(key), ''))
    return value.strip() if isinstance(value, str) else ''


def _host_slot(row: dict) -> str | None:
    name = row['equip_slot']['Name']
    # This dedicated host slot represents the verified original slot 293 only.
    if name == 'DominationStone' and row['EquipSlotID'] != 293:
        return None
    return SLOT_MAP.get(name)


def _unconditional(row: dict) -> bool:
    bonus = row['bonus']
    return (row.get('IsPossession') is False
            and bonus.get('BonusApplicationTypeID') == 0
            and bonus.get('BonusApplicationTargetID') == 0)


def _flat_value(row: dict) -> bool:
    # bools and fractional numbers are not interchangeable with a source int.
    return (row['unit']['Name'] == 'Value'
            and type(row['bonus'].get('Value')) is int)


def _unsupported_reason(row: dict, equipment: bool) -> str:
    bonus = row['bonus']
    if row.get('IsPossession') is not False:
        return 'possession_effect_not_applied'
    if (bonus.get('BonusApplicationTypeID') != 0
            or bonus.get('BonusApplicationTargetID') != 0):
        return 'conditional_effect_not_applied'
    if not equipment:
        return 'item_use_or_nonwearable_effect_not_applied'
    if row['unit']['Name'] != 'Value':
        return 'nonflat_unit_not_applied'
    if type(bonus.get('Value')) is not int:
        return 'noninteger_value_not_applied'
    return 'host_effect_not_implemented'


def _hp_spec(rows: list[dict], category: dict) -> tuple[dict, set[int]]:
    """Represent a source HP formula verbatim; never average its dice."""
    if category['Name'] != 'Potion':
        return {}, set()
    values = defaultdict(list)
    for number, row in enumerate(rows):
        name = row['bonus_type']['Name']
        if name in HP_BONUSES and _unconditional(row) and _flat_value(row):
            values[name].append((number, row['bonus']['Value']))
    if not values or any(len(group) != 1 for group in values.values()):
        return {}, set()
    spec = {name: group[0][1] for name, group in values.items()}
    dice = spec.get('HPRestorationDiceNumber', 0)
    sides = spec.get('HPRestorationDiceSpotCount', 0)
    # An incomplete/negative dice formula has no safely executable meaning.
    if (dice < 0 or sides < 0 or bool(dice) != bool(sides)
            or spec.get('HPRestoration', 0) + dice * sides <= 0):
        return {}, set()
    spec['kind'] = 'source_hp_dice'
    spec['routing_policy'] = 'heal_is_base_or_positive_indicator_not_expected_value'
    return spec, {group[0][0] for group in values.values()}


def _fixed_card_spec(rows: list[dict], category: dict, indexes: dict,
                     server_limits: dict, item_id: int) -> tuple[dict, set[int]]:
    """Describe one exact collectible card; never turn a ticket into a draw."""
    if category['Name'] != 'BuffCardDrawer' or category.get('IsConsumable') is not True:
        return {}, set()
    references = [(number, row) for number, row in enumerate(rows)
                  if row['bonus_type']['Name'] == 'BuffCardID']
    if len(references) != 1:
        return {}, set()
    number, link = references[0]
    if not _unconditional(link) or link['unit']['Name'] != 'BuffCardID':
        return {}, set()
    card = _lookup(indexes, 'BuffCard', link['bonus']['Value'], item_id)
    deck = _lookup(indexes, 'BuffCardDeck', card['BuffCardDeckID'], item_id)
    kind = COLLECTIBLE_CARD_DECKS.get((deck['ID'], deck['Name']))
    if not kind or card.get('SpellClassID', 0) != 0:
        return {}, set()
    handled = {number}
    cannot_swap = []
    for index, row in enumerate(rows):
        if index == number:
            continue
        # An additional item effect cannot be silently discarded on activation.
        if (row['bonus_type']['Name'] != 'BuffCardCannotSwap'
                or not _unconditional(row) or row['unit']['Name'] != 'TrueFalse'
                or type(row['bonus'].get('Value')) is not int
                or row['bonus']['Value'] not in (0, 1)):
            return {}, set()
        cannot_swap.append(row['bonus']['Value'])
        handled.add(index)
    if len(cannot_swap) > 1:
        return {}, set()
    limit_id = card.get('ServerLimitSetID', 0)
    limits = server_limits.get(limit_id, []) if limit_id else []
    status = 'unrestricted'
    if limit_id:
        status = 'server_context_required' if limits else 'server_definition_missing'
    if card.get('StartDateTimeID', 0) or card.get('EndDateTimeID', 0):
        status = 'source_date_window_unresolved'
    return {
        'kind': 'fixed_card', 'card_kind': kind, 'card_id': card['ID'],
        'deck_id': deck['ID'], 'original_card': deepcopy(card),
        'original_deck': deepcopy(deck),
        # Runtime must compare original_card with its registered target's full
        # source_original_card before using this cross-snapshot identity.
        'host_card_identity': f'source:m508:{deck["ID"]}:{card["ID"]}',
        'host_binding_policy': 'exact_ID_and_full_original_card_equality',
        'server_limit_set_id': limit_id, 'server_limits': deepcopy(limits),
        'start_datetime_id': card.get('StartDateTimeID', 0),
        'end_datetime_id': card.get('EndDateTimeID', 0),
        'activation_status': status,
        'buff_card_cannot_swap': bool(cannot_swap and cannot_swap[0]),
        'source_card_bonus_id': link['BonusID'],
        'source_card_item_bonus_id': link['ID'],
        'quantity': 1,
    }, handled


def _activation_metadata(rows: list[dict], original: dict, category: dict,
                         permitted: dict, require_delay: bool = True) -> tuple[dict, list[str]]:
    """Fail closed on source lifecycle/use rules that have no host reducer."""
    reasons = []
    if category.get('IsConsumable') is not True:
        reasons.append('source_category_not_consumable')
    if original.get('TestItem') is not False:
        reasons.append('source_test_item')
    if original.get('TargettingTypeID') != 1:
        reasons.append('unsupported_targetting_type')
    if original.get('ServiceRegionCode', ''):
        reasons.append('source_service_region_context_required')
    values = defaultdict(list)
    for row in rows:
        name = row['bonus_type']['Name']
        if not _unconditional(row):
            reasons.append('conditional_or_possession_item_bonus:' + name)
        elif name not in permitted:
            reasons.append({'DeleteTime': 'source_item_lifetime_unresolved',
                            'InfiniteAmount': 'source_infinite_amount_not_supported'}.get(
                                name, 'unsupported_item_bonus:' + name))
        elif (row['unit']['Name'] != permitted[name]
              or type(row['bonus'].get('Value')) is not int):
            reasons.append('unsupported_item_bonus_unit_or_value:' + name)
        else:
            values[name].append(row['bonus']['Value'])
    if len(values.get('ItemConsumeDelay', [])) > 1 or (
            require_delay and not values.get('ItemConsumeDelay')):
        reasons.append('missing_or_ambiguous_consume_delay')
    elif values.get('ItemConsumeDelay') and values['ItemConsumeDelay'][0] < 0:
        reasons.append('invalid_consume_delay')
    if len(values.get('ItemConsumeEffectSpriteID', [])) > 1:
        reasons.append('ambiguous_consume_sprite')
    metadata = {
        'targetting_type_id': original.get('TargettingTypeID'),
        'can_use_when_invisible': original.get('CanUseWhenInvisible'),
        'consume_delay_ms': values.get('ItemConsumeDelay', [None])[0],
        'consume_effect_sprite_id': values.get('ItemConsumeEffectSpriteID', [0])[0],
    }
    return metadata, reasons


def _timed_buff_spec(rows: list[dict], original: dict, category: dict,
                     indexes: dict, buff_bonuses: dict, item_id: int) -> tuple[dict, set[int]]:
    references = [row for row in rows if row['bonus_type']['Name'] == 'BuffClassID']
    if len(references) != 1:
        return {}, set()
    reference = references[0]
    if (reference['unit']['Name'] != 'BuffClassID'
            or type(reference['bonus'].get('Value')) is not int):
        return {}, set()
    buff = _lookup(indexes, 'BuffClass', reference['bonus']['Value'], item_id)
    group = _lookup(indexes, 'BuffGroup', buff['BuffGroupID'], item_id)
    metadata, reasons = _activation_metadata(rows, original, category, {
        'BuffClassID': 'BuffClassID', 'BuffDuration': 'Seconds',
        'ItemConsumeDelay': 'MilliSeconds', 'ItemConsumeEffectSpriteID': 'SpriteID',
    })
    durations = [row['bonus']['Value'] for row in rows
                 if row['bonus_type']['Name'] == 'BuffDuration'
                 and _unconditional(row) and row['unit']['Name'] == 'Seconds'
                 and type(row['bonus'].get('Value')) is int]
    duration = durations[0] if len(durations) == 1 else 0
    if len(durations) != 1 or duration <= 0:
        reasons.append('missing_or_ambiguous_positive_duration')
    linked_effects, typed = [], {}
    for row in buff_bonuses.get(buff['ID'], []):
        bonus = _lookup(indexes, 'Bonus', row['BonusID'], item_id)
        kind = _lookup(indexes, 'BonusType', bonus['BonusTypeID'], item_id)
        unit = _lookup(indexes, 'Unit', kind['UnitID'], item_id)
        linked_effects.append({**deepcopy(row), 'bonus': deepcopy(bonus),
                               'bonus_type': deepcopy(kind), 'unit': deepcopy(unit)})
        if (any(row.get(key) != 0 for key in
                ('CharacterLevel', 'CharacterClass', 'MinSpellLevel'))
                or bonus.get('BonusApplicationTypeID') != 0
                or bonus.get('BonusApplicationTargetID') != 0):
            reasons.append('conditional_buff_effect:' + kind['Name'])
        elif (unit['Name'] != 'Value' or type(bonus.get('Value')) is not int
              or kind['Name'] not in FLAT_ITEM_BUFF_BONUSES):
            reasons.append('unsupported_buff_effect:' + kind['Name'])
        else:
            field = FLAT_ITEM_BUFF_BONUSES[kind['Name']]
            typed[field] = typed.get(field, 0) + bonus['Value']
    if not linked_effects or not typed:
        reasons.append('no_supported_buff_effects')
    if buff.get('IsGood') is not True or buff.get('IsBuffGroup') is not True:
        reasons.append('unsupported_buff_kind')
    if buff.get('IsEraseOnTimeEnd') is not True:
        reasons.append('source_buff_timer_semantics_unresolved')
    for name in BUFF_UNSUPPORTED_ACTION_FIELDS:
        if buff.get(name, 0):
            reasons.append('unsupported_buff_action_rule:' + name)
    for name in ('MaxHPPercent', 'EraseOnLevel', 'MaxStackCount', 'MPCostPercent',
                 'MinMPCost', 'IsAbsoluteTimeBuff', 'IsOverlapByPlayer',
                 'IsDecreaseStackOnTimeEnd', 'IsObtainItemBuff'):
        if buff.get(name, 0):
            reasons.append('unsupported_buff_state_rule:' + name)
    if (group.get('IsAllowPriority') is not False
            or group.get('IsEraseBySpellLevel') is not False
            or buff.get('BuffGroupPriority') != 1):
        reasons.append('unsupported_buff_priority_or_spell_level_rule')
    if (type(group.get('IsAllowOverlap')) is not bool
            or type(buff.get('IsImmuneToDead')) is not bool
            or type(buff.get('IsImmuneToCancellation')) is not bool):
        reasons.append('missing_buff_lifecycle_flags')
    reasons = list(dict.fromkeys(reasons))
    spec = {
        'kind': 'source_timed_buff', 'source_snapshot': 'patch523',
        'source_item_class_id': item_id, **metadata,
        'buff_class_id': buff['ID'], 'duration_seconds': duration,
        'typed_effects': typed, 'source_buff_class': deepcopy(buff),
        'source_buff_group': deepcopy(group), 'source_buff_bonus': linked_effects,
        'source_item_bonus_ids': [row['ID'] for row in rows],
        'activation_status': 'blocked' if reasons else 'unrestricted',
        'blocked_reasons': reasons,
    }
    return spec, set(range(len(rows))) if not reasons else set()


def _mp_spec(rows: list[dict], original: dict, category: dict,
             item_id: int) -> tuple[dict, set[int]]:
    names = ('MPRestoration', 'MPRestorationDiceNumber', 'MPRestorationDiceSpotCount')
    if not any(row['bonus_type']['Name'] in names for row in rows):
        return {}, set()
    metadata, reasons = _activation_metadata(rows, original, category, {
        **{name: 'Value' for name in names},
        'ItemConsumeDelay': 'MilliSeconds', 'ItemConsumeEffectSpriteID': 'SpriteID',
    })
    values = defaultdict(list)
    for row in rows:
        name = row['bonus_type']['Name']
        if name in names and _unconditional(row) and _flat_value(row):
            values[name].append(row['bonus']['Value'])
    if any(len(group) != 1 for group in values.values()):
        reasons.append('ambiguous_mp_formula')
    formula = {name: group[0] for name, group in values.items()}
    base = formula.get('MPRestoration', 0)
    count = formula.get('MPRestorationDiceNumber', 0)
    sides = formula.get('MPRestorationDiceSpotCount', 0)
    if (base < 0 or count < 0 or sides < 0 or bool(count) != bool(sides)
            or base + count * sides <= 0):
        reasons.append('invalid_mp_formula')
    reasons = list(dict.fromkeys(reasons))
    spec = {
        'kind': 'source_mp_dice', 'source_snapshot': 'patch523',
        'source_item_class_id': item_id, **metadata, **formula,
        'base': base, 'dice_number': count, 'dice_spot_count': sides,
        'source_item_bonus_ids': [row['ID'] for row in rows],
        'activation_status': 'blocked' if reasons else 'unrestricted',
        'blocked_reasons': reasons,
    }
    return spec, set(range(len(rows))) if not reasons else set()


def _effect_rows(indexes: dict, table: str, foreign_key: str,
                 source_id: int, item_id: int) -> list[dict]:
    cache_key = '_grouped_' + table
    if cache_key not in indexes:
        grouped = defaultdict(list)
        for row in indexes[table].values():
            grouped[row[foreign_key]].append(row)
        indexes[cache_key] = grouped
    linked = []
    for row in indexes[cache_key].get(source_id, []):
        bonus = _lookup(indexes, 'Bonus', row['BonusID'], item_id)
        kind = _lookup(indexes, 'BonusType', bonus['BonusTypeID'], item_id)
        unit = _lookup(indexes, 'Unit', kind['UnitID'], item_id)
        linked.append({**deepcopy(row), 'bonus': deepcopy(bonus),
                       'bonus_type': deepcopy(kind), 'unit': deepcopy(unit)})
    return linked


def _source_bleed(option: dict, indexes: dict, item_id: int) -> tuple[dict, list[str]]:
    """Preserve the exact 17564/51984 chain and label the authorized local rules."""
    reasons = []
    spell = _lookup(indexes, 'SpellClass', option['Param1'], item_id)
    spell_effects = _effect_rows(indexes, 'SpellBonus', 'SpellClassID', spell['ID'], item_id)
    expected_spell = {
        'SpecialResistanceTypeID': ('SpecialResistanceTypeID', 22),
        'SpellDebuffMaxDuration': ('Seconds', 3),
        'SpellDebuffMinDuration': ('Seconds', 3),
        'BuffClassID': ('BuffClassID', 51984),
    }
    values = {}
    for row in spell_effects:
        name, bonus = row['bonus_type']['Name'], row['bonus']
        if (name in values or name not in expected_spell or row.get('MinSpellLevel') != 0
                or bonus.get('BonusApplicationTypeID') != 0
                or bonus.get('BonusApplicationTargetID') != 0
                or type(bonus.get('Value')) is not int
                or (row['unit']['Name'], bonus['Value']) != expected_spell.get(name)):
            reasons.append('unsupported_source_bleed_spell_effect:' + name)
        values[name] = bonus['Value']
    if set(values) != set(expected_spell):
        reasons.append('incomplete_source_bleed_spell_effects')
    spell_values = values.copy()
    buff = _lookup(indexes, 'BuffClass', 51984, item_id)
    group = _lookup(indexes, 'BuffGroup', buff['BuffGroupID'], item_id)
    buff_effects = _effect_rows(indexes, 'BuffBonus', 'BuffClassID', buff['ID'], item_id)
    expected_buff = {
        'PoisonDamageDiceSpotCount': ('Value', 1),
        'PoisonDamageDiceNumber': ('Value', 10),
        'PoisonDamageMotion': ('TrueFalse', 1),
        'StatusEffectID': ('StatusEffectID', 16372),
    }
    values = {}
    for row in buff_effects:
        name, bonus = row['bonus_type']['Name'], row['bonus']
        if (name in values or name not in expected_buff
                or any(row.get(key) != 0 for key in
                       ('CharacterLevel', 'CharacterClass', 'MinSpellLevel'))
                or bonus.get('BonusApplicationTypeID') != 0
                or bonus.get('BonusApplicationTargetID') != 0
                or type(bonus.get('Value')) is not int
                or (row['unit']['Name'], bonus['Value']) != expected_buff.get(name)):
            reasons.append('unsupported_source_bleed_buff_effect:' + name)
        values[name] = bonus['Value']
    if set(values) != set(expected_buff):
        reasons.append('incomplete_source_bleed_buff_effects')
    material = _lookup(indexes, 'SpellMaterialType', spell['SpellMaterialTypeID'], item_id)
    targetting = _lookup(indexes, 'TargettingType', spell['TargettingTypeID'], item_id)
    target = _lookup(indexes, 'TargetKind', spell['TargetKindID'], item_id)
    category = _lookup(indexes, 'SpellCategory', spell['SpellCategoryID'], item_id)
    resistance = _lookup(indexes, 'SpecialResistanceType', 22, item_id)
    if ((spell['ID'], material['ID'], material['Name']) != (17564, 0, 'None')
            or (targetting['ID'], targetting['Name']) != (2, 'SingleObject')
            or (target['ID'], target['Name']) != (2, 'All')
            or (category['ID'], category['Name']) != (8, 'SpellDebuff')
            or (resistance['ID'], resistance['Name']) != (22, 'Poison')):
        reasons.append('unsupported_source_bleed_spell_kind')
    if spell.get('TestSpell') is not False:
        reasons.append('source_bleed_test_spell')
    for name in ('HPCost', 'MPCost', 'VPCost', 'SpellMaterialItemAmount', 'CastDelay',
                 'TargetAreaRadius', 'SiegeTargetKindID', 'SpellCompositionNode',
                 'MinCastRange', 'TargetLimitCount', 'CopySpellClassID', 'IsChargeSpell',
                 'IsRequireSpellGroupMastery', 'SpellGroupLevel', 'BackwardPathCount'):
        if spell.get(name, 0):
            reasons.append('unsupported_source_bleed_spell_rule:' + name)
    if (buff['ID'] != 51984 or group['ID'] != 564
            or buff.get('IsGood') is not False or buff.get('IsBuffGroup') is not False
            or buff.get('BuffGroupPriority') != 0 or buff.get('MaxHPPercent') != 50
            or buff.get('IsEraseOnTimeEnd') is not True
            or buff.get('IsImmuneToDead') is not False
            or buff.get('IsImmuneToCancellation') is not False
            or any(group.get(key) is not False for key in
                   ('IsAllowOverlap', 'IsAllowPriority', 'IsEraseBySpellLevel'))):
        reasons.append('unsupported_source_bleed_lifecycle')
    for name in (*BUFF_UNSUPPORTED_ACTION_FIELDS, 'MaxStackCount', 'EraseOnLevel',
                 'IsAbsoluteTimeBuff', 'MPCostPercent', 'MinMPCost', 'IsOverlapByPlayer',
                 'IsDecreaseStackOnTimeEnd', 'IsObtainItemBuff'):
        if buff.get(name, 0):
            reasons.append('unsupported_source_bleed_buff_rule:' + name)
    return {
        'spell_class_id': spell['ID'], 'buff_class_id': buff['ID'],
        'duration_seconds': spell_values.get('SpellDebuffMinDuration', 0),
        'damage_dice_number': values.get('PoisonDamageDiceNumber', 0),
        'damage_dice_spot_count': values.get('PoisonDamageDiceSpotCount', 0),
        'source_max_hp_percent': buff['MaxHPPercent'],
        'source_spell_class': deepcopy(spell), 'source_spell_bonus': spell_effects,
        'source_buff_class': deepcopy(buff), 'source_buff_group': deepcopy(group),
        'source_buff_bonus': buff_effects, 'source_special_resistance_type': deepcopy(resistance),
        'source_spell_material_type': deepcopy(material),
        'source_targetting_type': deepcopy(targetting), 'source_target_kind': deepcopy(target),
        'source_spell_category': deepcopy(category),
        'local_interpretation': {
            'origin': 'local_estimate_after_source_and_public_research',
            'tick_interval_seconds': 0.75, 'tick_interval_origin': 'existing_host_default',
            'tick_interval_configuration_key': 'patch523_bleed_tick_interval_seconds',
            'max_hp_percent_semantics': 'total_bleed_damage_cap',
            'max_hp_percent_origin': 'local_estimate',
            'max_hp_percent_configuration_key': 'patch523_bleed_max_hp_rule',
        },
    }, list(dict.fromkeys(reasons))


def _invoke_options(rows: list[dict], indexes: dict, equipment: bool,
                    slot: str, item_id: int) -> list[dict]:
    """Keep contextual source invokes separate from passive/legacy stats."""
    result = []
    for row in rows:
        if row['bonus_type']['Name'] != 'InvokeOption':
            continue
        bonus = row['bonus']
        application = _lookup(indexes, 'BonusApplicationType',
                              bonus['BonusApplicationTypeID'], item_id)
        if application['Name'] != 'InvokeOption':
            result.append({'item_bonus': deepcopy(row),
                           'application_type': deepcopy(application),
                           'activation_status': 'blocked',
                           'blocked_reasons': ['unsupported_invoke_application_type']})
            continue
        option = _lookup(indexes, 'InvokeOption', bonus['BonusApplicationTargetID'], item_id)
        kind = _lookup(indexes, 'InvokeOptionType', option['InvokeOptionTypeID'], item_id)
        ui_units = [value for value in indexes['UIUnit'].values()
                    if value.get('UnitID') == row['unit']['ID']]
        reasons = []
        supported_kind = {
            (9, 'Attack_AddCriticalProbability'): 'normal_attack_additional_critical',
            (6, 'Attack_WeaponDamageScale'): 'normal_attack_weapon_scale',
        }.get((kind['ID'], kind['Name']))
        is_bleed = (kind['ID'], kind['Name'], option['ID'], option.get('Param1')) == (
            1, 'Attack_Spell', 611, 17564)
        if is_bleed:
            supported_kind = 'normal_attack_source_bleed'
            if (kind.get('Param1Unit') != 12
                    or indexes['Unit'].get(12, {}).get('Name') != 'SpellClassID'):
                reasons.append('unsupported_source_bleed_spell_reference_unit')
        if not supported_kind:
            reasons.append('source_invoke_effect_not_implemented')
        is_scale = supported_kind == 'normal_attack_weapon_scale'
        if is_scale and (type(option.get('Param1')) is not int or option['Param1'] <= 0):
            reasons.append('unsupported_invoke_weapon_scale')
        if not equipment or slot != 'weapon':
            reasons.append('source_invoke_requires_weapon')
        if (row.get('IsPossession') is not False or row['unit']['Name'] != 'Percentage'
                or type(bonus.get('Value')) is not int or not 0 <= bonus['Value'] <= 1000000
                or len(ui_units) != 1 or ui_units[0].get('Denominator') != 10000):
            reasons.append('unsupported_invoke_probability_units')
        if kind.get('IsDefence') is not False or option.get('BySpellAttack') is not False:
            reasons.append('unsupported_invoke_attack_trigger')
        for name in ('AttackTypeID', 'MaterialTypeID', 'MaterialAmount', 'WeaponGroupID',
                     'Param1', 'Param2', 'Param3', 'Param4', 'Param5', 'Param6',
                     'ShieldTypeID', 'SuccessedInvokeOptionID', 'IsAmmoAttack',
                     'TargetKind', 'SiegeTargetKind'):
            if name == 'Param1' and (is_scale or is_bleed):
                continue
            if option.get(name, 0):
                reasons.append('unsupported_invoke_condition:' + name)
        compiled = {
            'kind': supported_kind if not reasons else 'unsupported_source_invoke',
            'item_bonus': deepcopy(row), 'application_type': deepcopy(application),
            'invoke_option': deepcopy(option), 'invoke_option_type': deepcopy(kind),
            'ui_unit': deepcopy(ui_units[0]) if len(ui_units) == 1 else {},
            'probability_raw': bonus['Value'], 'probability_denominator': 1000000,
            'activation_status': 'blocked' if reasons else 'unrestricted',
            'blocked_reasons': reasons,
        }
        if is_scale:
            compiled.update({
                'scale_raw': option['Param1'], 'scale_denominator': 1000000,
                # Source type/Param1 establish the ratio. The weapon-component
                # boundary is an explicitly configured local estimate, informed
                # by the primary experiment, rather than a verified 523 formula.
                'component_boundary_origin': 'local_estimate_based_on_primary_experiment',
                'configuration_key': 'patch523_weapon_double_scope',
            })
        if is_bleed:
            bleed, bleed_reasons = _source_bleed(option, indexes, item_id)
            compiled.update(bleed)
            reasons.extend(bleed_reasons)
            compiled['blocked_reasons'] = reasons
            compiled['activation_status'] = 'blocked' if reasons else 'unrestricted'
            compiled['kind'] = supported_kind if not reasons else 'unsupported_source_invoke'
        result.append(compiled)
    return result


def _source_reward_bag_spec(rows: list[dict], original: dict, category: dict,
                            indexes: dict, entities: dict, class_limits: dict,
                            root_classes: list[dict], item_id: int) -> tuple[dict, set[int]]:
    references = [row for row in rows if row['bonus_type']['Name'] == 'LuckyBagClassID']
    if len(references) != 1:
        return {}, set()
    reference = references[0]
    if (reference['unit']['Name'] != 'LuckyBagClassID'
            or type(reference['bonus'].get('Value')) is not int):
        return {}, set()
    bag = _lookup(indexes, 'LuckyBagClass', reference['bonus']['Value'], item_id)
    source_entities = entities.get(bag['ID'], [])
    entity_types = {row['LuckyBagEntityTypeID'] for row in source_entities}
    # FinalReward and Selectable require a separate interaction model.
    if not source_entities or not entity_types <= {0, 1}:
        return {}, set()
    metadata, reasons = _activation_metadata(rows, original, category,
                                            {'LuckyBagClassID': 'LuckyBagClassID'},
                                            require_delay=False)
    if metadata['consume_delay_ms'] is None:
        del metadata['consume_delay_ms']
    rewards, linked_entities, distribution_reasons = [], [], []
    active_classes = {key: row for key, row in indexes['Class'].items()
                      if key > 0 and row.get('CanCreateClient') is True}
    root_class_ids = [row['ClassID'] for row in root_classes]
    domain = sorted(set(root_class_ids)) if root_class_ids else sorted(active_classes)
    if any(class_id not in active_classes for class_id in root_class_ids):
        distribution_reasons.append('unsupported_lucky_bag_root_class')
    for row in source_entities:
        kind = _lookup(indexes, 'LuckyBagEntityType', row['LuckyBagEntityTypeID'], item_id)
        if kind['Name'] != {0: 'Probability', 1: 'IsGiven'}[row['LuckyBagEntityTypeID']]:
            distribution_reasons.append('unsupported_lucky_bag_entity_type')
        output_item = _lookup(indexes, 'ItemClass', row['ItemClassID'], item_id)
        limits = class_limits.get(row['ID'], [])
        linked_limits = [{**deepcopy(limit), 'class': deepcopy(_lookup(
            indexes, 'Class', limit['ClassID'], item_id))} for limit in limits]
        class_ids = [limit['ClassID'] for limit in limits]
        if ((row.get('LimitClass') == 10000 and class_ids)
                or (row.get('LimitClass') != 10000 and row.get('LimitClass') not in class_ids)):
            distribution_reasons.append('unresolved_lucky_bag_class_limit')
        if any(class_id not in active_classes for class_id in class_ids):
            distribution_reasons.append('unsupported_lucky_bag_entity_class')
        if (output_item.get('TestItem') is not False
                and (row['LuckyBagEntityTypeID'] == 1
                     or (type(row.get('Probability')) is int and row['Probability'] > 0))
                and (not class_ids or any(class_id in domain for class_id in class_ids))):
            reasons.append('source_test_reward_item')
        initial_level = row.get('ItemEnchant')
        initial_level_supported = type(initial_level) is int and initial_level >= 0
        if initial_level_supported and initial_level > 0:
            output_equips = [
                {**equip, 'equip_slot': _lookup(indexes, 'EquipSlot', equip['EquipSlotID'], item_id)}
                for equip in indexes['_item_equip_rows'].get(row['ItemClassID'], [])]
            initial_level_supported = (
                bool(output_equips)
                and len({equip['EquipSlotID'] for equip in output_equips}) == 1
                and all(_host_slot(equip) is not None for equip in output_equips))
        # ItemEnchant is the reward's initial physical level, not an attempt.
        # Positive levels require one exact mapped source equipment slot.
        if (type(row.get('ItemAmount')) is not int or row['ItemAmount'] <= 0
                or row.get('ItemBlessCodeID') not in (1, 2, 3)
                or not initial_level_supported):
            reasons.append('unsupported_lucky_bag_reward_amount_or_variant')
        linked_entities.append({**deepcopy(row), 'entity_type': deepcopy(kind),
                                'class_limits': linked_limits})
        rewards.append({'source_entity_id': row['ID'],
                        'item_class_id': row['ItemClassID'], 'amount': row['ItemAmount'],
                        'bless_raw': row['ItemBlessCodeID'], 'enchant': row['ItemEnchant'],
                        'class_ids': class_ids, 'entity_type_id': kind['ID'],
                        'entity_type': kind['Name'], 'probability_raw': row['Probability']})
    weighted = [reward for reward in rewards if reward['entity_type_id'] == 0]
    totals = {}
    if weighted:
        if not domain:
            distribution_reasons.append('unresolved_lucky_bag_source_class_scope')
        if any(type(reward['probability_raw']) is not int or reward['probability_raw'] < 0
               for reward in weighted):
            distribution_reasons.append('invalid_lucky_bag_probability')
        for class_id in domain:
            total = sum(reward['probability_raw'] for reward in weighted
                        if (not reward['class_ids'] or class_id in reward['class_ids'])
                        and type(reward['probability_raw']) is int
                        and reward['probability_raw'] >= 0)
            totals[str(class_id)] = total
            if total != 10000000:
                distribution_reasons.append('incomplete_lucky_bag_probability_for_class:' + str(class_id))
    reasons = list(dict.fromkeys(reasons + distribution_reasons))
    spec = {
        'kind': ('guaranteed_bag' if not weighted else 'source_weighted_bag'
                 if entity_types == {0} else 'mixed_rewards_bag'),
        'source_snapshot': 'patch523',
        'source_item_class_id': item_id, **metadata,
        'lucky_bag_class_id': bag['ID'], 'original_lucky_bag_class': deepcopy(bag),
        'source_entities': linked_entities, 'rewards': rewards,
        'source_item_bonus_ids': [row['ID'] for row in rows],
        'activation_status': 'blocked' if reasons else 'unrestricted',
        'blocked_reasons': reasons,
    }
    if weighted:
        spec.update({
            'class_probability_totals': totals,
            'source_class_domain': domain,
            'source_class_domain_origin': ('ItemClassLimit' if root_class_ids
                                           else 'Class.CanCreateClient'),
            'reward_selection_model': 'local_single_weighted_draw',
            'random_draw_count': 1,
            'draw_count_origin': 'local_policy_not_source_count',
            'selection_configuration_key': 'patch523_reward_bag_draw_count',
        })
        # No renormalization, rounding or uniform fallback for incomplete pools.
        if not distribution_reasons:
            spec['source_probability_denominator'] = 10000000
    return spec, set(range(len(rows))) if not reasons else set()


def compile_items(tables: dict, descriptions: dict, wanted: set[int],
                  existing_bindings: dict) -> dict:
    """Return source definitions keyed by decimal source ItemClass ID.

    ``tables`` contains validated source row lists. ID-less relationship tables
    retain their order and multiplicity. Existing exact catalog bindings are
    copied separately; native names never fall back to another catalog item.
    """
    for name in ITEM_TABLES:
        if name not in tables:
            raise ValueError('missing source table: ' + name)
    indexes = {name: _index(tables[name], name) for name in ITEM_TABLES
               if name not in ('ItemBonus', 'ItemEquipSlot', 'ItemClassLimit',
                               'LuckyBagEntityClassLimit')}
    server_limits = defaultdict(list)
    for row in tables['ServerLimit']:
        server_limits[row['ServerLimitSetID']].append(row)
    buff_bonuses = defaultdict(list)
    for row in tables['BuffBonus']:
        buff_bonuses[row['BuffClassID']].append(row)
    bag_entities = defaultdict(list)
    for row in tables['LuckyBagEntityView']:
        bag_entities[row['LuckyBagClassID']].append(row)
    bag_class_limits = defaultdict(list)
    for row in tables['LuckyBagEntityClassLimit']:
        bag_class_limits[row['LuckyBagEntityID']].append(row)
    indexes['_item_equip_rows'] = defaultdict(list)
    for row in tables['ItemEquipSlot']:
        indexes['_item_equip_rows'][row['ItemClassID']].append(row)
    grouped = {}
    for name in ('ItemBonus', 'ItemEquipSlot', 'ItemClassLimit'):
        grouped[name] = defaultdict(list)
        for row in tables[name]:
            if row['ItemClassID'] in wanted:
                grouped[name][row['ItemClassID']].append(row)

    definitions = {}
    for item_id in sorted(wanted):
        original = _lookup(indexes, 'ItemClass', item_id, item_id)
        category = _lookup(indexes, 'ItemCategory', original['CategoryID'], item_id)
        grade = _lookup(indexes, 'Grade', original['GradeID'], item_id)
        label = (_description(descriptions, original['IdentifiedDescID'])
                 or _description(descriptions, original['DescID']))
        grade_label = _description(descriptions, grade['DescID'])
        if not label or not grade_label:
            raise ValueError(f'missing localized item/grade descriptor: item #{item_id}')

        bonuses = []
        for row in grouped['ItemBonus'][item_id]:
            bonus = _lookup(indexes, 'Bonus', row['BonusID'], item_id)
            kind = _lookup(indexes, 'BonusType', bonus['BonusTypeID'], item_id)
            unit = _lookup(indexes, 'Unit', kind['UnitID'], item_id)
            linked = {**deepcopy(row), 'bonus': deepcopy(bonus),
                      'bonus_type': deepcopy(kind), 'unit': deepcopy(unit)}
            if kind['Name'] == 'WeaponType' and unit['Name'] == 'WeaponTypeID':
                linked['weapon_type'] = deepcopy(_lookup(
                    indexes, 'WeaponType', bonus['Value'], item_id))
            bonuses.append(linked)
        equips = [{**deepcopy(row), 'equip_slot': deepcopy(_lookup(
            indexes, 'EquipSlot', row['EquipSlotID'], item_id))}
            for row in grouped['ItemEquipSlot'][item_id]]
        classes = [{**deepcopy(row), 'class': deepcopy(_lookup(
            indexes, 'Class', row['ClassID'], item_id))}
            for row in grouped['ItemClassLimit'][item_id]]
        slot_names = [row['equip_slot']['Name'] for row in equips]
        resolved_slots = [_host_slot(row) for row in equips]
        mapped_slots = {slot for slot in resolved_slots if slot is not None}
        # Unknown or conflicting source slots cannot become fictitious wearables.
        equipment = bool(slot_names) and len(mapped_slots) == 1 and all(
            slot is not None for slot in resolved_slots)
        slot = next(iter(mapped_slots)) if equipment else 'material'
        if not equipment and not equips:
            if category['Name'] == 'Currency':
                slot = 'currency'
            elif category['Name'] == 'Potion' or category.get('IsConsumable') is True:
                slot = 'consumable'
        equipment_status = ('mapped' if equipment else 'unsupported_source_slot'
                            if any(slot is None for slot in resolved_slots)
                            else 'ambiguous_source_equip_slots' if equips
                            else 'no_source_equip_slot')
        class_labels = [_description(descriptions, row['class']['DescID'])
                        for row in classes]
        unresolved_classes = [row['ClassID'] for row, name in zip(classes, class_labels)
                              if not name]
        source_id = f'm523:item:{item_id}'
        record = {
            'name': f'{label} · 원본#{item_id}', 'source_display_name': label,
            'source': 'lineagem_patch523', 'source_snapshot': 'patch523',
            'source_item_class_id': item_id, 'sourceId': source_id,
            'sourceUrl': '', 'source_m_native_item': True,
            'grade': grade_label, 'source_grade_id': grade['ID'],
            'slot': slot, 'type': _description(descriptions, category['DescID'])
                or category['Name'],
            'source_category_id': category['ID'],
            'source_category_name': category['Name'],
            'source_test_item': original.get('TestItem', False),
            'source_is_stackable': category.get('IsStackable', False),
            'source_is_consumable': category.get('IsConsumable', False),
            'source_weight': original.get('Weight', 0),
            'source_weight_unit': 'unverified_source_units',
            'source_equip_slots': slot_names,
            'source_equip_slot_ids': [row['EquipSlotID'] for row in equips],
            'source_equipment_status': equipment_status,
            'source_class_ids': [row['ClassID'] for row in classes],
            'source_class_names': class_labels,
            'source_unresolved_class_ids': unresolved_classes,
            'source_level_limit_min': original.get('LevelLimitMin', 0),
            'source_level_limit_max': original.get('LevelLimitMax', 0),
            'source_max_level_limit_min': original.get('MaxLevelLimitMin', 0),
            'source_max_level_limit_max': original.get('MaxLevelLimitMax', 0),
        }
        for key in ('Tradable', 'Storable', 'Droppable', 'Deletable'):
            value = original.get('Is' + key, False)
            record[key.lower()] = value
            record['source_is_' + key.lower()] = value
        if equipment:
            record['type'] = _description(descriptions, equips[0]['equip_slot']['DescID']) or record['type']

        handled = set()
        mapped = []
        for number, row in enumerate(bonuses):
            name = row['bonus_type']['Name']
            if not _unconditional(row):
                continue
            if equipment and _flat_value(row) and name in FLAT_EQUIPMENT_BONUSES:
                field = FLAT_EQUIPMENT_BONUSES[name]
                record[field] = record.get(field, 0) + row['bonus']['Value']
                handled.add(number)
                mapped.append({'item_bonus_id': row['ID'], 'bonus_id': row['BonusID'],
                               'field': field, 'value': row['bonus']['Value']})
            elif (equipment and slot == 'domination_stone'
                  and name == 'ExperienceAdditionPercent'
                  and row['unit']['Name'] == 'Percentage'
                  and type(row['bonus'].get('Value')) is int):
                ui_units = [unit for unit in indexes['UIUnit'].values()
                            if unit.get('UnitID') == row['unit']['ID']]
                if len(ui_units) == 1 and ui_units[0].get('Denominator') == 10000:
                    value = row['bonus']['Value'] / 1000000
                    record['xp'] = record.get('xp', 0.0) + value
                    handled.add(number)
                    mapped.append({'item_bonus_id': row['ID'], 'bonus_id': row['BonusID'],
                                   'field': 'xp', 'value': value,
                                   'source_value': row['bonus']['Value'],
                                   'source_denominator': 1000000})
        for name, field in (('IsTwoHanded', 'source_is_two_handed'),
                            ('CanEquipWithTwoHanded', 'source_can_equip_with_two_handed')):
            flags = [(number, row) for number, row in enumerate(bonuses)
                     if equipment and row['bonus_type']['Name'] == name
                     and _unconditional(row) and row['unit']['Name'] == 'TrueFalse'
                     and type(row['bonus'].get('Value')) is int
                     and row['bonus']['Value'] in (0, 1)]
            if flags and len({row['bonus']['Value'] for _, row in flags}) == 1:
                record[field] = bool(flags[0][1]['bonus']['Value'])
                for number, row in flags:
                    handled.add(number)
                    mapped.append({'item_bonus_id': row['ID'], 'bonus_id': row['BonusID'],
                                   'field': field, 'value': record[field]})
        weapon_rows = [row for row in bonuses if _unconditional(row)
                       and 'weapon_type' in row]
        weapon_types = {row['weapon_type']['ID'] for row in weapon_rows}
        if equipment and slot == 'weapon' and len(weapon_types) == 1:
            weapon = weapon_rows[0]['weapon_type']
            weapon_label = _description(descriptions, weapon['DescID'])
            if weapon_label:
                record['type'] = weapon_label
                record['source_weapon_type_id'] = weapon['ID']
                record['source_weapon_type_name'] = weapon['Name']
                for number, row in enumerate(bonuses):
                    if row in weapon_rows:
                        handled.add(number)

        heal_spec, hp_handled = _hp_spec(bonuses, category)
        if slot == 'consumable' and heal_spec:
            record['heal_spec'] = heal_spec
            # Existing host routing tests only heal > 0. Exact use must read
            # heal_spec; this indicator is never the dice's expected value.
            record['heal'] = max(1, heal_spec.get('HPRestoration', 0))
            handled.update(hp_handled)
        use_spec, use_handled = _fixed_card_spec(
            bonuses, category, indexes, server_limits, item_id)
        if not use_spec:
            use_spec, use_handled = _timed_buff_spec(
                bonuses, original, category, indexes, buff_bonuses, item_id)
        if not use_spec:
            use_spec, use_handled = _mp_spec(bonuses, original, category, item_id)
        if not use_spec:
            use_spec, use_handled = _source_reward_bag_spec(
                bonuses, original, category, indexes, bag_entities, bag_class_limits, classes, item_id)
        if use_spec:
            use_spec['item_requirements'] = {
                'test_item': original.get('TestItem', False),
                'level_min': original.get('LevelLimitMin', 0),
                'level_max': original.get('LevelLimitMax', 0),
                'max_level_min': original.get('MaxLevelLimitMin', 0),
                'max_level_max': original.get('MaxLevelLimitMax', 0),
                'class_ids': record['source_class_ids'].copy(),
                'unresolved_class_ids': unresolved_classes.copy(),
                'service_region_code': original.get('ServiceRegionCode', ''),
                'targetting_type_id': original.get('TargettingTypeID'),
                'can_use_when_invisible': original.get('CanUseWhenInvisible'),
            }
            record['source_use_spec'] = use_spec
            handled.update(use_handled)
        unhandled = [
            {'item_bonus_id': row['ID'], 'bonus_id': row['BonusID'],
             'bonus_type': row['bonus_type']['Name'],
             'reason': _unsupported_reason(row, equipment)}
            for number, row in enumerate(bonuses) if number not in handled
        ]
        record['source_mapped_bonuses'] = mapped
        record['source_unhandled_bonuses'] = unhandled
        record['source_unhandled_bonus_ids'] = [row['bonus_id'] for row in unhandled]
        # Empty metadata does not certify an unsupported consumable's use system.
        partial = bool(unhandled) or (slot == 'consumable' and not (heal_spec or use_spec)) or (
            bool(equips) and not equipment) or bool(unresolved_classes) or (
            bool(use_spec) and use_spec['activation_status'] != 'unrestricted')
        record['source_effect_status'] = 'partial' if partial else 'represented_source_fields'
        record['source_effect_scope'] = 'unconditional_flat_equipment_hp_mp_potion_fixed_card_typed_buffs_source_reward_bags'
        record['desc'] = ('523 원본 아이템 · 일부 효과 미지원' if partial
                          else '523 원본 아이템 · 지원되는 원본 필드 적용')
        definitions[str(item_id)] = {
            'original_item': deepcopy(original), 'category': deepcopy(category),
            'grade': deepcopy(grade), 'item_bonus': bonuses, 'equip_rows': equips,
            'class_rows': classes, 'native_record': record,
            'source_invoke_options': _invoke_options(
                bonuses, indexes, equipment, slot, item_id),
            'existing_binding': deepcopy(existing_bindings.get(
                str(item_id), existing_bindings.get(item_id, {}))),
        }
    # Only ready reward bags expand definitions; drop membership never widens.
    outputs = {reward['item_class_id'] for definition in definitions.values()
               for spec in [definition['native_record'].get('source_use_spec', {})]
               if spec.get('kind') in ('guaranteed_bag', 'source_weighted_bag', 'mixed_rewards_bag')
               and spec.get('activation_status') == 'unrestricted'
               for reward in spec['rewards']}
    if outputs - wanted:
        return compile_items(tables, descriptions, wanted | outputs, existing_bindings)
    return definitions
