from pathlib import Path
import json,hashlib,math
from PIL import Image,ImageDraw,ImageFilter
import numpy as np
D=Path(__file__).resolve().parent;Q=D/'flight2-actual-rig-v01';Q.mkdir();B=Path('/workspace/scratch/mythic413-NW-run-author-20261020-r001');src=D/'thunder_female-NW-run-contact0-v08-original-cloth-joint-occlusion.png';I=Image.open(src).convert('RGBA');M=Image.open(B/'thunder_female-NW-run-contact0-v01-service.png').convert('RGBA');SIZE=1536
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
cleanLshoe=Image.open(D/'clean-actual-stiletto-modules-v01/LEFT-actual-complete-stiletto-native.png').convert('RGBA');cleanRshoe=Image.open(D/'clean-actual-stiletto-modules-v01/RIGHT-actual-complete-stiletto-native.png').convert('RGBA');LM=Image.open(D/'clean-actual-stiletto-modules-v01/LEFT-semantic-whole-shoe-matte.png');RM=Image.open(D/'clean-actual-stiletto-modules-v01/RIGHT-semantic-whole-shoe-matte.png');body=I.copy();body.paste(M,(0,0),A);ba=np.asarray(body).copy();remove=(np.asarray(N)>0)|(np.asarray(F)>0)|(np.asarray(LM)>0)|(np.asarray(RM)>0);ba[remove,3]=0;body=Image.fromarray(ba)
cloth=Image.open(D/'contact0-original-pleat-cloth-posed-layer-v04.png').convert('RGBA');body.alpha_composite(cloth,(560,570));body.save(Q/'actual-body-layer-source-oldfeet-removed.png')
bob=np.array([-2.,-38.]);hipL=np.array([610.,692.])+bob;heel0=np.array([583.5,1191.]);delta=np.array([232.,5.]);heel1=heel0+delta;ankleL=np.array([796.,1080.])

def ik(a,b,l1,l2,left=True):
 d=b-a;length=np.linalg.norm(d);assert abs(l1-l2)<length<l1+l2;u=d/length;t=(l1*l1-l2*l2+length*length)/(2*length);v=math.sqrt(l1*l1-t*t);return a+u*t+np.array([-u[1],u[0]])*v*(1 if left else -1)
kneeL=ik(hipL,ankleL,245.,230.);hipR=np.array([705.,705.])+bob;ankleR=np.array([585.,882.]);kneeR=ik(hipR,ankleR,205.,200.)
# Width is native and unchanged; only the axial projection changes with rig articulation/foreshortening.
def warp(im,s0,s1,d0,d1):
 s0=np.array(s0,float);s1=np.array(s1,float);d0=np.array(d0,float);d1=np.array(d1,float);sv=s1-s0;dv=d1-d0;su=sv/np.linalg.norm(sv);du=dv/np.linalg.norm(dv);sp=np.array([-su[1],su[0]]);dp=np.array([-du[1],du[0]]);mat=np.outer(sv/np.linalg.norm(dv),du)+np.outer(sp,dp);off=s0-mat@d0;v=(*mat[0],off[0],*mat[1],off[1]);return im.transform((SIZE,SIZE),Image.Transform.AFFINE,v,Image.Resampling.BICUBIC)
def bounded(im,poly):return layer(im,mask(poly))
# Overlapping actual material around native hinges avoids a hard edge at the rig joint.
def spline(points):
 p=[np.array(x,float)for x in points];P=[2*p[0]-p[1],*p,2*p[-1]-p[-2]];ans=[]
 for k in [1,2]:
  for t in np.linspace(0,1,65,endpoint=(k==2)):
   a,b,c,d=P[k-1:k+3];q=.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t);ans.append(q)
 return np.array(ans)
