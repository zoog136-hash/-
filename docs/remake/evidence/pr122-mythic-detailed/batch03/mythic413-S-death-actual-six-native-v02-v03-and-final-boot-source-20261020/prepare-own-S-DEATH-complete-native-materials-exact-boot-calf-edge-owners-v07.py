from pathlib import Path
import argparse,json,hashlib,numpy as np
from PIL import Image,ImageDraw
B=Path(__file__).parent;pa=argparse.ArgumentParser();pa.add_argument('--arm-manifest',required=True);pa.add_argument('--cape-pass',required=True);args=pa.parse_args();AMP=Path(args.arm_manifest);PASS=Path(args.cape_pass);am=json.loads(AMP.read_text());qa=json.loads(PASS.read_text());assert'PASS'in str(qa.get('status',''));D=B/'actual-own-S-DEATH-complete-native-materials-v07';D.mkdir();BP=B/'actual-own-S-DEATH-native-calf-full-true-source-AA-owners-v07/own-S-native-source-owned-complete-boot-only-calf-edges-and-head-input-v07.json';basic=json.loads(BP.read_text());REG=Path(basic['once_registration']['path']);reg=json.loads(REG.read_text());assert am['once_registration']['sha256']==basic['once_registration']['sha256'];raw=Image.open(basic['source']['path']).convert('RGBA');core=Image.open(am['fullCORE']['path']).convert('RGBA')
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def take(im,m):
 a=np.array(im);a[:,:,3]=np.minimum(a[:,:,3],np.array(m));a[a[:,:,3]==0,:3]=0;return Image.fromarray(a)
def remove(im,m):
 a=np.array(im);a[np.array(m)>0]=0;return Image.fromarray(a)
materials={};masks={};original_head_core=core.copy()
for side in ['R','L']:
 materials[side+'-complete-native-skin-thigh-shaft-counter-stiletto']=Image.open(basic['materials'][side+'-complete-native-leg']['path']).convert('RGBA');m=Image.open(basic['mattes'][side+'-complete-native-leg']['path']).convert('L');masks[side+'-complete-native-leg']=m;core=remove(core,m)
hm=Image.open(basic['mattes']['head-face-bun-and-both-blue-ribbons']['path']).convert('L');materials['head-face-bun-hair-complete-blue-ribbons']=take(original_head_core,hm);masks['complete-native-head-bow-goldcurls-and-two-blue-ribbons']=hm;core=remove(core,hm)
y,x=np.mgrid[:1254,:1254];prox=(x>=510)&(x<=755)&(y<=690);cm=Image.fromarray(((((y>=675)|((y>=575)&(x<560)))&~prox)*255).astype('uint8'));materials['complete-original-blue-gold-cape-and-both-coattails']=take(core,cm);masks['complete-native-cape']=cm
# Real source cloth overlaps its pelvis attachment through native675..681;
# this original visible material stays exact, rather than alpha edge butt joints.
pm=Image.fromarray((((y>=565)&(y<=681))*255).astype('uint8'));pelvis=take(core,pm);tm=Image.fromarray(((y<=579)*255).astype('uint8'));torso=take(core,tm);a=np.array(pelvis);ra=np.array(raw);overlap=np.zeros((1254,1254),bool)
for side,hip in [('R',650),('L',650)]:
 leg=np.array(materials[side+'-complete-native-skin-thigh-shaft-counter-stiletto'])
 for xx in range(1254):
  ys=np.where(leg[hip-15:hip+40,xx,3]>0)[0]
  if len(ys):
   start=hip-15+int(ys[0]);overlap[start:start+6,xx]|=leg[start:start+6,xx,3]>0
# Same original bare-neck skin is retained below the articulated head root.
neck=Image.new('L',(1254,1254));ImageDraw.Draw(neck).polygon([(619,311),(643,311),(640,322),(632,326),(623,319)],fill=255);ta=np.array(torso);nm=np.array(neck)>0;ta[nm]=ra[nm];materials['torso-original-blue-gold-bodice']=Image.fromarray(ta);a[overlap]=ra[overlap];materials['pelvis-white-pleated-miniskirt-original-waist-and-thigh-roots']=Image.fromarray(a);masks['actual-six-native-row-proximal-skin-overlap']=Image.fromarray((overlap*255).astype('uint8'));masks['actual-original-neck-skin-overlap']=neck
for name,r in am['parts'].items():materials[name]=Image.open(r['path']).convert('RGBA')
rfore=Image.new('RGBA',(1254,1254));rfore.alpha_composite(materials['complete-rigid-RIGHT-near-staff']);rfore.alpha_composite(materials['RIGHT-near-complete-forearm-grip-hand']);materials['RIGHT-actual-complete-forearm-grip-and-entire-pole-both-ends']=rfore
files={};maskfiles={}
for name,im in materials.items():p=D/(name+'.png');im.save(p);files[name]=pin(p)
for name,im in masks.items():p=D/(name+'-actual-semantic-matte.png');im.save(p);maskfiles[name]=pin(p)
o=D/'own-S-DEATH-complete-native-materials-and-QA-cape-source-handoff-v07.json';o.write_text(json.dumps(dict(status='ACTUAL_OWN_S_COMPLETE_NATIVE_INPUT_WITH_SHARED_CAPE_SOURCE_QA_PENDING_DEDICATED_DEATH_QC',source=basic['source'],once_registration=basic['once_registration'],canonical_sole_capture=basic['canonical_original_sole_capture'],source_cape_CORE=am['fullCORE'],source_cape_CORE_gate='SHARED_CAPE_SOURCE_PASS_DEDICATED_DEATH_PENDING',shared_cape_SOURCE_PASS=pin(PASS),arm_staff_input=pin(AMP),actual_prepared_head_boot_inputs=pin(BP),C=reg['new_S_fixed_C'],bodyunit=reg['new_S_fixed_bodyunit'],common_unpadded_root=reg['common_rig_root_in_unpadded_frame'],materials=files,mattes=maskfiles,native_canvas=[1254,1254],source_RGBA_recolored=False,wholeactor_mirror=False,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(manifest=pin(o),actual_native_materials=len(files))))
