from pathlib import Path
import numpy as np, math, hashlib, json
from PIL import Image
from scipy.ndimage import map_coordinates
from scipy.spatial import cKDTree

# Full floating-point, four-channel premultiplied source sampling. Clamp only
# after unpremultiplication, including bicubic overshoot at original AA rims.
def pin(p):
 p=Path(p);return dict(path=str(p),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest())
def sample(im,x,y):
 a=np.asarray(im).astype(np.float64)/255.;a[:,:,:3]*=a[:,:,3:4]
 c=np.stack([map_coordinates(a[:,:,k],[y,x],order=1,mode='constant',cval=0,prefilter=False)for k in range(4)],-1)
 c[...,:3]=np.divide(c[...,:3],c[...,3:4],out=np.zeros_like(c[...,:3]),where=np.abs(c[...,3:4])>1e-12)
 c=np.uint8(np.floor(np.clip(c,0.,1.)*255.+.5));c[c[...,3]==0,:3]=0;return c

def render_surface(im,world,root,projection,canvas,pad):
 a=np.asarray(im);sy,sx=np.where(a[:,:,3]>0);assert len(sx)
 source_lo=np.array([sx.min(),sy.min()]);source_hi=np.array([sx.max(),sy.max()])
 # Native material is densely mapped before any output crop. A regular source
 # seed grid is only an inverse-solver accelerator; final UV is continuous.
 gy,gx=np.meshgrid(np.arange(source_lo[1]-1,source_hi[1]+3,3.),np.arange(source_lo[0]-1,source_hi[0]+3,3.),indexing='ij')
 uv=np.column_stack([gx.ravel(),gy.ravel()]);xyz=world(uv);screen=np.array(root)+xyz@np.array(projection).T+pad
 lo=np.floor(screen.min(0)-5).astype(int);hi=np.ceil(screen.max(0)+5).astype(int);assert np.all(lo>=0)and np.all(hi<canvas),(lo,hi)
 yy,xx=np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1];target=np.column_stack([xx.ravel(),yy.ravel()]);_,ids=cKDTree(screen).query(target);sol=uv[ids].copy()
 for _ in range(13):
  val=np.array(root)+world(sol)@np.array(projection).T+pad
  jx=(world(sol+[.05,0])-world(sol-[.05,0]))@np.array(projection).T/.1
  jy=(world(sol+[0,.05])-world(sol-[0,.05]))@np.array(projection).T/.1
  delta=target-val;det=jx[:,0]*jy[:,1]-jx[:,1]*jy[:,0];ok=np.abs(det)>1e-7
  dx=np.divide(delta[:,0]*jy[:,1]-delta[:,1]*jy[:,0],det,out=np.zeros(len(det)),where=ok)
  dy=np.divide(jx[:,0]*delta[:,1]-jx[:,1]*delta[:,0],det,out=np.zeros(len(det)),where=ok)
  sol+=np.clip(np.column_stack([dx,dy]),-15,15)
 xyz=world(sol);res=np.linalg.norm(np.array(root)+xyz@np.array(projection).T+pad-target,axis=1)
 c=sample(im,sol[:,0],sol[:,1]);c[res>.7]=0
 out=Image.new('RGBA',(canvas,canvas));out.paste(Image.fromarray(c.reshape(xx.shape+(4,))),tuple(lo))
 keep=c[:,3]>0
 return out,dict(original_source_texels=int(len(sx)),output_texels=int(keep.sum()),inverse_max_residual=float(res[keep].max())if keep.any()else 0.,source_bbox=[*source_lo.tolist(),*source_hi.tolist()],stored_bbox=[*lo.tolist(),*hi.tolist()],premultiplied_float_4channel=True,final_clamp_after_unpremultiply=True,original_source_RGBA_recolored=False,hidden_surface_min_sampled_Z=float(xyz[keep,2].min())if keep.any()else None)

def planar(im,source_anchor,anchor,basis,root,projection,canvas,pad):
 source_anchor=np.asarray(source_anchor);anchor=np.asarray(anchor);basis=np.asarray(basis)
 return render_surface(im,lambda uv:anchor+(uv-source_anchor)@basis.T,root,projection,canvas,pad)

def bone_basis(source_a,source_b,a,b,projection):
 source_a=np.asarray(source_a);source_b=np.asarray(source_b);a=np.asarray(a);b=np.asarray(b);sv=source_b-source_a;sl=np.linalg.norm(sv);sn=np.array([-sv[1],sv[0]])/sl;bv=b-a;pv=np.asarray(projection)@bv;tn=np.array([-pv[1],pv[0]])/np.linalg.norm(pv);W=np.linalg.pinv(projection)@tn
 return np.outer(bv,sv)/(sl*sl)+np.outer(W,sn)

def fixed_knee(hip,ankle,length,side):
 hip=np.asarray(hip);ankle=np.asarray(ankle);d=ankle-hip;distance=np.linalg.norm(d);assert 0<distance<2*length,(side,distance)
 axis=d/distance;preferred=np.array([-.18 if side=='R'else .18,1.,.16]);preferred-=axis*np.dot(preferred,axis);preferred/=np.linalg.norm(preferred)
 k=(hip+ankle)/2+math.sqrt(length*length-distance*distance/4)*preferred
 assert abs(np.linalg.norm(k-hip)-length)<1e-7 and abs(np.linalg.norm(ankle-k)-length)<1e-7
 return k

