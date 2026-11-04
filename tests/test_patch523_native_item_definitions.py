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
                dict(ID=7, Name='BuffCardDrawer', DescID=107, IsStackable=True, IsConsumable=True),
                dict(ID=8, Name='LuckyBag', DescID=108, IsStackable=True, IsConsumable=True),
            ],
            'Grade': [dict(ID=1, Name='Grade1', DescID=201),
                      dict(ID=42, Name='BM', DescID=242),
                      dict(ID=52, Name='Grade7', DescID=252)],
            'EquipSlot': [dict(ID=8, Name='WeaponHold', DescID=301),
                          dict(ID=1, Name='Head', DescID=302),
                          dict(ID=293, Name='DominationStone', DescID=303)],
            'Unit': [dict(ID=1, Name='Value'), dict(ID=2, Name='Percentage'),
                     dict(ID=3, Name='WeaponTypeID'), dict(ID=4, Name='BuffCardID'),
                     dict(ID=5, Name='TrueFalse'), dict(ID=6, Name='BuffClassID'),
                     dict(ID=7, Name='Seconds'), dict(ID=8, Name='MilliSeconds'),
                     dict(ID=9, Name='SpriteID'), dict(ID=10, Name='Time'),
                     dict(ID=11, Name='LuckyBagClassID'), dict(ID=12, Name='SpellClassID'),
                     dict(ID=13, Name='SpecialResistanceTypeID'), dict(ID=14, Name='StatusEffectID')],
            'Class': [dict(ID=1, Name='knight', DescID=401, CanCreateClient=True),
                      dict(ID=2, Name='elf', DescID=402, CanCreateClient=True)],
            'WeaponType': [dict(ID=1, Name='OneHandSword', DescID=501)],
            'BuffCardDeck': [dict(ID=1, Name='PolymorphCardDeck', CharacterBased=False),
                             dict(ID=2, Name='MagicDollCardDeck', CharacterBased=False),
                             dict(ID=98, Name='HolyStuffCardDeck', CharacterBased=False),
                             dict(ID=41, Name='Spell', CharacterBased=True)],
            'BuffCard': [dict(ID=122, Name='ExactCard', BuffCardDeckID=1,
                              SpellClassID=0, BuffClassID=9, ServerLimitSetID=0,
                              StartDateTimeID=0, EndDateTimeID=0, IsNoSwapOut=False)],
            'BonusApplicationType': [dict(ID=0, Name='None'), dict(ID=10, Name='InvokeOption')],
            'UIUnit': [dict(ID=2, UnitID=2, Denominator=10000)],
            'InvokeOptionType': [dict(ID=9, Name='Attack_AddCriticalProbability', IsDefence=False),
                                 dict(ID=6, Name='Attack_WeaponDamageScale', IsDefence=False)],
            'InvokeOption': [dict(ID=741, InvokeOptionTypeID=9, BySpellAttack=False,
                                  AttackTypeID=0, Param1=0, Param2=0, Param3=0,
                                  Param4=False, Param5=False, Param6=0, MaterialTypeID=0,
                                  MaterialAmount=0, WeaponGroupID=0, ShieldTypeID=0,
                                  SuccessedInvokeOptionID=0, IsAmmoAttack=False,
                                  TargetKind=0, SiegeTargetKind=0, TargetEffectSpriteID=13416)],
            'LuckyBagClass': [dict(ID=7, Name='Exact guaranteed reward', AbleMultiple=True)],
            'LuckyBagEntityType': [dict(ID=1, Name='IsGiven'), dict(ID=0, Name='Probability')],
            'SpellMaterialType': [dict(ID=0, Name='None')],
            'SpecialResistanceType': [dict(ID=22, Name='Poison')],
            'TargettingType': [dict(ID=2, Name='SingleObject')],
            'TargetKind': [dict(ID=2, Name='All', RootTargetKindNodeID=11)],
            'SpellCategory': [dict(ID=8, Name='SpellDebuff')],
        })
        self.descriptions = {
            101: '무기', 102: '방어구', 103: '물약', 104: '마법서', 105: '화폐', 106: '재료', 107: '카드', 108: '상자',
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

    def usable_item(self, item_id=21):
        return self.item(item_id, category=3, equip=None, TestItem=False,
                         TargettingTypeID=1, CanUseWhenInvisible=True,
                         ServiceRegionCode='', LevelLimitMin=0, LevelLimitMax=0)

    def timed_buff(self, item_id=21):
        self.usable_item(item_id)
        self.tables['BuffClass'].append(dict(
            ID=223, BuffGroupID=502, BuffGroupPriority=1, IsGood=True,
            IsBuffGroup=True, IsEraseOnTimeEnd=True,
            IsImmuneToDead=True, IsImmuneToCancellation=True))
        self.tables['BuffGroup'].append(dict(
            ID=502, Name='Exact source group', IsAllowOverlap=False,
            IsAllowPriority=False, IsEraseBySpellLevel=False))
        self.bonus('BuffClassID', 223, item=item_id, unit=6)
        self.bonus('BuffDuration', 1800, item=item_id, unit=7)
        self.bonus('ItemConsumeDelay', 500, item=item_id, unit=8)
        self.bonus('ItemConsumeEffectSpriteID', 190, item=item_id, unit=9)

    def buff_effect(self, name, value, **conditions):
        number = self.bonus(name, value)
        self.tables['ItemBonus'].pop()
        row = dict(ID=number, BuffClassID=223, BonusID=number,
                   CharacterLevel=0, CharacterClass=0, MinSpellLevel=0)
        row.update(conditions)
        self.tables['BuffBonus'].append(row)
        return row

    def guaranteed_bag(self):
        self.item(21, category=8, equip=None, TestItem=False, TargettingTypeID=1,
                  CanUseWhenInvisible=True, ServiceRegionCode='')
        self.item(22, category=5, equip=None, TestItem=False)
        self.bonus('LuckyBagClassID', 7, item=21, unit=11)
        row = dict(ID=101, LuckyBagClassID=7, LuckyBagEntityTypeID=1,
                   Probability=0, ItemClassID=22, ItemAmount=1500,
                   ItemBlessCodeID=1, ItemEnchant=0, LimitClass=10000)
        self.tables['LuckyBagEntityView'].append(row)
        return row

    def bleed_invoke(self):
        self.bonus('InvokeOption', 5000, unit=2, application=10, target=611)
        self.tables['InvokeOptionType'].append(dict(
            ID=1, Name='Attack_Spell', IsDefence=False, Param1Unit=12))
        self.tables['InvokeOption'].append({**self.tables['InvokeOption'][0],
                                           'ID': 611, 'InvokeOptionTypeID': 1,
                                           'Param1': 17564, 'TargetEffectSpriteID': 0})
        self.tables['SpellClass'].append(dict(
            ID=17564, Name='Source bleed', SpellMaterialTypeID=0,
            TargettingTypeID=2, TargetKindID=2, SpellCategoryID=8,
            TestSpell=False, HPCost=0, MPCost=0, VPCost=0,
            TargetAreaRadius=0, CastDelay=0, EffectSpriteID=16372,
            IsPierceCounterMagic=True, IsPierceCounterAssult=False))
        self.tables['BuffClass'].append(dict(
            ID=51984, BuffGroupID=564, BuffGroupPriority=0, IsGood=False,
            IsBuffGroup=False, IsEraseOnTimeEnd=True, MaxHPPercent=50,
            IsImmuneToDead=False, IsImmuneToCancellation=False))
        self.tables['BuffGroup'].append(dict(
            ID=564, Name='Source bleed group', IsAllowOverlap=False,
            IsAllowPriority=False, IsEraseBySpellLevel=False))
        for name, value, unit in [('SpecialResistanceTypeID', 22, 13),
                                  ('SpellDebuffMaxDuration', 3, 7),
                                  ('SpellDebuffMinDuration', 3, 7),
                                  ('BuffClassID', 51984, 6)]:
            number = self.bonus(name, value, unit=unit)
            self.tables['ItemBonus'].pop()
            self.tables['SpellBonus'].append(dict(ID=number, SpellClassID=17564,
                                                  BonusID=number, MinSpellLevel=0))
        for name, value, unit in [('PoisonDamageDiceNumber', 10, 1),
                                  ('PoisonDamageDiceSpotCount', 1, 1),
                                  ('PoisonDamageMotion', 1, 5),
                                  ('StatusEffectID', 16372, 14)]:
            number = self.bonus(name, value, unit=unit)
            self.tables['ItemBonus'].pop()
            self.tables['BuffBonus'].append(dict(
                ID=number, BuffClassID=51984, BonusID=number,
                CharacterLevel=0, CharacterClass=0, MinSpellLevel=0))

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
        self.tables['EquipSlot'][2]['Name'] = 'UnknownOriginalSlot'
        self.bonus('Strength', 99)
        native = self.compile()['20']['native_record']
        self.assertEqual(native['slot'], 'material')
        self.assertEqual(native['source_equip_slots'], ['UnknownOriginalSlot'])
        self.assertEqual(native['source_equipment_status'], 'unsupported_source_slot')
        self.assertNotIn('strFlat', native)
        self.tables['ItemEquipSlot'][0]['EquipSlotID'] = 8
        self.tables['ItemEquipSlot'].append(dict(ItemClassID=20, EquipSlotID=1))
        native = self.compile()['20']['native_record']
        self.assertEqual(native['slot'], 'material')
        self.assertEqual(native['source_equipment_status'], 'ambiguous_source_equip_slots')

    def test_domination_stone_has_its_exact_dedicated_slot_and_verified_xp_units(self):
        self.tables['ItemEquipSlot'][0]['EquipSlotID'] = 293
        self.bonus('MagicResist', 2)
        self.bonus('ExperienceAdditionPercent', 10000, unit=2)
        native = self.compile()['20']['native_record']
        self.assertEqual(native['slot'], 'domination_stone')
        self.assertEqual(native['source_equip_slot_ids'], [293])
        self.assertEqual(native['mr'], 2)
        self.assertEqual(native['xp'], 0.01)
        self.assertEqual(native['source_unhandled_bonus_ids'], [])
        self.tables['UIUnit'][0]['Denominator'] = 100
        native = self.compile()['20']['native_record']
        self.assertNotIn('xp', native)
        self.assertIn(2, native['source_unhandled_bonus_ids'])
        self.tables['EquipSlot'][2]['ID'] = 294
        self.tables['ItemEquipSlot'][0]['EquipSlotID'] = 294
        native = self.compile()['20']['native_record']
        self.assertEqual(native['slot'], 'material')
        self.assertNotIn('mr', native)
        self.assertNotIn('xp', native)

    def test_exact_unconditional_boolean_equipment_flags_only(self):
        self.bonus('IsTwoHanded', 1, unit=5)
        self.bonus('CanEquipWithTwoHanded', 0, unit=5)
        native = self.compile()['20']['native_record']
        self.assertIs(native['source_is_two_handed'], True)
        self.assertIs(native['source_can_equip_with_two_handed'], False)
        self.assertEqual(native['source_unhandled_bonus_ids'], [])
        self.tables['Bonus'][0]['Value'] = 0.5
        self.tables['Bonus'][1]['BonusApplicationTargetID'] = 1
        native = self.compile()['20']['native_record']
        self.assertNotIn('source_is_two_handed', native)
        self.assertNotIn('source_can_equip_with_two_handed', native)
        self.assertEqual(native['source_unhandled_bonus_ids'], [1, 2])

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

    def test_fixed_card_exact_identity_and_no_swap_are_preserved(self):
        self.item(21, category=7, equip=None, TestItem=False, TargettingTypeID=1)
        self.bonus('BuffCardID', 122, item=21, unit=4)
        self.bonus('BuffCardCannotSwap', 1, item=21, unit=5)
        native = self.compile({21})['21']['native_record']
        spec = native['source_use_spec']
        self.assertEqual(spec['kind'], 'fixed_card')
        self.assertEqual(spec['card_kind'], '변신')
        self.assertEqual(spec['card_id'], 122)
        self.assertEqual(spec['host_card_identity'], 'source:m508:1:122')
        self.assertEqual(spec['host_binding_policy'], 'exact_ID_and_full_original_card_equality')
        self.assertEqual(spec['original_card'], self.tables['BuffCard'][0])
        self.assertTrue(spec['buff_card_cannot_swap'])
        self.assertEqual(spec['activation_status'], 'unrestricted')
        self.assertEqual(spec['server_limits'], [])
        self.assertEqual(spec['item_requirements']['targetting_type_id'], 1)
        self.assertEqual(native['source_unhandled_bonus_ids'], [])
        self.assertEqual(native['source_effect_status'], 'represented_source_fields')
        spec['original_card']['Name'] = 'changed'
        self.assertEqual(self.tables['BuffCard'][0]['Name'], 'ExactCard')

    def test_fixed_card_server_and_date_gates_remain_explicit(self):
        self.item(21, category=7, equip=None)
        self.bonus('BuffCardID', 122, item=21, unit=4)
        self.tables['BuffCard'][0]['ServerLimitSetID'] = 772
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertEqual(spec['activation_status'], 'server_definition_missing')
        self.tables['ServerLimit'].extend([
            dict(ID=1, ServerLimitSetID=772, WorldNo=1, ServiceRegionCode='KR'),
            dict(ID=2, ServerLimitSetID=772, WorldNo=2, ServiceRegionCode='KR'),
        ])
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertEqual(spec['activation_status'], 'server_context_required')
        self.assertEqual(spec['server_limits'], self.tables['ServerLimit'])
        self.assertEqual(spec['server_limit_set_id'], 772)
        self.tables['BuffCard'][0]['StartDateTimeID'] = 100
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertEqual(spec['activation_status'], 'source_date_window_unresolved')
        self.assertEqual(spec['start_datetime_id'], 100)

    def test_fixed_card_requires_exact_deck_unconditional_reference_and_no_extra_effect(self):
        self.item(21, category=7, equip=None)
        self.bonus('BuffCardID', 122, item=21, unit=4)
        original = deepcopy(self.tables['BuffCard'][0])
        self.tables['BuffCard'][0]['BuffCardDeckID'] = 41
        self.tables['BuffCard'][0]['SpellClassID'] = 83
        self.assertNotIn('source_use_spec', self.compile({21})['21']['native_record'])
        self.tables['BuffCard'][0] = original
        self.tables['BuffCardDeck'][0]['Name'] = 'OtherDeck'
        self.assertNotIn('source_use_spec', self.compile({21})['21']['native_record'])
        self.tables['BuffCardDeck'][0]['Name'] = 'PolymorphCardDeck'
        self.tables['Bonus'][0]['BonusApplicationTargetID'] = 1
        self.assertNotIn('source_use_spec', self.compile({21})['21']['native_record'])
        self.tables['Bonus'][0]['BonusApplicationTargetID'] = 0
        self.bonus('UnimplementedUseEffect', 1, item=21)
        self.assertNotIn('source_use_spec', self.compile({21})['21']['native_record'])

    def test_fixed_card_dangling_reference_fails_closed(self):
        self.item(21, category=7, equip=None)
        self.bonus('BuffCardID', 123, item=21, unit=4)
        with self.assertRaisesRegex(ValueError, 'BuffCard #123'):
            self.compile({21})

    def test_timed_source_buff_keeps_exact_effect_group_lifecycle_and_cooldown(self):
        self.timed_buff()
        self.buff_effect('MeleeDamage', 3)
        self.buff_effect('Strength', 1)
        self.buff_effect('ArmorClassBonus', 3)
        native = self.compile({21})['21']['native_record']
        spec = native['source_use_spec']
        self.assertEqual(spec['kind'], 'source_timed_buff')
        self.assertEqual(spec['activation_status'], 'unrestricted')
        self.assertEqual(spec['blocked_reasons'], [])
        self.assertEqual(spec['typed_effects'], {'melee_damage': 3, 'strFlat': 1, 'def': 3})
        self.assertEqual(spec['duration_seconds'], 1800)
        self.assertEqual(spec['consume_delay_ms'], 500)
        self.assertEqual(spec['consume_effect_sprite_id'], 190)
        self.assertEqual(spec['source_buff_class'], self.tables['BuffClass'][0])
        self.assertEqual(spec['source_buff_group'], self.tables['BuffGroup'][0])
        self.assertEqual(len(spec['source_buff_bonus']), 3)
        self.assertNotIn('strFlat', native)
        self.assertNotIn('def', native)
        self.assertEqual(native['source_unhandled_bonus_ids'], [])
        spec['source_buff_bonus'][0]['bonus']['Value'] = 999
        self.assertEqual(self.tables['Bonus'][4]['Value'], 3)

    def test_timed_source_buff_blocks_incomplete_effects_and_action_rules(self):
        self.timed_buff()
        effect = self.buff_effect('MeleeDamage', 3)
        effect['CharacterLevel'] = 1
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertEqual(spec['activation_status'], 'blocked')
        self.assertIn('conditional_buff_effect:MeleeDamage', spec['blocked_reasons'])
        effect['CharacterLevel'] = 0
        self.buff_effect('RegenHP', 3)
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertIn('unsupported_buff_effect:RegenHP', spec['blocked_reasons'])
        self.assertEqual(spec['typed_effects'], {'melee_damage': 3})
        self.tables['BuffClass'][0]['IsEraseOnAttack'] = True
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertIn('unsupported_buff_action_rule:IsEraseOnAttack', spec['blocked_reasons'])

    def test_timed_source_buff_preserves_overlap_without_inventing_timer_or_lifetime(self):
        self.timed_buff()
        self.buff_effect('ArmorClass', 3)
        self.tables['BuffGroup'][0]['IsAllowOverlap'] = True
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertEqual(spec['activation_status'], 'unrestricted')
        self.assertTrue(spec['source_buff_group']['IsAllowOverlap'])
        self.tables['BuffClass'][0]['IsEraseOnTimeEnd'] = False
        self.bonus('DeleteTime', 2020102105, item=21, unit=10)
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertIn('source_buff_timer_semantics_unresolved', spec['blocked_reasons'])
        self.assertIn('source_item_lifetime_unresolved', spec['blocked_reasons'])

    def test_mp_dice_exact_formula_and_delay_without_mean_or_invented_base(self):
        self.usable_item()
        self.bonus('MPRestorationDiceNumber', 1, item=21)
        self.bonus('MPRestorationDiceSpotCount', 10, item=21)
        self.bonus('ItemConsumeDelay', 1000, item=21, unit=8)
        native = self.compile({21})['21']['native_record']
        spec = native['source_use_spec']
        self.assertEqual(spec['kind'], 'source_mp_dice')
        self.assertEqual(spec['activation_status'], 'unrestricted')
        self.assertEqual(spec['base'], 0)
        self.assertNotIn('MPRestoration', spec)
        self.assertEqual(spec['MPRestorationDiceNumber'], 1)
        self.assertEqual(spec['MPRestorationDiceSpotCount'], 10)
        self.assertEqual(spec['consume_delay_ms'], 1000)
        self.assertNotIn('heal', native)
        self.assertNotIn('expected_value', spec)

    def test_mp_dice_blocks_source_expiry_infinite_and_territory_rules(self):
        self.usable_item()
        self.bonus('MPRestorationDiceNumber', 1, item=21)
        self.bonus('MPRestorationDiceSpotCount', 10, item=21)
        self.bonus('ItemConsumeDelay', 1000, item=21, unit=8)
        self.bonus('DeleteTime', 2021011305, item=21, unit=10)
        self.bonus('InfiniteAmount', 1, item=21, unit=5)
        self.bonus('ValidLand', 12, item=21)
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertEqual(spec['activation_status'], 'blocked')
        self.assertIn('source_item_lifetime_unresolved', spec['blocked_reasons'])
        self.assertIn('source_infinite_amount_not_supported', spec['blocked_reasons'])
        self.assertIn('unsupported_item_bonus:ValidLand', spec['blocked_reasons'])

    def test_source_critical_invoke_is_separate_contextual_sidecar(self):
        self.bonus('InvokeOption', 250000, unit=2, application=10, target=741)
        definition = self.compile()['20']
        invoke = definition['source_invoke_options'][0]
        self.assertEqual(invoke['kind'], 'normal_attack_additional_critical')
        self.assertEqual(invoke['activation_status'], 'unrestricted')
        self.assertEqual(invoke['probability_raw'], 250000)
        self.assertEqual(invoke['probability_denominator'], 1000000)
        self.assertEqual(invoke['invoke_option'], self.tables['InvokeOption'][0])
        self.assertEqual(invoke['invoke_option_type'], self.tables['InvokeOptionType'][0])
        self.assertEqual(invoke['item_bonus']['bonus'], self.tables['Bonus'][0])
        self.assertNotIn('critical', definition['native_record'])
        self.assertEqual(definition['native_record']['source_unhandled_bonus_ids'], [1])

    def test_source_invoke_wrong_trigger_unit_or_unknown_scale_remains_blocked(self):
        self.bonus('InvokeOption', 250000, unit=2, application=10, target=741)
        self.tables['InvokeOption'][0]['BySpellAttack'] = True
        invoke = self.compile()['20']['source_invoke_options'][0]
        self.assertIn('unsupported_invoke_attack_trigger', invoke['blocked_reasons'])
        self.tables['InvokeOption'][0]['BySpellAttack'] = False
        self.tables['UIUnit'][0]['Denominator'] = 100
        invoke = self.compile()['20']['source_invoke_options'][0]
        self.assertIn('unsupported_invoke_probability_units', invoke['blocked_reasons'])
        self.tables['UIUnit'][0]['Denominator'] = 10000
        self.tables['InvokeOption'][0]['InvokeOptionTypeID'] = 6
        self.tables['InvokeOption'][0]['Param1'] = 2000000
        self.tables['InvokeOptionType'][1]['Name'] = 'UnknownWeaponScale'
        invoke = self.compile()['20']['source_invoke_options'][0]
        self.assertEqual(invoke['activation_status'], 'blocked')
        self.assertEqual(invoke['invoke_option']['Param1'], 2000000)
        self.assertIn('source_invoke_effect_not_implemented', invoke['blocked_reasons'])

    def test_source_weapon_scale_keeps_raw_ratio_chance_and_labels_local_component_scope(self):
        self.bonus('InvokeOption', 180000, unit=2, application=10, target=741)
        self.tables['InvokeOption'][0]['InvokeOptionTypeID'] = 6
        self.tables['InvokeOption'][0]['Param1'] = 2000000
        invoke = self.compile()['20']['source_invoke_options'][0]
        self.assertEqual(invoke['kind'], 'normal_attack_weapon_scale')
        self.assertEqual(invoke['activation_status'], 'unrestricted')
        self.assertEqual(invoke['probability_raw'], 180000)
        self.assertEqual(invoke['probability_denominator'], 1000000)
        self.assertEqual(invoke['scale_raw'], 2000000)
        self.assertEqual(invoke['scale_denominator'], 1000000)
        self.assertEqual(invoke['invoke_option']['Param1'], 2000000)
        self.assertEqual(invoke['component_boundary_origin'],
                         'local_estimate_based_on_primary_experiment')
        self.assertEqual(invoke['configuration_key'], 'patch523_weapon_double_scope')
        self.tables['InvokeOption'][0]['Param2'] = 1
        blocked = self.compile()['20']['source_invoke_options'][0]
        self.assertEqual(blocked['activation_status'], 'blocked')
        self.assertIn('unsupported_invoke_condition:Param2', blocked['blocked_reasons'])
        self.tables['InvokeOption'][0]['Param2'] = 0
        self.tables['InvokeOption'][0]['Param1'] = 2000000.5
        blocked = self.compile()['20']['source_invoke_options'][0]
        self.assertIn('unsupported_invoke_weapon_scale', blocked['blocked_reasons'])

    def test_source_bleed_preserves_exact_chain_and_labels_local_tick_and_cap(self):
        self.bleed_invoke()
        invoke = self.compile()['20']['source_invoke_options'][0]
        self.assertEqual(invoke['kind'], 'normal_attack_source_bleed')
        self.assertEqual(invoke['activation_status'], 'unrestricted')
        self.assertEqual(invoke['probability_raw'], 5000)
        self.assertEqual(invoke['duration_seconds'], 3)
        self.assertEqual((invoke['damage_dice_number'], invoke['damage_dice_spot_count']), (10, 1))
        self.assertEqual(invoke['source_max_hp_percent'], 50)
        self.assertEqual(invoke['source_spell_class'], self.tables['SpellClass'][0])
        self.assertEqual(invoke['source_buff_class'], self.tables['BuffClass'][0])
        self.assertEqual(len(invoke['source_spell_bonus']), 4)
        self.assertEqual(len(invoke['source_buff_bonus']), 4)
        self.assertEqual(invoke['source_target_kind']['Name'], 'All')
        self.assertEqual(invoke['source_special_resistance_type']['Name'], 'Poison')
        local = invoke['local_interpretation']
        self.assertEqual(local['tick_interval_seconds'], 0.75)
        self.assertEqual(local['tick_interval_origin'], 'existing_host_default')
        self.assertEqual(local['max_hp_percent_semantics'], 'total_bleed_damage_cap')
        self.assertEqual(local['max_hp_percent_origin'], 'local_estimate')
        self.assertEqual(local['tick_interval_configuration_key'], 'patch523_bleed_tick_interval_seconds')
        self.assertEqual(local['max_hp_percent_configuration_key'], 'patch523_bleed_max_hp_rule')
        invoke['source_buff_bonus'][0]['bonus']['Value'] = 999
        self.assertEqual(self.tables['Bonus'][5]['Value'], 10)

    def test_source_bleed_blocks_costs_conditions_and_unknown_effects(self):
        self.bleed_invoke()
        self.tables['SpellClass'][0]['HPCost'] = 1
        self.tables['SpellBonus'][0]['MinSpellLevel'] = 1
        self.tables['BuffClass'][0]['MaxHPPercent'] = 51
        number = self.bonus('UnimplementedBleedEffect', 2)
        self.tables['ItemBonus'].pop()
        self.tables['BuffBonus'].append(dict(
            ID=number, BuffClassID=51984, BonusID=number,
            CharacterLevel=0, CharacterClass=0, MinSpellLevel=0))
        invoke = self.compile()['20']['source_invoke_options'][0]
        self.assertEqual(invoke['activation_status'], 'blocked')
        self.assertIn('unsupported_source_bleed_spell_rule:HPCost', invoke['blocked_reasons'])
        self.assertIn('unsupported_source_bleed_spell_effect:SpecialResistanceTypeID',
                      invoke['blocked_reasons'])
        self.assertIn('unsupported_source_bleed_lifecycle', invoke['blocked_reasons'])
        self.assertIn('unsupported_source_bleed_buff_effect:UnimplementedBleedEffect',
                      invoke['blocked_reasons'])
        self.assertEqual(len(invoke['source_buff_bonus']), 5)

    def test_source_bleed_requires_exact_spell_chain_and_landed_normal_attack(self):
        self.bleed_invoke()
        self.tables['InvokeOption'][-1]['Param5'] = True
        invoke = self.compile()['20']['source_invoke_options'][0]
        self.assertIn('unsupported_invoke_condition:Param5', invoke['blocked_reasons'])
        self.tables['InvokeOption'][-1]['Param5'] = False
        self.tables['InvokeOption'][-1]['Param1'] = 17565
        invoke = self.compile()['20']['source_invoke_options'][0]
        self.assertEqual(invoke['activation_status'], 'blocked')
        self.assertIn('source_invoke_effect_not_implemented', invoke['blocked_reasons'])
        self.assertNotIn('source_spell_class', invoke)

    def test_guaranteed_bag_uses_explicit_quantity_and_only_ready_output_closure(self):
        row = self.guaranteed_bag()
        definitions = self.compile({21})
        self.assertEqual(set(definitions), {'21', '22'})
        spec = definitions['21']['native_record']['source_use_spec']
        self.assertEqual(spec['kind'], 'guaranteed_bag')
        self.assertEqual(spec['activation_status'], 'unrestricted')
        self.assertNotIn('consume_delay_ms', spec)
        self.assertEqual(spec['original_lucky_bag_class'], self.tables['LuckyBagClass'][0])
        self.assertEqual(spec['source_entities'][0]['entity_type']['Name'], 'IsGiven')
        self.assertEqual(spec['source_entities'][0]['Probability'], 0)
        self.assertEqual(spec['rewards'], [dict(source_entity_id=101, item_class_id=22,
                                               amount=1500, bless_raw=1, enchant=0,
                                               class_ids=[], entity_type_id=1,
                                               entity_type='IsGiven', probability_raw=0)])
        spec['source_entities'][0]['ItemAmount'] = 999
        self.assertEqual(row['ItemAmount'], 1500)

    def test_guaranteed_bag_lifetime_and_extra_effect_block_without_output_expansion(self):
        self.guaranteed_bag()
        self.bonus('DeleteTime', 2021011305, item=21, unit=10)
        self.bonus('AdditionalUseEffect', 1, item=21)
        definitions = self.compile({21})
        self.assertEqual(set(definitions), {'21'})
        spec = definitions['21']['native_record']['source_use_spec']
        self.assertEqual(spec['activation_status'], 'blocked')
        self.assertIn('source_item_lifetime_unresolved', spec['blocked_reasons'])
        self.assertIn('unsupported_item_bonus:AdditionalUseEffect', spec['blocked_reasons'])
        self.assertEqual(spec['rewards'][0]['amount'], 1500)

    def test_guaranteed_bag_class_limit_multiplicity_and_dangling_view_gate(self):
        row = self.guaranteed_bag()
        row['LimitClass'] = 1
        self.tables['LuckyBagEntityClassLimit'].extend([
            dict(LuckyBagEntityID=101, ClassID=1), dict(LuckyBagEntityID=101, ClassID=1)])
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertEqual(spec['activation_status'], 'unrestricted')
        self.assertEqual(spec['rewards'][0]['class_ids'], [1, 1])
        self.assertEqual(len(spec['source_entities'][0]['class_limits']), 2)
        self.assertEqual(spec['source_entities'][0]['class_limits'][0]['class']['Name'], 'knight')
        self.tables['LuckyBagEntityClassLimit'].clear()
        definitions = self.compile({21})
        self.assertEqual(set(definitions), {'21'})
        spec = definitions['21']['native_record']['source_use_spec']
        self.assertIn('unresolved_lucky_bag_class_limit', spec['blocked_reasons'])

    def test_incomplete_mixed_bag_blocks_without_renormalizing_or_expanding(self):
        row = self.guaranteed_bag()
        self.tables['LuckyBagEntityView'].append({**row, 'ID': 102,
                                                 'LuckyBagEntityTypeID': 0,
                                                 'Probability': 5000000})
        definitions = self.compile({21})
        self.assertEqual(set(definitions), {'21'})
        spec = definitions['21']['native_record']['source_use_spec']
        self.assertEqual(spec['kind'], 'mixed_rewards_bag')
        self.assertEqual(spec['activation_status'], 'blocked')
        self.assertEqual(spec['rewards'][1]['probability_raw'], 5000000)
        self.assertEqual(spec['class_probability_totals'], {'1': 5000000, '2': 5000000})
        self.assertNotIn('source_probability_denominator', spec)

    def test_weighted_source_bag_preserves_weights_zero_rows_and_local_single_draw(self):
        row = self.guaranteed_bag()
        row.update(LuckyBagEntityTypeID=0, Probability=7500000)
        self.item(23, category=6, equip=None, TestItem=False)
        self.tables['LuckyBagEntityView'].extend([
            {**row, 'ID': 102, 'ItemClassID': 23, 'Probability': 2500000},
            {**row, 'ID': 103, 'ItemClassID': 23, 'Probability': 0},
        ])
        definitions = self.compile({21})
        self.assertEqual(set(definitions), {'21', '22', '23'})
        spec = definitions['21']['native_record']['source_use_spec']
        self.assertEqual(spec['kind'], 'source_weighted_bag')
        self.assertEqual(spec['activation_status'], 'unrestricted')
        self.assertEqual([reward['probability_raw'] for reward in spec['rewards']],
                         [7500000, 2500000, 0])
        self.assertEqual(spec['source_probability_denominator'], 10000000)
        self.assertEqual(spec['class_probability_totals'], {'1': 10000000, '2': 10000000})
        self.assertEqual(spec['reward_selection_model'], 'local_single_weighted_draw')
        self.assertEqual(spec['random_draw_count'], 1)
        self.assertEqual(spec['draw_count_origin'], 'local_policy_not_source_count')
        self.assertTrue(spec['original_lucky_bag_class']['AbleMultiple'])

    def test_mixed_bag_separates_guaranteed_and_one_complete_weighted_pool(self):
        row = self.guaranteed_bag()
        self.item(23, category=6, equip=None, TestItem=False)
        self.tables['LuckyBagEntityView'].append({
            **row, 'ID': 102, 'ItemClassID': 23, 'LuckyBagEntityTypeID': 0,
            'Probability': 10000000, 'ItemAmount': 1})
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertEqual(spec['kind'], 'mixed_rewards_bag')
        self.assertEqual(spec['activation_status'], 'unrestricted')
        self.assertEqual([r['entity_type_id'] for r in spec['rewards']], [1, 0])
        self.assertEqual([r['amount'] for r in spec['rewards']], [1500, 1])
        self.assertEqual(spec['random_draw_count'], 1)

    def test_weighted_bag_class_filters_use_complete_relation_and_root_class_domain(self):
        row = self.guaranteed_bag()
        row.update(LuckyBagEntityTypeID=0, Probability=10000000, LimitClass=1)
        self.tables['LuckyBagEntityClassLimit'].append(dict(LuckyBagEntityID=101, ClassID=1))
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertEqual(spec['activation_status'], 'blocked')
        self.assertEqual(spec['class_probability_totals'], {'1': 10000000, '2': 0})
        self.tables['ItemClassLimit'].append(dict(ItemClassID=21, ClassID=1))
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertEqual(spec['activation_status'], 'unrestricted')
        self.assertEqual(spec['source_class_domain'], [1])
        self.assertEqual(spec['source_class_domain_origin'], 'ItemClassLimit')
        self.tables['ItemClassLimit'].clear()
        self.tables['LuckyBagEntityClassLimit'].append(dict(LuckyBagEntityID=101, ClassID=2))
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertEqual(spec['activation_status'], 'unrestricted')
        self.assertEqual(spec['rewards'][0]['class_ids'], [1, 2])
        self.assertEqual(spec['class_probability_totals'], {'1': 10000000, '2': 10000000})

    def test_zero_only_and_test_reward_bags_block_without_uniform_or_reroll_fallback(self):
        row = self.guaranteed_bag()
        row.update(LuckyBagEntityTypeID=0, Probability=0)
        definitions = self.compile({21})
        self.assertEqual(set(definitions), {'21'})
        spec = definitions['21']['native_record']['source_use_spec']
        self.assertEqual(spec['activation_status'], 'blocked')
        self.assertEqual(spec['rewards'][0]['probability_raw'], 0)
        self.assertNotIn('source_probability_denominator', spec)
        row['Probability'] = 10000000
        self.tables['ItemClass'][2]['TestItem'] = True
        definitions = self.compile({21})
        self.assertEqual(set(definitions), {'21'})
        self.assertIn('source_test_reward_item',
                      definitions['21']['native_record']['source_use_spec']['blocked_reasons'])

    def test_final_and_selectable_bag_types_stay_unsupported(self):
        row = self.guaranteed_bag()
        for kind in (2, 3):
            row['LuckyBagEntityTypeID'] = kind
            definitions = self.compile({21})
            self.assertEqual(set(definitions), {'21'})
            self.assertNotIn('source_use_spec', definitions['21']['native_record'])

    def test_ready_weighted_child_bag_expands_recursive_output_definitions(self):
        row = self.guaranteed_bag()
        self.tables['ItemClass'][2].update(CategoryID=8, TargettingTypeID=1,
                                          CanUseWhenInvisible=True, ServiceRegionCode='')
        self.tables['LuckyBagClass'].append(dict(ID=8, Name='Weighted child', AbleMultiple=True))
        self.bonus('LuckyBagClassID', 8, item=22, unit=11)
        self.item(23, category=6, equip=None, TestItem=False)
        self.item(24, category=6, equip=None, TestItem=False)
        self.tables['LuckyBagEntityView'].extend([
            {**row, 'ID': 201, 'LuckyBagClassID': 8, 'LuckyBagEntityTypeID': 0,
             'ItemClassID': 23, 'ItemAmount': 1, 'Probability': 3000000},
            {**row, 'ID': 202, 'LuckyBagClassID': 8, 'LuckyBagEntityTypeID': 0,
             'ItemClassID': 24, 'ItemAmount': 1, 'Probability': 7000000},
        ])
        definitions = self.compile({21})
        self.assertEqual(set(definitions), {'21', '22', '23', '24'})
        self.assertEqual(definitions['22']['native_record']['source_use_spec']['kind'],
                         'source_weighted_bag')

    def test_weighted_bag_rejects_unsupported_root_class_and_invalid_raw_weight(self):
        row = self.guaranteed_bag()
        row.update(LuckyBagEntityTypeID=0, Probability=10000000)
        self.tables['Class'].append(dict(ID=3, Name='unused', DescID=401, CanCreateClient=False))
        self.tables['ItemClassLimit'].append(dict(ItemClassID=21, ClassID=3))
        spec = self.compile({21})['21']['native_record']['source_use_spec']
        self.assertIn('unsupported_lucky_bag_root_class', spec['blocked_reasons'])
        self.assertNotIn('source_probability_denominator', spec)
        self.tables['ItemClassLimit'].clear()
        for value in (-1, 10000000.0):
            row['Probability'] = value
            definitions = self.compile({21})
            self.assertEqual(set(definitions), {'21'})
            spec = definitions['21']['native_record']['source_use_spec']
            self.assertIn('invalid_lucky_bag_probability', spec['blocked_reasons'])
            self.assertEqual(spec['rewards'][0]['probability_raw'], value)

    def test_reward_initial_equipment_level_is_preserved_without_an_enhancement_roll(self):
        row = self.guaranteed_bag()
        self.tables['ItemClass'][2]['CategoryID'] = 1
        self.tables['ItemEquipSlot'].append(dict(ItemClassID=22, EquipSlotID=8))
        row['ItemEnchant'] = 9
        definitions = self.compile({21})
        self.assertEqual(set(definitions), {'21', '22'})
        spec = definitions['21']['native_record']['source_use_spec']
        self.assertEqual(spec['activation_status'], 'unrestricted')
        self.assertEqual(spec['rewards'][0]['enchant'], 9)
        self.assertEqual(spec['source_entities'][0]['ItemEnchant'], 9)
        self.assertEqual(definitions['22']['native_record']['slot'], 'weapon')
        self.assertNotIn('success_chance', spec)
        self.assertNotIn('enhancement_cost', spec)

    def test_positive_reward_level_rejects_nonwearable_unknown_or_ambiguous_slot(self):
        row = self.guaranteed_bag()
        row['ItemEnchant'] = 5
        for equips in ([], [dict(ItemClassID=22, EquipSlotID=293)],
                       [dict(ItemClassID=22, EquipSlotID=8),
                        dict(ItemClassID=22, EquipSlotID=1)]):
            self.tables['ItemEquipSlot'] = [dict(ItemClassID=20, EquipSlotID=8), *equips]
            self.tables['EquipSlot'][2]['Name'] = 'UnknownOriginalSlot'
            definitions = self.compile({21})
            self.assertEqual(set(definitions), {'21'})
            spec = definitions['21']['native_record']['source_use_spec']
            self.assertEqual(spec['activation_status'], 'blocked')
            self.assertEqual(spec['rewards'][0]['enchant'], 5)
            self.assertIn('unsupported_lucky_bag_reward_amount_or_variant', spec['blocked_reasons'])

    def test_negative_or_fractional_initial_reward_level_stays_blocked(self):
        row = self.guaranteed_bag()
        self.tables['ItemEquipSlot'].append(dict(ItemClassID=22, EquipSlotID=8))
        for level in (-1, 0.5, True):
            row['ItemEnchant'] = level
            definitions = self.compile({21})
            self.assertEqual(set(definitions), {'21'})
            spec = definitions['21']['native_record']['source_use_spec']
            self.assertEqual(spec['activation_status'], 'blocked')
            self.assertEqual(spec['rewards'][0]['enchant'], level)

    def test_all_mapped_slot_names_are_explicit(self):
        self.assertEqual(compiler.SLOT_MAP, {
            'Head': 'helmet', 'Torso': 'body', 'Shirt': 'tshirt', 'Cloak': 'cloak',
            'Leg': 'gaiters', 'Foot': 'boots', 'Hand': 'gloves', 'WeaponHold': 'weapon',
            'Finger': 'ring', 'Neck': 'necklace', 'Waist': 'belt', 'Ear': 'earring',
            'ShieldHold': 'offhand', 'Quiver': 'offhand', 'Rune': 'rune',
            'SpellRune': 'rune', 'Badge': 'seal', 'Insignia': 'badge',
            'Spaulder': 'shoulder', 'Bangle_normal': 'bracelet', 'Bangle_BM': 'bracelet',
            'Crest': 'crystal', 'Catalyst': 'catalyst',
            'DominationStone': 'domination_stone',
        })


if __name__ == '__main__':
    unittest.main()
