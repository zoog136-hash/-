"""Export review tables from runtime JSON, so reports cannot silently drift."""
from pathlib import Path
from collections import defaultdict, Counter
import json

ROOT=Path(__file__).resolve().parents[1]
DOC=ROOT/'docs'
DOC.mkdir(exist_ok=True)
catalog=json.loads((ROOT/'data/monsters/monster_world_catalog.json').read_text())
profiles=json.loads((ROOT/'data/monsters/world_spawn_profiles.json').read_text())
base=json.loads((ROOT/'data/game_db_v17.json').read_text())['몬스터']
by_name={}
for record in base:
    by_name[record['name']]=dict(record,**catalog['overlays'].get(record['name'],{}))
for patch in catalog['additions']:
    record=dict(by_name.get(patch.get('template','해골 근위병'),{}))
    record.update(patch)
    by_name[record['name']]=record
locations=defaultdict(set)
boss_rows=[]
spawn_rows=[]
map_rows=[]
for map_id, data in profiles['maps'].items():
    modes=Counter()
    active_names=set()
    boss_names=[]
    capacities=Counter()
    for zone in data['monster_spawn']:
        mode=zone.get('mode','normal')
        modes[mode]+=1;capacities[mode]+=zone['max_count']
        for name in zone['monster_types']:
            active_names.add(name);locations[name].add(map_id)
        if mode=='boss':
            name=zone['monster_types'][0];boss_names.append(name)
            skill=by_name[name]['ai'].get('special',{})
            boss_rows.append([map_id,name,zone['rect'],skill.get('kind',''),skill.get('label',''),
                              skill.get('windup',''),skill.get('cooldown',''),zone['respawn_time'],
                              'TWILIGHT 로컬 기술 / 원작 고증 미확인'])
        spawn_rows.append([map_id,zone['id'],mode,zone['rect'],zone['max_count'],zone.get('spawn_radius','—'),
                           zone['respawn_time'],zone.get('activation_distance','일반 AI 거리 제한'),
                           ', '.join(zone['monster_types']),zone.get('weights','균등 순환'),
                           zone.get('roster_evidence','기존 DB/추정')])
    map_rows.append([map_id,len(active_names),modes['normal'],capacities['normal'],
                     modes['dense'],capacities['dense'],', '.join(boss_names),data.get('coordinate_note','')])

def table(headers, rows):
    def fmt(v):
        if isinstance(v,list): return json.dumps(v,ensure_ascii=False)
        return str(v).replace('|','/').replace('\n',' ')
    return '\n'.join(['| '+' | '.join(headers)+' |','| '+' | '.join(['---']*len(headers))+' |']+
                     ['| '+' | '.join(fmt(x) for x in row)+' |' for row in rows])+'\n'
species_rows=[]
placed_count=sum(1 for values in locations.values() if values)
for name, record in by_name.items():
    visual=record['visual']; evidence=record['evidence']
    species_rows.append([name,'기존 확장' if name in {x['name'] for x in base} else '신규',
        ('보스' if record.get('is_boss') else str(record.get('grade','일반'))),
        visual['body']+' / atlas '+str(visual['atlas'])+':'+str(visual['cell']),
        record['attack_type']+' · '+visual['weapon'],record['attack_range'],record['attack_interval'],
        'Idle / Walk / Attack / Hit / Death'+(' / Cast' if record['attack_type']=='magic' else ' / RangedAttack' if record['attack_type']=='ranged' else '')+(' / SpecialAttack' if record['ai'].get('special') else ''),
        '선공' if record['ai']['aggressive'] else '비선공·피격 시 반격',
        str(record['ai']['aggro_radius'])+' / '+str(record['ai']['leash_distance']),
        ', '.join(sorted(locations[name])) or 'DB 보존 · 현재 맵 배치 없음',
        str(record.get('lv',1))+' / '+str(record.get('hp',100))+' / '+str(record.get('atk',8)),
        evidence['name_region']+' / '+evidence['attack_style']])
(DOC/'MONSTER_SPECIES.md').write_text(
    '# 몬스터별 구현 표\n\n'+f'총 {len(by_name)}종 = 기존 {len(base)}종 확장 + 신규 {len(by_name)-len(base)}종. 실제 배치 고유 종류 {placed_count}종.\n\n'
    '아트는 계열 원화를 공유하며 종별 비율·장비·장식·공격 프로필이 다릅니다. 방향은 절차적 8방향 표현이며 독립 제작한 8시점 프레임이 아닙니다. 아래 수치는 기존 TWILIGHT 값을 유지했거나 신규 로컬 설계 값입니다. 원작 수치로 제시하지 않습니다. 방어·속성·상태이상·사회적 어그로의 상세 값과 근거는 JSON에 있습니다.\n\n'+
    table(['이름','변경','등급','원화 계열','공격·장비','거리 px','공격 간격 s','모션','성향','어그로/복귀 px','배치 맵','로컬 Lv/HP/ATK','이름·공격 근거 키'],species_rows),encoding='utf-8')
