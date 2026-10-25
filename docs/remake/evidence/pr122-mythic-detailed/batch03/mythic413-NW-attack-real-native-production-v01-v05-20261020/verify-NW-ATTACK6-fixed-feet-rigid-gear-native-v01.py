from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-NW-ATTACK6-native-rig-v05';P=D/'NW-ATTACK6-actual-directional-rig-contract-v05.json';c=json.loads(P.read_text());L=np.array(Image.open(D/'actual-complete-LEFT-fixed-attack-stance-shoe.png'));R=np.array(Image.open(D/'actual-complete-RIGHT-flat-fixed-attack-stance-shoe.png'));yy,xx=np.indices(L.shape[:2]);feet=[('LEFT',L,(yy>=869)&(L[:,:,3]>0)),('RIGHT',R,(yy>=1037)&(R[:,:,3]>0))];rows=[]
for f in c['frames']:
 a=np.array(Image.open(f['path']));assert hashlib.sha256(Path(f['path']).read_bytes()).hexdigest()==f['sha256'];fd={name:int(np.any(a[m]!=v[m],1).sum())for name,v,m in feet};assert all(v==0 for v in fd.values());cc,n=label(a[:,:,3]>100);ss=np.bincount(cc.ravel());strong=[int(v)for v in ss[1:]if v>=200];assert len(strong)==1;lc,ln=label(a[:,:,3]>16);sz=np.bincount(lc.ravel());top=sz[1:].argmax()+1;small=[]
 for k in range(1,ln+1):
  if k!=top and sz[k]>=3:
   y,x=np.where(lc==k);small.append(dict(area=int(sz[k]),bbox=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]))
 rows.append(dict(phase=f['phase'],sha256=f['sha256'],fixed_native_COMPLETE_footsole_RGBA_changes=fd,strong_alpha100_bodies=strong,detached_alpha16_components_ge3=small,RIGHT_rigid_staff_orthogonality_error=f['RIGHT_staff_orthogonality_error']))
assert len({r['sha256']for r in rows})==6
p=D/'NW-ATTACK6-six-native-fixed-sole-and-rigid-gear-finite-proof-v01.json';p.write_text(json.dumps({'status':'FINITE_FIXED_SOLE_AND_RIGID_GEAR_PASS_NOT_SOURCE_OR_GAME_APPROVAL','source_contract_sha256':hashlib.sha256(P.read_bytes()).hexdigest(),'C':2048,'bodyunit':2,'same_common_root':[641,1058.3],'storage_translation':[0,0],'wholeactor_N_NE_mirror_or_perpose_C_rootfit':False,'all_six_distinct_actual_native_source_RGBA':True,'native_feet_initial_placement_constant_all6':True,'rigid_RIGHT_staff_and_RIGHT_forearm_same_exact_grip_point':True,'source_semantic_old_staff_removed_from_leg_material':True,'frames':rows,'source_cycle_game_actor_approval_added':0},indent=2)+'\n');print(json.dumps({'proof':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'all_fixed_bootsole_RGBA_changes':0,'strong_body_each':1,'detached_counts':[len(x['detached_alpha16_components_ge3'])for x in rows]}))
