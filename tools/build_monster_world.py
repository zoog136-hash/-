"""Reproducible monster overlays; never rewrite the original DB or map geometry.

Names/regions have citations. All combat numbers, exact world coordinates, boss
skills without an observed source, and respawn timings are local design values.
"""
from pathlib import Path
import json
import hashlib

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'data/monsters'
OUT.mkdir(exist_ok=True)
BASE = json.loads((ROOT / 'data/game_db_v17.json').read_text())['몬스터']
BY_NAME = {x['name']: x for x in BASE}
SOURCES = {
    'oman_low': 'https://lineagem.inven.co.kr/dataninfo/guide/?idx=185439',
    'oman_mid': 'https://lineagem.inven.co.kr/dataninfo/guide/?idx=192955',
    'oman_7': 'https://saimplay.tistory.com/225',
    'oman_8': 'https://saimplay.tistory.com/226',
    'oman_9': 'https://saimplay.tistory.com/227',
    'oman_10': 'https://saimplay.tistory.com/228',
    'regional_names': 'https://www.inven.co.kr/board/lineagem/5557/13982',
    'faith_3': 'https://lineagem.inven.co.kr/db/monster/79804',
    'faith_3_names': 'https://lineagem.inven.co.kr/db/item/232394',
    'boss_schedule': 'https://lounge.plaync.com/feed/66358',
    'albino': 'https://www.inven.co.kr/board/lineagem/5019/482927',
    'field_reference': 'https://lineagem.inven.co.kr/dataninfo/guide/',
    'field_2022': 'https://what.tistory.com/542?category=1097726',
    'dragon_hotspot': 'https://lineagem.inven.co.kr/dataninfo/guide/?idx=182978',
    'elf_quest': 'https://lineagem.inven.co.kr/db/quest/?level=1',
}

# Each key points to a distinct original silhouette in five original plates.
BODIES = [
    'goblin','orc','orc_captain','bandit','skeleton','skeleton_archer','zombie','ghoul',
    'ghost','mummy','dark_knight','lich','wolf','tiger','cougar','minotaur',
    'spider','ant','soldier_ant','scorpion','lamia','medusa','cockatrice','chimera',
    'eye','succubus','demon','cerberus','drake','bone_dragon','dragon','phoenix',
    'stone_golem','iron_golem','lava_golem','crystal','fire','water','wind','earth',
    'lizard','elf_archer','mage','angel','prince','queen','reaper','ugnu',
    'dog','bugbear','ettin','cyclops','goat_demon','vampire','zombie_lord','spider_queen',
    'seer','mummy_king','valkyrie','commander','ape','bull','watcher','worm',
    'mimic','living_sword','imp','nightmare','bat','flower','dryad','stag',
    'frog','fishman','crab','turtle','unicorn','winged_skeleton','tentacle','witch',
    'orc_archer','orc_mage','bandit_archer','orc_warlord','gnoll','harpy','blue_harpy','bee',
    'salamander','fire_egg','magma_golem','basilisk','snowman','ice_man','yeti','ratman',
]

def seed(name):
    return int.from_bytes(hashlib.sha256(name.encode()).digest()[:4], 'big')