(DOC/'MONSTER_SPAWN_TABLES.md').write_text(
    '# 맵·스폰·보스 좌표 표\n\n'
    '좌표는 실제 Godot 월드 픽셀의 [x,y,width,height]입니다. 원작 좌표가 아닙니다. 전체 설정의 권위 있는 파일은 [world_spawn_profiles.json](../data/monsters/world_spawn_profiles.json)입니다.\n\n'
    '## 맵 구성\n\n'+table(['맵 ID','배치 종류','일반 구역','일반 상한','폭젠 구역','폭젠 상한','보스','지형 대응·한계'],map_rows)+
    '\n## 일반·폭젠·보스 스폰\n\n'
    '폭젠은 좁은 원형 범위·독립 슬롯·접근 활성화·간격 제한을 사용합니다. 일반 개체는 멀리 있으면 AI를 멈춥니다. weights는 각 종의 상대 출현 비율입니다. 멀어진 기존 폭젠 개체는 보존하되 AI를 멈추고 신규 생성을 보류합니다. 몬스터 간 충돌을 쓰지 않아 통로를 막지 않습니다.\n\n'+
    table(['맵','구역','모드','사각 범위 px','상한','원형 반경 px','재출현 s','활성 거리 px','종 목록','비율','출현 근거'],spawn_rows)+
    '\n## 보스 출현·전투·리스폰\n\n'
    '최초 입장 시 출현, 처치 후 설정된 게임 내 경과 시간으로 리스폰합니다. 맵별 boss ID에 HP·위치·생존/대기 상태·다음 출현 시각을 저장합니다. 앱 종료 동안 시간은 진행하지 않습니다. 벽/안전지대에 저장된 위치는 유효 스폰 위치로 대체합니다. 기술 피해는 경고 모션의 85% 마커에서 발생하며 투사체는 도착 시 판정합니다. 체력 50% 이하에서는 특수기 대기 시간이 70%로 줄어드는 로컬 격노 규칙입니다.\n\n'+
    table(['맵','보스','구역 px','패턴','게임 기술명','시전 s','기술 간격 s','리스폰 s','고증 상태'],boss_rows),encoding='utf-8')
(DOC/'MONSTER_WORLD_SOURCES.md').write_text(
    '# 조사 근거와 미확인 범위\n\n'
    '확인일 2026-10-09. 이름·지역·일부 선공/독/마법 공격 설명과 원작 수치·프레임을 구분했습니다. 출처 문장을 복제하지 않고 확인된 사실을 데이터 키에 연결했습니다. 원작 이미지·스프라이트를 추출하거나 배포하지 않습니다.\n\n'+
    table(['근거 키','URL'],catalog['sources'].items())+
    '\n## 해석 범위\n\n'
    '- 오만 저층/중층 가이드는 오래된 구성·행동 참고입니다. 7~10층 참고 글은 2026-09 자료입니다. 과거 가이드의 수치와 리스폰 시간표를 현재 원작 사실로 옮기지 않았습니다.\n'
    '- 공식 NC feed/66358은 월드 총력전 이벤트 자료입니다. 보스 이름과 참고 시간표 확인에 사용했으나 2026-10 상시 서버 시간표 전체를 확인한 것으로 주장하지 않습니다. 게임 설정에는 원작 이벤트 시간표를 자동 적용하지 않습니다.\n'
    '- 아덴 일부 필드 구성은 2022 지역 자료와 인벤 퀘스트/가이드를 참고했습니다. 오크·은기사 주변의 기존 저레벨 종, 정상 일반 몬스터, 에스카로스 5개 세부 구역 소속은 확인 수준이 낮아 기존/추정 표시가 남습니다.\n'
    '- 신념 3층은 개별 몬스터 DB와 드랍 목록에서 이름을 확인했습니다. 모든 종의 정확한 세부 출현점·전투 영상 고증은 미완료입니다.\n'
    '- 알비노 보스 원작 출현은 별도 실험실입니다. 현재 프로젝트에 독립 실험실 맵이 없어 각 맵 최심부 보스방으로 대응했습니다. 4구역의 확정 원작 구성은 확인하지 못해 3구역 종을 임시 사용합니다.\n'
    '- 아덴 프로젝트 지형은 원작 지형이 아닙니다. 글루디오 던전·개미굴 독립 맵은 없어 지상 대체 구역입니다. 전체 원작 월드의 지형 재현 완료로 주장하지 않습니다.\n'
    '- 원작 게임플레이 영상의 프레임별 검토는 완료하지 않았습니다. 모든 모션·특수기를 원작 영상에서 확인했다고 주장하지 않습니다.\n'
    '- 8방향 논리·절차적 변형·장비 모션은 구현했으나 모든 종의 독립 8시점 Idle/Walk/Attack/Hit/Death 스프라이트 제작은 미완료입니다. 계열 원화 공유가 남아 있어 “동일 원화 공유 없는 전면 아트 완성” 조건은 충족하지 않습니다.\n'
    '- 신규 전투 수치·속성·상태이상 확률·보스 기술·격노 규칙·보상 템플릿은 TWILIGHT 로컬 설계입니다. 신규 종은 기존 드랍 풀을 상속하며 기존 확률 계산/보스 장비 최대 3개 규칙은 수정하지 않았습니다.\n',encoding='utf-8')
print('MONSTER_REPORT_OK',len(by_name),'species',placed_count,'placed',len(spawn_rows),'zones',len(boss_rows),'boss zones')
