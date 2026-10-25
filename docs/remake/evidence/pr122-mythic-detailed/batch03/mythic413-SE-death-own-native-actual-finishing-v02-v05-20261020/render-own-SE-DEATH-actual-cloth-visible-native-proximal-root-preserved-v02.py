import math
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates

def root_bound_cloth(source, source_root, world_root, pelvis_native_anchor,
                     pelvis_world, pelvis_U, pelvis_V, transverse, angle,
                     canvas, storage, root, projection_x=10/9):
    a=np.array(source);S=np.array(source_root,float);A=np.array(world_root,float)
    HP=np.array(pelvis_world,float);SP=np.array(pelvis_native_anchor,float)
    U=np.array(pelvis_U,float);V=np.array(pelvis_V,float);T=np.array(transverse,float)
    theta=math.radians(angle);co=math.cos(theta);si=math.sin(theta)
    P=np.array([[projection_x,0,0],[0,1,-1.]])
    def world(x,y):
        u=x-S[0];length=y-S[1];baseZ=A[2]+T[2]*u
        hit=np.maximum(0.,(baseZ-10.)/max(co,1e-9));air=np.minimum(length,hit)
        travel=si*air+np.maximum(0.,length-hit);dx=-math.cos(math.radians(25.));dy=math.sin(math.radians(25.))
        q=np.stack([A[0]+T[0]*u+dx*travel,A[1]+T[1]*u+dy*travel,np.maximum(10.,baseZ-co*length)],axis=-1)
        body=HP+(x-SP[0])[...,None]*U+(y-SP[1])[...,None]*V
        t=np.clip((y-720.)/100.,0,1);g=t*t*(3-2*t)
        return body*(1-g[...,None])+q*g[...,None]
    sy,sx=np.where(a[:,:,3]>0);x0=max(0,int(sx.min())-1);x1=min(a.shape[1]-1,int(sx.max())+1)
    y0=max(0,int(sy.min())-1);y1=min(a.shape[0]-1,int(sy.max())+1)
    xs=np.unique(np.r_[np.arange(x0,x1,4.),x1]);ys=np.unique(np.r_[np.arange(y0,y1,4.),y1])
    yy,xx=np.meshgrid(ys,xs,indexing='ij');uv=np.stack([xx,yy],axis=-1);xyz=world(xx,yy)
    screen=np.array(root)+np.einsum('ij,...j->...i',P,xyz)+storage
    lo=np.floor(screen.min(axis=(0,1))-2).astype(int);hi=np.ceil(screen.max(axis=(0,1))+2).astype(int)
    assert np.all(lo>=0)and np.all(hi<canvas)
    hh,ww=(hi-lo+1)[::-1];out=np.zeros((hh,ww,4),np.uint8)
    depth=np.full((hh,ww),-np.inf);quad_floor=np.full((hh,ww),np.inf)
    for iy in range(len(ys)-1):
        for ix in range(len(xs)-1):
            bx0=max(0,int(xs[ix])-1);by0=max(0,int(ys[iy])-1)
            bx1=min(a.shape[1],int(math.ceil(xs[ix+1]))+2);by1=min(a.shape[0],int(math.ceil(ys[iy+1]))+2)
            if not np.any(a[by0:by1,bx0:bx1,3]):continue
            for ids in [[(iy,ix),(iy,ix+1),(iy+1,ix+1)],[(iy,ix),(iy+1,ix+1),(iy+1,ix)]]:
                q=np.array([screen[i,j]-lo for i,j in ids]);u=np.array([uv[i,j]for i,j in ids]);w=np.array([xyz[i,j]for i,j in ids])
                M=np.column_stack([q[1]-q[0],q[2]-q[0]])
                if abs(np.linalg.det(M))<1e-8:continue
                iv=np.linalg.inv(M);ll=np.maximum(0,np.floor(q.min(axis=0)-.5).astype(int));hh2=np.minimum([ww-1,hh-1],np.ceil(q.max(axis=0)+.5).astype(int))
                gy,gx=np.mgrid[ll[1]:hh2[1]+1,ll[0]:hh2[0]+1];v=np.stack([gx-q[0,0],gy-q[0,1]],axis=-1)@iv.T
                bc=np.concatenate([1-v.sum(axis=-1,keepdims=True),v],axis=-1);inside=np.min(bc,axis=-1)>=-.035
                wp=np.einsum('...i,ij->...j',bc,w);d=wp[:,:,1]+wp[:,:,2];tu=np.einsum('...i,ij->...j',bc,u)
                color=np.stack([map_coordinates(a[:,:,k],[tu[:,:,1],tu[:,:,0]],order=1,mode='constant',cval=0,prefilter=False)for k in range(4)],axis=-1).astype('uint8')
                dst=out[ll[1]:hh2[1]+1,ll[0]:hh2[0]+1];dd=depth[ll[1]:hh2[1]+1,ll[0]:hh2[0]+1];qq=quad_floor[ll[1]:hh2[1]+1,ll[0]:hh2[0]+1]
                choose=inside&(color[:,:,3]>0)&(d>=dd);grad=(w[1:,2]-w[0,2])@iv
                dst[choose]=color[choose];dd[choose]=d[choose];qq[choose]=(wp[:,:,2]-.5*abs(grad).sum())[choose]
    out[out[:,:,3]==0,:3]=0;result=Image.new('RGBA',(canvas,canvas));result.paste(Image.fromarray(out),tuple(lo))
    # On y<=820 the pelvis plane bounds the proximal attachment. Beyond
    # that source coordinate the exact drape is bounded by its Z10 branch.
    bx=np.array([sx.min()-.5,sx.max()+.5]);by=np.array([sy.min()-.5,min(820.,sy.max()+.5)])
    plane_bound=min(float((HP+(x-SP[0])*U+(y-SP[1])*V)[2])for x in bx for y in by)
    source_min=min(10.,plane_bound);corners=[]
    for dx in [-.5,.5]:
        for dy in [-.5,.5]:corners.append(float(world(sx+dx,sy+dy)[:,2].min()))
    rmin=float(quad_floor[out[:,:,3]>0].min());guard=3.;minimum=min(source_min,min(corners),rmin)-guard
    info=dict(kind='ACTUAL_COMPLETE_ORIGINAL_CAPE_CONTINUOUS_PELVIS_ROOT_TO_LAGGING_ARCLENGTH_FLOOR_SURFACE',source_root=S.tolist(),world_root=A.tolist(),pelvis_native_anchor=SP.tolist(),pelvis_world=HP.tolist(),pelvis_U=U.tolist(),pelvis_V=V.tolist(),transverse=T.tolist(),longitudinal_angle=angle,source_proximal_blend_y=[720.,820.],floor_Z=10.,source_complete_surface_min_Z=source_min,source_all_quad_corner_min_Z=min(corners),raster_all_texel_quad_min_Z=rmin,guard_native=guard,guarded_min_Z=minimum,above_floor=minimum>=0,actual_source_alpha_gt0_texels=len(sx),actual_raster_alpha_gt0_texels=int((out[:,:,3]>0).sum()),source_RGBA_recolored=False,source_proximal_to_y720_exact_pelvis_surface=True,limits=['Original complete native cape material only, no artificial bridges.','The original proximal cloth follows the true pelvis surface then continuously relaxes to the dedicated trailing cloth/floor field.','One fixed arclength drape model after the proximal cloth transition, not a unique hidden3D reconstruction.'])
    return result,info