def body_for(name):
    rules = [
        ('오크 궁수','orc_archer'),('오크 마법사','orc_mage'),('오크 전사','orc_warlord'),
        ('산적 저격수','bandit_archer'),('산적 궁수','bandit_archer'),('블루 하피','blue_harpy'),
        ('하피','harpy'),('킬러비','bee'),('놀','gnoll'),('사라만다','salamander'),
        ('파이어 에그','fire_egg'),('마그마 골렘','magma_golem'),('바실리스크','basilisk'),
        ('눈사람','snowman'),('아이스 맨','ice_man'),('에티','yeti'),('랫맨','ratman'),('아타바크','goat_demon'),
        ('제니스','spider_queen'),('시어','seer'),('뱀파이어','vampire'),('좀비 로드','zombie_lord'),
        ('쿠거','cougar'),('머미 로드','mummy_king'),('아이리스','valkyrie'),('나이트발드','commander'),
        ('우그누스','ugnu'),('데우스','prince'),('벨리엘','queen'),('이자벨','valkyrie'),('라즈엘','watcher'),
        ('그림 리퍼','reaper'),('샌드 웜','worm'),('웨링','cougar'),('듀페리온','commander'),
        ('욥니르','bull'),('살라흐','goat_demon'),('그라디움','dragon'),
        ('개구리','frog'),('거북','turtle'),('크랩','crab'),('박쥐','bat'),
        ('디어','stag'),('플라워','flower'),('드라이어드','dryad'),('몽크','ape'),('유니콘','unicorn'),
        ('스켈레톤 윙','winged_skeleton'),('알비온','watcher'),('로가리우스','commander'),('메이드','zombie'),
        ('엔트키아','dryad'),('코아쿡','demon'),('그럽','ant'),('텐타클','tentacle'),('만토디아','soldier_ant'),
        ('킬 하운드','cerberus'),('레버넌트','ghost'),('제라키엘','angel'),('네르갈','mage'),('제노사이더','demon'),
        ('데스 도그','cerberus'),('데스 리퍼','reaper'),('데스 헌터','elf_archer'),
        ('서번트','ghost'),('라이더','dark_knight'),('키퍼','commander'),('워리어','dark_knight'),
        ('치프','orc_captain'),('솔져','dark_knight'),('나이트','dark_knight'),('매지션','mage'),
        ('어쌔신','bandit'),('시커','eye'),('그리미','ghoul'),('넝마','ghost'),('커스번','demon'),
        ('소울러','lich'),('퍼포','mage'),('테이너','bandit'),('하이드','commander'),('패트롤','dark_knight'),
        ('로머','orc_captain'),('가디언','iron_golem'),('커터','bandit'),('톱니','soldier_ant'),
        ('바포메트','goat_demon'),('베레스','goat_demon'),('얼음 여왕','queen'),('피닉스','phoenix'),
        ('본 드래곤','bone_dragon'),('해룡','dragon'),('드레이크','drake'),('드래곤','dragon'),
        ('웅골리언','spider'),('옹골리언','spider'),('타란툴','spider'),('거미','spider'),('스파이더','spider'),
        ('병정개미','soldier_ant'),('개미','ant'),('스콜피','scorpion'),('메두사','medusa'),('라미아','lamia'),
        ('코카트리스','cockatrice'),('키메라','chimera'),('비홀더','eye'),('서큐','succubus'),
        ('켈베로','cerberus'),('불타는 궁수','skeleton_archer'),('저격병','skeleton_archer'),('궁수','skeleton_archer'),
        ('불타는','dark_knight'),('해골','skeleton'),('스켈레톤','skeleton'),('스파토이','skeleton'),
        ('좀비','zombie'),('구울','ghoul'),('고스트','ghost'),('유령','ghost'),('리치','lich'),('머미','mummy'),
        ('아이언','iron_golem'),('라바','lava_golem'),('변이된 골렘','crystal'),('골렘','stone_golem'),
        ('불꽃','fire'),('화염','fire'),('이프리트','fire'),('아그니','fire'),('파이어','fire'),
        ('폭풍','wind'),('바람','wind'),('태풍','wind'),('물','water'),('파도','water'),('심해정령','water'),
        ('수중정령','water'),('대지','earth'),('나무','earth'),('땅','earth'),
        ('마도','mage'),('마법','mage'),('장로','mage'),('네크로','lich'),('사제','mage'),('마녀','mage'),
        ('다크엘프','elf_archer'),('샤벨','tiger'),('호랑이','tiger'),('라이칸','wolf'),('늑대','wolf'),
        ('미믹','mimic'),('댄싱 소드','living_sword'),('임프','imp'),('나이트메어','nightmare'),
        ('들개','dog'),('마이노','minotaur'),('미노','minotaur'),
        ('버그베어','bugbear'),('오우거','bugbear'),('에틴','ettin'),('사이클롭스','cyclops'),
        ('아이스 골렘','crystal'),('아이스 맨','water'),('눈사람','crystal'),('에티','ape'),
        ('하피','angel'),('킬러비','soldier_ant'),('사라만다','lizard'),('크랩맨','crab'),
        ('산적 저격수','elf_archer'),('산적 궁수','elf_archer'),('오크 궁수','elf_archer'),('오크 마법사','mage'),
        ('도마뱀','lizard'),('리자드','lizard'),('이구아나','lizard'),('피쉬','fishman'),('심해어','fishman'),('어인','fishman'),
        ('상어','lizard'),('악어','lizard'),('아시타','demon'),('악마','demon'),('데몬','demon'),
        ('천사','angel'),('성광','angel'),('고블린','goblin'),('코볼트','goblin'),('오크','orc'),
        ('산적','bandit'),('도적','bandit'),('기사','dark_knight'),('커츠','dark_knight'),
    ]
    for token, body in rules:
        if token in name: return body
    return 'dark_knight'

