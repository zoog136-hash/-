from pathlib import Path
from PIL import Image
from scipy.ndimage import label
import numpy as np,json,hashlib
B=Path(__file__).parent;O=B/'native-source-parts-v04-complete-RIGHT-rims';O.mkdir(exist_ok=False);old=B/'native-source-parts-v03-complete-RIGHT-jointcaps/SW-exact-own-native-complete-RIGHT-jointcaps-source-contract-v03.json';j=json.loads(old.read_text());src=np.array(Image.open(j['source']['path']).convert('RGBA'));H,W=src.shape[:2];yy,xx=np.indices((H,W));parts={};entries=dict(j['parts'])
def pin(p):p=Path(p);v=p.read_bytes();return dict(path=str(p),bytes=len(v),sha256=hashlib.sha256(v).hexdigest())
for n,r in entries.items():
 a=np.zeros_like(src);x,y,ex,ey=r['native_crop_box'];a[y:ey,x:ex]=np.array(Image.open(r['path']).convert('RGBA'));parts[n]=a
rnames=['RIGHT-full-upper-arm-and-shoulder','RIGHT-white-puff-elbow','RIGHT-complete-forearm-cuff-grip-fingers'];right=np.zeros((H,W),bool)
for n in rnames:right|=parts[n][:,:,3]>0
body=parts['BODY-own-chest-waist-ribbons'];cc,n=label(body[:,:,3]>0);backing=cc==cc[370,500];assert int(backing.sum())==1482
actual_arm_local_support=((xx>=325)&(xx<560)&(yy>=397)&(yy<497))|((xx>=325)&(xx<535)&(yy>=497)&(yy<521))
extra=actual_arm_local_support&(body[:,:,3]>0)&~backing;right|=extra
forearm=right&(xx<=445);puff=(parts['RIGHT-white-puff-elbow'][:,:,3]>0)|((yy>=450)&right&~forearm);puff&=~forearm;upper=right&~puff&~forearm;bodym=(body[:,:,3]>0)&~extra
for name,m in [('RIGHT-full-upper-arm-and-shoulder',upper),('RIGHT-white-puff-elbow',puff),('RIGHT-complete-forearm-cuff-grip-fingers',forearm),('BODY-own-chest-waist-ribbons',bodym)]:
 a=np.zeros_like(src);a[m]=src[m];parts[name]=a;ys,xs=np.where(m);box=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];f=O/f'{name}-complete-native-original-rims-and-backing-owner-v04.png';Image.fromarray(a).crop(box).save(f,optimize=True);entries[name]=dict(**pin(f),native_crop_box=box,native_nonzero_alpha_pixels=int(m.sum()),source_RGBA_mismatch=0)
assert np.array_equal(sum(parts.values(),np.zeros_like(src)),src)
mask=O/'actual-original-RIGHT-rim-and-cap-to-rigid-forearm-owner-mask-v04.png';Image.fromarray(extra.astype('uint8')*255).save(mask,optimize=True)
j.update(schema='MYTHIC413_SW_COMPLETE_RIGHT_RIMS_CAPS_AND_TRUE_BLUE_BACKING_V04',parts=entries,source_partition_disjoint_except_actual_opaque_jointcaps=False,source_part_reconstruction_RGBA_changed=0,source_all_part_RGBA_mismatch=0,source_all_parts_disjoint_and_complete=True,actual_native_jointcap_ownership=dict(visible_elbow_control=[511,443],full_original_white_puff_and_blue_elbow_wall_follow_forearm=True,source_caps_RGBA_unchanged=True,duplicate_opaque_caps_added=0,reason='Native AA-clean source interior alpha is mostly253, so no duplicated opaque cap invented; true full original rim/cap material ownership stays connected'),complete_native_RIGHT_rim_owner_transfer=dict(mask=pin(mask),original_source_pixels=int(extra.sum()),true_blue_head_backing_preserved_pixels=1482,small_old_RIGHT_material_remaining_in_BODY=0,bounded_native_support='x325..559/y397..496 and x325..534/y497..520; isolated true head backing excluded',source_RGBA_mismatch=0),prior_provisional_contract=pin(old))
f=O/'SW-exact-own-native-complete-RIGHT-rims-and-true-backing-v04.json';f.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(contract=pin(f),actual_right_rims=int(extra.sum()))))
