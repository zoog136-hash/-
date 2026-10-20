"""Actual actor-specific terminal gait: new joints, toeoff, body bob and coat lag."""
from pathlib import Path
import numpy as np,math,json,hashlib
from PIL import Image,ImageDraw,ImageChops,ImageFilter
from scipy.ndimage import map_coordinates,label

P=Path(__file__).parent;O=Path('/workspace/scratch/mythic413-NW-walk-terminal2-author-20261020-v02');O.mkdir(exist_ok=False)
S=P/'thunder_female-NW-walk-LOAD1-rigged-retouched-v04.png';assert hashlib.sha256(S.read_bytes()).hexdigest()=='396c0803145a31990f7caeff6a889aac8d41966c2efe27e3362734268670b886'
im=Image.open(S).convert('RGBA');W,H=im.size
def poly(q):
 m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(q,fill=255);return m
def part(q):
 a=im.copy();m=poly(q).filter(ImageFilter.GaussianBlur(.65));a.putalpha(ImageChops.multiply(a.getchannel('A'),m));aa=np.array(a);cc,n=label(aa[:,:,3]>8);sizes=np.bincount(cc.ravel());sizes[0]=0;keep=cc==np.argmax(sizes);aa[:,:,3][~keep]=0;return Image.fromarray(aa)
def affine(a,A,t):
 inv=np.linalg.inv(A);b=-inv@t;return a.transform((W,H),Image.Transform.AFFINE,(inv[0,0],inv[0,1],b[0],inv[1,0],inv[1,1],b[1]),Image.Resampling.BICUBIC)
def joint(a,b,c,d):
 a,b,c,d=map(np.asarray,(a,b,c,d));v=b-a;z=d-c;u=v/np.linalg.norm(v);U=z/np.linalg.norm(z);oldbasis=np.column_stack([u,[-u[1],u[0]]]);newbasis=np.column_stack([U*np.linalg.norm(z)/np.linalg.norm(v),[-U[1],U[0]]]);A=newbasis@oldbasis.T;return A,c-A@a
Lhip=(590.,728.);Lknee=(579.,850.);Lankle=(631.,972.)
Rhip=(670.,731.);Rknee=(652.,844.);Rankle=(721.,960.)
toe1=np.array([595.,1017.5]);toe2=toe1+np.array([111.35431880224218,100.21888692201796])
fx=-.5399492471560389;fy=.841697576624542;e=math.radians(35.264389682754654)
def basis(t):return np.array([[fx*math.cos(t),-fx*math.sin(t)],[-(fy*math.sin(e)*math.cos(t)+math.cos(e)*math.sin(t)),fy*math.sin(e)*math.sin(t)-math.cos(e)*math.cos(t)]])
BT=basis(math.radians(-23.))@np.linalg.inv(basis(0.));Bt=toe2-BT@toe1
NLA=BT@np.asarray(Lankle)+Bt;NLK=np.array([659.,906.]);NLH=np.asarray(Lhip)+[0.,-6.]
Rheel1=np.array([762.,1060.]);Rheel2=np.array([705.77,980.25]);Rshift=Rheel2-Rheel1
NRA=np.asarray(Rankle)+Rshift;NRK=np.array([625.,806.]);NRH=np.asarray(Rhip)+[0.,-6.]
legs=[('R_thigh',[(638,713),(713,713),(710,786),(682,853),(634,875),(611,830)],Rhip,Rknee,NRH,NRK),('R_shin',[(626,825),(675,820),(723,924),(746,957),(720,991),(687,964),(654,916)],Rknee,Rankle,NRK,NRA),('L_thigh',[(540,713),(638,713),(627,813),(615,863),(552,882),(528,800)],Lhip,Lknee,NLH,NLK),('L_shin',[(550,838),(612,834),(649,923),(656,977),(600,990),(568,937)],Lknee,Lankle,NLK,NLA)]
LF=[(600,944),(653,938),(680,967),(686,1009),(671,1037),(636,1051),(610,1055),(584,1041),(575,1017),(577,987),(594,966)]
RF=[(706,939),(751,945),(766,980),(779,1039),(774,1068),(744,1079),(708,1069),(680,1053),(669,1012),(682,978)]
old=Image.new('L',(W,H))
for _,q,*_ in legs:old=ImageChops.lighter(old,poly(q))
old=ImageChops.lighter(old,ImageChops.lighter(poly(LF),poly(RF))).filter(ImageFilter.MaxFilter(19));ImageDraw.Draw(old).rectangle((0,0,W-1,711),fill=0)
staff=Image.open(P/'actual-LOAD1-rig-original-protection-v03.png').convert('L');old=ImageChops.subtract(old,staff)
body=im.copy();body.paste((0,0,0,0),(0,0),old)
# Six native pixels actual rising torso/hips, with mild blue coat follow-through.
# This is rigged upperbody relative to world root; stance is independently pinned.
y,x=np.indices((H,W),dtype=float);coat=np.clip((x-725.)/200.,0.,1.)*np.clip((y-660.)/250.,0.,1.)
dx=3.*coat;dy=-6.+2.*coat
# Far gripping hand remains at its original fixed staff, upper arm subtly deforms.
grip=np.exp(-((x-820.)**2+(y-445.)**2)/(2*50.**2));dy*=1-grip
coords=np.array([y-dy,x-dx]);ba=np.asarray(body).astype(float)/255.;alpha=ba[:,:,3];pa=ba[:,:,:3]*alpha[:,:,None];wa=map_coordinates(alpha,coords,order=1,mode='constant',cval=0.);rgb=np.stack([map_coordinates(pa[:,:,i],coords,order=1,mode='constant',cval=0.) for i in range(3)],2);rgb=np.divide(rgb,wa[:,:,None],out=np.zeros_like(rgb),where=wa[:,:,None]>1e-7);body=Image.fromarray(np.uint8(np.clip(np.dstack([rgb,wa])*255+.5,0,255)),'RGBA')
layer=Image.new('RGBA',(W,H));ops=[]
for name,q,a,b,c,d in legs:
 A,t=joint(a,b,c,d);layer.alpha_composite(affine(part(q),A,t));ops.append({'part':name,'source_joint_pair':[a,b],'target_joint_pair':[np.asarray(c).tolist(),np.asarray(d).tolist()]})
