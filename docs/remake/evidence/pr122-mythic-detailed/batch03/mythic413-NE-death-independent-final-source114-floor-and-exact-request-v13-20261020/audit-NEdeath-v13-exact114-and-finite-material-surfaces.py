"""Read-only independent numeric companion; writes this audit JSON only.

No source PNG, repo, engine, image service, or prior evidence is modified.
Finite depth/material surfaces are declared constructive models, not measured
hidden anatomy. Source appearance is reviewed separately in the private ledger.
"""
from pathlib import Path
import json, hashlib, math
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates, label

A=Path('/workspace/scratch/mythic413-NE-death-author-20261020-v01')
B=Path(__file__).parent
CP=A/'actual-NE-DEATH-six-native-v13/actual-NE-DEATH-six-source-contract-v13.json'
PP=A/'NE-DEATH-v13-whole-actual-source-raster-floor-and-exact-editable-parts-binding-v01.json'
MP=A/'NE-DEATH-v13-exact114-raster-to-original-source-and-defining-UV-functions-v01.json'
C=json.loads(CP.read_text()); D=json.loads(PP.read_text()); M=json.loads(MP.read_text())
ROOT=np.array(C['common_unpadded_root']); PAD=np.array(C['storage_translation']); P=np.array(D['projection'])
assert hashlib.sha256(CP.read_bytes()).hexdigest()=='f48f6769e20de2f3bf12171ff59d2e27fceed66e5c57801632707854a5ef8a43'
assert hashlib.sha256(PP.read_bytes()).hexdigest()=='71d47d43a0dd47b0bebe80c69fe1d346838239346615591e2c9693521a1b6cfe'
assert hashlib.sha256(MP.read_bytes()).hexdigest()=='5478c4a875c624242174858eb982c89ae1943c00a607a2b2cba49e6d6cfcc0e3'
assert C['fixed_C']==2432 and C['bodyunit']==2.375 and C['storage_canvas']==[2304,2304]
assert np.array_equal(P,[[10/9,0,0],[0,1,-1]]) and np.array_equal(PAD,[256,256])
assert C['runtime_death_seconds']==.8 and C['resource_role_seconds']==.65 and C['phase_seconds']==.8/6 and not C['loop'] and C['held_dead_terminal']
seen={}; arrays={}
def stamp(path):
 p=Path(path); return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def verify(s):
 p=s['path']
 if p not in seen:
  v=stamp(p); assert v['sha256']==s['sha256'],p
  if 'bytes' in s: assert v['bytes']==s['bytes'],p
  seen[p]=v
 return Path(p)
def rgba(s,cache=False):
 p=verify(s)
 if str(p) in arrays:return arrays[str(p)]
 a=np.array(Image.open(p).convert('RGBA'))
 if cache: arrays[str(p)]=a
 return a
def close(a,b,tol=2e-7):
 assert np.allclose(a,b,atol=tol,rtol=0),(a,b)
def coords(a):
 y,x=np.where(a[:,:,3]>0); assert len(x); return x.astype(float),y.astype(float)
for z in M['defining_code']:verify(z)
assert len(D['records'])==len(D['parts'])==len(M['records'])==114
rows=[]
def affine(r,src,ra):
 sx,sy=coords(src); rx,ry=coords(ra); sa=np.array(r['source_anchor']); wa=np.array(r['world_anchor']); UV=np.column_stack([r['source_U'],r['source_V']]); guard=r['guard_native']
 smin=float((wa[2]+(np.stack([sx,sy],1)-sa)@UV[2]).min()-.5*np.abs(UV[2]).sum()-guard)
 IV=np.linalg.inv(P@UV); grad=UV[2]@IV
 rmin=float((wa[2]+(np.stack([rx,ry],1)-PAD-ROOT-P@wa)@grad).min()-.5*np.abs(grad).sum()-guard)
 assert len(sx)==r['all_source_alpha_gt0_texels'] and len(rx)==r['all_raster_alpha_gt0_texels']
 if 'source_bone_end' in r:
  bv=np.array(r['world_bone_end'])-wa; sv=np.array(r['source_bone_end'])-sa; W=np.array(r['source_normal_world']);close(UV@sv,bv);close(W@bv,0);close(np.linalg.norm(bv),275.2625)
 return smin,rmin,dict(source_count=len(sx),actual_raster_count=len(rx))
