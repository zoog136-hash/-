#!/usr/bin/env python3
"""Preserve the verified523 level96 quest/box/unlock chain and full ancestry.

This exports evidence, not an automatic grant or a completion-state policy.
PrerequisiteType4 only names a Quest; its completion/claim semantics are absent.
"""
import argparse
import collections
import hashlib
import json
import pathlib
import zipfile

SOURCE_SHA256 = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'


def build(source, output):
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest != SOURCE_SHA256:
        raise ValueError('Expected the verified patch523 source ZIP')
    names = ('QuestView', 'QuestType', 'QuestLevel', 'QuestPrerequisite',
             'Prerequisite', 'PrerequisiteType', 'QuestGoal', 'Goal', 'GoalType',
             'QuestReward', 'Reward', 'RewardType', 'ItemClass', 'ItemCategory',
             'ItemBonus', 'Bonus', 'BonusType', 'Unit', 'UIUnit', 'UseDesc',
             'BuffClass', 'BuffBonus', 'LuckyBagClass', 'LuckyBagEntityView',
             'LuckyBagEntityType', 'DescData_Korean', 'ServerLimit',
             'DateTimes', 'DateTimes_Korean', 'Grade', 'ItemBlessCode',
             'ItemClassLimit', 'LuckyBagEntityClassLimit', 'LuckyBagClassView')
    tables, hashes = {}, {}
    with zipfile.ZipFile(source) as archive:
        for name in names:
            raw = archive.read('content/' + name + '.json')
            hashes[name] = hashlib.sha256(raw).hexdigest()
            tables[name] = json.loads(raw.decode('utf-8-sig'))['rows']
    by = {name: {r['ID']: r for r in rows if 'ID' in r}
          for name, rows in tables.items()}
    positions = {name: {id(r): i for i, r in enumerate(rows)}
                 for name, rows in tables.items()}
    references = set()

    def ref(name, row):
        index = positions[name][id(row)]
        references.add((name, index))
        return {'table': name, 'row_index_zero': index, 'raw': row}

    def get(name, row_id):
        return ref(name, by[name][row_id])

    def descriptions(row, fields):
        return {field: get('DescData_Korean', row[field])
                for field in fields if row.get(field) in by['DescData_Korean']}

    def item(row_id):
        row = by['ItemClass'][row_id]
        return {'item': get('ItemClass', row_id),
                'category': get('ItemCategory', row['CategoryID']),
                'grade': get('Grade', row['GradeID']),
                'class_limits': [ref('ItemClassLimit', limit) for limit in tables['ItemClassLimit']
                                 if limit['ItemClassID'] == row_id],
                'descriptions': descriptions(row, ('DescID', 'IdentifiedDescID',
                    'StoryDescID', 'ProductTitleDescID', 'ProductDescID'))}

    def effect(name, row):
        bonus = by['Bonus'][row['BonusID']]
        typ = by['BonusType'][bonus['BonusTypeID']]
        value = {'link': ref(name, row), 'bonus': get('Bonus', bonus['ID']),
                 'type': get('BonusType', typ['ID']), 'unit': get('Unit', typ['UnitID'])}
        ui = next((r for r in tables['UIUnit'] if r['UnitID'] == typ['UnitID']), None)
        if ui is not None:
            value['ui_unit'] = ref('UIUnit', ui)
        return value

    quest_links = collections.defaultdict(list)
    for row in tables['QuestPrerequisite']:
        quest_links[row['QuestID']].append(row)
    closure, pending = [], [96201]
    while pending:
        quest_id = pending.pop(0)
        if quest_id in closure:
            continue
        if quest_id not in by['QuestView']:
            raise ValueError('Missing referenced source QuestView')
        closure.append(quest_id)
        for link in quest_links[quest_id]:
            condition = by['Prerequisite'][link['PrerequisiteID']]
            if by['PrerequisiteType'][condition['PrerequisiteTypeID']]['Name'] == 'Quest':
                pending.append(condition['Value'])

    quests = {}
    for quest_id in closure:
        view = by['QuestView'][quest_id]
        prerequisites, goals, rewards = [], [], []
        for link in quest_links[quest_id]:
            condition = by['Prerequisite'][link['PrerequisiteID']]
            typ = by['PrerequisiteType'][condition['PrerequisiteTypeID']]
            prerequisites.append({'link': ref('QuestPrerequisite', link),
                'condition': get('Prerequisite', condition['ID']),
                'type': get('PrerequisiteType', typ['ID']),
                'descriptions': descriptions(typ, ('DescId',))})
        for link in tables['QuestGoal']:
            if link['QuestID'] == quest_id:
                goal = by['Goal'][link['GoalID']]
                goals.append({'link': ref('QuestGoal', link), 'goal': get('Goal', goal['ID']),
                    'type': get('GoalType', goal['GoalTypeID']),
                    'descriptions': descriptions(goal, ('DescID',))})
        for link in tables['QuestReward']:
            if link['QuestID'] != quest_id:
                continue
            reward = by['Reward'][link['RewardID']]
            entry = {'link': ref('QuestReward', link), 'reward': get('Reward', reward['ID']),
                     'type': get('RewardType', reward['RewardTypeID'])}
            if by['RewardType'][reward['RewardTypeID']]['Name'] == 'Item':
                entry['item_definition'] = item(reward['RewardClassID'])
            rewards.append(entry)
        dates = {}
        for name in names:
            if name.startswith('DateTimes'):
                dates[name] = {field: get(name, view[field]) if view[field] in by[name] else None
                               for field in ('StartTime', 'EndTime')}
        quests[str(quest_id)] = {'view': get('QuestView', quest_id),
            'quest_type': get('QuestType', view['TypeID']),
            'quest_level': get('QuestLevel', view['QuestLevelID']),
            'descriptions': descriptions(view, ('TitleDescID', 'ScenarioDescID', 'DescID', 'QuestLevelDescID')),
            'prerequisites': prerequisites, 'goals': goals, 'rewards': rewards,
            'dates': dates, 'server_limits': [ref('ServerLimit', row) for row in tables['ServerLimit']
                                            if row['ServerLimitSetID'] == view['ServerLimitSetID']]}

    def consumable_definition(row_id):
        result = item(row_id)
        result['effects'] = [effect('ItemBonus', row) for row in tables['ItemBonus']
                             if row['ItemClassID'] == row_id]
        return result

    box = consumable_definition(346921)
    bag_id = 81612
    bag_links = [r for r in tables['LuckyBagEntityView'] if r['LuckyBagClassID'] == bag_id]
    box['lucky_bag'] = get('LuckyBagClass', bag_id)
    box['contents'] = [{'entity': ref('LuckyBagEntityView', row),
                        'type': get('LuckyBagEntityType', row['LuckyBagEntityTypeID']),
                        'grade': get('Grade', row['GradeID']),
                        'category': get('ItemCategory', row['CategoryID']),
                        'bless_code': get('ItemBlessCode', row['ItemBlessCodeID']),
                        'class_limits': [ref('LuckyBagEntityClassLimit', limit)
                            for limit in tables['LuckyBagEntityClassLimit']
                            if limit['LuckyBagEntityID'] == row['ID']],
                        'item_definition': consumable_definition(row['ItemClassID'])}
                       for row in bag_links]
    box['content_type_counts'] = dict(collections.Counter(
        by['LuckyBagEntityType'][row['LuckyBagEntityTypeID']]['Name'] for row in bag_links))
    box['source_constraint_summary'] = {
        'item_bonus_names': [e['type']['raw']['Name'] for e in box['effects']],
        'item_level_limits': {key: by['ItemClass'][346921][key] for key in (
            'LevelLimitMin', 'LevelLimitMax', 'MaxLevelLimitMin', 'MaxLevelLimitMax')},
        'service_region_code': by['ItemClass'][346921]['ServiceRegionCode'],
        'content_limit_class_values': [row['LimitClass'] for row in bag_links],
        'content_equip_slot_values': [row['EquipSlotID'] for row in bag_links],
        'warning': 'Raw LimitClass10000 and EquipSlotID10000 are preserved; no broader server/date/choice rule is inferred.'}
    unlock = next(r['item_definition'] for r in box['contents']
                  if r['entity']['raw']['ItemClassID'] == 365748)
    unlock['buff'] = get('BuffClass', 95648)
    unlock['buff_effects'] = [effect('BuffBonus', row) for row in tables['BuffBonus']
                              if row['BuffClassID'] == 95648]
    unlock['use_desc'] = get('UseDesc', by['ItemClass'][365748]['UseDescID'])
    unlock['use_description'] = get('DescData_Korean', unlock['use_desc']['raw']['DescID'])
    if (len(closure) != 36 or len(quests['96201']['rewards']) != 5
            or len(quests['92794']['rewards']) != 5
            or [(r['ItemClassID'], r['ItemAmount'], r['LuckyBagEntityTypeID']) for r in bag_links]
                != [(365748, 1, 1), (365758, 1, 1)]):
        raise ValueError('Reviewed source closure/reward/box content changed')
    level_goals = [g['goal']['raw'] for g in quests['96201']['goals']]
    if len(level_goals) != 1 or level_goals[0]['GoalTypeID'] != 7 or level_goals[0]['Amount'] != 96:
        raise ValueError('Level96 goal changed')
    result = {'schema': 1, 'source_snapshot': 'patch523', 'source_zip_sha256': digest,
        'source_table_sha256': hashes, 'target_quest_id': 96201,
        'prerequisite_quest_id': 92794, 'ancestor_quest_ids_target_first': closure,
        'quests': quests, 'box': box,
        'execution_boundaries': {
            'quest_reference_state_semantics': 'unspecified: PrerequisiteType4 says Quest / 선행 퀘스트 only; goal-complete versus reward-claimed is not encoded',
            'quest_level_semantics': 'QuestLevel1 carries MinLevel1/MaxLevel30 even for Level96 goal; do not reinterpret it as a use/claim ceiling without runtime evidence',
            'reward_get_time_type_2': 'raw value retained; no corresponding enum table supplied in1065 content tables',
            'claim_policy': 'explicit user claim must not mark ancestry claimed from current level or auto-pay a reward',
            'open_policy': 'separate explicit open consumes the exact source box and gives BOTH IsGiven items365748 and365758; Probability0 is not a random weight',
            'box_constraints': 'All2 rows are IsGiven, ItemAmount1, ItemBlessCode1, ItemEnchant0. No selectable/random entity, class-limit row or item DeleteTime bonus is present. Numeric item level limits are0 and ServiceRegionCode is empty. Absence does not prove every server execution condition.',
            'scope': 'ServerLimitSetID0 on all36 quests; locale DateTimes preserved separately; absent date definitions remain absent',
            'source_execution': 'static content graph only; execution timing, prerequisite state, claim persistence and transaction behavior are not supplied'},
        'counts': {'ancestor_quests': len(closure),
                   'quest_rewards': sum(len(q['rewards']) for q in quests.values()),
                   'box_entities': len(bag_links), 'distinct_source_rows': len(references)}}
    # Validate all embedded references independently against the source rows.
    count = 0
    def verify(value):
        nonlocal count
        if isinstance(value, dict):
            if {'table', 'row_index_zero', 'raw'} <= value.keys():
                if tables[value['table']][value['row_index_zero']] != value['raw']:
                    raise ValueError('Source reference mismatch')
                count += 1
            else:
                for child in value.values():
                    verify(child)
        elif isinstance(value, list):
            for child in value:
                verify(child)
    verify(result)
    result['counts']['verified_embedded_references'] = count
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')
    print(json.dumps(result['counts']))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=pathlib.Path)
    parser.add_argument('--output', default='data/cards/patch523_relic_acquisition.json', type=pathlib.Path)
    args = parser.parse_args()
    build(args.source, args.output)
