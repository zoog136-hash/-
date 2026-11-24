#!/usr/bin/env python3
"""Reproduce exact quest-only ItemClass retirement; no broad name matching."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile

SOURCE_SHA = "d5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832"

# This older item uses an individual story rather than the shared quest-only
# caption; its pinned QuestReward and ItemUse joins are checked below.
LEGACY_NAMES = {
    "[퀘스트] 죽은 모험가의 일지": 1214,
    "[퀘스트] 하딘의 일지 1": 1991,
    "[퀘스트] 하딘의 일지 2": 2001,
    "[퀘스트] 수상한 쪽지": 2011,
    "[퀘스트] 맹세의 잔": 122562,
}


def audited(path: Path) -> tuple[dict, dict, dict[str, set[int]]]:
    with path.open('rb') as handle:
        if hashlib.file_digest(handle, 'sha256').hexdigest() != SOURCE_SHA:
            raise ValueError("not the exact pinned 523 source definitions")
    with ZipFile(path) as src:
        def table(name):
            return json.loads(src.read(f"content/{name}.json"))['rows']

        raw = {x['ID']: x for x in table('ItemClass')}
        local = {x['ID']: x['Description'] for x in table('DescData_Korean')}
        cat = {x['ID']: x['Name'] for x in table('ItemCategory')}
        assert cat[10234] == 'ScrollQuest' and cat[10341] == 'QuestFreePass'
        reasons = {
            'source_quest_scroll': {r['ID'] for r in raw.values() if r['CategoryID'] == 10234},
            'source_quest_pass': {r['ID'] for r in raw.values() if r['CategoryID'] == 10341}
                                 | {r['ItemClassID'] for r in table('QuestFreePass')},
            'original_quest_item_only_description': {
                r['ID'] for r in raw.values()
                if local.get(r['StoryDescID'], '').strip() == "퀘스트 아이템"
            },
        }
        item_use_id = next(r['ID'] for r in table('GoalType') if r['Name'] == 'ItemUse')
        used = {r['ID']: r['GoalClassID'] for r in table('Goal')
                if r['GoalTypeID'] == item_use_id}
        goal_items = {used[g['GoalID']] for g in table('QuestGoal') if g['GoalID'] in used}
        item_reward = next(r['ID'] for r in table('RewardType') if r['Name'] == 'Item')
        rewards = {r['ID']: r['RewardClassID'] for r in table('Reward')
                   if r['RewardTypeID'] == item_reward}
        reward_items = {rewards[q['RewardID']] for q in table('QuestReward') if q['RewardID'] in rewards}
        for name, id_value in LEGACY_NAMES.items():
            assert raw[id_value]['TestItem'] is True and id_value in goal_items and id_value in reward_items
            assert any(local.get(raw[id_value][key], '').strip() == name for key in ('DescID', 'IdentifiedDescID'))
        reasons['exact_legacy_quest_reward_and_item_use'] = set(LEGACY_NAMES.values())
    return raw, local, reasons


def main() -> None:
    cli = argparse.ArgumentParser()
    cli.add_argument('source', type=Path)
    cli.add_argument('--csv', type=Path)
    cli.add_argument('--constants', action='store_true')
    args = cli.parse_args()
    raw, local, reasons = audited(args.source)
    ids = sorted(set.union(*reasons.values()))
    if args.constants:
        for index in range(0, len(ids), 12):
            print('\t' + ''.join(f"{n}:true," for n in ids[index:index+12]))
    if args.csv:
        with args.csv.open('w', encoding='utf-8-sig', newline='') as file:
            csv_out = csv.writer(file)
            csv_out.writerow(['ItemClassID', '한국어 이름', 'TestItem', '원본 전용 근거'])
            for n in ids:
                row = raw[n]
                csv_out.writerow([n, local.get(row['DescID'], row['Name']), row['TestItem'],
                                  '; '.join(k for k, values in reasons.items() if n in values)])
    print(f"retired={len(ids)} normal={sum(not raw[n]['TestItem'] for n in ids)} test={sum(raw[n]['TestItem'] for n in ids)}")


if __name__ == '__main__':
    main()
