from pathlib import Path
import copy,datetime,hashlib,json,sys
repo=Path('/workspace/twilight');root=Path('/workspace/runtime/batch16');out=repo/'docs/remake/evidence/pr122-remaining106/batch16'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
def read(p):return json.loads(Path(p).read_text())
def save(p,d):Path(p).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
game=read(root/'Deer-Main-QA-v01/gameplay.json');temporal=read(root/'Deer-Temporal-QA-v01/report.json');detail=read(root/'Deer-Main-QA-v01/gameplay-cases/albino-deer.json')
assert not game['failures'] and not temporal['failures'] and not detail['failures']
assert len(detail['pose_samples'])==144 and detail['lifecycle']['manual_pickup'] and detail['lifecycle']['death_callbacks']==1
key='monster:알비노 디어';actor='albino_deer_batch16_authored';folder=repo/'assets/actors/eight_direction/original_based'/actor
for p in folder.iterdir():
    if p.suffix in {'.png','.tres'}:assert core.sha(p)==core.sha(root/'Main-project/assets/actors/eight_direction/original_based'/actor/p.name)
path=repo/'data/combat_animation_profiles.json';before=read(path);after=copy.deepcopy(before)
assert not before['profiles'].get(key,{}).get('frames_path')
after['profiles'][key]=read(root/'Main-project/data/combat_animation_profiles.json')['profiles'][key]
assert [k for k in after['profiles'] if after['profiles'][k]!=before['profiles'].get(k)]==[key]
core.expansion.save_profiles(path,after)
for source,name in [('Deer-Main-QA-v01','Deer-Main-reports'),('Deer-Temporal-QA-v01','Deer-Temporal-reports')]:
    for p in (root/source).rglob('*.json'):
        if any(x in p.parts for x in ['data','config','cache']):continue
        dest=out/name/p.relative_to(root/source);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(p.read_bytes())
preservation=out/'deer-source-preservation.json'
files=sorted(p for p in folder.iterdir() if p.suffix in {'.png','.tres','.json'})+[repo/'assets/monsters/original/atlas_4.png']
save(preservation,{'purpose':'Whole authored144 pose sources plus preserved original project reference; no recovered SPX claim','checked_files':[{'path':str(p.relative_to(repo)),'sha256':core.sha(p),'bytes':p.stat().st_size} for p in files]})
decision={'id':key,'name':'알비노 디어','status':'APPROVED','decided_UTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'scope':'Local newly authored reference-based native completion; final integrated CI pending, not recovered SPX or independent human approval',
 'species_gates':dict.fromkeys(['source_review','static_image_gate','temporal_gate','game_function_gate','actual_Main_visual_gate','baseline_comparison'],'PASS'),
 'independent_visual_review':'Resuming agent reviewed actual Main E idle/attack, SE/W gait, N attack, NW death. No independent human claim.',
 'directions':core.DIRECTIONS,'motion_contract':{'idle':2,'walk':8,'attack':3,'hit':2,'death':3,'unique_poses':144,'run':'No separate source run defined; none invented'},
 'newly_drawn_poses':56,'preserved_prior_poses':88,'new_raw_PNG':12,'total_pack_PNG':17,'runtime_connected':True,
 'actual_Main_checks':detail['checks'],'with_baseline_gameplay_checks':game['checks'],'continuous_with_baseline_checks':temporal['checks'],
 'source_reference_SHA256':core.sha(repo/'assets/monsters/original/atlas_4.png'),
 'visual_notes':'Broad antler silhouette, connected neck/body/hooves retained. Four-beat walk64 and three-phase lowered-antler attack24 preserve complete raw source bounds. One whole-source canvas calibrated to full-height recovery prevents enlarged low-head impact. Ground and eight-view transitions reviewed. No gameplay stats, AI, collision or save changes.',
 'final_CI':'PENDING_BATCH','Android_device':'NOT_RUN','source_preservation_manifest':str(preservation.relative_to(repo)),
 'reviewed_profile_sha256':hashlib.sha256(json.dumps(after['profiles'][key],sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()).hexdigest()}
pins=[preservation,out/'deer-candidate.json',out/'Deer-Main-reports/gameplay.json',out/'Deer-Main-reports/gameplay-cases/albino-deer.json',out/'Deer-Temporal-reports/report.json',out/'Deer-Temporal-reports/report-cases/albino-deer.json']
decision['evidence_pins']=[{'path':str(p.relative_to(repo)),'sha256':core.sha(p)} for p in pins]
save(out/'deer-completion-decision.json',decision)
registry=read(out/'individual-approvals.json');assert key not in {d['id'] for d in registry['decisions']}
registry['decisions'].append(decision);registry.update(completed=401,remaining=97,new_completed=9,session_added=7,batch16_added=2);save(out/'individual-approvals.json',registry)
status=read(out/'all498-production-status.json');row=next(x for x in status['species'] if x['id']==key);assert row['production_status']=='SOURCE_HOLD'
row.update(production_status='VERIFIED_COMPLETED',reason='Batch16 full144 reference-based native pack, actual Main3272 with baseline and continuous81417 checks; new art56 preserved prior88, not SPX originals',frames_path=after['profiles'][key]['frames_path'])
status['status_counts']['SOURCE_HOLD']-=1;status['status_counts']['VERIFIED_COMPLETED']+=1;status.update(approvals_total=401,session_added=7,batch16_added=2);assert sum(status['status_counts'].values())==498;save(out/'all498-production-status.json',status)
checkpoint=read(repo/'docs/remake/TWILIGHT_REMAINING106_CHECKPOINT.json');checkpoint['counts'].update(completed=401,remaining=97,HOLD=17,new_approved=9)
checkpoint['latest_source_status']['batch16'].update(newly_drawn_poses=168,new_completed=2,active='transform:269');save(repo/'docs/remake/TWILIGHT_REMAINING106_CHECKPOINT.json',checkpoint)
state=read(out/'checkpoint.json');state.update(state='GOLEM_AND_DEER_LOCALLY_COMPLETED; TOMB269_SOURCE_RESTORATION_CONTINUES',active='transform:269',new_completed=2,newly_drawn_poses=168,counts=status['status_counts'],normal_completed=387,approvals_total=401,remaining_unapproved=97,last_safe_commit='844a2633')
if key not in state['approved_ids']:state['approved_ids'].append(key)
state['active_authoring'][key].update(status='APPROVED',complete_approved_source_matrix=True,blocker='None for local native five-motion contract; final integrated CI and Android device verification separate',next='Retain approved whole-source pack and original raw failures',runtime_connected=True,proof=str((out/'deer-completion-decision.json').relative_to(repo)))
save(out/'checkpoint.json',state)
print('DEER_PRODUCTION_CONNECTED',game['checks'],temporal['checks'])
