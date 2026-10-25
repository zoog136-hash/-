from pathlib import Path
import json, hashlib, math
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import map_coordinates, label, find_objects
from scipy.spatial.transform import Rotation

# New six-pose production. All original approved attack/death sources remain
# read only. This is a conditional fixed source-plane rig, not hidden anatomy.
B=Path(__file__).parent; D=B/'actual-own-E-RUN-six-native-v03'; D.mkdir()
PARTS=D/'actual-semantic-native-parts'; PARTS.mkdir()
N=2048; PAD=320; PX=10/9; BONE=245.0
MP=Path('/workspace/scratch/mythic413-E-death-author-20261020-v01/actual-own-E-DEATH-native-parts-v05/own-E-DEATH-complete-native-materials-and-fixed-registration-handoff-v05.json')
AM=Path('/workspace/scratch/mythic413-E-attack-author-20261020-v01/actual-own-E-ATTACK-native-complete-pole-shaft-ownership-v07/E-ATTACK-own-complete-native-materials-and-actual-shaft-owner-provenance-v07.json')
mat=json.loads(MP.read_text()); arms=json.loads(AM.read_text()); REG=Path(mat['once_registration']['path']); reg=json.loads(REG.read_text())
ROOT=np.array(reg['common_rig_root_in_unpadded_frame']); C=reg['new_E_fixed_C']; UNIT=reg['new_E_fixed_bodyunit']; assert C==2816 and UNIT==2.75
SOLE=Path(mat['canonical_sole_capture']['path']); sole=json.loads(SOLE.read_text()); Pr=np.array([[PX,0,0],[0,1,-1.]])
U=np.array([.9,.35,.35]); V=np.array([0.,0.,-1.]); UV=np.column_stack([U,V]); H0=np.array([(724-ROOT[0])/PX,225.,225.-(686-ROOT[1])])
profile=Path('/workspace/twilight/assets/actors/eight_direction/native_locomotion_staging/thunder_female_413/r035/NativeMotionProfile.tres')
controller=Path('/workspace/twilight/scripts/animation/actor_motion.gd')
PROFILE_SCALE=.237068965517; NS=PROFILE_SCALE*1024/C; STEP=210*.08/NS
SCREEN_FORWARD=np.array([1.,0.]); FW=np.array([1.,0.,0.]); PITCH_AXIS=np.array([0.,1.,0.])
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def blank():return Image.new('RGBA',(N,N))
def axis(a,d):return Rotation.from_rotvec(np.array(a)/np.linalg.norm(a)*math.radians(d)).as_matrix()
sources={}; original_refs={}
for name,r in mat['materials'].items():
 p=Path(r['path']);assert pin(p)['sha256']==r['sha256'];sources[name]=Image.open(p).convert('RGBA');original_refs[name]=r
for name,r in arms['parts'].items():
 p=Path(r['path']);assert pin(p)['sha256']==r['sha256'];sources[name]=Image.open(p).convert('RGBA');original_refs[name]=r
q=Image.new('RGBA',(1254,1254));q.alpha_composite(sources['complete-rigid-RIGHT-near-staff']);q.alpha_composite(sources['RIGHT-near-complete-forearm-grip-hand']);sources['RIGHT-actual-complete-forearm-grip-and-entire-pole-both-ends']=q

# RUN-only semantic ownership closure: the two original blue ribbon tips
# and adjacent original golden hair texels cannot remain on the moving torso.
hn='head-face-bun-hair-complete-blue-ribbons';tn='torso-original-blue-gold-bodice';h0=np.array(sources[hn]);t0=np.array(sources[tn]);yy,xx=np.mgrid[:1254,:1254];owner=(xx<546)&(yy<470)&(t0[:,:,3]>0);h1=h0.copy();t1=t0.copy();choose=owner&(t0[:,:,3]>h0[:,:,3]);h1[choose]=t0[choose];t1[owner]=0
before=h0.copy();take=t0[:,:,3]>before[:,:,3];before[take]=t0[take];after=h1.copy();take=t1[:,:,3]>after[:,:,3];after[take]=t1[take];assert np.array_equal(before,after)
sources[hn]=Image.fromarray(h1);sources[tn]=Image.fromarray(t1);op=PARTS/'RUN-only-exact-original-head-ribbon-tip-owner-transfer-mask.png';Image.fromarray((owner*255).astype('uint8')).save(op)
ownerproof=D/'E-RUN-original-ribbon-tip-RGBA-semantic-owner-transfer-v03.json';ownerproof.write_text(json.dumps(dict(status='EXACT_ORIGINAL_RGBA_HEAD_RIBBON_TIP_OWNER_TRANSFER_ONLY_FOR_NEW_RUN',source_manifest=pin(MP),head_source=original_refs[hn],torso_source=original_refs[tn],source_region=[0,0,546,470],actual_transfer_mask=pin(op),transferred_nonzero_alpha_texels=int(owner.sum()),union_RGBA_bitexact=True,source_RGBA_recolored=False,source_RGBA_deleted=False,old_asset_changed=False,registration_changed=False),indent=2)+'\n')

