from pathlib import Path
import json,hashlib,subprocess,os,sys
R=Path('/workspace/twilight');T=Path(__file__).parent;role=sys.argv[1];ids=[int(x) for x in sys.argv[2:]];assert len(ids)<=3
D=R/'docs/remake/evidence/pr122-mythic-detailed/batch03/draft-first-pass-20261023';label=role+'-S-'+'-'.join(map(str,ids));log=T/(label+'.log');env=os.environ.copy();env.update(XDG_DATA_HOME='/workspace/scratch/twilight-test-first-drafts',XDG_CACHE_HOME='/workspace/scratch/pr122-runtime-cache',XDG_CONFIG_HOME='/workspace/scratch/pr122-runtime-config',PR122_DRAFT_IDS=','.join(map(str,ids)),PR122_DRAFT_ROLE=role)
with log.open('w') as f:r=subprocess.run(['/workspace/scratch/godot472/Godot_v4.7.2-stable_linux.x86_64','--headless','--fixed-fps','60','--disable-render-loop','--path',str(R),'--script',str(T/'generated_motion_draft_test.gd')],env=env,stdout=f,stderr=subprocess.STDOUT,timeout=60)
s=log.read_text();assert r.returncode==0 and 'failures=0' in s and 'ERROR' not in s,s[-900:]
def sha(b):return hashlib.sha256(b).hexdigest()
idx=D/'preserved-source-index.json';index=json.loads(idx.read_text());records={e['repo_path']:e for e in index['files']};paths=[];stats=[]
for id in ids:
 p=R/f'docs/remake/evidence/pr122-mythic-detailed/batch03/transform_{id}-S-{role}-draft-v01.json';q=json.loads(p.read_text());q.update(generation_request_sha256=sha(json.dumps(q['generation_request'],ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()),generation_service='image_gen.imagegen',Godot_resource_six_pose_playback='PASS_LOOP' if role in ('run','idle') else 'PASS_ONCE',actual_Main_Player='NOT_RUN');p.write_text(json.dumps(q,ensure_ascii=False,indent=2)+'\n');paths.extend([p,R/q['source'],R/q['output_spriteframes'].removeprefix('res://')]);stats.append(dict(key=q['key'],poses=6,clipped_cells=sum(c['border_alpha_pixels']>0 for c in q['automatic_checks'])))
for p in [log,T/'preserve-generated-clip.py',T/'generated_motion_draft_test.gd',T/'checkpoint-new-motion-drafts-v02.py']:
 dest=D/p.name;b=p.read_bytes()
 if not dest.exists():dest.write_bytes(b)
 else:assert dest.read_bytes()==b
 paths.append(dest)
queue=json.loads((R/'docs/remake/evidence/pr122-mythic-detailed/batch01/queue.json').read_text())
holds=[R/f'docs/remake/evidence/pr122-mythic-detailed/batch03/transform_{a["id"].split(":")[1]}-S-{role}-generation-HOLD-v01.json' for a in queue[3:]]
holds=[p for p in holds if p.exists()];paths.extend(holds)
if role=='death':
 p=T/'prepare-next-death-requests.py';dest=D/p.name
 if not dest.exists():dest.write_bytes(p.read_bytes())
 else:assert dest.read_bytes()==p.read_bytes()
 paths.append(dest)
index['generation_holds']=[str(p.relative_to(R)) for p in holds]
for p in paths:records[str(p.relative_to(R))]=dict(repo_path=str(p.relative_to(R)),sha256=sha(p.read_bytes()),bytes=p.stat().st_size)
queue=json.loads((R/'docs/remake/evidence/pr122-mythic-detailed/batch01/queue.json').read_text());completed=[];next_key=None
for a in queue[3:]:
 p=R/f'docs/remake/evidence/pr122-mythic-detailed/batch03/transform_{a["id"].split(":")[1]}-S-{role}-draft-v01.json'
 if p.exists():completed.append(a['id'])
 elif (R/f'docs/remake/evidence/pr122-mythic-detailed/batch03/transform_{a["id"].split(":")[1]}-S-{role}-generation-HOLD-v01.json').exists():continue
 elif next_key is None:next_key=a['id']
index['new_S_'+role+'_drafts']=len(completed);index.update(files=list(records.values()),new_poses=6*sum(index.get('new_S_'+r+'_drafts',0) for r in ['attack','run','hit','death','idle']),next_key=next_key,next_role=role,final_motion_approvals_added=0,actors_final_approved=2,actors_active_total=19);idx.write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n');paths.append(idx)
p=R/'docs/remake/TWILIGHT_PR122_RESUME_20261019.md'
with p.open('a') as f:f.write('\n- First-pass production checkpoint: '+','.join(str(x) for x in ids)+' S '+role.upper()+' six new poses each, Godot resource six-pose playback PASS; source/edge/identity/quality HOLD and Main/Player NOT_RUN. Total new S '+role.upper()+' drafts '+str(len(completed))+'/16, final approvals0; active2/19 unchanged. Edge HOLD cells '+json.dumps(stats,ensure_ascii=False)+'. Continue '+str(next_key)+' without draft polishing.\n')
paths.append(p)
for rel in ['data/pr122_native_locomotion_staging.json','data/pr122_transform_motion_scope.json','data/pr122_palette_finish_20261019.json','data/combat_animation_profiles.json','docs/remake/evidence/pr122-mythic-detailed/batch01/queue.json']:
 assert (R/rel).read_bytes()==subprocess.check_output(['git','show','HEAD:'+rel],cwd=R)
subprocess.run(['git','diff','--check'],cwd=R,stdout=subprocess.DEVNULL,check=True);subprocess.run(['git','add','--force','--sparse','--',*[str(p.relative_to(R)) for p in paths]],cwd=R,check=True)
changed=subprocess.check_output(['git','diff','--cached','--name-only','-z'],cwd=R,text=True).split('\0');assert {n for n in changed if n}<={str(p.relative_to(R)) for p in paths}
with (T/(label+'.commit.log')).open('w') as f:subprocess.run(['git','commit','-m','[skip ci] Produce south '+role+' animation drafts for '+', '.join(map(str,ids))],cwd=R,stdout=f,stderr=subprocess.STDOUT,check=True)
print('COMMITTED',subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),'total_new_S_'+role+'_drafts='+str(len(completed)),'final_approvals=0 next='+str(next_key))
