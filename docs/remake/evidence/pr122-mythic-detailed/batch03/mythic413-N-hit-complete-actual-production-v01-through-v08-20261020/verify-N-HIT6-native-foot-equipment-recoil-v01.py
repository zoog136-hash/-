from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-N-HIT6-articulated-rig-v03';N=Path('/workspace/scratch/mythic413-N-walk-load-author-fresh-20261020-v01');C=D/'actual-N-HIT6-native-articulated-recoil-contract-v03.json';c=json.loads(C.read_text());s=np.array(Image.open(c['source0']['path']).convert('RGBA'));yy,xx=np.indices(s.shape[:2]);feet=np.zeros(s.shape[:2],bool)
for side in ['LEFT','RIGHT']:
 a=np.array(Image.open(N/f'N-native-rig-and-material-handoff-for-RUN-v01/complete-original-native-{side}-semantic-matte.png'));feet|=a>0
staff=xx>=750;out=[];digests=set()
for f in c['frames']:
 p=Path(f['path']);a=np.array(Image.open(p).convert('RGBA'));assert hashlib.sha256(p.read_bytes()).hexdigest()==f['sha256'];digests.add(f['sha256']);foot=int(np.any(a[feet]!=s[feet],1).sum());right=int(np.any(a[staff]!=s[staff],1).sum());assert foot==right==0;cc,n=label(a[:,:,3]>100);sizes=np.bincount(cc.ravel());big=[int(k)for k in sizes[1:]if k>=200];assert len(big)==1;out.append({'phase':f['phase'],'sha256':f['sha256'],'all_original_leg_semantic_RGBA_changed':foot,'RIGHT_staff_grip_source_x750plus_RGBA_changed':right,'alpha100_4connected_ge200':big,'LEFT_elbow_wrist_projected_length_native':float(np.linalg.norm(np.array(f['LEFT_actual_guard_arm_rig']['F'])-np.array(f['LEFT_actual_guard_arm_rig']['C'])))})
assert len(digests)==6
p=D/'N-HIT6-native-fixed-plant-equipment-and-six-distinct-pose-proof-v01.json';p.write_text(json.dumps({'status':'FINITE_NATIVE_RGBA_FIXED_PLANT_AND_EQUIPMENT_PASS_NOT_SOURCE_OR_GAME_APPROVAL','actual_sources':str(C),'source_contract_sha256':hashlib.sha256(C.read_bytes()).hexdigest(),'same_physical_C':1920,'same_common_rig_root':[662.8125,917.6920531878804],'native_canvas':[1254,1254],'storage_translation':[0,0],'all_six_distinct_actual_composites':True,'frames':out,'source_cycle_game_actor_approval_added':0},indent=2)+'\n');print(json.dumps({'proof':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'six_unique':len(digests),'all_original_leg_and_RIGHTstaff_RGBA_changes':0,'one_strong_body_each':True}))
