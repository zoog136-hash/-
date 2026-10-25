from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
B=Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020');D=Path('/workspace/scratch/mythic413-N-death-actual-packed-r001-20261020')
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def save(n,d):
 p=B/n;assert not p.exists();p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');return pin(p)
rp=D/'request-NdeathSixActualRig01.json';rawp=D/'thunder_female-N-death-six-actual-poses-r001.png';pp=D/'thunder_female-N-death-six-actual-poses-r001.packing.json';cp=B/'Ndeath-v09-42b774-independent-actual-source-cycle-PASS-v01.json'
q=json.loads(rp.read_text());pack=json.loads(pp.read_text());c=json.loads(cp.read_text())
assert pin(rp)['sha256']=='93edf2e62deebdb4e77f187c44b85c42b8db433d928c30a87e847297f3bf599a'
assert pin(rawp)['sha256']=='342d0ad9b651848313871346130131c3ffe0ebb36ce0eaef3b4da921df623792'
assert q['authored_packing_proof_sha256']==pin(pp)['sha256'] and c['source_visual_status']=='PASS'
for k,v in dict(key='transform:413',direction='N',role='death',version='NdeathSixActualRig01').items():assert q[k]==v
a=np.array(Image.open(rawp).convert('RGBA'));assert a.shape==(4608,3072,4);rows=[]
for i,(p,o) in enumerate(zip(pack['authored_poses'],c['all_six_independent_binding'])):
 assert p['source_sha256']==o['source']['sha256']==pin(p['source'])['sha256'];s=np.array(Image.open(p['source']).convert('RGBA'));assert s.shape==(1536,1536,4)
 assert hashlib.sha256(s.tobytes()).hexdigest()==p['source_rgba_sha256']==o['rgba_sha256']
 x,y=p['atlas_origin'];assert np.array_equal(a[y:y+1536,x:x+1536],s)
 rx,ry,rw,rh=q['source_region_review']['regions'][i];sy,sx=np.where(s[:,:,3]>0);assert np.all((sx+x>=rx)&(sx+x<rx+rw)&(sy+y>=ry)&(sy+y<ry+rh))
 assert p['physical_canvas']==1920 and p['storage_translation']==[128,128]
 assert np.max(abs(np.array(p['atlas_root_anchor'])-(np.array([x,y])+np.array(c['common_rig_root'])+[128,128])))<1e-9
 assert np.array_equal(q['reviewed_runtime_layout']['source_anchors'][i],np.array([x,y])+[791,1046])
 rows.append(dict(phase=i,source=o['source'],rgba_sha256=o['rgba_sha256'],atlas_origin=[x,y],source_size=[1536,1536],RGBA_changes=0,every_alpha_positive_source_pixel_preserved_in_reviewed_region=True,physical_C=1920,source_anchor=q['reviewed_runtime_layout']['source_anchors'][i]))
assert q['reviewed_runtime_layout']['authored_pose_canvas_sizes']==[1920]*6
delta=q['common_root_rounding_delta'];assert np.max(abs(np.array(delta)-(np.array([663,918])-np.array(c['common_rig_root']))))<1e-9
binding=save('Ndeath-v09-final-exact-request-source-binding-v01.json',dict(schema='PR122-independent-actual-N-death-final-exact-source-binding-v1',status='PASS_EXACT_SIX_REVIEWED_SOURCE_TO_FINAL_ATLAS_AND_REQUEST',request=pin(rp),raw=pin(rawp),packing=pin(pp),actual_source_cycle_review=pin(cp),source_bindings=rows,uniform_root_rounding_delta=delta,source_resampled=False,actual_game_status='PENDING_ROOT_SCOPED_RESOURCE_PLAYER_DEATH_TERMINAL_CHECKS',actor_approvals_added=0))
receipt=save('NdeathSixActualRig01-93edf2-independent-final-source-cycle-PASS-v01.json',dict(schema='PR122-independent-final-exact-request-source-cycle-review-v1',status='PASS_EXACT_FINAL_N_DEATH_SIX_SOURCE_FALL_AND_HELD_DEAD_TERMINAL',source_visual_status='PASS',key='transform:413',direction='N',role='death',version='NdeathSixActualRig01',request_sha256=pin(rp)['sha256'],request_path=str(rp),raw_sha256=pin(rawp)['sha256'],raw_bytes=pin(rawp)['bytes'],raw_path=str(rawp),source_contract=c['source_contract'],actual_source_cycle_review=pin(cp),exact_source_binding=binding,physical_canvas=1920,common_unpadded_root=c['common_rig_root'],storage_translation=[128,128],uniform_integer_root_rounding_delta=delta,loop=False,terminal_pose_held=True,retained_runtime_death_seconds=.8,resource_role_seconds=.65,equal_weight_phase_seconds=.8/6,visual_findings=c['visual_findings'],visual_limitations=['Final atlas/request preserves all six reviewed actual source RGBA pixels and the finite source/floor binding. One uniform root rounding adds no relative body/foot/gear change.']+c['visual_limitations'],images_forwarded=0,new_image_views=0,actor_approvals_added=0))
print(json.dumps(dict(receipt=receipt,binding=binding,raw_bytes=pin(rawp)['bytes'],new_image_views=0)))
