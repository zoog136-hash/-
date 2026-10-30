#!/usr/bin/env python3
"""Record the private visual review without changing approval/art/runtime data."""
from pathlib import Path
import json,hashlib,collections
from PIL import Image
ROOT=Path(__file__).resolve().parents[5];OUT=Path(__file__).resolve().parent

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
m=json.loads((OUT/'metadata.json').read_text());counts=json.loads((OUT/'exact-phase-counts.json').read_text());packs={p['id']:p for p in m['packs']}
observations={
'pack-00':{
 'status':'HOLD','identity':'PASS_WITHIN_EXAMINED_SOURCE','eight_view_silhouette':'PASS_WITHIN_EXAMINED_SOURCE','idle_hit_separation':'PASS_WITHIN_EXAMINED_SOURCE',
 'findings':['원형의 커다란 불꽃 상체·손의 발톱 형태·소용돌이 불꽃 하반신이 실제 SpriteFrames에서 유지된다. S 전면/N 후면 및 E/W 측면이 분리된다.','8방향 공격1은 각 방향으로 팔/불꽃을 뻗고 0 준비→1 방출→2 복귀가 구분된다. 피격은 상체가 젖혀지고 사망은 불꽃이 낮은 잔불로 가라앉는다.','독립 RUN 트랙은 없으며 현재 RUN 상태가 3자세 WALK를 사용한다. 불꽃형 개체라 발 지지 교대는 적용하지 않지만, 3자세 반복의 실제 Main 이동/방출 타이밍·질량감은 이번 정지 프레임 검토만으로 확정하지 않는다.'],
 'reasons':['전용 외형/방향/역할의 기본 소스 구분은 확인했으나 실제 게임의 이동 루프·방출 순간과 대상 접촉을 확인하지 않아 신화급 동작 완료 PASS를 주지 않는다.'],
 'support':'NOT_APPLICABLE_FLAME_BODY; flow/altitude timing NOT_REVIEWED','attack_contact':'SOURCE_EXTENSION_VISIBLE; live hit-marker/target contact NOT_REVIEWED'},
'pack-01':{
 'status':'REWORK_CANDIDATE','identity':'FAIL_REFERENCE_MISMATCH','eight_view_silhouette':'8_VIEW_SOURCE_PRESENT; BOSS_SPECIFIC_SILHOUETTE_LOST','idle_hit_separation':'LIMITED_GENERIC_RIG',
 'findings':['원형은 넓은 가시 어깨/무거운 흉갑·장식 달린 투구·큰 붉은 망토·폭넓고 긴 대검을 가진 판금 기사다. 실제 바인딩은 가는 체격의 공용 기사이며 붉은 망토와 가시 갑옷의 넓은 윤곽, 대검 폭/비례가 사라진다.','담당 12종이 같은 SpriteFrames를 사용하고 프로필 틴트만 달라, 개체별 신화급 외형 정체성을 복구하지 못한다. 같은 프로젝트 원형을 가진 지역 지배자라도 공용 가는 기사와 색상만으로 전용 원형의 장비 윤곽을 대체할 수 없다.','현재 실제 소스에서 WALK8/ATTACK4/HIT2/DEATH6 자세와 8방향을 보았다. IDLE은 표기6프레임 중 E방향의 정규화된 가시 픽셀은 4개만 구분된다. 이는 프레임 누락 판정이 아니라 보스 동작 세부 재검토 근거다.'],
 'reasons':['보스 전용 원형의 망토·가시 갑옷·대검 비례가 현재 공용 바인딩에 보존되지 않아 전용 아트/동작 재제작 후보.'],
 'support':'PHASES_PRESENT; semantic individual support and mass NOT_APPROVED','attack_contact':'GENERIC_SWORD_SWING_VISIBLE; dedicated broadsword identity/weight fails'},
'pack-02':{
 'status':'REWORK_CANDIDATE','identity':'FAIL_REFERENCE_MISMATCH','eight_view_silhouette':'8_VIEW_GENERIC_SUCCUBUS; DEDICATED_BOSS_FEATURES_LOST','idle_hit_separation':'LIMITED_GENERIC_RIG',
 'findings':['실제 소스는 짧은 흰/보라 머리·작은 검은 박쥐 날개·분홍색 몸통의 공용 서큐버스이며, 공격1은 빈 손 앞의 작은 보라 구체 방출이다.','8방향 idle2/walk3/attack3/hit2/death3을 확인했지만 원형 보스의 장비와 큰 깃털 날개를 복구하지 못한다. 틴트만 달라진 같은 서큐버스 바인딩이다.'],
 'reasons':['원형 고유 날개/머리/의복/무기 정체성이 공용 서큐버스로 대체되어 신화급 기준 재제작 후보.'],
 'support':'PHASES_PRESENT; dedicated support/weight NOT_APPROVED','attack_contact':'SMALL_HAND_ORB_SOURCE; reference weapon identity fails'},
'pack-03':{
 'status':'REWORK_CANDIDATE','identity':'FAIL_REFERENCE_MISMATCH','eight_view_silhouette':'8_VIEW_GENERIC_ZOMBIE; LORD_MASS_LOST','idle_hit_separation':'GENERIC_RECOIL_VISIBLE',
 'findings':['원형 좀비 로드는 거대한 배와 넓은 몸통, 늘어진 사슬/장신구, 무거운 팔이 실루엣의 중심이다. 실제 소스는 배가 없는 가늘고 작은 어두운 좀비로, 체적과 사슬 및 보스 장비 정체성이 사라진다.','8방향 WALK8/ATTACK4/HIT2/DEATH6을 보았으며 공격은 맨팔을 올렸다 내리는 공용 동작이다. 거대한 보스 질량/무게 이동과 무기 정체성을 이 공용 마른 체형으로 대체할 수 없다.'],
 'reasons':['종족을 좀비로 읽을 수 있다는 사실만으로 거대한 좀비 로드 정체성을 충족하지 않는다. 전용 체적·장비·중량 동작 재제작 후보.'],
 'support':'GENERIC_WALK_VISIBLE; BOSS_MASS_FAIL','attack_contact':'GENERIC_BARE_ARM_SWING; reference equipment/mass fails'},
'pack-04':{
 'status':'HOLD','identity':'PASS_WITHIN_EXAMINED_SOURCE','eight_view_silhouette':'PASS_WITHIN_EXAMINED_SOURCE','idle_hit_separation':'PASS_WITHIN_EXAMINED_SOURCE',
 'findings':['원형의 검은 근육질 대형 고양잇과 몸통·긴 꼬리·발톱·벌어진 이빨/주둥이가 보존된다. 8방향에 독립 전/후/측면 실루엣이 있다.','공격1은 E/W에서 앞발과 상체를 앞으로 길게 뻗고, 다른 방향에서도 준비/도약/복귀가 구분된다. 피격의 앞몸 들림/뒤틀림과 사망의 옆으로 무너짐은 idle과 구분된다.','현재 RUN은 전용 트랙이 아니라 3자세 WALK 재생이다. E/W 및 후면의 전체 원본 자세를 확대해 보았지만 검은 근접/원거리 다리의 어느 쪽이 실제 하중을 받는지와 반대 지지 교대를 정지3자세에서 모두 확정하지 못했다. 발이 바닥선에 정렬된 사실만으로 접지를 승인하지 않는다.'],
 'reasons':['외형/8방향 기본 실루엣은 유지되나 대형 사족 보행의 반대 지지 교대와 이동 루프의 중량·접촉 타이밍이 미확정이다.'],
 'support':'HOLD_OPPOSITE_SUPPORT_UNRESOLVED_IN_THREE_PHASE_SOURCE','attack_contact':'FORWARD_PAW_EXTENSION_VISIBLE; live target/marker contact NOT_REVIEWED'},
'pack-05':{
 'status':'REWORK_CANDIDATE','identity':'FAIL_REFERENCE_MISMATCH','eight_view_silhouette':'8_VIEW_GENERIC_HOODED_CASTER; WINGED_ARMORED_PRINCESS_LOST','idle_hit_separation':'GENERIC_RECOIL_VISIBLE',
 'findings':['이자벨 지정 원형은 큰 깃털 날개, 붉은/금빛 갑옷, 투구/긴 머리와 긴 창을 가진 여성 보스다. 실제 소스는 날개 없는 단순 갈색 후드 로브와 초록 끝 지팡이의 공용 마법사다.','실제 CAST8방향도 추가 확인했다. 공용 지팡이 손짓/머리 위 회전은 원형의 긴 창 및 날개 움직임을 대신하지 못한다.'],
 'reasons':['성별/인간형 공통점만 남고 핵심 날개·갑옷·창 정체성이 소실되어 전용 보스 제작 후보.'],
 'support':'GENERIC_WALK_VISIBLE; dedicated body/wing mass NOT_APPROVED','attack_contact':'CAST_SOURCE_EXAMINED; reference spear/wing identity fails'},
'pack-06':{
 'status':'HOLD','identity':'PASS_WITHIN_EXAMINED_SOURCE','eight_view_silhouette':'PASS_WITHIN_EXAMINED_SOURCE','idle_hit_separation':'PASS_WITHIN_EXAMINED_SOURCE',
 'findings':['원형의 밝은 주황/금빛 불새, 긴 불꽃 꼬리, 큰 날개와 부리가 유지된다. 8방향의 3자세 이동 소스에서 날개 올림→펼침→내림이 구분되고 전/후/측면이 분리된다.','공격은 몸통/머리를 해당 방향으로 내밀고 회복하며, 피격의 날개 접힘과 사망의 불꽃/몸체 침강은 idle과 구분된다. 심각한 머리/날개/꼬리 절단은 본 소스 프레임에서 관찰하지 못했다.','RUN 전용 트랙은 없고 현재 3자세 WALK가 비행 이동에 쓰인다. 날개/꼬리 말단이 캔버스 아래 앵커에 닿는 위치는 정렬되어도 몸통의 비행 높이와 무게가 실제 반복에서 안정적인지는 정지 contact sheet만으로 승인하지 않는다.'],
 'reasons':['전용 외형과 방향/날개 단계는 보존되나 비행 루프의 몸통 고도/날개 중량 및 실제 타격 시점은 추가 게임 재생 품질 검토가 필요하다.'],
 'support':'NOT_APPLICABLE_FLYING; body altitude/wing-root continuity HOLD','attack_contact':'DIRECTIONAL_BODY_EXTENSION_VISIBLE; live target/marker contact NOT_REVIEWED'},
'pack-07':{
 'status':'REWORK_CANDIDATE','identity':'FAIL_REFERENCE_MISMATCH','eight_view_silhouette':'8_VIEW_GENERIC_HOODED_CASTER; ELDER_FEATURES_LOST','idle_hit_separation':'GENERIC_RECOIL_VISIBLE',
 'findings':['원형 흑장로의 긴 흰 머리/수염, 얼굴이 드러난 노년 인상, 장식 많은 긴 로브와 나뭇가지형 지팡이가 실제 소스의 단순 갈색 후드·작은 체형·초록 끝 일자 지팡이로 바뀌었다.','실제 CAST8방향까지 확인했지만 공용 마법사의 손짓이므로 고유 머리/수염/로브/지팡이의 방향별 중량 움직임을 보존하지 않는다.'],
 'reasons':['후드 마법사라는 공통 역할로 고유 노년 외형·의복·나무 지팡이를 대체하므로 신화급 보스 전용 제작 후보.'],
 'support':'GENERIC_WALK_VISIBLE; dedicated robe/staff mass NOT_APPROVED','attack_contact':'CAST_SOURCE_EXAMINED; reference staff identity fails'},
}
actors=[]
for i,a in enumerate(m['actors']):
 p=packs[a['pack']];o=observations[a['pack']];ref=a['reference'];src=ROOT/ref['path'].removeprefix('res://');im=Image.open(src).convert('RGBA');x,y,w,h=[round(v) for v in ref['region']];reference_pin={'path':str(src.relative_to(ROOT)),'sha256':sha(src),'region':[x,y,w,h],'region_rgba_sha256':hashlib.sha256(im.crop((x,y,x+w,y+h)).tobytes()).hexdigest(),'basis':a['reference_basis'],'scope':'Existing project art, not verified external original game art'}
 roles=['idle','walk','attack','hit','death']+(['cast'] if a['pack'] in ['pack-05','pack-07'] else [])
 examined={role:{d:list(range(len(p['tracks'].get(f'{role}_{j}',[])))) for j,d in enumerate(['E','SE','S','SW','W','NW','N','NE'])} for role in roles}
 findings=list(o['findings'])
 if a['id']=='monster:잔혹한 아이리스':findings.append('아이리스 원형의 큰 어두운 깃털 날개·투구/갑옷·긴 금빛 창이 공용 작은 박쥐 날개/빈 손 구체로 사라졌다.')
 if a['id']=='monster:탐욕의 여왕 벨리엘':findings.append('벨리엘 원형의 긴 은빛 머리·보랏빛 깃털 날개·긴 치마/왕관·보랏빛 지팡이가 현재 작은 박쥐 날개/짧은 머리 서큐버스로 사라졌다.')
 if a['id'] in ['monster:테베 아누비스','monster:테베 오시리스','monster:테베 호루스']:findings.append('제공된 프로젝트 원형 자체가 세 테베 보스에 같은 판금 기사 crop을 지정한다. 이 근거만으로 외부 원작의 신별 머리/무기 형태를 추정 승인하지 않으며, 전용 원형 정립도 필요하다.')
 evidence=[OUT/'contact-sheets'/f'{a["pack"]}-{suffix}.png' for suffix in ['movement','attack','idle-hit-death']]
 evidence.append(OUT/'contact-sheets'/f'references-{(i//5)*5:02d}-{(i//5)*5+4:02d}.png')
 if a['pack'] in ['pack-05','pack-07']:evidence.append(OUT/'contact-sheets'/f'{a["pack"]}-cast.png')
 if a['pack']=='pack-04':evidence += [OUT/'contact-sheets'/f'pack-04-walk-close-{j}.png' for j in [0,1]]
 actors.append({'id':a['id'],'name':a['name'],'status':o['status'],'approval_preserved':a['approval_preserved'],'original_approval_status':a['original_approval_status'],'approval_mutated':False,'new_approval':False,
 'runtime_pack':a['pack'],'profile_pin':{'catalog_path':'data/combat_animation_profiles.json','catalog_sha256':a['profile_catalog_sha256'],'profile_canonical_json_sha256':a['profile_sha256'],'profile':a['profile']},
 'SpriteFrames_pin':{'path':p['frames_path'],'sha256':p['frames_sha256']},'source_PNG_pins':p['sources'],'reference_pin':reference_pin,
 'actual_examined_views':['E','SE','S','SW','W','NW','N','NE'],'actual_examined_roles':roles,'actual_examined_frame_indices':examined,
 'run_source':'No authored run_* track; current runtime run state falls back to existing walk_*','visual_review_method':'Private inspection of exact current TRES source regions/margins, eight-view phase strips and per-boss original reference comparison. Per-profile tint applied in reference comparison; shared pack motion shape examined once.',
 'findings':findings,'reasons':o['reasons'],'checks':{'identity':o['identity'],'eight_view_silhouette':o['eight_view_silhouette'],'idle_hit_separation':o['idle_hit_separation'],'support_or_flight_weight':o['support'],'attack_contact':o['attack_contact'],'severe_cutoff_in_examined_source':'NOT_OBSERVED; actual Main sprite/viewport clipping NOT_REVIEWED'},
 'unseen_not_reviewed':['Live default Main scene loop cadence, impact marker/target alignment, foot support force, collision-relative actor positioning, viewport clipping and transition continuity were not played or approved in this review.','Staging drafts and new image sources are outside this current-production-binding review.','Optional CAST is not examined where the reviewed boss uses melee ATTACK.' if a['pack'] not in ['pack-05','pack-07'] else 'CAST source was seen, but live cast timing/projectile origin was not approved.'],
 'evidence':[{'path':str(x.relative_to(ROOT)),'sha256':sha(x)} for x in evidence],
 'phase_counts':counts[a['pack']]})
