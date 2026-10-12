"""Existing rock assets flank saved Escaros travel routes, with lateral exits.

Reuses saved road geometry, not an invented original floor plan. Adds only this
pass's tagged physical objects; all old map and actor coordinates are preserved.
"""
import json
import math
from shapely.geometry import LineString, Polygon
from shapely.ops import unary_union
from build_hunting_pathways import Authoring, ROOT, shape


def main():
    profiles=json.loads((ROOT/'data/monsters/world_spawn_profiles.json').read_text())['maps']
    index=json.loads((ROOT/'data/maps/field_index.json').read_text())
    outputs=[];reports={}
    for serial,entry in enumerate(index,1):
        if entry['family']!='escaros':continue
        path=ROOT/entry['path'].removeprefix('res://')
        d=json.loads(path.read_text())
        if d['hunting_paths'].get('canyon_revision'):raise SystemExit('Canyon pass already applied: '+str(path))
        a=Authoring(d,serial,profiles[d['map_id']])
        a.floor=unary_union([Polygon(p) for p in d['navigable_polygons']])
        a.floor_inside=a.floor.buffer(-a.clearance)
        a.existing=unary_union([shape(c,5) for c in d['collision']])
        a.groups=d['hunting_paths']['lanes'].copy()
        for road_index,road in enumerate(d['roads']):
            line=LineString(road['points'])
            for side in ['left','right']:
                ridge=line.parallel_offset(510 if road_index==0 else 460,side,join_style=2).simplify(45)
                lines=[ridge] if ridge.geom_type=='LineString' else list(ridge.geoms)
                for part,curve in enumerate(lines):
                    for segment in range(math.ceil(curve.length/1850)):
                        start=segment*1850+130
                        end=min(curve.length,segment*1850+1570)
                        if end-start<260:continue
                        count=math.ceil((end-start)/125)
                        coords=[]
                        for step in range(count+1):
                            p=curve.interpolate(start+(end-start)*step/count)
                            coords.append([round(p.x,2),round(p.y,2)])
                        a.offer_chain(coords,'rocks',78,f'canyon_{road_index}_{side}_{part}',segment)
        checks=a.validate()
        a.d['hunting_paths']['lanes']=a.groups
        a.d['hunting_paths']['detour_probes']=a.probes
        a.d['hunting_paths']['canyon_revision']=1
        outputs.append((path,a.d));reports[d['map_id']]=checks
        print(d['map_id'],'physical hunting objects',sum('hunting_lane' in p for p in a.d['props']),
              'lanes',len(a.groups),'reachable',checks['reachable_cells'],flush=True)
    for path,d in outputs:path.write_text(json.dumps(d,ensure_ascii=False,separators=(',',':'))+'\n')
    ledger=ROOT/'docs/hunting-paths-20261012/authoring-ledger.json'
    document=json.loads(ledger.read_text())
    for row in document['maps']:
        if row['map_id'] not in reports:continue
        d=next(d for path,d in outputs if d['map_id']==row['map_id'])
        row['navigation_authoring_check']=reports[row['map_id']]
        row['after_props']=len(d['props']);row['lane_count']=len(d['hunting_paths']['lanes'])
    document['escaros_canyon_refinement']=True
    ledger.write_text(json.dumps(document,ensure_ascii=False,indent=2)+'\n')
    print('ESCAROS_CANYONS_OK',len(outputs))


if __name__=='__main__':main()
