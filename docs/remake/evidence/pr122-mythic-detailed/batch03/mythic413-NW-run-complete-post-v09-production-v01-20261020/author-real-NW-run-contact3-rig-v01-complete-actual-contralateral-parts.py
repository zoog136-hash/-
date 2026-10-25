from pathlib import Path
import json,hashlib,math
from PIL import Image,ImageDraw,ImageFilter
import numpy as np
D=Path(__file__).resolve().parent;Q=D/'contact3-actual-rig-v01';Q.mkdir();B=Path('/workspace/scratch/mythic413-NW-run-author-20261020-r001');src=D/'thunder_female-NW-run-contact0-v08-original-cloth-joint-occlusion.png';I=Image.open(src).convert('RGBA');M=Image.open(B/'thunder_female-NW-run-contact0-v01-service.png').convert('RGBA');SIZE=1536;STORAGE=np.array([128.,128.])
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
cloth=Image.open(D/'contact0-original-pleat-cloth-posed-layer-v04.png').convert('RGBA');body.alpha_composite(cloth,(560,570))
# Exact independent-QC old near-boot residual: body source504/870, left of old removal matte.
oldedge=mask([(488,828),(514,828),(522,960),(505,970),(488,910)]);oldedge.save(Q/'source-old-nearleg-edge-remnant-semantic-removal-mask.png');before=np.asarray(body).copy();after=before.copy();after[:,:,3]=np.rint(after[:,:,3].astype(float)*(1-np.asarray(oldedge).astype(float)/255)).astype('uint8');body=Image.fromarray(after);outside=np.asarray(oldedge)==0;npixels=int(np.any(before!=after,axis=2).sum());assert not np.any(before[outside]!=after[outside]);(Q/'old-nearleg-residual-only-removal-proof.json').write_text(json.dumps(dict(changed_pixels=npixels,outside_semantic_mask_RGBA_changed=0,preserved_rgb_everywhere=bool(np.array_equal(before[:,:,:3],after[:,:,:3])),actual_old_nearleg_marker=[504,870],body_pose_and_new_leg_material_unchanged=True),indent=2)+'\n');body.save(Q/'actual-body-layer-source-oldfeet-removed.png')
bob=np.array([0.,0.]);hipL=np.array([610.,692.])+bob;heel0=np.array([583.5,1191.]);delta=np.array([234.5,7.]);heel1=np.array([818.,1198.]);ankleL=np.array([655.,845.])

def ik(a,b,l1,l2,left=True):
 d=b-a;length=np.linalg.norm(d);assert abs(l1-l2)<length<l1+l2;u=d/length;t=(l1*l1-l2*l2+length*length)/(2*length);v=math.sqrt(l1*l1-t*t);return a+u*t+np.array([-u[1],u[0]])*v*(1 if left else -1)
