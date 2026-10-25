from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-own-SE-ATTACK-native-complete-materials-v02';D.mkdir(exist_ok=False);P=B/'actual-own-SE-ATTACK-native-complete-materials-v01/SE-ATTACK-own-complete-native-materials-and-unfinished-cape-provenance-v01.json';j=json.loads(P.read_text());a=np.array(Image.open(j['source']['path']).convert('RGBA'));wm=np.array(Image.open(j['semantic_mattes']['complete-rigid-RIGHT-near-staff']['path']).convert('L'))>0;wp=np.array(Image.open(j['parts']['complete-rigid-RIGHT-near-staff']['path']).convert('RGBA'));yy,xx=np.indices(wm.shape)
# This complete lower original blade is isolated by genuine transparent
# native background (cape ended above1008; nearest boot is rightof485).
r=(yy>=1008)&(yy<1140)&(xx>=340)&(xx<466);wm[r]=a[:,:,3][r]>0;wp[r]=a[r]
def pin(p):
 p=Path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
p=D/'original-actual-SE-complete-rigid-RIGHT-staff-full-lower-blade-native-v02.png';Image.fromarray(wp).save(p);j['parts']['complete-rigid-RIGHT-near-staff']=pin(p);p=D/'original-actual-SE-complete-RIGHT-staff-semantic-matte-v02.png';Image.fromarray(wm.astype('uint8')*255).save(p);j['semantic_mattes']['complete-rigid-RIGHT-near-staff']=pin(p)
erase=wm.copy()
for k in ['RIGHT-near-upper-arm','RIGHT-near-complete-forearm-grip-hand','LEFT-far-upper-arm','LEFT-far-complete-curved-cuff-forearm-free-hand']:erase|=np.array(Image.open(j['semantic_mattes'][k]['path']).convert('L'))>0
core=a.copy();core[erase]=0;p=D/'actual-SE-complete-old-arms-staff-erased-BODY-complete-lower-pole-removal-native-v02.png';Image.fromarray(core).save(p);j['fullCORE']=pin(p);p=D/'actual-SE-complete-old-arms-staff-erasure-native-v02.png';Image.fromarray(erase.astype('uint8')*255).save(p);j['complete_old_erasure_mask']=pin(p);j['prior_material']=pin(P);j['complete_original_lower_pole_RGBA_transferred']=int((r&(a[:,:,3]>0)).sum());j['lower_native_pole_part_source_RGBA_difference']=0;p=D/'SE-ATTACK-own-complete-native-materials-and-unfinished-cape-provenance-v02.json';p.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps({'materials':pin(p),'complete_lower_original_pixels':j['complete_original_lower_pole_RGBA_transferred']}))
