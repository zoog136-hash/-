"""Numeric-only independent current SE death companion; no source writes."""
from pathlib import Path
import json,hashlib,math
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates,label
A=Path('/workspace/scratch/mythic413-SE-death-author-20261020-v01');B=Path(__file__).parent
CP=A/'actual-own-SE-DEATH-six-native-v05/own-SE-DEATH-six-actual-native-source-contract-v05.json';PP=A/'own-SE-DEATH-v05-whole-actual-source-raster-floor-and-exact108-native-parts-binding-v01.json'
C=json.loads(CP.read_text());D=json.loads(PP.read_text());ROOT=np.array(C['common_unpadded_root']);PAD=np.array(C['storage_translation']);P=np.array(C['projection_matrix']);seen={};cache={}
def pin(p):
 p=Path(p);return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def check(s):
 p=s['path']
 if p not in seen:
  q=pin(p);assert q['sha256']==s['sha256'];assert 'bytes' not in s or q['bytes']==s['bytes'];seen[p]=q
 return Path(p)
def rgba(s,retain=False):
 p=check(s)
 if str(p) in cache:return cache[str(p)]
 a=np.array(Image.open(p).convert('RGBA'))
 if retain:cache[str(p)]=a
 return a
def close(a,b):assert np.allclose(a,b,atol=3e-7,rtol=0),(a,b)
assert pin(CP)['sha256']=='70c9c539fb01d1b1d847e92c12224a7b28a01022cf26a755bfdd5fee37b3832e';assert pin(PP)['sha256']=='c0c95ee8278e7d787991aa7a6b9c20e42cdc528db6d82356756631e655763465'
assert C['fixed_C']==2816 and C['bodyunit']==2.75 and C['fixed_femur_tibia']==318.725 and np.array_equal(P,[[10/9,0,0],[0,1,-1]]) and np.array_equal(PAD,[256,256])
assert C['runtime_death_seconds']==.8 and C['resource_role_seconds']==.65 and C['phase_seconds']==.8/6 and not C['loop'] and C['held_dead_terminal'];assert not C['source_RGBA_scaled'] and not C['wholeactor_mirror'] and not C['perpose_root_or_C_fit']
for key in ['renderer','binder','source_native_manifest','canonical_original_sole_model','once_registration','defining_joint_UV','defining_rootcloth_UV']:check(D[key])
def xy(a):
 y,x=np.where(a[:,:,3]>0);return x.astype(float),y.astype(float)
def affine(r,s,a):
 x,y=xy(s);rx,ry=xy(a);sa=np.array(r['source_anchor']);wa=np.array(r['world_anchor']);UV=np.column_stack([r['source_world_U'],r['source_world_V']]);g=r['guard_native'];grad=UV[2]@np.linalg.inv(P@UV)
 sm=float((wa[2]+(np.stack([x,y],1)-sa)@UV[2]).min()-.5*abs(UV[2]).sum()-g);rm=float((wa[2]+(np.stack([rx,ry],1)-ROOT-PAD-P@wa)@grad).min()-.5*abs(grad).sum()-g)
 assert len(x)==r['source_alpha_gt0_texels'] and len(rx)==r['raster_alpha_gt0_texels'];return sm,rm,dict(source_alpha=len(x),raster_alpha=len(rx))
