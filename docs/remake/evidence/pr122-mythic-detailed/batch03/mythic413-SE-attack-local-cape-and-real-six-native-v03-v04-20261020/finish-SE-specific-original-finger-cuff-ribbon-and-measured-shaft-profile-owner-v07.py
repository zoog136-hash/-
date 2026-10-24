from pathlib import Path
from PIL import Image
from scipy.ndimage import binary_dilation,label
import numpy as np,json,hashlib
B=Path(__file__).parent;D=B/'actual-own-SE-ATTACK-native-final-specific-material-owners-v07';D.mkdir(exist_ok=False);P=B/'actual-own-SE-ATTACK-native-local-cape-mask-metadata-repin-v06/SE-ATTACK-native-complete-parts-and-actual-cape-mask-coverage-corrected-metadata-v06.json';j=json.loads(P.read_text());a=np.array(Image.open(j['source']['path']).convert('RGBA'));H,W=a.shape[:2];yy,xx=np.indices((H,W));rf=np.array(Image.open(j['parts']['RIGHT-near-complete-forearm-grip-hand']['path']).convert('RGBA'));ru=np.array(Image.open(j['parts']['RIGHT-near-upper-arm']['path']).convert('RGBA'));wp=np.array(Image.open(j['parts']['complete-rigid-RIGHT-near-staff']['path']).convert('RGBA'));core=np.array(Image.open(j['fullCORE']['path']).convert('RGBA'));oldrf=rf.copy();oldru=ru.copy();oldwp=wp.copy();oldcore=core.copy();rfm=np.array(Image.open(j['semantic_mattes']['RIGHT-near-complete-forearm-grip-hand']['path']).convert('L'))>0;rum=np.array(Image.open(j['semantic_mattes']['RIGHT-near-upper-arm']['path']).convert('L'))>0;wm=np.array(Image.open(j['semantic_mattes']['complete-rigid-RIGHT-near-staff']['path']).convert('L'))>0;er=np.array(Image.open(j['complete_old_erasure_mask']['path']).convert('L'))>0;coef=j['staff_axis_once_from_original_visible_metal'];axis=coef[0]*yy+coef[1];rgb=a[:,:,:3].astype(float);band=abs(xx-axis)<15;metal=band&(((rgb[:,:,0]>70)&(rgb[:,:,1]>35)&(rgb[:,:,2]<rgb[:,:,1]*.54))|((rgb[:,:,0]>.95*rgb[:,:,1])&(rgb[:,:,0]<1.09*rgb[:,:,1])&(rgb[:,:,1]>85)&(rgb[:,:,2]<rgb[:,:,1]*.95)));fist=(xx>=348)&(xx<417)&(yy>=433)&(yy<497);skin=fist&~metal&(a[:,:,3]>0);newskin=skin&~rfm;rf[skin]=a[skin];rfm|=skin;core[skin]=0;wm[skin]=False;er|=skin
# Exactly the original isolated gold/leather forecuff rim, not wholearm recolor.
rim=(xx>=470)&(xx<485)&(yy>=515)&(yy<526)&(core[:,:,3]>0);rf[rim]=a[rim];rfm|=rim;core[rim]=0;er|=rim
# Independent native visual QA identified this exact brightblue triangular
# material as behind-arm hair-ribbon. It remains attached to head/CORE.
roi=(xx>=568)&(xx<588)&(yy>=488)&(yy<512);seed=roi&(rgb[:,:,2]>90)&(rgb[:,:,2]>rgb[:,:,1]*1.7)&(rgb[:,:,2]>rgb[:,:,0]*2.5)&(a[:,:,3]>0);hair=binary_dilation(seed,iterations=1)&roi&(a[:,:,3]>0);ru[hair]=0;rf[hair]=0;rum[hair]=False;rfm[hair]=False;wm[hair]=False;core[hair]=a[hair];er[hair]=False
# Rebuild only hidden-grip straight shaft from actual measured native RGBA
# profile, including its genuine alpha width. No opaque black RGB0 profile
# columns may be invented outside the original transparent-background shaft.
region=(yy>=425)&(yy<522)&(abs(xx-axis)<18);wp[region]=0;visible=region&wm&~skin;wp[visible]=a[visible];profile=[]
for u in range(-17,18):
 v=np.array([a[y,int(round(coef[0]*y+coef[1]))+u]for y in range(560,741)]);al=int(round(float(np.median(v[:,3]))));good=v[:,3]>16;col=np.median(v[good,:3],axis=0)if good.any()else np.zeros(3);profile.append([*np.rint(col).astype(int).tolist(),al])
