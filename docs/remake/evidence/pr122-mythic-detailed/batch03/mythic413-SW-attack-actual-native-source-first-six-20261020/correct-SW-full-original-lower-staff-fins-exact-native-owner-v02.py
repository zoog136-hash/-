from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import label
import numpy as np,json,hashlib
B=Path(__file__).parent;O=B/'native-source-parts-v02-full-lower-staff';O.mkdir(exist_ok=False);old=B/'native-source-parts-v01/SW-exact-own-native-semantic-parts-and-rig-controls-v01.json';j=json.loads(old.read_text());src=np.array(Image.open(j['source']['path']).convert('RGBA'));parts={};entries=dict(j['parts'])
def pin(p):p=Path(p);b=p.read_bytes();return dict(path=str(p),bytes=len(b),sha256=hashlib.sha256(b).hexdigest())
for n,r in entries.items():
 a=np.zeros_like(src);x0,y0,x1,y1=r['native_crop_box'];a[y0:y1,x0:x1]=np.array(Image.open(r['path']).convert('RGBA'));parts[n]=a
coat=parts['COAT-own-native-UV-tails'];cc,n=label(coat[:,:,3]>0);k=int(cc[900,390]);assert k>0;m=cc==k;ys,xs=np.where(m);assert [int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]==[381,862,401,1006] and int(m.sum())==1293
parts['complete-rigid-RIGHT-staff'][m]=src[m];parts['COAT-own-native-UV-tails'][m]=0
for n in ['complete-rigid-RIGHT-staff','COAT-own-native-UV-tails']:
 a=parts[n];ys,xs=np.where(a[:,:,3]>0);box=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];f=O/(n+'-complete-corrected-exact-original-RGBA-v02.png');Image.fromarray(a).crop(box).save(f,optimize=True);entries[n]=dict(**pin(f),native_crop_box=box,native_nonzero_alpha_pixels=int((a[:,:,3]>0).sum()),source_RGBA_mismatch=0)
assert np.array_equal(sum(parts.values(),np.zeros_like(src)),src)
mask=O/'exact-original-lower-staff-right-fins-AA-owner-transfer-mask-v02.png';Image.fromarray(m.astype('uint8')*255).save(mask,optimize=True)
# The crop lets a reviewer distinguish beveled jeweled staff fins/blade from the cloak V tip.
box=(310,760,445,1085);board=Image.new('RGB',(405,350),(50,50,50));draw=ImageDraw.Draw(board)
for i,(name,a)in enumerate([('ORIGINAL',src),('RIGID STAFF',parts['complete-rigid-RIGHT-staff']),('CLOAK ONLY',parts['COAT-own-native-UV-tails'])]):
 c=Image.fromarray(a).crop(box);bg=Image.new('RGB',c.size,(50,50,50));bg.paste(c,mask=c.getchannel('A'));board.paste(bg,(i*135,25));draw.text((i*135+3,3),name,fill='white')
cf=O/'private-original-full-staff-fin-vs-true-cloak-native-owner-proof-v02.png';board.save(cf,optimize=True);assert cf.stat().st_size<=150000
j.update(schema='MYTHIC413_SW_OWN_EXACT_NATIVE_SEMANTIC_PARTS_V02_COMPLETE_LOWER_STAFF',parts=entries,source_owner_index_mask=None,source_part_reconstruction_RGBA_changed=0,lower_staff_original_right_fin_exact_owner_transfer=dict(native_bbox=[381,862,401,1006],actual_alpha_positive_pixels=1293,mask=pin(mask),source_RGBA_mismatch=0,coat_original_pixels_erased=1293,reason='Own native beveled jewel/fin/blade outside x381 provisional staff cut; complete original blade converges to staff tip, distinct cloak gold V remains coat',private_exact_native_owner_crop=pin(cf)),prior_provisional_contract=pin(old))
f=O/'SW-exact-own-native-semantic-parts-complete-staff-v02.json';f.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps(dict(contract=pin(f),native_owner_crop=pin(cf))))
