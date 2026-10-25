from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
B=Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020')
D=Path('/workspace/scratch/mythic413-N-attack-actual-packed-r002-20261020')
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def save(name,d):
 p=B/name;assert not p.exists();p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');return pin(p)
rp=D/'request-NattackSixActualRig02.json';rawp=D/'thunder_female-N-attack-six-actual-poses-r002.png';pp=D/'thunder_female-N-attack-six-actual-poses-r002.packing.json'
q=json.loads(rp.read_text());pack=json.loads(pp.read_text());certp=B/'Nattack-v07-a62030-independent-actual-source-cycle-PASS-v01.json';c=json.loads(certp.read_text())
assert pin(rp)['sha256']=='f0072517af971eac916c17f6c175171d029968a5a667e5e6c6cdf792e536398b'
assert pin(rawp)['sha256']=='ee0de24eae8c268ef16143eeaa90fa6ca18bfb0f61d9c2626003b966814aee54'
assert q['authored_packing_proof_sha256']==pin(pp)['sha256']
assert all(q[k]==v for k,v in dict(key='transform:413',direction='N',role='attack',version='NattackSixActualRig02').items())
assert c['source_visual_status']=='PASS' and c['source_contract']['sha256']=='a6203050cd25b15c88d839dbcbbabea7c37b137bcd99bc8e3f0a7a9a64ce5653'
a=np.array(Image.open(rawp).convert('RGBA'));assert a.shape==(4608,3072,4)
rows=[]
for i,(p,old) in enumerate(zip(pack['authored_poses'],c['all_six_independent_binding'])):
 assert p['source_sha256']==old['source']['sha256']==pin(p['source'])['sha256']
 s=np.array(Image.open(p['source']).convert('RGBA'));assert list(s.shape[:2][::-1])==p['source_size']==[1254,1414]
 assert hashlib.sha256(s.tobytes()).hexdigest()==p['source_rgba_sha256']==old['rgba_sha256']
 x,y=p['atlas_origin'];tile=a[y:y+1536,x:x+1536];assert np.array_equal(tile[:1414,:1254],s)
 outside=tile.copy();outside[:1414,:1254]=0;assert not np.any(outside)
 rx,ry,rw,rh=q['source_region_review']['regions'][i];mask=a[ry:ry+rh,rx:rx+rw,3]>0
 sy,sx=np.where(s[:,:,3]>0);assert np.all((sx+x>=rx)&(sx+x<rx+rw)&(sy+y>=ry)&(sy+y<ry+rh))
 expected=np.array([x,y])+np.array([663,1078]);assert np.array_equal(q['reviewed_runtime_layout']['source_anchors'][i],expected)
 assert p['storage_translation']==[0,160] and p['physical_canvas']==1920
 assert np.max(abs(np.array(p['atlas_root_anchor'])-(np.array([x,y])+np.array(c['common_rig_root'])+np.array([0,160]))))<1e-9
 rows.append(dict(phase=i,source=old['source'],source_rgba_sha256=old['rgba_sha256'],atlas_origin=[x,y],source_size=[1254,1414],RGBA_changes=0,outside_source_tile_RGBA_nonzero=0,region_contains_every_alpha_positive_source_pixel=True,source_anchor=q['reviewed_runtime_layout']['source_anchors'][i],physical_C=1920))
assert q['reviewed_runtime_layout']['authored_pose_canvas_sizes']==[1920]*6
delta=q['common_root_rounding_delta'];assert np.max(abs(np.array(delta)-(np.array([663,918])-np.array(c['common_rig_root']))))<1e-9
binding=save('Nattack-v07-final-exact-request-source-binding-v01.json',dict(schema='PR122-independent-actual-attack-final-exact-source-binding-v1',status='PASS_EXACT_SIX_REVIEWED_SOURCE_TO_FINAL_ATLAS_AND_REQUEST',request=pin(rp),raw=pin(rawp),packing=pin(pp),actual_source_cycle_review=pin(certp),source_bindings=rows,uniform_root_rounding_delta=delta,relative_stance_drift_added_by_rounding=[0,0],source_resampled=False,actual_game_binding_status='PENDING_ROOT_SCOPED_RESOURCE_PLAYER_ACTION_CHECKS',actor_approvals_added=0))
receipt=save('NattackSixActualRig02-f00725-independent-final-source-cycle-PASS-v01.json',dict(schema='PR122-independent-final-exact-request-source-cycle-review-v1',status='PASS_EXACT_FINAL_N_ATTACK_SIX_SOURCE_AND_VISIBLE_ONE_SHOT_CYCLE',source_visual_status='PASS',key='transform:413',direction='N',role='attack',version='NattackSixActualRig02',request_sha256=pin(rp)['sha256'],request_path=str(rp),raw_sha256=pin(rawp)['sha256'],raw_bytes=pin(rawp)['bytes'],raw_path=str(rawp),source_contract=c['source_contract'],actual_source_cycle_review=pin(certp),exact_source_binding=binding,physical_canvas=1920,common_unpadded_root=c['common_rig_root'],storage_translation=[0,160],uniform_integer_root_rounding_delta=delta,impact_frame=3,one_shot=True,visual_findings=c['visual_findings'],visual_limitations=['Exact final atlas preserves all six independently reviewed source RGBA pixels; integer root rounding is uniform, so it adds no relative stance drift.']+c['visual_limitations'],images_forwarded=0,new_image_views=0,actor_approvals_added=0))
print(json.dumps(dict(receipt=receipt,binding=binding,private_context_bytes=3468195,actor_approvals_added=0)))