def continuous_chain_world(anchors,bases,transitions):
 # Each parent/child surface agrees at its structural joint. Complete source
 # alpha and original leather/gold/skin are sampled once through smooth UV.
 def world(uv):
  uv=np.asarray(uv);result=anchors[0][1]+(uv-anchors[0][0])@bases[0].T
  for i,(lo,hi) in enumerate(transitions):
   t=np.clip((uv[:,1]-lo)/(hi-lo),0,1);g=t*t*(3-2*t)
   target=anchors[i+1][1]+(uv-anchors[i+1][0])@bases[i+1].T
   result=result*(1-g[:,None])+target*g[:,None]
  return result
 return world

def raster_surface(im,world,root,projection,canvas,pad):
 a=np.asarray(im);sy,sx=np.where(a[:,:,3]>0);x0=max(0,int(sx.min())-1);x1=min(a.shape[1]-1,int(sx.max())+1);y0=max(0,int(sy.min())-1);y1=min(a.shape[0]-1,int(sy.max())+1)
 xs=np.unique(np.r_[np.arange(x0,x1,3.),x1]);ys=np.unique(np.r_[np.arange(y0,y1,3.),y1]);yy,xx=np.meshgrid(ys,xs,indexing='ij');uv=np.stack([xx,yy],-1);xyz=world(uv.reshape(-1,2)).reshape(xx.shape+(3,));screen=np.asarray(root)+xyz@np.asarray(projection).T+pad
 lo=np.floor(screen.min((0,1))-3).astype(int);hi=np.ceil(screen.max((0,1))+3).astype(int);assert np.all(lo>=0)and np.all(hi<canvas)
 hh,ww=(hi-lo+1)[::-1];out=np.zeros((hh,ww,4),np.uint8);depth=np.full((hh,ww),-np.inf)
 pm=a.astype(float)/255.;pm[:,:,:3]*=pm[:,:,3:4];used=0;zmin=math.inf
 for iy in range(len(ys)-1):
  for ix in range(len(xs)-1):
   if not a[max(0,int(ys[iy])-1):min(a.shape[0],int(ys[iy+1])+2),max(0,int(xs[ix])-1):min(a.shape[1],int(xs[ix+1])+2),3].any():continue
   for ids in [[(iy,ix),(iy,ix+1),(iy+1,ix+1)],[(iy,ix),(iy+1,ix+1),(iy+1,ix)]]:
    q=np.array([screen[i,j]-lo for i,j in ids]);u=np.array([uv[i,j]for i,j in ids]);w=np.array([xyz[i,j]for i,j in ids]);T=np.column_stack([q[1]-q[0],q[2]-q[0]])
    if abs(np.linalg.det(T))<1e-9:continue
    ll=np.maximum(0,np.floor(q.min(0)-.5).astype(int));hh2=np.minimum([ww-1,hh-1],np.ceil(q.max(0)+.5).astype(int));gy,gx=np.mgrid[ll[1]:hh2[1]+1,ll[0]:hh2[0]+1];v=np.stack([gx-q[0,0],gy-q[0,1]],-1)@np.linalg.inv(T).T;bc=np.concatenate([1-v.sum(-1,keepdims=True),v],-1);inside=bc.min(-1)>=-.02;z=bc@w;d=z[:,:,1]+z[:,:,2];tu=bc@u
    c=np.stack([map_coordinates(pm[:,:,k],[tu[:,:,1],tu[:,:,0]],order=1,mode='constant',cval=0,prefilter=False)for k in range(4)],-1);c[:,:,:3]=np.divide(c[:,:,:3],c[:,:,3:4],out=np.zeros_like(c[:,:,:3]),where=c[:,:,3:4]>1e-12);c=np.uint8(np.floor(np.clip(c,0.,1.)*255.+.5));c[c[:,:,3]==0,:3]=0
    dst=out[ll[1]:hh2[1]+1,ll[0]:hh2[0]+1];dd=depth[ll[1]:hh2[1]+1,ll[0]:hh2[0]+1];choose=inside&(c[:,:,3]>0)&(d>=dd);dst[choose]=c[choose];dd[choose]=d[choose];used+=int(choose.sum())
    if choose.any():zmin=min(zmin,float(z[:,:,2][choose].min()))
 out[out[:,:,3]==0,:3]=0;result=Image.new('RGBA',(canvas,canvas));result.paste(Image.fromarray(out),tuple(lo))
 return result,dict(original_source_texels=int(len(sx)),output_texels=int((out[:,:,3]>0).sum()),source_bbox=[x0,y0,x1,y1],stored_bbox=[*lo.tolist(),*hi.tolist()],premultiplied_float_4channel=True,final_clamp_after_unpremultiply=True,original_source_RGBA_recolored=False,hidden_surface_min_sampled_Z=zmin,visible_overlap_camera_depth='selected maximum Y+Z of actual source UV triangles')

def fixed_knee_front(hip,ankle,length,side,kind,rootY):
 hip=np.asarray(hip);ankle=np.asarray(ankle);x=(hip[0]+ankle[0])/2;r1=math.sqrt(length**2-(x-hip[0])**2);r2=math.sqrt(length**2-(ankle[0]-x)**2);dv=ankle[1:]-hip[1:];distance=np.linalg.norm(dv);assert abs(r1-r2)<distance<r1+r2
 unit=dv/distance;along=(r1*r1-r2*r2+distance*distance)/(2*distance);center=hip[1:]+along*unit;height=math.sqrt(max(0.,r1*r1-along*along));normal=np.array([-unit[1],unit[0]]);cs=[np.array([x,*(center+s*height*normal)])for s in [-1,1]]
 if kind=='recovery':k=max(cs,key=lambda v:v[1]-v[2])
 elif kind=='drive':k=min(cs,key=lambda v:v[1]-v[2])
 else:k=min(cs,key=lambda v:abs(rootY+v[1]-v[2]-820))
 assert max(abs(np.linalg.norm(k-hip)-length),abs(np.linalg.norm(ankle-k)-length))<1e-7;return k
