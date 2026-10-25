from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,hashlib
B=Path(__file__).parent;P=B/'actual-S-ATTACK6-own-native-articulated-rig-v07/S-ATTACK6-own-actual-native-front-six-rig-and-local-cape-HOLD-contract-v07.json';O=B/'actual-S-ATTACK6-own-native-articulated-rig-v03/S-ATTACK6-own-actual-native-front-six-rig-and-local-cape-HOLD-contract-v03.json';j=json.loads(P.read_text());old=json.loads(O.read_text())
def pin(p):p=Path(p);b=p.read_bytes();return dict(path=str(p),sha256=hashlib.sha256(b).hexdigest(),bytes=len(b))
for k in ['C','bodyunit','common_rig_root_in_unpadded_frame','storage_translation']:assert j[k]==old[k]
assert len(set(f['sha256']for f in j['frames']))==6
rows=[];st=j['storage_translation'];x0,y0,x1,y1=[480+st[0],690+st[1],925+st[0],1240+st[1]]
for f,of in zip(j['frames'],old['frames']):
 for k in ['actual_rig_nodes_unpadded_native','RIGHT_exact_foregrip_affine_grip_target','RIGHT_rigid_staff_matrix']:assert f[k]==of[k]
 out=Image.new('RGBA',tuple(j['native_canvas']));nonbody=np.zeros((y1-y0,x1-x0),bool);nodechanges=[];bodyFootChanges=None
 for ni,(nn,oo)in enumerate(zip(f['actual_composition_nodes'],of['actual_composition_nodes'])):
  a=np.array(Image.open(nn['path']));o=np.array(Image.open(oo['path']));diff=np.any(a!=o,2);n=int(diff.sum());assert ni not in [0,1]or n==0;out.alpha_composite(Image.fromarray(a));nodechanges.append(dict(node=ni,pin=pin(nn['path']),RGBA_changes_from_v03=n))
  if ni==2:bodyFootChanges=int(diff[y0:y1,x0:x1].sum());assert bodyFootChanges==0
  else:nonbody|=diff[y0:y1,x0:x1]
 a=np.array(Image.open(f['path']));o=np.array(Image.open(of['path']));assert np.array_equal(a,np.array(out));diff=np.any(a[y0:y1,x0:x1]!=o[y0:y1,x0:x1],2);assert not np.any(diff&~nonbody);cc,n=label(a[:,:,3]>100);sz=np.bincount(cc.ravel());sz[0]=0;assert int((sz>=200).sum())==1;small=[]
 for k in np.where((sz>=3)&(sz<200))[0]:
  yy,xx=np.where(cc==k);small.append(dict(area=int(sz[k]),stored_bbox=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)]))
 rows.append(dict(phase=f['phase'],actual_frame=pin(f['path']),actual_nodes=nodechanges,actual_RGBA_recomposition_difference=0,physical_BODY_lowerbody_and_complete_boot_RGBA_changes=bodyFootChanges,physical_BODY_probe_storage=[x0,y0,x1,y1],final_visible_probe_changes_by_completed_equipment=int(diff.sum()),final_probe_changes_outside_foreground_material_changes=0,LEFTupper_and_forehand_node_changes=0,strong_body_count=1,alpha100_small_components_ge3=small,C_root_unit_storage_plant_controls_changes=0))
proof={'schema':'PR122-actual-current-six-source-node-physical-body-boots-integrity-v2','actual_contract':pin(P),'prior_contract':pin(O),'checks':rows,'six_unique_RGBA_sources':6,'actual_36nodes_recomposition_RGBA_difference':0,'actual_BODY_lowerbody_and_complete_boot_RGBA_changes':0,'scope_note':'Wholeframe thigh ROI can differ where restored genuine original rigidstaff fins pass in front. Physical body/boot node is exact; all final ROI changes are attributable solely to actual foreground part changes. No footfit or test/importer threshold relaxation.','source_status':'PENDING_FINAL_NATIVE_SOURCE_JOINT_GATE_NO_AUTO_ACTOR_GAME_APPROVAL','author_actual_image_bytes':6017817,'new_image_views_services_or_returns':0,'actor_approvals_added':0};q=P.parent/'S-ATTACK6-v07-actual36nodes-protected-body-boots-and-equipment-occlusion-proof-v02.json';q.write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps({'proof':pin(q),'source':pin(P),'BODY_boot_RGBA_changes':0,'all36_recomposition':0,'small_alpha100_ge3':[r['alpha100_small_components_ge3']for r in rows]}))
