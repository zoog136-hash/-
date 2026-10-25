from pathlib import Path
import json,hashlib,math
from PIL import Image,ImageDraw,ImageFilter
import numpy as np
D=Path(__file__).resolve().parent;Q=D/'load1-actual-rig-v01';Q.mkdir();B=Path('/workspace/scratch/mythic413-NW-run-author-20261020-r001');src=D/'thunder_female-NW-run-contact0-v08-original-cloth-joint-occlusion.png';I=Image.open(src).convert('RGBA');M=Image.open(B/'thunder_female-NW-run-contact0-v01-service.png').convert('RGBA');SIZE=1536
h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();assert h(src)=='c4f6d79437f1f0d142a765af3b04e11c2413b0975c2fa32a87764a5e9aa6a482'
A=Image.open(D/'contact0-actual-new-arm-foreground-protect-mask-v01.png').convert('L')
near=[(504,681),(538,678),(575,680),(616,700),(634,748),(637,807),(629,867),(618,923),(617,977),(626,1032),(634,1083),(635,1123),(626,1152),(608,1176),(592,1209),(558,1214),(535,1191),(504,1173),(483,1152),(477,1123),(484,1088),(493,1053),(500,1010),(505,967),(510,916),(507,860),(499,802),(493,751)]
far=[(600,696),(639,697),(681,711),(714,741),(741,772),(768,797),(796,824),(819,854),(831,887),(833,927),(815,969),(791,999),(762,989),(744,950),(729,917),(707,894),(677,872),(650,848),(627,816),(612,776)]
coats=[[(585,549),(543,592),(510,632),(476,663),(442,695),(405,731),(365,763),(332,790),(318,812),(335,829),(359,826),(388,816),(410,836),(441,849),(465,824),(489,791),(514,758),(542,716),(567,674),(588,632),(604,592)],[(713,549),(753,568),(787,598),(821,638),(860,683),(900,730),(942,772),(982,807),(1014,844),(1030,874),(1006,893),(980,876),(947,886),(923,876),(899,848),(870,815),(845,781),(820,743),(792,701),(770,659),(747,620)]]
def mask(poly):
 im=Image.new('L',(1254*3,1254*3));ImageDraw.Draw(im).polygon([(x*3,y*3)for x,y in poly],fill=255);return im.resize((1254,1254),Image.Resampling.LANCZOS)
N=mask(near);F=mask(far);coatpoly=Image.new('L',(1254,1254));cd=ImageDraw.Draw(coatpoly)
for p in coats:cd.polygon(p,fill=255)
a=np.asarray(I);r=a[:,:,0].astype(float);g=a[:,:,1].astype(float);b=a[:,:,2].astype(float);blue=(b>1.22*r)&(b>1.1*g)&(b>35)&(np.asarray(coatpoly)>0);bd=np.asarray(Image.fromarray((blue*255).astype('uint8')).filter(ImageFilter.MaxFilter(13)))>0;gold=(r>1.15*b)&(g>1.2*b);coat=(np.asarray(coatpoly)>0)&(blue|(gold&bd));nm=np.asarray(N).copy();fm=np.asarray(F).copy();nm[coat]=0;fm[coat]=0;N=Image.fromarray(nm);F=Image.fromarray(fm)
for name,im in [('source-near-leg-mask.png',N),('source-far-leg-mask.png',F),('source-left-arm-mask.png',A),('source-coat-foreground-material-mask.png',Image.fromarray((coat*255).astype('uint8')))]:im.save(Q/name)
def layer(source,msk):
 z=source.copy();alpha=np.asarray(source.getchannel('A')).astype(float)*np.asarray(msk).astype(float)/255;z.putalpha(Image.fromarray(np.rint(alpha).astype('uint8')));return z
nearimg=layer(I,N);farimg=layer(I,F);armimg=layer(I,A)
body=I.copy();body.paste(M,(0,0),A);ba=np.asarray(body).copy();remove=(np.asarray(N)>0)|(np.asarray(F)>0);ba[remove,3]=0;body=Image.fromarray(ba)
cloth=Image.open(D/'contact0-original-pleat-cloth-posed-layer-v04.png').convert('RGBA');body.alpha_composite(cloth,(560,570))
bob=np.array([4.,70.]);hipL=np.array([610.,692.])+bob;heel0=np.array([583.5,1191.]);delta=np.array([139.19289850280273,125.27360865252246]);heel1=heel0+delta;ankleL=np.array([547.,1082.])+delta

def ik(a,b,l1,l2,left=True):
 d=b-a;length=np.linalg.norm(d);assert abs(l1-l2)<length<l1+l2;u=d/length;t=(l1*l1-l2*l2+length*length)/(2*length);v=math.sqrt(l1*l1-t*t);return a+u*t+np.array([-u[1],u[0]])*v*(1 if left else -1)