for y in range(425,522):
 cx=float(coef[0]*y+coef[1])
 for x in range(int(cx-17),int(cx+18)):
  u=int(np.clip(round(x-cx)+17,0,34));p=np.array(profile[u],dtype='uint8')
  if p[3]>0 and (skin[y,x]or a[y,x,3]==0 or wp[y,x,3]<16):wp[y,x]=p
assert np.array_equal(rf[skin],a[skin]);assert np.array_equal(core[hair],a[hair]);assert not np.any(core[740:]!=oldcore[740:])
def pin(p):
 p=Path(p);return {'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
for name,ar,key in [('original-actual-SE-complete-RIGHT-foregrip-all-original-fingers-cuff-rim-v07',rf,'RIGHT-near-complete-forearm-grip-hand'),('original-actual-SE-RIGHTupper-excluding-actual-hair-ribbon-v07',ru,'RIGHT-near-upper-arm'),('original-actual-SE-complete-RIGHT-rigid-pole-original-native-alpha-profile-v07',wp,'complete-rigid-RIGHT-near-staff')]:
 p=D/(name+'.png');Image.fromarray(ar).save(p);j['parts'][key]=pin(p)
for name,m,key in [('RIGHTforegrip-all-fingers-cuff-rim-semantic-v07',rfm,'RIGHT-near-complete-forearm-grip-hand'),('RIGHTupper-excluding-hair-semantic-v07',rum,'RIGHT-near-upper-arm'),('complete-original-visible-RIGHTpole-source-erasure-v07',wm,'complete-rigid-RIGHT-near-staff')]:
 p=D/(name+'.png');Image.fromarray(m.astype('uint8')*255).save(p);j['semantic_mattes'][key]=pin(p)
cp=D/'actual-SE-complete-CORE-attached-original-hair-ribbon-and-PASS-cape-fixed-boots-v07.png';Image.fromarray(core).save(cp);j['fullCORE']=pin(cp);ep=D/'actual-SE-complete-old-arm-pole-erasure-preserving-original-hair-v07.png';Image.fromarray(er.astype('uint8')*255).save(ep);j['complete_old_erasure_mask']=pin(ep)
items={}
for name,m in [('top-finger-skin-restored-to-foregrip',newskin),('original-cuff-rim-moved-to-foregrip',rim),('original-behind-arm-hair-ribbon-moved-to-CORE',hair)]:
 p=D/(name+'-native-mask-v07.png');Image.fromarray(m.astype('uint8')*255).save(p);items[name]={'mask':pin(p),'native_nonzero_RGBA_pixels':int(m.sum())}
j['prior_material']=pin(P);j['final_specific_original_material_owner_fixes']={'items':items,'native_shaft_original_measured_RGBA_profile_offset_range':[-17,17],'native_shaft_original_measured_RGBA_profile':profile,'native_shaft_profile_y_range':[560,741],'actual_original_finger_RGBA_difference':0,'actual_original_hair_ribbon_RGBA_difference':0,'full_PASS_cape_native_y740plus_CORE_RGBA_difference':0,'actual_source_hips_legs_boots_modified':False,'all_bone_phase_controls_modified':False};j['understaff_cape_status']='INDEPENDENT_BOUNDED_NATIVE_CAPE_SOURCE_PASS_78aaa20_UNCHANGED';q=D/'SE-ATTACK-final-specific-original-material-owners-and-PASS-cape-provenance-v07.json';q.write_text(json.dumps(j,indent=2)+'\n');pr=D/'SE-actual-specific-finger-cuff-ribbon-shaft-owner-native-transfer-proof-v07.json';proof={'schema':'SE-specific-actual-material-native-owner-transfer-v1','prior_material':pin(P),'new_material':pin(q),'fixes':j['final_specific_original_material_owner_fixes'],'inverse_actual_source_trace':pin(B/'SE-actual-six-small-component-exact-native-part-and-body-inverse-source-trace-v01.json'),'actual_original_source_modified':False,'all_PHASES_root_C_unit_storage_OR_original_boots_modified':False,'SOURCE_status':'PENDING_FINAL_SIX_NATIVE_EXACT_OWNER_TRANSFER_AND_JOINT_QC'};pr.write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps({'material':pin(q),'proof':pin(pr),'new_top_finger_pixels':int(newskin.sum()),'actual_cuff_rim_pixels':int(rim.sum()),'actual_hair_ribbon_RGBA_pixels':int(hair.sum()),'PASS_cape_RGBA_diff':0}))
