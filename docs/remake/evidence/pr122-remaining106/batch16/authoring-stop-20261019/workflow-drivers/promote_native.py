"""Adopt an explicitly visually reviewed exact QA pack, never infer source approval."""
from pathlib import Path
import copy,datetime,hashlib,json,sys
repo=Path('/workspace/twilight');root=Path('/workspace/runtime/batch16');out=repo/'docs/remake/evidence/pr122-remaining106/batch16'
sys.path.insert(0,str(repo/'tools'));import import_original_based_motion as core
def read(p):return json.loads(Path(p).read_text())
def save(p,d):Path(p).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
config=read(sys.argv[1]);assert config['visual_decision']['species_gates'] and all(v=='PASS' for v in config['visual_decision']['species_gates'].values())
key=config['key'];actor=config['actor'];slug=config['slug'];label=config['label']
main=root/config['main'];temporal=root/config['temporal']
game=read(main/'gameplay.json');continuous=read(temporal/'report.json');detail=read(main/'gameplay-cases'/(slug+'.json'))
assert not game['failures'] and not continuous['failures'] and not detail['failures']
assert len(detail['pose_samples'])==config['poses'] and detail['lifecycle']['manual_pickup'] and detail['lifecycle']['death_callbacks']==1
folder=repo/'assets/actors/eight_direction/original_based'/actor
for p in folder.iterdir():
    if p.suffix in {'.png','.tres'}:assert core.sha(p)==core.sha(root/'Main-project/assets/actors/eight_direction/original_based'/actor/p.name)
path=repo/'data/combat_animation_profiles.json';before=read(path);after=copy.deepcopy(before);assert not before['profiles'].get(key,{}).get('frames_path')
after['profiles'][key]=read(root/'Main-project/data/combat_animation_profiles.json')['profiles'][key]
assert [k for k in after['profiles'] if after['profiles'][k]!=before['profiles'].get(k)]==[key];core.expansion.save_profiles(path,after)
main_label=config.get('main_label',label);temporal_label=config.get('temporal_label',label)
for source,name in [(main,main_label+'-Main-reports'),(temporal,temporal_label+'-Temporal-reports')]:
    for p in source.rglob('*.json'):
        if any(x in p.parts for x in ['data','config','cache']):continue
        dest=out/name/p.relative_to(source);dest.parent.mkdir(parents=True,exist_ok=True)
        if dest.exists():assert dest.read_bytes()==p.read_bytes()
        else:dest.write_bytes(p.read_bytes())
target=next(x for x in read(repo/'data/animation_authoring_sources.json')['targets'] if x['key']==key)
reference=repo/target['reference']['path'].removeprefix('res://')
preservation=out/(label+'-source-preservation.json');files=sorted(p for p in folder.iterdir() if p.suffix in {'.png','.tres','.json'})+[reference]
proof=read(folder/'provenance.json')
for shared in proof.get('retargeting',{}).get('shared_texture_files',[]):
    p=repo/shared['path'];assert core.sha(p)==shared['SHA256'];files.append(p)
save(preservation,{'purpose':'Whole newly authored native source/provenance/resource plus exact original project reference; no recovered SPX claim','checked_files':[{'path':str(p.relative_to(repo)),'sha256':core.sha(p),'bytes':p.stat().st_size} for p in files]})
decision=copy.deepcopy(config['visual_decision']);decision.update(id=key,name=target['name'],status='APPROVED',decided_UTC=datetime.datetime.now(datetime.timezone.utc).isoformat(),
 scope='Local reference-based native completion, final integrated CI/device acceptance separate; no independent human claim',
 runtime_connected=True,actual_Main_checks=detail['checks'],with_baseline_gameplay_checks=game['checks'],continuous_with_baseline_checks=continuous['checks'],
 source_reference_SHA256=core.sha(reference),final_CI='PENDING_BATCH',Android_device='NOT_RUN',source_preservation_manifest=str(preservation.relative_to(repo)),
 reviewed_profile_sha256=hashlib.sha256(json.dumps(after['profiles'][key],sort_keys=True,ensure_ascii=False,separators=(',',':')).encode()).hexdigest())
pins=[preservation,out/config['candidate'],out/(main_label+'-Main-reports/gameplay.json'),out/(main_label+'-Main-reports/gameplay-cases/'+slug+'.json'),out/(temporal_label+'-Temporal-reports/report.json'),out/(temporal_label+'-Temporal-reports/report-cases/'+slug+'.json')]
decision['evidence_pins']=[{'path':str(p.relative_to(repo)),'sha256':core.sha(p)} for p in pins];save(out/(label+'-completion-decision.json'),decision)
registry=read(out/'individual-approvals.json');assert key not in {d['id'] for d in registry['decisions']};registry['decisions'].append(decision)
for field in ['completed','new_completed','session_added','batch16_added']:registry[field]=registry.get(field,0)+1
registry['remaining']-=1;save(out/'individual-approvals.json',registry)
status=read(out/'all498-production-status.json');row=next(x for x in status['species'] if x['id']==key);previous=row['production_status'];assert previous in ['SOURCE_HOLD','NOT_AUTHORED','IN_PROGRESS']
row.update(production_status='VERIFIED_COMPLETED',reason=config['completion_reason'],frames_path=after['profiles'][key]['frames_path']);status['status_counts'][previous]-=1;status['status_counts']['VERIFIED_COMPLETED']+=1
for field in ['approvals_total','session_added','batch16_added']:status[field]+=1
assert sum(status['status_counts'].values())==498;save(out/'all498-production-status.json',status)
checkpoint=read(repo/'docs/remake/TWILIGHT_REMAINING106_CHECKPOINT.json');checkpoint['counts'].update(completed=registry['completed'],remaining=registry['remaining'],HOLD=status['status_counts']['SOURCE_HOLD'],new_approved=registry['new_completed'])
checkpoint['latest_source_status']['batch16'].update(new_completed=registry['batch16_added'],active=config['next_active']);checkpoint['latest_source_status']['batch16']['newly_drawn_poses']+=decision.get('newly_drawn_poses',0);save(repo/'docs/remake/TWILIGHT_REMAINING106_CHECKPOINT.json',checkpoint)
state=read(out/'checkpoint.json');state.update(state=config['next_state'],active=config['next_active'],new_completed=registry['batch16_added'],counts=status['status_counts'],normal_completed=status['status_counts']['VERIFIED_COMPLETED'],approvals_total=registry['completed'],remaining_unapproved=registry['remaining'])
state['newly_drawn_poses']+=decision.get('newly_drawn_poses',0)
if key not in state['approved_ids']:state['approved_ids'].append(key)
state['remaining_ids']=[x for x in state['remaining_ids'] if x!=key];state['HOLD']=[x for x in state['HOLD'] if x['id']!=key];state['active_authoring'][key]={'status':'APPROVED','runtime_connected':True,'proof':str((out/(label+'-completion-decision.json')).relative_to(repo))};save(out/'checkpoint.json',state)
print('EXPLICITLY_REVIEWED_NATIVE_PACK_CONNECTED',key,registry['completed'],game['checks'],continuous['checks'])
