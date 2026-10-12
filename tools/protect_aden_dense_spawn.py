"""Remove only this pass's hunting barriers from the existing dense spawn area.

Retains every earlier object, NPC, wall, spawn coordinate and population rule.
The population cap is unchanged. Recomputes real detour probes after the fix.
"""
import json
from shapely.geometry import Point, Polygon
from shapely.ops import unary_union
from build_hunting_pathways import Authoring, ROOT, GROUP, shape


def main():
    path=ROOT/'data/maps/aden_field.json'
    d=json.loads(path.read_text())
    if d['hunting_paths'].get('dense_capacity_revision'):raise SystemExit('Dense capacity protection already applied')
    profile=json.loads((ROOT/'data/monsters/world_spawn_profiles.json').read_text())['maps']['aden_world']
    a=Authoring(d,0,profile)
    # Authoring.protection now includes the full dense polygons and spacing.
    removed=[]
    for c in d['collision']:
        if c.get('placement_group')==GROUP and c.get('hunting_lane') and a.protection.distance(Point(c['center']))<c['radius']+30:
            # The pre-existing route/NPC masks already excluded these records;
            # newly rejected circles are the ones beside the dense encounter.
            removed.append(c)
    ids={c['id'] for c in removed}
    a.d['collision']=[c for c in a.d['collision'] if c.get('id') not in ids]
    a.d['props']=[p for p in a.d['props'] if p.get('id') not in ids]
    counts={}
    for c in a.d['collision']:
        if c.get('hunting_lane'):counts[c['hunting_lane']]=counts.get(c['hunting_lane'],0)+1
    a.groups=[{**g,'object_count':counts[g['id']]} for g in d['hunting_paths']['lanes'] if counts.get(g['id'],0)>0]
    a.floor=unary_union([Polygon(p) for p in d['navigable_polygons']])
    a.floor_inside=a.floor.buffer(-a.clearance)
    a.existing=unary_union([shape(c,5) for c in a.d['collision']])
    check=a.validate()
    a.d['hunting_paths']['lanes']=a.groups
    a.d['hunting_paths']['detour_probes']=a.probes
    a.d['hunting_paths']['dense_capacity_revision']=1
    path.write_text(json.dumps(a.d,ensure_ascii=False,separators=(',',':'))+'\n')
    ledger=ROOT/'docs/hunting-paths-20261012/authoring-ledger.json'
    document=json.loads(ledger.read_text())
    for record in document['maps']:
        if record['map_id']!='aden_world':continue
        record['after_props']=len(a.d['props'])
        record['lane_count']=len(a.groups)
        record['navigation_authoring_check']=check
        record['dense_capacity_correction_removed_only_this_pass']=removed
    ledger.write_text(json.dumps(document,ensure_ascii=False,indent=2)+'\n')
    print('ADEN_DENSE_CAPACITY_PROTECTED','removed',len(removed),'spawn cells',check['spawn_cells']['dragon_dense'])


if __name__=='__main__':main()
