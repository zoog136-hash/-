from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-SE-ATTACK6-native-articulated-rig-v03';P=D/'SE-ATTACK6-actual-native-six-rig-and-continuous-cape-candidate-contract-v04.json';O=B/'actual-SE-ATTACK6-native-articulated-rig-v02/SE-ATTACK6-actual-native-six-rig-actual-observed-SE-pole-tips-HOLD-contract-v03.json';j=json.loads(P.read_text());old=json.loads(O.read_text());reg=json.loads(Path(j['shared_once_registration_exact_JSON']['path']).read_text());root=reg['common_rig_root_in_unpadded_frame'];storage=reg['production_storage_translation'];source=np.array(Image.open(j['source']['path']).convert('RGBA'));rows=[];rgba=[]
def pin(p):
 p=Path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
for f,o in zip(j['frames'],old['frames']):
 assert f['common_rig_root_in_unpadded_frame']==root and f['storage_translation']==storage and f['physical_C']==reg['new_SE_fixed_C'];assert f['actual_rig_nodes_unpadded_native']==o['actual_rig_nodes_unpadded_native'];out=Image.new('RGBA',tuple(j['native_canvas']));nd=[];na=[]
 for i,(n,on)in enumerate(zip(f['actual_composition_nodes'],o['actual_composition_nodes'])):
  assert pin(n['path'])==n;ar=np.array(Image.open(n['path']).convert('RGBA'));ao=np.array(Image.open(on['path']).convert('RGBA'));dif=int(np.any(ar!=ao,2).sum());assert i not in [0,1,3]or dif==0;out.alpha_composite(Image.fromarray(ar));na.append(ar);nd.append({'node':Path(n['path']).name,'prior_RGBA_difference':dif,'LEFTupper_LEFTfore_RIGHTupper_unchanged':i in [0,1,3]})
 a=np.array(Image.open(f['path']).convert('RGBA'));assert np.array_equal(a,np.array(out));foot={}
 for k,(x0,y0,x1,y1)in {'imageLEFT_original_complete_boot':[485,1070,680,1240],'imageRIGHT_original_complete_boot':[800,1070,1030,1240]}.items():foot[k]=int(np.any(a[y0+storage[1]:y1+storage[1],x0+storage[0]:x1+storage[0]]!=source[y0:y1,x0:x1],2).sum())
 assert sum(foot.values())==0;cc,n=label(a[:,:,3]>100);s=np.bincount(cc.ravel());s[0]=0;assert int((s>=200).sum())==1;small=[]
 for k in range(1,n+1):
  if 3<=s[k]<200:
   y,x=np.where(cc==k);own=[]
   for z,ar in enumerate(na):
    count=int(((ar[:,:,3]>0)&(cc==k)).sum())
    if count:own.append({'node':Path(f['actual_composition_nodes'][z]['path']).name,'pixels':count})
   small.append({'area':int(s[k]),'stored_bbox':[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)],'actual_node_owners':own})
 rgba.append(hashlib.sha256(a.tobytes()).hexdigest());rows.append({'phase':f['phase'],'actual_frame':pin(f['path']),'actual_nodes_RGBA_recomposition_difference':0,'nodes':nd,'actual_original_complete_boot_RGBA_changes':foot,'fixed_C_root_bodyunit_storage_and_all_phase_controls_drift':0,'rigidstaff_orthogonality_error':f['RIGHT_staff_orthogonality_error'],'actual_source_edge_alpha16_pixels':f['edge_alpha16_pixels'],'strong_body_count':1,'small_alpha100_components_ge3_for_native_QC':small})
assert len(set(rgba))==6;q={'schema':'PR122-SE-actual-final-six-native-node-pole-hand-cape-and-boot-binding-v1','status':'PASS_EXACT_ACTUAL_NODE_RGBA_FIXED_NATIVE_BOOT_AND_REGISTRATION_PENDING_INDEPENDENT_SOURCE_ONE_SHOT_QC','actual_source_contract':pin(P),'prior_HOLD_contract':pin(O),'shared_REG_JSON_exact':j['shared_once_registration_exact_JSON'],'actual_local_cape_protection_proof':pin(B/'actual-own-SE-ATTACK-native-cape-original-visible-hem-join-v05r2/SE-native-original-visible-hem-join-and-complete-oldpart-AA-protection-proof-v05.json'),'actual_source_hand_and_pole_owner_proof':j['actual_hand_pole_material_ownership'],'six_unique_RGBA':6,'checks':rows,'SOURCE_actor_or_game_approval_added':0};p=D/'SE-ATTACK6-v03-exact-current-actual-six-node-finger-pole-cape-boot-proof-v01.json';p.write_text(json.dumps(q,indent=2)+'\n');print(json.dumps({'proof':pin(p),'nodes_RGBA_diff':0,'boots_RGBA_diff':0,'strong_counts':[x['strong_body_count']for x in rows],'small_alpha100_components_ge3':[x['small_alpha100_components_ge3_for_native_QC']for x in rows],'source_approval_added':0}))
