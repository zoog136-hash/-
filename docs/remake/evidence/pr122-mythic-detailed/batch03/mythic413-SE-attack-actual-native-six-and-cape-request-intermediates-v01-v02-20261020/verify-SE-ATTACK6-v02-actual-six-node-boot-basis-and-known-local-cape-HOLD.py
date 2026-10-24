from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-SE-ATTACK6-native-articulated-rig-v02';P=D/'SE-ATTACK6-actual-native-six-rig-actual-observed-SE-pole-tips-HOLD-contract-v03.json';j=json.loads(P.read_text());reg=json.loads(Path(j['shared_once_registration_exact_JSON']['path']).read_text());root=reg['common_rig_root_in_unpadded_frame'];storage=reg['production_storage_translation'];source=np.array(Image.open(j['source']['path']).convert('RGBA'));rows=[];rgba=[]
def pin(p):
 p=Path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
for f in j['frames']:
 assert f['common_rig_root_in_unpadded_frame']==root and f['storage_translation']==storage and f['physical_C']==reg['new_SE_fixed_C'];out=Image.new('RGBA',tuple(j['native_canvas']))
 for n in f['actual_composition_nodes']:
  assert pin(n['path'])==n;out.alpha_composite(Image.open(n['path']).convert('RGBA'))
 a=np.array(Image.open(f['path']).convert('RGBA'));assert np.array_equal(a,np.array(out));foot={}
 for k,(x0,y0,x1,y1)in {'imageLEFT_original_complete_boot':[485,1070,680,1240],'imageRIGHT_original_complete_boot':[800,1070,1030,1240]}.items():
  foot[k]=int(np.any(a[y0+storage[1]:y1+storage[1],x0+storage[0]:x1+storage[0]]!=source[y0:y1,x0:x1],2).sum())
 assert sum(foot.values())==0;cc,n=label(a[:,:,3]>100);s=np.bincount(cc.ravel());s[0]=0;main=int(s.argmax());det=[]
 for k in range(1,n+1):
  if k!=main and s[k]>=200:
   y,x=np.where(cc==k);box=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)];assert 380<=box[0]<550 and 870<=box[1]<1100
   core=np.array(Image.open(f['actual_composition_nodes'][2]['path']));assert int(((core[:,:,3]>100)&(cc==k)).sum())==int(s[k]);det.append({'area':int(s[k]),'stored_bbox':box,'semantic':'Actual native cape under original foreground pole, detached until local hidden-cloth retouch. SOURCE HOLD.'})
 rgba.append(hashlib.sha256(a.tobytes()).hexdigest());rows.append({'phase':f['phase'],'actual_frame':pin(f['path']),'actual_nodes_recomposition_RGBA_difference':0,'actual_original_boot_RGBA_changes':foot,'fixed_C_root_storage_drift':0,'rigidstaff_orthogonality_error':f['RIGHT_staff_orthogonality_error'],'strong_components_ge200':int((s>=200).sum()),'unresolved_local_cape':det})
assert len(set(rgba))==6;q={'schema':'PR122-SE-attack-finite-actual-node-and-originalboot-proof-v1','status':'ACTUAL_NODES_BOOT_BASIS_PASS_SOURCE_HOLD_LOCAL_CAPE_AND_PENDING_ACTUAL_JOINT_QC','actual_source_contract':pin(P),'six_unique_RGBA':6,'checks':rows,'actor_approvals_added':0,'fullSOURCE_cycle_or_game_approval':False};p=D/'SE-ATTACK6-actual-node-boot-basis-and-only-known-cape-HOLD-proof-v01.json';p.write_text(json.dumps(q,indent=2)+'\n');print(json.dumps({'proof':pin(p),'nodes_RGBA_diff':0,'boots_RGBA_diff':0,'strong_counts':[r['strong_components_ge200']for r in rows],'remaining_seam_HOLD':True,'source_approval_added':0}))
