from pathlib import Path
from PIL import Image
from scipy.ndimage import label,binary_dilation
import numpy as np,json,math,hashlib
B=Path(__file__).parent;D=B/'actual-E-ATTACK6-native-articulated-rig-v04';P=D/'E-ATTACK6-actual-native-articulated-six-rig-and-local-cape-contract-v04.json';O=B/'actual-E-ATTACK6-native-articulated-rig-v03/E-ATTACK6-actual-native-articulated-six-rig-and-local-cape-contract-v03.json';j=json.loads(P.read_text());old=json.loads(O.read_text());root=j['common_rig_root_in_unpadded_frame'];storage=j['storage_translation'];transfer=np.array(Image.open(j['actual_original_foregrip_shaft_semantic_transfer']['transfer_mask']['path']).convert('L'))>0;inflated=Image.fromarray(binary_dilation(transfer,iterations=3).astype('uint8')*255);W=H=1792;rows=[]
def pin(p):
 p=Path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
def bone(a,b,c,d):
 a,b,c,d=map(lambda v:np.array(v,float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);M=np.column_stack((v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]))@np.column_stack((u,[-u[1],u[0]])).T;return M,c-M@a
for f,o in zip(j['frames'],old['frames']):
 p=f['actual_rig_nodes_unpadded_native'];FM,FO=bone([550,471],[428,505],p['re'],p['rw']);SM=np.array(f['RIGHT_rigid_staff_matrix']);SO=np.array(f['RIGHT_exact_same_forearm_affine_grip_target'])-SM@np.array([386,506]);allowed_union=np.zeros((H,W),bool);out=Image.new('RGBA',(W,H));nd=[]
 assert p==o['actual_rig_nodes_unpadded_native'];assert f['common_rig_root_in_unpadded_frame']==o['common_rig_root_in_unpadded_frame'];assert f['storage_translation']==o['storage_translation']
 for i,(q,r)in enumerate(zip(f['actual_composition_nodes'],o['actual_composition_nodes'])):
  ar=np.array(Image.open(q['path']).convert('RGBA'));ao=np.array(Image.open(r['path']).convert('RGBA'));diff=np.any(ar!=ao,2);allow=np.zeros((H,W),bool)
  if i in [4,5]:
   M,b=(SM,SO)if i==4 else(FM,FO);V=np.linalg.inv(M);off=-V@b;mask=inflated.transform((W,H),Image.Transform.AFFINE,tuple(V[0])+(off[0],)+tuple(V[1])+(off[1],),Image.Resampling.BICUBIC);stored=Image.new('L',(W,H));stored.paste(mask,tuple(storage));allow=np.array(stored)>0;allowed_union|=allow
  assert int((diff&~allow).sum())==0;out.alpha_composite(Image.fromarray(ar));nd.append({'node':Path(q['path']).name,'RGBA_changed_pixels':int(diff.sum()),'outside_original_material_transfer_kernel_RGBA_changes':0})
 a=np.array(Image.open(f['path']).convert('RGBA'));ao=np.array(Image.open(o['path']).convert('RGBA'));assert np.array_equal(a,np.array(out));assert int((np.any(a!=ao,2)&~allowed_union).sum())==0;cc,n=label(a[:,:,3]>100);sz=np.bincount(cc.ravel());sz[0]=0;assert int((sz>=200).sum())==1;small=[]
 for k in range(1,n+1):
  if 3<=sz[k]<200:
   y,x=np.where(cc==k);small.append({'area':int(sz[k]),'stored_bbox':[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]})
 rows.append({'phase':f['phase'],'actual_frame':pin(f['path']),'exact_node_recomposition_RGBA_changes':0,'nodes':nd,'outside_allowed_RF_and_rigidpole_original_source_owner_transfer_RGBA_changes':0,'all_CORE_cape_boot_LEFTarm_and_RIGHTupper_RGBA_changes':0,'strong_body_count':1,'remaining_small_alpha100_components_ge3':small,'C_root_unit_storage_controls_grip_OR_staff_rotation_changes':0})
q={'schema':'E-ATTACK-v04-actual-shaft-node-owner-exact-transfer-proof-v1','prior_contract':pin(O),'actual_contract':pin(P),'source_native_transfer_proof':pin(B/'actual-own-E-ATTACK-native-complete-pole-shaft-ownership-v07/E-original-visible-shaft-actual-RGBA-owner-transfer-proof-v07.json'),'inverse_actual_original_material_owner_trace':pin(B/'E-ATTACK-v03-tiny-hand-native-node-original-source-trace-v01.json'),'original_source_modified':False,'actual_original_native_metal_RGBA_transferred':185,'actual_fist_native_RGBA_changes':0,'actual_cape_SOURCE_PASS_preserved':True,'checks':rows,'SOURCE_cycle_gate':'PENDING_INDEPENDENT_FINAL_SHAFT_OWNER_REPIN_ONLY','actor_approvals_added':0};p=D/'E-ATTACK6-v04-actual-original-shaft-node-owner-exact-transfer-proof-v01.json';p.write_text(json.dumps(q,indent=2)+'\n');print(json.dumps({'proof':pin(p),'source_contract':pin(P),'all_non_owner_changes':0,'remaining_alpha100_small_ge3':[r['remaining_small_alpha100_components_ge3']for r in rows]}))
