"""Reproducible authored field; all coordinates are Godot world pixels, feet at origin.

Generates data only. Art remains independent and navigation/physics consume the
same blocker geometry at runtime. Existing maps_v18.json is intentionally retained.
"""
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
rng = random.Random(7082026)
W, H = 12288, 8192
props, blockers = [], []

def rect(x, y, w, h, kind='wall'):
    shape = {'shape': 'rect', 'rect': [x, y, w, h], 'kind': kind}
    blockers.append(shape)
    return shape

def prop(kind, x, y, scale=1.0, radius=0, **kw):
    item = {'kind': kind, 'position': [round(x, 1), round(y, 1)],
            'scale': round(scale, 3), 'flip': rng.random() < .5, **kw}
    props.append(item)
    if radius:
        blockers.append({'shape': 'circle', 'center': item['position'],
                         'radius': round(radius * scale, 1), 'kind': kind})
    return item

def river_x(y):
    return 6000 + 290 * math.sin(y / 1300) + 110 * math.sin(y / 460)

roads = [
    {'id':'kingroad', 'width':210, 'material':1, 'points':[[600,4100],[1600,4100],[2700,4100],[3650,3650],[4500,3050],[river_x(3000),3000],[7150,3000],[8000,3250],[9200,2600],[10700,1900]]},
    {'id':'southroad', 'width':168, 'material':1, 'points':[[2700,4100],[3550,5150],[4500,5700],[river_x(5700),5700],[7200,5700],[9000,6050],[10750,5400],[11300,4600]]},
    {'id':'forestroad', 'width':130, 'material':1, 'points':[[3650,3650],[3300,3000],[2900,2150],[3500,1200]]},
    {'id':'ruinroad', 'width':158, 'material':1, 'points':[[8000,3250],[8450,4300],[9000,6050]]},
]
bridges = []
for i, y in enumerate([3000, 5700]):
    x = river_x(y)
    bridges.append({'id':f'bridge_{i}', 'rect':[x-510,y-125,1020,250]})
    rect(x-510,y-132,1020,14,'bridge_rail')
    rect(x-510,y+118,1020,14,'bridge_rail')
water = []
for lo, hi in [(0,2875),(3125,5575),(5825,H)]:
    ys = [lo + (hi-lo)*i/32 for i in range(33)]
    poly = [[round(river_x(y)-235,1),round(y,1)] for y in ys]
    poly += [[round(river_x(y)+235,1),round(y,1)] for y in reversed(ys)]
    water.append({'polygon':poly})
    blockers.append({'shape':'polygon','points':poly,'kind':'water'})

# The playable border has a visible rock escarpment, never an invisible edge.
for r in [(0,0,W,96),(0,H-96,W,96),(0,96,96,H-192),(W-96,96,96,H-192)]:
    rect(*r,kind='cliff')