kneeL=np.array([547.,772.]);hipR=np.array([705.,705.])+bob;ankleR=np.array([659.,1088.]);kneeR=np.array([661.,913.])
# Width is native and unchanged; only the axial projection changes with rig articulation/foreshortening.
def warp(im,s0,s1,d0,d1):
 s0=np.array(s0,float);s1=np.array(s1,float);d0=np.array(d0,float)+STORAGE;d1=np.array(d1,float)+STORAGE;sv=s1-s0;dv=d1-d0;su=sv/np.linalg.norm(sv);du=dv/np.linalg.norm(dv);sp=np.array([-su[1],su[0]]);dp=np.array([-du[1],du[0]]);mat=np.outer(sv/np.linalg.norm(dv),du)+np.outer(sp,dp);off=s0-mat@d0;v=(*mat[0],off[0],*mat[1],off[1]);return im.transform((SIZE,SIZE),Image.Transform.AFFINE,v,Image.Resampling.BICUBIC)
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
def forward_actual_material(im,sourcepoints,targetpoints,name):
 # Forward actual-material mesh: continuous anatomical skin, no nearest-branch UV switch.
 sp=np.asarray(sourcepoints,float);tp=np.asarray(targetpoints,float)+STORAGE
 def bone_affine(a,b,c,d):
  su=(b-a)/np.linalg.norm(b-a);tu=(d-c)/np.linalg.norm(d-c);sn=np.array([-su[1],su[0]]);tn=np.array([-tu[1],tu[0]]);mat=np.outer((d-c)/np.linalg.norm(b-a),su)+np.outer(tn,sn);return mat,c-mat@a
 m0,o0=bone_affine(sp[0],sp[1],tp[0],tp[1]);m1,o1=bone_affine(sp[1],sp[2],tp[1],tp[2]);tangent=(sp[1]-sp[0])/np.linalg.norm(sp[1]-sp[0])+(sp[2]-sp[1])/np.linalg.norm(sp[2]-sp[1]);tangent/=np.linalg.norm(tangent)
 def posed(p):
  z=np.clip((float((p-sp[1])@tangent)+25)/50,0,1);w=z*z*(3-2*z);ans=(1-w)*(m0@p+o0)+w*(m1@p+o1)
  if name=='Lleg-original915-recovery':
   q=np.clip((75-np.linalg.norm(p-sp[-1]))/55,0,1);q=q*q*(3-2*q);ans=(1-q)*ans+q*(p-sp[-1]+tp[-1])
  return ans
 data=np.asarray(im).astype(float)/255;data[:,:,:3]*=data[:,:,3,None];alpha=data[:,:,3];yy,xx=np.where(alpha>0);x0,x1=int(xx.min())//10*10,int(xx.max())//10*10+20;y0,y1=int(yy.min())//10*10,int(yy.max())//10*10+20;acc=np.zeros((SIZE,SIZE,4),float)
 vertices=[];triangles=0
 for sy in range(y0,y1,10):
  for sx in range(x0,x1,10):
   if not alpha[max(0,sy):min(1254,sy+11),max(0,sx):min(1254,sx+11)].any():continue
   cell=np.array([[sx,sy],[sx+10,sy],[sx+10,sy+10],[sx,sy+10]],float);dst=np.array([posed(p)for p in cell]);vertices.append(dict(source=cell.tolist(),target=dst.tolist()))
   for ids in [(0,1,2),(0,2,3)]:
    S=cell[list(ids)];T=dst[list(ids)];A=np.column_stack((T[1]-T[0],T[2]-T[0]));det=np.linalg.det(A)
    if abs(det)<1e-7:continue
    bx0=max(0,int(np.floor(T[:,0].min())));bx1=min(SIZE,int(np.ceil(T[:,0].max()))+1);by0=max(0,int(np.floor(T[:,1].min())));by1=min(SIZE,int(np.ceil(T[:,1].max()))+1)
    if bx1<=bx0 or by1<=by0:continue
    gy,gx=np.mgrid[by0:by1,bx0:bx1];V=np.stack((gx-T[0,0],gy-T[0,1]),axis=-1);uv=V@np.linalg.inv(A).T;u=uv[:,:,0];v=uv[:,:,1];inside=(u>=-1e-7)&(v>=-1e-7)&(u+v<=1+1e-7)
    mx=S[0,0]+u*(S[1,0]-S[0,0])+v*(S[2,0]-S[0,0]);my=S[0,1]+u*(S[1,1]-S[0,1])+v*(S[2,1]-S[0,1]);ix=np.clip(np.floor(mx).astype(int),0,1252);iy=np.clip(np.floor(my).astype(int),0,1252);fx=(mx-ix)[:,:,None];fy=(my-iy)[:,:,None];val=(1-fx)*(1-fy)*data[iy,ix]+fx*(1-fy)*data[iy,ix+1]+(1-fx)*fy*data[iy+1,ix]+fx*fy*data[iy+1,ix+1];val[~inside]=0;dest=acc[by0:by1,bx0:bx1];dest[:]=val+dest*(1-val[:,:,3,None]);triangles+=1
 a=acc[:,:,3];rgb=np.divide(acc[:,:,:3],a[:,:,None],out=np.zeros_like(acc[:,:,:3]),where=a[:,:,None]>1e-8);rgba=np.dstack((rgb,a));ans=Image.fromarray(np.rint(rgba.clip(0,1)*255).astype('uint8'));ans.save(Q/(name+'-forward-actual-material-posed-layer.png'));(Q/(name+'-forward-mesh-contract.json')).write_text(json.dumps(dict(source_knots=sp.tolist(),target_knots_in_stored_canvas=tp.tolist(),storage_translation=STORAGE.tolist(),source_mesh_spacing_native=10,anatomical_knee_blend_halfwidth_native=25,triangles=triangles,mesh=vertices,method='continuous forward actual-material mesh, native transverse width, explicit bone projected articulation; premultiplied bilinear texture; no source endpoint extrusion'),indent=2)+'\n');return ans

