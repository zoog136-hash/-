#!/usr/bin/env python3
"""Pin attempted edits, selected source-plane improvement and explicit remaining holds."""
from pathlib import Path
import json
import sys
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[5]
sys.path.insert(0,str(ROOT/'tools'))
import import_original_based_motion as core
from build_pr122_monster_batch import preserve,json_bytes

BATCH=Path('docs/remake/evidence/pr122-monsters-20261023/boss-fix07-zombie-e')
BASE=ROOT/BATCH
KEY='monster:죽음의 좀비 로드'


def pin(path):
    p=ROOT/path
    return {'path':str(path),'bytes':p.stat().st_size,'sha256':core.sha(p)}


def finish():
    register=json.loads((BASE/'candidate.json').read_text());actor=register['actors'][KEY]
    previous=json.loads((ROOT/register['previous_candidate']).read_text())['actors'][KEY]
    assert core.sha(ROOT/register['previous_candidate'])==register['previous_candidate_sha256']
    assert actor['native_track_count']==33 and actor['native_pose_count']==116
    assert not actor['production_connected'] and not actor['detailed_completed']
    old={(t['role'],t['direction']):t for t in previous['tracks']}
    unchanged=0
    for t in actor['tracks']:
        for f in t['geometry']['frames']:
            source=f.get('source',t['source']);texture=f.get('texture',t['texture']);sha=f.get('source_sha256',t['source_sha256'])
            assert core.sha(ROOT/source)==sha==core.sha(ROOT/texture)
        if (t['role'],t['direction'])==('run','E'):continue
        for before,after in zip(old[(t['role'],t['direction'])]['geometry']['frames'],t['geometry']['frames']):
            for field in ['region','source_anchor','rgba_sha256']:assert before[field]==after[field]
            unchanged+=1
    assert unchanged==110
    attempts=[
      ('zombie-lord-E-far-left-plant-single-v01','d2f376d6-23c2-4912-83a9-c26245a73ca5',1,[],
       'Near large thigh still connects to forward grounded sole, only smaller far leg lifts behind. Independent queen reviewer agrees; semantic HOLD. Core2048 fit error is an importer limit, not a visual-quality rejection.'),
      ('zombie-lord-E-far-left-support3-guide-v01','b93e1921-3cf6-46b6-a4e1-4aad1538df8d',3,[1,2],
       'Row0 retains near support and is excluded. Rows1/2 clearly raise large near thigh/foot with smaller far leg grounded; independent queen reviewer confirms partial source-plane improvement.'),
      ('zombie-lord-E-run6-structural-final-v01','3dbb77ff-d284-45d4-8a21-01f0c512abdc',6,[4],
       'As a whole ordered sheet rows0/3 still repeat near support, so whole6 rejected. Only reviewed row4 far support selected; every raw pixel and all failed source poses preserved.')]
    records=[]
    for name,uuid,rows,selected,findings in attempts:
        source=BATCH/'raw'/(name+'.png');qpath=BATCH/'requests'/(name+'.json');q=json.loads((ROOT/qpath).read_text())
        original=Path('/workspace/generated_images')/('exec-'+uuid+'.png')
        assert original.read_bytes()==(ROOT/source).read_bytes()
        rec={'source':pin(source),'exact_request':pin(qpath),'original_generated_path':str(original),
             'raw_pose_slots':rows,'selected_source_rows':selected,'actual_source_findings':findings,
             'whole_sheet_as_ordered_RUN':'HOLD','new_approval':False}
        try:
            g=core.analyze(ROOT/source,rows,q['reference_rows'],directions_axis=q['directions_axis'],canvas_size=2048,directions=['E'])
            core.require_complete_pose_regions(ROOT/source,g);rec['strict_whole_source_geometry']='PASS'
        except ValueError as error:
            rec.update(strict_whole_source_geometry='IMPORTER_LIMIT_UNSELECTED',importer_note=str(error))
        alpha=np.asarray(Image.open(ROOT/source).convert('RGBA'))[:,:,3]
        rec.update(alpha0_fraction=float((alpha==0).mean()),low_alpha_1_to100_fraction=float(((alpha>0)&(alpha<=100)).mean()))
        records.append(rec)
    preserve(BASE/'generation-provenance.json',json_bytes(records))
    independent={
        'reviewer_agent':'/root/queen_run_production','method':'Actual private vision comparison of proposed mixed6 and original E0; text-only findings returned.',
        'examined':pin(BATCH/'qa-proposed-mixed-E6-private.png'),'reference':pin(BATCH/'reference-E-phase0.png'),
        'examined_phases':[0,1,2,3,4,5],'source_support_improvement':'CONFIRMED_NARROW_SOURCE_PLANE_FINDING',
        'findings':['0→3 changes large near leg from upright grounded stance to bent airborne foot, with the smaller far leg taking support.',
            'All selected bodies retain the same right-facing quarter/side orientation. No camera reversal or serious body collapse was observed.',
            'Phase3 head/torso appears slightly smaller than phase0; crouching and source differences are mixed, so final size review remains pending.',
            'Phases3/5 have similar support poses and near half lacks forward swing; full RUN/gait approval remains HOLD.'],
        'quoted_reply_ko':'혼합6 private 시트를 실제 대조했습니다. 0→3에서 근접 큰 다리의 직립 접지→구부려 공중에 든 자세, 그 뒤 far다리의 지지로 바뀌는 것이 명확합니다. 전부 같은 우향3/4 몸통이라 새 카메라 뒤집힘/심한 신체붕괴는 안 보입니다. phase3 머리/몸통이0보다 약간 작아 보이지만 crouch와혼재하므로 크기최종QA는 유지하세요. 새6에는 phase3/5 유사지지와nearhalf앞swing부족이 남아 fullRUN/gait승인은HOLD가 타당합니다. 원지지반복보다0↔3 명확한 개선은 인정할 수 있습니다.',
        'new_approval':False,'Main':'NOT_REVIEWED_BY_THIS_AGENT'}
    preserve(BASE/'independent-source-review.json',json_bytes(independent))
    review={
        'actor':KEY,'revision':'r003','status':'HOLD','approval_preserved':True,'approval_mutated':False,'new_approval':False,
        'candidate':pin(BATCH/'candidate.json'),'previous_candidate':pin(register['previous_candidate']),
        'new_generated_raw_PNGs':3,'new_generated_pose_slots_including_failed_trials':10,
        'selected_new_source_poses':3,'reused_r002_source_poses':113,'unmodified_other_110_pose_RGBA':True,
        'actual_examined_new_sources':[r['source'] for r in records],'actual_examined_E_playback_phases':[0,1,2,3,4,5],
        'observed_support_sequence':['near_RIGHT','near_RIGHT','near_RIGHT','far_LEFT','far_LEFT','far_LEFT'],
        'selected_source_rows':['r002_E0','r002_E1','r002_E4','guide1','guide2','final4'],
        'actual_before_after':'Original r002 E0/E3 both near support. Selected r003 phase0 is nearRIGHT grounded; phase3 is nearRIGHT airborne/farLEFT grounded, independently confirmed.',
        'identity_camera_findings':'Large belly, chains, shoulder/back nails, empty fists, gray mottled skin and right-facing body retained. Source-plane support improvement does not establish final mythic quality.',
        'remaining_holds':['Near half lacks a complete forward swing arc and far half repeats a bent-under support pose at3/5; timing/gait continuity remains incomplete.',
            'Cross-source head/torso size and pivot continuity need root in-game rendering; phase3 appears slightly smaller to independent reviewer.',
            'Low-alpha brown halo visible in source previews; no alpha cleanup performed. New whole-source low-alpha fraction4.3% is comparable to r002 E4.52%, but actual ground compositing needs review.',
            'Actual gameplay weight, contact target synchronization and default Main not reviewed here.'],
        'reference_height':96,'profile_pixel_scale':128/96,'nominal_display_height':128,
        'metadata_change_only':'All previous PNG/crop RGBA remains unchanged. Virtual margins/canvases rebase64→96 with compensating profile scale; whole-source phase groups share a canvas.',
        'new_walk_sources':0,'source_pixel_edits':0,'source_mirror_operations':0,'source_frame_duplicates':0,
        'actual_loaded_RGBA_proof':pin(BATCH/'godot-playback.json'),
        'Godot':'4.7.2 actual ActorMotion playback33clips/116poses, DBboss speed107, mixed per-frame textures and116loaded RGBA SHA verified.',
        'independent_review':pin(BATCH/'independent-source-review.json'),
        'default_Main':'NOT_RUN_BY_THIS_AGENT','new_runtime_switches':0,
        'further_generation':'STOPPED_AFTER_3_TARGETED_ATTEMPTS; no extra direction attempted because full E gait still HOLD.'}
    preserve(BASE/'visual-review.json',json_bytes(review))
    files=sorted({p for p in BASE.rglob('*') if p.is_file() and p.name!='file-manifest.json'}|
        {p for p in (ROOT/'assets/actors/eight_direction/monster_boss_repair/zombie_lord/r003').rglob('*') if p.is_file()})
    manifest={'schema':'pr122-zombie-e-r003-artifacts-v1','actor':KEY,'revision':'r003','clips':33,'poses':116,
        'new_raw_PNGs':3,'raw_pose_slots_with_failed_trials':10,'selected_new_source_poses':3,'reused_r002_poses':113,
        'other110_RGBA_preserved':True,'source_plane_support_exchange_0_to3':'OBSERVED_AND_INDEPENDENTLY_CONFIRMED',
        'full_RUN_gait_quality':'HOLD','new_approvals':0,'runtime_switches_by_this_agent':0,'git_mutations_by_this_agent':0,
        'files':[pin(p.relative_to(ROOT)) for p in files]}
    preserve(BASE/'file-manifest.json',json_bytes(manifest))
    print(json.dumps({k:v for k,v in manifest.items() if k!='files'}))


if __name__=='__main__':finish()