def band(im,y0,y1):
 a=np.array(im);a[:y0]=0;a[y1+1:]=0;return Image.fromarray(a)
controls={'R':dict(hip=[677,696],knee=[622,868],ankle=[551,1052]),'L':dict(hip=[770,694],knee=[830,875],ankle=[875,1050])}
legs={}; source_parts={}
for side,m in zip(['R','L'],sole['source_material_capture_models']):
 full=sources[side+'-complete-native-skin-thigh-shaft-counter-stiletto'];c=controls[side];ky=c['knee'][1];ay=c['ankle'][1]
 # Complete gold counter, toe and heel come from the full final own material.
 # The old neutral sole support material omits a few final rim alpha texels.
 parts=dict(thigh=band(full,0,ky-12),calf=band(full,ky+17,ay-12),knee=band(full,ky-19,ky+24),ankle=band(full,ay-24,ay+15),foot=band(full,ay+5,1253))
 for name,im in parts.items():
  p=PARTS/f'{side}-original-complete-{name}.png';im.save(p);source_parts[side+'-'+name]=pin(p)
 legs[side]=dict(parts=parts,capture=m)
for name in ['head-face-bun-hair-complete-blue-ribbons','complete-original-blue-gold-cape-and-both-coattails','pelvis-white-pleated-miniskirt-original-waist-and-thigh-roots','torso-original-blue-gold-bodice','RIGHT-near-upper-arm','LEFT-far-upper-arm','LEFT-far-complete-curved-cuff-forearm-free-hand','RIGHT-actual-complete-forearm-grip-and-entire-pole-both-ends']:
 p=PARTS/(name+'.png');sources[name].save(p);source_parts[name]=pin(p)
# Real original hair ribbon module. Its root shares original pixels with the
# head for four native rows; no generated bridge or color patch is added.
ha=np.array(sources['head-face-bun-hair-complete-blue-ribbons']);yy,xx=np.mgrid[:1254,:1254];ribbon=(yy>=311)&(xx<=641);ra=ha.copy();ra[~ribbon]=0;hc=ha.copy();hc[(yy>=315)&(xx<=641)]=0
for name,a in [('head-core',hc),('original-blue-ribbon-lag',ra)]:
 sources[name]=Image.fromarray(a);p=PARTS/(name+'.png');sources[name].save(p);source_parts[name]=pin(p)

def premult(im):
 a=np.array(im).astype(np.float32);a[:,:,:3]*=a[:,:,3:4]/255.;return a
def sample(a,x,y):
 s=np.stack([map_coordinates(a[:,:,k],[y,x],order=1,mode='constant',cval=0,prefilter=False)for k in range(4)],axis=-1)
 rgb=np.divide(s[:,:,:3]*255.,s[:,:,3:4],out=np.zeros_like(s[:,:,:3]),where=s[:,:,3:4]>1.e-7)
 out=np.concatenate([np.clip(rgb,0,255),np.clip(s[:,:,3:4],0,255)],axis=-1);out=np.floor(out+.5).astype('uint8');out[out[:,:,3]==0,:3]=0;return out
def floor_source(im,sa,A,M):
 a=np.array(im);y,x=np.where(a[:,:,3]>0);sa=np.array(sa);A=np.array(A);M=np.array(M);w=A+np.column_stack([x-sa[0],y-sa[1]])@M.T
 z=float(w[:,2].min()-.5*np.abs(M[2]).sum());return z