def curved_material(im,sourcepoints,targetpoints,name):
 source=spline(sourcepoints);target=spline(targetpoints);x0,y0,x1,y1=350,650,950,1370;gy,gx=np.mgrid[y0:y1,x0:x1];best=np.full(gx.shape,np.inf);mx=np.zeros(gx.shape);my=np.zeros(gx.shape)
 for j in range(len(target)-1):
  a,b=target[j:j+2];v=b-a;l=float(v@v)
  if l<1e-8:continue
  u=np.clip(((gx-a[0])*v[0]+(gy-a[1])*v[1])/l,0,1);qx=a[0]+u*v[0];qy=a[1]+u*v[1];dx=gx-qx;dy=gy-qy;dist=dx*dx+dy*dy;hit=dist<best
  if not hit.any():continue
  vv=math.sqrt(l);normal=np.array([-v[1],v[0]])/vv;sd=source[j+1]-source[j];sn=np.array([-sd[1],sd[0]])/np.linalg.norm(sd);z=dx*normal[0]+dy*normal[1];sx=source[j,0]+u*sd[0]+z*sn[0];sy=source[j,1]+u*sd[1]+z*sn[1];best[hit]=dist[hit];mx[hit]=sx[hit];my[hit]=sy[hit]
 start=target[1]-target[0];start=start/np.linalg.norm(start);end=target[-1]-target[-2];end=end/np.linalg.norm(end);longstart=(gx-target[0,0])*start[0]+(gy-target[0,1])*start[1];longend=(gx-target[-1,0])*end[0]+(gy-target[-1,1])*end[1];domain=(longstart>=-8.)&(longend<=8.)
 # A finite anatomical bridge matches the rigid tarsal field locally, without reshaping the shoe.
 distance=np.sqrt((gx-target[-1,0])**2+(gy-target[-1,1])**2);bw=np.clip((65-distance)/55,0,1);bw=bw*bw*(3-2*bw);rx=source[-1,0]+gx-target[-1,0];ry=source[-1,1]+gy-target[-1,1];mx=(1-bw)*mx+bw*rx;my=(1-bw)*my+bw*ry
 data=np.asarray(im).astype(float);ix=np.clip(np.floor(mx).astype(int),0,1252);iy=np.clip(np.floor(my).astype(int),0,1252);fx=(mx-ix)[:,:,None];fy=(my-iy)[:,:,None];out=(1-fx)*(1-fy)*data[iy,ix]+fx*(1-fy)*data[iy,ix+1]+(1-fx)*fy*data[iy+1,ix]+fx*fy*data[iy+1,ix+1];out[(~domain)|(best>10000)|(mx<0)|(mx>1253)|(my<0)|(my>1253)]=0;canvas=Image.new('RGBA',(SIZE,SIZE));canvas.alpha_composite(Image.fromarray(np.rint(out).clip(0,255).astype('uint8')),(x0,y0));return canvas
cl=Image.new('L',(1254,1254));cl.paste(cloth.getchannel('A'),(560,570));viscloth=np.asarray(cl).astype(float)/255;viscloth[np.asarray(Image.open(D/'contact0-new-nearboot-cuff-protect-mask-v02.png'))>0]=0;viscloth[np.asarray(A)>0]=0
# Exact near thigh/shaft excludes the adjacent folded far-leg root (old broad removal matte stays fixed).
true_near_poly=[(519,710),(531,699),(543,692),(555,692),(569,696),(582,700),(596,710),(604,724),(601,735),(595,747),(588,763),(583,780),(576,797),(578,815),(585,835),(592,855),(597,880),(594,905),(589,928),(579,954),(578,977),(588,993),(606,1007),(627,1035),(641,1083),(642,1123),(630,1158),(605,1198),(586,1217),(551,1217),(520,1186),(493,1168),(476,1140),(477,1108),(489,1068),(499,1020),(507,967),(510,916),(507,860),(499,802),(495,760),(500,737)]
true_near=mask(true_near_poly);true_near.save(Q/'source-true-near-thigh-shaft-material-matte.png')
nearupper=nearimg.copy();na=np.asarray(nearupper.getchannel('A')).astype(float);na*=(np.asarray(true_near).astype(float)/255)*(1-np.asarray(LM).astype(float)/255)*(1-viscloth);nearupper.putalpha(Image.fromarray(np.rint(na).astype('uint8')))

farupper=farimg.copy();fa=np.asarray(farupper.getchannel('A')).astype(float);fa*=(1-np.asarray(RM).astype(float)/255)*(1-viscloth);farupper.putalpha(Image.fromarray(np.rint(fa).astype('uint8')))
out=Image.new('RGBA',(SIZE,SIZE));out.alpha_composite(curved_material(farupper,[(705,705),(642,785),(750,858)],[hipR,kneeR,ankleR],'Rleg'))
rfoot=cleanRshoe;out.alpha_composite(warp(rfoot,(750,858),(793,910),ankleR,ankleR+np.array([43,52])))
out.alpha_composite(curved_material(nearupper,[(610,692),(566,900),(564,1075)],[hipL,kneeL,ankleL],'Lleg'))
# Genuine exposed ankle leather joint, sampled from this actor's unoccluded original black shaft.
# It is behind the unchanged rigid complete shoe/counter, not a pixel-colour fill.
bridgepoly=[(692,1137),(702,1143),(711,1149),(721,1150),(732,1147),(741,1144),(746,1149),(745,1163),(738,1181),(730,1200),(718,1211),(703,1208),(692,1193),(685,1174),(686,1154)]
bridge_shift=ankleL-np.array([703.1928985028028,1200.2736086525224]);bridgepoly=[tuple(np.array(q)+bridge_shift)for q in bridgepoly]
bridge_mask=Image.new('L',(SIZE*3,SIZE*3));ImageDraw.Draw(bridge_mask).polygon([(x*3,y*3)for x,y in bridgepoly],fill=255);bridge_mask=bridge_mask.resize((SIZE,SIZE),Image.Resampling.LANCZOS)
# This finite UV map draws actual source leather [546..583,1043..1098] with a natural bent joint projection.
bridge=I.transform((SIZE,SIZE),Image.Transform.AFFINE,(.58,0,566-.58*(718+bridge_shift[0]),0,.62,1070-.62*(1175+bridge_shift[1])),Image.Resampling.BICUBIC);bridge.putalpha(Image.fromarray(np.rint(np.asarray(bridge.getchannel('A')).astype(float)*np.asarray(bridge_mask)/255).astype('uint8')));bridge.save(Q/'actual-original-leather-tarsal-joint-posed-layer.png');bridge_mask.save(Q/'actual-leather-joint-target-semantic-matte.png');out.alpha_composite(bridge)
lfoot=cleanLshoe;out.alpha_composite(warp(lfoot,(564,1075),(583.5,1191),ankleL,heel1))

