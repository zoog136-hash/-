"""Synthetic source-item regressions; private original tables stay outside Git."""
from copy import deepcopy
import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'tools/monsters/patch523_item_definitions.py'
SPEC = importlib.util.spec_from_file_location('patch523_items', SCRIPT)
compiler = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(compiler)


class NativeItemDefinitionTests(unittest.TestCase):
    def setUp(self):
        self.tables = {name: [] for name in compiler.ITEM_TABLES}
        self.tables.update({
            'ItemCategory': [
                dict(ID=1, Name='Weapon', DescID=101, IsStackable=False, IsConsumable=False),
                dict(ID=2, Name='Armor', DescID=102, IsStackable=False, IsConsumable=False),
                dict(ID=3, Name='Potion', DescID=103, IsStackable=True, IsConsumable=True),
                dict(ID=4, Name='SpellBook', DescID=104, IsStackable=True, IsConsumable=True),
                dict(ID=5, Name='Currency', DescID=105, IsStackable=True, IsConsumable=False),
                dict(ID=6, Name='StackableItem', DescID=106, IsStackable=True, IsConsumable=False),
            ],
            'Grade': [dict(ID=1, Name='Grade1', DescID=201),
                      dict(ID=42, Name='BM', DescID=242),
                      dict(ID=52, Name='Grade7', DescID=252)],
            'EquipSlot': [dict(ID=8, Name='WeaponHold', DescID=301),
                          dict(ID=1, Name='Head', DescID=302),
                          dict(ID=293, Name='DominationStone', DescID=303)],
            'Unit': [dict(ID=1, Name='Value'), dict(ID=2, Name='Percentage'),
                     dict(ID=3, Name='WeaponTypeID')],
            'Class': [dict(ID=1, Name='knight', DescID=401),
                      dict(ID=2, Name='elf', DescID=402)],
            'WeaponType': [dict(ID=1, Name='OneHandSword', DescID=501)],
        })
        self.descriptions = {
            101: '무기', 102: '방어구', 103: '물약', 104: '마법서', 105: '화폐', 106: '재료',
            201: '일반', 242: '특수', 252: '유일', 301: '무기', 302: '투구', 303: '지배석',
            401: '기사', 402: '요정', 501: '한손검', 601: '원본 검', 602: '원본 검(미확인)',
        }
        self.bindings = {'20': dict(name='옛 검', source='inven', sourceId='20',
                                   sourceUrl='https://example.invalid/item/20')}
        self.item(20)

    def item(self, item_id, category=1, grade=1, equip=8, **extra):
        row = dict(ID=item_id, Name='internal only', DescID=602, IdentifiedDescID=601,
                   CategoryID=category, GradeID=grade, Weight=4000, TestItem=True,
                   IsTradable=False, IsStorable=True, IsDroppable=False, IsDeletable=True,
                   LevelLimitMin=12, LevelLimitMax=90, MaxLevelLimitMin=0,
                   MaxLevelLimitMax=0, MaxStackAmount=1)
        row.update(extra)
        self.tables['ItemClass'].append(row)
        if equip is not None:
            self.tables['ItemEquipSlot'].append(dict(ItemClassID=item_id, EquipSlotID=equip))
        return row

    def bonus(self, name, value, item=20, unit=1, application=0, target=0, possession=False):
        number = len(self.tables['Bonus']) + 1
        self.tables['BonusType'].append(dict(ID=number, Name=name, UnitID=unit,
                                            DescID=0, IsShowOnToolTip=True))
        self.tables['Bonus'].append(dict(ID=number, BonusTypeID=number, Value=value,
                                        BonusApplicationTypeID=application,
                                        BonusApplicationTargetID=target))
        self.tables['ItemBonus'].append(dict(ID=number, ItemClassID=item,
                                            BonusID=number, IsPossession=possession))
        return number

    def compile(self, wanted=None):
        return compiler.compile_items(self.tables, self.descriptions,
                                      wanted or {20}, self.bindings)

    def test_isolated_source_identity_and_existing_binding(self):
        self.item(21, grade=42)
        pack = self.compile({20, 21})
        native = pack['20']['native_record']
        self.assertEqual(native['name'], '원본 검 · 원본#20')
        self.assertEqual(pack['21']['native_record']['name'], '원본 검 · 원본#21')
        self.assertEqual(native['source_display_name'], '원본 검')
        self.assertEqual(native['source'], 'lineagem_patch523')
        self.assertEqual(native['source_snapshot'], 'patch523')
        self.assertEqual(native['sourceId'], 'm523:item:20')
        self.assertEqual(native['source_item_class_id'], 20)
        self.assertTrue(native['source_m_native_item'])
        self.assertEqual(pack['20']['existing_binding'], self.bindings['20'])
        self.assertEqual(pack['21']['existing_binding'], {})
        self.assertEqual(pack['21']['native_record']['grade'], '특수')
        self.assertTrue(native['source_test_item'])
        self.assertEqual(pack['20']['original_item'], self.tables['ItemClass'][0])
        pack['20']['original_item']['Weight'] = 1
        pack['20']['existing_binding']['name'] = 'changed'
        self.assertEqual(self.tables['ItemClass'][0]['Weight'], 4000)
        self.assertEqual(self.bindings['20']['name'], '옛 검')

    def test_localized_descriptor_fallback_never_uses_catalog_name(self):
        del self.descriptions[601]
        self.assertEqual(self.compile()['20']['native_record']['source_display_name'],
                         '원본 검(미확인)')
        del self.descriptions[602]
        with self.assertRaisesRegex(ValueError, 'missing localized'):
            self.compile()

    def test_no_grade_limit_or_test_row_filter(self):
        self.item(21, grade=52)
        records = self.compile({20, 21})
        self.assertEqual(set(records), {'20', '21'})
        self.assertEqual(records['21']['native_record']['grade'], '유일')
        self.assertTrue(records['21']['original_item']['TestItem'])

    def test_relation_multiplicity_and_full_source_joins(self):
        self.tables['ItemEquipSlot'].append(deepcopy(self.tables['ItemEquipSlot'][0]))
        limits = [dict(ItemClassID=20, ClassID=i) for i in (1, 1, 2)]
        self.tables['ItemClassLimit'].extend(limits)
        self.bonus('WeaponType', 1, unit=3)
        self.bonus('WeaponSmallDamage', 10)
        definition = self.compile()['20']
        native = definition['native_record']
        self.assertEqual([row['EquipSlotID'] for row in definition['equip_rows']], [8, 8])
        self.assertEqual([row['ClassID'] for row in definition['class_rows']], [1, 1, 2])
        self.assertEqual(native['source_class_names'], ['기사', '기사', '요정'])
        self.assertEqual(native['source_class_ids'], [1, 1, 2])
        self.assertEqual(native['type'], '한손검')
        linked = definition['item_bonus'][0]
        self.assertEqual(linked['bonus'], self.tables['Bonus'][0])
        self.assertEqual(linked['bonus_type'], self.tables['BonusType'][0])
        self.assertEqual(linked['unit'], self.tables['Unit'][2])
        self.assertEqual(linked['weapon_type'], self.tables['WeaponType'][0])
        linked['bonus']['Value'] = 9
        self.assertEqual(self.tables['Bonus'][0]['Value'], 1)

    def test_only_exact_unconditional_flat_equipment_bonuses(self):
        for name in compiler.FLAT_EQUIPMENT_BONUSES:
            self.bonus(name, 2)
        self.bonus('WeaponHitBonus', -3)
        ignored = [self.bonus('Strength', 100, possession=True),
                   self.bonus('Dexterity', 100, application=1),
                   self.bonus('Intelligence', 100, target=2),
                   self.bonus('HPPlus', 100, unit=2),
                   self.bonus('ArmorClass', 2.5),
                   self.bonus('UnimplementedPower', 900)]
        native = self.compile()['20']['native_record']
        self.assertEqual(native['hit'], -1)
        self.assertEqual(native['strFlat'], 2)
        self.assertEqual(native['dexFlat'], 2)
        self.assertEqual(native['intFlat'], 2)
        self.assertEqual(native['hpFlat'], 2)
        self.assertEqual(native['def'], 4)
        self.assertEqual(native['small_damage'], 2)
        self.assertEqual(native['large_damage'], 2)
        self.assertEqual(native['sp'], 2)
        self.assertEqual(native['source_unhandled_bonus_ids'], ignored)
        self.assertEqual(native['source_effect_status'], 'partial')
        self.assertEqual(len(self.compile()['20']['item_bonus']),
                         len(self.tables['ItemBonus']))

    def test_non_equipment_never_gains_flat_equipment_effects(self):
        self.tables['ItemEquipSlot'].clear()
        self.bonus('Strength', 99)
        native = self.compile()['20']['native_record']
        self.assertEqual(native['slot'], 'material')
        self.assertNotIn('strFlat', native)
        self.assertEqual(native['source_equipment_status'], 'no_source_equip_slot')
        self.assertEqual(native['source_unhandled_bonus_ids'], [1])

    def test_unknown_and_conflicting_source_slots_are_not_fabricated(self):
        self.tables['ItemEquipSlot'][0]['EquipSlotID'] = 293
        self.bonus('Strength', 99)
        native = self.compile()['20']['native_record']
        self.assertEqual(native['slot'], 'material')
        self.assertEqual(native['source_equip_slots'], ['DominationStone'])
        self.assertEqual(native['source_equipment_status'], 'unsupported_source_slot')
        self.assertNotIn('strFlat', native)
        self.tables['ItemEquipSlot'][0]['EquipSlotID'] = 8
        self.tables['ItemEquipSlot'].append(dict(ItemClassID=20, EquipSlotID=1))
        native = self.compile()['20']['native_record']
        self.assertEqual(native['slot'], 'material')
        self.assertEqual(native['source_equipment_status'], 'ambiguous_source_equip_slots')

    def test_hp_potion_preserves_exact_base_and_dice_without_average(self):
        self.item(21, category=3, equip=None)
        for name, value in [('HPRestoration', 80), ('HPRestorationDiceNumber', 2),
                            ('HPRestorationDiceSpotCount', 6)]:
            self.bonus(name, value, item=21)
        native = self.compile({21})['21']['native_record']
        self.assertEqual(native['slot'], 'consumable')
        self.assertEqual(native['heal'], 80)
        self.assertEqual(native['heal_spec']['HPRestoration'], 80)
        self.assertEqual(native['heal_spec']['HPRestorationDiceNumber'], 2)
        self.assertEqual(native['heal_spec']['HPRestorationDiceSpotCount'], 6)
        self.assertEqual(native['source_unhandled_bonus_ids'], [])
        self.assertNotIn('chance', native['heal_spec'])
        self.assertNotIn('expected_value', native['heal_spec'])

    def test_hp_potion_dice_only_positive_route_and_invalid_dice_block(self):
        self.item(21, category=3, equip=None)
        self.bonus('HPRestorationDiceNumber', 2, item=21)
        self.bonus('HPRestorationDiceSpotCount', 6, item=21)
        native = self.compile({21})['21']['native_record']
        self.assertEqual(native['heal'], 1)
        self.assertNotIn('HPRestoration', native['heal_spec'])
        self.bonus('HPRestorationDiceNumber', 2, item=21)
        native = self.compile({21})['21']['native_record']
        self.assertNotIn('heal', native)
        self.assertNotIn('heal_spec', native)
        self.assertEqual(native['source_effect_status'], 'partial')

    def test_consumable_and_currency_flags_do_not_invent_use_effects(self):
        self.item(21, category=4, equip=None)
        self.item(22, category=5, equip=None)
        self.item(23, category=6, equip=None)
        for item in (21, 22, 23):
            self.bonus('HPRestoration', 99, item=item)
        records = self.compile({21, 22, 23})
        self.assertEqual([records[str(i)]['native_record']['slot'] for i in (21, 22, 23)],
                         ['consumable', 'currency', 'material'])
        for definition in records.values():
            self.assertNotIn('heal', definition['native_record'])
            self.assertNotIn('heal_spec', definition['native_record'])
            self.assertEqual(definition['native_record']['source_effect_status'], 'partial')

    def test_raw_weight_flags_and_level_limits_are_preserved(self):
        native = self.compile()['20']['native_record']
        self.assertNotIn('weight', native)
        self.assertEqual(native['source_weight'], 4000)
        self.assertEqual(native['source_weight_unit'], 'unverified_source_units')
        self.assertFalse(native['tradable'])
        self.assertFalse(native['droppable'])
        self.assertTrue(native['storable'])
        self.assertTrue(native['deletable'])
        self.assertFalse(native['source_is_stackable'])
        self.assertEqual(native['source_level_limit_min'], 12)
        self.assertEqual(native['source_level_limit_max'], 90)

    def test_missing_tables_and_dangling_joins_fail_closed(self):
        del self.tables['Unit']
        with self.assertRaisesRegex(ValueError, 'missing source table: Unit'):
            self.compile()
        self.tables['Unit'] = []
        self.bonus('Strength', 2)
        with self.assertRaisesRegex(ValueError, 'dangling source item #20: Unit #1'):
            self.compile()

    def test_duplicate_source_entity_ids_rejected_but_relation_rows_preserved(self):
        self.tables['Grade'].append(deepcopy(self.tables['Grade'][0]))
        with self.assertRaisesRegex(ValueError, 'duplicate source ID: Grade #1'):
            self.compile()

    def test_empty_source_class_label_is_preserved_without_inventing_a_class(self):
        self.tables['Class'].append(dict(ID=0, Name='None', DescID=999))
        self.tables['ItemClassLimit'].append(dict(ItemClassID=20, ClassID=0))
        record = self.compile()['20']['native_record']
        self.assertEqual(record['source_class_ids'], [0])
        self.assertEqual(record['source_class_names'], [''])
        self.assertEqual(record['source_unresolved_class_ids'], [0])
        self.assertEqual(record['source_effect_status'], 'partial')

    def test_all_mapped_slot_names_are_explicit(self):
        self.assertEqual(compiler.SLOT_MAP, {
            'Head': 'helmet', 'Torso': 'body', 'Shirt': 'tshirt', 'Cloak': 'cloak',
            'Leg': 'gaiters', 'Foot': 'boots', 'Hand': 'gloves', 'WeaponHold': 'weapon',
            'Finger': 'ring', 'Neck': 'necklace', 'Waist': 'belt', 'Ear': 'earring',
            'ShieldHold': 'offhand', 'Quiver': 'offhand', 'Rune': 'rune',
            'SpellRune': 'rune', 'Badge': 'seal', 'Insignia': 'badge',
            'Spaulder': 'shoulder', 'Bangle_normal': 'bracelet', 'Bangle_BM': 'bracelet',
            'Crest': 'crystal', 'Catalyst': 'catalyst',
        })


if __name__ == '__main__':
    unittest.main()
