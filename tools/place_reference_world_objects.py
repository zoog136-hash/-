"""Place existing TWILIGHT art on the saved Aden/Oman geography.

Public screenshots establish composition, not original client object coordinates.
Never creates, edits or downloads art. Existing objects are retained; foliage
relocations include their matching colliders and an explicit before/after ledger.
"""
import collections
import copy
import hashlib
import json
import math
import random
from pathlib import Path

from build_reference_world_structure import TOWNS, inside, box

ROOT = Path(__file__).resolve().parents[1]
BASELINE = "21ac99ee9ae0833dccafa4abf9920927a0df0e55"
GROUP = "reference_object_pass_1"
REFERENCES = {
    "giran_plaza": "https://lineagem.plaync.com/board/free/view?articleId=65143adae08a821fd62f20c9",
    "giran_shop": "https://www.inven.co.kr/webzine/news/?news=263550&site=lineagem",
    "oman_rail": "https://www.inven.co.kr/board/lineagem/5056/12423",
    "continent": "https://games.app-liv.jp/archives/397568",
    "oman_floor": "https://www.gamechosun.co.kr/webzine/article/view.php?no=145842",
}

# District compositions differ deliberately. Numbers are TWILIGHT offsets,
# not recovered M object coordinates. The existing buildings are kept as well.
# Every offer is checked against coast/water/old obstacles, roads and services.
TOWN_BLOCKS = {
 "gludio": {
  "house":[(-80,-760),(380,-490),(820,-150),(880,440),(430,690),(-140,680),(-760,160)],
  "market":[(180,-310),(-280,190),(650,460)],
  "crates":[(540,600),(-650,490)],"oak":[(-730,-660),(840,720)],
 },
 "kent": {
  "house":[(-590,-330),(-190,-530),(230,-510),(630,-220),(580,380),(170,590),(-520,400)],
  "market":[(-310,-180),(330,190)],"tower":[(-720,180),(620,-510)],
  "wall":[(-460,-630),(-220,-670),(20,-660),(280,-630),(-710,-90),(660,40)],
 },
 "giran": {
  "house":[(-660,-320),(-320,-550),(100,-540),(490,-400),(710,-30),(650,490),(-610,470),(-760,80)],
  "market":[(-350,-170),(-40,-330),(310,-180),(470,180),(-370,290)],
  "pillar":[(-270,90)],"bush":[(-40,210),(180,230),(-170,430),(410,410)],
  "crates":[(-500,-110),(410,-160)],
 },
 "aden": {
  "house":[(-720,-340),(-350,-640),(130,-620),(630,-300),(700,300),(350,650),(-200,650),(-680,310)],
  "tower":[(-570,-470),(540,-470),(-560,510),(540,510)],
  "wall":[(-340,-530),(-140,-530),(80,-530),(310,-530),(-740,-40),(740,40),(-300,590),(250,590)],
  "statue":[(-230,80),(260,180)],"market":[(-390,250),(400,290)],
 },
 "heine": {
  "house":[(-660,-210),(-340,-510),(100,-540),(550,-330),(710,170),(330,510),(-180,520),(-600,330)],
  "market":[(-250,-200),(390,120),(50,370)],
  "wall":[(-770,80),(710,450)],"bush":[(-380,70),(250,-230),(490,390)],
  "crates":[(-700,400),(540,580)],
 },
 "oren": {
  "house":[(-550,-250),(-130,-470),(330,-330),(540,130),(110,500),(-500,320)],
  "market":[(-220,140)],"pine":[(-720,-470),(630,-560),(-690,520),(680,460)],
  "rocks":[(-740,-160),(620,690)],
 },
 "weldan": {
  "house":[(-550,-300),(-130,-470),(320,-400),(620,120),(180,510),(-540,330)],
  "market":[(-230,200),(380,350)],"rocks":[(-770,-530),(630,-600),(-800,540)],
  "crates":[(500,500),(-420,-90)],
 },
 "windawood": {
  "house":[(-450,-320),(170,-460),(540,-90),(-410,440),(200,560)],
  "tower":[(-650,-440),(620,430)],
  "wall":[(-390,-550),(-150,-580),(80,-570),(410,550),(-640,40)],
  "market":[(280,270)],"statue":[(-200,150)],
 },
 "silver_knight": {
  "house":[(-610,-300),(-180,-530),(270,-410),(640,90),(350,510),(-500,410)],
  "market":[(-300,160)],"tower":[(600,-440)],
  "wall":[(-430,-650),(-220,-690),(30,-660),(-740,90),(600,490)],
  "statue":[(190,120)],"oak":[(-770,620)],
 },
 "fire_village": {
  "house":[(-420,-250),(170,-420),(450,130),(-340,430)],
  "market":[(-240,150)],"crates":[(530,350)],
  "oak":[(-700,-490),(650,-310),(-650,550),(690,520)],
 },
 "elf_village": {
  "house":[(-430,-280),(380,-300),(-470,440)],
  "market":[(340,300)],"oak":[(-660,-500),(30,-700),(670,-110),(-680,170),(600,550)],
  "bush":[(-280,130),(240,-60),(30,440)],"statue":[(-180,-160)],
 },
}

