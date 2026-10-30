from pathlib import Path
import json,hashlib
import numpy as np
from PIL import Image
from scipy.ndimage import label
B=Path('/workspace/scratch/mythic413-nw-n-walk-independent-qc-20261020');A=Path('/workspace/scratch/mythic413-NW-attack-author-20261020-v01');D=A/'actual-NW-ATTACK6-native-rig-v07';V6=A/'actual-NW-ATTACK6-native-rig-v06';V5=A/'actual-NW-ATTACK6-native-rig-v05';cp=D/'NW-ATTACK6-actual-directional-rig-contract-v07.json';c=json.loads(cp.read_text());old=json.loads((V5/'NW-ATTACK6-actual-directional-rig-contract-v05.json').read_text())
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def save(n,d):
 p=B/n;assert not p.exists();p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');return pin(p)
assert pin(cp)['sha256']=='5a4355ef3f6a7a11985911e2eacc5141910a16aaf22478775cb215e51cc7c332'
assert c['C']==2048 and c['bodyunit']==2 and c['common_rig_root']==[641,1058.3] and c['one_shot'] and c['intended_contact_frame']==3
feet={k:np.array(Image.open(D/n).convert('RGBA')) for k,n in [('LEFT','actual-complete-LEFT-fixed-attack-stance-shoe.png'),('RIGHT','actual-complete-RIGHT-flat-fixed-attack-stance-shoe.png')]};y,x=np.indices((1536,1536));masks={k:(v[:,:,3]>0)&(y>=({'LEFT':869,'RIGHT':1045}[k]))for k,v in feet.items()};rows=[];maxortho=0.
for i,(f,o) in enumerate(zip(c['frames'],old['frames'])):
 p=pin(f['path']);assert p['sha256']==f['sha256'];a=np.array(Image.open(f['path']).convert('RGBA'));assert a.shape==(1536,1536,4)
 assert f['physical_C']==2048 and f['bodyunit']==2 and f['common_rig_root_in_unpadded_frame']==[641,1058.3] and f['storage_translation']==[0,0]
 assert f['actual_rig_nodes']==o['actual_rig_nodes']
 nodeproof={}
 for node in ['RIGHTfore','RIGHTstaff','LEFTupper']:
  nm=f'phase{i}-actual-{node}-node.png';assert pin(D/nm)['sha256']==pin(V6/nm)['sha256']==pin(V5/nm)['sha256'];nodeproof[node]=pin(D/nm)
 nm=f'phase{i}-actual-legs-node.png';assert pin(D/nm)['sha256']==pin(V6/nm)['sha256'];nodeproof['actual_v06_finished_legs']=pin(D/nm)
 fixed={k:int(np.count_nonzero(np.any(a[masks[k]]!=v[masks[k]],axis=1)))for k,v in feet.items()};assert all(v==0 for v in fixed.values())
 R=np.array(f['RIGHT_staff_rigid_rotation_matrix']);er=float(np.max(abs(R.T@R-np.eye(2))));maxortho=max(maxortho,er);assert er<1e-12
 labs,n=label(a[:,:,3]>100);areas=np.bincount(labs.ravel())[1:];strong=[int(v)for v in areas if v>=200];assert len(strong)==1
 lc,n=label(a[:,:,3]>16);areas=np.bincount(lc.ravel());idx=int(areas[1:].argmax()+1);small=[]
 for j in range(1,len(areas)):
  if j!=idx and areas[j]>=3:
   yy,xx=np.where(lc==j);small.append(dict(pixels=int(areas[j]),bbox=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]))
 assert small==([dict(pixels=3,bbox=[760,386,763,387])]if i==1 else[])
 rows.append(dict(phase=i,name=f['name'],source=p,rgba_sha256=hashlib.sha256(a.tobytes()).hexdigest(),actual_pose=f['actual_rig_nodes'],reviewed_node_transfer=nodeproof,complete_actual_fixed_shoe_RGBA_changes=fixed,strong_alpha100_4connected_components=strong,alpha16_detached_components_ge3=small,RIGHT_staff_rotation_orthonormality_error=er))
