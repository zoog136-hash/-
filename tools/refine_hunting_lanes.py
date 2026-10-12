"""Extend this pass's partitions to full hall width; preserve every old object.

Only replaces objects tagged hunting_paths_v1 AND hunting_lane. Perimeters,
actors, old assets, maps, portals and existing geometry are left in place.
"""
import json
from pathlib import Path
from shapely.geometry import Polygon
from shapely.ops import unary_union
from build_hunting_pathways import Authoring, GROUP, ROOT, shape


def main():
    index=json.loads((ROOT/'data/maps/field_index.json').read_text())
    paths=[ROOT/'data/maps/aden_field.json']+[ROOT/e['path'].removeprefix('res://') for e in index]
    profiles=json.loads((ROOT/'data/monsters/world_spawn_profiles.json').read_text())['maps']
    results=[];reports=[]
    for serial,path in enumerate(paths):
        d=json.loads(path.read_text())
        if d.get('hunting_paths',{}).get('version')!=1: raise SystemExit('Missing first pass: '+str(path))
        if d['hunting_paths'].get('hall_width_revision'):raise SystemExit('Already refined: '+str(path))
        preserved=d['hunting_paths']['preserved_original_props']
        d['props']=[r for r in d['props'] if not (r.get('placement_group')==GROUP and r.get('hunting_lane'))]
        d['collision']=[r for r in d['collision'] if not (r.get('placement_group')==GROUP and r.get('hunting_lane'))]
        a=Authoring(d,serial,profiles.get(d['map_id'],{}))
        a.floor=unary_union([Polygon(p) for p in d['navigable_polygons']])
        a.floor_inside=a.floor.buffer(-a.clearance)
        a.existing=unary_union([shape(c,5) for c in d['collision']])
        a.hunting_lanes()
        check=a.validate()
        a.d['hunting_paths']['lanes']=a.groups
        a.d['hunting_paths']['detour_probes']=a.probes
        a.d['hunting_paths']['hall_width_revision']=1
        a.d['hunting_paths']['preserved_original_props']=preserved
        results.append((path,a.d))
        reports.append({'map_id':d['map_id'],'lane_count':len(a.groups),'navigation_authoring_check':check})
        print(d['map_id'],'lanes',len(a.groups),'props',len(a.d['props']),flush=True)
    for path,d in results:path.write_text(json.dumps(d,ensure_ascii=False,separators=(',',':'))+'\n')
    ledger=ROOT/'docs/hunting-paths-20261012/authoring-ledger.json'
    document=json.loads(ledger.read_text())
    by_id={r['map_id']:r for r in reports}
    for record in document['maps']:
        record['navigation_authoring_check']=by_id[record['map_id']]['navigation_authoring_check']
        path=next(p for p,d in results if d['map_id']==record['map_id'])
        record['after_props']=len(json.loads(path.read_text())['props'])
        record['lane_count']=by_id[record['map_id']]['lane_count']
    document['hall_width_refinement']=True
    ledger.write_text(json.dumps(document,ensure_ascii=False,indent=2)+'\n')
    print('HUNTING_HALL_REFINEMENT_OK',len(results))


if __name__=='__main__':main()