MAGIC = {'mage','lich','succubus','eye','seer','watcher','fire','water','wind','earth','queen','prince','angel','witch','dryad','tentacle','orc_mage','fire_egg'}
CRAWL = {'spider','ant','soldier_ant','scorpion','worm','spider_queen','crab','turtle','frog'}
HEAVY = {'iron_golem','stone_golem','lava_golem','bugbear','ettin','cyclops','minotaur','zombie_lord','bull','commander','magma_golem','yeti','orc_warlord'}
BEAST = {'wolf','dog','tiger','cougar','cerberus','drake','dragon','bone_dragon','phoenix','nightmare','stag','unicorn','bat','harpy','blue_harpy','bee','salamander','basilisk'}

def profile(name, source='legacy', boss=False, overrides=None):
    body = body_for(name)
    code = BODIES.index(body)
    s = seed(name)
    kind = 'magic' if body in MAGIC else ('ranged' if body in {'elf_archer','skeleton_archer','orc_archer','bandit_archer'} else 'melee')
    if body in {'drake','dragon','bone_dragon','phoenix','cerberus'}: kind = 'magic'
    style = 'magic' if kind == 'magic' else ('bow' if kind == 'ranged' else ('heavy' if body in HEAVY else ('crawl' if body in CRAWL else 'slash')))
    weapon = 'staff' if kind == 'magic' else ('bow' if kind == 'ranged' else ('claws' if body in CRAWL | BEAST else ('axe' if body in HEAVY else 'sword')))
    element = 'fire' if body in {'fire','lava_golem','phoenix','cerberus','drake','fire_egg','salamander','magma_golem'} else ('dark' if body in {'mage','lich','succubus','reaper'} else ('water' if body in {'water','ice_man','snowman'} else ('wind' if body in {'wind','harpy','blue_harpy'} else ('earth' if body in {'earth','stone_golem'} else 'physical'))))
    result = {
        'name': name, 'attack_type':kind, 'attack_element':element,
        'attack_interval':round((1.6 if body in HEAVY else (1.35 if kind=='magic' else .95 if body in BEAST else 1.2)) + (s % 4)*.07, 2),
        'attack_range':310 if kind=='magic' else 285 if kind=='ranged' else 66 if body in HEAVY else 58,
        'visual_height':128 if boss else 98 if body in {'dragon','bone_dragon','ettin','cyclops'} else 78 if body in CRAWL | BEAST else 86,
        'collision_radius':26 if boss else 16 if body in CRAWL else 19,
        'visual':{'atlas':code//16, 'cell':code%16, 'body':body, 'variant':s%16,
                  'width':round(.92+(s%7)*.026,3), 'weapon':weapon, 'crest':s%5,
                  'accent':['c4aa64','b76d5a','849bab','aa8aaf','8daa7b'][s%5]},
        'animation_profile':{'motion_style':style,'attack_hit_ratio':.56 if style=='heavy' else .52 if kind=='magic' else .38 if kind=='ranged' else .44,
                             'floating':body in {'ghost','eye','seer','watcher','fire','water','wind','angel','phoenix','reaper','harpy','blue_harpy','bee','bat'}},
        'ai':{'aggressive':True,'aggro_radius':600 if boss else 480,'leash_distance':820 if boss else 760,
              'social_radius':180 if body in {'orc','orc_captain','ant','soldier_ant','dark_knight'} else 0,
              'social_group':body, 'preferred_range':210 if kind in {'ranged','magic'} else 0,
              'retreat_distance':120 if kind in {'ranged','magic'} else 0},
        'evidence':{'name_region':source,'combat_numbers':'local_design','appearance':'original_interpretation',
                    'attack_style':'inferred_from_archetype','animation':'procedural_8_direction_not_native_8_view_art'},
    }
    if body in {'wolf','dog','ant','zombie','skeleton','ghost'}: result['ai']['aggressive']=False
    if source == 'legacy': result['ai']['aggressive']=True
    if boss: result['is_boss']=True; result['ai']['aggressive']=True
    if '알비노' in name and not boss: result['ai']['aggressive']=False
    if body in {'spider','spider_queen','ghoul','scorpion','lamia'}:
        result.update(poison_accuracy=30,poison_duration=5.0,poison_tick_damage=3,poison_tick_interval=1.0)
    if body in {'medusa','cockatrice','eye','seer'}:
        result.update(hold_accuracy=35,hold_duration=1.3)
    if name=='불신의 서큐버스': result['ai']['blink']=True;result['evidence']['attack_style']='oman_low'
    if name.startswith('공포의 ') and body in {'cerberus','nightmare'}:
        result['evidence']['attack_style']='oman_low'
    if overrides: result.update(overrides)
    return result