def plane(im,sa,A,M,name,ph):
 sa=np.array(sa,float);A=np.array(A,float);M=np.array(M,float);a=np.array(im);y,x=np.where(a[:,:,3]>0);corners=np.array([[x.min()-1,y.min()-1],[x.max()+1,y.min()-1],[x.min()-1,y.max()+1],[x.max()+1,y.max()+1]])
 scr=ROOT+(A+(corners-sa)@M.T)@Pr.T+PAD;lo=np.floor(scr.min(axis=0)-2).astype(int);hi=np.ceil(scr.max(axis=0)+2).astype(int);assert np.all(lo>=0)and np.all(hi<N),(name,lo,hi)
 gy,gx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1];iv=np.linalg.inv(Pr@M);uv=np.stack([gx-PAD-ROOT[0],gy-PAD-ROOT[1]],axis=-1);uv=(uv-A@Pr.T)@iv.T+sa;out=sample(premult(im),uv[:,:,0],uv[:,:,1]);wp=A+(uv-sa)@M.T;depth=wp[:,:,1]+wp[:,:,2];grad=M[2]@iv;zquad=wp[:,:,2]-.5*np.abs(grad).sum();mask=out[:,:,3]>0
 zsrc=floor_source(im,sa,A,M);zr=float(zquad[mask].min());q=dict(name=name,phase=ph,kind='ACTUAL_ORIGINAL_NATIVE_RGBA_FIXED_PLANE',source_anchor=sa.tolist(),world_anchor=A.tolist(),source_world_UV=M.tolist(),source_quad_min_Z=zsrc,raster_texel_quad_min_Z=zr,guard_native=1.,guard_basis='Exact original source texel quads and selected output texel quads are already bounded; one additional native unit reserved.',guarded_min_Z=min(zsrc,zr)-1.,source_RGBA_recolored=False,premultiplied_float4_RGBA_sampling=True)
 return node(out,lo,depth,zquad,q,name,ph)
def node(out,lo,depth,zquad,meta,name,ph):
 im=blank();im.paste(Image.fromarray(out),tuple(lo));p=D/f'phase{ph}-{name}-actual-native-node.png';im.save(p);npz=D/f'phase{ph}-{name}-actual-native-UV-raydepth.npz';np.savez_compressed(npz,lo=lo,camera_ray_depth=depth.astype('float32'),texel_quad_min_Z=zquad.astype('float32'),alpha_nonzero=(out[:,:,3]>0).astype('uint8'));meta.update(raster=pin(p),selected_depth_and_raster_floor=pin(npz),stored_bbox=[*map(int,lo),int(lo[0]+out.shape[1]),int(lo[1]+out.shape[0])]);return dict(im=im,rgba=out,lo=lo,depth=depth,meta=meta)
