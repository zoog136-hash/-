from pathlib import Path
import copy,hashlib,json,shutil,sys

repo=Path('/workspace/twilight');runtime=Path('/workspace/runtime/batch17');out=repo/'docs/remake/evidence/pr122-remaining106/batch17'
out.mkdir(parents=True,exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
def immutable(src,dest):
    dest.parent.mkdir(parents=True,exist_ok=True)
    if dest.exists():assert sha(src)==sha(dest),dest
    else:shutil.copyfile(src,dest)
checks={x['name']:x for x in json.loads((runtime/'source-checks.json').read_text())};files=[];mapping={}
for request in sorted((runtime/'requests').glob('*.json')):
    item=json.loads(request.read_text());name=item['name'];source=Path(item['image_path']);dest=out/'raw'/(name+'.png');req=out/'requests'/request.name
    immutable(source,dest);immutable(request,req);check=checks[name];assert sha(dest)==check['sha256']
    mapping[str(source)]=str(dest.relative_to(repo))
    files.append({'name':name,'image':str(dest.relative_to(repo)),'bytes':dest.stat().st_size,'sha256':sha(dest),
                  'request':str(req.relative_to(repo)),'request_sha256':sha(req),'original_generation_path':str(source),
                  'geometry_status':check['status'],'reason':check.get('reason',''), 'production_approved':False})
assert len(files)==67
newchecks=copy.deepcopy(list(checks.values()))
for c in newchecks:c['path']=mapping[c['path']]
save(out/'raw-source-checks.json',newchecks)
save(out/'source-preservation-manifest.json',{'schema':1,'start_HEAD':'bc4ce605510a42a5db78f0ba9df8d8e63f39e68a',
 'raw_PNGs':67,'geometry_pass_only':50,'geometry_hold':17,'newly_approved':0,'approved_total_preserved':405,
 'claim':'Newly authored project-reference candidates, not recovered original/SPX animations. Geometry/Main automation is not visual approval.',
 'reference_resolution':{'/workspace/runtime/references/queen-reference.png':'docs/remake/evidence/pr122-remaining106/batch14/icequeen-project-reference.png',
   '/workspace/runtime/references/monk-SW-v02.png':'docs/remake/evidence/pr122-remaining106/batch16/authoring-stop-20261019/monk/monk-SW_v02.png',
   '/workspace/runtime/references/gnoll-reference.png':{'atlas':'assets/monsters/original/atlas_5.png','region':[16,305,304,306],'RGBA_sha256':'03aacdb80bdc12007b84dff89e36b730dd85312c366cdd932a06db1ee847e9df'},
   '/workspace/runtime/references/east-biped-gait-guide.png':'docs/remake/evidence/pr122-remaining106/batch17/reference-guides/east-biped-gait-guide.png'},
 'generation_path_to_repository':mapping,'files':files,'private_backup':'NOT_DELIVERED','old_uncommitted_reaper':'UNRECOVERED'})
guide=Path('/workspace/runtime/references/east-biped-gait-guide.png');immutable(guide,out/'reference-guides'/guide.name)
for label in ['monk','queen','gnoll']:
    source=runtime/(label+'-candidate.json')
    if not source.exists():continue
    recipe=json.loads(source.read_text())
    for sheet in recipe['sheets']:
        path=sheet['output_path']
        if path in mapping:sheet['output_path']=mapping[path]
        else:
            p=Path(path);assert p.is_relative_to(repo);sheet['output_path']=str(p.relative_to(repo))
    save(out/'recipes'/(label+'-candidate.json'),recipe)
    actor={'monk':'albino_monk_batch17_authored','queen':'ice_queen_batch17_candidate','gnoll':'gnoll_batch17_candidate'}[label]
    folder=runtime/'Main-project/assets/actors/eight_direction/original_based'/actor
    if folder.exists():
        for name in ['provenance.json','SpriteFrames.tres']:
            src=folder/name;dest=out/'staged-metadata'/actor/(name+'.txt' if name.endswith('.tres') else name)
            immutable(src,dest)
        save(out/'staged-metadata'/actor/'status.json',{'production_activated':False,'newly_approved':0,'source_status':'SOURCE_HOLD_VISUAL_GAIT_CONTACT_REVIEW',
              'staged_SpriteFrames_sha256':sha(folder/'SpriteFrames.tres'),'metadata_is_staged_preservation_only':True,
              'rebuild':'Use the strict importer on recipes in a separate Main copy; raw image bytes are preserved above.'})
for name in ['stage_monk.py','stage_queen_gnoll.py','check_sources.py','run_main.py','make_monk_main_montages.py']:
    immutable(runtime/name,out/'workflow-drivers'/name)
for name in ['monk-walk-front-actual-Main.png','monk-walk-rear-actual-Main.png','monk-main-montage-inputs.json']:
    immutable(runtime/name,out/'Monk-Main-visual-rejection'/name)
registry=json.loads((repo/'docs/remake/evidence/pr122-remaining106/batch16/individual-approvals.json').read_text())
registry.update(batch17_added=0,completed=405,remaining=93);save(out/'individual-approvals.json',registry)
status=json.loads((repo/'docs/remake/evidence/pr122-remaining106/batch16/all498-production-status.json').read_text())
gnoll=next(x for x in status['species'] if x['id']=='monster:놀');assert gnoll['production_status']=='NOT_AUTHORED'
gnoll.update(production_status='SOURCE_HOLD',reason='Batch17 eight-view128 candidate source; gait/contact visual review remains HOLD. No production link or approval.')
status['status_counts']['NOT_AUTHORED']-=1;status['status_counts']['SOURCE_HOLD']+=1
for key,reason in [('monster:알비노 몽크','Batch17 SW heading/body source repair, full128 Main3128/continuous81257 technical PASS; same-hind support repeats in actual Main, source HOLD. No new approval.'),('monster:얼음 여왕','Batch17 full128 eight-view source geometry; original black/gold/violet model and single left-hand staff. Isolated Main and gait/contact/body-scale review, no production approval.')]:
    next(x for x in status['species'] if x['id']==key)['reason']=reason
status.update(approvals_total=405,batch17_added=0,remaining_unapproved=93);assert sum(status['status_counts'].values())==498
save(out/'all498-production-status.json',status)
save(out/'checkpoint.json',{'state':'AUTHORING_BATCH_QUARANTINED; FINAL_VALIDATION_IN_PROGRESS','approved_total':405,'new_approvals':0,'remaining':93,
 'counts':status['status_counts'],'raw_new_PNGs':67,'staged_candidate_native_poses':384,'selected_new_source_poses':272,'preserved_monk_source_poses':112,
 'production_connected_new_species':0,'preserved_prior_six_Main':'PASS 10518 + 250861 + 69815 checks; not new approvals',
 'candidate_status':'Monk SOURCE_HOLD actual gait; queen/gnoll isolated visual review, not production approved',
 'local_full_regression':'RUNNING; initial catalog failure and corrected targeted PASS both preserved',
 'final_CI':'PENDING exact final HEAD; historical CI never reused','private_backup':'NOT_DELIVERED','old_reaper':'UNRECOVERED'})
checkpoint=repo/'docs/remake/TWILIGHT_REMAINING106_CHECKPOINT.json';d=json.loads(checkpoint.read_text())
d['individual_approval_registry']=str((out/'individual-approvals.json').relative_to(repo));d['active_batch_checkpoint']=str((out/'checkpoint.json').relative_to(repo))
d['counts'].update(status['status_counts']);d['counts'].update(completed=405,remaining=93,HOLD=17)
d.setdefault('latest_source_status',{})['batch17']={'raw_new_PNGs':67,'new_completed':0,'active':['monster:알비노 몽크','monster:얼음 여왕','monster:놀'],'proof':str((out/'checkpoint.json').relative_to(repo))}
save(checkpoint,d)
print('PRESERVED67_RAW_REQUESTS; SOURCE_APPROVALS_ADDED0; TOTAL405; STATUS',status['status_counts'])
