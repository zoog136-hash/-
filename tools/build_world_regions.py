"""Authored, deterministic region layouts; never reads or rewrites legacy maps.

Order: Oman 1-10, Domination, Escaros 1-5, Albino 1-4, Faith 1-4.
Shared atlases are reused; topology, landmarks, materials and monster regions
are authored per family and per floor. All geometry is in world/feet coordinates.
"""
import argparse
import json
import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MONSTERS = {m['name']: m for m in json.loads((ROOT / 'data/game_db_v17.json').read_text())['몬스터']}
ORDER = ([f'oman_{i:02}' for i in range(1, 11)] + ['domination_summit']
         + [f'escaros_{i:02}' for i in range(1, 6)]
         + [f'albino_{i:02}' for i in range(1, 5)]
         + [f'faith_{i:02}' for i in range(1, 5)])


def box_points(box):
    x, y, w, h = box
    return [[x, y], [x+w, y], [x+w, y+h], [x, y+h]]


def contains(box, point, pad=0):
    x, y, w, h = box
    return x-pad <= point[0] <= x+w+pad and y-pad <= point[1] <= y+h+pad


def distance_segment(p, a, b):
    vx, vy = b[0]-a[0], b[1]-a[1]
    t = max(0, min(1, ((p[0]-a[0])*vx+(p[1]-a[1])*vy)/max(1, vx*vx+vy*vy)))
    return math.hypot(p[0]-a[0]-t*vx, p[1]-a[1]-t*vy)


