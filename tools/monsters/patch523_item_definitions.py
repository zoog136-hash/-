"""Build isolated host records from private patch523 item definitions.

This module does not choose drops or infer source drop chances, quantities,
weight units, item-use effects, or missing equipment slots. All source joins
remain in the returned definitions, including effects the host cannot apply.
"""
from __future__ import annotations

from collections import defaultdict
from copy import deepcopy


ITEM_TABLES = (
    'ItemClass', 'ItemCategory', 'Grade', 'EquipSlot', 'ItemEquipSlot',
    'ItemBonus', 'Bonus', 'BonusType', 'Unit', 'Class', 'ItemClassLimit',
    'WeaponType',
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
               if name not in ('ItemBonus', 'ItemEquipSlot', 'ItemClassLimit')}
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
        mapped_slots = {SLOT_MAP[name] for name in slot_names if name in SLOT_MAP}
        # Unknown or conflicting source slots cannot become fictitious wearables.
        equipment = bool(slot_names) and len(mapped_slots) == 1 and all(
            name in SLOT_MAP for name in slot_names)
        slot = next(iter(mapped_slots)) if equipment else 'material'
        if not equipment and not equips:
            if category['Name'] == 'Currency':
                slot = 'currency'
            elif category['Name'] == 'Potion' or category.get('IsConsumable') is True:
                slot = 'consumable'
        equipment_status = ('mapped' if equipment else 'unsupported_source_slot'
                            if any(name not in SLOT_MAP for name in slot_names)
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
        partial = bool(unhandled) or (slot == 'consumable' and not heal_spec) or (
            bool(equips) and not equipment) or bool(unresolved_classes)
        record['source_effect_status'] = 'partial' if partial else 'represented_source_fields'
        record['source_effect_scope'] = 'unconditional_flat_equipment_and_hp_potion_only'
        record['desc'] = ('523 원본 아이템 · 일부 효과 미지원' if partial
                          else '523 원본 아이템 · 지원되는 원본 필드 적용')
        definitions[str(item_id)] = {
            'original_item': deepcopy(original), 'category': deepcopy(category),
            'grade': deepcopy(grade), 'item_bonus': bonuses, 'equip_rows': equips,
            'class_rows': classes, 'native_record': record,
            'existing_binding': deepcopy(existing_bindings.get(
                str(item_id), existing_bindings.get(item_id, {}))),
        }
    return definitions
