#!/usr/bin/env python3
"""Save verified production artifacts, exact remaining errors, and a short commit."""
from collections import Counter
import fcntl,hashlib,json,shutil,subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent
B=HERE.parent
ROOT=B.parents[4]
BASE='db1b9b7430db2abf3041cd85ebd34a4472263456'
def read(p):return json.loads(p.read_text())
def write(p,d):p.parent.mkdir(exist_ok=True,parents=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def copy_runtime(source,dest):
    dest.mkdir(exist_ok=True,parents=True)
    for n in ['process.json','report.json','command.json','godot.txt','godot-run.txt','config.json','capture-manifest.json']:
        if (source/n).exists():shutil.copyfile(source/n,dest/n)
    for p in source.glob('*.png'):shutil.copyfile(p,dest/p.name)
    for p in source.glob('*/captures/*.png'):
        target=dest/p.relative_to(source);target.parent.mkdir(exist_ok=True,parents=True);shutil.copyfile(p,target)
def main():
    full=Path('/workspace/runtime/boss-final-main-v02');boot=Path('/workspace/runtime/boss-final-main-boot-v02')
    result=read(full/'report.json');bp=read(boot/'process.json');br=read(boot/'report.json')
    assert not result['errors'] and len(result['cases'])==3
    assert sum(c['required_requests'] for c in result['cases'])==144
    assert sum(c['attack_release_events'] for c in result['cases'])==24
    assert bp['returncode']==0 and not bp['script_errors'] and not br['errors']
    assert read(HERE/'final-integration/summary.json')['status']=='PASS'
    assert read(HERE/'changed-v01-playback/summary.json')['status']=='PASS'
    assert read(HERE/'normal-frame-final.json')['status']=='PASS'
    kp=read(Path('/workspace/runtime/kurtz-w-hit-r015/process.json'));assert kp['returncode']==0 and not kp['script_errors']
    copy_runtime(full,HERE/'default-connection/full-main')
    copy_runtime(boot,HERE/'default-connection/final-boot')
    copy_runtime(Path('/workspace/runtime/kurtz-w-hit-r015'),HERE/'kurtz-w-hit/runtime')
    validation=dict(status='PASS',actual_Main=True,default_profile_candidate_injections=0,boss_role_direction_requests=144,attack_release_events=24,changed_default_bosses=[c['key'] for c in result['cases']],boss_request_errors=result['errors'],final_boot_script_errors=bp['script_errors'],previous_environment_errors=read(full/'process.json')['script_errors'],environment_resolution='Exact tracked dependencies restored in sparse checkout; only affected boot repeated, successful144 boss requests not replayed.',captures_visually_inspected=['0-run-4.png','1-idle-4.png','2-attack-6.png'],player_save_data='isolated; original player data unchanged',full_CI_runs=0)
    write(HERE/'default-connection/final-validation.json',validation)
    summary=read(HERE/'final-reviewed-v01/summary.json');visual={(x['slug'],x['clip']):x for x in read(HERE/'visual-review.json')['findings']}
    for x in summary['holds']:
        key=(x['slug'],x['clip']);proof=HERE/'affected-review-v01/owned-parts-repair'/x['slug']/(x['clip']+'.json')
        if key in visual:x.update(cause=visual[key]['cause'],reason=visual[key]['observation'])
        elif proof.exists() and (p:=read(proof))['status']=='HOLD':x.update(cause='unprovable_whole_pose_ownership',reason=p['reason'])
        x['automatic_retry']=False
    assert len(summary['holds'])==495-summary['selected_clips']==37
    write(HERE/'final-reviewed-v01/summary.json',summary)
    remaining=dict(schema='pr122-final-remaining-errors-v1',first_draft_missing_slots=0,remaining_boss_error_clips=37,common_causes=dict(Counter(x['cause'] for x in summary['holds'])),clips=summary['holds'],policy='No regeneration of good clips; repeated source errors stay HOLD; no further automatic attempts',normal_runtime_missing_frames=0,normal_inactive_draft_missing_slots=63,prior_unchanged_boss_quality_followups=read(B/'whole-review-v01/remaining-errors.json')['prior_unchanged_bosses_requiring_dedicated_quality_review_followup'])
    write(HERE/'remaining-errors.json',remaining)
    connections=ROOT/'data/pr122_monster_boss_runtime_connections.json';registry=read(connections);plan=read(HERE/'default-connection/connection-plan.json')
    for a in plan['actors']:
        assert not any(x['id']==a['key'] for x in registry['connections'])
        registry['connections'].append(dict(id=a['key'],frames=a['frames'],frames_sha256=a['frames_sha256'],status='CONNECTED_REVIEWED',required_clips=33,source_poses=a['poses'],formal_approval_history_unchanged=True))
    registry['additional_validations']=[(HERE/'default-connection/final-validation.json').relative_to(ROOT).as_posix()]
    write(connections,registry)
    before=read(HERE/'default-connection/prior-catalog.json');catalog=read(ROOT/'data/combat_animation_profiles.json');keys={a['key'] for a in plan['actors']}
    assert all(catalog['profiles'][k]==v for k,v in before['profiles'].items() if k not in keys)
    modified=git('diff','--name-only','--diff-filter=MD',BASE,'--','assets').splitlines();assert not modified,'Prior art must remain unchanged'
    receipts=[]
    for p in B.glob('*/*-receipt.json'):
        d=read(p);assert sha(ROOT/d['source'])==d['sha256'];receipts.append(dict(path=d['source'],sha256=d['sha256'],bytes=d['bytes']))
    write(HERE/'source-delivery-pins.json',dict(canonical_and_action_source_versions=len(receipts),first_draft_slots=495,newly_filled_slots=210,targeted_corrected_sheets=82,kurtz_corrected_poses=2,prior_assets_modified_or_deleted=modified,sources=receipts))
    lines=['# PR122 몬스터 제작 마감 — 2026-10-24','',
      '- 일반: 현재 게임 경로 258종 / 8,514개 필수 요청 누락 0. 기존 93개 SpriteFrames와 433개 PNG의 SHA가 동일하다. 비활성 초안 12종의 미작성 63슬롯은 별도 보존했다.',
      '- 보스 전용 초안: 15종 × 33시트 = 495/495. 이번에 남아 있던 210시트를 모두 제작·저장했다. 방향/원화 보완 82시트와 커츠 피격 2포즈를 추가했다.',
      '- 최종 사용 가능 초안: 458클립. 보스 2종(알비노 유니콘·테베 아누비스)은 33클립 전체가 준비됐고 커츠는 남은 W HIT를 수정했다. 세 보스를 기본 게임 경로에 반영했다.',
      '- 기존 완료 장부의 일반 221/258, 보스 43/60 승인 이력은 변경하지 않았다. 이번 초안 생성 수를 기존 승인 완료 수로 바꾸지 않았다.',
      '- 원화 픽셀을 보존한 겹침 수정: 신규210 중98시트, 보완본35시트, 그리드 메타데이터 수정12시트. 원본 PNG 재생성/덮어쓰기 없이 RGBA 역변환 검사 통과.',
      '- 수정/영향 구간113클립 Godot1x 재생 통과. 최종15개 프로필 통합 로딩·변경 구간 재생 통과. 실제 Main에서 세 보스144개 요청과24회 공격 이벤트를 확인했고, 의존 자산 복구 후 영향받는 기동만 재확인해 오류0을 확인했다.',
      '- HOLD37클립: 원화 잘림/포즈 소속 불명확/반복 방향 오류 및 제니스 퀸 SW 공격 생성 서비스 거부. 정상 클립 재생성과 무한 재시도는 하지 않았다. 상세 원인·목록은 remaining-errors.json에 있다.',
      '- 기존 승인 자산 수정·삭제0, 새 PR/강제 푸시/전체 CI 반복0. 사용자 저장 파일은 격리했다.','',
      '## 이번 남은210 대상','',
      '테베 아누비스, 테베 호루스, 제로스, 그림 리퍼, 공포의 뱀파이어, 교만의 왕자 데우스, 알비노 유니콘, 오만한 우그누스, 왜곡의 제니스 퀸, 욥니르, 질투의 공주 이자벨.','',
      '## 재개 지점','',
      '보스 잔여37클립과 기존 공용 기반41종의 전용 품질 보완 후보를 별도로 유지한다. 비활성 일반 초안63슬롯은 현재 게임 프레임 누락으로 집계하지 않는다.','']
    (HERE/'DELIVERY_20261024.md').write_text('\n'.join(lines))
    resume=ROOT/'docs/remake/TWILIGHT_PR122_RESUME_20261019.md';text=resume.read_text();marker='## 2026-10-24 남은210 제작 및 마감'
    assert marker not in text
    resume.write_text(text+'\n'+marker+'\n\n남은210시트 제작 완료. 전용 초안495/495, 사용 가능458클립, HOLD37클립. 일반 게임 경로258종의 프레임 누락0. 알비노 유니콘·테베 아누비스·커츠 기본 경로 반영 및 실제Main 검증. 상세: [마감 기록](evidence/pr122-monsters-20261023/boss-draft-first/corrections-v01/DELIVERY_20261024.md).\n')
    paths=set()
    for folder in [HERE,ROOT/'assets/actors/eight_direction/boss_draft_first',ROOT/'assets/actors/eight_direction/monster_boss_repair/kurtz',B.parent/'boss-production-r003/kurtz-motion']:
        paths.update(p for p in folder.rglob('*') if p.is_file() and p.suffix in ['.png','.tres','.py','.js','.json','.jpg','.gd','.txt','.md'] and '__pycache__' not in p.parts)
    for a in plan['actors']:paths.add(ROOT/a['frames'].removeprefix('res://'))
    for a in summary['actors']:paths.add(ROOT/a['candidate'])
    paths.update(B.glob('*.py'));paths.update((B/'resume210-v01').glob('*.py'));paths.update((B/'resume210-v01').glob('*.txt'))
    paths.update([connections,ROOT/'data/combat_animation_profiles.json',ROOT/'data/pr122_monster_boss_repair_staging.json',resume])
    for p in B.glob('*/reviewed-fixes-v01/candidate.json'):paths.add(p)
    with open('/tmp/twilight-pr122-production-git.lock','w') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        subprocess.run(['git','add','--sparse','-f','--',*(p.relative_to(ROOT).as_posix() for p in sorted(paths))],cwd=ROOT,check=True)
        subprocess.run(['git','diff','--cached','--check'],cwd=ROOT,check=True)
        assert not git('diff','--cached','--name-only','--diff-filter=D'),'Never delete approved assets'
        subprocess.run(['git','commit','--quiet','-m','[skip ci] Complete remaining210 boss drafts and publish three reviewed bosses'],cwd=ROOT,check=True)
    print(json.dumps(dict(commit=git('rev-parse','HEAD'),first_draft_slots=495,selected_clips=458,holds=37,new_default_bosses=3,normal_missing_frames=0)))
if __name__=='__main__':main()
