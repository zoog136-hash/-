from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,hashlib
B=Path(__file__).parent;P=B/'actual-S-ATTACK6-own-native-articulated-rig-v07/S-ATTACK6-own-actual-native-front-six-rig-and-local-cape-HOLD-contract-v07.json';O=B/'actual-S-ATTACK6-own-native-articulated-rig-v03/S-ATTACK6-own-actual-native-front-six-rig-and-local-cape-HOLD-contract-v03.json';j=json.loads(P.read_text());old=json.loads(O.read_text());m=json.loads(Path(j['shared_materials']['path']).read_text());rows=[]
def pin(p):p=Path(p);b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
for key in ['C','bodyunit','common_rig_root_in_unpadded_frame','storage_translation']:assert j[key]==old[key]
assert len(set(f['sha256']for f in j['frames']))==6
for f,of in zip(j['frames'],old['frames']):
 assert f['actual_rig_nodes_unpadded_native']==of['actual_rig_nodes_unpadded_native'];assert f['RIGHT_exact_foregrip_affine_grip_target']==of['RIGHT_exact_foregrip_affine_grip_target'];assert f['RIGHT_rigid_staff_matrix']==of['RIGHT_rigid_staff_matrix'];out=Image.new('RGBA',tuple(j['native_canvas']));nd=[]
 for i,(p,op)in enumerate(zip(f['actual_composition_nodes'],of['actual_composition_nodes'])):
  ar=np.array(Image.open(p['path']));ao=np.array(Image.open(op['path']));n=int(np.any(ar!=ao,2).sum());assert i not in [0,1]or n==0;out.alpha_composite(Image.fromarray(ar));nd.append(dict(node=i,pin=pin(p['path']),RGBA_changes_from_v03=n))
 a=np.array(Image.open(f['path']));o=np.array(Image.open(of['path']));assert np.array_equal(a,np.array(out));st=j['storage_translation'];x0,y0,x1,y1=[480+st[0],690+st[1],925+st[0],1240+st[1]];feet=int(np.any(a[y0:y1,x0:x1]!=o[y0:y1,x0:x1],2).sum());assert feet==0;c,n=label(a[:,:,3]>100);sz=np.bincount(c.ravel());sz[0]=0;assert (sz>=200).sum()==1;small=[]
 for k in np.where((sz>=3)&(sz<200))[0]:
  y,x=np.where(c==k);small.append(dict(area=int(sz[k]),bbox=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]))
 rows.append(dict(phase=f['phase'],actual_frame=pin(f['path']),actual_nodes=nd,RGBA_recomposition_difference=0,LEFTupper_and_LF_original_art_node_changes=0,actual_original_lowerbody_and_full_boots_RGBA_changes=feet,original_boot_probe_storage=[x0,y0,x1,y1],C_root_unit_storage_plant_and_phase_controls_changes=0,strong_body_count=1,small_alpha100_components_ge3=small))
proof={'schema':'PR122-actual-current-S6-native-nodes-physical-basis-original-boots-exact-v1','actual_contract':pin(P),'prior_contract':pin(O),'native_material':j['shared_materials'],'checks':rows,'source_status':'ACTUAL_SOURCE_PENDING_FINAL_SKIN_PUFF_NATIVE_GATE_NO_AUTO_APPROVAL','one_shot_role_seconds':.42,'contact_frame':3,'frame_RGBA_unique_count':6,'all_36_node_RGBA_recomposition_difference':0,'C_root_unit_footfit_changes':0,'new_private_views_services_or_image_returns':0,'author_actual_cumulative_image_bytes':6017817,'actor_game_approvals_added':0};q=P.parent/'S-ATTACK6-v07-current36node-original-boots-rig-and-native-source-integrity-proof-v01.json';q.write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps({'proof':pin(q),'actual_contract':pin(P),'six_alpha100_small_ge3':[r['small_alpha100_components_ge3']for r in rows],'actual_original_boot_RGBA_changes':0,'actual_36nodes_recomposition_difference':0}))