assert len({r['rgba_sha256']for r in rows})==6
lp=B/'private-image-ledger-working-v01.json';l=json.loads(lp.read_text());e=l['entries'][-1];assert e['view']==77 and e['status']=='RESERVED_BEFORE_PRIVATE_VIEW';e['status']='PRIVATELY_VIEWED';e['actual_view_payload_bytes']=e['bytes'];l['new_viewed_bytes']=sum(x.get('actual_view_payload_bytes',0)for x in l['entries']if x['status']=='PRIVATELY_VIEWED');l['context_total_viewed_bytes']=l['inherited_context_private_image_bytes']+l['new_viewed_bytes'];lp.write_text(json.dumps(l,ensure_ascii=False,indent=2)+'\n');snap=save('private-image-ledger-through-NWattack-final-source-view77-frozen.json',l)
proof=save('NWattack-v07-5a4355-independent-actual-source-cycle-PASS-v01.json',dict(schema='PR122-independent-actual-NW-attack-six-source-cycle-prepacking-v1',status='PASS_ACTUAL_NW_ATTACK_SIX_SOURCE_AND_ONE_SHOT_STRIKE3_CYCLE_PREPACKING',source_visual_status='PASS',key='transform:413',direction='NW',role='attack',source_contract=pin(cp),all_six_independent_binding=rows,C_fixed=2048,bodyunit_fixed=2,common_rig_root=[641,1058.3],storage_translation=[0,0],source_canvas=[1536,1536],one_shot=True,impact_frame=3,resource_role_seconds=.42,visual_findings=['Dedicated READY/WINDUP/COIL, NW-directed STRIKE3, FOLLOW and RECOVER poses articulate actual torso/knees/nearLEFT counterarm and farRIGHT staff arm rather than relabeling an existing clip.','The rearNW unique head/bun/ribbon, gold-blue costume, white skirt and complete high-heeled boots remain coherent. Both real flat shoes preserve their initial native yaw and fixed support material across all six poses.','Complete far anatomicalRIGHT hand/forearm and rigid double-ended staff stay connected. All six reviewed grip/staff nodes transfer byte-exactly from the native reviewed grip sequence, with orthonormal staff rotations.','The new continuous RIGHT calf uses actual owned calf-to-flatshoe material and closes the earlier sawtooth/cut contour. The isolated dark old-underarm fragment now follows the real underarm cap; old LEFT fingertip traces are removed while preserving the complete moving hand.','STRIKE3 reaches the NW quadrant with the actual blade endpoint around[136.294,219.771]; recovery returns toward the ready guard without a body/equipment pop.'],visual_limitations=['This approves actual source appearance and visible one-shot attack cycle. Final exact atlas/request binding and actual scoped Godot/Player/impact scheduling remain pending.','Visible stationary complete-shoe material is independently fixed; hidden3D anatomy and finite foot volume are not uniquely reconstructed. Foot perimeter yaw is retained rather than forced to a common heading slope.','One3px source bow-edge alpha fragment remains in WINDUP1; it is not a detached hand/armor or additional strong body. No alpha threshold or gameplay validation was relaxed.','The initial RIGHT flatshoe placement changed once by1nativeY before this final shared stance. It is constant across all six final frames and is not a perpose foot/root fit.','Only this new NW ATTACK source cycle is approved here; detailed actor approvals remain unchanged.'],author_material_transfer_proof=pin(D/'NW-ATTACK6-v06-to-v07-actual-underarm-cap-and-complete-hand-node-transfer-proof-v01.json'),author_fixed_sole_and_gear_proof=pin(D/'NW-ATTACK6-six-native-fixed-sole-and-rigid-gear-finite-proof-v01.json'),private_ledger_snapshot=snap,images_forwarded=0,actor_approvals_added=0))
print(json.dumps(dict(certificate=proof,private_context_bytes=l['context_total_viewed_bytes'],source_poses=6,actor_approvals_added=0)))
