"""Shape actual walking lanes with existing TWILIGHT objects on all 25 maps.

Requires numpy, scipy and shapely (authoring only). No image assets are created.
Saved geography, map IDs, room connectivity, actors and all old props survive.
Public maps inform rock corridors/colonnades; these are local approximations,
not recovered original client placements or verified boss coordinates.
"""
import collections
import copy
import hashlib
import json
import math
from pathlib import Path

import numpy as np
from scipy.ndimage import label
from shapely import contains_xy, make_valid
from shapely.geometry import LineString, Point, Polygon, box
from shapely.ops import unary_union

ROOT = Path(__file__).resolve().parents[1]
BASELINE = "bab7ba5aa1a074bc1d37c6b2500e2c0fcd11bc91"
GROUP = "hunting_paths_v1"
REFERENCES = {
    "aden": "https://games.app-liv.jp/archives/397568",
    "oman": "https://www.gamechosun.co.kr/webzine/article/view.php?no=145842",
    "escaros": "https://www.inven.co.kr/board/powerbbs.php?come_idx=5056&l=19989&vtype=pc",
    "faith": "assets/maps/faith1.png; assets/maps/faith3.png; assets/maps/faith4.png",
    "albino": "assets/maps/albino12.png; assets/maps/albino3.png",
    "domination": "https://lineagem-jp.com/guides/lm/guides/dungeon_TowerofDomination",
}


def polygons(value):
    if value.is_empty:
        return []
    if value.geom_type == "Polygon":
        return [value]
    if hasattr(value, "geoms"):
        return [p for g in value.geoms for p in polygons(g)]
    return []


def points(ring):
    return [[round(x, 2), round(y, 2)] for x, y in list(ring.coords)[:-1]]


def shape(c, pad=0):
    if c['shape'] == 'circle':
        return Point(c['center']).buffer(c['radius']+pad, quad_segs=12)
    if c['shape'] == 'rect':
        x, y, w, h = c['rect']
        return box(x-pad, y-pad, x+w+pad, y+h+pad)
    return Polygon(c['points']).buffer(pad, quad_segs=6) if pad else Polygon(c['points'])


def jagged_rectangle(w, h, seed):
    """Keep the former field boundary; replace the ruler-straight cliff edge."""
    corners = [(160, 160), (w-160, 160), (w-160, h-160), (160, h-160)]
    result = []
    for edge, (a, b) in enumerate(zip(corners, corners[1:]+corners[:1])):
        distance = math.dist(a, b)
        count = math.ceil(distance/340)
        dx, dy = (b[0]-a[0])/distance, (b[1]-a[1])/distance
        for i in range(count):
            t = i/count
            inset = 75+65*math.sin(i*1.39+seed+edge)+35*math.sin(i*.71+edge)
            inset *= math.sin(math.pi*t)**.5
            result.append((a[0]+(b[0]-a[0])*t-dy*inset, a[1]+(b[1]-a[1])*t+dx*inset))
    return Polygon(result)