def sha(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()

def segment_distance(p, a, b):
    dx,dy=b[0]-a[0],b[1]-a[1]
    t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dy)/max(1,dx*dx+dy*dy)))
    return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dy)

def shape_contains(p, c, pad):
    if c['shape']=='circle': return math.dist(p,c['center'])<=c['radius']+pad
    if c['shape']=='rect':
        x,y,w,h=c['rect'];return x-pad<=p[0]<=x+w+pad and y-pad<=p[1]<=y+h+pad
    pts=c['points']
    return inside(p,pts) or any(segment_distance(p,a,b)<=pad for a,b in zip(pts,pts[1:]+pts[:1]))

class Placement:
    def __init__(self, definition):
        self.d=copy.deepcopy(definition)
        if definition['map_id']=='aden_world':
            for npc in self.d['npc_spawn']:
                if npc['id']=='warehouse_keeper':npc['position']=[10460,16100]
                if npc['id']=='teleport_guide':npc['position']=[10830,16460]
                if npc['id']=='craft_artisan':npc['position']=[10650,16600]
            # Reuse existing service actors near the Giran plaza observed in
            # the reference. Roles work; original M NPC coordinates are unknown.
            for id,name,role,pos in [
                ('giran_shop','기란 잡화 상인','shop',[25610,9070]),
                ('giran_warehouse','기란 창고지기','warehouse',[26070,9090]),
                ('giran_teleport','기란 이동 안내인','teleport',[26040,9440])]:
                self.d['npc_spawn'].append({'id':id,'name':name,'role':role,'position':pos,
                    'placement_group':GROUP,'placement_verification':'reference_composition_local_approximation'})
        else:
            for npc in self.d['npc_spawn']:
                if npc['id']=='guide':npc['position']=[3008,3296]
        self.rng=random.Random(841102)
        self.initial_props=copy.deepcopy(definition['props'])
        self.initial_collision=copy.deepcopy(definition['collision'])
        self.buckets=collections.defaultdict(list)
        self.offers=collections.Counter()
        self.accepted=collections.Counter()
        self.protected=[(definition['spawn_position'],105)]
        self.protected.extend((r['position'],125) for r in self.d['portal']+self.d['npc_spawn'])
        self.protected.extend((p,90) for p in definition['route_checks'])
        self.road_segments=[(a,b,r['width']/2) for r in definition['roads'] for a,b in zip(r['points'],r['points'][1:])]
        for c in self.d['collision']: self.index(c)
        self.relocations=[]
        if definition['map_id']=='aden_world':self.relocate_town_foliage()

    def relocate_town_foliage(self):
        # Former small-map clusters now sit across some new town plots. Move
        # those same objects and their exact trunk/rock colliders to the fringe;
        # do not destroy them or place houses through them.
        matching=collections.defaultdict(list)
        for c in self.d['collision']:
            if c['shape']=='circle':matching[c['kind'],tuple(c['center'])].append(c)
        natural={'oak','oak2','birch','pine','grass','bush','rocks','rock'}
        for index,r in enumerate(self.d['props']):
            if r['kind'] not in natural:continue
            old=r['position']
            towns=[(id,[v*40 for v in pos]) for id,(_,pos) in TOWNS.items()
                   if id not in ['elf_village','fire_village']]
            district,center=min(towns,key=lambda t:math.dist(old,t[1]))
            if ((old[0]-center[0])/850)**2+((old[1]-center[1])/680)**2>=1:continue
            # Irregular corner groves, not a ring around each settlement.
            found=None
            for attempt in range(140):
                sx,sy=self.rng.choice([(-1,-1),(1,-1),(-1,1),(1,1)])
                pt=[round(center[0]+sx*self.rng.uniform(1050,1950),2),
                    round(center[1]+sy*self.rng.uniform(850,1500),2)]
                if any(math.dist(pt,c)<radius+80 for c,radius in self.protected):continue
                if any(segment_distance(pt,a,b)<w+100 for a,b,w in self.road_segments):continue
                if self.clear(pt,65):found=pt;break
            if found is None:continue
            for c in matching.get((r['kind'],tuple(old)),[]):
                c['center']=found[:];self.index(c)
            r['position']=found
            self.relocations.append({'index':index,'kind':r['kind'],'from':old,'to':found,'district':district})

    def index(self,c):
        if c['shape']=='circle':
            x,y=c['center'];r=c['radius'];bb=[x-r,y-r,r*2,r*2]
        else: bb=c['rect'] if c['shape']=='rect' else box(c['points'])
        x,y,w,h=bb
        for by in range(math.floor(y/1024),math.floor((y+h)/1024)+1):
            for bx in range(math.floor(x/1024),math.floor((x+w)/1024)+1):self.buckets[bx,by].append(c)

    def clear(self,p,pad):
        if not any(inside(p,poly) for poly in self.d['navigable_polygons']):return False
        for by in range(math.floor((p[1]-pad)/1024),math.floor((p[1]+pad)/1024)+1):
            for bx in range(math.floor((p[0]-pad)/1024),math.floor((p[0]+pad)/1024)+1):
                if any(shape_contains(p,c,pad) for c in self.buckets[bx,by]):return False
        return True

    def add(self,kind,p,scale,area,style='reference',rail=False):
        self.offers[area]+=1
        p=[round(v,2) for v in p];scale=round(scale,3)
        half={'house':110,'tower':75,'market':88,'wall':90,'crates':32,'pillar':25,'statue':33,'bush':35}.get(kind,20)*scale
        if any(math.dist(p,c)<r+half for c,r in self.protected):return False
        lane_margin=15 if kind=='bush' else 50
        if any(segment_distance(p,a,b)<w+half+lane_margin for a,b,w in self.road_segments):return False
        if not rail and not self.clear(p,half+22):return False
        if rail and not any(inside(p,poly) for poly in self.d['navigable_polygons']):return False
        id=f"{self.d['map_id']}/{area}/{self.accepted[area]:04d}"
        r={'kind':kind,'position':p,'scale':scale,'flip':bool(self.rng.randrange(2)),
           'placement_group':GROUP,'placement_id':id,'district':area,'texture_style':style,
           'placement_verification':'reference_composition_local_approximation'}
        c=None
        if kind in ['house','tower','market','wall','crates','statue','bush']:
            depth={'house':70,'tower':70,'market':55,'wall':25,'crates':30,'statue':30,'bush':22}[kind]*scale
            c={'shape':'rect','rect':[round(p[0]-half,2),round(p[1]-depth,2),round(half*2,2),round(depth,2)],
               'kind':'building' if kind in ['house','market'] else kind}
            access=[p[0],round(p[1]+80*scale,2)]
            if not rail and not self.clear(access,55):return False
            if kind in ['house','market']:r['access_point']=access
        elif kind in ['oak','oak2','birch','pine','rocks','rock','pillar']:
            radius=(20 if kind in ['oak','oak2','birch','pine'] else (35 if kind in ['rock','rocks'] else 20))*scale
            c={'shape':'circle','center':p,'radius':round(radius,2),'kind':kind}
        if c:
            c.update(placement_group=GROUP,placement_id=id)
            self.d['collision'].append(c);self.index(c)
        self.d['props'].append(r);self.accepted[area]+=1
        if 'access_point' in r:self.protected.append((r['access_point'],90))
        return True

    def finish(self):
        moved={r['index'] for r in self.relocations}
        for i,(before,after) in enumerate(zip(self.initial_props,self.d['props'])):
            expected=copy.deepcopy(before)
            if i in moved:expected['position']=after['position']
            assert expected==after
        assert len(self.d['props'])>=len(self.initial_props)
        assert len(self.d['collision'])>=len(self.initial_collision)
        self.d['object_layout_version']=1
        self.d['object_layout_reference']={'baseline':BASELINE,'references':REFERENCES,
            'verification_status':'reference_composition_not_exact_original_object_coordinates',
            'new_art_files':0,'preserved_props':len(self.initial_props),'preserved_prop_sha256':sha(self.initial_props),
            'relocated_existing_props':self.relocations,
            'districts':dict(self.accepted),'attempted':dict(self.offers)}
        return self.d