regions = [
    {'id':'town','name':'은빛 마을','type':'safe','center':[1580,4100],'radius':740,'color':'b5ac77'},
    {'id':'meadow','name':'은빛 초원','type':'combat','center':[3340,4380],'radius':1100,'color':'83925a'},
    {'id':'forest','name':'속삭이는 숲','type':'combat','center':[2900,2000],'radius':1350,'color':'4e6a4d'},
    {'id':'riverbank','name':'갈대 강변','type':'combat','center':[4550,6550],'radius':980,'color':'698889'},
    {'id':'ruins','name':'황혼의 폐허','type':'combat','center':[7940,2900],'radius':1050,'color':'969087'},
    {'id':'boss','name':'잊힌 왕의 언덕','type':'boss','center':[10500,1600],'radius':860,'color':'a88569'},
    {'id':'east','name':'동부 수호림','type':'combat','center':[9340,6200],'radius':1500,'color':'727e54'},
]
spawn_regions = [
    {'id':'meadow','rect':[2550,4220,1700,850], 'monster_types':['버그베어','고스트'], 'level':[3,5], 'max_count':14,'density':9.7,'respawn_time':18,'roaming_radius':170},
    {'id':'forest','rect':[1600,1300,2300,1500], 'monster_types':['늑대인간','오우거'], 'level':[10,14], 'max_count':20,'density':5.8,'respawn_time':24,'roaming_radius':220},
    {'id':'riverbank','rect':[3750,6100,1400,1000], 'monster_types':['거대 개미','킹버그베어'], 'level':[18,42], 'max_count':12,'density':8.6,'respawn_time':26,'roaming_radius':150},
    {'id':'ruins','rect':[7220,2100,1500,1400], 'monster_types':['스파토이','흑장로'], 'level':[5,32], 'max_count':16,'density':7.6,'respawn_time':28,'roaming_radius':180},
    {'id':'east','rect':[8300,5600,2100,1400], 'monster_types':['정예 다크엘프','다크엘프'], 'level':[52,58], 'max_count':18,'density':6.1,'respawn_time':32,'roaming_radius':220},
    {'id':'boss','rect':[10200,1330,520,510], 'monster_types':['드레이크'], 'level':[22,22], 'max_count':1,'density':3.8,'respawn_time':90,'roaming_radius':160},
]

def distance_segment(p,a,b):
    vx,vy=b[0]-a[0],b[1]-a[1]
    t=max(0,min(1,((p[0]-a[0])*vx+(p[1]-a[1])*vy)/(vx*vx+vy*vy)))
    return math.hypot(p[0]-a[0]-t*vx,p[1]-a[1]-t*vy)

def road_clear(x,y,pad=80):
    return all(distance_segment((x,y),a,b)>r['width']/2+pad for r in roads for a,b in zip(r['points'],r['points'][1:]))

def special_clear(x,y):
    # Reserve all landmarks, entrances and teleport landings before scatter.
    return all(math.hypot(x-a,y-b)>r for a,b,r in [(1600,4100,940),(7920,2790,650),(10500,1600,600),(10800,5400,400),(2100,4050,280)])

def clear_geometry(x,y,pad):
    for s in blockers:
        if s['shape']=='circle':
            if math.hypot(x-s['center'][0],y-s['center'][1])<s['radius']+pad:return False
        elif s['shape']=='rect':
            a,b,w,h=s['rect']
            if a-pad<x<a+w+pad and b-pad<y<b+h+pad:return False
    return abs(x-river_x(y))>310+pad

# Town buildings: feet anchored; rectangle matches the visible building base.
for x,y,s in [(1120,3710,1.35),(1630,3610,1.5),(1060,4510,1.2),(1660,4630,1.35)]:
    prop('house',x,y,s)
    rect(x-125*s,y-84*s,250*s,98*s,'building')
prop('market',1940,3740,1.3)
rect(1820,3670,240,95,'building')
prop('statue',1510,4010,.9,36)
prop('tower',2300,3870,1.5,92)
for x in range(780,2150,206):
    prop('wall',x,3410,1.05)
    rect(x-98,3380,196,46)
for x,y in [(960,3870),(1900,4650),(2090,3750),(1280,4580)]:prop('crates',x,y,.68,28)

# Ruin courtyard: gaps intentionally remain 190+ pixels wide.
for x,y,s in [(7500,2330,1.25),(8300,2330,1.1),(7500,3200,.85),(8350,3140,1.1)]:
    prop('pillar',x,y,s,40)
for x in [7660,7860,8060]:
    prop('wall',x,2170,1.0)
    rect(x-94,2140,188,44)
prop('tower',8610,2720,1.9,115)
prop('statue',7930,2570,1.45,52)
for x,y in [(10200,1200),(10800,1200),(10200,1970),(10800,1970)]:prop('pillar',x,y,1.5,40)
prop('statue',10500,1150,1.5,50)
prop('tower',11040,5260,1.8,95)

