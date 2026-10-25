from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import distance_transform_edt,label
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-own-SE-ATTACK-native-complete-pole-hand-and-expanded-cape-v04';D.mkdir(exist_ok=False);P=B/'actual-own-SE-ATTACK-native-local-cape-strict-mask-v03/SE-ATTACK-own-complete-native-materials-and-actual-local-cape-provenance-v03.json';j=json.loads(P.read_text());a=np.array(Image.open(j['source']['path']).convert('RGBA'));H,W=a.shape[:2];yy,xx=np.indices((H,W));oldrf=np.array(Image.open(j['parts']['RIGHT-near-complete-forearm-grip-hand']['path']).convert('RGBA'));oldwp=np.array(Image.open(j['parts']['complete-rigid-RIGHT-near-staff']['path']).convert('RGBA'));oldwm=np.array(Image.open(j['semantic_mattes']['complete-rigid-RIGHT-near-staff']['path']).convert('L'))>0

def pin(p):
 p=Path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
def poly(q):
 m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return np.array(m)>0
# New finite native contour tracing, fixed source coordinates. Upper tip and
# continuous exposed shaft are identical; full lower blade uses real original
# alpha on genuinely transparent background, not a sampled geometric ending.
left=[(394,750),(395,775),(392,783),(391,789),(387,793),(383,798),(389,802),(391,806),(391,812),(395,818),(394,823),(390,830),(385,837),(384,842),(391,848),(395,854),(389,861),(384,866),(382,870),(389,878),(390,881),(384,884),(381,888),(379,895),(382,900),(389,906),(390,909),(387,913),(381,920),(377,928),(376,932),(383,939),(387,947),(391,955),(399,963),(402,968),(399,973),(393,978),(388,984),(386,990),(383,995),(382,1000)]
right=[(414,750),(416,778),(420,783),(423,787),(430,790),(429,794),(424,798),(421,804),(420,809),(422,816),(418,823),(419,830),(423,838),(429,842),(427,847),(422,852),(423,857),(428,862),(432,867),(430,870),(428,875),(432,879),(431,885),(436,889),(438,896),(433,901),(430,906),(431,911),(434,917),(441,925),(446,932),(446,935),(441,942),(434,950),(428,958),(424,967),(426,975),(432,980),(440,986),(449,994),(450,1000)]
lo=poly(left+right[::-1]);wm=oldwm.copy();wm[yy>=750]=False;wm|=lo;lower=(yy>=1000)&(yy<1140)&(xx>=340)&(xx<451);wm[lower]=a[:,:,3][lower]>0
# Native original fingers must belong to foregrip. The initial generic gold
# predicate had mistaken warm pink finger segments for metal on the near pole.
# True gold is saturated yellow; its near-white highlight has R/G near one.
coef=j['staff_axis_once_from_original_visible_metal'];axis=coef[0]*yy+coef[1];band=abs(xx-axis)<15
rgb=a[:,:,:3].astype(float);metal=band&(((rgb[:,:,0]>70)&(rgb[:,:,1]>35)&(rgb[:,:,2]<rgb[:,:,1]*.54))|((rgb[:,:,0]>.95*rgb[:,:,1])&(rgb[:,:,0]<1.09*rgb[:,:,1])&(rgb[:,:,1]>85)&(rgb[:,:,2]<rgb[:,:,1]*.95)))
fist=(xx>=348)&(xx<417)&(yy>=441)&(yy<497);skinhand=fist&~metal&(a[:,:,3]>0)
rf=oldrf.copy();rf[skinhand]=a[skinhand];rf[fist&metal]=0
# Exposed shaft above/below this original fist is proper rigid metal, including
# its pale highlights and full dark edge/AA. No skin/finger pixels are deleted.
shaftoutside=((yy>=425)&(yy<441)|(yy>=497)&(yy<522))&(xx>=350)&(xx<417)&band
rf[shaftoutside]=0;wm|=shaftoutside;wm[skinhand]=False;wm[fist&metal]=True
wp=a.copy();wp[~wm]=0
profile=[]
for u in range(-13,14):profile.append(np.median([a[y,int(round(coef[0]*y+coef[1]))+u,:3]for y in range(560,741)],axis=0))
# Only material hidden by actual skin is filled by the same exposed shaft
# profile. Pink source pixels never travel on the independently rotating pole.
for y in range(435,515):
 cx=float(coef[0]*y+coef[1])
 for x in range(int(cx-13),int(cx+14)):
  if abs(x-cx)<13 and (wp[y,x,3]==0 or skinhand[y,x]):
   wp[y,x,:3]=profile[int(np.clip(round(x-cx)+13,0,26))];wp[y,x,3]=255 if abs(x-cx)<11.5 else int(255*(13-abs(x-cx))/1.5)
