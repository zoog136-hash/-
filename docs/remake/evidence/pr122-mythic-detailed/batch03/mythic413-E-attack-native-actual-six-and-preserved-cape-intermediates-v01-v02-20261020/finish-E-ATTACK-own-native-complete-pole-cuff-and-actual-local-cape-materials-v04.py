from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import label,binary_dilation
import numpy as np,json,hashlib
B=Path(__file__).parent;V=B/'common-own-E-native-arm-staff-materials-v03r1';D=B/'actual-own-E-ATTACK-native-complete-materials-v04';D.mkdir(exist_ok=False);P=V/'E-own-native-complete-arm-staff-and-LEFT-only-body-readonly-handoff-v03.json';j=json.loads(P.read_text());s=Image.open(j['source']['path']).convert('RGBA');a=np.array(s);H,W=a.shape[:2];yy,xx=np.indices((H,W))
def pin(p):p=Path(p);r=p.read_bytes();return {'path':str(p),'sha256':hashlib.sha256(r).hexdigest(),'bytes':len(r)}
def poly(q):m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return np.array(m)>0
# Complete upper pole is the actual connected native ornamented object.
region=(xx>=300)&(xx<475)&(yy<475);c,n=label(region&(a[:,:,3]>16));sizes=np.bincount(c.ravel());sizes[0]=0;idx=int(sizes.argmax());assert sizes[idx]>15000;upper=binary_dilation(c==idx,iterations=2)&region&(a[:,:,3]>0)
weapon=np.array(Image.open(j['parts']['complete-rigid-RIGHT-near-staff']['path']).convert('RGBA'));weapon[region]=0;weapon[upper]=a[upper]
# Two native lower ornament rim fragments were outside approximate edge trace.
for box in [(373,957,381,966),(374,972,382,981)]:
 x0,y0,x1,y1=box;weapon[y0:y1,x0:x1]=a[y0:y1,x0:x1]
wp=D/'original-actual-E-complete-RIGHT-pole-whole-native-ornaments-v04.png';Image.fromarray(weapon).save(wp);j['parts']['complete-rigid-RIGHT-near-staff']=pin(wp)
# Original visible RIGHT upper pauldron owns warm skin/gold pixels; only the
# actual blue hair streamer and its AA are kept in the head/core.
ru=poly([(591,345),(628,330),(652,341),(678,362),(676,388),(664,416),(649,439),(628,462),(611,485),(588,494),(560,490),(542,474),(538,454),(550,434),(569,416),(585,400)])
hairshape=poly([(633,280),(687,287),(645,328),(606,367),(570,403),(538,435),(523,452),(505,439),(496,442),(476,442),(507,409),(539,379),(585,335)])|poly([(638,414),(663,414),(664,466),(650,495),(643,481),(628,494),(625,454)])
blue=(a[:,:,2]>a[:,:,0]*1.28)&(a[:,:,2]>a[:,:,1]*1.1)&(a[:,:,3]>0);hair=hairshape&binary_dilation(blue,iterations=1);ru=binary_dilation(ru,iterations=2)&~hair;rup=a.copy();rup[~ru]=0;rp=D/'original-actual-E-RIGHT-near-upper-arm-actual-skin-and-pauldron-v04.png';Image.fromarray(rup).save(rp);rm=D/'original-actual-E-RIGHT-near-upper-arm-complete-semantic-matte-v04.png';Image.fromarray(ru.astype('uint8')*255).save(rm);j['parts']['RIGHT-near-upper-arm']=pin(rp);j['semantic_mattes']['RIGHT-near-upper-arm']=pin(rm)
# Finite source-native lower forecuff rim belongs to its moving gauntlet.
rf=np.array(Image.open(j['parts']['RIGHT-near-complete-forearm-grip-hand']['path']).convert('RGBA'));rfm=np.array(Image.open(j['semantic_mattes']['RIGHT-near-complete-forearm-grip-hand']['path']).convert('L'))>0
coreold=np.array(Image.open(B/'actual-E-ATTACK6-native-articulated-rig-v01/original-actual-E-full-body-original-boots-complete-old-arms-pole-erased-INPUT-HOLD-cape.png'))[:H,:W];cc,n=label(coreold[:,:,3]>100);rim=np.zeros((H,W),bool)
for z in range(1,n+1):
 y,x=np.where(cc==z)
 if len(x)==77 and [int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]==[452,534,479,543]:rim|=cc==z
