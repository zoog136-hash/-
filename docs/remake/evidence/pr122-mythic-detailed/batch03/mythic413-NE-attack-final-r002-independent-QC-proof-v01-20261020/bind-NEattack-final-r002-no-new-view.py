from pathlib import Path
import json,hashlib,sys
import numpy as np
from PIL import Image
B=Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020');D=Path('/workspace/scratch/mythic413-NE-attack-actual-packed-r002-20261020')
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def save(n,x):
 p=B/n;assert not p.exists();p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n');return pin(p)
assert len(sys.argv)==4,'Expected exact parent-announced requestSHA rawSHA rawbytes'
rqsha,rawsha,rawbytes=sys.argv[1:];rawbytes=int(rawbytes)
rp=D/'request-NEattackSixActualRig02.json';rawp=D/'thunder_female-NE-attack-six-actual-poses-r002.png';pp=D/'thunder_female-NE-attack-six-actual-poses-r002.packing.json';cp=B/'NEattack-v06-42d0cd-independent-actual-source-cycle-PASS-v01.json'
assert pin(cp)['sha256']=='df4a2edf1844d62d74cb3ddccccbb0fb6e8942e9f00977e78511bf338d3db3bd'
transferp=B/'NEattack-v08-f40d09-metadata-only-final-source-transfer-v01.json'
assert pin(transferp)['sha256']=='32ce7b1406731d36ee338d7d6be87735f74c8dbe785e6280428cabfe1db8f3c6'
transfer=json.loads(transferp.read_text())
assert pin(transfer['latest_final_contract']['path'])['sha256']==transfer['latest_final_contract']['sha256']
assert pin(rp)['sha256']==rqsha and pin(rawp)['sha256']==rawsha and pin(rawp)['bytes']==rawbytes
q=json.loads(rp.read_text());pack=json.loads(pp.read_text());c=json.loads(cp.read_text());assert q['authored_packing_proof_sha256']==pin(pp)['sha256'] and c['source_visual_status']=='PASS'
for k,v in dict(key='transform:413',direction='NE',role='attack',version='NEattackSixActualRig02').items():assert q[k]==v
a=np.array(Image.open(rawp).convert('RGBA'));assert a.shape==(4608,3072,4);rows=[];root=np.array(c['common_rig_root']);roundroot=np.rint(root).astype(int);rounddelta=roundroot-root
for i,(p,o)in enumerate(zip(pack['authored_poses'],c['all_six_independent_binding'])):
 assert p['source_sha256']==o['source']['sha256']==pin(p['source'])['sha256'];s=np.array(Image.open(p['source']).convert('RGBA'));assert s.shape==(1536,1536,4) and hashlib.sha256(s.tobytes()).hexdigest()==p['source_rgba_sha256']==o['rgba_sha256']
 x,y=p['atlas_origin'];assert np.array_equal(a[y:y+1536,x:x+1536],s)
 rx,ry,rw,rh=q['source_region_review']['regions'][i];sy,sx=np.where(s[:,:,3]>0);assert np.all((sx+x>=rx)&(sx+x<rx+rw)&(sy+y>=ry)&(sy+y<ry+rh))
 assert p['physical_canvas']==2432 and p['storage_translation']==[0,0] and np.max(abs(np.array(p['atlas_root_anchor'])-(np.array([x,y])+root)))<1e-9
 assert np.array_equal(q['reviewed_runtime_layout']['source_anchors'][i],np.array([x,y])+roundroot)
 rows.append(dict(phase=i,source=o['source'],rgba_sha256=o['rgba_sha256'],atlas_origin=[x,y],source_size=[1536,1536],RGBA_changes=0,every_alpha_positive_source_pixel_preserved_in_reviewed_region=True,physical_C=2432,source_anchor=q['reviewed_runtime_layout']['source_anchors'][i]))
assert len(rows)==6 and q['reviewed_runtime_layout']['authored_pose_canvas_sizes']==[2432]*6
assert np.max(abs(np.array(q['common_root_rounding_delta'])-rounddelta))<1e-9
binding=save('NEattack-v06-final-r002-exact-request-source-binding-v01.json',dict(schema='PR122-independent-actual-NE-attack-final-exact-source-binding-v1',status='PASS_EXACT_SIX_REVIEWED_SOURCE_TO_FINAL_ATLAS_AND_REQUEST',request=pin(rp),raw=pin(rawp),packing=pin(pp),actual_source_cycle_review=pin(cp),latest_final_source_metadata_transfer=pin(transferp),source_bindings=rows,uniform_root_rounding_delta=rounddelta.tolist(),source_resampled=False,actual_game_status='PENDING_ROOT_SCOPED_RESOURCE_PLAYER_ATTACK_CONTACT_CHECKS',actor_approvals_added=0))
receipt=save('NEattackSixActualRig02-independent-final-source-cycle-PASS-v01.json',dict(schema='PR122-independent-final-exact-request-source-cycle-review-v1',status='PASS_EXACT_FINAL_NE_ATTACK_SIX_DEDICATED_ONE_SHOT_SOURCE_CYCLE',source_visual_status='PASS',key='transform:413',direction='NE',role='attack',version='NEattackSixActualRig02',request_sha256=rqsha,request_path=str(rp),raw_sha256=rawsha,raw_bytes=rawbytes,raw_path=str(rawp),source_contract=transfer['latest_final_contract'],reviewed_source_contract=c['source_contract'],latest_final_source_metadata_transfer=pin(transferp),actual_source_cycle_review=pin(cp),exact_source_binding=binding,physical_canvas=2432,common_unpadded_root=root.tolist(),storage_translation=[0,0],uniform_integer_root_rounding_delta=rounddelta.tolist(),loop=False,cycle_seconds=.42,phase_seconds=.07,resource_fps=6/.42,intended_contact_frame=3,visual_findings=c['visual_findings'],visual_limitations=['Final atlas/request preserves all six reviewed actual source RGBA pixels, actual joint/gear/support and one common root rounding; no new source or image view.']+c['visual_limitations'],images_forwarded=0,new_image_views=0,actor_approvals_added=0))
print(json.dumps(dict(receipt=receipt,binding=binding,raw_bytes=rawbytes,new_image_views=0)))
