from pathlib import Path
from PIL import Image,ImageDraw
from scipy.sparse import lil_matrix
from scipy.sparse.linalg import spsolve
import numpy as np,json,hashlib
B=Path(__file__).parent;V=B/'actual-own-E-ATTACK-native-complete-materials-v04';D=B/'actual-own-E-ATTACK-native-local-cape-boundary-finish-v05';D.mkdir(exist_ok=False);P=V/'E-ATTACK-own-complete-native-parts-and-actual-local-cape-provenance-v04.json';j=json.loads(P.read_text());core0=np.array(Image.open(j['body_inputs']['attack-final-CORE-actual-local-cape-retouch']['body']['path']).convert('RGBA'));guide=np.array(Image.open(j['actual_local_cape_retouch']['local_native_paint']['path']).convert('RGBA')).astype(float)/255;target=core0[770:1020,260:510].astype(float)/255;mask=np.array(Image.open('/workspace/scratch/mythic413-E-attack-author-20261020-v01/E-cape-native-pole-occlusion-local-retouch-handoff-v01/replace-only-original-pole-occluded-real-cape-native-mask-250.png'))>0
# New actual service fabric is the material. One exact sparse Poisson colour/
# alpha finish joins its native painted gradients to the protected old cape;
# outside-mask original pixels, actor density/root and every rig node stay fixed.
g=guide.copy();g[:,:,:3]*=g[:,:,3,None];t=target.copy();t[:,:,:3]*=t[:,:,3,None];ys,xs=np.where(mask);N=len(xs);idx=np.full(mask.shape,-1,int);idx[ys,xs]=np.arange(N);A=lil_matrix((N,N));rhs=np.zeros((N,4))
for k,(y,x)in enumerate(zip(ys,xs)):
 A[k,k]=4;rhs[k]=4*g[y,x]
 for dy,dx in [(-1,0),(1,0),(0,-1),(0,1)]:
  ny,nx=y+dy,x+dx;rhs[k]-=g[ny,nx]
  if mask[ny,nx]:A[k,idx[ny,nx]]=-1
  else:rhs[k]+=t[ny,nx]
sol=spsolve(A.tocsc(),rhs);sol[:,3]=np.clip(sol[:,3],0,1);sol[:,:3]=np.clip(sol[:,:3],0,sol[:,3,None]);out=target.copy();out[ys,xs,3]=sol[:,3];out[ys,xs,:3]=np.divide(sol[:,:3],sol[:,3,None],out=np.zeros_like(sol[:,:3]),where=sol[:,3,None]>1e-8);out=np.uint8(np.clip(out*255+.5,0,255));core=core0.copy();core[770:1020,260:510]=out;fullmask=np.zeros(core.shape[:2],bool);fullmask[770:1020,260:510]=mask;assert not np.any(core[~fullmask]!=core0[~fullmask]);cp=D/'actual-E-complete-body-fixed-boots-and-new-cape-native-boundary-finished-v05.png';Image.fromarray(core).save(cp);pp=D/'actual-new-E-cape-native-250-source-painted-boundary-finished-v05.png';Image.fromarray(out).save(pp)
def pin(p):p=Path(p);r=p.read_bytes();return {'path':str(p),'sha256':hashlib.sha256(r).hexdigest(),'bytes':len(r)}
j['body_inputs']['attack-final-CORE-actual-local-cape-retouch']['body']=pin(cp);j['actual_local_cape_retouch']['native_boundary_finish']={'actual_new_service_paint_input':j['actual_local_cape_retouch']['local_native_paint'],'native_finished_crop':pin(pp),'method':'One finite sparse Poisson solve of new actual premultiplied RGBA fabric gradients, Dirichlet original visible cape boundary. No old pole colours or code-only failed fabric guide used.','unknown_native_pixels':N,'outside_original_CORE_replacement_mask_RGBA_difference':0,'source_C_root_unit_or_rig_or_boot_RGBA_changed':False};j['prior_native_materials']=pin(P);p=D/'E-ATTACK-own-complete-native-parts-and-actual-local-cape-provenance-v05.json';p.write_text(json.dumps(j,indent=2)+'\n');im=Image.new('RGB',(1040,540),(72,72,75));dr=ImageDraw.Draw(im)
for k,(name,a)in enumerate([('ACTUAL PAINT RAW MASK COMPOSITE',core0),('NEW ACTUAL PAINT NATIVE BOUNDARY FINISH',core)]):
 q=Image.fromarray(a).crop((260,770,510,1020)).resize((500,500));im.paste(q,(k*520,30),q);dr.text((k*520+4,5),name,fill='white')
im.save(D/'private-E-actual-new-cloth-native-boundary-finish-before-after-v05.jpg',quality=86);print(json.dumps({'materials':pin(p),'local_native_pixels':N,'outside_mask_RGBA_difference':0,'full_actor_or_rig_transforms_added':0}))