layer.alpha_composite(affine(part(RF),np.eye(2),Rshift));layer.alpha_composite(affine(part(LF),BT,Bt));body.alpha_composite(layer)
# Complete original weapon is a rigid independent bone; no warped shaft.
fullstaff=poly([(886,7),(940,105),(900,144),(885,216),(864,260),(842,459),(815,620),(790,765),(783,815),(784,866),(758,944),(731,938),(726,886),(738,823),(753,762),(781,611),(804,454),(827,265),(839,194),(825,162),(845,115),(861,65)])
sl=im.copy();sl.putalpha(ImageChops.multiply(sl.getchannel('A'),fullstaff));body.alpha_composite(sl)
# Natural opposite-phase LEFT forwardarm from original actual dc5 source, body bob6.
armorig=Image.open('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/thunder_female-NW-walk-contact0-v01-service.png').convert('RGBA');armmask=Image.open('/workspace/scratch/mythic413-NW-walk-contact0-author-20261020-v01/left-backswing-native-edit-v02/allowed-actual-LEFT-backarm-mask-v02.png').convert('L');ash=Image.new('RGBA',(W,H));ash.paste(armorig,(0,-6));msh=Image.new('L',(W,H));msh.paste(armmask,(0,-6));body=Image.composite(ash,body,msh)
out=O/'thunder_female-NW-walk-terminal2-actual-rig-v02.png';body.save(out);layer.save(O/'terminal2-actual-new-leg-layer-v01.png');old.save(O/'terminal2-old-leg-erasure-mask-v01.png');fullstaff.save(O/'terminal2-original-rigid-staff-mask-v01.png')
proof={'status':'ACTUAL_UNIQUE_TERMINAL2_CANDIDATE_PENDING_INDEPENDENT_QC','source':str(S),'source_sha256':hashlib.sha256(S.read_bytes()).hexdigest(),'output':str(out),'output_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'fixed_C':2048,'body_factor':2,'raw_canvas':[1254,1254],'body_root':'COMMON_RIG_ROOT_UNCHANGED_FROM_SOURCE0; actual torso rising6px, no wholeimage/root translation','near_LEFT_support':'Terminal support/toeoff, complete shoe rotates23deg around actual sole pivot, heel rises','LEFT_forefoot1':toe1.tolist(),'LEFT_forefoot2':toe2.tolist(),'plant_delta':[111.35431880224218,100.21888692201796],'LEFT_heel2_estimate':(BT@np.array([625.3543188022422,1044.2188869220179])+Bt).tolist(),'LEFT_ankle2_estimate':NLA.tolist(),'far_RIGHT':'Advancing recovering swing, full rigid shoe translation only, knee flexes','RIGHT_heel2_estimate':Rheel2.tolist(),'limbs':ops,'secondary_motion':'Torso rises6nativepx, hips6; coat lag+3x/+2y relativetorso; fararm grip pinned to fixedstaff','current_quality_scope':'Actual twoleg rig with transverse width preserved under longitudinal foreshortening; natural original LEFTforward arm for opposite leg phase; actual fullsource/plant QC pending','approval_added':0}
(O/'terminal2-actual-rig-provenance-v02.json').write_text(json.dumps(proof,indent=2)+'\n')
for n,img in [('terminal2-actual-v02-whole-private.jpg',body),('terminal2-actual-v02-legs-private.jpg',body.crop((460,650,900,1240)))]:
 bg=Image.new('RGB',img.size,(80,80,80));bg.paste(img,mask=img.getchannel('A'));bg.thumbnail((750,750));bg.save(O/n,quality=85,optimize=True);assert(O/n).stat().st_size<150000
print(json.dumps({'output_sha256':proof['output_sha256'],'toe2':toe2.tolist(),'heel2':proof['LEFT_heel2_estimate'],'ankle2':NLA.tolist()}))
