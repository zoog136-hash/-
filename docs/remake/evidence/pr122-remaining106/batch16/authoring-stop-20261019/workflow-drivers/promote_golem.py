from pathlib import Path
import copy
import datetime
import hashlib
import json
import sys

repo=Path('/workspace/twilight');root=Path('/workspace/runtime/batch16');out=repo/'docs/remake/evidence/pr122-remaining106/batch16'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
def read(path):return json.loads(Path(path).read_text())
def save(path,value):Path(path).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n')
game=read(root/'Main-QA-v02/gameplay.json');temporal=read(root/'Temporal-QA-v01/report.json')
assert not game['failures'] and not temporal['failures']
detail=read(root/'Main-QA-v02/gameplay-cases/albino-mutated-golem.json')
assert not detail['failures'] and len(detail['pose_samples'])==144 and detail['lifecycle']['manual_pickup']
assert detail['lifecycle']['death_callbacks']==1
key='monster:알비노 변이된 골렘';actor='albino_mutated_golem_batch16_authored'
source=root/'Main-project/assets/actors/eight_direction/original_based'/actor
dest=repo/'assets/actors/eight_direction/original_based'/actor
for p in source.iterdir():
    if p.suffix in {'.png','.tres'}:assert core.sha(p)==core.sha(dest/p.name)
profile_path=repo/'data/combat_animation_profiles.json'
before=read(profile_path);after=copy.deepcopy(before)
assert not before['profiles'].get(key,{}).get('frames_path')
after['profiles'][key]=read(root/'Main-project/data/combat_animation_profiles.json')['profiles'][key]
assert [k for k in after['profiles'] if after['profiles'][k]!=before['profiles'].get(k)]==[key]
core.expansion.save_profiles(profile_path,after)
for old,base in [(root/'Main-QA-v02','Main-reports'),(root/'Temporal-QA-v01','Temporal-reports')]:
    target=out/base;target.mkdir(exist_ok=True)
    for p in old.rglob('*.json'):
        if any(x in p.parts for x in ['data','config','cache']):continue
        relative=p.relative_to(old);destination=target/relative;destination.parent.mkdir(parents=True,exist_ok=True)
        destination.write_bytes(p.read_bytes())
decision={'id':key,'name':'알비노 변이된 골렘','status':'APPROVED',
    'decided_UTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'scope':'Local reference-based newly drawn native completion; final integrated CI pending; not recovered SPX and not independent human approval',
    'species_gates':dict.fromkeys(['source_review','static_image_gate','temporal_gate','game_function_gate','actual_Main_visual_gate','baseline_comparison'],'PASS'),
    'independent_visual_review':'Post-authoring raw sheets plus actual Main side/front/back/attack/death reviewed by resuming agent; no independent human claim',
    'directions':core.DIRECTIONS,'motion_contract':{'idle':2,'walk':8,'attack':3,'hit':2,'death':3,'unique_poses':144,'run':'No separately defined run; none invented by speed-up'},
    'newly_drawn_poses':112,'preserved_prior_poses':32,'runtime_connected':True,
    'new_raw_PNG':16,'total_pack_PNG':18,
    'actual_Main_checks':detail['checks'],'with_baseline_gameplay_checks':game['checks'],
    'continuous_with_baseline_checks':temporal['checks'],
    'source_reference_SHA256':'07ed0ffe7904cba821178ee635ac7ee29dc87cdec9c972fbd58683a3447106c9',
    'visual_notes':'Full-height side/front/back poses retain connected fists/head/legs and ground anchors, original crystal model and palette. Whole-sheet resolution canvases preserve model scale; no clipped strike or direction flip in W/NW preparation. No original movement speed, combat intervals, damage, AI, collision or save data changes.',
    'final_CI':'PENDING_BATCH','Android_device':'NOT_RUN'}
save(out/'golem-completion-decision.json',decision)
registry=read(repo/'docs/remake/evidence/pr122-remaining106/batch15/individual-approvals.json')
assert key not in {r['id'] for r in registry['decisions']}
registry['decisions'].append(decision);registry.update(completed=400,remaining=98,new_completed=8,session_added=6,batch16_added=1)
save(out/'individual-approvals.json',registry)
status=read(repo/'docs/remake/evidence/pr122-remaining106/batch15/all498-production-status.json')
row=next(r for r in status['species'] if r['id']==key);assert row['production_status']=='SOURCE_HOLD'
row.update(production_status='VERIFIED_COMPLETED',reason='Batch16 full144 reference-based native pack, actual Main1884 + baseline1484 + continuous81417 checks; new art112, not recovered original SPX',frames_path=after['profiles'][key]['frames_path'])
status['status_counts']['SOURCE_HOLD']-=1;status['status_counts']['VERIFIED_COMPLETED']+=1
status.update(approvals_total=400,session_added=6,batch16_added=1);assert sum(status['status_counts'].values())==498
save(out/'all498-production-status.json',status)
checkpoint=read(repo/'docs/remake/TWILIGHT_REMAINING106_CHECKPOINT.json')
checkpoint['individual_approval_registry']=str((out/'individual-approvals.json').relative_to(repo))
checkpoint['active_batch_checkpoint']=str((out/'checkpoint.json').relative_to(repo))
checkpoint['counts'].update(completed=400,remaining=98,HOLD=18,new_approved=8)
checkpoint['latest_source_status']['batch16']={'newly_drawn_poses':112,'new_completed':1,'active':'monster:알비노 디어','proof':str((out/'golem-completion-decision.json').relative_to(repo))}
save(repo/'docs/remake/TWILIGHT_REMAINING106_CHECKPOINT.json',checkpoint)
state=read(out/'checkpoint.json');state.update(state='GOLEM_LOCALLY_COMPLETED; DEER_REAL_SOURCE_AUTHORING_CONTINUES',new_completed=1,runtime_profile_applied=True,actual_Main='PASS',active='monster:알비노 디어',approved_ids=[key],counts=status['status_counts'],normal_completed=386,approvals_total=400,remaining_unapproved=98,last_safe_commit='213abb8c')
save(out/'checkpoint.json',state)
print('GOLEM_ACTUAL_NATIVE_PRODUCTION_LINKED',json.dumps({'poses':144,'new_drawn':112,'target':key,'normal':386,'approval_total':400,'Main':detail['checks'],'continuous':temporal['checks']},ensure_ascii=False))