def cloth(r,src,ra):
 sx,sy=coords(src); rx,ry=coords(ra); sa=np.array(r['source_root']); wa=np.array(r['world_root']); T=np.array(r['transverse_world']); th=math.radians(r['longitudinal_angle']); co=math.cos(th); si=math.sin(th); floor=r['fixed_floor_Z']; guard=r['guard_native']
 sm=rm=math.inf
 for dx in [-.5,.5]:
  for dy in [-.5,.5]:
   sm=min(sm,float(np.maximum(floor,wa[2]+T[2]*(sx+dx-sa[0])-co*(sy+dy-sa[1])).min()))
   u=(rx+dx-PAD[0]-ROOT[0]-(P@wa)[0])/(P[0,0]*T[0]); z=wa[2]+T[2]*u; depth=wa[1]+T[1]*u; hit=np.maximum(0,(z-floor)/max(co,1e-9)); q=ry+dy-PAD[1]-(ROOT[1]+depth-z); length=np.where(q<=(si+co)*hit,q/(si+co),hit+q-(si+co)*hit); zz=np.maximum(floor,z-co*length); rm=min(rm,float(zz.min()))
 assert len(sx)==r['all_source_alpha_gt0_texels'] and len(rx)==r['all_raster_alpha_gt0_texels']
 return sm-guard,rm-guard,dict(source_count=len(sx),actual_raster_count=len(rx),piecewise_arclength_floor=floor)
def ankle(r):
 q=r['operator']; O=np.array(q['orthonormal_surface_basis']);close(O.T@O,np.eye(3));close(np.linalg.det(O),1)
 radii=np.array(q['all_edge_texel_quad_expanded_radii']);close(radii,np.array(q['physical_radii'])+1.1)
 z=float(q['center_world'][2]-np.linalg.norm(radii*O[2])-q['material_Z_guard'])
 close(z,q['conservative_all_surface_and_raster_quad_guard_min_Z'])
 return z,z,dict(method='analytic enclosing ellipsoid Z-support, enlarged1.1 and additive Zguard2',expanded_radii=radii.tolist())
