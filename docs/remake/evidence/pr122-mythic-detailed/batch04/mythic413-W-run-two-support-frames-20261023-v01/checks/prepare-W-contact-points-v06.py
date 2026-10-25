from pathlib import Path
import hashlib,json,shutil
import numpy as np
from PIL import Image
T=Path(__file__).parent
W=Path('/workspace/scratch/mythic413-W-run-own-native-20261022-v01')
L=Path('/workspace/scratch/pr122-death-s-only-20261022-v01')
c=json.loads((W/'actual-W-RUN-six-own-native-v06-world-contact/W-RUN-six-own-native-source-contract-v06.json').read_text())
def checked(r):
 p=Path(r['path']); assert hashlib.sha256(p.read_bytes()).hexdigest()==r['sha256']; return p
legs=json.loads(checked(c['source_materials']['legs']).read_text())
points={}; pairs=[]
for side, phases in [('L-near',[0,1]),('R-far',[3,4])]:
 a=np.array(Image.open(checked(legs['parts'][side])).convert('RGBA'))
 y,x=np.where((a[:,:,3]>100)&(np.indices(a.shape[:2])[0]>=1000)); native=np.stack([x,y],axis=1).astype(float)
 transformed=[]; mask=np.ones(len(x),bool)
 for i in phases:
  b=c['frames'][i]['bones'][side]; q=native@np.array(b['lower']).T+np.array(b['lower_offset']); transformed.append(q); mask &= q[:,1]>=q[:,1].max()-0.5
 idx=np.flatnonzero(mask); assert len(idx)>0
 idx=int(idx[len(idx)//2]); root=np.array(c['common_rig_root_unpadded']); C=c['C']
 for i,q in zip(phases,transformed):
  points[str(i)]={'side':side,'native_original_texel':native[idx].tolist(),'local':[float(q[idx,0]-root[0]),float(C/8+q[idx,1]-root[1])]}
 pairs.append({'side':side,'phases':phases})
meta={'scope':'ACTUAL_MAIN_PLAYER_SPRITE_TRANSFORM_WITH_PRESCRIBED_WORLD_TRANSLATION_NO_COLLISION_PHYSICS','source_contract':str(W/'actual-W-RUN-six-own-native-v06-world-contact/W-RUN-six-own-native-source-contract-v06.json'),'points':points,'pairs':pairs}
(T/'W-contact-points-v06.json').write_text(json.dumps(meta,indent=2)+'\n')