def mesh_bound(s,a,world,step,skip_empty):
 sx,sy=xy(s);x0=max(0,int(sx.min())-1);x1=min(s.shape[1]-1,int(sx.max())+1);y0=max(0,int(sy.min())-1);y1=min(s.shape[0]-1,int(sy.max())+1);xs=np.unique(np.r_[np.arange(x0,x1,step),x1]);ys=np.unique(np.r_[np.arange(y0,y1,step),y1]);yy,xx=np.meshgrid(ys,xs,indexing='ij');uv=np.stack([xx,yy],-1);xyz=world(xx,yy);screen=ROOT+xyz@P.T+PAD;lo=np.floor(screen.min((0,1))-2).astype(int);hi=np.ceil(screen.max((0,1))+2).astype(int);w,h=hi-lo+1
 assert np.all(lo>=0) and np.all(hi<2304);alpha=np.zeros((h,w),np.uint8);depth=np.full((h,w),-np.inf);floor=np.full((h,w),np.inf)
 for iy in range(len(ys)-1):
  for ix in range(len(xs)-1):
   if skip_empty:
    bx0=max(0,int(xs[ix])-1);by0=max(0,int(ys[iy])-1);bx1=min(s.shape[1],int(math.ceil(xs[ix+1]))+2);by1=min(s.shape[0],int(math.ceil(ys[iy+1]))+2)
    if not s[by0:by1,bx0:bx1,3].any():continue
   for ids in [[(iy,ix),(iy,ix+1),(iy+1,ix+1)],[(iy,ix),(iy+1,ix+1),(iy+1,ix)]]:
    q=np.array([screen[i,j]-lo for i,j in ids]);u=np.array([uv[i,j] for i,j in ids]);W=np.array([xyz[i,j] for i,j in ids]);T=np.column_stack([q[1]-q[0],q[2]-q[0]])
    if abs(np.linalg.det(T))<1e-8:continue
    iv=np.linalg.inv(T);ll=np.maximum(0,np.floor(q.min(0)-.5).astype(int));hh=np.minimum([w-1,h-1],np.ceil(q.max(0)+.5).astype(int));gy,gx=np.mgrid[ll[1]:hh[1]+1,ll[0]:hh[0]+1];bc12=np.stack([gx-q[0,0],gy-q[0,1]],-1)@iv.T;bc=np.concatenate([1-bc12.sum(-1,keepdims=True),bc12],-1);inside=bc.min(-1)>=-.035;pos=bc@W;U=bc@u;al=map_coordinates(s[:,:,3],[U[:,:,1],U[:,:,0]],order=1,mode='constant',cval=0,prefilter=False);dep=pos[:,:,1]+pos[:,:,2];sl=(slice(ll[1],hh[1]+1),slice(ll[0],hh[0]+1));use=inside&(al>0)&(dep>=depth[sl]);grad=(W[1:,2]-W[0,2])@iv;zmin=pos[:,:,2]-.5*abs(grad).sum();alpha[sl][use]=al[use];depth[sl][use]=dep[use];floor[sl][use]=zmin[use]
 assert np.array_equal(alpha,a[lo[1]:hi[1]+1,lo[0]:hi[0]+1,3]);assert np.count_nonzero(alpha)==np.count_nonzero(a[:,:,3]);return float(floor[alpha>0].min()),int(np.count_nonzero(alpha)),dict(lo=lo,depth=depth,alpha=alpha)
