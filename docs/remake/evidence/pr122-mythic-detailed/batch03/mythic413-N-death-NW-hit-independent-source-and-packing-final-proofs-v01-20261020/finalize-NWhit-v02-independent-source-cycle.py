from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
from scipy.ndimage import label
B=Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020');D=Path('/workspace/scratch/mythic413-NW-hit-author-20261020-v01');cp=D/'actual-NW-HIT6-native-braced-recoil-v02/NW-HIT-six-actual-native-source-and-common-root-contract-v02.json';c=json.loads(cp.read_text())
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def save(n,d):
 p=B/n;assert not p.exists();p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');return pin(p)
lp=B/'private-image-ledger-working-v01.json';l=json.loads(lp.read_text());e=l['entries'][-1];assert e['view']==73 and e['status']=='RESERVED_BEFORE_PRIVATE_VIEW';e['status']='PRIVATELY_VIEWED';e['actual_view_payload_bytes']=e['bytes'];l['new_viewed_bytes']=sum(x.get('actual_view_payload_bytes',0)for x in l['entries']if x['status']=='PRIVATELY_VIEWED');l['context_total_viewed_bytes']=l['inherited_context_private_image_bytes']+l['new_viewed_bytes'];lp.write_text(json.dumps(l,ensure_ascii=False,indent=2)+'\n');ledger=save('private-image-ledger-through-NWhit-final-source-joints-view73-frozen.json',l)
assert c['physical_canvas']==2048 and c['body_unit']==2 and c['common_rig_root_in_unpadded_frame']==[641,1058.3] and c['storage_translation']==[0,0] and not c['loop']
def pad(p):
 a=Image.new('RGBA',(1536,1536));a.paste(Image.open(p).convert('RGBA'),(0,0));return np.array(a)
base=pad(D/'actual-braced-stance-v03/thunder_female-NW-HIT-braced-fixed-stance-candidate-v03.png')
legs=pad(D/'actual-braced-stance-v03/NW-HIT-articulated-braced-legs-and-complete-shoes.png');yy,xx=np.indices(base.shape[:2]);lm=(legs[:,:,3]>16)&(yy>=730)
staffp=Path('/workspace/scratch/mythic413-NW-attack-author-20261020-v01/actual-NW-ATTACK6-native-rig-v03/actual-original-NW-complete-rigid-RIGHT-staff-material.png');sm=pad(staffp)[:,:,3]>100
assert int(lm.sum())==32843 and int(sm.sum())==23241
rows=[]
for i,f in enumerate(c['frames']):
 p=pin(f['path']);assert p['sha256']==f['sha256'];a=np.array(Image.open(f['path']).convert('RGBA'));assert a.shape==(1536,1536,4)
 assert f['physical_canvas']==2048 and f['common_rig_root']==[641,1058.3] and f['storage_translation']==[0,0]
 diff=np.any(a!=base,axis=2);lc=int(np.count_nonzero(diff&lm));sc=int(np.count_nonzero(diff&sm));assert lc==sc==0
 labs,n=label(a[:,:,3]>100);areas=np.bincount(labs.ravel());strong=[int(x)for x in areas[1:]if x>=200];assert len(strong)==1
 heel={}
 for k,rect in {'LEFT':(495,920,540,960),'RIGHT':(684,1100,720,1130)}.items():
  x,y,x1,y1=rect;Y,X=np.where(a[y:y1,x:x1,3]>=100);heel[k]=int(Y.max()+y)
 assert heel==dict(LEFT=944,RIGHT=1116)
 rows.append(dict(phase=i,name=f['name'],source=p,rgba_sha256=hashlib.sha256(a.tobytes()).hexdigest(),fixed_leg_material_RGBA_changes=lc,fixed_complete_staff_RGBA_changes=sc,strong_alpha100_4connected_components=strong,actual_heel_alpha100_bottom=heel,actual_pose=f['actual_pose']))
assert len({r['rgba_sha256']for r in rows})==6
proof=save('NWhit-v02-ff27c7-independent-actual-source-cycle-PASS-v01.json',dict(schema='PR122-independent-actual-NW-hit-six-source-cycle-prepacking-v1',status='PASS_ACTUAL_NW_HIT_SIX_SOURCE_AND_ONE_SHOT_RECOIL_CYCLE_PREPACKING',source_visual_status='PASS',key='transform:413',direction='NW',role='hit',source_contract=pin(cp),all_six_independent_binding=rows,C_fixed=2048,common_rig_root=[641,1058.3],storage_translation=[0,0],loop=False,observed_phases=['guard','impact','peak recoil','counterbalance','recovery','reset guard'],visual_findings=['Six dedicated hit phases articulate head/spine recoil, a complete LEFT guard arm and coat lag into impact, counterbalance and recovery.','Native LEFT shoulder/cuff/white sleeve/bracer/complete hand remain visibly connected through guard, recoil and counterbalance; original garment and rear-NW identity are retained.','Both complete actual flat shoes and the true calf-to-shoe surfaces are continuous after removing the earlier misplaced airborne toe fragment. The observed fixed stance remains unchanged through all six reactions.','The complete anatomical RIGHT-held double-ended staff and its original grip/arm stay coherent; actual leg material32843px and complete staff material23241px are independently unchanged across all six source frames.','All six actual poses have one strong alpha100/4connected body and are individually distinct; the source sequence is dedicated to hit reaction rather than an old locomotion/attack clip.'],visual_limitations=['This is an actual source/visible six-phase hit gate. Exact final atlas/request binding and scoped Godot/Player/action checks remain pending.','Fixed heel/leg material verifies visible stationary support. Foot yaw is retained from the actual flat shoe material; hidden joint/depth anatomy is not uniquely recovered.','Two constant very weak staff-edge AA clusters total7px at alpha18..22 remain; their RGB and source semantic provenance match the original staff edge. They are not detached hands, armor or additional strong bodies. No threshold was changed to hide them.','Detailed actor approvals remain unchanged; only this new NW HIT source cycle is approved here.'],author_fixed_material_proof=pin(D/'actual-NW-HIT6-native-braced-recoil-v02/NW-HIT-six-exact-fixed-actual-legs-flatshoes-and-complete-staff-proof-v01.json'),braced_stance_contract=c['fixed_stance_contract'],private_ledger_snapshot=ledger,images_forwarded=0,actor_approvals_added=0))
print(json.dumps(dict(certificate=proof,private_context_bytes=l['context_total_viewed_bytes'],source_poses=6,actor_approvals_added=0)))
