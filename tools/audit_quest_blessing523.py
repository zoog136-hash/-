"""Verify the exact original 523 quest blessing joins without extracting pack contents."""
import argparse
import collections
import hashlib
import json
import zipfile
from pathlib import Path

PIN = 'd5192c3c735ff95c6b181bf2d4d77448d8b562fdb28dbd43f897fa4eae1f4832'


def check(path):
    if hashlib.sha256(path.read_bytes()).hexdigest() != PIN:
        raise ValueError('wrong original definitions archive')
    with zipfile.ZipFile(path) as z:
        def rows(name):
            return json.loads(z.read(f'content/{name}.json').decode('utf-8-sig'))['rows']
        reward = {r['ID']: r for r in rows('Reward')}
        quests = {q['ID']: q for q in rows('QuestView')}
        types = {r['ID']: r['Name'] for r in rows('RewardType')}
        if types.get(5) != 'Einasad':
            raise ValueError('wrong RewardType')
        by_quest = collections.defaultdict(list)
        for link in rows('QuestReward'):
            by_quest[link['QuestID']].append(reward.get(link['RewardID'], {}))
        grants = []
        for qid, rewards in by_quest.items():
            for r in rewards:
                if r.get('RewardTypeID') != 5:
                    continue
                if (qid not in quests or r['RewardGetTimeTypeID'] != 2 or r['RewardEnhancementTypeID'] != 1
                        or r['UseImmediately'] is not False or r['ClanOnly'] is not False or r['CharacterClassID'] != 0
                        or r['RewardClassID'] not in (7049, 1859) or not isinstance(r['Amount'], int) or r['Amount'] <= 0):
                    raise ValueError(f'unsupported reward shape: {qid}')
                grants.append((qid, r['ID'], r['Amount'], r['RewardClassID'], len(rewards) > 1))
        if len(grants) != 38 or len({a[0] for a in grants}) != 38:
            raise ValueError('unexpected number of quest links')
        return {'archive_sha256': PIN, 'count': len(grants), 'mixed_reward_quests': sum(r[4] for r in grants),
                'amount_counts': dict(sorted(collections.Counter(r[2] for r in grants).items())),
                'reference_class_counts': dict(sorted(collections.Counter(r[3] for r in grants).items())),
                'base_quest_links': sorted(grants)}


if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('archive', type=Path)
    print(json.dumps(check(ap.parse_args().archive), ensure_ascii=False))
