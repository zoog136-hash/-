from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-SE-ATTACK6-native-articulated-rig-v02';P=D/'SE-ATTACK6-actual-native-articulated-six-rig-and-local-cape-HOLD-contract-v02.json';j=json.loads(P.read_text());m=json.loads(Path(j['shared_materials']['path']).read_text());a=np.array(Image.open(m['parts']['complete-rigid-RIGHT-near-staff']['path']));ys,xs=np.where(a[:,:,3]>100);top=int(ys.min());bot=int(ys.max());T=np.array([float(np.where(a[top,:,3]>100)[0].mean()),float(top)]);BT=np.array([float(np.where(a[bot,:,3]>100)[0].mean()),float(bot)]);G=np.array(m['actual_native_controls']['RIGHT_original_grip'],float)
def pin(p):
 p=Path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
for f in j['frames']:
 M=np.array(f['RIGHT_rigid_staff_matrix']);g=np.array(f['RIGHT_exact_same_forearm_affine_grip_target']);f['native_original_full_staff_top_tip_target']=(M@(T-G)+g).tolist();f['native_original_full_staff_bottom_tip_target']=(M@(BT-G)+g).tolist()
j['observed_original_complete_staff_tips_alpha100']={'top_tip':T.tolist(),'bottom_tip':BT.tolist(),'observation_scope':'Actual same SE native painted tip pixels; no unique hidden3D reconstruction.'};j['prior_metadata_contract']=pin(P);j['metadata_repin_only_PNG_changes']=0;j['metadata_correction']='Replaced inherited E-only approximate top-tip metadata with this own SE original observed wholepole endpoints; actual rendered PNG/rig matrices unchanged.';q=D/'SE-ATTACK6-actual-native-six-rig-actual-observed-SE-pole-tips-HOLD-contract-v03.json';q.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps({'contract':pin(q),'native_actual_source_top':T.tolist(),'native_actual_source_bottom':BT.tolist(),'actual_png_changed':0}))
