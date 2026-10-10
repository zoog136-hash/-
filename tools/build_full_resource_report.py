#!/usr/bin/env python3
"""Report the entire live catalog, separating logic checks from visual review."""
import argparse, collections, hashlib, json, pathlib, shutil, zipfile

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def main():
    p=argparse.ArgumentParser();p.add_argument('--root',type=pathlib.Path,required=True)
    p.add_argument('--audit',type=pathlib.Path,required=True);p.add_argument('--sources',type=pathlib.Path,required=True)
    a=p.parse_args();root=a.root.resolve();audit=a.audit.resolve()
    private=root/'reports/resource-integration';private.mkdir(parents=True,exist_ok=True)
    runtime=read(audit/'repaired-preview/all_catalog_runtime.json')
    if runtime['failures']: raise ValueError('Catalog verification failed')
    gl_path=next((audit/'all-catalog-gl-user').rglob('render.json'),None)
    gl=read(gl_path) if gl_path else {'records':[],'failures':[]}
    if gl['failures']: raise ValueError('Production catalog GL capture failed')
    drawn={r['key']:r for r in gl['records'] if r['passed']}
    gpu_path=next((audit/'all-catalog-capture-user').rglob('render-results.json'))
    gpu=read(gpu_path)
    if gpu['failures'] or gpu['total'] != 723: raise ValueError('Full catalog render incomplete')
    gpu_by_id={r['game_key']:r['automatic_gpu_render_verified'] for r in gpu['records']}
    shutil.copytree(gpu_path.parent,private/'all-catalog-render',dirs_exist_ok=True)
    counts=read(audit/'original-bindings/original_binding_summary.json')
    summary=read(audit/'catalog-motion/catalog_summary.json')
    manifest=read(root/'data/visuals/runtime_manifest.json')
    catalog=read(root/'data/catalog_v19.json')
    for category,kind in [('변신','transform'),('마법인형','doll'),('성물','relic')]:
        verified={str(r['game_id']):r['passed'] for r in runtime['results'][kind]}
        rows=read(audit/f'catalog-motion/{kind}_sheets.json')
        if len(rows)!=len(catalog[category]): raise ValueError('Incomplete '+category)
        for row in rows:
            row['game_connected']=True
            row['automated_actor_state_verified']=verified.get(str(row['game_id']),False)
            row['manual_all_frames_reviewed']=False
            row['rendered_sample']=kind+':'+str(row['game_id']) in drawn
            row['production_world_gl_verified']=row['rendered_sample']
            row['production_world_gl_frames']=drawn.get(kind+':'+str(row['game_id']),{}).get('drawn_frames',0)
            row['automatic_gpu_two_pose_verified']=gpu_by_id.get(kind+':'+str(row['game_id']),False)
            row['remaining']='전 프레임 육안 검수; 단일 기준 이미지는 보이지 않는 방향 미복원'
        write(private/f'{kind}_sheets.json',rows)
        summary[kind]['game_verified']=sum(verified.values())
        summary[kind]['manual_reviewed']=0
        summary[kind]['rendered_samples']=sum(key.startswith(kind+':') for key in drawn)
        summary[kind]['automatic_gpu_render_verified']=len(verified)
    write(private/'catalog_summary.json',summary)
    for name in ['monster_bindings','item_bindings']:
        rows=read(audit/f'original-bindings/{name}.json')
        for r in rows:
            if name=='monster_bindings':
                r['connected']=r['source_available'];r['texture_load_verified']=r['source_available']
                r['original_action_animation_verified']=False
            else:
                r['game_connected']=r['original_available'];r['texture_load_verified']=r['original_available']
        write(private/f'{name}.json',rows)
    maps=read(root/'data/maps_v18.json');npc_instances=[];map_rows=[]
    for r in maps:
        field=root/('data/maps/aden_field.json' if r['id']=='aden_world' else 'data/maps/'+r['id']+'.json')
        data=read(field)
        npc_instances.extend(dict(npc,map_id=r['id']) for npc in data.get('npc_spawn',[]))
        map_rows.append({'map_id':r['id'],'name':r['name'],'current_kind':r['kind'],
            'original_terrain_fully_applied':False,'original_tile_texture_available':False,
            'existing_playable_field_preserved':True,'original_visual_state':'원본 이미지 부족 / 현재 게임 맵 유지',
            'source_map_id_verified':False,'available':'L1J MAP/S32 통행·속성 자료 및 뷰어 코드',
            'missing':['지형 타일 텍스처 또는 클라이언트 타일 팩','건물·수목·벽 오브젝트 리소스',
                       '시각 타일 배치와 TWILIGHT 맵의 검증된 원본 ID·좌표 대응'],
            'required_file_types':['client tile/texture pack (for example .til/.pak)','visual segment/tile layout'],
            'rendered_sample':r['id'] in ['aden_world','oman_01','oman_10','albino_04','faith_04']})
    write(private/'all_maps.json',map_rows);write(private/'all_npc_instances.json',npc_instances)
    source_maps=read(root/'data/l1j/maps/source_maps.json')
    s32=read(root/'data/l1j/maps/s32_placements.json')
    write(private/'source_geometry_summary.json',{'converted_cache_count':len(source_maps['maps']),
        'parsed_s32_segments':s32['parsed_segments'],'unparsed_original_s32':s32['failures'],
        'required_tile_ids':s32['missing_tile_ids'],'original_terrain_applied':0})
    sources=read(audit/'sources_summary.json')
    for archive in sorted(a.sources.glob('*.zip')):
        if not archive.name.startswith(('14-','15-','16-','17-')): continue
        with zipfile.ZipFile(archive) as z:
            files=[i for i in z.infolist() if not i.is_dir()]
            sources.append({'source':archive.name,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),
                'files':len(files),'extensions':dict(collections.Counter(pathlib.PurePosixPath(i.filename).suffix.lower() for i in files))})
    write(private/'all_sources.json',sources)
    for name in ['split_original_spx_hashes.json','split_image_hashes.json','additional-sources-inventory.json']:
        shutil.copy2(audit/name,private/name)
    for folder in ['repaired-preview','resume-regression','fade-fix','spx-complete','recovered-originals']:
        shutil.copytree(audit/folder,private/folder,dirs_exist_ok=True)
    initial=read(audit/'resume-regression/summary.json')
    reruns={r['test']:r['passed'] for r in read(audit/'fade-fix/summary.json')}
    for name in ['l1j_png_load_test','l1j_spx_frames_test']:
        log=(audit/f'repaired-preview/{name}.log').read_text()
        reruns[name]='_OK' in log and not any(s in log for s in ['FAIL:','ERROR:'])
    unresolved=[name for name in initial['failed'] if not reruns.get(name)]
    write(private/'verification.json',{'initial_full_suite':initial,'failed_checks_rerun':reruns,
        'remaining_failed_checks':unresolved,'all_catalog_actor_checks':{k:len(v) for k,v in runtime['results'].items()},
        'manual_review_of_every_catalog_frame':False,'baseline_and_new_same_seed':20261010})
    if unresolved: raise ValueError('Unresolved regression failures: '+str(unresolved))
    final=read(audit/'final-regression/summary.json')
    if final['failed']: raise ValueError('Final complete regression failed')
    shutil.copytree(audit/'final-regression',private/'final-regression',dirs_exist_ok=True)
    write(private/'production_catalog_gl.json',gl)
    verification=read(private/'verification.json')
    verification.update(final_full_suite=final,production_world_gl_drawn=len(drawn),production_world_gl_failures=gl['failures'])
    write(private/'verification.json',verification)
    final_path=audit/'final-regression/summary.json'
    if final_path.exists():
        final=read(final_path)
        if final['failed']: raise ValueError('Final broad suite failed')
        shutil.copytree(audit/'final-regression',private/'final-regression',dirs_exist_ok=True)
    placements=read(root/'data/l1j/maps/s32_placements.json')
    caches=read(root/'data/l1j/maps/source_maps.json')
    write(private/'source_map_inventory.json',{'cache_count':len(caches['maps']),
        's32_valid':placements['parsed_segments'],'s32_rejected':len(placements['failures']),
        'required_missing_tile_ids':len(placements['missing_tile_ids']),
        'source_placement_counts':placements['placement_counts'],'original_terrain_playable':False})
    text=f'''# TWILIGHT 원본 리소스 통합 진행 보고서 — 2026-10-11

기준 main: `88d1c68e2a497fb540461a3e1dfa6cba2e1d38f4`. 기존 프로젝트·게임 데이터를 유지한다. PR #59는 수정하지 않는다. 전체 원본 복원은 **미완료**다.

| 분류 | 전체 등록 | 제작·원본 연결 | 자동 검증 | 남은 작업 |
| --- | ---: | ---: | ---: | --- |
| 기본 직업 | 13 | 직업 ID 대응 미확인; 선택형 SPX 본체 2종 | 본체 2종의 8방향·무기·효과 | 13직업의 정확한 원본 ID 및 전용 리소스 |
| 변신 | 413 | 신규 시트 413 | 413 상태 전환·실제 게임 GL 표시 | 전체 프레임 육안 검수; 335종은 기준 시점 1개 |
| 마법인형 | 166 | 신규 시트 166 | 166 소환·따라가기·해제·GL 표시 | 전체 프레임 육안 검수; 107종은 기준 시점 1개 |
| 성물 | 144 | 신규 시트 144 | 144 장착·활성화·해제·GL 표시 | 전체 프레임 육안 검수; 모든 성물은 기준 시점 1개 |
| 일반 몬스터 | 258 | 원본 정적 이미지 {counts['original_normal_images']} ({counts['original_normal_images']/258:.1%}) | 원본 텍스처·동일 계열 공유 | 126종 원본 매핑; 모든 일반 몬스터의 정확한 동작 SPX |
| 보스 | 60 | 기존 고유 외형 유지 60 | 기존 몬스터·전투 회귀 | 추가 원본 ID 고증 |
| 맵 | 25 | 원본 지형 완성 0 / 기존 필드 유지 25 | 이동·경로·포털·저장 회귀 | 원본 시각 타일·텍스처·좌표 대응 |
| 등록 아이템 | 2,129 | 원본 아이콘 420 ({420/2129:.1%}); 전용 바닥 25 | 모든 아이콘 로딩 2,129 | 원본 미매칭 1,709개·전체 아이콘 육안 검수 |
| NPC | 7 유형 / 30 배치 | 기존 배치·대화·상점 유지 | NPC·상점·이동 회귀 | 정확한 원본 외형·배치 고증 |

신규 제작 시트는 총 723개, 41,442프레임이다. 기존 그림의 파츠·메시 리깅으로 제작했다. 원본 SPX나 보이지 않는 8시점을 복원했다고 집계하지 않는다. 기존 4시점은 변신 78개·인형 59개다. 수치상 시트 연결과 모든 프레임의 실제 화면 검수는 다르다.

SPX 1,700개 시퀀스의 14,534프레임을 픽셀 해시로 검사했다. 추가 `a2002.zip`의 원본 1,700개 SPX 해시와 기존 복원본이 전부 일치한다. 21624·21653은 본체, 21625·21654는 그림자, 21626·21655는 효과, 21627·21656은 마스크·광원이다. 선택형 본체에는 무기별 자세·시전·피격·사망·효과 레이어를 연결했다. 본체와 레이어를 독립 캐릭터 수로 합산하지 않는다.

일반 몬스터는 `게임 몬스터 → 계열 → 원본 sprite ID → 텍스처`로 연결한다. 동일 계열은 원본 외형을 공유하고 이름·레벨·HP·AI·드랍·스폰은 독립적으로 유지한다. 보스는 이 공통 매핑에서 제외한다. 원본 몬스터 동작 자료를 확인하지 못했으므로 정적 이미지가 SPX 애니메이션을 갖는다고 보고하지 않는다.

아이템은 정확한 이름·장비 테이블·단일 iconId 조건으로 연결했다. 등록 아이템 420개와 별도 구형 아이템 47개를 구분한다. 인벤토리·상점·도감·퀵슬롯·바닥 드랍은 같은 ID 매핑을 사용한다. 원본 바닥 그림이 없으면 UI 그림을 바닥 표시의 대체 이미지로 사용하며, 전용 바닥 원본으로 집계하지 않는다. 아이콘의 전수 육안 검수는 미완료다.

맵은 전체 25개를 조사했다. A3의 MAP 캐시 전체 1,000개를 원본 좌표·헤더 검증 후 행 우선 바이너리로 변환했고 Godot에서 모두 불러와 해시를 확인했다. S32 1,847개 중 1,845개의 지형·덮개·오브젝트·포털 배치를 파싱했다. 같은 내용의 임시 `tempseg.s32` 2개는 선언된 길이가 맞지 않아 변환하지 않고 원본과 오류 사유를 보존했다. 원본에 기록된 타일 참조는 2,651개다. 자료에는 시각 타일 팩이 없어 기존 25개 필드를 유지했다. 원본 지형 적용률은 0/25다. 행 우선 통행 캐시의 변환 완료를 실제 플레이 필드의 원본 복원 완료로 집계하지 않는다.

검증: Godot 4.7.2 최종 전체 **{final['passed']}/{final['total']}** 검사 통과. 최초 검사 실패 4개를 수정하고 전체 검사를 다시 돌렸다. 새 인형 소환 시 이전 동작 시간을 초기화하고, 해제 검사는 실제 클립 길이까지 확인한다. 원본 설치 상태와 CI 합성 자료도 구분한다. `Main.tscn`의 실제 장착 API로 변신 413개·인형 166개·성물 144개를 각각 표시해 **723/723개**, 1,446개 프레임의 OpenGL 픽셀 변화를 검사했다. Linux llvmpipe 소프트웨어 GL의 자동 확인이다. 각 외형의 모든 동작·프레임을 육안 검수한 결과와 Windows 실기기 결과는 별개이며 아직 미완료다. ZIP에서 압축 해제 후 실행한 결과는 배포 검사 기록에 남긴다.

상세 A~L 산출물은 실행 ZIP의 `reports/resource-integration/`에 포함한다: 전체 소스, 캐릭터 SPX·방향, 변신·인형·성물 개별 시트/동작/프레임, 몬스터 매핑, 전체 맵과 누락 자료, 아이템 매핑, 실행 로그, 화면 비교, GitHub 결과, 배포 검증, 재개 지점.

공개 저장소에는 코드·변환 도구·검증 문서를 반영한다. 사용자 제공 원본 및 파생 이미지 팩은 공개 GitHub에 새로 커밋하지 않고 실행 ZIP에만 포함한다.

재개 지점: `reports/resource-integration/monster_bindings.json`의 미매칭 126종과 `item_bindings.json`의 원본 미매칭 1,709개를 ID 기준으로 검토한다. 시트 723개는 전체 프레임 육안 검수와 기준 이미지에 없는 방향 제작이 남았다. 맵 25개는 시각 타일 팩·원본 맵 ID 및 좌표 대응을 확보한 뒤 변환한다. 같은 실패를 진전 없이 반복하지 않고, 마지막 검증 결과와 이 재개 지점을 보존한다.
'''
    doc=root/'docs/FULL_RESOURCE_INTEGRATION_20261011.md';doc.write_text(text,encoding='utf-8')
    shutil.copy2(doc,private/doc.name)
    write(private/'progress.json',{'complete':False,'counts':counts,'catalog':summary,'maps':25,
        'npc_types':7,'npc_instances':len(npc_instances),'source_archives_inspected':len(sources),
        'final_checks':final['passed'],'final_checks_total':final['total'],
        'production_world_gl_drawn':len(drawn),'source_cache_maps':len(source_maps['maps']),
        's32_parsed_segments':s32['parsed_segments'],'s32_rejected_segments':len(s32['failures'])})
    print('FULL_RESOURCE_REPORT_OK',len(sources),'sources',len(map_rows),'maps',len(npc_instances),'NPC instances')

if __name__=='__main__': main()