def sleeve(r,src,ra):
 op=r['operator']; S=np.array(op['source_elbow']); wa=np.array(op['world_elbow']); U=np.array(op['upper_basis']); F=np.array(op['forearm_rigid_basis']); E=U-F; MF=P@F; ME=P@E
 def weights(q):
  x,y=q.T; zx=np.clip((x-840)/25,0,1);zy=np.clip((y-568)/36,0,1); fx=1-zx*zx*(3-2*zx);fy=1-zy*zy*(3-2*zy)
  gx=np.where((x>840)&(x<865),-6*zx*(1-zx)/25,0)*fy;gy=np.where((y>568)&(y<604),-6*zy*(1-zy)/36,0)*fx
  return fx*fy,gx,gy
 def world(q):
  g,_,_=weights(q); return wa+(q-S)@F.T+((q-S)@E.T)*g[:,None]
 def inverse(t):
  q=S+t@np.linalg.inv(MF).T
  for _ in range(16):
   g,gx,gy=weights(q); du=(q-S)@ME.T; err=(q-S)@MF.T+du*g[:,None]-t; j=MF[None,:,:]+g[:,None,None]*ME[None,:,:]+du[:,:,None]*np.stack([gx,gy],1)[:,None,:]
   det=j[:,0,0]*j[:,1,1]-j[:,0,1]*j[:,1,0];assert np.min(abs(det))>1e-5
   dx=(j[:,1,1]*err[:,0]-j[:,0,1]*err[:,1])/det;dy=(j[:,0,0]*err[:,1]-j[:,1,0]*err[:,0])/det;q-=np.clip(np.stack([dx,dy],1),-20,20)
  res=float(np.linalg.norm((world(q)-wa)@P.T-t,axis=1).max()); assert res<.08;return q,res
 sx,sy=coords(src);rx,ry=coords(ra); sm=rm=math.inf; residual=0
 for dx in [-.5,.5]:
  for dy in [-.5,.5]:
   sm=min(sm,float(world(np.stack([sx+dx,sy+dy],1))[:,2].min())); uv,err=inverse(np.stack([rx+dx,ry+dy],1)-ROOT-PAD-P@wa); residual=max(residual,err);rm=min(rm,float(world(uv)[:,2].min()))
 box=np.array([[x,y] for x in [sx.min()-.5,sx.max()+.5] for y in [sy.min()-.5,sy.max()+.5]]); dzmax=np.max(abs((box-S)@E[2])); L=np.maximum(abs(U[2]),abs(F[2]))+np.array([1.5/25,1.5/36])*dzmax
 bound=float(world(np.stack([sx,sy],1))[:,2].min()-.5*L.sum());close(bound,r['source_quad_complete_interior_min_Z']);close(L,r['source_quad_derivative_bound'])
 return min(sm,bound)-2,rm-2,dict(source_count=len(sx),actual_raster_count=len(rx),all_actual_corner_inverse_residual=residual,source_quad_interior_bound=bound)
