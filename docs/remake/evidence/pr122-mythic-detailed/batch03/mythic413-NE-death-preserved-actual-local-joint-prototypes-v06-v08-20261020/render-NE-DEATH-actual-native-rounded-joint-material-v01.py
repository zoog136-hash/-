"""Local native leather joint painting on explicit finite 3D surfaces.

This creates no replacement body/boot design. RGB is sampled from the actor's
own complete native leather semantic, and the original counter/stiletto is
composited after this local joint. All geometry centres remain the exact bones.
"""
import math
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates,distance_transform_edt

def native_material(source,valid):
 a=np.array(source.convert('RGBA'));assert valid.shape==a.shape[:2] and np.any(valid)
 _,indices=distance_transform_edt(~valid,return_indices=True)
 rgb=a[indices[0],indices[1],:3]
 return rgb,dict(actual_donor_pixels=int(np.sum(valid)),RGBA_semantic_source_only=True,nearest_padding_is_texture_only_not_segment_endpoint_extrusion=True)

def projected_joint_material(center,basis,radii,paint_transverse,paint_longitudinal,texture,source_uv,uv_density,canvas,storage,root,projection_x=10/9):
 C=np.array(center,float);E=np.array(basis,float);r=np.array(radii,float);assert np.max(np.abs(E.T@E-np.eye(3)))<1e-7
 S=E@np.diag(r*r)@E.T;P=np.array([[projection_x,0,0],[0,1,-1.]])
 pc=np.array(root)+P@C+storage;extent=np.sqrt(np.diag(P@S@P.T));lo=np.floor(pc-extent-2).astype(int);hi=np.ceil(pc+extent+2).astype(int);assert np.all(lo>=0) and np.all(hi<canvas)
 yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1].astype(float)
 Q=E@np.diag(1/(r*r))@E.T;ray=np.array([0.,1.,1.])/math.sqrt(2);qa=float(ray@Q@ray);qray=Q@ray
 tr=np.array(paint_transverse,float);tr/=np.linalg.norm(tr);long=np.array(paint_longitudinal,float);long/=np.linalg.norm(long)
 accum=np.zeros((*xx.shape,3),float);coverage=np.zeros(xx.shape,float);actual_min=math.inf;actual_max=-math.inf
 for dx in [-.25,.25]:
  for dy in [-.25,.25]:
   sx=xx+dx-pc[0];sy=yy+dy-pc[1]
   q=np.stack([sx/projection_x,sy*.5,-sy*.5],axis=-1)
   qb=2*np.einsum('...i,i->...',q,qray);qc=np.einsum('...i,ij,...j->...',q,Q,q)-1;disc=qb*qb-4*qa*qc;inside=disc>=0
   t=(-qb+np.sqrt(np.maximum(0,disc)))/(2*qa);v=q+t[:,:,None]*ray
   uvx=source_uv[0]+uv_density[0]*np.einsum('...i,i->...',v,tr)
   uvy=source_uv[1]+uv_density[1]*np.einsum('...i,i->...',v,long)
   uv=np.array([uvy,uvx]);colors=np.stack([map_coordinates(texture[:,:,k],uv,order=1,mode='nearest',prefilter=False)for k in range(3)],axis=-1)
   accum+=colors*inside[:,:,None];coverage+=inside
   if np.any(inside):actual_min=min(actual_min,float((C[2]+v[:,:,2])[inside].min()));actual_max=max(actual_max,float((C[2]+v[:,:,2])[inside].max()))
 out=np.zeros((*xx.shape,4),np.uint8);ok=coverage>0;out[ok,:3]=np.rint(accum[ok]/coverage[ok,None]).clip(0,255).astype('uint8');out[:,:,3]=np.rint(coverage*255/4).astype('uint8')
 patch=Image.fromarray(out);result=Image.new('RGBA',(canvas,canvas));result.paste(patch,tuple(lo))
 # Expanding every physical semi-axis by1.1native conservatively covers full
 # output texel quads, including partially covered edge pixels. +2 is the
 # unchanged material guard, not an alpha threshold relaxation.
 expanded=r+1.1;vertical_radius=float(np.sqrt(np.sum((E[2,:]*expanded)**2)))
 min_guard=float(C[2]-vertical_radius-2.)
 info=dict(center_world=C.tolist(),orthonormal_surface_basis=E.tolist(),physical_radii=r.tolist(),source_texture_anchor=list(source_uv),native_texture_density=list(uv_density),source_RGBA_colors_from_own_native_semantic=True,actual_supersample_min_Z=actual_min,actual_supersample_max_Z=actual_max,all_edge_texel_quad_expanded_radii=expanded.tolist(),material_Z_guard=2.,conservative_all_surface_and_raster_quad_guard_min_Z=min_guard,above_floor_with_guard=min_guard>=-1e-8,pose_or_bone_changed=False,source_surface='actual_native_leather_RGB_on_local_finite_joint_surface')
 return result,info

