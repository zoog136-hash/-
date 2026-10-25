#!/usr/bin/env python3
"""Summarize actual boss corrections without converting staging into approval."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent
BASE = HERE.parent


def read(path):
    return json.loads(path.read_text())


def main():
    verification = read(HERE / 'selection-verification.json')
    inputs = read(HERE / 'inputs.json')
    baseline = read(HERE / 'baseline.json')
    prior = json.loads(subprocess.check_output(['git', 'show', baseline['source_commit'] + ':data/pr122_monster_boss_repair_staging.json'], cwd=ROOT))
    prior_hashes = {f['rgba_sha256'] for a in prior['actors'].values() for t in a['tracks'] for f in t['geometry']['frames']}
    source_folders = ['boss-fix06-queen-n', 'boss-fix07-zombie-e', 'boss-fix08-demon-e',
                      'boss-fix09-kurtz', 'boss-fix10-queen-diagonal-attack', 'boss-fix11-demon-se-nw']
    raw = {p.relative_to(ROOT).as_posix() for folder in source_folders for p in (BASE / folder).rglob('raw/*.png')}
    remaining = {
        'monster:얼음 여왕': ['기존 N IDLE 0/1의 pale slit 좌우 변화. 새 N RUN 회귀와 구분한다.'],
        'monster:죽음의 좀비 로드': ['E 보행의 약한 전방 swing arc와 3/5 유사 지지 자세.'],
        'monster:알비노 데몬': ['기존 SE RUN 0/3 같은 지지발 반복.', '기존 NW ATTACK의 overhead contact. fix11 수정본은 잘림/영역혼입/도끼 손 반전으로 미채택.'],
        'monster:커츠': ['필수16슬롯 미제작/오류 선택 제외. 상세 목록은 missing_required_tracks를 따른다.'],
    }
    actors, all_hashes, newly_drawn = {}, set(), set()
    for key, path in inputs.items():
        actor = read(ROOT / path)['actors'][key]
        selected = set()
        for track in actor['tracks']:
            for frame in track['geometry']['frames']:
                digest = frame['rgba_sha256']
                all_hashes.add(digest)
                source = str(frame.get('source', track['source'])).removeprefix('res://')
                if source in raw:
                    selected.add(digest)
                    newly_drawn.add(digest)
        actors[key] = dict(clips=actor['native_track_count'], poses=actor['native_pose_count'],
                           newly_generated_selected_poses=len(selected),
                           missing_required_tracks=actor['missing_required_tracks'],
                           native_profile=actor['native_profile'], quality_review=actor['quality_review'],
                           confirmed_remaining_defects=remaining[key],
                           production_connected=False, new_approval=False)
    receipts = [read(path / 'receipt.json') for path in sorted(HERE.glob('arena-*')) if path.is_dir() and (path / 'receipt.json').exists()]
    assert all(r['process']['returncode'] == 0 and not r['process']['script_errors'] for r in receipts)
    summary = dict(schema='pr122-boss-correction-session-summary-v1', date='2026-10-23',
                   baseline_commit=baseline['source_commit'], scope='Boss corrections only; normal frame availability carried forward by exact-byte preservation.',
                   normal=dict(total=258, previously_approved=221, remaining=37,
                               runtime_required_requests=8514, runtime_missing_frames=0,
                               WALK_as_RUN_reuse_requests=2064, art_quality_review_performed=False,
                               separate_new_staging_unmade_slots=baseline['normal_new_staging_unmade_slots']),
                   boss=dict(total=60, historical_approved_preserved=43, remaining=17,
                             corrected_candidates=4, selected_clips=sum(a['clips'] for a in actors.values()),
                             selected_unique_RGBA_poses=len(all_hashes), newly_generated_selected_poses=len(newly_drawn),
                             newly_selected_RGBA_vs_prior_selection=len(all_hashes - prior_hashes),
                             raw_generated_PNGs_including_failed_trials=len(raw),
                             missing_required_selected_slots=sum(len(a['missing_required_tracks']) for a in actors.values()),
                             actors=actors, new_approvals=0, default_catalog_switches=0),
                   verification=dict(normal_profiles_and_scope_rows_preserved=258,
                                     prior_delivered_files_preserved=verification['prior_delivered_files_preserved'],
                                     root_real_speed_viewport_captures=sum(r['captures'] for r in receipts),
                                     root_arena_cases=[case for r in receipts for case in r['cases']],
                                     speed_scale=1, camera_zoom=1, actual_Main=False,
                                     original_ActorMotion=True, full_CI_repeated=False),
                   raw_source_files=sorted(raw), concurrent_history=read(HERE / 'concurrent-merge.json'))
    (HERE / 'session-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    improvements = {
        'monster:얼음 여왕': 'N RUN 의상 좌우·반대발 3자세 수정 + 기존 올바른 3자세 재사용. SE/SW 공격 방향 및 LEFT 지팡이 유지 보완.',
        'monster:죽음의 좀비 로드': 'E RUN 0/3 반대 지지 보완. 실제 새 far-support 3자세 + 기존 113자세 재사용.',
        'monster:알비노 데몬': 'E RUN 측면·반대발 6자세 수정. SE/NW 추가원화3장은 잘림·몸체영역혼입·도끼손 반전으로 미채택.',
        'monster:커츠': 'E/SE/S IDLE·HIT 6클립12자세 추가. 잘못된 카메라·검손 8클립은 선택 제외, 원본 보존.',
    }
    rows = '\n'.join(f"| {key.removeprefix('monster:')} | {a['clips']}/33 | {a['poses']} | {a['newly_generated_selected_poses']} | {improvements[key]} |" for key, a in actors.items())
    hold_rows = '\n'.join('- ' + key.removeprefix('monster:') + ': ' + ' '.join(values) for key, values in remaining.items())
    text = f'''# PR122 보스 확인 후 실제 수정 — 2026-10-23 후속 배치

일반258종의 현재 게임 재생 경로는 필수8,514요청에서 프레임 누락0이다. WALK→RUN 재사용2,064건을 포함하며, 모든 종의 새 전용RUN 완성을 뜻하지 않는다. 이번 작업에서는 일반 외형을 검토하거나 수정하지 않았다. 별도 새 초안의 놀31·알비노몽크32 역할/방향 슬롯 미제작은 유지한다.

기승인43종을 포함한 보스60종의 기존 검토를 바탕으로 수정했다. 추가 바인딩 검사57종(기존 시각통과3 제외),26 SpriteFrames·159PNG·4,584참조에서 누락·잘림·방향alias의 확실한 간편 수정 후보는0이었다. 따라서 확인된 원화 결함을 고쳤다. 새 원화{len(raw)}PNG(실패 포함)를 보존하고 현재4종의 {summary['boss']['selected_clips']}클립/{len(all_hashes)}고유RGBA자세를 선택했다. 이 중 이번에 실제 생성하여 선택한 자세는{len(newly_drawn)}개다.

| 몬스터 | 선택 필수클립 | 고유자세 | 이번 생성 선택자세 | 수정 내용 |
| --- | ---: | ---: | ---: | --- |
{rows}

여왕·좀비로드·데몬의 필수 소스는 각33클립이다. 커츠는 오류8클립을 보존하되 새 선택에서 제외하여 필수16슬롯이 남는다. 이전19→현재17클립의 감소를 제작 퇴행이나 완료로 숨기지 않는다. 새 원화·선택·정속재생 통과와 신화급 최종 승인은 별도로 기록하며 신규승인·기본 게임 카탈로그 교체는0이다. 보스 전체 재작업이 끝난 상태는 아니다.

HOLD 사유는 각 후보의 quality_review와 원화 review.json에 명시했다. 커츠16슬롯, 남은 보스별 보행/무기 동작/의상 연속성 결함을 유지한다. 실제 Main·물리적 타깃 접촉의 미검토는 이번 최소 검증 실패로 바꾸지 않는다.

{hold_rows}

공식 Godot4.7.2와 기존 ActorMotion을 사용해 실제 DB속도·프로필 배율·카메라1·재생1배속으로 검사했다. root OpenGL(llvmpipe) 캡처는{summary['verification']['root_real_speed_viewport_captures']}장이다. headless 원본RGBA/모든소스위상 검사와 정속viewport 검사를 분리했다. 가상 캔버스 발 기준점은 실제 발의 물리 접촉 승인과 구분한다. 원본 PNG/RGBA는 리샘플링하지 않았다.

기존 일반 프로필/분류행258개와 이전 납품 파일{verification['prior_delivered_files_preserved']}개는 바이트/SHA를 보존했다. 기존 승인 원장도 그대로이며, 승인 이력 기준 일반221완료/37잔여·보스43완료/17잔여다. 같은 PR122에서 병행 제작 커밋을 정상 merge로 보존하고 [skip ci]로 저장한다. 새 PR·main 병합·강제푸시·전체CI 재실행은 없다.

재현: inputs.json → verify_candidates.py --select → tools/reclassify_pr122_monsters.py → 같은 도구 --check. 개별 고정 원화·TRES·QA의 경로/크기/SHA는 각 file-manifest와 최종 delivery-manifest.json을 따른다. 저장 SHA와 실제 GitHub PNG 다운로드 증거는 delivery receipt를 따른다.
'''
    (HERE / 'README.md').write_text(text)
    print(json.dumps(dict(selected_clips=summary['boss']['selected_clips'], unique_poses=len(all_hashes), newly_drawn_selected=len(newly_drawn), raw_PNGs=len(raw), captures=summary['verification']['root_real_speed_viewport_captures']), ensure_ascii=False))


if __name__ == '__main__':
    main()
