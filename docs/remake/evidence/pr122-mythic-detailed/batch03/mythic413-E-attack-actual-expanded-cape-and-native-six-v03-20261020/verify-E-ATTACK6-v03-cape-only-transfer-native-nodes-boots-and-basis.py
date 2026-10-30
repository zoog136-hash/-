from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-E-ATTACK6-native-articulated-rig-v03';P=D/'E-ATTACK6-actual-native-articulated-six-rig-and-local-cape-contract-v03.json';O=B/'actual-E-ATTACK6-native-articulated-rig-v02/E-ATTACK6-actual-native-articulated-six-rig-and-local-cape-contract-v02.json';j=json.loads(P.read_text());old=json.loads(O.read_text());reg=json.loads(Path(j['shared_once_registration_exact_JSON']['path']).read_text());root=reg['common_rig_root_in_unpadded_frame'];storage=reg['production_storage_translation']
def pin(p):
 p=Path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
rows=[];rgba=[]
for z,o in zip(j['frames'],old['frames']):
 assert z['common_rig_root_in_unpadded_frame']==root and z['storage_translation']==storage and z['physical_C']==reg['new_E_fixed_C'];out=Image.new('RGBA',(1792,1792));nd=[]
 for q,r in zip(z['actual_composition_nodes'],o['actual_composition_nodes']):
  assert pin(q['path'])==q;node=Image.open(q['path']).convert('RGBA');prior=Image.open(r['path']).convert('RGBA');out.alpha_composite(node);diff=int(np.any(np.array(node)!=np.array(prior),2).sum());iscore='head-spine-coat-fixed-native-boots' in q['path'];assert iscore or diff==0;nd.append({'node':Path(q['path']).name,'prior_RGBA_difference':diff,'CORE_only_change':iscore})
 a=np.array(Image.open(z['path']).convert('RGBA'));ao=np.array(Image.open(o['path']).convert('RGBA'));assert not np.any(a!=np.array(out));assert pin(z['path'])['sha256']==z['sha256'];rgba.append(hashlib.sha256(a.tobytes()).hexdigest());change={}
 for k,(x0,y0,x1,y1)in {'imageLEFT_original_complete_boot':[500,1090,750,1240],'imageRIGHT_original_complete_boot':[850,1090,1050,1240]}.items():
  x0+=storage[0];x1+=storage[0];y0+=storage[1];y1+=storage[1];change[k]=int(np.any(a[y0:y1,x0:x1]!=ao[y0:y1,x0:x1],2).sum())
 assert sum(change.values())==0;assert z['actual_rig_nodes_unpadded_native']==o['actual_rig_nodes_unpadded_native'];assert z['RIGHT_exact_same_forearm_affine_grip_target']==o['RIGHT_exact_same_forearm_affine_grip_target'];c,n=label(a[:,:,3]>100);s=np.bincount(c.ravel());s[0]=0;main=int((s>=200).sum());assert main==1;small=[]
 for v in range(1,n+1):
  if 3<=s[v]<200:
   y,x=np.where(c==v);small.append({'area':int(s[v]),'stored_bbox':[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]})
 rows.append({'phase':z['phase'],'actual_frame':pin(z['path']),'RGBAsha256':rgba[-1],'all_actual_nodes_recomposition_RGBA_difference':0,'nodes':nd,'all_original_boot_RGBA_difference':change,'strong_body_count':main,'small_alpha100_components_ge3_for_visual_QC':small,'C_root_storage_controls_grip_drift':0})
assert len(set(rgba))==6
q={'schema':'PR122-E-attack-v03-cape-only-exact-transfer-proof-v1','status':'PASS_EXACT_NODE_AND_BOOT_TRANSFER_PENDING_FINAL_NATIVE_JOINT_SOURCE_QC','prior_contract':pin(O),'actual_source_contract':pin(P),'shared_exact_registration':j['shared_once_registration_exact_JSON'],'cape_native_actual_source_QC':'Primary actualv06 localcloth PASS received; formal certificate in final6 sourcegate','native_source_size':[1792,1792],'transparent_storage_extension_only_for_atlas_permitted':True,'six_RGBA_unique':6,'checks':rows,'actor_approvals_added':0};p=D/'E-ATTACK6-v03-cape-only-node-original-boot-and-rig-transfer-proof-v01.json';p.write_text(json.dumps(q,indent=2)+'\n');print(json.dumps({'proof':pin(p),'contract':pin(P),'nonCOREnode_RGBA_diff':0,'actualboot_RGBA_diff':0,'strong_counts':[v['strong_body_count']for v in rows],'small_alpha100_components_ge3':[v['small_alpha100_components_ge3_for_visual_QC']for v in rows]}))
