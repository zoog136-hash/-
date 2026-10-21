"""Author PR137 local encounters on inspected source pixels; never redraw art.

These are TWILIGHT encounter/portal placements, not recovered server spawns.
Only the listed floor pockets are enabled. Same-map travel gates connect Aden's
separate reviewed pockets; opaque PNG pixels are never treated as walkability.
The source PNGs/chunks remain byte-identical; only plan/manifest receipts change.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVISION = 2026102002


def read(path):
    return json.loads((ROOT / path).read_text())


def write(path, value):
    (ROOT / path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def digest(path):
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()


def box(x, y, width, height):
    return [[x, y], [x + width, y], [x + width, y + height], [x, y + height]]


def circle(identity, center, radius):
    return dict(id=identity, shape='circle', center=center, radius=radius)


# Individual polygons were traced against decoded native-resolution source
# crops. Trees, buildings, cliff faces, lava and opaque holes remain obstacles.
# Arrival/exit pads are local gameplay placements and do not assert original
# monster positions or an original-game teleport network.
HABITATS = [
    dict(id='meadow', name='아덴 성문 초원',
         floor=[[11010,3335],[11070,3330],[11155,3375],[11255,3410],[11340,3450],
                [11330,3475],[11240,3470],[11175,3445],[11100,3440],[11040,3400]],
         landing=[11060,3360], back=[11035,3360], onward=[11300,3450], count=6,
         collisions=[]),
    dict(id='forest', name='동쪽 숲 공터',
         floor=[[10240,3380],[10310,3345],[10395,3355],[10440,3390],
                [10410,3455],[10365,3480],[10310,3460],[10270,3420]],
         landing=[10290,3395], back=[10265,3395], onward=[10370,3450], count=6,
         collisions=[circle('forest_camp_stone',[10360,3395],17)]),
    dict(id='riverbank', name='강가 유적 주변',
         floor=[[7210,4160],[7250,4100],[7330,4090],[7395,4140],
                [7370,4215],[7320,4250],[7240,4230]],
         landing=[7250,4200], back=[7230,4185], onward=[7350,4205], count=6,
         collisions=[dict(id='river_ruin',shape='polygon',points=[[7245,4160],[7300,4110],
                         [7350,4130],[7330,4180],[7270,4190]])]),
    dict(id='ruins', name='황혼의 폐허 공터',
         floor=[[8195,3090],[8340,3075],[8470,3120],[8455,3195],
                [8300,3210],[8230,3180]],
         landing=[8240,3130], back=[8215,3125], onward=[8415,3170], count=6,
         collisions=[circle('ruin_tree',[8245,3090],16)]),
    dict(id='east', name='동부 숲길',
         floor=[[10970,2375],[11050,2350],[11085,2320],[11140,2325],
                [11185,2355],[11235,2375],[11220,2415],[11135,2420],[11060,2415],[10980,2405]],
         landing=[11015,2390], back=[10995,2390], onward=[11195,2390], count=6,
         collisions=[circle('east_tree',[11140,2350],16)]),
    dict(id='desert', name='사막 사냥터',
         floor=box(7460,5200,480,350),
         landing=[7500,5370], back=[7480,5370], onward=[7895,5225], count=8,
         collisions=[circle('desert_rock_a',[7510,5300],13),
                     circle('desert_rock_b',[7560,5350],17),
                     circle('desert_rock_c',[7630,5455],18),
                     circle('desert_crystal_a',[7605,5285],10),
                     circle('desert_crystal_b',[7740,5345],12)]),
    dict(id='bandits', name='산적 야영지 외곽',
         floor=[[8750,4940],[8810,4895],[8900,4900],[8960,4960],
                [8945,5040],[8880,5095],[8770,5050]],
         landing=[8790,4945], back=[8770,4945], onward=[8925,5000], count=6,
         collisions=[dict(id='bandit_hut',shape='polygon',points=[[8775,5000],[8820,4970],
                         [8860,5010],[8840,5060],[8795,5045]])]),
    dict(id='dragon_valley', name='용의 계곡 서쪽 골짜기',
         floor=[[5420,2460],[5470,2425],[5535,2440],[5530,2490],[5510,2520],
                [5545,2570],[5530,2610],[5560,2670],[5500,2690],[5465,2630],[5430,2600]],
         landing=[5475,2470], back=[5445,2470], onward=[5515,2650], count=4,
         collisions=[]),
    dict(id='oren', name='설원 들판',
         floor=[[7735,1105],[7890,1100],[7970,1150],[7950,1225],[7810,1245],[7740,1200]],
         landing=[7780,1140], back=[7755,1130], onward=[7920,1200], count=6,
         collisions=[circle('snow_tree',[7770,1195],10),circle('snow_tree_2',[7810,1150],8)]),
    dict(id='fire_land', name='화염 지대 현무암 평지',
         floor=box(6410,2165,360,150),
         landing=[6450,2270], back=[6430,2270], onward=[6725,2285], count=6,
         collisions=[circle('lava_pool',[6755,2245],30),
                     circle('basalt_rock',[6590,2215],13)]),
    dict(id='wind_land', name='바람 언덕 능선길',
         floor=[[10385,1920],[10450,1905],[10525,1915],[10565,1950],
                [10585,1980],[10545,2010],[10455,2000],[10400,1970]],
         landing=[10425,1945], back=[10405,1945], onward=[10550,1980], count=6,
         collisions=[circle('ridge_stone',[10500,1965],10)]),
    dict(id='western_approach', name='서부 초원',
         floor=[[3500,3710],[3580,3680],[3720,3700],[3770,3760],
                [3720,3820],[3600,3880],[3500,3860]],
         landing=[3540,3745], back=[3520,3745], onward=[3700,3800], count=6,
         collisions=[circle('western_stump',[3680,3740],10)]),
]

# Dedicated boss arenas are separated from normal-monster patrols. Each uses
# the same historical boss key, HP and wall-clock cooldown across both layouts.
BOSSES = [
    dict(id='drake', name='드레이크', source_zone='boss', title='드레이크 골짜기',
         floor=[[5950,2490],[6030,2450],[6110,2480],[6110,2540],[6030,2570],[5955,2535]],
         landing=[5980,2510], back=[5960,2510], onward=[6075,2520],
         encounter=box(6010,2470,90,80), collisions=[]),
    dict(id='dark_elder', name='흑장로', boss_id='dark_elder_encounter', title='흑장로 골짜기',
         floor=[[5595,2570],[5660,2530],[5730,2560],[5730,2620],[5670,2650],[5605,2620]],
         landing=[5625,2600], back=[5605,2600], onward=[5705,2610],
         encounter=box(5655,2545,70,80), collisions=[]),
    dict(id='sand_worm', name='샌드 웜', source_zone='desert_boss', title='사막 보스 구역',
         floor=box(7780,5500,250,150),
         landing=[7820,5590], back=[7800,5590], onward=[7980,5615],
         encounter=box(7870,5520,130,80),
         collisions=[circle('worm_rock',[7830,5535],14)]),
    dict(id='phoenix', name='피닉스', source_zone='fire_boss', title='화염 보스 구역',
         floor=box(6820,2140,170,170),
         landing=[6850,2265], back=[6835,2280], onward=[6960,2270],
         encounter=box(6870,2160,95,90), collisions=[]),
    dict(id='death_knight', name='데스나이트', boss_id='death_knight_encounter', title='폐허 보스 구역',
         floor=[[8150,3350],[8235,3350],[8310,3390],[8335,3445],
                [8280,3470],[8170,3415]],
         landing=[8200,3390], back=[8175,3380], onward=[8295,3440],
         encounter=box(8240,3380,65,65), collisions=[]),
]


def gate(identity, name, position, destination, mid='aden_world'):
    return dict(id=identity, name=name, position=position, radius=14,
                target_map=mid, target_position=destination,
                target_layout_revision=REVISION)


def author():
    plan = read('data/maps/aden_faith_png_plan.json')
    plan['revision'] = REVISION
    aden = plan['maps']['aden_world']
    aden.update(layout_revision=REVISION, spawn=[11720,2934],
                portal_connected_regions=True, constrain_all_population_patrol=True)
    aden['walk_polygons'] = [[[11650,2910],[11735,2867],[11880,2938],[11795,2980]]]
    aden['collision'] = [circle('palace_plaza_fountain',[11762,2921],14)]
    aden['route_checks'] = [aden['spawn'],[11700,2915],[11745,2895],[11815,2930],[11785,2950]]
    aden['regions'] = [dict(id='aden_palace_safe',name='아덴 궁전 안전 광장',type='safe',
                            polygons=aden['walk_polygons'].copy())]
    aden['portals'] = [dict(id='faith_entry',name='신념의 탑 입장',position=[11735,2897],target_map='faith_01',radius=14),
                       dict(id='albino_entry',name='알비노 분지',position=[11835,2938],target_map='albino_01',radius=14),
                       dict(id='yahee_entry',name='야히의신전',position=[11785,2955],target_map='yahee_temple',radius=14)]
    areas = HABITATS + BOSSES
    aden['portals'].append(gate('aden_hunting_entry','아덴 사냥터 이동', [11695,2917],areas[0]['landing']))
    aden['hunting_routes'] = []
    rows = []
    for index, area in enumerate(areas):
        identity = area['id']
        is_boss = 'encounter' in area
        title = area.get('title',area['name'])
        aden['walk_polygons'].append(area['floor'])
        aden['collision'].extend(area['collisions'])
        # Arrival is protected even after a player or monster is already moving.
        aden['regions'].append(dict(id=identity+'_arrival',name=title+' 이동 안전 구역',type='safe',
                                    center=area['landing'],radius=28))
        aden['regions'].append(dict(id='png_'+identity,name=title,type='boss' if is_boss else 'combat',
                                    polygon=area['floor']))
        following = areas[index+1]['landing'] if index+1<len(areas) else aden['spawn']
        aden['portals'].extend([
            gate(identity+'_return','아덴 광장 귀환',area['back'],aden['spawn']),
            gate(identity+'_next','다음 사냥 구역' if index+1<len(areas) else '아덴 광장',area['onward'],following)])
        aden['hunting_routes'].append(dict(id=identity,entry=area['landing'],exit=area['onward'],
                                           return_portal=identity+'_return',next_portal=identity+'_next'))
        row = dict(id='png_aden_'+identity,source_map='aden_world',
                   polygons=[area.get('encounter',area['floor'])],
                   max_count=1 if is_boss else area['count'],min_spacing=32,
                   roaming_radius=45 if is_boss else 48)
        if is_boss:
            row.update(mode='boss',monster_types=[area['name']],boss_id=area.get('boss_id',area['name']))
            if 'source_zone' in area: row['source_zone'] = area['source_zone']
        else:
            row['source_zone'] = identity
        rows.append(row)
    config = dict(schema_version=1,layout_revision=REVISION,base_plan_sha256='',
                  scope='LOCAL_REVIEWED_PNG_ENCOUNTERS_NOT_ORIGINAL_SERVER_SPAWNS',
                  maps={'aden_world':rows},map_settings={
                      'aden_world':dict(spawn_exclusion_radius=36,portal_exclusion_radius=20,
                                        min_spacing=32,roaming_radius=48,constrain_patrol=True)})

    for mid in ['faith_01','faith_02','faith_03','faith_04']:
        spec = plan['maps'][mid]
        spec.update(layout_revision=REVISION,constrain_all_population_patrol=True)
        if mid!='faith_03':
            # Retain the existing hall and extend only the visually inspected
            # east corridor. The slanted central balustrade remains solid.
            spec['walk_polygons'] = [
                [[4210,2740],[4415,2638],[4530,2700],[4710,2780],[4520,2870]],
                [[4640,2770],[4835,2675],[4930,2725],[4740,2820]]]
            if mid=='faith_02':
                spec['walk_polygons'][0]=[[4210,2740],[4415,2638],[4530,2700],
                                         [4690,2770],[4520,2825],[4445,2805],[4390,2810]]
            spec['collision'] = [circle('hall_column',[4600,2742],30),
                dict(id='central_balustrade',shape='polygon',points=[
                    [4440,2645],[4600,2725],[4770,2640],[4770,2670],[4600,2760],[4440,2680]])]
            if mid=='faith_04':
                spec['collision'].append(dict(id='broken_floor_steps',shape='polygon',
                    points=[[4450,2840],[4490,2820],[4545,2850],[4505,2875]]))
            spec['spawn'] = [4460,2760]
            spec['route_checks'] = [[4460,2760],[4320,2730],[4380,2735],[4520,2785],[4780,2750]]
            if mid=='faith_02': spec['route_checks'][3]=[4510,2790]
            boss_polygon = [[4790,2710],[4840,2685],[4900,2720],[4840,2755]]
            normal_polygons = spec['walk_polygons']
            source_zones = ['room_1','room_3'] if mid!='faith_04' else ['room_1','room_3','room_5']
        else:
            # This entire carpet hall was already inspected in PR137.
            boss_polygon = [[4940,2700],[5040,2650],[5170,2715],[5060,2770]]
            normal_polygons = spec['walk_polygons']
            source_zones = ['room_1','room_4']
        spec['regions'] = [dict(id=mid+'_arrival',name='신념 입장 안전 구역',type='safe',
                                center=spec['spawn'],radius=30)]
        for portal in spec['portals']:
            spec['regions'].append(dict(id=mid+'_'+portal['id']+'_safe',name='이동진 안전 구역',type='safe',
                                       center=portal['position'],radius=24))
        spec['regions'].append(dict(id=mid+'_boss_room',name='층 보스 구역',type='boss',polygon=boss_polygon))
        spec['regions'].append(dict(id=mid+'_hunting',name=spec['name']+' 사냥 구역',type='combat',
                                    polygons=spec['walk_polygons']))
        config['maps'][mid] = [dict(id='png_'+mid+'_'+source,source_map=mid,source_zone=source,
            polygons=normal_polygons,max_count=3,exclusions=[dict(polygon=boss_polygon)],
            roaming_radius=70) for source in source_zones]
        config['maps'][mid].append(dict(id='png_'+mid+'_boss',source_map=mid,source_zone='boss',
                                      polygons=[boss_polygon],max_count=1,roaming_radius=48))
        config['map_settings'][mid] = dict(spawn_exclusion_radius=36,portal_exclusion_radius=30,
                                           min_spacing=32,roaming_radius=70,constrain_patrol=True)

    for mid,spec in plan['maps'].items():
        # The minimap label anchor is metadata, not a replacement for the
        # exact polygon used by navigation/safety/population predicates.
        for region in spec.get('regions',[]):
            if 'center' not in region:
                polygons = region.get('polygons',[region.get('polygon',[])])
                points = [point for polygon in polygons for point in polygon]
                region['center'] = [round(sum(p[i] for p in points)/len(points)) for i in (0,1)]
            region.setdefault('radius',28)
            region.setdefault('color',{'safe':'70b99c','boss':'cd7765','combat':'b0a078'}[region['type']])
        spec['collision_scope'] = 'MANUALLY_REVIEWED_ENCOUNTER_FLOORS_AND_PORTAL_ROUTES_ONLY'
        spec['monster_coordinate_status'] = 'EXISTING_ROSTERS_LOCAL_REVIEWED_ENCOUNTERS_NOT_ORIGINAL_SERVER_COORDINATES'
        spec['review_method'] = 'DECODED_NATIVE_PIXEL_CROP_VISUAL_TRACE; explicit obstacles, alpha guard and body/path checks'
        spec['full_terrain_collision_verified'] = False
    plan['terrain_review'].update(
        scope='Reviewed entry halls and named encounter pockets only; Aden pockets are connected by authored same-map gates. Full terrain collision/foreground is not complete.',
        population='Existing registered species and boss identity/policy, placed on reviewed local PNG floor; no original coordinate transform claimed.')
    write('data/maps/aden_faith_png_plan.json',plan)
    plan_hash = digest('data/maps/aden_faith_png_plan.json')
    config['base_plan_sha256'] = plan_hash
    write('data/monsters/aden_faith_png_spawn_layout.json',config)

    # Update the existing integrity chain; no chunk, source, overview or mask
    # bytes are regenerated or relaxed. An old private pack remains old.
    pack = 'external_map_packs/aden_faith_png_v1'
    index = read(pack+'/index.json')
    index['plan_sha256'] = plan_hash
    for mid in plan['maps']:
        path = pack+'/'+mid+'/manifest.json'
        manifest = read(path)
        manifest['plan_sha256'] = plan_hash
        manifest['collision_scope'] = plan['maps'][mid]['collision_scope']
        write(path,manifest)
        index['maps'][mid]['sha256'] = digest(path)
    write(pack+'/index.json',index)
    receipt = read('data/maps/aden_faith_png_pack.json')
    receipt.update(plan_sha256=plan_hash,index_sha256=digest(pack+'/index.json'),maps=index['maps'],
                   scope='TRACKED_PNG_REVIEWED_LOCAL_ENCOUNTERS_NOT_FULL_TERRAIN_COLLISION',
                   private_art_in_public_git=True)
    write('data/maps/aden_faith_png_pack.json',receipt)
    print(json.dumps(dict(plan_sha256=plan_hash,index_sha256=receipt['index_sha256'],
        maps={mid:dict(zones=len(rows),normal_slots=sum(row['max_count'] for row in rows
              if row.get('mode')!='boss' and row.get('source_zone') not in ['boss','desert_boss','fire_boss']),
              bosses=sum(row.get('mode')=='boss' or row.get('source_zone')=='boss' for row in rows))
              for mid,rows in config['maps'].items()})))


if __name__ == '__main__':
    author()