def strip(im,sa,A,M0,M1,blend,name,ph,step=3.):
 a=np.array(im);y,x=np.where(a[:,:,3]>0);sa=np.array(sa,float);A=np.array(A,float);b0,b1=blend
 def world(x,y):
  t=np.clip((y-b0)/(b1-b0),0,1);g=t*t*(3-2*t);uv=np.stack([x-sa[0],y-sa[1]],axis=-1);return A+np.einsum('ij,...j->...i',M0,uv)*(1-g[...,None])+np.einsum('ij,...j->...i',M1,uv)*g[...,None]
 xs=np.unique(np.r_[np.arange(max(0,x.min()-1),min(1253,x.max()+1),step),min(1253,x.max()+1)]);ys=np.unique(np.r_[np.arange(max(0,y.min()-1),min(1253,y.max()+1),step),min(1253,y.max()+1)]);gy,gx=np.meshgrid(ys,xs,indexing='ij');uv=np.stack([gx,gy],axis=-1);wp=world(gx,gy);sc=ROOT+wp@Pr.T+PAD;lo=np.floor(sc.min(axis=(0,1))-2).astype(int);hi=np.ceil(sc.max(axis=(0,1))+2).astype(int);assert np.all(lo>=0)and np.all(hi<N),(name,lo,hi)
 hh,ww=(hi-lo+1)[::-1];out=np.zeros((hh,ww,4),np.uint8);dep=np.full((hh,ww),-np.inf);zq=np.full((hh,ww),np.inf);pa=premult(im)
 for iy in range(len(ys)-1):
  for ix in range(len(xs)-1):
   if not np.any(a[max(0,int(ys[iy])-1):min(1254,int(ys[iy+1])+2),max(0,int(xs[ix])-1):min(1254,int(xs[ix+1])+2),3]):continue
   for ids in [[(iy,ix),(iy,ix+1),(iy+1,ix+1)],[(iy,ix),(iy+1,ix+1),(iy+1,ix)]]:
    q=np.array([sc[i,j]-lo for i,j in ids]);u=np.array([uv[i,j]for i,j in ids]);w=np.array([wp[i,j]for i,j in ids]);T=np.column_stack([q[1]-q[0],q[2]-q[0]])
    if abs(np.linalg.det(T))<1e-8:continue
    iv=np.linalg.inv(T);ll=np.maximum(0,np.floor(q.min(axis=0)-.5).astype(int));rr=np.minimum([ww-1,hh-1],np.ceil(q.max(axis=0)+.5).astype(int));py,px=np.mgrid[ll[1]:rr[1]+1,ll[0]:rr[0]+1];v=np.stack([px-q[0,0],py-q[0,1]],axis=-1)@iv.T;bc=np.concatenate([1-v.sum(axis=-1,keepdims=True),v],axis=-1);inside=np.min(bc,axis=-1)>=-1.e-6;tu=bc@u;worldp=bc@w;d=worldp[:,:,1]+worldp[:,:,2];c=sample(pa,tu[:,:,0],tu[:,:,1]);dst=out[ll[1]:rr[1]+1,ll[0]:rr[0]+1];dd=dep[ll[1]:rr[1]+1,ll[0]:rr[0]+1];zz=zq[ll[1]:rr[1]+1,ll[0]:rr[0]+1];choose=inside&(c[:,:,3]>0)&(d>=dd);grad=(w[1:,2]-w[0,2])@iv;dst[choose]=c[choose];dd[choose]=d[choose];zz[choose]=(worldp[:,:,2]-.5*np.abs(grad).sum())[choose]
 # Exact quartic minimum of the declared continuous source rectangle. This
 # covers all original alpha texel quads as well as the selected raster.
 ymin=float(y.min())-.5;ymax=float(y.max())+.5;zmin=math.inf
 for sx in [float(x.min())-.5,float(x.max())+.5]:
  yp=np.polynomial.Polynomial([b0,b1-b0]);gp=np.polynomial.Polynomial([0.,0.,3.,-2.]);base=A[2]+M0[2,0]*(sx-sa[0])+M0[2,1]*(yp-sa[1]);delta=(M1[2,0]-M0[2,0])*(sx-sa[0])+(M1[2,1]-M0[2,1])*(yp-sa[1]);poly=base+gp*delta;points=[ymin,ymax,b0,b1]+[b0+(b1-b0)*r.real for r in poly.deriv().roots()if abs(r.imag)<1e-8 and 0<=r.real<=1];points=[p for p in points if ymin<=p<=ymax];zmin=min(zmin,float(world(np.full(len(points),sx),np.array(points))[:,2].min()))
 mask=out[:,:,3]>0;zr=float(zq[mask].min());meta=dict(name=name,phase=ph,kind='ORIGINAL_NATIVE_CONTINUOUS_CUBIC_PARENT_TO_CHILD_UV_SURFACE',source_anchor=sa.tolist(),world_anchor=A.tolist(),from_world_UV=M0.tolist(),to_world_UV=M1.tolist(),blend_y=[b0,b1],whole_source_rectangle_quartic_min_Z=zmin,raster_texel_quad_min_Z=zr,guard_native=1.,guard_basis='Exact original source texel quads and selected output texel quads are already bounded; one additional native unit reserved.',guarded_min_Z=min(zmin,zr)-1.,source_RGBA_recolored=False,premultiplied_float4_RGBA_sampling=True,hidden_patch_or_large_cap=False)
 return node(out,lo,dep,zq,meta,name,ph)
def bone_basis(sa,sb,A,Z):
 sa=np.array(sa,float);sb=np.array(sb,float);sv=sb-sa;sl=np.linalg.norm(sv);sn=np.array([-sv[1],sv[0]])/sl;bv=Z-A;pv=Pr@bv;tn=np.array([-pv[1],pv[0]])/np.linalg.norm(pv);W=np.array([tn[0]/PX,tn[1]/2,-tn[1]/2]);return np.column_stack([bv*sv[0]/sl**2+W*sn[0],bv*sv[1]/sl**2+W*sn[1]])
