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
 c[:,:,:3]=np.divide(c[:,:,:3],c[:,:,3:4],out=np.zeros_like(c[:,:,:3]),where=np.abs(c[:,:,3:4])>1e-12)
 c=np.uint8(np.floor(np.clip(c,0.,1.)*255.+.5));c[c[:,:,3]==0,:3]=0;return c

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