def knee(r,src,ra):
 op=r['operator']; K=np.array(op['knee']); MT=np.array(op['source_femur_world_UV']); MC=np.array(op['source_calf_world_UV']); sx,sy=coords(src)
 def world(x,y):
  t=np.clip((y-804)/26,0,1); g=t*t*(3-2*t); uv=np.stack([x-790,y-815],-1);return K+uv@MT.T*(1-g[...,None])+uv@MC.T*g[...,None]
 sm=min(float(world(sx+dx,sy+dy)[:,2].min()) for dx in [-.5,.5] for dy in [-.5,.5]); bound=math.inf
 for x in [sx.min()-.5,sx.max()+.5]:
  yp=np.polynomial.Polynomial([804,26]); gp=np.polynomial.Polynomial([0,0,3,-2]); pol=K[2]+MT[2,0]*(x-790)+MT[2,1]*(yp-815)+gp*((MC[2,0]-MT[2,0])*(x-790)+(MC[2,1]-MT[2,1])*(yp-815)); yy=[sy.min()-.5,sy.max()+.5,804.,830.];yy += [804+26*q.real for q in pol.deriv().roots() if abs(q.imag)<1e-8 and 0<=q.real<=1]; yy=np.array([y for y in yy if sy.min()-.5<=y<=sy.max()+.5]);bound=min(bound,float(world(np.full(len(yy),x),yy)[:,2].min()))
 close(sm,op['source_quad_min_Z']);close(bound,op['complete_continuous_surface_quartic_min_Z'])
 # Independent triangle selection and alpha/color sampling in memory only.
 xs=np.unique(np.r_[np.arange(max(0,int(sx.min())-1),min(src.shape[1]-1,int(sx.max())+1),1.5),min(src.shape[1]-1,int(sx.max())+1)])
 ys=np.unique(np.r_[np.arange(max(0,int(sy.min())-1),min(src.shape[0]-1,int(sy.max())+1),1.5),min(src.shape[0]-1,int(sy.max())+1)])
 gy,gx=np.meshgrid(ys,xs,indexing='ij'); UV=np.stack([gx,gy],-1); W=world(gx,gy); Q=ROOT+W@P.T+PAD;lo=np.floor(Q.min((0,1))-2).astype(int);hi=np.ceil(Q.max((0,1))+2).astype(int);width,height=hi-lo+1
 result=np.zeros((height,width,4),np.uint8); dep=np.full((height,width),-np.inf); floor=np.full((height,width),np.inf)
 for iy in range(len(ys)-1):
  for ix in range(len(xs)-1):
   for ids in [[(iy,ix),(iy,ix+1),(iy+1,ix+1)],[(iy,ix),(iy+1,ix+1),(iy+1,ix)]]:
    q=np.array([Q[i,j]-lo for i,j in ids]);uv=np.array([UV[i,j] for i,j in ids]);w=np.array([W[i,j] for i,j in ids]);T=np.column_stack([q[1]-q[0],q[2]-q[0]])
    if abs(np.linalg.det(T))<1e-8:continue
    iv=np.linalg.inv(T);ll=np.maximum(0,np.floor(q.min(0)-.5).astype(int));hh=np.minimum([width-1,height-1],np.ceil(q.max(0)+.5).astype(int)); yy,xx=np.mgrid[ll[1]:hh[1]+1,ll[0]:hh[0]+1];t=np.stack([xx-q[0,0],yy-q[0,1]],-1)@iv.T;bc=np.concatenate([1-t.sum(-1,keepdims=True),t],-1);hit=bc.min(-1)>=-.035; xyz=bc@w; tu=bc@uv; col=np.stack([map_coordinates(src[:,:,k],[tu[:,:,1],tu[:,:,0]],order=1,mode='constant',cval=0,prefilter=False) for k in range(4)],-1).astype(np.uint8)
    sl=(slice(ll[1],hh[1]+1),slice(ll[0],hh[0]+1));zdep=xyz[:,:,1]+xyz[:,:,2];use=hit&(col[:,:,3]>0)&(zdep>=dep[sl]);grad=(w[1:,2]-w[0,2])@iv;zmin=xyz[:,:,2]-.5*abs(grad).sum();result[sl][use]=col[use];dep[sl][use]=zdep[use];floor[sl][use]=zmin[use]
 result[result[:,:,3]==0,:3]=0
 expected=ra[lo[1]:hi[1]+1,lo[0]:hi[0]+1];assert np.array_equal(result,expected),(r['phase'],r['name'],'knee raster differs')
 assert np.count_nonzero(ra[:,:,3])==np.count_nonzero(result[:,:,3]);rm=float(floor[result[:,:,3]>0].min());close(rm,op['raster_texel_quad_min_Z'])
 return min(sm,bound,rm)-3,rm-3,dict(source_count=len(sx),actual_raster_count=int(np.count_nonzero(result[:,:,3])),independent_actual_RGBA_triangle_reproduction_mismatch=0,continuous_quartic_bound=bound)

for i,(r,m) in enumerate(zip(D['records'],M['records'])):
 assert (r['phase'],r['name'],r['kind'])==(m['phase'],m['name'],m['kind']);assert r['raster']==m['exact_raster']==D['parts'][i]
 inputs=m['source_definition']['source_inputs']; [verify(s) for s in inputs]; src=rgba(inputs[0],True); ra=rgba(r['raster'])
 kind=r['kind']
 if kind in ['exact_3D_material_plane','exact_fixed_bone_flexible_native_material_surface']:sm,rm,detail=affine(r,src,ra)
 elif kind.startswith('exact_native_2D'):sm,rm,detail=cloth(r,src,ra)
 elif kind.startswith('FINITE_NATIVE'):sm,rm,detail=ankle(r)
 elif kind.startswith('CONTINUOUS_ORIGINAL'):sm,rm,detail=sleeve(r,src,ra)
 elif kind.startswith('ORIGINAL_ACTUAL'):sm,rm,detail=knee(r,src,ra)
 else:raise AssertionError(kind)
 close(sm,r['source_texel_quad_plus_guard_min_Z']);close(rm,r['raster_texel_quad_plus_guard_min_Z']);assert min(sm,rm)>=0
 rows.append(dict(phase=r['phase'],name=r['name'],kind=kind,source_min_Z=sm,actual_raster_min_Z=rm,detail=detail))
 if i%19==18:print(json.dumps(dict(stage='finite-materials',completed_phase=r['phase'],records=i+1)),flush=True)

