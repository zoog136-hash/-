"""Build source-only review entries; no NPC/merchant or region-center fallback."""
import argparse
import hashlib
import json
from pathlib import Path


def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def build(universe, tables, inventory):
    locations = {int(r['ID']): r for r in read(tables / 'Locations.json')['rows']}
    types = {int(r['ID']) for r in read(tables / 'BonusType.json')['rows'] if r['Name'] == 'TeleportToLocation'}
    entries = {}
    for bonus in read(tables / 'Bonus.json')['rows']:
        if int(bonus['BonusTypeID']) not in types:
            continue
        location = locations.get(int(bonus['Value']))
        if location:
            entries.setdefault(int(location['LandID']), []).append(dict(kind='TELEPORT_TO_LOCATION', id=int(bonus['ID']), location_id=int(location['ID']), x=int(location['X']), y=int(location['Y'])))
    seen = set()
    for file in sorted(universe.glob('base508_asset_*/portals.json')):
        for portal in read(file):
            pid = int(portal['ID'])
            if pid in seen:
                continue
            seen.add(pid)
            target = portal['TargetTerritory']
            if target['StartX'] != target['EndX'] or target['StartY'] != target['EndY']:
                continue
            entries.setdefault(int(target['LandID']), []).append(dict(kind='PORTAL_POINT_TARGET', id=pid, territory_id=int(target['ID']), source_land_id=int(portal['SourceLandID']), x=int(target['StartX']), y=int(target['StartY'])))
    result = []
    for source in inventory:
        asset = source['asset']
        manifest = universe / ('base508_asset_' + asset) / 'map.json'
        choices = sorted(entries.get(source['land'], []), key=lambda e: (e['kind'], e['id']))
        status = 'READY_FOR_GRAPH_REVIEW' if source['candidate_01_only'] and choices else ('NO_EXPLICIT_ENTRY' if source['candidate_01_only'] else 'UNREVIEWED_ATTRIBUTE_PROFILE')
        result.append(dict(asset=asset, land=source['land'], name=source['name'], status=status, entries=choices, map_sha256=hashlib.sha256(manifest.read_bytes()).hexdigest()))
    return dict(schema=1, edition='LineageM_base508', scope='REVIEW_ONLY_NOT_NATIVE_M_APPROVAL', maps=result)


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--universe', type=Path, required=True)
    p.add_argument('--tables', type=Path, required=True)
    p.add_argument('--inventory', type=Path, required=True)
    p.add_argument('--out', type=Path, required=True)
    a = p.parse_args()
    result = build(a.universe, a.tables, read(a.inventory))
    a.out.write_text(json.dumps(result, ensure_ascii=False, indent=2))
    from collections import Counter
    print(dict(Counter(r['status'] for r in result['maps'])))


if __name__ == '__main__':
    main()
