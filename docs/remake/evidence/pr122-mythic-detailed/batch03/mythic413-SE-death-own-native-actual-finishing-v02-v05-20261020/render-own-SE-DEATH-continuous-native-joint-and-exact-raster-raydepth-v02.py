import math
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates

def native_joint_strip(source, source_anchor, world_anchor, from_basis, to_basis, blend_range, canvas, storage, root, projection_x=10/9, return_depth=False):
    """The original knee strip bends between its two existing bone surfaces.

    Actual source leather and filigree are retained. There is no invented
    disk, color fill, endpoint extrusion, or whole-boot rotation.
    """
    a=np.array(source);K=np.array(world_anchor,float);S=np.array(source_anchor,float);MT=np.array(from_basis,float);MC=np.array(to_basis,float);b0,b1=map(float,blend_range);bw=b1-b0;assert bw>0
    root=np.array(root,float);P=np.array([[projection_x,0,0],[0,1,-1.]])
    def world(x,y):
        t=np.clip((y-b0)/bw,0,1);g=t*t*(3-2*t);uv=np.stack([x-S[0],y-S[1]],axis=-1)
        return K+np.einsum('ij,...j->...i',MT,uv)*(1-g[...,None])+np.einsum('ij,...j->...i',MC,uv)*g[...,None]
    sy,sx=np.where(a[:,:,3]>0);assert len(sx)>0
    x0=max(0,int(sx.min())-1);x1=min(a.shape[1]-1,int(sx.max())+1);y0=max(0,int(sy.min())-1);y1=min(a.shape[0]-1,int(sy.max())+1)
    xs=np.unique(np.r_[np.arange(x0,x1,1.5),x1]);ys=np.unique(np.r_[np.arange(y0,y1,1.5),y1]);yy,xx=np.meshgrid(ys,xs,indexing='ij');uv=np.stack([xx,yy],axis=-1);xyz=world(xx,yy);screen=root+np.einsum('ij,...j->...i',P,xyz)+storage
    lo=np.floor(screen.min(axis=(0,1))-2).astype(int);hi=np.ceil(screen.max(axis=(0,1))+2).astype(int);assert np.all(lo>=0)and np.all(hi<canvas)
    hh,ww=(hi-lo+1)[::-1];out=np.zeros((hh,ww,4),np.uint8);depth=np.full((hh,ww),-np.inf);quad_floor=np.full((hh,ww),np.inf)
    for iy in range(len(ys)-1):
        for ix in range(len(xs)-1):
            for ids in [[(iy,ix),(iy,ix+1),(iy+1,ix+1)],[(iy,ix),(iy+1,ix+1),(iy+1,ix)]]:
                q=np.array([screen[i,j]-lo for i,j in ids]);u=np.array([uv[i,j]for i,j in ids]);w=np.array([xyz[i,j]for i,j in ids]);T=np.column_stack([q[1]-q[0],q[2]-q[0]])
                if abs(np.linalg.det(T))<1e-8:continue
                ll=np.maximum(0,np.floor(q.min(axis=0)-.5).astype(int));hh2=np.minimum([ww-1,hh-1],np.ceil(q.max(axis=0)+.5).astype(int))
                gy,gx=np.mgrid[ll[1]:hh2[1]+1,ll[0]:hh2[0]+1];v=np.stack([gx-q[0,0],gy-q[0,1]],axis=-1)@np.linalg.inv(T).T;bc=np.concatenate([1-v.sum(axis=-1,keepdims=True),v],axis=-1);inside=np.min(bc,axis=-1)>=-.035
                z=np.einsum('...i,ij->...j',bc,w);d=z[:,:,1]+z[:,:,2];tu=np.einsum('...i,ij->...j',bc,u);c=np.stack([map_coordinates(a[:,:,k],[tu[:,:,1],tu[:,:,0]],order=1,mode='constant',cval=0,prefilter=False)for k in range(4)],axis=-1).astype('uint8');dst=out[ll[1]:hh2[1]+1,ll[0]:hh2[0]+1];dd=depth[ll[1]:hh2[1]+1,ll[0]:hh2[0]+1];qq=quad_floor[ll[1]:hh2[1]+1,ll[0]:hh2[0]+1];choose=inside&(c[:,:,3]>0)&(d>=dd);grad=(w[1:,2]-w[0,2])@np.linalg.inv(T);qmin=z[:,:,2]-.5*np.abs(grad).sum();dst[choose]=c[choose];dd[choose]=d[choose];qq[choose]=qmin[choose]
    out[out[:,:,3]==0,:3]=0;result=Image.new('RGBA',(canvas,canvas));result.paste(Image.fromarray(out),tuple(lo))
    # Native source texel quads are evaluated in the same continuous map.
    # The interval uses both endpoints and extrema of the cubic blend.
    mins=[]
    for dx in [-.5,.5]:
        for dy in [-.5,.5]:mins.append(float(world(sx+dx,sy+dy)[:,2].min()))
    # A fixed-x Z is quartic through the cubic blend. Its exact stationary
    # roots on the strip bound the entire source rectangle, including quads.
    continuous_min=math.inf
    for x in [float(sx.min())-.5,float(sx.max())+.5]:
        yp=np.polynomial.Polynomial([b0,bw]);gp=np.polynomial.Polynomial([0.,0.,3.,-2.]);base=K[2]+MT[2,0]*(x-S[0])+MT[2,1]*(yp-S[1]);delta=(MC[2,0]-MT[2,0])*(x-S[0])+(MC[2,1]-MT[2,1])*(yp-S[1]);poly=base+gp*delta
        points=[float(sy.min())-.5,float(sy.max())+.5,b0,b1]
        points += [b0+bw*r.real for r in poly.deriv().roots()if abs(r.imag)<1e-8 and 0<=r.real<=1]
        valid=[y for y in points if sy.min()-.5<=y<=sy.max()+.5]
        continuous_min=min(continuous_min,float(world(np.full(len(valid),x),np.array(valid))[:,2].min()))
    grid_min=float(xyz[:,:,2].min());raster_min=float(quad_floor[out[:,:,3]>0].min());guard=3.;minimum=min(mins+[continuous_min,raster_min])-guard
    meta=dict(kind='ORIGINAL_ACTUAL_NATIVE_JOINT_STRIP_CONTINUOUS_UV_BETWEEN_FIXED_PARENT_SURFACES',original_native_source_bbox=[x0,y0,x1,y1],source_anchor=S.tolist(),source_blend_y=[b0,b1],original_native_RGBA_recolored=False,large_spherical_cap=False,source_alpha_gt0_texels=int(len(sx)),raster_alpha_gt0_texels=int((out[:,:,3]>0).sum()),source_quad_min_Z=min(mins),complete_continuous_surface_quartic_min_Z=continuous_min,complete_sampled_surface_min_Z=grid_min,raster_texel_quad_min_Z=raster_min,conservative_surface_and_raster_guard=guard,guarded_min_Z=minimum,above_floor=minimum>=0,world_anchor=K.tolist(),original_parent_bones_unchanged=True,source_femur_world_UV=MT.tolist(),source_calf_world_UV=MC.tolist(),limits=['One fixed native UV skinning surface, using original alpha and original leather/gold pixels only.','The same source strip continuously blends the two existing fixed-bone surfaces; natural folded inner space stays outside its original alpha.','All native source texel quads and the continuous quartic source rectangle are bounded. Every painted output texel quad uses its actual selected mesh triangle Z gradient plus 3-native material guard.'])
    if return_depth: return result,meta,dict(lo=lo,depth=depth)
    return result,meta