class Authoring:
    def __init__(self, original, serial, profile):
        self.d = copy.deepcopy(original)
        self.old = original
        self.serial = serial
        self.family = self.d.get('family', 'aden')
        self.w, self.h = self.d['bounds'][2:]
        self.cell = self.d['navigation']['cell_size']
        self.clearance = self.d['navigation']['clearance']
        self.spawns = profile.get('monster_spawn', original['monster_spawn'])
        self.replaced = []
        self.groups = []
        self.probes = []
        self.start_props = len(self.d['props'])
        self.protected = [(original['spawn_position'], 150)]
        self.protected += [(v['position'], 155) for v in original['portal']+original['npc_spawn']]
        self.protected += [(p, 100) for p in original['route_checks']]
        for p in original['portal']:
            if p.get('target_map') == original['map_id'] and p.get('target_position'):
                self.protected.append((p['target_position'], 150))
        self.safe = []
        for r in original['regions']:
            if r['type'] == 'safe':
                self.safe.append(Polygon(r['polygon']) if r.get('polygon') else Point(r['center']).buffer(r['radius']))
        self.protection = unary_union([Point(p).buffer(r) for p, r in self.protected]+self.safe)
        dense_areas=[]
        for spawn in self.spawns:
            if spawn.get('mode')!='dense':continue
            x,y,w,h=spawn['rect']
            area=Polygon(spawn['polygon']) if spawn.get('polygon') else box(x,y,x+w,y+h)
            dense_areas.append(area.buffer(self.clearance+float(spawn.get('min_spacing',28))))
        if dense_areas:self.protection=unary_union([self.protection]+dense_areas)
        if original['roads']:
            # Keep a continuous 140px trunk route through each existing door.
            # Hunting rows can branch on either side, but cannot seal a room.
            self.protection=unary_union([self.protection]+[LineString(r['points']).buffer(70) for r in original['roads']])

    def add_polygon(self, poly, kind, id):
        for n, p in enumerate(polygons(make_valid(poly))):
            if p.area > 24:
                self.d['collision'].append({'shape':'polygon', 'kind':kind, 'points':points(p.exterior),
                    'id':f'{id}_{n}', 'placement_group':GROUP})

    def add_boundary(self, ring, id, width=34):
        # A polygon cannot store holes in this collision schema. Emit narrow
        # edge strips instead of accidentally filling an entire closed ring.
        coords=list(ring)
        for i,(a,b) in enumerate(zip(coords,coords[1:])):
            self.add_polygon(LineString([a,b]).buffer(width,cap_style=2),
                'terrain_boundary',f'{id}_{i}')

    def edge_props(self, ring, spacing, kind='rocks', scale=1.8):
        line = LineString(ring)
        for i in range(math.ceil(line.length/spacing)):
            p = line.interpolate(i*spacing)
            if self.protection.distance(p) < 25:
                continue
            self.d['props'].append({'kind':kind, 'position':[round(p.x,2),round(p.y,2)],
                'scale':round(scale*(.9+.1*math.sin(i*1.73)),3), 'flip':bool(i%2),
                'placement_group':GROUP, 'boundary_dressing':True,
                'texture_style':'aden_original' if self.family=='aden' else 'reference'})

    def boundaries(self):
        if self.family in ('oman', 'faith', 'albino') and self.d['map_id'] != 'oman_01':
            floor = unary_union([box(s['rect'][0], s['rect'][1], s['rect'][0]+s['rect'][2], s['rect'][1]+s['rect'][3])
                if 'rect' in s else Polygon(s['polygon']) for s in self.d['surfaces']])
            # Chamfer stone rooms; round rock caves. Doors remain >=384 wide.
            radius = 125 if self.family=='albino' else 90
            floor = floor.buffer(-radius, join_style=2).buffer(radius, quad_segs=3)
            if self.family=='albino':
                # Different saved cave lobes remain. Rounded concave and convex
                # corners replace the old 64px staircase wall complement.
                floor = floor.buffer(45, quad_segs=3)
            removed = [c for c in self.d['collision'] if c['kind']=='dungeon_wall']
            self.replaced.extend(removed)
            self.d['collision'] = [c for c in self.d['collision'] if c['kind']!='dungeon_wall']
            self.d['world_geometry'] = {'void_color':'10121a' if self.family!='albino' else '0d171c',
                'floor_material':self.d['background']['base_material'], 'terrain_zones':[],
                'boundary_height':110 if self.family=='albino' else 88,
                'verification':'authored_boundary_on_existing_room_connectivity'}
            self.d['navigable_polygons'] = [points(p.exterior) for p in polygons(floor)]
            for n, p in enumerate(polygons(floor)):
                self.add_boundary(p.exterior.coords, f'edge_{n}')
                self.edge_props(p.exterior.coords, 175 if self.family=='albino' else 245,
                    'rocks' if self.family=='albino' else 'wall', 1.8 if self.family=='albino' else 1.25)
                for k, hole in enumerate(p.interiors):
                    self.add_polygon(Polygon(hole), 'dungeon_pit', f'void_{n}_{k}')
                    self.add_boundary(hole.coords, f'inner_edge_{n}_{k}')
                    self.edge_props(hole.coords, 185 if self.family=='albino' else 245,
                        'rocks' if self.family=='albino' else 'wall', 1.7 if self.family=='albino' else 1.25)
        elif self.family in ('escaros','domination'):
            floor = jagged_rectangle(self.w, self.h, self.serial)
            for c in self.d['collision']:
                if c['kind'] in ('cliff','dungeon_wall'):
                    self.replaced.append(c)
            self.d['collision'] = [c for c in self.d['collision'] if c['kind'] not in ('cliff','dungeon_wall')]
            self.d['navigable_polygons'] = [points(floor.exterior)]
            self.d['world_geometry'] = {'void_color':'12181b','floor_material':self.d['background']['base_material'],
                'terrain_zones':[], 'boundary_height':125 if self.family=='escaros' else 95,
                'verification':'authored_jagged_perimeter_existing_bounds'}
            self.add_boundary(floor.exterior.coords,'outer_edge',40)
            self.edge_props(floor.exterior.coords,190,'rocks',2.25)
        elif self.family=='aden':
            floor = unary_union([Polygon(p) for p in self.d['navigable_polygons']])
            old = [c for c in self.d['collision'] if c['kind']=='cliff' and c['shape']=='rect']
            self.replaced.extend(old)
            self.d['collision'] = [c for c in self.d['collision'] if c not in old]
            roads = unary_union([LineString(r['points']).buffer(r['width']*.5+165) for r in self.d['roads']])
            for n, c in enumerate(old):
                x,y,w,h=c['rect']
                a,b = ((x,y+h*.5),(x+w,y+h*.5)) if w>h else ((x+w*.5,y),(x+w*.5,y+h))
                distance=math.dist(a,b); dx,dy=(b[0]-a[0])/distance,(b[1]-a[1])/distance
                pts=[]
                for i in range(math.ceil(distance/180)+1):
                    t=min(1,i*180/distance)
                    offset=75*math.sin(i*.58+n)+30*math.sin(i*1.79)
                    pts.append((a[0]+(b[0]-a[0])*t-dy*offset,a[1]+(b[1]-a[1])*t+dx*offset))
                ridge=LineString(pts).buffer(50,quad_segs=2).intersection(floor).difference(roads).difference(self.protection)
                self.add_polygon(ridge,'terrain_boundary',f'aden_ridge_{n}')
                for component in polygons(ridge):
                    self.edge_props(component.exterior.coords,145,'rocks',2.15)
            self.d['world_geometry']['boundary_height']=100
        else:
            floor=unary_union([Polygon(p) for p in self.d['navigable_polygons']])
            # Keep the referenced first-floor contour and pits unchanged.
            for p in polygons(floor):
                self.edge_props(p.exterior.coords,195,'rocks',1.4)
        self.floor=floor
        self.floor_inside=floor.buffer(-self.clearance)
        self.existing=unary_union([shape(c,5) for c in self.d['collision']])

    def offer_chain(self, pts, kind, radius, sector, serial):
        line=LineString(pts)
        spacing=radius*1.45
        offered=[]
        n=math.ceil(line.length/spacing)
        for i in range(n+1):
            p=line.interpolate(line.length*i/n)
            if not self.floor_inside.contains(p) or self.protection.distance(p)<radius+30:
                continue
            if self.existing.contains(p):
                continue
            offered.append([round(p.x,2),round(p.y,2)])
        if len(offered)<3:
            return
        group=f'{sector}_lane_{serial}'
        before=len(self.d['collision'])
        for i, p in enumerate(offered):
            asset_kind=kind
            if self.family=='aden' and kind in ('oak','pine'):
                asset_kind=[kind,'bush',kind,'oak2'][i%4] if kind=='oak' else [kind,'rocks',kind,'pine'][i%4]
            elif self.family=='albino' and i%5==1:
                asset_kind='crystal'
            elif self.family=='faith' and i%5==0:
                asset_kind='pillar'
            id=f'{self.d["map_id"]}_{group}_{i}'
            scale=1.15 if asset_kind in ('oak','oak2','pine') else (1.8 if asset_kind in ('rocks','rock','crystal') else 1.22)
            prop={'kind':asset_kind,'position':p,'scale':scale,'flip':bool((i+self.serial)%2),
                'id':id,'placement_group':GROUP,'hunting_lane':group}
            if self.family=='aden' or asset_kind=='bush': prop['texture_style']='aden_original'
            self.d['props'].append(prop)
            self.d['collision'].append({'shape':'circle','kind':asset_kind,'center':p,'radius':radius,
                'id':id,'placement_group':GROUP,'hunting_lane':group})
        self.groups.append({'id':group,'sector':sector,'object_kind':kind,'points':pts,
            'radius':radius,'object_count':len(self.d['collision'])-before})

    def hunting_lanes(self):
        for index,s in enumerate(self.spawns):
            if s.get('mode') in ('boss','dense') or 'boss' in s['id']:
                continue
            x,y,w,h=s['rect']; cx,cy=x+w*.5,y+h*.5
            size=min(w,h)
            # Hunting spawn rectangles cover only the centre of larger halls.
            # Fit partition lengths to the actual room, not just that rectangle.
            if self.family in ('oman','faith','albino') and self.d['map_id']!='oman_01':
                for surface in self.d['surfaces']:
                    if 'rect' not in surface: continue
                    a,b,sw,sh=surface['rect']
                    if a<=cx<=a+sw and b<=cy<=b+sh and 900<=min(sw,sh)<=2000:
                        size=max(size,min(sw,sh)-180)
            radius=58 if size<1300 else 76
            reach=min(size*.43,850)
            offset=min(size*.255,450)
            gap=max(220,size*.22)
            rotation=(self.serial+index)%4
            def transform(pt):
                a,b=pt
                for _ in range(rotation): a,b=-b,a
                return [round(cx+a,2),round(cy+b,2)]
            # Opposing L-shaped partitions produce a real S-route with alternate
            # entrances. Rows end before room doors; never close a combat arena.
            segments=[ [(-reach,-offset),(reach-gap,-offset),(reach-gap,-30)],
                       [(reach,offset),(-reach+gap,offset),(-reach+gap,30)] ]
            if self.family=='albino':
                segments=[ [(-reach,-offset),(-reach*.4,-offset-60),(reach*.2,-offset+45),(reach-gap,-40)],
                           [(reach,offset),(reach*.4,offset+65),(-reach*.25,offset-45),(-reach+gap,35)] ]
            if self.family=='aden':
                kind='rocks' if any(v in s['id'] for v in ('desert','dragon','ruins','fire')) else ('pine' if 'oren' in s['id'] else 'oak')
            elif self.family=='albino':kind='rocks'
            elif self.family=='escaros':kind='rocks' if self.serial%2 else 'wall'
            else:kind='wall'
            for serial,pts in enumerate(segments):
                self.offer_chain([transform(p) for p in pts],kind,radius,s['id'],serial)

    def grid(self):
        h,w=math.ceil(self.h/self.cell),math.ceil(self.w/self.cell)
        yy,xx=np.mgrid[:h,:w]
        xx=(xx+.5)*self.cell;yy=(yy+.5)*self.cell
        floor=contains_xy(self.floor,xx,yy)
        obstacles=unary_union([shape(c,self.clearance) for c in self.d['collision']])
        clear=floor & ~contains_xy(obstacles,xx,yy)
        labels,_=label(clear)
        sx,sy=self.old['spawn_position']
        start=labels[int(sy//self.cell),int(sx//self.cell)]
        if start==0: raise RuntimeError(f'{self.d["map_id"]}: blocked entry')
        reach=labels==start
        return xx,yy,clear,reach,labels

    def validate(self):
        xx,yy,clear,reachable,labels=self.grid()
        failures=[]
        for p,r in self.protected:
            x,y=p; ix,iy=int(x//self.cell),int(y//self.cell)
            if not reachable[iy,ix]: failures.append(p)
        counts={}
        for s in self.spawns:
            x,y,w,h=s['rect']
            poly=Polygon(s['polygon']) if s.get('polygon') else box(x,y,x+w,y+h)
            cells=reachable & contains_xy(poly,xx,yy)
            for safe in self.safe: cells &= ~contains_xy(safe,xx,yy)
            counts[s['id']]=int(cells.sum())
            minimum=int(s['max_count']) if s.get('mode')=='dense' else 1
            if counts[s['id']]<minimum: failures.append(s['id'])
        if failures:
            raise RuntimeError(f'{self.d["map_id"]}: disconnected landmarks/spawns {failures}')
        # Probe actual solid row midpoints, not a cosmetic line descriptor.
        grouped=collections.defaultdict(list)
        for c in self.d['collision']:
            if c.get('hunting_lane'):grouped[c['hunting_lane']].append(c)
        for group in self.groups:
            chain=grouped[group['id']]
            for c in chain[2:-2]:
                p=c['center'];r=c['radius']
                for dx,dy in [(0,1),(1,0)]:
                    distance=r+self.clearance+80
                    a=[p[0]-dx*distance,p[1]-dy*distance]
                    b=[p[0]+dx*distance,p[1]+dy*distance]
                    ax,ay=int(a[0]//self.cell),int(a[1]//self.cell)
                    bx,by=int(b[0]//self.cell),int(b[1]//self.cell)
                    if min(ax,ay,bx,by)<0 or max(ax,bx)>=clear.shape[1] or max(ay,by)>=clear.shape[0]: continue
                    if reachable[ay,ax] and reachable[by,bx]:
                        self.probes.append({'lane':group['id'],'from':a,'to':b,'blocker_id':c['id']})
                        break
                if self.probes and self.probes[-1]['lane']==group['id']:break
        if not self.probes:raise RuntimeError(f'{self.d["map_id"]}: no real obstacle detour probe')
        return {'walkable_cells':int(clear.sum()),'reachable_cells':int(reachable.sum()),'spawn_cells':counts,
            'protected_landmarks':len(self.protected),'detour_probes':len(self.probes)}

    def finish(self):
        self.boundaries()
        self.hunting_lanes()
        checks=self.validate()
        self.d['hunting_paths']={'version':1,'baseline_sha':BASELINE,'verification':'reference_style_local_approximation',
            'source_reference':REFERENCES[self.family], 'lanes':self.groups,'detour_probes':self.probes,
            'boundary_revision':1,'preserved_original_props':self.start_props}
        # Preserve exact replaced boundary data for review, rollback and resumed work.
        return self.d,{'map_id':self.d['map_id'],'family':self.family,'baseline_sha':BASELINE,
            'before_props':self.start_props,'after_props':len(self.d['props']),
            'replaced_boundary_colliders':self.replaced,'lane_count':len(self.groups),
            'navigation_authoring_check':checks}


def main():
    index=json.loads((ROOT/'data/maps/field_index.json').read_text())
    paths=[ROOT/'data/maps/aden_field.json']+[ROOT/e['path'].removeprefix('res://') for e in index]
    profiles=json.loads((ROOT/'data/monsters/world_spawn_profiles.json').read_text())['maps']
    reports=[]; results=[]
    for serial,path in enumerate(paths):
        original=json.loads(path.read_text())
        if original.get('hunting_paths',{}).get('version'):
            raise SystemExit(f'{path.name}: already applied; do not repeat this pass')
        d,report=Authoring(original,serial,profiles.get(original['map_id'],{})).finish()
        results.append((path,d));reports.append(report)
        print(d['map_id'],report['before_props'],'->',report['after_props'], 'lanes',report['lane_count'],
            'reachable',report['navigation_authoring_check']['reachable_cells'],flush=True)
    # All-or-nothing source writes after every authoring connectivity check passes.
    for path,d in results:path.write_text(json.dumps(d,ensure_ascii=False,separators=(',',':'))+'\n')
    out=ROOT/'docs/hunting-paths-20261012'
    out.mkdir(parents=True,exist_ok=True)
    (out/'authoring-ledger.json').write_text(json.dumps({'baseline_sha':BASELINE,'maps':reports},ensure_ascii=False,indent=2)+'\n')
    print('HUNTING_AUTHORING_OK',len(results))


if __name__=='__main__': main()