def joint(r,s,a):
 op=r['operator'];S=np.array(op['source_anchor']);K=np.array(op['world_anchor']);MT=np.array(op['source_femur_world_UV']);MC=np.array(op['source_calf_world_UV']);b0,b1=op['source_blend_y'];bw=b1-b0;sx,sy=xy(s)
 def world(x,y):
  t=np.clip((y-b0)/bw,0,1);g=t*t*(3-2*t);uv=np.stack([x-S[0],y-S[1]],-1);return K+uv@MT.T*(1-g[...,None])+uv@MC.T*g[...,None]
 sm=min(float(world(sx+dx,sy+dy)[:,2].min()) for dx in [-.5,.5] for dy in [-.5,.5]);bound=math.inf
 for x in [sx.min()-.5,sx.max()+.5]:
  yp=np.polynomial.Polynomial([b0,bw]);gp=np.polynomial.Polynomial([0,0,3,-2]);pol=K[2]+MT[2,0]*(x-S[0])+MT[2,1]*(yp-S[1])+gp*((MC[2,0]-MT[2,0])*(x-S[0])+(MC[2,1]-MT[2,1])*(yp-S[1]));points=[sy.min()-.5,sy.max()+.5,b0,b1];points += [b0+bw*t.real for t in pol.deriv().roots() if abs(t.imag)<1e-8 and 0<=t.real<=1];yy=np.array([y for y in points if sy.min()-.5<=y<=sy.max()+.5]);bound=min(bound,float(world(np.full(len(yy),x),yy)[:,2].min()))
 close(sm,op['source_quad_min_Z']);close(bound,op['complete_continuous_surface_quartic_min_Z']);rm,count,selected=mesh_bound(s,a,world,1.5,False);
 if 'selected_actual_raster_raydepth' in op:
  q=np.load(check(op['selected_actual_raster_raydepth']),allow_pickle=False);assert np.array_equal(q['lo'],selected['lo']);ok=selected['alpha']>0;close(q['depth'][ok],selected['depth'][ok])
 close(rm,op['raster_texel_quad_min_Z']);assert count==op['raster_alpha_gt0_texels'];return min(sm,bound)-3,rm-3,dict(source_alpha=len(sx),raster_alpha=count,continuous_quartic_min=bound,actual_selected_triangle_alpha_mismatch=0)
def cloth(r,s,a):
 op=r['operator'];S=np.array(op['source_root']);A0=np.array(op['world_root']);SP=np.array(op['pelvis_native_anchor']);HP=np.array(op['pelvis_world']);U=np.array(op['pelvis_U']);V=np.array(op['pelvis_V']);T=np.array(op['transverse']);angle=math.radians(op['longitudinal_angle']);co=math.cos(angle);si=math.sin(angle);b0,b1=op['source_proximal_blend_y'];floor=op['floor_Z'];sx,sy=xy(s)
 def world(x,y):
  u=x-S[0];length=y-S[1];base=A0[2]+T[2]*u;hit=np.maximum(0,(base-floor)/max(co,1e-9));air=np.minimum(length,hit);travel=si*air+np.maximum(0,length-hit);q=np.stack([A0[0]+T[0]*u-math.cos(math.radians(25))*travel,A0[1]+T[1]*u+math.sin(math.radians(25))*travel,np.maximum(floor,base-co*length)],-1);body=HP+(x-SP[0])[...,None]*U+(y-SP[1])[...,None]*V;t=np.clip((y-b0)/(b1-b0),0,1);g=t*t*(3-2*t);return body*(1-g[...,None])+q*g[...,None]
 # Each proximal blend is convex between the bounded pelvis plane and the
 # Z>=10 arclength drape. At/after780 it is exactly the drape.
 pb=min(float((HP+(x-SP[0])*U+(y-SP[1])*V)[2]) for x in [sx.min()-.5,sx.max()+.5] for y in [sy.min()-.5,min(b1,sy.max()+.5)]);bound=min(floor,pb);sm=min(float(world(sx+dx,sy+dy)[:,2].min()) for dx in [-.5,.5] for dy in [-.5,.5]);close(bound,op['source_complete_surface_min_Z']);close(sm,op['source_all_quad_corner_min_Z']);rm,count,_=mesh_bound(s,a,world,4,True);close(rm,op['raster_all_texel_quad_min_Z']);assert len(sx)==op['actual_source_alpha_gt0_texels'] and count==op['actual_raster_alpha_gt0_texels'];return min(sm,bound)-3,rm-3,dict(source_alpha=len(sx),raster_alpha=count,entire_continuous_source_min=bound,actual_selected_triangle_alpha_mismatch=0)