original_capture=np.column_stack([C['source_capture_body_U'],C['source_capture_body_V']]); gram=original_capture.T@original_capture; boneerr=gramerr=0.; frames=[]
for ph,f in enumerate(C['frames']):
 actual=rgba(f); assert actual.shape==(2304,2304,4)
 layers=[Image.open(verify(z)).convert('RGBA') for z in D['parts'][19*ph:19*(ph+1)]]
 out=Image.new('RGBA',(2304,2304));out.alpha_composite(layers[18])
 for indexes in [[0,1,2,3,4],[5,6,7,8,9],[10],[11],[12],[16,17],[13,14,15]]:
  group=Image.new('RGBA',(2304,2304))
  for j in indexes:group.alpha_composite(layers[j])
  out.alpha_composite(group)
 assert np.array_equal(np.array(out),actual),'114 grouped exact RGBA composition'
 la,n=label(actual[:,:,3]>100); counts=np.bincount(la.ravel())[1:];assert sum(counts>=200)==1
 assert not np.any(actual[[0,-1],:,3]>16) and not np.any(actual[:,[0,-1],3]>16)
 for side,b in f['bones'].items():
  for u,v in [('hip','knee'),('knee','ankle')]:boneerr=max(boneerr,abs(np.linalg.norm(np.array(b[u])-b[v])-275.2625))
 for name in ['pelvis_SO3','torso_SO3','head_SO3']:
  R=np.array(f[name]);close(R.T@R,np.eye(3));close(np.linalg.det(R),1)
 arm=f['arms']['R'];UV=np.column_stack([arm['forearm_source_U'],arm['forearm_source_V']]);gramerr=max(gramerr,float(abs(UV.T@UV-gram).max()))
 close(f['seconds_range'],[ph*.8/6,(ph+1)*.8/6]);frames.append(dict(phase=ph,source=stamp(f['path']),RGBA_composition_mismatch_pixels=0,strong_bodies=1))
close(boneerr,0);close(gramerr,0)

# Verify original genuine semantic-owner texels, actual output differences, and
# unchanged underlying pose/body/grip/staff controls against v05 and v11.
O5=json.loads((A/'actual-NE-DEATH-six-native-v05/actual-NE-DEATH-six-source-contract-v05.json').read_text());O11=json.loads((A/'actual-NE-DEATH-six-native-v11/actual-NE-DEATH-six-source-contract-v11.json').read_text())
def subset(a,b):
 if isinstance(a,dict):
  for k,v in a.items():assert k in b; subset(v,b[k])
 elif isinstance(a,list):assert a==b
 else:assert a==b,(a,b)
for old,new in zip(O5['frames'],C['frames']):
 for k in ['state','pelvis_world','pelvis_SO3','torso_waist_world','torso_SO3','head_neck_world','head_SO3','cloth_native_model','bones','arms']:subset(old[k],new[k])
ownerpath=A/'NE-DEATH-v13-v11-true-ribbon-and-LEFTcuff-owner-only-RGBA-binding-v01.json';owner=json.loads(ownerpath.read_text());ownerrows=[]
for old,new,r in zip(O11['frames'],C['frames'],owner['rows']):
 oa=rgba(old);na=rgba(new);allow=np.zeros(oa.shape[:2],bool)
 for q in r['allowed_regions']:
  x0,y0,x1,y1=q['stored_bbox'];allow[y0:y1,x0:x1]=True
 diff=np.any(oa!=na,2); assert np.count_nonzero(diff&~allow)==0;assert np.count_nonzero(diff)==r['changed_RGBA_pixels'];ownerrows.append(dict(phase=new['phase'],actual_changed_pixels=int(diff.sum()),outside_declared_owner_bounds=0))