class Region:
    def __init__(self, map_id, name, family, number, w=7168, h=6656):
        self.rng = random.Random(20261007 + ORDER.index(map_id)*7919)
        self.w, self.h = w, h
        self.floors = []
        self.d = {
            'schema_version': 2, 'map_id': map_id, 'map_name': name,
            'family': family, 'short_name': name.split(' · ')[0], 'floor': number,
            'layout_revision': 2, 'bounds': [0, 0, w, h],
            'navigation': {'cell_size': 32, 'agent_radius': 24, 'clearance': 47, 'diagonal_corner_cutting': False},
            'camera': {'zoom': .78, 'follow_speed': 7., 'offset': [0, 45]},
            'background': {'material_atlas': 'res://assets/maps/aden/terrain.png', 'base_material': 2},
            'foreground': {'prop_atlas': 'res://assets/maps/aden/props.png', 'fade_alpha': .32},
            'render_style': {'wild_ground': False, 'palette': 'b4b7c2', 'saturation': .45,
                             'brightness_lift': 0., 'wall_tint': '51535e', 'prop_tint': 'b9b9c5', 'accent': 'd7a66b'},
            'surfaces': [], 'roads': [], 'water': [], 'bridges': [], 'props': [], 'collision': [],
            'regions': [], 'monster_spawn': [], 'npc_spawn': [], 'portal': [], 'teleport': [],
            'safe_zone': ['entry'], 'combat_zone': [], 'boss_zone': ['boss'],
            'minimap': {'title': family.upper(), 'show_roads': True, 'show_regions': True, 'show_monsters': True},
            'streaming': {'chunk_size': 1024, 'margin': 360, 'monster_sleep_distance': 2100},
            'review_points': {}, 'route_checks': [],
            'art_note': 'Original authored world; reused generated atlases and code-native landmarks. Not official game maps.'
        }

    def rect(self, box, kind='wall'):
        self.d['collision'].append({'shape': 'rect', 'rect': list(box), 'kind': kind})

    def prop(self, kind, x, y, scale=1., radius=0, color=None):
        rec = {'kind': kind, 'position': [round(x, 1), round(y, 1)], 'scale': round(scale, 3),
               'flip': self.rng.random() < .5}
        if color:
            rec['color'] = color
        self.d['props'].append(rec)
        if radius:
            self.d['collision'].append({'shape': 'circle', 'center': rec['position'],
                                        'radius': round(radius*scale, 1), 'kind': kind})

    def floor(self, box, material=2, tint=None):
        self.floors.append(list(box))
        surface = {'rect': list(box), 'material': material}
        if tint:
            surface['tint'] = tint
        self.d['surfaces'].append(surface)

    def corridor(self, a, b, width=384, bend=False):
        points = [a, [a[0], b[1]] if bend else [b[0], a[1]], b]
        points = [p for i, p in enumerate(points) if i == 0 or p != points[i-1]]
        for p, q in zip(points, points[1:]):
            self.floor([min(p[0], q[0])-width/2, min(p[1], q[1])-width/2,
                        abs(q[0]-p[0])+width, abs(q[1]-p[1])+width])
        self.d['roads'].append({'id': f'passage_{len(self.d["roads"])}', 'points': points,
                                'width': width-64, 'material': 2, 'opacity': .12})

    def seal_void(self):
        """Rectangle partition of the exact floor complement, on a 64px lattice.

        The same rectangles are rendered as raised walls and used by physics
        and navigation. No invisible walls and no separate navigation artwork.
        """
        step = 64
        active = {}
        for row in range(self.h//step + 1):
            runs = []
            if row < self.h//step:
                start = None
                for col in range(self.w//step + 1):
                    solid = col < self.w//step and not any(contains(b, (col*step+32, row*step+32)) for b in self.floors)
                    if solid and start is None:
                        start = col
                    if not solid and start is not None:
                        runs.append((start, col)); start = None
            for key in list(active):
                if key not in runs:
                    box = active.pop(key)
                    self.rect(box, 'dungeon_wall')
            for key in runs:
                if key in active:
                    active[key][3] += step
                else:
                    active[key] = [key[0]*step, row*step, (key[1]-key[0])*step, step]

    def hunt(self, ident, name, center, box, types, count, level, boss=False):
        region_type = 'boss' if boss else 'combat'
        self.d['regions'].append({'id': ident, 'name': name, 'center': center,
                                  'radius': min(box[2], box[3])*.56, 'type': region_type,
                                  'color': self.d['render_style']['accent']})
        self.d['monster_spawn'].append({
            'id': ident, 'rect': box, 'monster_types': types, 'level': [level, level+3],
            'variants': {t: {'level': level+i*3} for i, t in enumerate(types)},
            'density': round(count/(box[2]*box[3])*1e6, 2), 'max_count': count,
            'respawn_time': 120 if boss else 22+self.d['floor']*2, 'roaming_radius': 140 if boss else 180})
        if not boss:
            self.d['combat_zone'].append(ident)
        self.d['route_checks'].append(center)

    def entrance(self, point):
        self.d['spawn_position'] = point
        self.d['regions'].insert(0, {'id': 'entry', 'name': '입구 쉼터', 'type': 'safe',
                                     'center': point, 'radius': 360, 'color': 'c0b179'})
        self.d['npc_spawn'].append({'id': 'guide', 'name': '지역 안내자',
                                   'position': [point[0]+192, point[1]+224], 'role': 'guide'})
        self.d['review_points']['entrance'] = point

    def connect(self, exit_point):
        index = ORDER.index(self.d['map_id'])
        previous = ORDER[index-1] if index else 'aden_world'
        following = ORDER[index+1] if index+1 < len(ORDER) else 'aden_world'
        spawn = self.d['spawn_position']
        portals = [
            {'id': 'previous', 'name': '이전 지역', 'position': [spawn[0]-256, spawn[1]-96], 'target_map': previous, 'radius': 56},
            {'id': 'next', 'name': '다음 지역', 'position': [exit_point[0]+256, exit_point[1]+160], 'target_map': following, 'radius': 56},
            {'id': 'aden_return', 'name': '아덴 귀환', 'position': [spawn[0]-256, spawn[1]+160], 'target_map': 'aden_world', 'radius': 56},
        ]
        midway=self.d['route_checks'][len(self.d['route_checks'])//2]
        portals += [
            {'id':'advance_waystone','name':'중앙 이동석','position':[spawn[0]+384,spawn[1]-64],
             'target_map':self.d['map_id'],'target_position':midway,'radius':56},
            {'id':'entry_waystone','name':'입구 이동석','position':[midway[0]-256,midway[1]+160],
             'target_map':self.d['map_id'],'target_position':spawn,'radius':56},
        ]
        self.d['portal'] = portals
        self.d['teleport'] = portals[3:]
        for p in portals:
            self.prop('stairs' if p['id'] in ['previous','next'] else 'waystone', p['position'][0], p['position'][1]-64, .85)
        self.d['review_points']['boss'] = exit_point

    def write(self):
        assert len(self.d['props']) > 60, self.d['map_id']
        assert all(t in MONSTERS for r in self.d['monster_spawn'] for t in r['monster_types'])
        filename = self.d['map_id']+'.json'
        (ROOT / 'data/maps' / filename).write_text(json.dumps(self.d, ensure_ascii=False, separators=(',', ':'))+'\n', encoding='utf-8')
        return {'map_id': self.d['map_id'], 'map_name': self.d['map_name'],
                'bounds': self.d['bounds'], 'family': self.d['family'], 'path': 'res://data/maps/'+filename}


OMAN_EDGES = [
    [(0,1),(1,2),(0,3),(1,4),(2,5),(3,6),(4,7),(5,8),(3,4),(7,8)],
    [(0,3),(3,6),(6,7),(7,8),(8,5),(5,2),(2,1),(1,4),(4,7),(1,0)],
    [(0,1),(1,4),(4,3),(3,6),(4,7),(7,8),(8,5),(5,2),(2,1)],
    [(0,3),(3,4),(4,1),(1,2),(2,5),(5,4),(4,7),(7,6),(7,8)],
    [(0,1),(1,2),(2,5),(5,8),(8,7),(7,6),(6,3),(3,4),(4,7)],
    [(0,3),(3,6),(6,7),(7,4),(4,1),(1,2),(2,5),(5,8),(4,5)],
    [(0,1),(1,4),(4,7),(7,8),(8,5),(5,2),(4,3),(3,6),(6,7)],
    [(0,3),(3,4),(4,5),(5,8),(8,7),(7,6),(4,1),(1,2),(2,5)],
    [(0,1),(1,2),(2,5),(5,4),(4,3),(3,6),(6,7),(7,8),(4,7)],
    [(0,3),(3,6),(6,7),(7,8),(8,5),(5,2),(2,1),(1,4),(4,8)],
]
OMAN_NAMES = ['감시자의 회랑','뒤틀린 납골당','불신의 서고','악마의 감옥','침묵의 제단',
              '잿빛 병영','망자의 갤러리','심연의 전실','검은 왕좌','죽음의 성채']
OMAN_TYPES = [
    ['오만의 탑 감시자','해골 근위병'], ['오만의 탑 왜곡의 기사','해골 궁수'],
    ['오만의 탑 불신의 마법사','서큐버스'], ['오만의 탑 공포의 악마','흑장로'],
    ['오만의 탑 죽음의 수호자','네크로맨서'], ['불타는 전사','마이노'],
    ['정예 다크엘프','아크모'], ['지룡의 정예병','지룡의 서큐버스 퀸'],
    ['지옥의 레서 드래곤','제로스'], ['오만의 탑 죽음의 수호자','데스나이트']]


def dungeon(map_id, family, number):
    if family == 'oman':
        name = f'오만의 탑 {number}층 · {OMAN_NAMES[number-1]}'
    elif family == 'faith':
        name = f'신념의 탑 {number}층 · '+['빛의 회랑','순례자의 정원','서약의 대성당','영원의 성소'][number-1]
    else:
        name = f'알비노 분지 {number}구역 · '+['백색 수정굴','푸른 폭포','유황의 심장','별빛 석실'][number-1]
    r = Region(map_id, name, family, number)
    nodes = [[1280,5504],[3456,5504],[5632,5504],[1280,3328],[3456,3328],[5632,3328],
             [1280,1152],[3456,1152],[5632,1152]]
    if family == 'oman':
        edges = OMAN_EDGES[number-1]
        shade = ['b6b7c0','9ab6bb','a5b299','b49d9b','a495bb','c0a597','999db9','8dabb1','ac939c','b3958d'][number-1]
        r.d['render_style'].update(palette=shade, wall_tint='43434e', prop_tint=shade, brightness_lift=.025)
        types = OMAN_TYPES[number-1]
        level = 51 + number*4
        boss = ['바포메트','커츠','베레스','아크모','그림 리퍼'][(number-1)//2]
    elif family == 'faith':
        # Basilica, two-way cloister, transept labyrinth and axial sanctum.
        edges = [
            [(0,1),(1,4),(4,7),(4,3),(4,5),(3,6),(5,8),(1,2)],
            [(0,1),(1,2),(2,5),(5,8),(8,7),(7,6),(6,3),(3,0),(3,4),(4,5)],
            [(0,3),(3,4),(4,1),(1,2),(2,5),(5,8),(4,7),(7,6)],
            [(0,1),(1,4),(4,7),(7,8),(1,2),(4,3),(3,6),(4,5)]
        ][number-1]
        r.d['render_style'].update(palette='ece2c3', wall_tint='8e887b', prop_tint='ded4b5',
                                   accent='d7b75f', saturation=.2, brightness_lift=.18)
        types = ['테베 아누비스','테베 호루스'] if number%2 else ['오만의 탑 불신의 마법사','해골 근위병']
        level = 72 + number*4
        boss = '테베 오시리스'
    else:
        edges = [
            [(0,3),(3,6),(3,4),(4,1),(1,2),(2,5),(4,7),(7,8),(5,8)],
            [(0,1),(1,2),(2,5),(5,4),(4,3),(3,6),(6,7),(7,8),(4,7)],
            [(0,3),(3,4),(4,1),(4,2),(4,5),(4,7),(7,6),(7,8)],
            [(0,1),(1,2),(1,4),(4,3),(3,6),(4,7),(7,8),(8,5),(5,2)]
        ][number-1]
        nodes = [
            [[1280,5504],[3456,5504],[5632,5376],[1536,3584],[3712,3328],[5632,3456],[1408,1664],[3584,1280],[5632,1408]],
            [[1280,5504],[3456,5632],[5632,5376],[1536,3072],[3584,3328],[5632,3200],[1536,1280],[3584,1536],[5632,1152]],
            [[1280,5504],[3456,5376],[5632,5504],[1536,3456],[3456,3328],[5632,3456],[1536,1408],[3456,1280],[5632,1408]],
            [[1280,5504],[3456,5376],[5632,5504],[1408,3200],[3456,3456],[5504,3456],[1536,1408],[3456,1152],[5632,1408]]
        ][number-1]
        r.d['render_style'].update(palette=['c8dfea','b4d8e4','e2d9ad','d6c7eb'][number-1],
                                   wall_tint='a9b1c0', prop_tint='d5e3ed', accent='80d3eb',
                                   saturation=.12, brightness_lift=.27)
        types = ['수룡의 둥지 얼음기사','에바 왕국 수중정령'] if number%2 else ['수룡의 둥지 심해정령','에바 왕국 해저수호자']
        level = 64 + number*4
        boss = '얼음 여왕'
    for i, (x, y) in enumerate(nodes):
        side = 1280 if i in (0,4,8) else (1024 if (i+number)%3 else 1536)
        if family == 'faith' and i in (1,4,7):
            side = 1536
        if family == 'albino':
            side = 1280 if i != 4 else 1792
        r.floor([x-side/2, y-side/2, side, side])
        if family == 'albino':
            # Overlapping lobes produce broad, irregular cave bays, not tower boxes.
            r.floor([x-side/2-128, y-256, side+256, 512])
            r.floor([x-256, y-side/2-128, 512, side+256])
        # Pillars/rocks occupy real bases. Central transit and combat lanes stay clear.
        for dx, dy in [(-side/2+160,-side/2+160),(side/2-160,-side/2+160),(-side/2+160,side/2-160),(side/2-160,side/2-160)]:
            r.prop('crystal' if family == 'albino' else 'pillar', x+dx,y+dy,
                   1.1 if family != 'albino' else 1.4, 28 if family=='albino' else 42)
            r.prop('torch' if family != 'albino' else 'spore', x+dx+70,y+dy, .85, color=r.d['render_style']['accent'])
        if i not in (0,8):
            r.hunt(f'room_{i}', ['옆 회랑','수호실','기록실','중앙 전장','상부 전실','기도실','왕의 회랑'][i-1],
                   [x,y], [x-384,y-384,768,768], types if i%2 else list(reversed(types)), 7, level+i//3)
        for _ in range(10):
            px, py = x+r.rng.uniform(-side*.4,side*.4), y+r.rng.uniform(-side*.4,side*.4)
            r.prop('rune' if family=='faith' else 'rubble', px,py,.3)
    for a, b in edges:
        r.corridor(nodes[a],nodes[b],512 if family=='faith' else 384, bend=(number%2==0))
    r.seal_void()
    if family=='albino':
        # Silhouette rocks sit only in the shared solid complement, not passage mouths.
        for box in r.floors[:27]:
            x,y,w,h=box
            edge_points=[(px,y-36) for px in range(int(x),int(x+w),240)]+[(px,y+h+36) for px in range(int(x),int(x+w),240)]
            for px,py in edge_points:
                if not any(contains(other,(px,py),15) for other in r.floors):
                    r.prop('rocks',px,py,1.1)
    r.entrance(nodes[0])
    r.hunt('boss', '최심부 제단', nodes[8], [nodes[8][0]-320,nodes[8][1]-320,640,640], [boss], 1, level+10, True)
    if family == 'faith':
        for x,y in [nodes[4],nodes[7],nodes[8]]:
            r.prop('altar',x,y-220,1.3,60)
        for x,y in nodes:
            r.prop('banner',x+440,y-180,1., color='d6b254')
    elif family == 'oman':
        r.prop('altar',nodes[8][0],nodes[8][1]-230,1.2,60)
        for x,y in nodes[1:]: r.prop('tomb',x-280,y-200,.9,35)
    else:
        # Two cave-only basins: never across the central connecting passages.
        for x,y in [nodes[2],nodes[6]]:
            poly=box_points([x-400,y-430,260,180])
            r.d['water'].append({'polygon':poly,'deep_color':'366c84' if number!=3 else '807d35','shallow_color':'6db9ce' if number!=3 else 'c8b84f'})
            r.d['collision'].append({'shape':'polygon','points':poly,'kind':'water'})
        for x,y in nodes: r.prop('crystal',x+320,y-200,1.7,32, color=r.d['render_style']['accent'])
    r.connect(nodes[8])
    r.d['review_points']['central'] = nodes[4]
    return r


def domination():
    r=Region('domination_summit','지배의 탑 정상 · 검은 왕의 성채','domination',1,8192,7168)
    r.d['render_style'].update(palette='7c7998',wall_tint='34313f',prop_tint='9188a9',accent='b688cf',brightness_lift=.015)
    r.floor([384,384,7424,6400]); r.seal_void()
    # Two independent gates in the transverse rampart; upper split courtyard.
    for b in [[384,3456,1408,192],[2432,3456,3072,192],[6144,3456,1664,192],
              [3840,384,192,1024],[3840,2112,192,1344]]:r.rect(b,'fortress_wall')
    for x in [2048,5824]:
        r.d['roads'].append({'id':f'gate_{x}','points':[[x,6144],[x,1024]],'width':240,'material':2})
        r.prop('arch',x,3540,2.1)
        for y in range(4300,6200,480):r.prop('obelisk',x+330,y,1.5,45,color='9777bd')
    r.d['roads'].append({'id':'crownroad','points':[[2048,1600],[4096,1600],[5824,1600]],'width':320,'material':2})
    r.entrance([2048,6144])
    points=[[1408,2304],[5888,2432],[4096,4864],[6400,5632],[5824,1280]]
    for i,(x,y) in enumerate(points[:-1]):
        r.hunt(f'bastion_{i}',f'검은 성채 {i+1}전장',[x,y],[x-480,y-480,960,960],['정예 다크엘프','지룡의 정예병'] if i%2 else ['데스나이트','흑장로'],12,86+i*3)
    r.hunt('boss','왕관의 제단',points[-1],[5504,960,640,640],['그림 리퍼'],1,105,True)
    for x,y in points:
        for dx in [-610,610]:r.prop('pillar',x+dx,y-220,1.6,48)
        r.prop('statue',x,y-500,1.4,50)
    for _ in range(190):
        x,y=r.rng.randrange(600,7500),r.rng.randrange(600,6500)
        if all(math.dist((x,y),p)>760 for p in points+[[2048,6144]]) and all(distance_segment((x,y),a,b)>260 for road in r.d['roads'] for a,b in zip(road['points'],road['points'][1:])):
            r.prop(r.rng.choice(['rubble','tomb','rune']),x,y,r.rng.uniform(.3,.8))
    r.prop('altar',5824,780,2.,80)
    r.connect(points[-1]);r.d['review_points']['central']=[2048,3300]
    return r


def escaros(number):
    labels=['잿빛 협곡','독안개 습지','무너진 전초기지','용암의 경계','심연의 분화구']
    r=Region(f'escaros_{number:02}',f'에스카로스 {number}구역 · {labels[number-1]}','escaros',number,9216,7168)
    r.d['background']['base_material']=1 if number in (1,4,5) else 3
    r.d['render_style'].update(palette=['c6ad91','91b0a0','a6a996','b79987','9b8eac'][number-1],
                               wall_tint='665d58',prop_tint='afa390',accent=['e0ac70','98c893','c9bf8c','ed9f66','b59ad7'][number-1],saturation=.65)
    for box in [[0,0,9216,128],[0,7040,9216,128],[0,128,128,6912],[9088,128,128,6912]]:r.rect(box,'cliff')
    centers=[[1280,5504],[2944,4480],[3456,1536],[6912,1856],[7552,4736],[7552,6144]]
    road=[[1280,5504],[2944,4480],[3968,2560],[5504,2560],[6912,1856],[7552,4736],[7552,6144]]
    r.d['roads']=[{'id':'ashroad','width':220,'material':1,'points':road},
                  {'id':'lower_loop','width':170,'material':1,'points':[[2944,4480],[4096,5120],[5760,5120],[7552,4736]]}]
    if number in (1,2,4):
        # A warped fissure with two physically open bridge crossings.
        mid=4700+number*90
        def fissure(y): return mid+120*math.sin(y/800+number)
        for lo,hi in [(128,2440),(2680,5000),(5240,7040)]:
            ys=[lo+(hi-lo)*i/16 for i in range(17)]
            poly=[[round(fissure(y)-170,1),round(y,1)] for y in ys]+[[round(fissure(y)+170,1),round(y,1)] for y in reversed(ys)]
            r.d['water'].append({'polygon':poly,'deep_color':'513327' if number==4 else '304c41' if number==2 else '293849',
                                 'shallow_color':'b46935' if number==4 else '78926d' if number==2 else '587786'})
            r.d['collision'].append({'shape':'polygon','points':poly,'kind':'water'})
        for y in [2560,5120]:
            box=[fissure(y)-430,y-120,860,240]
            r.d['bridges'].append({'id':f'fissure_bridge_{y}','rect':box})
            r.rect([box[0],box[1]-12,box[2],12],'bridge_rail');r.rect([box[0],box[1]+box[3],box[2],12],'bridge_rail')
    elif number==3:
        for b in [[1664,2752,1536,160],[3200,1728,160,1024],[3200,3232,160,640],
                  [5888,3584,1920,160],[5888,3584,160,768],[5888,4864,160,896]]:r.rect(b,'fortress_wall')
        for x,y in [[1800,2550],[3240,3750],[6090,3450],[7760,3450]]:r.prop('tower',x,y,1.4,80)
    else:
        # Four lava quadrants leave a wide cross-shaped causeway and crater rim.
        for b in [[4352,3456,1216,1088],[6016,3456,1152,1088],[4352,4928,1216,896],[6016,4928,1152,896]]:
            poly=box_points(b);r.d['water'].append({'polygon':poly,'deep_color':'3c294f','shallow_color':'78528b'})
            r.d['collision'].append({'shape':'polygon','points':poly,'kind':'water'})
    r.entrance(centers[0])
    for i,(x,y) in enumerate(centers[1:-1]):
        types=(['화룡의 둥지 라바 골렘','불타는 전사'] if number in (1,4) else ['정예 다크엘프','라이칸스로프'] if number==3 else ['지룡의 서큐버스 퀸','공포의 아그니'])
        r.hunt(f'field_{i}',f'{labels[number-1]} {i+1}사냥터',[x,y],[x-480,y-480,960,960],types,12,62+number*3+i*2)
    r.hunt('boss','경계의 지배자',centers[-1],[7232,5824,640,640],['이프리트' if number<4 else '피닉스'],1,83+number*2,True)
    for x,y in centers[1:]:r.prop('obelisk',x-580,y-360,1.6,38,color=r.d['render_style']['accent'])
    # Collision props are kept away from the actual routes, portal landings and hunts.
    for _ in range(2400):
        if len(r.d['props'])>=420:break
        x,y=r.rng.uniform(260,8950),r.rng.uniform(260,6900)
        if any(math.dist((x,y),p)<780 for p in centers):continue
        if any(distance_segment((x,y),a,b)<310 for rd in r.d['roads'] for a,b in zip(rd['points'],rd['points'][1:])):continue
        if 4000<x<5800 and number!=3:continue
        kind=r.rng.choice(['rocks','rock','rubble','obelisk','grass'])
        r.prop(kind,x,y,r.rng.uniform(.5,1.15),32 if kind in ['rocks','rock','obelisk'] else 0)
    for x in range(80,9216,160):r.prop('rocks',x,140,1.5);r.prop('rocks',x,7140,1.5)
    for y in range(200,7000,160):r.prop('rocks',40,y,1.5);r.prop('rocks',9180,y,1.5)
    r.connect(centers[-1]);r.d['review_points']['central']=[5800,4700] if number==5 else [4320,2560]
    if number==2:
        rotate_world(r)
    return r


def rotate_world(r):
    """Wetland's river runs west/east, with north/south crossing and combat lanes."""
    old_h=r.h
    def point(p):return [old_h-p[1],p[0]]
    def box(b):return [old_h-b[1]-b[3],b[0],b[3],b[2]]
    r.w,r.h=r.h,r.w
    r.d['bounds']=[0,0,r.w,r.h]
    r.d['spawn_position']=point(r.d['spawn_position'])
    for p in r.d['props']:p['position']=point(p['position'])
    for s in r.d['collision']:
        if s['shape']=='rect':s['rect']=box(s['rect'])
        elif s['shape']=='circle':s['center']=point(s['center'])
        else:s['points']=[point(p) for p in s['points']]
    for s in r.d['surfaces']:s['rect']=box(s['rect'])
    for road in r.d['roads']:road['points']=[point(p) for p in road['points']]
    for water in r.d['water']:water['polygon']=[point(p) for p in water['polygon']]
    for bridge in r.d['bridges']:bridge['rect']=box(bridge['rect'])
    for region in r.d['regions']:region['center']=point(region['center'])
    for region in r.d['monster_spawn']:region['rect']=box(region['rect'])
    for p in r.d['npc_spawn']+r.d['portal']:
        p['position']=point(p['position'])
        if 'target_position' in p and p['target_map']==r.d['map_id']:
            p['target_position']=point(p['target_position'])
    r.d['route_checks']=[point(p) for p in r.d['route_checks']]
    r.d['review_points']={key:point(p) for key,p in r.d['review_points'].items()}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--family',choices=['all','oman','domination','escaros','albino','faith'],default='all')
    args=parser.parse_args()
    index_path=ROOT/'data/maps/field_index.json'
    existing={x['map_id']:x for x in json.loads(index_path.read_text())} if index_path.exists() else {}
    for map_id in ORDER:
        family='domination' if map_id=='domination_summit' else map_id.split('_')[0]
        if args.family not in ('all',family):continue
        number=1 if family=='domination' else int(map_id.split('_')[1])
        region=domination() if family=='domination' else escaros(number) if family=='escaros' else dungeon(map_id,family,number)
        existing[map_id]=region.write()
        print(f'{map_id}: {len(region.d["props"])} props, {len(region.d["collision"])} blockers, {sum(s["max_count"] for s in region.d["monster_spawn"])} monsters')
    index_path.write_text(json.dumps([existing[m] for m in ORDER if m in existing],ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


if __name__=='__main__':main()