assert len(D['records'])==len(D['parts'])==108;rows=[]
for i,r in enumerate(D['records']):
 assert r['raster']==D['parts'][i];s=rgba(r['source'],True);a=rgba(r['raster']);kind=r['kind']
 if kind.startswith('EXACT_PINNED'):sm,rm,detail=affine(r,s,a)
 elif kind=='ORIGINAL_COMPLETE_DIRECTIONAL_NATIVE_JOINT_CONTINUOUS_UV':check(r['defining_UV_code']);sm,rm,detail=joint(r,s,a)
 elif kind=='ORIGINAL_COMPLETE_CLOTH_PELVIS_ROOT_CONTINUOUS_ARCLENGTH_FLOOR_SURFACE':check(r['defining_UV_code']);sm,rm,detail=cloth(r,s,a)
 else:raise AssertionError(kind)
 close(sm,r['source_texel_quad_plus_guard_min_Z']);close(rm,r['raster_texel_quad_plus_guard_min_Z']);assert min(sm,rm)>0;rows.append(dict(phase=r['phase'],name=r['name'],kind=kind,source_min_Z=sm,actual_raster_min_Z=rm,detail=detail))
 if i%18==17:print(json.dumps(dict(stage='source_and_actual_raster_surfaces',completed_phase=r['phase'],records=i+1)),flush=True)
capture=np.column_stack([C['source_capture_body_U'],C['source_capture_body_V']]);gram=capture.T@capture;berr=gerr=0.;frames=[]
for ph,f in enumerate(C['frames']):
 a=rgba(f);layers=[Image.open(check(p)).convert('RGBA') for p in D['parts'][ph*18:(ph+1)*18]];out=Image.new('RGBA',(2304,2304));out.alpha_composite(layers[17])
 for side,start in [('R',0),('L',5)]:
  aa=np.array(layers[start]);bb=np.array(layers[start+1]);ys,xs=np.where((aa[:,:,3]>0)|(bb[:,:,3]>0));lo=np.array([xs.min(),ys.min()]);hi=np.array([xs.max(),ys.max()])+1;gy,gx=np.mgrid[lo[1]:hi[1],lo[0]:hi[0]];bone=f['bones'][side];K=np.array(bone['knee']);MC=np.array(bone['calf_source_world_UV']);grad=(MC[1]+MC[2])@np.linalg.inv(P@MC);calfdepth=K[1]+K[2]+(np.stack([gx,gy],-1)-ROOT-PAD-P@K)@grad
  spec=bone['actual_proximal_thigh_root']['selected_actual_raster_raydepth'];z=np.load(check(spec),allow_pickle=False);dl=z['lo'];dh,dw=z['depth'].shape;left=np.maximum(lo,dl);right=np.minimum(hi,dl+[dw,dh]);thighdepth=np.full(calfdepth.shape,-np.inf);thighdepth[left[1]-lo[1]:right[1]-lo[1],left[0]-lo[0]:right[0]-lo[0]]=z['depth'][left[1]-dl[1]:right[1]-dl[1],left[0]-dl[0]:right[0]-dl[0]]
  both=(aa[lo[1]:hi[1],lo[0]:hi[0],3]>0)&(bb[lo[1]:hi[1],lo[0]:hi[0],3]>0);front=both&(thighdepth>calfdepth+1e-8);temp=Image.new('RGBA',(2304,2304));temp.alpha_composite(layers[start]);temp.alpha_composite(layers[start+1]);rev=Image.new('RGBA',(2304,2304));rev.alpha_composite(layers[start+1]);rev.alpha_composite(layers[start]);ta=np.array(temp);ra=np.array(rev);ta[lo[1]:hi[1],lo[0]:hi[0]][front]=ra[lo[1]:hi[1],lo[0]:hi[0]][front];temp=Image.fromarray(ta)
  for j in [2,3,4]:temp.alpha_composite(layers[start+j])
  out.alpha_composite(temp)
 for group in [[10],[11],[12],[15,16],[13,14]]:
  temp=Image.new('RGBA',(2304,2304))
  for j in group:temp.alpha_composite(layers[j])
  out.alpha_composite(temp)
 assert np.array_equal(a,np.array(out));lab,n=label(a[:,:,3]>100);counts=np.bincount(lab.ravel())[1:];assert np.count_nonzero(counts>=200)==1 and not a[[0,-1],:,3].any() and not a[:,[0,-1],3].any()
 for side,b in f['bones'].items():
  for u,v in [('hip','knee'),('knee','ankle')]:berr=max(berr,abs(np.linalg.norm(np.array(b[u])-b[v])-318.725))
  for u,v,key in [('hip','knee','thigh_source_world_UV'),('knee','ankle','calf_source_world_UV')]:
   sv=np.array(b['source_controls'][v])-b['source_controls'][u];bv=np.array(b[v])-b[u];UV=np.array(b[key]);close(UV@sv,bv);sn=np.array([-sv[1],sv[0]])/np.linalg.norm(sv);tv=P@bv;tn=np.array([-tv[1],tv[0]])/np.linalg.norm(tv);W=UV@sn;close(W,[tn[0]/P[0,0],tn[1]/2,-tn[1]/2])
 for key in ['pelvis_SO3','torso_SO3','head_SO3']:
  R=np.array(f[key]);close(R.T@R,np.eye(3));close(np.linalg.det(R),1)
 for arm in f['arms'].values():
  for key in ['upper_SO3','fore_SO3']:
   R=np.array(arm[key]);close(R.T@R,np.eye(3));close(np.linalg.det(R),1)
 UV=np.array(f['arms']['R']['source_fore_UV']);gerr=max(gerr,float(abs(UV.T@UV-gram).max()));close(f['clock_seconds'],[ph*.8/6,(ph+1)*.8/6]);frames.append(dict(phase=ph,source=pin(f['path']),RGBA_recomposition_mismatch=0,strong_bodies=1,edge_contact=False))