records = {x['name']:profile(x['name']) for x in BASE}
additions = []

def register(name, level, source, boss=False, body=None, special=None):
    patch = profile(name,source,boss)
    if body:
        idx=BODIES.index(body);patch['visual'].update(atlas=idx//16,cell=idx%16,body=body)
    if special:
        patch['ai']['special']={'kind':special, 'cooldown':9+(seed(name)%6), 'windup':1.15,
            'radius':200+(seed(name)%4)*20,'multiplier':1.6,'element':patch['attack_element'],
            'label':{'nova':'광역 파동','cone':'부채꼴 강타','charge':'돌진','drain':'흡혈','summon':'수호자 소환','volley':'연속 사격','beam':'직선 마법'}.get(special,special),
            'evidence':'local_adaptation_not_verified_original_skill'}
    if name in BY_NAME:
        records[name]=patch
    else:
        template='바포메트' if boss else '해골 궁수' if patch['attack_type']=='ranged' else '서큐버스' if patch['attack_type']=='magic' else '해골 근위병'
        patch.update(lv=level,hp=(16000+level*100 if boss else 100+level*20),atk=(30+level//3 if boss else 5+level//3),
                     defense=level//5,xp=level*9,gold=level*4,speed=75+(seed(name)%50),
                     template=template,desc='원작 이름·지역 참고 / 전투 수치와 미확인 기술은 TWILIGHT 로컬 설계')
        # Templates supply established drop pools, never another species' race/grade.
        undead=patch['visual']['body'] in {'skeleton','skeleton_archer','zombie','ghoul','ghost','mummy','lich','bone_dragon','zombie_lord','mummy_king','reaper','winged_skeleton'}
        patch.update(undead=undead,type='언데드' if undead else '지역 몬스터',grade='보스' if boss else '일반',
                     element_resistance={},crit=5,stun_duration=0,silence_duration=0,fear_duration=0,bleed_duration=0)
        for status in ['stun','silence','hold','fear','poison','bleed']:
            patch.setdefault(status+'_duration',0)
            patch.setdefault(status+'_accuracy',0)
        additions.append(patch)
        records[name]=patch
    return name

OMAN = [
 ['왜곡의 웅골리언트','왜곡의 라미아','왜곡의 메두사','왜곡의 코카트리스','왜곡의 키메라','왜곡의 타란툴라'],
 ['불신의 다이어울프','불신의 비홀더','불신의 서큐버스','불신의 미믹','불신의 댄싱 소드','불신의 임프'],
 ['공포의 파이어 에그','공포의 켈베로스','공포의 레서 데몬','공포의 나이트메어','공포의 이프리트','공포의 아그니'],
 ['죽음의 해골 근위병','죽음의 해골 돌격병','죽음의 해골 저격병','죽음의 스파토이','죽음의 좀비'],
 ['지옥의 고스트','지옥의 네크로맨서','지옥의 아이언골렘','지옥의 본 드래곤','지옥의 레서 드래곤'],
 ['불사의 구울','불사의 좀비 병사','불사의 좀비 마법사','불사의 좀비 장군'],
 ['잔혹한 혼 켈베로스','잔혹한 샤벨타이거','잔혹한 라이칸스로프','잔혹한 아시타지오'],
 ['어둠의 불타는 전사','어둠의 불타는 궁수','암흑의 서큐버스 퀸','암흑의 흑기사'],
 ['불멸의 해골 근위병','불멸의 해골 저격병','불멸의 해골 돌격병','불멸의 해골 기사','불멸의 본 드래곤'],
 ['오만한 아스모데우스','오만한 플레임 팽','오만한 레비아탄','오만한 서큐버스 퀸','오만한 아시타지오'],
]
THEMES=['왜곡','불신','공포','죽음','지옥','불사','잔혹','어둠','불멸','오만']
OMAN_BOSSES=['왜곡의 제니스 퀸','불신의 시어','공포의 뱀파이어','죽음의 좀비 로드','지옥의 쿠거',
             '불사의 머미 로드','잔혹한 아이리스','어둠의 나이트발드','불멸의 리치','오만한 우그누스']
SPECIALS=['nova','beam','drain','summon','charge','nova','volley','cone','summon','cone']
FAITH=[['교만의 킬 하운드','교만의 레버넌트','교만의 제라키엘','교만의 네르갈','교만의 제노사이더'],
       ['탐욕의 엔트키아','탐욕의 코아쿡','탐욕의 그럽','탐욕의 텐타클','탐욕의 만토디아'],
        ['질투의 스켈레톤 윙','질투의 로가리우스','질투의 좀비 메이드','질투의 감시자 알비온','질투의 좀비 나이트','질투의 아타바크'],
       ['분노의 데스 서번트','분노의 데스 키퍼','분노의 데스 도그','분노의 데스 라이더','분노의 데스 워리어','분노의 데스 리퍼','분노의 데스 헌터']]
FAITH_BOSSES=['교만의 왕자 데우스','탐욕의 여왕 벨리엘','질투의 공주 이자벨','분노의 주시자 라즈엘']
ESCAROS=[['에스카로스 솔져','에스카로스 나이트','에스카로스 매지션','에스카로스 어쌔신','에스카로스 치프'],
         ['톱니','스파이더','커스번','넝마','그리미','시커'],
         ['패트롤','로머','가디언'],['커터','소울러'],['퍼포','테이너','하이드']]
ESCAROS_BOSSES=['웨링','듀페리온','욥니르','살라흐','그라디움']
ALBINO=[['알비노 플라워','알비노 드라이어드','알비노 몽크','알비노 디어','알비노 도마뱀'],
        ['알비노 악어','알비노 개구리','알비노 심해어','알비노 이구아나','알비노 사냥꾼'],
        ['알비노 뿔 개구리','알비노 변이된 골렘','알비노 피쉬맨','알비노 악어거북','알비노 자이언트 크랩']]

maps={}
titles={}
def add_map(file, roster, boss, source, level, special, dense=False, note=''):
    definition=json.loads((ROOT / 'data/maps' / (file+'.json')).read_text())
    for i,name in enumerate(roster): register(name,level+i%3,source)
    if boss: register(boss,level+12,'boss_schedule',True,special=special)
    regions=[]
    for i,region in enumerate(definition['monster_spawn']):
        region=region.copy();region.pop('variants',None)
        if region['id']=='boss':
            if not boss: continue
            region.update(monster_types=[boss],mode='boss',boss_id=boss,max_count=1,
                          respawn_time=900,initial_delay=0,roaming_radius=110,activation_distance=2100,
                          schedule_reference='boss_schedule',respawn_policy='game_seconds')
        else:
            subset=[roster[(i+j)%len(roster)] for j in range(min(3,len(roster)))]
            region.update(monster_types=subset,mode='normal',max_count=8 if definition['family']=='escaros' else 6,
                          respawn_time=25,roaming_radius=130)
        values=[int(records[n].get('lv',BY_NAME.get(n,{}).get('lv',level))) for n in region['monster_types']]
        region['level']=[min(values),max(values)]
        region['density']=round(region['max_count']*1000000/(region['rect'][2]*region['rect'][3]),2)
        region['weights']=[3 if j==0 else 2 for j in range(len(region['monster_types']))]
        region['coordinate_evidence']='local_world_pixels_not_original_coordinates'
        region['roster_evidence']=source
        regions.append(region)
    if dense:
        base=next((r for r in regions if r['id']=='room_4'),regions[0]);rect=base['rect'];cx=rect[0]+rect[2]/2;cy=rect[1]+rect[3]/2
        dense_region=dict(base,id='dense_hotspot',rect=[cx-224,cy-224,448,448],mode='dense',
                          monster_types=roster[:],weights=[3]+[1]*(len(roster)-1),max_count=24,respawn_time=7,
                          spawn_radius=220,roaming_radius=70,activation_distance=1900,min_spacing=38,
                          source_hotspot='oman_low' if file=='oman_03' else 'local_layout_of_documented_hotspot',
                          density=119.58)
        dense_region['level']=[min(int(records[n].get('lv',level)) for n in roster),max(int(records[n].get('lv',level)) for n in roster)]
        regions.append(dense_region)
    maps[definition['map_id']]={'monster_spawn':regions,'coordinate_note':note or '현재 지형의 연결된 사냥방에 원작 지역 구성을 대응. 원작 지형의 정확한 복제 좌표가 아님.'}

for i,roster in enumerate(OMAN):
    source='oman_low' if i<3 else 'oman_mid' if i<6 else 'oman_'+str(i+1)
    # Updated name expansions are listed in the separately dated regional list.
    for name in roster:
        register(name,75+i,source if i>=6 else 'regional_names')
    add_map('oman_%02d'%(i+1),roster,OMAN_BOSSES[i],source,75+i,SPECIALS[i],dense=i in {2,6,9})
    titles['oman_%02d'%(i+1)]='오만의 탑 %d층 · %s'%(i+1,THEMES[i])
for i,roster in enumerate(FAITH):
    add_map('faith_%02d'%(i+1),roster,FAITH_BOSSES[i],'faith_3_names' if i==2 else 'regional_names',87+i*2,
            ['cone','nova','volley','beam'][i],note='신념의 원작 지역과 기존 9실 지형을 대응. 실제 사냥터 도형과 좌표는 재현이 아닌 로컬 배치.')
for i,roster in enumerate(ESCAROS):
    add_map('escaros_%02d'%(i+1),roster,ESCAROS_BOSSES[i],'regional_names',92+i,
            ['charge','cone','nova','summon','beam'][i],note='에스카로스 종 목록 확인. 5구역 내부 세부 소속과 보스방 좌표는 프로젝트 지형에 맞춘 로컬 배치이며 원작 정확 위치 미확인.')
for i,roster in enumerate(ALBINO):
    add_map('albino_%02d'%(i+1),roster,['알비노 유니콘','알비노 피닉스','알비노 데몬'][i],'albino',88+i,
            ['charge','nova','cone'][i],note='늪지/폭포/유황 몬스터 구분 확인. 원작 보스는 별도 실험실; 현재 맵 최심부를 실험실 대체 구역으로 사용한 로컬 변경.')
add_map('albino_04',ALBINO[2],'알비노 데몬','albino',91,'cone',note='2026-10 신설 4구역의 확정 몬스터 목록 자료 부족. 3구역 확인 몬스터를 로컬 고난도 구역으로 임시 배치; 원작 4구역 재현은 미완료.')
add_map('domination_summit',['데스나이트','흑장로','정예 다크엘프','지룡의 정예병'],'그림 리퍼','legacy',90,'summon',
        note='그림 리퍼 정상 보스와 기존 지형 보존. 일반 몬스터의 정확한 정상 출현 근거는 미확인.')

# Field geometry stays intact; all named field biomes use explicit rectangles.
aden=json.loads((ROOT/'data/maps/aden_field.json').read_text())
field_specs=[
 ('meadow','은기사 마을 주변',[2550,4220,1700,850],['말하는 섬 들개','말하는 섬 고블린','오크'],4),
 ('forest','오크 숲·오크 부락',[1600,1300,2300,1500],['오크','오크 궁수','오크 마법사'],12),
 ('riverbank','하이네·늪지',[3750,6100,1400,1000],['도마뱀','사악한 셸로브','크랩맨','라미아'],30),
 ('ruins','글루디오 던전 지상 대체',[7220,2100,1500,1400],['글루디오 던전 좀비','글루디오 던전 스켈레톤','글루디오 던전 구울'],24),
 ('east','요정 숲 남쪽 경계',[8300,5600,2100,1400],['오크','오크 궁수','오크 마법사'],32),
 ('desert','사막·개미굴 지상 대체',[2700,640,1350,580],['거대 개미','개미굴 일개미','개미굴 병정개미','스콜피온'],38),
 ('bandits','산적 소굴',[3400,3100,1700,650],['산적','산적 저격수','산적 행동대장'],42),
 ('dragon_valley','용의 계곡',[8800,2400,1800,1450],['흑장로','코카트리스','오우거','해골 저격병','해골 근위병'],55),
 ('oren','오렌 설벽',[8600,420,2350,820],['아이스 맨','샤벨 타이거','에티','아이스 골렘','아이언 골렘','눈사람'],58),
 ('fire_land','화룡 지역',[9700,4250,1500,780],['사라만다','파이어 에그','불타는 궁수','라바 골렘','혼 켈베로스'],65),
 ('wind_land','풍룡 지역',[900,6600,1900,980],['놀','하피','블루 하피','유니 드래곤','테라 드래곤','독침 킬러비'],65),
]
spawns=[];names=[]
for rid,label,rect,roster,lv in field_specs:
    for n in roster:
        if n not in records:register(n,lv,'field_2022' if rid in {'riverbank','bandits','dragon_valley','oren','fire_land','wind_land'} else 'elf_quest' if rid=='east' else 'field_reference')
    levels=[records[n].get('lv',BY_NAME.get(n,{}).get('lv',lv)) for n in roster]
    spawns.append(dict(id=rid,rect=rect,monster_types=roster,level=[min(levels),max(levels)],max_count=12,
                       density=round(12*1000000/(rect[2]*rect[3]),2),respawn_time=24,roaming_radius=120,mode='normal',
                       roster_evidence='field_2022' if rid in {'riverbank','bandits','dragon_valley','oren','fire_land','wind_land'} else 'elf_quest' if rid=='east' else 'legacy_or_inferred_field_biome',coordinate_evidence='local_world_pixels'))
    names.append(dict(id=rid,name=label,type='combat',center=[rect[0]+rect[2]/2,rect[1]+rect[3]/2],radius=max(rect[2:])*.52,color='8caa78'))
for boss,rid,rect,special in [('드레이크','boss',[10200,1330,520,510],'cone'),('샌드 웜','desert_boss',[4200,640,500,500],'nova'),
                              ('피닉스','fire_boss',[10600,5200,500,500],'nova')]:
    register(boss,BY_NAME.get(boss,{}).get('lv',75),'legacy',True,special=special)
    levels=[BY_NAME.get(boss,{}).get('lv',75)]*2
    spawns.append(dict(id=rid,rect=rect,monster_types=[boss],level=levels,max_count=1,density=4,respawn_time=600,
                       roaming_radius=90,mode='boss',boss_id=boss,initial_delay=0,respawn_policy='game_seconds'))
dragon_group=next(x for x in spawns if x['id']=='dragon_valley')
spawns.append(dict(dragon_group,id='dragon_dense',rect=[9310,2960,448,448],mode='dense',max_count=24,
                   spawn_radius=220,respawn_time=7,roaming_radius=70,min_spacing=38,activation_distance=1900,
                   weights=[2,2,1,3,3],density=119.58,source_hotspot='dragon_hotspot'))
maps['aden_world']={'monster_spawn':spawns,'region_labels':names,
    'coordinate_note':'아덴의 12288×8192 자체 지형에 생물군계를 대응. 글루디오 던전/개미굴은 독립 맵이 없어 지상 대체 구역. 실제 오렌/화룡/풍룡 좌표·지형은 원작과 다름.'}

# Set observed aggression explicitly instead of treating every creature alike.
for name,entry in records.items():
    if name.startswith('죽음의 '):entry['ai']['aggressive']=('근위병' in name or '돌격병' in name)
    if name.startswith('불사의 '):entry['ai']['aggressive']=('병사' in name or '장군' in name or '머미' in name)
    if name.startswith('지옥의 '):entry['ai']['aggressive']=('골렘' in name or '드래곤' in name or '쿠거' in name)
    if name.startswith('불신의 '):entry['ai']['aggressive']=('서큐버스' in name or '비홀더' in name or '시어' in name)
    if name.startswith('왜곡의 '):entry['ai']['aggressive']=('메두사' in name or '코카트리스' in name or '제니스' in name)
    if name.startswith('알비노 ') and not entry.get('is_boss'):entry['ai']['aggressive']=False

# Re-register can update a record; output additions once by name with final data.
# Some same species also live in a later map (Albino 3/4). Derive level bounds
# after every registration, avoiding stale ranges from the earlier map pass.
for map_profile in maps.values():
    for zone in map_profile['monster_spawn']:
        levels=[int(records[n].get('lv',BY_NAME.get(n,{}).get('lv',1))) for n in zone['monster_types']]
        zone['level']=[min(levels),max(levels)]
addition_names=set(x['name'] for x in additions)
document={'schema_version':1,'base_sha':'82dbbdb18ec3088fcf521ce887af61c0c48c5a28',
          'researched_on':'2026-10-09','sources':SOURCES,
          'overlays':{n:p for n,p in records.items() if n not in addition_names},
          'additions':[records[n] for n in sorted(addition_names)],'bodies':BODIES,
          'limitations':['원작 수치·보스 기술 정확성 미확인 항목은 local_design/local_adaptation',
                         '8방향은 논리/절차적 시점 표현; 원작처럼 그린 8시점 프레임은 미완료',
                         '종별 프로필은 고유하지만 원본 아트는 96개 종 계열을 공유',
                         '알비노 4구역의 확정 원작 구성 자료 부족',
                         '아덴 원작 지역 지형 및 독립 글루디오/개미굴 맵 재현은 범위 밖']}
(OUT/'monster_world_catalog.json').write_text(json.dumps(document,ensure_ascii=False,indent=2)+'\n')
(OUT/'world_spawn_profiles.json').write_text(json.dumps({'schema_version':1,'maps':maps,'map_titles':titles},ensure_ascii=False,indent=2)+'\n')
print('MONSTER_WORLD_DATA_OK',len(records),'species',len(maps),'maps',sum(len(x['monster_spawn']) for x in maps.values()),'zones')