assert np.array_equal(rf[skinhand],a[skinhand]);rfm=np.array(Image.open(j['semantic_mattes']['RIGHT-near-complete-forearm-grip-hand']['path']).convert('L'))>0;rfm|=skinhand;rfm[fist&metal]=False;rfm[shaftoutside]=False
rp=D/'original-actual-SE-complete-RIGHT-foregrip-including-all-original-fingers-v04.png';Image.fromarray(rf).save(rp);rmp=D/'original-actual-SE-complete-RIGHT-foregrip-all-fingers-semantic-matte-v04.png';Image.fromarray(rfm.astype('uint8')*255).save(rmp);wpp=D/'original-actual-SE-complete-rigid-RIGHT-pole-full-native-contour-without-fingers-v04.png';Image.fromarray(wp).save(wpp);wmp=D/'original-actual-SE-complete-native-RIGHT-pole-visible-source-erasure-matte-v04.png';Image.fromarray(wm.astype('uint8')*255).save(wmp)
j['parts']['RIGHT-near-complete-forearm-grip-hand']=pin(rp);j['semantic_mattes']['RIGHT-near-complete-forearm-grip-hand']=pin(rmp);j['parts']['complete-rigid-RIGHT-near-staff']=pin(wpp);j['semantic_mattes']['complete-rigid-RIGHT-near-staff']=pin(wmp)
erase=wm|rfm
for k in ['RIGHT-near-upper-arm','LEFT-far-upper-arm','LEFT-far-complete-curved-cuff-forearm-free-hand']:erase|=np.array(Image.open(j['semantic_mattes'][k]['path']).convert('L'))>0
core0=a.copy();core0[erase]=0
# Expanded actual cape-only derivative mask, needed because the strict6583
# occlusion cut the new continuous gold motif/hem. Body/othergear/boots excluded.
paint=np.array(Image.open(j['actual_local_cape_retouch']['local_native_paint']['path']).convert('RGBA'));m0=np.array(Image.open(j['actual_local_cape_retouch']['replacement_mask']['path']).convert('L'))>0;assert int(m0.sum())==6583
capePoly=poly([(474,725),(528,741),(509,871),(474,1007),(452,982),(420,951),(390,922),(360,899),(330,880),(300,870),(269,868),(314,828),(353,796),(394,766),(438,741)])
occ=(wm&capePoly)[750:1000,275:525]|m0
visible=(core0[750:1000,275:525,3]>0);cape=visible|occ;crop=a[750:1000,275:525].copy();d=distance_transform_edt(~occ);w=np.clip(1-d/46.,0,1);w=w*w*(3-2*w);yc,xc=np.indices((250,250))
gold0=(crop[:,:,0]>110)&(crop[:,:,0]>crop[:,:,2]*1.5)&(crop[:,:,1]>crop[:,:,2]*1.25);gold1=(paint[:,:,0]>110)&(paint[:,:,0]>paint[:,:,2]*1.5)&(paint[:,:,1]>paint[:,:,2]*1.25);seed=(gold0|gold1)&(d<77)&(yc<160)&(xc>90);dg=distance_transform_edt(~seed);gw=np.clip(1-dg/8.,0,1);gw=gw*gw*(3-2*gw);w=np.maximum(w,gw);w[~cape]=0;w[occ]=1
valid=paint[:,:,3]>128;_,ix=distance_transform_edt(~valid,return_indices=True);prgb=paint[:,:,:3].copy();prgb[~valid]=paint[ix[0][~valid],ix[1][~valid],:3];new=crop.copy();new[:,:,:3]=np.rint(crop[:,:,:3]*(1-w[:,:,None])+prgb*w[:,:,None]).astype('uint8');new[occ,3]=paint[occ,3];new[occ&(paint[:,:,3]==0)]=0;allow=(w>0)&cape;mask=np.zeros((H,W),bool);mask[750:1000,275:525]=allow;plate=a.copy();plate[750:1000,275:525]=new;core=core0.copy();core[mask]=plate[mask];assert not np.any(plate[~mask]!=a[~mask]);assert not np.any(core[~mask]!=core0[~mask]);assert np.array_equal(core[1070:1240],core0[1070:1240])
pp=D/'actual-original-SE-source-only-bounded-expanded-cape-paint-v04.png';Image.fromarray(plate).save(pp);cp=D/'actual-SE-full-old-arms-pole-erased-CORE-original-boots-and-continuous-cape-v04.png';Image.fromarray(core).save(cp);maskp=D/'actual-SE-expanded-actual-cape-fold-and-gold-boundary-allowed-mask-native-v04.png';Image.fromarray(mask.astype('uint8')*255).save(maskp);ep=D/'actual-SE-complete-old-arms-and-pole-source-erasure-mask-v04.png';Image.fromarray(erase.astype('uint8')*255).save(ep)
j['prior_material']=pin(P);j['fullCORE']=pin(cp);j['complete_old_erasure_mask']=pin(ep);j['actual_local_cape_retouch'].update({'source_masked_only_plate':pin(pp),'expanded_actual_cape_mask':pin(maskp),'replacement_pixels':int(mask.sum()),'original6583mask_preserved':True,'outside_replacement_source_RGBA_difference':0,'outside_replacement_CORE_RGBA_difference':0,'native_mask_expansion_basis':'Only actual cape visible bluefold/gold motif/hem plus true oldpole-occluded cape; sourcebody/othergear/boots unchanged. Original visible alpha retained outside native pole/cape occlusion.'});j['actual_hand_pole_material_ownership']={'original_source_skin_hand_in_foregrip_RGBA_diff':0,'native_skin_hand_original_pixels':int(skinhand.sum()),'wrong_generic_gold_predicate_corrected':True,'source_hand_rect':[348,441,417,497],'hand_pink_pixels_in_rigid_pole':False,'exposed_real_shaft_above_below_hand_owner':'complete-rigid-RIGHT-near-staff','source_pole_contour_native_original_trace':{'left':left,'right':right},'complete_lower_weapon_on_actual_transparent_native_background':[340,1000,451,1140],'source_modified':False};j['understaff_cape_status']='ACTUAL_NEW_CONTINUOUS_SE_CAPE_CANDIDATE_PENDING_INDEPENDENT_NATIVE_SOURCE_QC';q=D/'SE-ATTACK-own-complete-native-parts-correct-hand-pole-and-continuous-cape-provenance-v04.json';q.write_text(json.dumps(j,indent=2)+'\n');proof={'schema':'SE-native-actual-pole-hand-owner-and-expanded-cape-protection-proof-v1','prior_material':pin(P),'new_material':pin(q),'source_modified':False,'outside_cape_mask_source_RGBA_changes':0,'outside_cape_mask_CORE_RGBA_changes_after_semantic_oldweapon_arm_erasure':0,'original_visible_alpha_outside_pole_occlusion_changes':int((new[:,:,3][~occ]!=crop[:,:,3][~occ]).sum()),'actual_original_fingers_RGBA_changes':0,'boots_1070plus_RGBA_changes':0,'C_root_bodyunit_storage_OR_wholeactor_resampling_changes':False,'actual_local_service_count':1,'original6583_mask_pixels':6583,'expanded_cape_pixels':int(mask.sum()),'SOURCE_status':'PENDING_NATIVE_CAPE_HAND_POLE_AND_NEW_SIX_QC'};pr=D/'SE-actual-native-hand-pole-owner-and-local-cape-mask-protection-proof-v04.json';pr.write_text(json.dumps(proof,indent=2)+'\n');im=Image.fromarray(core[750:1000,275:525]);bg=Image.new('RGBA',im.size,(68,68,68,255));bg.alpha_composite(im);vp=D/'private-SE-native-complete-continuous-CORE-cape-v04.jpg';bg.convert('RGB').save(vp,quality=93);board=Image.new('RGB',(300,105),(68,68,68))
for i,ar in enumerate([a,rf,wp]):
 im=Image.fromarray(ar[420:525,340:440]);bg=Image.new('RGBA',im.size,(68,68,68,255));bg.alpha_composite(im);board.paste(bg.convert('RGB'),(100*i,0))
fp=D/'private-SE-original-fist-complete-foregrip-and-complete-pole-native-v04.jpg';board.save(fp,quality=94);print(json.dumps({'material':pin(q),'protection_proof':pin(pr),'cape_preview':pin(vp),'hand_preview':pin(fp),'expanded_cape_pixels':int(mask.sum())}))
