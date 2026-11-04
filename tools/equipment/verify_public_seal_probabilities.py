#!/usr/bin/env python3
"""Verify the narrow executable seal policy against NC's public browser API.

Fetches no account data. Resource-Token is the public token served to every
visitor by /contents, and is neither logged nor written to the output report.
The report is source evidence, not a runtime auto-update or approval to change
existing TWILIGHT prices/probabilities.
"""
import argparse
import json
from pathlib import Path
import urllib.request

BASE = 'https://probability.plaync.com/api/lineagem/'
CATEGORY = '6656e14296b3cf5ad823b7a7'


def get(path, headers=None):
    request = urllib.request.Request(BASE + path, headers=headers or {})
    with urllib.request.urlopen(request, timeout=45) as response:
        return json.load(response)


def public_records(category, version):
    records = []
    for section in get('contents/' + category + '?version=' + version):
        page = 1
        while True:
            result = get('resources?version=' + version + '&page=' + str(page),
                         {'Resource-Token': section['resourceToken']})
            records.extend(result['records'])
            if page >= result['pageNavigation']['lastPage']:
                break
            page += 1
    return records


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    policy = json.loads((root/'data/crafting/patch523_seal_policy.json').read_text())
    latest = get('versions')[0]
    version = latest['version']
    records = public_records(CATEGORY, version)
    wanted = {
        '수호/회복의 인장(빛나는 장비 강화 주문서)': ('ordinary_normal_success_pct', 0, False),
        '수호/회복의 인장(빛나는 장비 보호 주문서)': ('protected_normal_success_pct', 4, True),
        '축복받은 수호/회복의 인장(빛나는 장비 보호 주문서)': ('protected_blessed_success_pct', 4, True),
    }
    checked = {}
    for title, (key, first, protected) in wanted.items():
        matches = [r['@entries'] for r in records if r.get('아이템명') == title]
        if len(matches) != 1:
            raise ValueError('official target missing/ambiguous: ' + title)
        rows = matches[0]
        expected = policy[key]
        if len(rows) != len(expected):
            raise ValueError('official level coverage changed: ' + title)
        for offset, (row, chance) in enumerate(zip(rows, expected)):
            actual = (int(row['인챈트 수치']), float(row['성공 확률[%]']),
                      float(row['아무 일 없음 확률[%]']), float(row['증발 확률[%]']))
            target = (first + offset, chance, 100 - chance if protected else 0,
                      0 if protected else 100 - chance)
            if any(abs(a-b)>0.000001 for a,b in zip(actual,target)):
                raise ValueError('official probability/failure rule changed: ' + title)
        checked[key] = {'current_levels': list(range(first, first+len(rows))),
                        'success_pct': expected, 'failure': 'retain' if protected else 'destroy'}
    weapon_records = public_records('663af7390b56825a0765f23b',version)
    craftsman = {}
    for title, levels in [('장인의 무기 마법 주문서(일반~영웅 등급 무기)',[9]),
                          ('장인의 무기 마법 주문서(전설 등급 무기)',[9,10]),
                          ('장인의 무기 마법 주문서(신화 등급 무기)',[9,10,11])]:
        matches = [r for r in weapon_records if r.get('주문서명')==title]
        if len(matches)!=1:
            raise ValueError('official craftsman grade missing/ambiguous')
        rows = matches[0].get('@entries',[matches[0]])
        if [int(r['인챈트 수치']) for r in rows]!=levels:
            raise ValueError('official craftsman qualification changed')
        for row in rows:
            if (float(row['성공 확률[%]']),float(row['아무 일 없음 확률[%]']),float(row['증발 확률[%]'])) != (policy['craftsman_weapon_success_pct'],95.0,0.0):
                raise ValueError('official craftsman probability changed')
        craftsman[title] = {'current_levels':levels,'success_pct':5,'remain_pct':95}
    report = {'official_url':policy['official_url'], 'observed_version':version,
              'observed_update':latest['updateDate'], 'policy_version':policy['official_version'],
              'matched':True, 'branches':checked, 'craftsman_weapon':craftsman}
    output = json.dumps(report,ensure_ascii=False,indent=2)+'\n'
    if args.output:
        if args.output.resolve().is_relative_to(root):
            raise ValueError('keep fetched research evidence outside the public repository')
        args.output.write_text(output)
    print(output,end='')


if __name__ == '__main__':
    main()