# Hand placed landmark vegetation around the first playable screen.
for kind,x,y,s in [('oak',2460,3550,1.1),('oak2',2690,3730,1.0),('oak',2870,4530,1.12),('rock',2740,4360,.8),('birch',3240,4060,1.02),('pine',3470,3840,1.2),('rocks',3590,4790,1.05)]:
    prop(kind,x,y,s,24 if kind in ['oak','oak2','pine','birch'] else 56)

for i in range(16000):
    if len(props)>1230:break
    x,y=rng.uniform(220,W-220),rng.uniform(260,H-190)
    if not road_clear(x,y) or not special_clear(x,y) or not clear_geometry(x,y,88):continue
    forest=math.hypot((x-2800)*.75,y-2050)<1800 or math.hypot(x-9400,y-6600)<1850
    if not forest and rng.random()<.5:continue
    kind=rng.choice(['oak','oak2','pine','birch'] if rng.random()<(.84 if forest else .53) else ['rock','rocks'])
    s=rng.uniform(.74,1.24) if kind in ['oak','oak2','pine','birch'] else rng.uniform(.55,1.1)
    prop(kind,x,y,s,24 if kind in ['oak','oak2','pine','birch'] else 56)

for _ in range(2300):
    x,y=rng.uniform(140,W-140),rng.uniform(140,H-140)
    if clear_geometry(x,y,35) and road_clear(x,y,8):prop(rng.choice(['grass','grass','bush']),x,y,rng.uniform(.26,.52))

# Continuous visible cliff ring follows the collision border.
for x in range(40,W,150):
    prop('rocks',x,120,1.4);prop('rocks',x,H-20,1.4)
for y in range(170,H-120,150):
    prop('rocks',35,y,1.4);prop('rocks',W-25,y,1.4)

portals=[
    {'id':'town_waystone','name':'폐허 이동석','position':[2120,4240],'target_map':'aden_world','target_position':[8120,3490],'radius':56},
    {'id':'ruin_waystone','name':'마을 이동석','position':[8170,3650],'target_map':'aden_world','target_position':[2240,4130],'radius':56},
    {'id':'oman_gate','name':'오만의 탑 입구','position':[10800,5400],'target_map':'oman_01','radius':68},
]
for p in portals:prop('waystone',p['position'][0],p['position'][1]-82,.83)
data={
    'schema_version':1,'map_id':'aden_world','map_name':'아덴 · 은빛 변경',
    'layout_revision':1,'bounds':[0,0,W,H],'spawn_position':[2420,4100],
    'navigation':{'cell_size':32,'agent_radius':24,'clearance':47,'diagonal_corner_cutting':False},
    'camera':{'zoom':.78,'follow_speed':7.0,'offset':[0,45]},
    'background':{'material_atlas':'res://assets/maps/aden/terrain.png','base_material':0},
    'foreground':{'prop_atlas':'res://assets/maps/aden/props.png','fade_alpha':.32},
    'roads':roads,'water':water,'bridges':bridges,'props':props,'collision':blockers,
    'regions':regions,'safe_zone':['town'],'combat_zone':['meadow','forest','riverbank','ruins','east'],'boss_zone':['boss'],
    'monster_spawn':spawn_regions,
    'npc_spawn':[{'id':'warden','name':'순찰대장','position':[2050,3920],'role':'guide'}, {'id':'merchant','name':'변경 상인','position':[1980,3840],'role':'shop'}],
    'portal':portals,'teleport':portals[:2],
    'minimap':{'show_roads':True,'show_regions':True,'show_monsters':True},
    'streaming':{'chunk_size':1024,'margin':360,'monster_sleep_distance':2100},
    'art_note':'Original authored playable field and generated environment assets; not official game geometry.'
}
target=ROOT/'data/maps/aden_field.json'
target.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n',encoding='utf-8')
print(f'{target}: {len(props)} props, {len(blockers)} shared collision shapes')