def knee(H,A):
 d=A-H;ln=np.linalg.norm(d);assert 0<ln<2*BONE;v=d/ln;f=FW-np.dot(FW,v)*v;f/=np.linalg.norm(f);K=(H+A)/2+math.sqrt(BONE**2-ln**2/4)*f;assert abs(np.linalg.norm(K-H)-BONE)<1.e-7 and abs(np.linalg.norm(A-K)-BONE)<1.e-7;return K
def depth_group(nodes,name,ph):
 # Resolve the real projected source surfaces by the declared camera ray.
 lo=np.min([r['lo']for r in nodes],axis=0);hi=np.max([r['lo']+[r['rgba'].shape[1],r['rgba'].shape[0]]for r in nodes],axis=0);hh,ww=(hi-lo)[::-1];rgba=np.zeros((len(nodes),hh,ww,4),np.uint8);depth=np.full((len(nodes),hh,ww),-np.inf)
 for k,r in enumerate(nodes):
  x,y=r['lo']-lo;h,w=r['rgba'].shape[:2];rgba[k,y:y+h,x:x+w]=r['rgba'];depth[k,y:y+h,x:x+w]=np.where(r['rgba'][:,:,3]>0,r['depth'],-np.inf)
 order=np.argsort(depth,axis=0,kind='stable');out=np.zeros((hh,ww,4),np.float32);gy,gx=np.mgrid[:hh,:ww]
 for i in range(len(nodes)):
  a=rgba[order[i],gy,gx].astype(np.float32)/255.;alpha=a[:,:,3:4];out[:,:,:3]=a[:,:,:3]*alpha+out[:,:,:3]*(1-alpha);out[:,:,3:4]=alpha+out[:,:,3:4]*(1-alpha)
 rgb=np.divide(out[:,:,:3],out[:,:,3:4],out=np.zeros_like(out[:,:,:3]),where=out[:,:,3:4]>1.e-7);a=np.floor(np.clip(np.concatenate([rgb,out[:,:,3:4]],axis=-1),0,1)*255+.5).astype('uint8');im=blank();im.paste(Image.fromarray(a),tuple(lo));p=D/f'phase{ph}-{name}-exact-depth-composition.png';im.save(p);return im