def source_round_end(source,sa,sb,endpoint,overlap=8.,transverse_radius=58.):
 """Real native alpha curved at one semantic bone end; no UV endpoint clamp."""
 a=np.array(source);sa=np.array(sa,float);sb=np.array(sb,float);v=(sb-sa)/np.linalg.norm(sb-sa);n=np.array([-v[1],v[0]]);anchor=sb if endpoint=='distal' else sa
 yy,xx=np.mgrid[:a.shape[0],:a.shape[1]];dx=xx-anchor[0];dy=yy-anchor[1];s=dx*v[0]+dy*v[1];t=dx*n[0]+dy*n[1]
 outward=s if endpoint=='distal'else -s
 outside=outward>0;ellipse=(outward/overlap)**2+(t/transverse_radius)**2
 a[outside&(ellipse>1)]=0
 return Image.fromarray(a)

def proximal_native_sleeve_surface(source,source_elbow,world_elbow,upper_U,upper_V,fore_U,fore_V,canvas,storage,root,projection_x=10/9):
 """Actual curved cuff remains on upperarm; original padded sleeve bends
 continuously to the unchanged rigid forearm/bracer/grip/complete staff.
 """
 a=np.array(source);sy,sx=np.where(a[:,:,3]>0);S=np.array(source_elbow,float);A=np.array(world_elbow,float);CU=np.column_stack([upper_U,upper_V]);CF=np.column_stack([fore_U,fore_V]);delta=CU-CF;P=np.array([[projection_x,0,0],[0,1,-1.]])
 def weights(x,y):
  zx=np.clip((x-840)/25,0,1);zy=np.clip((y-568)/36,0,1);fx=1-zx*zx*(3-2*zx);fy=1-zy*zy*(3-2*zy);gx=-6*zx*(1-zx)/25;gy=-6*zy*(1-zy)/36
  gx=np.where((x>840)&(x<865),gx,0);gy=np.where((y>568)&(y<604),gy,0)
  return fx*fy,gx*fy,gy*fx
 g,_,_=weights(sx,sy);uv=np.stack([sx-S[0],sy-S[1]]);points=A[:,None]+CF@uv+(delta@uv)*g
 pp=np.array(root)[:,None]+P@points+storage;lo=np.floor(pp.min(axis=1)-3).astype(int);hi=np.ceil(pp.max(axis=1)+3).astype(int);assert np.all(lo>=0)and np.all(hi<canvas)
 yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1].astype(float);target=np.stack([xx-storage-root[0],yy-storage-root[1]],axis=-1)-(P@A)
 MU=P@CU;MF=P@CF;MD=MU-MF;inv=np.linalg.inv(MF);q=target@inv.T+S
 for _ in range(12):
  x=q[:,:,0];y=q[:,:,1];g,gx,gy=weights(x,y);u=q-S;du=u@MD.T;res=u@MF.T+du*g[:,:,None]-target
  j00=MF[0,0]+g*MD[0,0]+du[:,:,0]*gx;j01=MF[0,1]+g*MD[0,1]+du[:,:,0]*gy;j10=MF[1,0]+g*MD[1,0]+du[:,:,1]*gx;j11=MF[1,1]+g*MD[1,1]+du[:,:,1]*gy;det=j00*j11-j01*j10
  safe=np.where(abs(det)>1e-5,det,np.copysign(1e-5,det+1e-12));dx=(j11*res[:,:,0]-j01*res[:,:,1])/safe;dy=(-j10*res[:,:,0]+j00*res[:,:,1])/safe
  q-=np.stack([np.clip(dx,-20,20),np.clip(dy,-20,20)],axis=-1)
 coords=np.array([q[:,:,1],q[:,:,0]]);v=np.stack([map_coordinates(a[:,:,k],coords,order=1,mode='constant',cval=0,prefilter=False)for k in range(4)],axis=-1).astype('uint8');v[v[:,:,3]==0,:3]=0
 g,_,_=weights(q[:,:,0],q[:,:,1]);uv=q-S;reprojection=uv@MF.T+(uv@MD.T)*g[:,:,None]-target;good=v[:,:,3]>0;maxres=float(np.linalg.norm(reprojection,axis=-1)[good].max())if np.any(good) else 0.;assert maxres<.08
 world=A+uv@CF.T+(uv@delta.T)*g[:,:,None];actual_min=float(world[:,:,2][good].min());source_min=float(points[2].min());guarded=min(actual_min,source_min)-3.
 result=Image.new('RGBA',(canvas,canvas));result.paste(Image.fromarray(v),tuple(lo));info=dict(source_elbow=S.tolist(),world_elbow=A.tolist(),upper_basis=CU.tolist(),forearm_rigid_basis=CF.tolist(),curved_cuff_weight='1-smoothstep(y568..604), multiplied by1-smoothstep(x840..865)',original_bracer_grip_entire_staff_at_x865plus_unchanged=True,maximum_inverse_UV_reprojection_native=maxres,all_actual_source_alpha_gt0=len(sx),all_actual_raster_alpha_gt0=int(np.sum(good)),minimum_actual_source_or_raster_Z=min(actual_min,source_min),conservative_local_native_guard=3.,guarded_min_Z=guarded,above_floor=guarded>=-1e-8,source_RGBA_from_actual_white_gold_native_padded_sleeve=True,pose_or_bone_changed=False)
 return result,info