result={'schema':'pr122-boss-quality-review-v1','scope':'Bosses only, sorted id[40:60], including previously approved. No normal-monster quality review.','date':'2026-10-23','normal_monsters_quality_reviewed':0,'bosses_reviewed':20,'unique_runtime_packs_examined':8,'new_approvals':0,'approval_mutations':0,'summary':dict(collections.Counter(x['status'] for x in actors)),'previously_approved_reviewed':sum(x['approval_preserved'] for x in actors),'previously_approved_rework_candidates':sum(x['approval_preserved'] and x['status']=='REWORK_CANDIDATE' for x in actors),'actors':actors}
assert len(actors)==len({x['id'] for x in actors})==20
(OUT/'review-results.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
all_sheets=[{'path':str(p.relative_to(ROOT)),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted((OUT/'contact-sheets').glob('*.png'))];(OUT/'contact-sheets-index.json').write_text(json.dumps({'private_review_only':True,'user_chat_image_output':False,'sheets':all_sheets},indent=2)+'\n')
files=[{'path':str(p.relative_to(ROOT)),'sha256':sha(p),'bytes':p.stat().st_size} for p in sorted(OUT.rglob('*')) if p.is_file() and p.name!='file-manifest.json' and '__pycache__' not in p.parts]
(OUT/'file-manifest.json').write_text(json.dumps({'schema':1,'files':files,'bosses_reviewed':20,'normal_quality_reviewed':0,'user_chat_image_output':False,'approval_mutations':0},indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['bosses_reviewed','summary','previously_approved_reviewed','previously_approved_rework_candidates','new_approvals','approval_mutations']},ensure_ascii=False))