originalLeg=Image.open(D/'original915-complete-near-leg-native-v01/actual-complete-original-upperthigh-and-boot-shaft-native.png').convert('RGBA');out=Image.new('RGBA',(SIZE,SIZE));out.alpha_composite(forward_actual_material(originalLeg,[(631,690),(653,865),(749,1068)],[hipR,kneeR,ankleR],'Rleg-original915-support'))
rfoot=cleanLshoe;out.alpha_composite(warp(rfoot,(564,1075),(583.5,1191),ankleR,np.array([678.5,1204.])))
originalLeg=Image.open(D/'original915-complete-near-leg-native-v01/actual-complete-original-upperthigh-and-boot-shaft-native.png').convert('RGBA');out.alpha_composite(forward_actual_material(originalLeg,[(631,690),(653,865),(749,1068)],[hipL,kneeL,ankleL],'Lleg-original915-recovery'))
out.alpha_composite(warp(cleanRshoe,(750,858),(791,906),ankleL,np.array([696.,893.])))
b=Image.new('RGBA',(SIZE,SIZE));b.alpha_composite(body,tuple(map(int,bob+STORAGE)));out.alpha_composite(b)
angle=math.radians(30);s0=np.array([559.,383.]);sv=np.array([609.,541.])-s0;rot=np.array([[math.cos(angle),-math.sin(angle)],[math.sin(angle),math.cos(angle)]]);d0=s0+bob;d1=d0+rot@sv;out.alpha_composite(warp(armimg,s0,s0+sv,d0,d1))
p=Q/'thunder_female-NW-run-contact3-actual-rig-v01.png';out.save(p);bbox=out.getchannel('A').point(lambda v:255 if v>16 else 0).getbbox();proof=dict(status='ACTUAL_OPPOSITE_RIGHT_CONTACT3_PENDING_INDEPENDENT_ART_AND_PHYSICAL_QC',output=dict(path=str(p),sha256=h(p),bytes=p.stat().st_size,canvas=[SIZE,SIZE],alpha16_bbox=bbox),source_body_sha256=h(src),original915_complete_leg_source_contract_sha256='177829492917fbe56696ae18a986c4c310c5e98b89de0caebbe3e3a24b1f5ceb',native_C=2560,density_factor=2.5,rig_common_root_in_unpadded_frame=[669.,1267.95],storage_translation=STORAGE.tolist(),body_node_bob_and_lean=bob.tolist(),actual_whole_actor_mirrored=False,actual_complete_own_boot_material_counterpart_rig=True,source_material_leg_bind=[[631,690],[653,865],[749,1068]],Lhip=hipL.tolist(),Lknee=kneeL.tolist(),Lankle=ankleL.tolist(),Rhip=hipR.tolist(),Rknee=kneeR.tolist(),Rankle=ankleR.tolist(),Rsupport_shoe=dict(source='actual same actor LEFT complete support shoe used as symmetric RIGHT counterpart',source_sha256=h(D/'clean-actual-stiletto-modules-v01/LEFT-actual-complete-stiletto-native.png'),source_tarsal=[564,1075],target_tarsal=ankleR.tolist(),source_structural_heel=[583.5,1191],target_structural_heel=[678.5,1204],source_structural_fore=[535,1164],target_structural_fore=[630,1177],translation=[95,13],geometric_scale=1,rotation_degrees=0),Lrecovery_shoe=dict(source='actual same actor RIGHT folded recovery shoe as symmetric LEFT counterpart',source_sha256=h(D/'clean-actual-stiletto-modules-v01/RIGHT-actual-complete-stiletto-native.png'),source_tarsal=[750,858],target_tarsal=ankleL.tolist(),translation=[-95,-13],geometric_scale=1,rotation_degrees=0,structural_heel_proposal=[696,893]),left_arm_rotation_degrees=30,foot_sampling='BICUBIC affine identity+translation; no geometric resize, not bit-copy after any fractional placement',old_near_leg_body_edge_remnant_removed=True,source_approved=False,physical_phase_approved=False,cycle_approved=False,actor_approvals_added=0);(Q/'contact3-actual-rig-placement-and-source-provenance-v01.json').write_text(json.dumps(proof,indent=2)+'\n');print(json.dumps(dict(output=str(p),sha256=h(p),bytes=p.stat().st_size,bbox=bbox)))