def aden_objects(d):
    p=Placement(d)
    for town,blocks in TOWN_BLOCKS.items():
        center=[v*40 for v in TOWNS[town][1]]
        for kind,offsets in blocks.items():
            for i,(x,y) in enumerate(offsets):
                scale={'house':1.25,'market':1.12,'tower':1.45,'wall':1.25,'bush':1.6}.get(kind,1.05)
                style='aden_original' if town in ['weldan','windawood','fire_village','elf_village'] or (kind=='house' and i%3==0) else 'reference'
                base=[center[0]+x,center[1]+y]
                # Resolve small conflicts with old footprints while retaining
                # the proposed side of the plaza and the district composition.
                for dx,dy in [(0,0),(0,180),(-180,0),(180,0),(0,-180),(-150,150),(150,150),(-150,-150),(150,-150)]:
                    if p.add(kind,[base[0]+dx,base[1]+dy],scale,town,style):break
        # Larger groves at the village fringe, with streets/service NPCs clear.
        if town in ['elf_village','fire_village','oren','silver_knight']:
            for i in range(45):
                angle=p.rng.uniform(0,math.tau);dist=p.rng.uniform(760,1350)
                p.add('pine' if town=='oren' else p.rng.choice(['oak','oak2','birch']),
                      [center[0]+math.cos(angle)*dist,center[1]+math.sin(angle)*dist],p.rng.uniform(.9,1.3),town,'aden_original')
    # Clustered forest canopies follow the saved geographic polygons. They are
    # not a repeated green backdrop, and all trunks have movement footprints.
    for zone in d['world_geometry']['terrain_zones']:
        id=zone['id'];poly=zone['polygon'];x,y,w,h=box(poly)
        forest='forest' in id;wet=id=='heine_wetlands'
        spacing=230 if forest else (310 if wet else 440)
        for yy in range(int(y),int(y+h),spacing):
            for xx in range(int(x),int(x+w),spacing):
                pt=[xx+p.rng.uniform(-spacing*.42,spacing*.42),yy+p.rng.uniform(-spacing*.42,spacing*.42)]
                if not inside(pt,poly):continue
                if any(math.dist(pt,[v*40 for v in pos])<1300 for _,pos in TOWNS.values()):continue
                modulation=(math.sin(pt[0]/790)+math.cos(pt[1]/630)+math.sin((pt[0]+pt[1])/1150))/3
                if forest or wet:
                    if modulation<-.48 or p.rng.random()<(.12 if forest else .28):continue
                    kind=p.rng.choice(['oak','oak2','birch'] if not wet else ['birch','oak2','bush'])
                    scale=p.rng.uniform(.95,1.45) if kind!='bush' else p.rng.uniform(1.1,1.8)
                    style='reference' if kind in ['oak','oak2'] else 'aden_original'
                elif id in ['dragon_valley','twilight_mountains','western_hills','fire_land']:
                    if modulation<-.2 or p.rng.random()<.25:continue
                    kind=p.rng.choice(['rocks','rock']);scale=p.rng.uniform(1.2,2.35)
                    style='aden_original' if id=='western_hills' else 'reference'
                elif id=='oren_snow':
                    if modulation<-.1 or p.rng.random()<.25:continue
                    kind='pine';scale=p.rng.uniform(.9,1.35);style='aden_original'
                else:
                    if p.rng.random()<.78:continue
                    kind='rock';scale=p.rng.uniform(.7,1.1);style='aden_original'
                p.add(kind,pt,scale,id,style)
    # Use existing low plants along the actual river banks, not across water.
    for river in d['water']:
        pts=river['polygon'];n=len(pts)//2
        for bank in [pts[:n],pts[n:][::-1]]:
            for a,b in zip(bank,bank[1:]):
                length=math.dist(a,b);count=max(1,int(length/310))
                for i in range(count):
                    t=(i+.5)/count;dx,dy=b[0]-a[0],b[1]-a[1]
                    for sign in [-1,1]:
                        pt=[a[0]+dx*t-dy/max(1,length)*sign*120,a[1]+dy*t+dx/max(1,length)*sign*120]
                        p.add('bush',pt,p.rng.uniform(.8,1.2),'river_banks','aden_original')
    return p.finish()

