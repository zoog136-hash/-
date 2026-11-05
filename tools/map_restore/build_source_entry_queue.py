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
    territories = {int(r['ID']): r for r in read(tables / 'Territories.json')['rows']}
    teleports = {int(r['ID']): r for r in read(tables / 'LandTeleport.json')['rows']}
    requirements = {}
    for r in read(tables / 'LandTeleportPrerequisite.json')['rows']:
        requirements.setdefault(int(r['LandTeleportID']), []).append(r)
    for relation in read(tables / 'LandTeleportTerritories.json')['rows']:
        target = territories.get(int(relation['TerritoryID']))
        teleport = teleports.get(int(relation['LandTeleportID']))
        if not target or not teleport or target['StartX'] != target['EndX'] or target['StartY'] != target['EndY']:
            continue
        entries.setdefault(int(target['LandID']), []).append(dict(kind='LAND_TELEPORT_POINT_TARGET', id=int(relation['ID']),
            territory_id=int(target['ID']), land_teleport=teleport, prerequisites=requirements.get(int(teleport['ID']), []),
            activation_status='NOT_EVALUATED_NOT_CONSUMED', x=int(target['StartX']), y=int(target['StartY'])))
    seen = set()
    for file in sorted(universe.glob('base508_asset_*/portals.json')):
        context_file = file.parent / 'land_contexts.json'
        portals = read(file)
        if context_file.exists():
            portals += [p for context in read(context_file) for p in context['portals']]
        for portal in portals:
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
        contexts_file = manifest.parent / 'land_contexts.json'
        contexts = read(contexts_file) if contexts_file.exists() else [dict(land=read(manifest)['land'])]
        for context in contexts:
            land = context['land']
            choices = sorted(entries.get(int(land['ID']), []), key=lambda e: (e['kind'], e['id']))
            status = 'READY_FOR_GRAPH_REVIEW' if source['candidate_01_only'] and choices else ('NO_EXPLICIT_ENTRY' if source['candidate_01_only'] else 'UNREVIEWED_ATTRIBUTE_PROFILE')
            result.append(dict(asset=asset, land=int(land['ID']), name=land['Name'], status=status, entries=choices, map_sha256=hashlib.sha256(manifest.read_bytes()).hexdigest()))
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
