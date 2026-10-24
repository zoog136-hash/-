from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,hashlib
B=Path(__file__).parent;O=B/'native-W-source-parts-v02-exact-rims-bow';O.mkdir(exist_ok=False);P=B/'native-W-source-parts-v01/W-exact-native-RIGHT-fullstaff-near-LEFT-upper-real-cloth-source-parts-v01.json';j=json.loads(P.read_text());src=np.array(Image.open(j['actual_BODY_input_with_single_real_native_hidden_coat']['path']).convert('RGBA'));H,W=src.shape[:2];yy,xx=np.indices((H,W));parts={};entries=dict(j['parts'])
def pin(p):p=Path(p);b=p.read_bytes();return dict(path=str(p),bytes=len(b),sha256=hashlib.sha256(b).hexdigest())
for n,r in entries.items():
 a=np.zeros_like(src);x,y,ex,ey=r['native_crop_box'];a[y:ey,x:ex]=np.array(Image.open(r['path']).convert('RGBA'));parts[n]=a
st=parts['complete-rigid-RIGHT-staff'];cc,n=label(st[:,:,3]>0);k=cc[465,430];rim=cc==k;assert int(rim.sum())==105;parts['RIGHT-complete-forearm-cuff-grip-fingers'][rim]=src[rim];st[rim]=0
u=parts['RIGHT-full-visible-upper-arm'];low=(u[:,:,3]>0)&(yy>=450);parts['RIGHT-white-puff-elbow'][low]=src[low];u[low]=0
body=parts['BODY-own-profile-chest-waist-ribbons'];cc,n=label(body[:,:,3]>0);end=cc==cc[480,738];assert int(end.sum())==181;parts['LEFT-full-near-upper-arm'][end]=src[end];body[end]=0
lu=parts['LEFT-full-near-upper-arm'];rgb=src[:,:,:3].astype(float);bow=(lu[:,:,3]>0)&(xx>=734)&(yy<=435)&(rgb[:,:,2]>60)&(rgb[:,:,2]>rgb[:,:,0]*1.2)&(rgb[:,:,2]>rgb[:,:,1]*1.2);body[bow]=src[bow];lu[bow]=0
changed=['complete-rigid-RIGHT-staff','RIGHT-complete-forearm-cuff-grip-fingers','RIGHT-white-puff-elbow','RIGHT-full-visible-upper-arm','LEFT-full-near-upper-arm','BODY-own-profile-chest-waist-ribbons']
for name in changed:
 a=parts[name];ys,xs=np.where(a[:,:,3]>0);box=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];f=O/f'{name}-exact-original-native-owner-v02.png';Image.fromarray(a).crop(box).save(f,optimize=True);entries[name]=dict(**pin(f),native_crop_box=box,native_nonzero_alpha_pixels=int((a[:,:,3]>0).sum()),actual_input_RGBA_mismatch=0)
rec=np.zeros_like(src)
for n,a in parts.items():
 if n!='LEFT-complete-original-curved-cuff-forearm-free-fingers':rec+=a
assert np.array_equal(rec,src)
mask=O/'W-exact-native-staff-arm-rim-and-head-bow-owner-transfer-indices-v02.png';Image.fromarray((rim.astype('uint8')+low.astype('uint8')*2+end.astype('uint8')*3+bow.astype('uint8')*4)).save(mask,optimize=True)
j.update(schema='MYTHIC413_W_EXACT_NATIVE_VISIBLE_RIGHT_LEFT_RIMS_TRUE_BOW_V02',parts=entries,actual_BODY_RGBA_reconstruction_changed=0,source_owner_corrections=dict(mask=pin(mask),original_staff_misowned_forearm_goldrim_pixels=105,actual_outer_RIGHT_puff_wall_from_upper_pixels=int(low.sum()),actual_near_upper_dark_rim_restored_pixels=181,true_blue_head_bow_restored_to_BODY_pixels=int(bow.sum()),source_RGBA_mismatch=0,prior_contract=pin(P)))
f=O/'W-exact-native-complete-RIGHT-staff-LEFT-upper-and-true-bow-parts-v02.json';f.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(contract=pin(f),RIGHT_puff_wall=int(low.sum()),true_bow=int(bow.sum()))))
