from pathlib import Path
from PIL import Image
from scipy.ndimage import label,binary_dilation
import numpy as np,json,hashlib
B=Path(__file__).parent;V=B/'common-own-E-native-arm-staff-materials-v02';D=B/'common-own-E-native-arm-staff-materials-v03r1';D.mkdir(exist_ok=False);P=V/'E-own-native-complete-arm-staff-and-LEFT-only-body-readonly-handoff-v02.json';j=json.loads(P.read_text());s=Image.open(j['source']['path']).convert('RGBA');a=np.array(s);oldbody=np.array(Image.open(j['body_inputs']['complete-LEFT-arm-old-erased-BODY-with-original-RIGHT-staff-and-boots']['body']['path']));cc,n=label(oldbody[:,:,3]>100);selected=[];details=[]
for z in range(1,n+1):
 y,x=np.where(cc==z)
 box=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]
 if box in [[835,507,891,540],[789,525,856,584],[930,618,937,621]]:selected.append(z);details.append({'alpha100_area':len(x),'bbox':box})
assert len(selected)==3;transfer=binary_dilation(np.isin(cc,selected),iterations=2)&(a[:,:,3]>0)
name='LEFT-far-complete-curved-cuff-forearm-free-hand';oldpart=np.array(Image.open(j['parts'][name]['path']));part=oldpart.copy();part[transfer]=a[transfer];mat=np.array(Image.open(j['semantic_mattes'][name]['path']))>0;mat|=transfer
p=D/f'original-actual-E-{name}-complete-native-cap-v03.png';Image.fromarray(part).save(p);mp=D/f'original-actual-E-{name}-complete-semantic-matte-v03.png';Image.fromarray(mat.astype('uint8')*255).save(mp)
def pin(p):p=Path(p);r=p.read_bytes();return {'path':str(p),'sha256':hashlib.sha256(r).hexdigest(),'bytes':len(r)}
j['parts'][name]=pin(p);j['semantic_mattes'][name]=pin(mp);lu=np.array(Image.open(j['semantic_mattes']['LEFT-far-upper-arm']['path']))>0
for k,m in [('LEFT-forearm-only-old-erased-BODY-with-original-RIGHT-staff-arms-and-boots',mat),('complete-LEFT-arm-old-erased-BODY-with-original-RIGHT-staff-and-boots',mat|lu)]:
 out=a.copy();out[m]=0;bp=D/f'actual-E-{k}-complete-native-cap-v03.png';Image.fromarray(out).save(bp);mm=D/f'complete-original-E-{k}-erasure-mask-v03.png';Image.fromarray(m.astype('uint8')*255).save(mm);j['body_inputs'][k]={'body':pin(bp),'complete_old_erasure_mask':pin(mm),'outside_erasure_RGBA_changed':int(np.any(out[~m]!=a[~m],1).sum())}
full=np.array(Image.open(j['body_inputs']['complete-LEFT-arm-old-erased-BODY-with-original-RIGHT-staff-and-boots']['body']['path']));co,cn=label(full[:,:,3]>100);sz=np.bincount(co.ravel());sz[0]=0
j['source_production_status']='ACTUAL_ORIGINAL_CURVED_CUFF_NATIVE_PART_OWNERSHIP_COMPLETED_PENDING_INDEPENDENT_QC';j['prior_source_material_manifest']=pin(P);j['actual_LEFT_cuff_component_transfer']={'source_fragments':details,'native_actual_RGBA_and_AA_pixels':int(transfer.sum()),'source_RGBA_diff_on_transfer':int(np.any(part[transfer]!=a[transfer],1).sum()),'outside_transfer_actual_part_RGBA_changed':int(np.any(part[~transfer]!=oldpart[~transfer],1).sum()),'RIGHT_arm_staff_boot_or_global_density_changed':False,'whole_LEFT_erased_body_alpha100_components_ge200':[int(v)for v in sz if v>=200]};j['body_inputs']['full-attack-CORE-with-native-fabric-restoration-INPUT']['source_visual_status']='HOLD_VISIBLE_COAT_RESTORATION_NOT_ACCEPTED_PENDING_ACTUAL_RETOUCH';p=D/'E-own-native-complete-arm-staff-and-LEFT-only-body-readonly-handoff-v03.json';p.write_text(json.dumps(j,indent=2)+'\n');print(json.dumps({'manifest':pin(p),'native_actual_cuff_pixels':int(transfer.sum()),'complete_LEFT_erased_strong_bodies':[int(v)for v in sz if v>=200]}))
