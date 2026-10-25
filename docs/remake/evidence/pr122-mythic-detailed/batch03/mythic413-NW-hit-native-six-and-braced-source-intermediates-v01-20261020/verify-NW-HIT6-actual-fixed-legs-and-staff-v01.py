from pathlib import Path
import json,hashlib,numpy as np
from PIL import Image
P=Path(__file__).parent;O=P/'actual-NW-HIT6-native-braced-recoil-v02'
F=O/'NW-HIT-six-actual-native-source-and-common-root-contract-v02.json';d=json.load(open(F))
def pad(p):
 a=Image.new('RGBA',(1536,1536));a.paste(Image.open(p).convert('RGBA'),(0,0));return np.array(a)
base=pad(P/'actual-braced-stance-v03/thunder_female-NW-HIT-braced-fixed-stance-candidate-v03.png')
legs=pad(P/'actual-braced-stance-v03/NW-HIT-articulated-braced-legs-and-complete-shoes.png');yy,xx=np.indices(base.shape[:2]);lm=(legs[:,:,3]>16)&(yy>=730)
S=Path('/workspace/scratch/mythic413-NW-attack-author-20261020-v01/actual-NW-ATTACK6-native-rig-v03/actual-original-NW-complete-rigid-RIGHT-staff-material.png')
sm=pad(S)[:,:,3]>100
records=[];prev=None
for z in d['frames']:
 a=np.array(Image.open(z['path']).convert('RGBA'));diff=np.any(a!=base,axis=2)
 records.append(dict(phase=z['phase'],source_sha256=z['sha256'],actual_leg_material_pixels=int(lm.sum()),actual_leg_RGBA_changed=int((diff&lm).sum()),complete_native_staff_material_pixels=int(sm.sum()),complete_native_staff_RGBA_changed=int((diff&sm).sum()),LEFT_actual_heel_alpha100_bottom=int(np.where(a[920:960,495:540,3]>=100)[0].max()+920),RIGHT_actual_heel_alpha100_bottom=int(np.where(a[1100:1130,684:720,3]>=100)[0].max()+1100),changed_RGBA_from_base=int(diff.sum()),changed_RGBA_from_previous=None if prev is None else int(np.any(a!=prev,axis=2).sum())))
 prev=a
result=dict(status='NUMERIC_MATERIAL_PRESERVATION_ONLY_PENDING_ACTUAL_SOURCE_CYCLE_QC',physical_C_fixed=2048,root_fixed=[641,1058.3],source_contract_sha256=hashlib.sha256(F.read_bytes()).hexdigest(),mask_rules=dict(legs='actual new braced-leg layer alpha>16 and y>=730, no background rectangles',staff='complete actual original rigid RIGHTstaff semantic source alpha>100, no threshold relaxation'),records=records,actor_approval_added=0)
out=O/'NW-HIT-six-exact-fixed-actual-legs-flatshoes-and-complete-staff-proof-v01.json';assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n')
assert all(z['actual_leg_RGBA_changed']==0 and z['complete_native_staff_RGBA_changed']==0 for z in records)
print(json.dumps(dict(proof=str(out),sha256=hashlib.sha256(out.read_bytes()).hexdigest(),actual_leg_pixels=int(lm.sum()),actual_staff_pixels=int(sm.sum()),actual_leg_or_staff_changes=0)))