def oman_objects(d):
    p=Placement(d);poly=d['navigable_polygons'][0];center=[4800,2480]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        length=math.dist(a,b);count=max(1,math.ceil(length/205))
        for i in range(count):
            t=(i+.5)/count;pt=[a[j]+(b[j]-a[j])*t for j in range(2)]
            direction=[center[j]-pt[j] for j in range(2)];mag=math.hypot(*direction)
            pt=[pt[j]+direction[j]/max(1,mag)*26 for j in range(2)]
            # Existing masonry/column sprites approximate the rail silhouette;
            # there is no suitable iron-rail sprite in the available atlases.
            kind='pillar' if i%4==0 else 'wall'
            p.add(kind,pt,.9 if kind=='pillar' else 1.1,'perimeter','aden_original',rail=True)
            if i%7==2:
                inward=[pt[j]+direction[j]/max(1,mag)*95 for j in range(2)]
                p.add('torch',inward,.8,'perimeter_lights',rail=True)
    for pit in [c for c in d['collision'] if c['kind']=='dungeon_pit']:
        x,y,w,h=box(pit['points'])
        for dx,dy in [(-80,20),(w+90,0),(w/2,h+100)]:
            p.add('rocks',[x+dx,y+dy],.8,'pit_edges','aden_original')
    # Open floor remains open; only modest old rubble at edge stations.
    for i in range(70):
        a=poly[i%len(poly)];delta=[center[j]-a[j] for j in range(2)];mag=math.hypot(*delta)
        pt=[a[j]+delta[j]/max(1,mag)*p.rng.uniform(180,410) for j in range(2)]
        p.add('rubble',pt,p.rng.uniform(.65,1.0),'edge_debris')
    return p.finish()

def main():
    files={'aden_field':aden_objects,'oman_01':oman_objects}
    report={'baseline_sha':BASELINE,'new_art_files':0,'references':REFERENCES,'maps':[]}
    for name,build in files.items():
        path=ROOT/'data/maps'/f'{name}.json';old=json.loads(path.read_text())
        assert old['layout_revision']==3 and not old.get('object_layout_version'), 'Already placed: preserve the saved pass and use a new version.'
        new=build(old)
        path.write_text(json.dumps(new,ensure_ascii=False,separators=(',',':'))+'\n')
        report['maps'].append({'map_id':new['map_id'],'preserved_props':len(old['props']),'new_props':len(new['props'])-len(old['props']),
            'relocated_existing_props':len(new['object_layout_reference']['relocated_existing_props']),
            'preserved_collision':len(old['collision']),'new_collision':len(new['collision'])-len(old['collision']),
            'new_service_npcs':len(new['npc_spawn'])-len(old['npc_spawn']),
            'kinds':dict(collections.Counter(r['kind'] for r in new['props'][len(old['props']):])),
            'districts':new['object_layout_reference']['districts'],'verification_status':new['object_layout_reference']['verification_status']})
    target=ROOT/'data/maps/reference_object_placement.json'
    target.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
