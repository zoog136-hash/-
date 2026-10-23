#!/usr/bin/env python3
"""Coverage and evidence ledger; missing footage never becomes VERIFIED."""
import json, collections
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/skills/vfx-20261023'

def main():
    OUT.mkdir(exist_ok=True)
    data=ROOT/'data/skills'
    master=json.loads((data/'master.json').read_text())['records']
    inventory=json.loads((data/'research_inventory.json').read_text())['records']
    manifest=json.loads((data/'authored_vfx.json').read_text())
    bindings=json.loads((data/'external_spx_name_bindings.json').read_text())['bindings']
    sources=[
        {'key':'knight-20240925','class':'기사','version':'VANGUARD / 2024-09-25',
         'url':'https://lineagem.plaync.com/preorder/record/vanguard/index',
         'status':'BLOCKED_VIDEO','note':'Official video link found via dated article; YouTube blocked by proxy (403).'},
        {'key':'thunder-20250618','class':'뇌신','version':'RISING STORM / 2025-06-18',
         'url':'https://lineagem.plaync.com/conts/250604_update',
         'status':'PARTIAL_METADATA_ONLY','note':'Official branding MP4 inspected at 30fps, duration 31.866667s. Cinematic, not in-game skill timing.'},
        {'key':'holy-20260318','class':'신성검사','version':'ContiNew / 2026-03-18',
         'url':'https://lounge.plaync.com/feed/62463',
         'video':'https://www.youtube.com/watch?v=l9IgJrC1y0A',
         'status':'BLOCKED_VIDEO','note':'Official embedded video identity found; no decoded combat frames.'},
        {'key':'dragon-20260909','class':'투사','version':'THE GOLDEN AGE / 2026-09-09',
         'url':'https://lounge.plaync.com/feed/80923?country=KR&locale=ko-KR',
         'video':'https://www.youtube.com/watch?v=H82Svb2lihs',
         'status':'BLOCKED_VIDEO','note':'YouTube 403. Four direct official MP4s inspected: 5/6/6/4 seconds, 30fps; animated key art, not combat.'},
    ]
    (OUT/'references.json').write_text(json.dumps({'cutoff_exclusive':'2026-10-23','sources':sources,
        'measurement_rule':'Original ms/frame fields remain null until a decoded in-game sequence is inspected.',
        'original_skill_sequences_measured':0},ensure_ascii=False,indent=2)+'\n')
    rows=[]
    for skill in master:
        sid=skill['id'];p=manifest['profiles'][sid]
        playback='INHERITS_BASE_NO_NEW_VISUAL_CLAIM' if 'inherits_visual' in p else 'AUTHORED_STUDY' if 'atlas' in p else 'NO_STANDALONE_VISUAL_EVENT'
        rows.append({'id':sid,'name':skill['name'],'class':skill['class'],'mode':skill['mode'],
            'runtime_effect':skill['runtime_effect'],'original_video':'UNVERIFIED','partial_visual_observation':False,
            'original_timing_ms':None,'original_frame_numbers':None,'before_after_reboot_visual_delta':'UNVERIFIED',
            'source_spx':'AVAILABLE_PC_SOURCE_NOT_LINEAGEM' if sid in bindings else 'NONE_NAME_MATCHED',
            'current_playback':playback,'profile':sid,'inherits':p.get('inherits_visual'),
            'program':p['program'],'atlas':p.get('atlas'),'visual_approval':'PENDING',
            'remaining':'Decode dated in-game footage, measure full phase sequence, compare at equal camera scale and eight directions; Android device check.'})
    (OUT/'runtime-125.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
    lines=['# 125개 런타임 연결 — 제작/검증을 구분한 상태표','',
        '원작 영상 프레임 비교 완료 0. 모든 자체 리소스는 제작 중인 독립 대체 연출이며 고증 승인 수가 아니다.',
        '', '| 직업 | 스킬 | ID | 런타임 동작 | 현재 재생 | 원작 영상 | PC SPX |',
        '|---|---|---|---|---|---|---|']
    for x in rows: lines.append(f"| {x['class']} | {x['name']} | `{x['id']}` | {x['mode']} | {x['current_playback']} | UNVERIFIED | {x['source_spx']} |")
    (OUT/'RUNTIME_125.md').write_text('\n'.join(lines)+'\n')
    ids={s['id'] for s in master}
    pending=[{'id':s['id'],'name':s['name'],'class':s['class'],'implementation':s['implementation'],
        'in_runtime':s['id'] in ids,'original_visual':'UNVERIFIED',
        'blocked_reason':s.get('blocked_reason'),'next':'Dated combat frames + runtime mechanic support; do not unlock from visual evidence.'} for s in inventory]
    (OUT/'research-695.json').write_text(json.dumps(pending,ensure_ascii=False,indent=2)+'\n')
    new=[{'name':n,'class':c,'runtime_id':None,'status':'RESEARCH_ONLY_NO_UNLOCK','visual':'UNVERIFIED','reference':src}
         for n,c,src in [('할파스','투사','dragon-20260909'),('팬텀 체인','투사','dragon-20260909'),('브레스 스턴','투사','dragon-20260909'),('썬더 플릭','뇌신','thunder-20250618'),('라그나로크','뇌신','thunder-20250618')]
         if n not in {s['name'] for s in master}]
    (OUT/'reboot-research-only.json').write_text(json.dumps(new,ensure_ascii=False,indent=2)+'\n')
    summary={'runtime_records':len(rows),'inventory_records':len(inventory),'classes':13,
        'playback_counts':dict(collections.Counter(x['current_playback'] for x in rows)),
        'inventory_implementation_counts':dict(collections.Counter(x['implementation'] for x in pending)),
        'new_public_atlases':len(manifest['assets']),'authored_cells':sum(x['frames'] for x in manifest['assets']),
        'blocked_preview_only':len(manifest.get('preview_profiles',{})),
        'original_visual_approvals':0,'android_device':'NOT_RUN','final_full_ci':'DEFERRED_UNTIL_PRODUCTION_COMPLETE'}
    (OUT/'coverage-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(summary,ensure_ascii=False))

if __name__=='__main__':main()