transforms=[dict(part='Lwhole_trailing_flight_thigh_shin',method='continuous nativewidth curved actual-material skeletal skinning',source_knots=[[610,692],[566,900],[564,1075]],target_knots=[hipL.tolist(),kneeL.tolist(),ankleL.tolist()]),dict(part='Rwhole_driving_flight_thigh_shin',method='continuous nativewidth curved actual-material skeletal skinning',source_knots=[[705,705],[642,785],[750,858]],target_knots=[hipR.tolist(),kneeR.tolist(),ankleR.tolist()]),dict(part='Lactual_airborne_heel_and_stiletto',method='EXACT rigid translation, no foot geometry scaling',translation=delta.tolist()),dict(part='Ractual_foot',method='rigid native boot placement',translation=(ankleR-np.array([750.,858.])).tolist())]
b=Image.new('RGBA',(SIZE,SIZE));b.alpha_composite(body,tuple(map(int,bob)));out.alpha_composite(b)
angle=math.radians(30);s0=np.array([559.,383.]);sv=np.array([609.,541.])-s0;rot=np.array([[math.cos(angle),-math.sin(angle)],[math.sin(angle),math.cos(angle)]]);d0=s0+bob;d1=d0+rot@sv;out.alpha_composite(warp(armimg,s0,s0+sv,d0,d1));transforms.append(dict(part='Larm_true_shoulder_rotation',angle_degrees=30,source_shoulder=s0.tolist(),target_shoulder=d0.tolist()))
p=Q/'thunder_female-NW-run-flight2-actual-rig-v01.png';out.save(p);alpha=out.getchannel('A');bbox=alpha.point(lambda v:255 if v>16 else 0).getbbox();proof=dict(status='ACTUAL_FLIGHT2_POSE_RENDERED_PENDING_INDEPENDENT_ART_AND_AIR_QC',source=dict(path=str(src),sha256=h(src)),output=dict(path=str(p),sha256=h(p),bytes=p.stat().st_size,canvas=[SIZE,SIZE],alpha16_bbox=bbox),rig_common_root_in_unpadded_frame=[669.,1267.95],storage_translation=[0,0],native_C=2560,source_body_density_factor=2.5,whole_source_resampled=False,actual_art_part_projection=True,body_node_bob_and_lean=bob.tolist(),source_heel0_marker=heel0.tolist(),target_flight2_near_heel_marker=heel1.tolist(),exact_plant_source_delta=None,flight_both_feet_authored_air_pending_rig_QC=True,same_heel_part_rigid_translation=delta.tolist(),genuine_new_trailing_knee=kneeL.tolist(),genuine_far_driving_knee=kneeR.tolist(),parts=transforms,uv_endpoint_policy='outside first/last longitudinal domain transparent except explicit8native actualjointoverlap; no100px endpointrowextrusion',tarsal_bridge='65native local continuous inversefield converges to same rigidshoe UV; no shoegeometry change',actual_skirt_occluder_removed_from_leg_material=True,near_shaft_semantic_matte='true anatomical near contour excludes adjacent far thigh; broad body removal unchanged',actual_tarsal_leather_surface='finite original own black shaft material UV surface behind complete rigid shoe, target polygon and layer retained',original_profile_preserved=True,feet_true_tarsal_annotation_uncertainty_xy=[8,8],foot_sampling='BICUBIC subpixel rigid affine; no geometric resize/rotation; not bit-copy after fractional placement',clean_shoe_material_sources='untouchedsource0 actualRGBA+exactsemanticwholeheelcountermattes, no coatcolourfilter',source_approved=False,cycle_approved=False,actor_approvals_added=0)
(Q/'flight2-actual-rig-placement-and-source-provenance-v01.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps({'output':str(p),'sha256':h(p),'bytes':p.stat().st_size,'bbox':bbox,'kneeL':kneeL.tolist(),'heel1':heel1.tolist()}))