assert int(rim.sum())==77;rim=binary_dilation(rim,iterations=2)&(a[:,:,3]>0);rf[rim]=a[rim];rfm|=rim;fp=D/'original-actual-E-RIGHT-complete-forearm-grip-native-cuff-rim-v04.png';Image.fromarray(rf).save(fp);fm=D/'original-actual-E-RIGHT-complete-forearm-grip-native-cuff-matte-v04.png';Image.fromarray(rfm.astype('uint8')*255).save(fm);j['parts']['RIGHT-near-complete-forearm-grip-hand']=pin(fp);j['semantic_mattes']['RIGHT-near-complete-forearm-grip-hand']=pin(fm)
# Actual newly painted local cloth: fixed output-canvas registration to the
# requested 250-square crop, never actor alpha/body normalization.
RH=Path('/workspace/scratch/mythic413-E-cape-clearplate-private-retouch-fresh-20261020-v01/E-cape-local-retouch-final-handoff-v01.json');rh=json.loads(RH.read_text());raw=Path(rh['output']);assert pin(raw)['sha256']==rh['sha256'];paint=Image.open(raw).convert('RGBA').resize((250,250),Image.Resampling.LANCZOS);replacement=np.array(Image.open(rh['replacement_mask_source']['path']).convert('L'))>0;assert int(replacement.sum())==5113
plate=a.copy();crop=plate[770:1020,260:510].copy();crop[replacement]=np.array(paint)[replacement];plate[770:1020,260:510]=crop;fullmask=np.zeros((H,W),bool);fullmask[770:1020,260:510]=replacement;assert not np.any(plate[~fullmask]!=a[~fullmask]);pp=D/'actual-original-E-source-only-local-occluded-cape-repainted-native-v04.png';Image.fromarray(plate).save(pp);npth=D/'actual-local-painted-cape-fixed-native-250-registration-v04.png';paint.save(npth)
erase=ru|rfm
for k in ['LEFT-far-upper-arm','LEFT-far-complete-curved-cuff-forearm-free-hand']:erase|=np.array(Image.open(j['semantic_mattes'][k]['path']).convert('L'))>0
erase|=weapon[:,:,3]>0;erase&=~fullmask;core=plate.copy();core[erase]=0;cp=D/'actual-E-complete-old-arms-staff-erased-body-fixed-boots-and-actual-new-cape-clearplate-v04.png';Image.fromarray(core).save(cp);em=D/'actual-E-complete-old-arms-staff-erasure-preserving-new-cape-mask-v04.png';Image.fromarray(erase.astype('uint8')*255).save(em)
j['body_inputs']['attack-final-CORE-actual-local-cape-retouch']={'body':pin(cp),'complete_old_erasure_mask':pin(em),'source_visual_status':'ACTUAL_NEW_LOCAL_CLOTH_SOURCE_PENDING_INDEPENDENT_QC'};j['actual_local_cape_retouch']={'service_handoff':pin(RH),'raw_unmodified':pin(raw),'fixed_requested_crop_rect':[260,770,510,1020],'raw_size':[1254,1254],'local_painted_texture_registration':'1254-square service crop mapped once to requested250-square native crop, no body/actor resample or root fit','local_native_paint':pin(npth),'source_masked_only_plate':pin(pp),'replacement_pixels':int(fullmask.sum()),'outside_replacement_source_RGBA_difference':0,'actor_OR_source_C_root_unit_CHANGED':False};j['actual_complete_pole_and_forecuff_native_transfer']={'upper_pole_component_alpha16_native_pixels':int((c==idx).sum()),'RIGHT_forecuff_rim_native_strong':77,'RIGHT_forecuff_rim_with_AA':int(rim.sum()),'original_source_modified':False};j['prior_material_input']=pin(P);j['source_production_status']='ACTUAL_NEW_E_ATTACK_MATERIALS_COMPLETE_PENDING_PARTS_CAPE_AND_SIX_CYCLE_SOURCE_QC';p=D/'E-ATTACK-own-complete-native-parts-and-actual-local-cape-provenance-v04.json';p.write_text(json.dumps(j,indent=2)+'\n')
print(json.dumps({'materials':pin(p),'complete_upper_pole_native_pixels':int(upper.sum()),'masked_cloth_native_pixels':int(fullmask.sum()),'outside_local_cloth_source_RGBA_difference':0}))