# Dedicated E running keyframes. A side advances through these six states;
# the other side is three phases apart, so CONTACT3 truly changes support.
gait=[dict(name='CONTACT',stride=120.,height=0.,pitch=0.),dict(name='LOAD',stride=120.-STEP/PX,height=0.,pitch=0.),dict(name='FLIGHT-trailing',stride=-225.,height=160.,pitch=-14.),dict(name='RECOVERY-fold',stride=-220.,height=200.,pitch=-20.),dict(name='DRIVE-forward',stride=-35.,height=255.,pitch=-5.),dict(name='FLIGHT-reaching',stride=165.,height=130.,pitch=9.)]
states=[];rows=[];allrecords=[]
for ph in range(6):
 state=dict(phase=ph,name=['LEFT-CONTACT','LEFT-LOAD','FLIGHT-RIGHT-drive','RIGHT-CONTACT','RIGHT-LOAD','FLIGHT-LEFT-drive'][ph],pelvis_bob_Z=[0.,-60.,60.,0.,-60.,60.][ph],pelvis_pitch=[4.,5.,3.,4.,5.,3.][ph],torso_pitch=[10.,12.,8.,10.,12.,8.][ph],cloth_lag=[28.,32.,37.,36.,32.,27.][ph],hair_lag=[-3.,1.,4.,3.,-1.,-4.][ph]);states.append(state);H=H0+np.array([0,0,state['pelvis_bob_Z']]);Rp=axis(PITCH_AXIS,state['pelvis_pitch']);Rb=axis(PITCH_AXIS,state['torso_pitch']);pelM=Rp@UV;torM=Rb@UV;atpel=lambda p:H+pelM@(np.array(p)-[724,686]);waist=atpel([724,601]);attor=lambda p:waist+torM@(np.array(p)-[724,601]);nodes=[];bn={};legnodes=[]
 for side,offset,lane in [('L',0,60.),('R',3,110.)]:
  g=gait[(ph+offset)%6];c=controls[side];q=legs[side];m=q['capture'];fu=np.array(m['source_U']);fv=np.array(m['source_V']);fm0=np.column_stack([fu,fv]);fr=axis(PITCH_AXIS,g['pitch']);fm=fr@fm0;hs=np.array(m['observed_painted_heel_native']);capture_paint=np.array(m['source_plane_anchor_world']);capture_support=np.array(m['physical_heel_support_world']);null=capture_paint-capture_support
  physical=np.array([g['stride'],lane,g['height']]);heel=physical+fr@null;A=heel+fm@(np.array(c['ankle'])-hs);hip=atpel(c['hip']);K=knee(hip,A);MT=bone_basis(c['hip'],c['knee'],hip,K);MC=bone_basis(c['knee'],c['ankle'],K,A)
  ns=[strip(q['parts']['thigh'],c['hip'],hip,pelM,MT,[c['hip'][1]+6,c['hip'][1]+82],side+'-thigh-proximal',ph),plane(q['parts']['calf'],c['knee'],K,MC,side+'-calf',ph),strip(q['parts']['knee'],c['knee'],K,MT,MC,[c['knee'][1]-12,c['knee'][1]+18],side+'-continuous-knee',ph),strip(q['parts']['ankle'],c['ankle'],A,MC,fm,[c['ankle'][1]-16,c['ankle'][1]+8],side+'-continuous-ankle',ph),plane(q['parts']['foot'],hs,heel,fm,side+'-complete-foot-toe-heel',ph)];legnodes.extend(ns);nodes.extend(ns)
  toe0=np.array(m['physical_foreball_support_world'])-capture_support;toe=physical+fr@toe0;bn[side]=dict(gait_state=g,hip=hip.tolist(),knee=K.tolist(),ankle=A.tolist(),painted_heel_anchor=heel.tolist(),structural_heel_support=physical.tolist(),structural_foreball=toe.tolist(),foot_source_heel=hs.tolist(),source_controls=c,foot_SO3=fr.tolist(),foot_world_UV=fm.tolist(),thigh_world_UV=MT.tolist(),calf_world_UV=MC.tolist(),femur=float(np.linalg.norm(K-hip)),tibia=float(np.linalg.norm(A-K)),support=ph in ([0,1]if side=='L'else[3,4]),paired_or_whole_actor_mirror=False)
 coat=strip(sources['complete-original-blue-gold-cape-and-both-coattails'],[724,686],H,pelM,axis(PITCH_AXIS,state['cloth_lag'])@pelM,[680,850],'original-root-bound-cape-lag',ph,step=4.)
 pelvis=plane(sources['pelvis-white-pleated-miniskirt-original-waist-and-thigh-roots'],[724,686],H,pelM,'pelvis-white-pleats-gold-waist',ph);torso=plane(sources['torso-original-blue-gold-bodice'],[724,601],waist,torM,'original-black-gold-bodice',ph)
 neck=attor([685,315]);Rh=axis(PITCH_AXIS,-2.)@Rb;hm=Rh@UV;head=strip(sources['head-face-bun-hair-complete-blue-ribbons'],[685,315],neck,hm,axis(PITCH_AXIS,state['hair_lag'])@hm,[350,430],'original-complete-head-with-continuous-real-ribbon-lag',ph)
 armsnodes=[];arminfo={}
 for side,up,fore,S0,E0,phase_shift in [('L','LEFT-far-upper-arm','LEFT-far-complete-curved-cuff-forearm-free-hand',[795,471],[808,513],0),('R','RIGHT-near-upper-arm','RIGHT-actual-complete-forearm-grip-and-entire-pole-both-ends',[622,354],[550,471],3)]:
  a=[-10.,-4.,9.,10.,4.,-9.][(ph+phase_shift)%6];Ru=axis(PITCH_AXIS,a)@Rb;Rf=axis(PITCH_AXIS,a*.7+5.)@Rb;S=attor(S0);E=S+Ru@UV@(np.array(E0)-S0);un=plane(sources[up],S0,S,Ru@UV,side+'-original-upper-arm',ph);fn=plane(sources[fore],E0,E,Rf@UV,side+'-original-full-forearm-grip-pole'if side=='R'else side+'-original-complete-forearm-cuff-hand',ph);armsnodes.extend([un,fn]);arminfo[side]=dict(shoulder=S.tolist(),elbow=E.tolist(),upper_SO3=Ru.tolist(),fore_SO3=Rf.tolist(),source_upper_anchor=S0,source_fore_anchor=E0,upper_world_UV=(Ru@UV).tolist(),fore_world_UV=(Rf@UV).tolist(),full_staff_and_actual_grip_single_rigid_node=side=='R')
 out=blank();out.alpha_composite(coat['im']);out.alpha_composite(depth_group(legnodes,'both-actual-legs-and-boots',ph));out.alpha_composite(pelvis['im']);out.alpha_composite(torso['im']);out.alpha_composite(head['im'])
 for a in armsnodes:out.alpha_composite(a['im'])
 nodes.extend([coat,pelvis,torso,head]+armsnodes);allrecords.extend([n['meta']for n in nodes]);p=D/f'E-RUN-phase{ph}-{state["name"]}-actual-native-v03.png';out.save(p);arr=np.array(out);lab,n=label(arr[:,:,3]>100);sz=np.bincount(lab.ravel());strong=[];boxes=find_objects(lab)
 for k,s in enumerate(sz[1:]):
  if s>=200:
   y,x=boxes[k];strong.append(dict(area=int(s),bbox=[x.start,y.start,x.stop,y.stop]))
 y,x=np.where(arr[:,:,3]>0);rows.append(dict(phase=ph,name=state['name'],**pin(p),physical_C=C,bodyunit=UNIT,common_unpadded_root=ROOT.tolist(),storage_translation=[PAD,PAD],native_size=[N,N],state=state,bones=bn,pelvis_world=H.tolist(),pelvis_SO3=Rp.tolist(),torso_waist=waist.tolist(),torso_SO3=Rb.tolist(),head_neck=neck.tolist(),head_SO3=Rh.tolist(),arms=arminfo,actual_node_rasters=[n['meta']['raster']for n in nodes],actual_node_count=len(nodes),strong_components=strong,stored_alpha_bbox=[int(x.min()),int(y.min()),int(x.max()),int(y.max())],storage_boundary_alpha_contact=bool(x.min()==0 or y.min()==0 or x.max()==N-1 or y.max()==N-1),authored_clock=[ph*.08,(ph+1)*.08]))
