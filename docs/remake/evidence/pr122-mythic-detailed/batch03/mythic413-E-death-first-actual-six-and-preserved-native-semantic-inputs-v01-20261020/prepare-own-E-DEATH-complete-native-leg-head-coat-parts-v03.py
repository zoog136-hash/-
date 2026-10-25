from pathlib import Path
import json,hashlib,numpy as np
from PIL import Image,ImageDraw
B=Path(__file__).parent;D=B/'actual-own-E-DEATH-native-parts-v03';D.mkdir()
SP=Path('/workspace/scratch/mythic413-E-hit-author-20261020-v01/E-new-high-quality-native-background-AA-clean-v01.png');CP=Path('/workspace/scratch/mythic413-E-attack-author-20261020-v01/actual-own-E-ATTACK-native-expanded-cape-seam-v06/actual-E-complete-old-arms-staff-erased-body-fixed-boots-and-continuous-cape-v06.png');REG=Path('/workspace/scratch/mythic413-E-hit-author-20261020-v01/E-new-native-one-time-body-density-C2816-root-registration-v01.json');AMP=Path('/workspace/scratch/mythic413-E-attack-author-20261020-v01/actual-own-E-ATTACK-native-complete-materials-v04/E-ATTACK-own-complete-native-parts-and-actual-local-cape-provenance-v04.json');SOLE=Path('/workspace/scratch/mythic413-E-hit-author-20261020-v01/E-original-neutral-once-true-sole-and-HIT-six-material-floor-binding-v01.json')
r=json.loads(REG.read_text());am=json.loads(AMP.read_text());sole=json.loads(SOLE.read_text());assert r['new_E_fixed_C']==2816 and r['new_E_fixed_bodyunit']==2.75
src=Image.open(SP).convert('RGBA');core=Image.open(CP).convert('RGBA')
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def poly(points):
 m=Image.new('L',src.size);ImageDraw.Draw(m).polygon(points,fill=255);return m
def take(im,m):
 a=np.array(im);a[:,:,3]=np.minimum(a[:,:,3],np.array(m));a[a[:,:,3]==0,:3]=0;return Image.fromarray(a)
def erase(im,m):
 a=np.array(im);a[np.array(m)>0]=0;return Image.fromarray(a)
legs={
'R':[(603,707),(627,713),(667,714),(692,710),(708,706),(707,709),(699,737),(688,763),(671,800),(650,845),(638,876),(625,912),(611,948),(592,992),(580,1026),(573,1048),(583,1073),(594,1109),(601,1147),(619,1180),(633,1196),(633,1211),(607,1221),(563,1224),(532,1217),(508,1204),(504,1168),(505,1121),(502,1094),(513,1070),(525,1048),(533,1021),(535,980),(535,941),(538,911),(546,886),(565,864),(580,843),(587,812),(590,780),(596,750),(597,719)],
'L':[(728,706),(757,704),(785,695),(812,688),(819,708),(836,747),(845,792),(854,839),(858,871),(872,916),(886,964),(902,1012),(909,1040),(924,1061),(930,1095),(941,1136),(958,1164),(980,1179),(991,1194),(988,1208),(952,1213),(909,1207),(878,1207),(860,1201),(850,1170),(846,1132),(840,1100),(837,1073),(830,1047),(817,1019),(808,990),(798,955),(790,918),(784,889),(782,865),(777,836),(767,805),(755,781),(741,765),(730,747),(724,720)]}
materials={};mattes={}
for side,points in legs.items():
 m=poly(points);im=take(src,m);materials[side+'-complete-native-skin-thigh-shaft-counter-stiletto']=im;mattes[side+'-complete-leg']=m;core=erase(core,m)
headmask=poly([(519,79),(765,79),(784,135),(814,207),(803,265),(789,301),(760,330),(740,348),(697,355),(662,349),(639,332),(614,344),(599,359),(575,385),(552,400),(518,416),(483,432),(445,451),(427,430),(434,407),(467,378),(497,348),(525,320),(551,288),(572,265),(568,229),(579,180),(596,143)])
# Both original blue ribbons belong to the head; all tips remain on the same
# native material and never stay behind on the torso during collapse.
ImageDraw.Draw(headmask).polygon([(584,247),(633,274),(651,312),(638,347),(617,382),(596,417),(563,451),(525,470),(483,479),(481,454),(507,429),(529,400),(543,370),(558,337),(569,302)],fill=255)
head=take(core,headmask);core=erase(core,headmask);materials['head-face-bun-hair-complete-blue-ribbons']=head;mattes['complete-head-ribbons']=headmask
# Separate only the original long coat behind the legs. White pleats, bare
# thigh roots and waist equipment remain together on the pelvis material.
y,x=np.mgrid[:1254,:1254];proxcap=(x>=590)&(x<=825)&(y<=730);cm=((y>=699)|((y>=615)&(x<606)))&~proxcap;cm=Image.fromarray((cm*255).astype('uint8'));coats=take(core,cm);core=erase(core,cm);materials['complete-original-blue-gold-cape-and-both-coattails']=coats;mattes['complete-original-coattails']=cm
pm=Image.new('L',src.size);ImageDraw.Draw(pm).rectangle((0,601,1253,1253),fill=255);materials['pelvis-white-pleated-miniskirt-original-waist-and-thigh-roots']=take(core,pm);tm=Image.new('L',src.size);ImageDraw.Draw(tm).rectangle((0,0,1253,615),fill=255);materials['torso-original-blue-gold-bodice']=take(core,tm)
for name,ref in am['parts'].items():
 p=Path(ref['path']);assert hashlib.sha256(p.read_bytes()).hexdigest()==ref['sha256'];materials[name]=Image.open(p).convert('RGBA')
# Whole original pole and actual RIGHT grip/forearm are a single rigid node.
q=Image.new('RGBA',src.size);q.alpha_composite(materials['complete-rigid-RIGHT-near-staff']);q.alpha_composite(materials['RIGHT-near-complete-forearm-grip-hand']);materials['RIGHT-actual-complete-forearm-grip-and-entire-pole-both-ends']=q
files={}
for name,im in materials.items():
 p=D/(name+'.png');im.save(p);files[name]=pin(p)
maskfiles={}
for name,m in mattes.items():
 p=D/(name+'-actual-semantic-matte.png');m.save(p);maskfiles[name]=pin(p)
cp=D/'own-E-DEATH-complete-native-materials-and-fixed-registration-handoff-v03.json';cp.write_text(json.dumps(dict(status='ACTUAL_NATIVE_E_DEATH_SEMANTIC_INPUT_PARTS_PENDING_SOURCE_POSE_QC_NOT_CLIP_APPROVAL',source=pin(SP),source_cape_CORE=pin(CP),once_registration=pin(REG),arm_staff_input=pin(AMP),canonical_sole_capture=pin(SOLE),C=r['new_E_fixed_C'],bodyunit=r['new_E_fixed_bodyunit'],common_unpadded_root=r['common_rig_root_in_unpadded_frame'],native_canvas=[1254,1254],source_RGBA_recolored=False,wholeactor_mirror=False,materials=files,mattes=maskfiles,original_assets_modified=False,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(manifest=pin(cp),actual_parts=len(files),mattes=len(maskfiles))))