original=rgba({'path':'/workspace/scratch/mythic413-NE-walk-author-20261020-v01/NE-contact0-actual-native-background-AA-clean-r002.png','sha256':'99ffa7da2332144f3d449e9e23881bbaa130ace3027e837518148b705d92c127'},True)
for own in C['semantic_owner_closure']:
 patch=rgba(own['source_RGBA']);mask=np.array(Image.open(verify(own['semantic_matte'])))>0
 if mask.ndim==3:mask=mask[:,:,0]
 # Dilation includes transparent ownership holes already occupied by another
 # original node. Verify only transferred painted RGBA against the original,
 # and the entire mask against its actual pre-transfer torso owner.
 painted=patch[:,:,3]>0;assert np.array_equal(patch[painted],original[painted])
 oldtorso=rgba({'path':str(A/'actual-NE-DEATH-six-native-v11/native-torso-native-bluegold-bodice.png'),'sha256':hashlib.sha256((A/'actual-NE-DEATH-six-native-v11/native-torso-native-bluegold-bodice.png').read_bytes()).hexdigest()},True)
 assert np.array_equal(patch[mask],oldtorso[mask]);ll,_=label(oldtorso[:,:,3]>100);seed=own['original_source_seed'];assert np.count_nonzero(ll==ll[seed[1],seed[0]])==own['original_strong_source_pixels']
terminal=C['frames'][5];tz=[]
for key in ['pelvis_SO3','torso_SO3','head_SO3']:tz.extend((np.array(terminal[key])@original_capture)[2].tolist())
close(tz,np.zeros(len(tz)));assert D['held_terminal']['back_surface_height']==D['held_terminal']['fixed_body_head_front_thickness']==60

result=dict(status='PASS_FINITE_DECLARED_MODEL_AND_EXACT_CURRENT_114_PART_BINDING',contract=stamp(CP),physical_model=stamp(PP),exact_source_function_map=stamp(MP),independent_script=stamp(__file__),verified_files=list(seen.values()),fixed_C=2432,bodyunit=2.375,root=ROOT.tolist(),storage_translation=PAD.tolist(),storage_canvas=[2304,2304],frames=frames,records=rows,actual_minimum_guarded_Z=min(min(r['source_min_Z'],r['actual_raster_min_Z']) for r in rows),actual_114_parts_recompose_all6_full_RGBA_exact=True,all12_fixed_femur_tibia_length_residual=boneerr,whole_RIGHT_grip_staff_source_Gram_residual=gramerr,v05_original_pose_bone_parent_SO3_staff_controls_unchanged=True,v11_to_v13_genuine_owner_RGBA_transfer=ownerrows,runtime_death_seconds=.8,resource_role_seconds=.65,phase_seconds=.8/6,loop=False,terminal_held=True,terminal_support_hull=dict(declared_hidden_front_thickness=60,terminal_visible_back_plane_height=60,front_support_Z=0),limitations=['This verifies one authored finite material/depth/skeleton model. Hidden depth, foot yaw, body thickness, and supporting hull are declared choices, not unique measurements recovered from the bitmap.','Actual source appearance/fall/held-terminal judgement is separate and uses the immutable private-view ledger. No game, full actor, or approval-count assertion is made.','The ankle material is bounded by the complete enlarged finite ellipsoid, including all source/raster quad edges; it is not a claim that an invisible anatomical joint is uniquely known.'],actor_approvals_added=0,images_viewed=0,repository_changes=0,game_tests_run=0)
target=B/'NEdeath-v13-independent-exact114-source-raster-finite-floor-companion-v01.json';assert not target.exists();target.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(result=stamp(target),minimum=result['actual_minimum_guarded_Z'],records=len(rows),frames=len(frames))),flush=True)
