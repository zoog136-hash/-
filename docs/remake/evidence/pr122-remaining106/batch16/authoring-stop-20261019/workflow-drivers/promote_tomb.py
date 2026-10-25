from pathlib import Path
import copy,datetime,hashlib,json,sys
repo=Path('/workspace/twilight');root=Path('/workspace/runtime/batch16');out=repo/'docs/remake/evidence/pr122-remaining106/batch16';source=root/'Tomb-Main-QA-v01/actual-Main'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
def read(p):return json.loads(Path(p).read_text())
def save(p,d):Path(p).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
summary=read(source/'report.json');detail=read(source/'report-cases/tomb-guardian269-batch16-repaired.json');delivery=read(source/'delivery-manifest.json')
assert not summary['failures'] and not detail['failures'] and delivery['native_phases']==112
assert detail['transform_temporal']['rendered_native_phases']==112 and detail['lifecycle']['manual_pickup'] and detail['lifecycle']['death_callbacks']==1
assert detail['pr122_tomb269_smaller_target']['real_hit_count']==1 and len(detail['pr122_tomb269_completed_baseline']['samples'])==40
key='transform:269';actor='tomb_guardian269_batch16_repaired';folder=repo/'assets/actors/eight_direction/original_based'/actor
for p in folder.iterdir():
    if p.suffix in {'.png','.tres'}:assert core.sha(p)==core.sha(root/'Main-project/assets/actors/eight_direction/original_based'/actor/p.name)
path=repo/'data/combat_animation_profiles.json';before=read(path);after=copy.deepcopy(before);assert not before['profiles'][key].get('frames_path')
after['profiles'][key]=read(root/'Main-project/data/combat_animation_profiles.json')['profiles'][key]
assert [k for k in after['profiles'] if after['profiles'][k]!=before['profiles'].get(k)]==[key];core.expansion.save_profiles(path,after)
for p in source.rglob('*.json'):
    if any(x in p.parts for x in ['platform','data','config','cache']):continue
    dest=out/'Tomb-Main-reports'/p.relative_to(source);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(p.read_bytes())
preservation=out/'tomb-source-preservation.json';files=sorted(p for p in folder.iterdir() if p.suffix in {'.png','.tres','.json'})+[repo/'assets/catalog/bace1006d136d422a1bb7fb9.png']
save(preservation,{'purpose':'Full51 whole source PNG/112 genuine poses, resource/provenance/reference; immutable original WIP archives remain preserved','checked_files':[{'path':str(p.relative_to(repo)),'sha256':core.sha(p),'bytes':p.stat().st_size} for p in files]})
decision={'id':key,'name':'거대한 무덤 가디언','status':'APPROVED','decided_UTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'scope':'Local repaired reference-based native completion; no new original-animation recovery or independent human/device approval',
 'species_gates':dict.fromkeys(['source_review','static_image_gate','temporal_gate','game_function_gate','actual_Main_visual_gate','baseline_comparison'],'PASS'),
 'independent_visual_review':'Resuming agent reviewed actual Main E idle/walk/strike, NE idle/gait/recoil, N gait, S recoil, NW terminal collapse; source biomechanical and baseline evidence retained. No human claim.',
 'directions':core.DIRECTIONS,'motion_contract':{'idle':2,'walk':4,'attack':3,'hit':2,'death':3,'unique_poses':112,'run':'No separate verified source run; none invented or claimed'},
 'newly_drawn_poses':0,'preserved_prior_genuine_motion_poses':112,'repaired_existing_poses':14,'new_palette_image_edits':3,'observed_hit_collapse_root_corrections':12,'total_pack_PNG':51,'runtime_connected':True,
 'actual_Main_and_continuous_checks':summary['checks'],'rendered_native_phases':112,'original_real_direction_contacts':8,'extra_SW_real_hits':1,'preserved_completed_baseline_samples':40,
 'memory':{'source_logical_RGBA_bytes':320860080,'Main_child_max_RSS_KiB':read(source/'process-result.json')['child_max_RSS_KiB'],'VRAM':'NOT_MEASURED','Android_device':'NOT_RUN','budget_acceptance':'Device acceptance pending; no Android memory PASS claim'},
 'visual_notes':'Corrected E heavy-cluster reach retains original dark shaft and connected grip; neutral silver/charcoal NE material, rear heel planes, projected foot roots and complete armor retained. Genuine alternating support, connected helmet/core and all eight directions inspected. Body hunch/foreshortening is retained without per-pose scale changes. No stats, AI, collision, actual attack interval/hit count or save changes.',
 'final_CI':'PENDING_BATCH','Android_device':'NOT_RUN','source_preservation_manifest':str(preservation.relative_to(repo)),
 'reviewed_profile_sha256':hashlib.sha256(json.dumps(after['profiles'][key],sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()).hexdigest()}
pins=[preservation,out/'tomb-repaired-candidate.json',out/'tomb-source-restoration.json',out/'Tomb-Main-reports/report.json',out/'Tomb-Main-reports/report-cases/tomb-guardian269-batch16-repaired.json',out/'Tomb-Main-reports/delivery-manifest.json',out/'Tomb-Main-reports/process-result.json']
decision['evidence_pins']=[{'path':str(p.relative_to(repo)),'sha256':core.sha(p)} for p in pins];save(out/'tomb-completion-decision.json',decision)
registry=read(out/'individual-approvals.json');assert key not in {d['id'] for d in registry['decisions']};registry['decisions'].append(decision);registry.update(completed=402,remaining=96,new_completed=10,session_added=8,batch16_added=3);save(out/'individual-approvals.json',registry)
status=read(out/'all498-production-status.json');row=next(x for x in status['species'] if x['id']==key);assert row['production_status']=='SOURCE_HOLD';row.update(production_status='VERIFIED_COMPLETED',reason='Batch16 repaired112 genuine motion poses, actual Main/continuous69875 checks,8 real direction hits+SW single-hit/40 preserved baseline samples. Device memory acceptance remains separate',frames_path=after['profiles'][key]['frames_path']);status['status_counts']['SOURCE_HOLD']-=1;status['status_counts']['VERIFIED_COMPLETED']+=1;status.update(approvals_total=402,session_added=8,batch16_added=3);save(out/'all498-production-status.json',status)
checkpoint=read(repo/'docs/remake/TWILIGHT_REMAINING106_CHECKPOINT.json');checkpoint['counts'].update(completed=402,remaining=96,HOLD=16,new_approved=10);checkpoint['latest_source_status']['batch16'].update(new_completed=3,active='monster:스파이더',new_palette_edits=3);save(repo/'docs/remake/TWILIGHT_REMAINING106_CHECKPOINT.json',checkpoint)
state=read(out/'checkpoint.json');state.update(state='GOLEM_DEER_TOMB269_LOCALLY_COMPLETED; SPIDER128_ACTUAL_MAIN_RUNNING',active='monster:스파이더',new_completed=3,counts=status['status_counts'],normal_completed=388,approvals_total=402,remaining_unapproved=96)
if key not in state['approved_ids']:state['approved_ids'].append(key)
state['remaining_ids']=[x for x in state['remaining_ids'] if x!=key];state['HOLD']=[x for x in state['HOLD'] if x['id']!=key];state['current_ids']=['monster:스파이더','monster:얼음 여왕'];state['active_authoring'][key]={'status':'APPROVED','runtime_connected':True,'proof':str((out/'tomb-completion-decision.json').relative_to(repo)),'remaining_device_limit':'Android device/VRAM not run; no device budget approval'};save(out/'checkpoint.json',state)
print('TOMB269_LOCAL_PRODUCTION_LINKED',summary['checks'],112)