kneeL=ik(hipL,ankleL,245.,230.);hipR=np.array([705.,705.])+bob;ankleR=np.array([669.,1167.]);kneeR=ik(hipR,ankleR,205.,200.)
# Width is native and unchanged; only the axial projection changes with rig articulation/foreshortening.
def warp(im,s0,s1,d0,d1):
 s0=np.array(s0,float);s1=np.array(s1,float);d0=np.array(d0,float);d1=np.array(d1,float);sv=s1-s0;dv=d1-d0;su=sv/np.linalg.norm(sv);du=dv/np.linalg.norm(dv);sp=np.array([-su[1],su[0]]);dp=np.array([-du[1],du[0]]);mat=np.outer(sv/np.linalg.norm(dv),du)+np.outer(sp,dp);off=s0-mat@d0;v=(*mat[0],off[0],*mat[1],off[1]);return im.transform((SIZE,SIZE),Image.Transform.AFFINE,v,Image.Resampling.BICUBIC)
def bounded(im,poly):return layer(im,mask(poly))
# Overlapping actual material around native hinges avoids a hard edge at the rig joint.
parts=[('Rthigh',bounded(farimg,[(590,690),(720,690),(795,810),(790,845),(630,845),(590,780)]),(705,705),(720,813),hipR,kneeR),('Rshin',bounded(farimg,[(620,780),(790,780),(829,880),(725,898),(620,840)]),(720,813),(775,861),kneeR,ankleR),('Rfoot',bounded(farimg,[(735,828),(780,820),(815,850),(840,920),(815,995),(755,1005),(725,910)]),(775,861),(800,904),ankleR,ankleR+np.array([25,43])),('Lthigh',bounded(nearimg,[(480,670),(640,670),(660,925),(480,940)]),(610,692),(566,900),hipL,kneeL),('Lshin',bounded(nearimg,[(480,870),(640,870),(650,1035),(480,1045)]),(566,900),(547,1082),kneeL,ankleL),('Lfoot',bounded(nearimg,[(480,990),(640,990),(655,1218),(470,1218)]),(547,1082),(583.5,1191),ankleL,heel1)]
out=Image.new('RGBA',(SIZE,SIZE));transforms=[]
for name,im,s0,s1,d0,d1 in parts:
 out.alpha_composite(warp(im,s0,s1,d0,d1));transforms.append(dict(part=name,source_joint_a=list(s0),source_joint_b=list(s1),target_joint_a=list(map(float,d0)),target_joint_b=list(map(float,d1)),transverse_scale=1.0))
b=Image.new('RGBA',(SIZE,SIZE));b.alpha_composite(body,tuple(map(int,bob)));out.alpha_composite(b)
angle=math.radians(15);s0=np.array([559.,383.]);sv=np.array([609.,541.])-s0;rot=np.array([[math.cos(angle),-math.sin(angle)],[math.sin(angle),math.cos(angle)]]);d0=s0+bob;d1=d0+rot@sv;out.alpha_composite(warp(armimg,s0,s0+sv,d0,d1));transforms.append(dict(part='Larm_true_shoulder_rotation',angle_degrees=15,source_shoulder=s0.tolist(),target_shoulder=d0.tolist()))
p=Q/'thunder_female-NW-run-load1-actual-rig-v01.png';out.save(p);alpha=out.getchannel('A');bbox=alpha.point(lambda v:255 if v>16 else 0).getbbox();proof=dict(status='ACTUAL_LOAD1_POSE_RENDERED_PENDING_INDEPENDENT_ART_AND_PLANT_QC',source=dict(path=str(src),sha256=h(src)),output=dict(path=str(p),sha256=h(p),bytes=p.stat().st_size,canvas=[SIZE,SIZE],alpha16_bbox=bbox),rig_common_root_in_unpadded_frame=[669.,1267.95],storage_translation=[0,0],native_C=2560,source_body_density_factor=2.5,whole_source_resampled=False,actual_art_part_projection=True,body_node_bob_and_lean=bob.tolist(),source_heel0_marker=heel0.tolist(),target_heel1_marker=heel1.tolist(),exact_plant_source_delta=delta.tolist(),same_heel_part_rigid_translation=delta.tolist(),genuine_new_support_knee=kneeL.tolist(),genuine_far_passing_knee=kneeR.tolist(),parts=transforms,original_profile_preserved=True,source_approved=False,cycle_approved=False,actor_approvals_added=0)
(Q/'load1-actual-rig-placement-and-source-provenance-v01.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps({'output':str(p),'sha256':h(p),'bytes':p.stat().st_size,'bbox':bbox,'kneeL':kneeL.tolist(),'heel1':heel1.tolist()}))