partpath=D/'E-RUN-actual-native-source-parts-and-semantic-owners-v03.json';partpath.write_text(json.dumps(dict(status='ACTUAL_NEW_RUN_PARTS_ALL_ORIGINAL_OWN_NATIVE_RGBA',parts=source_parts,original_materials=original_refs,source_material_manifest=pin(MP),final_arm_staff_manifest=pin(AM),original_native_RGBA_recolored=False,opposite_side_leg_source=False,new_unseen_material_used=False),indent=2)+'\n')
physics=D/'E-RUN-actual-all-native-source-raster-floor-binding-v03.json';physics.write_text(json.dumps(dict(status='ACTUAL_NATIVE_RUN_SURFACE_FLOOR_PENDING_INDEPENDENT_QC',records=allrecords,actual_source_and_raster_count=len(allrecords),min_guarded_source_raster_Z=min(r['guarded_min_Z']for r in allrecords),all_above_floor=all(r['guarded_min_Z']>=0 for r in allrecords),projection_matrix=Pr.tolist(),camera_ray=[0,1,1],source_alpha_preserved=True,float_premultiplied_four_channel_sampling=True,renderer=pin(Path(__file__))),indent=2)+'\n')
scale=dict(profile=pin(profile),controller=pin(controller),C=C,logical_canvas=1024,profile_pixel_scale=PROFILE_SCALE,native_to_game_world=NS,movement_reference_speed=210.,authored_fps=12.5,authored_phase_seconds=.08,authored_cycle_seconds=.48,existing_run_speed_ratio=1.25,actual_run_speed=262.5,actual_phase_seconds=.064,actual_cycle_seconds=.384,world_phase_step=16.8,screen_forward=SCREEN_FORWARD.tolist(),native_screen_phase_step=(SCREEN_FORWARD*STEP).tolist(),support_phase0_to1_native_heel_delta=(Pr@(np.array(rows[1]['bones']['L']['structural_heel_support'])-rows[0]['bones']['L']['structural_heel_support'])).tolist(),support_phase3_to4_native_heel_delta=(Pr@(np.array(rows[4]['bones']['R']['structural_heel_support'])-rows[3]['bones']['R']['structural_heel_support'])).tolist(),support_world_lock_error=abs((gait[0]['stride']-gait[1]['stride'])*PX*NS-16.8),profile_or_controller_changed=False)
c=dict(status='ACTUAL_NEW_OWN_E_RUN_SIX_SOURCE_PENDING_INDEPENDENT_NATIVE_FEET_GRIP_LOOP_AND_GAME_QC',actor='transform:413',direction='E',motion='run',fixed_C=C,bodyunit=UNIT,common_unpadded_root=ROOT.tolist(),native_input_canvas=[1254,1254],storage_canvas=[N,N],storage_translation=[PAD,PAD],source_capture_body_U=U.tolist(),source_capture_body_V=V.tolist(),native_pelvis_anchor=[724,686],fixed_femur_tibia=BONE,fixed_bone_choice='RUN-specific fixed245-native femur/tibia declared before final rendering; projected original longitudinal source native lengths remain conditioned on the native capture planes. Old death-specific318.725 crouch model was not a required run anatomy pin.',projection_matrix=Pr.tolist(),original_own_materials=pin(partpath),RUN_only_original_ribbon_owner_transfer=pin(ownerproof),once_registration=pin(REG),canonical_original_sole_capture=pin(SOLE),source_floor_binding=pin(physics),runtime_scale_and_fixed_control=scale,source_RGBA_scaled=False,wholeactor_mirror=False,perpose_root_or_C_fit=False,loop=True,authored_cycle_seconds=.48,authored_fps=12.5,frames=rows,renderer=pin(Path(__file__)),limits=['One fixed physical bone model and source capture with source-plane material witnesses, not a unique hidden3D recovery.','Original actual full ornate greaves, toes, heels, head, bodice, jewels, cape and complete RIGHT foregrip-pole preserved; proper own left/right feet with no oldRUN or paired-leg bitmap substitution.','Continuous original proximal thigh, knee, ankle and real cloth/ribbon modules; float4 premultiplied sample then unpremultiply then final clamp.','All6 are a dedicated new run cycle, leftsupport0/load1 then AIR2/rightsupport3/load4 then AIR5. Exact support displacement follows savedprofile and controller clock.','A seamless periodic six-pose controller samples these actual poses; independent visual loop and game timing checks remain required.'],actor_approvals_added=0,game_clips_adopted=0)
cp=D/'own-E-RUN-six-actual-native-source-contract-v01.json';cp.write_text(json.dumps(c,indent=2,allow_nan=False)+'\n')
allow=D/'E-RUN-v03-frozen-source-and-code-allowlist.json';files=[p for p in D.rglob('*')if p.is_file()and p!=allow]+[Path(__file__),REG,MP,AM,SOLE];allow.write_text(json.dumps(dict(status='IMMUTABLE_V03_NEW_ACTUAL6_SOURCE_REVIEW_ALLOWLIST',contract=pin(cp),files=[pin(p)for p in files],original_failed_or_prior_sources_preserved=True,actor_approvals_added=0),indent=2)+'\n')
board=Image.new('RGB',(1080,980),'#3c4e60');dr=ImageDraw.Draw(board)
for i,r in enumerate(rows):
 im=Image.open(r['path']);im=im.crop((PAD+260,PAD-40,PAD+1230,PAD+1300));im.thumbnail((355,450));x=i%3*360;y=i//3*490;board.paste(im,(x,y+27),im);dr.text((x+5,y+8),f'{i} {r["name"]}',fill='white')
bp=D/'private-E-RUN-six-source-bounded-v03.jpg';board.save(bp,quality=78);assert bp.stat().st_size<150000
print(json.dumps(dict(contract=pin(cp),allowlist=pin(allow),actual6=6,nodes=len(allrecords),strong=[len(r['strong_components'])for r in rows],minfloor=min(r['guarded_min_Z']for r in allrecords),support_lock_error=scale['support_world_lock_error'],preview=pin(bp))))