close(berr,0);close(gerr,0);term=C['frames'][5];flat=max(abs((np.array(term[key])@capture)[2]).max() for key in ['pelvis_SO3','torso_SO3','head_SO3']);close(flat,0)
target=B/'SEdeath-v05-independent-exact108-native-source-and-raster-floor-companion-v01.json';assert not target.exists();target.write_text(json.dumps(dict(status='PASS_ONE_DECLARED_FINITE_NATIVE_MATERIAL_MODEL_AND_EXACT_CURRENT108_BINDING',source_contract=pin(CP),physical_model=pin(PP),independent_script=pin(__file__),verified_files=list(seen.values()),actual_current_six=frames,records=rows,minimum_guarded_Z=min(min(r['source_min_Z'],r['actual_raster_min_Z']) for r in rows),all108_current_rasters_recompose_six_full_RGBA_exact=True,fixed318725_bones_max_residual=berr,whole_RIGHT_foregrip_pole_original_Gram_residual=gerr,minimum_norm_camera_plane_transverse_checked=True,terminal_front_plane_flat_residual=flat,declared_supine_terminal_support_hull=dict(visible_front_plane_Z=60,unseen_back_thickness=60,back_ground_Z=0),runtime_seconds=.8,resource_seconds=.65,phase_seconds=.8/6,loop=False,held_dead_terminal=True,limitations=['One declared compatible source/depth/material model, not uniquely measured hidden anatomy or a full physical3D body. Flexible transverse directions use the explicit minimum-norm camera-plane rule, not perpendicular anatomical muscle cross sections.','All nonlinear actual raster alpha/triangle selection and quad floor bounds are independently reconstructed in memory. Original actual editableRGBA rasters recompose the final source exactly; no PNG is saved or modified.','The terminal unseen60native back support hull is an authored finite thickness assumption beneath the visible front plane. This numeric witness does not replace separate actual source/fall/held-terminal QA or a real game test.'],images_viewed=0,source_images_written=0,repository_changes=0,game_tests_run=0,actor_approvals_added=0),indent=2)+'\n');print(json.dumps(dict(proof=pin(target),records=108,minimum=min(min(r['source_min_Z'],r['actual_raster_min_Z']) for r in rows))),flush=True)
