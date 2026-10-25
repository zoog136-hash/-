from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-E-ATTACK6-native-articulated-rig-v02';P=D/'E-ATTACK6-actual-native-articulated-six-rig-and-local-cape-contract-v02.json';j=json.loads(P.read_text());reg=json.loads(Path(j['shared_once_registration_exact_JSON']['path']).read_text());root=reg['common_rig_root_in_unpadded_frame'];storage=reg['production_storage_translation']
def pin(p):p=Path(p);r=p.read_bytes();return {'path':str(p),'sha256':hashlib.sha256(r).hexdigest(),'bytes':len(r)}
rows=[];ref=None;rgba=[]
for z in j['frames']:
 assert z['common_rig_root_in_unpadded_frame']==root and z['storage_translation']==storage and z['physical_C']==reg['new_E_fixed_C'];out=Image.new('RGBA',(1792,1792))
 for q in z['actual_composition_nodes']:assert pin(q['path'])==q;out.alpha_composite(Image.open(q['path']).convert('RGBA'))
 a=np.array(Image.open(z['path']).convert('RGBA'));assert not np.any(a!=np.array(out));assert pin(z['path'])['sha256']==z['sha256'];rgba.append(hashlib.sha256(a.tobytes()).hexdigest())
 if ref is None:ref=a.copy()
 footprints={'imageLEFT_original_complete_boot':[500,1090,750,1240],'imageRIGHT_original_complete_boot':[850,1090,1050,1240]};change={}
 for k,(x0,y0,x1,y1)in footprints.items():
  x0+=storage[0];x1+=storage[0];y0+=storage[1];y1+=storage[1];change[k]=int(np.any(a[y0:y1,x0:x1]!=ref[y0:y1,x0:x1],2).sum())
 assert sum(change.values())==0
 c,n=label(a[:,:,3]>100);s=np.bincount(c.ravel());s[0]=0;main=int((s>=200).sum());assert main==1;small=[]
 for v in range(1,n+1):
  if 3<=s[v]<200:
   y,x=np.where(c==v);small.append({'area':int(s[v]),'stored_bbox':[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]})
 rows.append({'phase':z['phase'],'source':pin(z['path']),'rgba_sha256':rgba[-1],'recomposition_all_actual_nodes_RGBA_difference':0,'actual_original_complete_boot_RGBA_difference':change,'strong_body_count':main,'small_alpha100_components_ge3_for_visual_QC':small,'C_root_storage_drift':0,'source_gate':'HOLD_LOCAL_CAPE_BOUNDARY_VISIBLE_SEAM','actor_approvals_added':0})
assert len(set(rgba))==6;q={'schema':'PR122-E-attack-v02-finite-actual-node-fixedboot-and-basis-check-v1','status':'PASS_FINITE_ACTUAL_SOURCE_BINDING_FIXED_BOOT_AND_STORAGE_ONLY_VISUAL_SOURCE_HOLD','actual_source_contract':pin(P),'shared_exact_registration':j['shared_once_registration_exact_JSON'],'six_RGBA_unique':6,'checks':rows,'visual_source_hold':'Original visible goldcross/hem colour and geometry boundary against new local service cape under strict5113mask is not yet accepted. No source/cycle/game approval implied.','actor_approvals_added':0};p=D/'E-ATTACK6-v02-actual-node-and-native-original-boot-finite-proof-v01.json';assert not p.exists();p.write_text(json.dumps(q,indent=2)+'\n');print(json.dumps({'finite_proof':pin(p),'all_nodes_RGBA_diff':0,'all_original_complete_boot_RGBA_diff':0,'strong_counts':[v['strong_body_count']for v in rows],'small_components':[len(v['small_alpha100_components_ge3_for_visual_QC'])for v in rows],'source_status':'HOLD_LOCAL_CAPE_BOUNDARY'}))
