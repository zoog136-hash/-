from pathlib import Path
import json,hashlib,numpy as np
from PIL import Image,ImageDraw
B=Path(__file__).parent;D=B/'actual-own-SE-DEATH-native-parts-v01';D.mkdir()
AMP=Path('/workspace/scratch/mythic413-SE-attack-author-20261020-v01/actual-own-SE-ATTACK-native-cape-original-visible-hem-join-v05r2/SE-ATTACK-own-complete-native-parts-and-original-visible-hem-cape-provenance-v05.json');am=json.loads(AMP.read_text());SP=Path(am['source']['path']);REG=Path(am['once_registration']['path']);CP=Path(am['fullCORE']['path']);SOLE=Path('/workspace/scratch/mythic413-SE-hit-author-20261020-v01/SE-original-neutral-once-true-sole-and-HIT-six-material-floor-binding-v01.json');reg=json.loads(REG.read_text());sole=json.loads(SOLE.read_text());assert reg['new_SE_fixed_C']==2816 and reg['new_SE_fixed_bodyunit']==2.75
for f in [am['source'],am['once_registration'],am['fullCORE']]:assert hashlib.sha256(Path(f['path']).read_bytes()).hexdigest()==f['sha256']
src=Image.open(SP).convert('RGBA');core=Image.open(CP).convert('RGBA')
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def poly(points):
 m=Image.new('L',src.size);ImageDraw.Draw(m).polygon(points,fill=255);return m
def take(im,m):
 a=np.array(im);a[:,:,3]=np.minimum(a[:,:,3],np.array(m));a[a[:,:,3]==0,:3]=0;return Image.fromarray(a)
def remove(im,m):
 a=np.array(im);a[np.array(m)>0]=0;return Image.fromarray(a)
legpolys={
'R':[(585,678),(617,686),(655,692),(680,684),(688,677),(687,711),(684,738),(673,770),(659,800),(644,830),(628,860),(608,900),(590,940),(578,980),(565,1020),(560,1040),(575,1070),(605,1140),(640,1229),(490,1229),(490,1040),(535,1040),(536,1000),(541,950),(550,900),(562,850),(574,800),(584,750),(585,704)],
'L':[(716,678),(744,683),(778,679),(807,668),(817,706),(831,750),(839,790),(847,835),(858,880),(872,930),(886,980),(899,1035),(925,1060),(990,1219),(820,1219),(820,1040),(839,1035),(827,1000),(815,960),(804,920),(790,880),(778,850),(760,800),(744,770),(731,742),(717,713)]}
materials={};masks={}
for side,model in zip(['R','L'],sole['source_material_capture_models']):
 m=poly(legpolys[side]);aa=np.maximum(np.array(m),np.array(Image.open(model['exact_source_alpha_support']['path']).convert('L')));m=Image.fromarray(aa.astype('uint8'));materials[side+'-complete-native-skin-thigh-shaft-counter-stiletto']=take(src,m);masks[side+'-complete-native-leg']=m;core=remove(core,m)
# The full native head includes the entire blue bow, both original ribbons
# and their real thin tips; they never remain stationary on the torso.
hm=poly([(490,70),(792,70),(792,282),(770,309),(748,321),(714,324),(686,316),(658,331),(632,350),(609,376),(581,398),(554,417),(526,438),(497,457),(467,477),(433,479),(422,449),(436,423),(464,399),(491,375),(517,347),(540,317),(553,286),(558,254),(557,223),(574,178),(594,134)])
ImageDraw.Draw(hm).rectangle((506,190,590,315),fill=255)
ImageDraw.Draw(hm).polygon([(580,270),(626,289),(643,329),(635,370),(625,413),(610,456),(587,496),(554,526),(517,537),(502,522),(524,488),(543,447),(556,400),(565,350)],fill=255)
materials['head-face-bun-hair-complete-blue-ribbons']=take(core,hm);masks['complete-native-head-and-both-ribbons']=hm;core=remove(core,hm)
y,x=np.mgrid[:1254,:1254];prox=(x>=574)&(x<=825)&(y<=704);cm=Image.fromarray(((((y>=694)|((y>=590)&(x<575)))&~prox)*255).astype('uint8'));materials['complete-original-blue-gold-cape-and-both-coattails']=take(core,cm);masks['complete-native-cape']=cm;core=remove(core,cm)
pm=Image.new('L',src.size);ImageDraw.Draw(pm).rectangle((0,575,1253,1253),fill=255);materials['pelvis-white-pleated-miniskirt-original-waist-and-thigh-roots']=take(core,pm);tm=Image.new('L',src.size);ImageDraw.Draw(tm).rectangle((0,0,1253,589),fill=255);materials['torso-original-blue-gold-bodice']=take(core,tm)
for name,f in am['parts'].items():
 p=Path(f['path']);assert hashlib.sha256(p.read_bytes()).hexdigest()==f['sha256'];materials[name]=Image.open(p).convert('RGBA')
q=Image.new('RGBA',src.size);q.alpha_composite(materials['complete-rigid-RIGHT-near-staff']);q.alpha_composite(materials['RIGHT-near-complete-forearm-grip-hand']);materials['RIGHT-actual-complete-forearm-grip-and-entire-pole-both-ends']=q
files={};maskpins={}
for name,im in materials.items():
 p=D/(name+'.png');im.save(p);files[name]=pin(p)
for name,im in masks.items():
 p=D/(name+'-actual-semantic-matte.png');im.save(p);maskpins[name]=pin(p)
o=D/'own-SE-DEATH-complete-native-materials-and-fixed-registration-handoff-v01.json';o.write_text(json.dumps(dict(status='ACTUAL_OWN_SE_NATIVE_DEATH_INPUT_PARTS_PENDING_NATIVE_SOURCE_QC_AND_SHARED_CAPE_FINAL_QC',source=pin(SP),source_cape_CORE=pin(CP),source_cape_CORE_gate=am['status'],once_registration=pin(REG),arm_staff_input=pin(AMP),canonical_sole_capture=pin(SOLE),C=reg['new_SE_fixed_C'],bodyunit=reg['new_SE_fixed_bodyunit'],common_unpadded_root=reg['common_rig_root_in_unpadded_frame'],native_canvas=[1254,1254],materials=files,mattes=maskpins,original_source_RGBA_recolored=False,wholeactor_mirror=False,original_assets_modified=False,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(manifest=pin(o),actual_native_parts=len(files),mattes=len(maskpins),shared_cape_gate='PENDING_OWNER_SOURCE_QC_NOT_FINAL')))
