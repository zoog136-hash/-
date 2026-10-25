from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-NE-ATTACK6-native-rig-v05';U=B/'actual-NE-ATTACK6-upper-chain-input-v02';R=B/'actual-NE-ATTACK6-native-rig-v03';V=B/'actual-NE-ATTACK6-native-rig-v04';P=D/'NE-ATTACK6-actual-complete-native-fixed-sole-weightshift-contract-v05.json';j=json.loads(P.read_text());W=H=1536

def pin(p):r=Path(p).read_bytes();return {'path':str(p),'sha256':hashlib.sha256(r).hexdigest(),'bytes':len(r)}
frames=[];checks=[];ref=None
for i,z in enumerate(j['frames']):
 nodes=[V/f'phase{i}-actual-LEFT-brace-leg-node.png',R/f'phase{i}-actual-RIGHT-weightshift-leg-node.png',U/f'phase{i}-actual-LEFT-upper-arm-node.png',U/f'phase{i}-actual-LEFT-forearm-hand-node.png',D/f'phase{i}-actual-head-torso-coat-node.png',U/f'phase{i}-actual-RIGHT-upper-arm-node.png',D/f'phase{i}-actual-complete-RIGHT-staff-node.png',D/f'phase{i}-actual-RIGHT-complete-forearm-hand-node.png']
 out=Image.new('RGBA',(W,H))
 for p in nodes:out.alpha_composite(Image.open(p).convert('RGBA'))
 a=np.array(Image.open(z['path']).convert('RGBA'));assert not np.any(a!=np.array(out));assert pin(z['path'])['sha256']==z['sha256']
 if ref is None:ref=a.copy()
 sole={'RIGHT_goldheel_ROI':[790,1020,811,1036],'RIGHT_forefoot_outsole_ROI':[842,998,870,1016],'LEFT_whole_heel_toe_ROI':[510,1090,575,1194]};changes={}
 for k,(x0,y0,x1,y1)in sole.items():changes[k]=int(np.any(a[y0:y1,x0:x1]!=ref[y0:y1,x0:x1],2).sum())
 assert sum(changes.values())==0
 c,n=label(a[:,:,3]>100);sizes=np.bincount(c.ravel());sizes[0]=0;assert int((sizes>=200).sum())==1
 edge=int((a[:3,:,3]>16).sum()+(a[-3:,:,3]>16).sum()+(a[:,:3,3]>16).sum()+(a[:,-3:,3]>16).sum());assert edge==0
 checks.append({'phase':i,'recompose_all_actual_nodes_RGBA_difference':0,'actual_visible_heel_and_forefoot_crops_RGBA_difference_to_phase0':changes,'strong_body_count':1,'opaque_near_storage_edge_pixels':edge,'actor_approvals_added':0})
 frames.append({'phase':i,'name':z['name'],'path':z['path'],'sha256':z['sha256'],'native_size':[1536,1536],'source_native_size':[1254,1254],'transparent_extension_right_bottom_only':[282,282],'physical_C':2432,'bodyunit':2.375,'common_rig_root_in_unpadded_frame':[716.2291666666666,1054.2766007046484],'storage_translation':[0,0],'actual_rig_nodes':z['actual_upper_rig_nodes'],'RIGHT_hip_target':z['RIGHT_actual_hip'],'RIGHT_knee_control':z['RIGHT_actual_knee_control'],'LEFT_actual_calf_attachment':z['LEFT_visible_calf_attachment_target'],'actual_composition_nodes':list(map(pin,nodes)),'RIGHT_grip_same_forearm_affine_target':z['RIGHT_grip_same_forearm_affine_target'],'RIGHT_staff_rigid_matrix':z['RIGHT_staff_rigid_matrix'],'source_status':'ACTUAL_NATIVE_COMPLETE_SOURCE_PENDING_INDEPENDENT_QC'})
proof={'schema':'PR122-NE-attack-final-six-actual-node-recomposition-and-fixedsole-v1','status':'PASS_FINITE_NATIVE_NODE_AND_VISIBLE_FIXEDSOLE_CHECK_NOT_VISUAL_APPROVAL','checks':checks,'sha256_unique_actual_RGBA':len({hashlib.sha256(np.array(Image.open(z['path']).convert('RGBA')).tobytes()).hexdigest()for z in frames}),'game_or_actor_approvals_added':0}
pp=D/'NE-ATTACK6-actual-final-native-node-recomposition-and-visible-sole-proof-v01.json';assert not pp.exists();pp.write_text(json.dumps(proof,indent=2)+'\n')
C={'schema':'PR122-actual-NE-attack-six-native-source-provenance-v1','status':'ACTUAL_COMPLETE_NE_ATTACK6_PENDING_INDEPENDENT_SOURCE_AND_ONE_SHOT_CYCLE_QC','actor':'413','direction':'NE','role':'attack','C':2432,'bodyunit':2.375,'common_rig_root':[716.2291666666666,1054.2766007046484],'storage_translation':[0,0],'native_size':[1536,1536],'frames':frames,'one_shot':True,'fps':6/.42,'role_seconds_preserved':.42,'intended_contact_frame':3,'production_contract':pin(P),'final_actual_node_and_fixedsole_proof':pin(pp),'physical_limitations':['Original native two-boot stationary registration preserved once; no unique occluded 3D floor reconstruction claimed.','No actor/game approval from source or numeric checks.'],'whole_actor_mirrored_or_perpose_C_root_foot_fit':False,'new_walk_production_or_existing_clip_modified':False,'actor_approvals_added':0}
cp=D/'NE-ATTACK6-exact-final-actual-native-source-provenance-contract-v06.json';assert not cp.exists();cp.write_text(json.dumps(C,indent=2)+'\n');print(json.dumps({'source_contract':pin(cp),'finite_proof':pin(pp),'visible_sole_changes_all6':0,'exact_nodes_RGBA_difference':0,'six_unique_RGBA':proof['sha256_unique_actual_RGBA']}))
