"""Authored 2D torso-turn attachments, driven by shared joint pose, not a separate clock.
Requires numpy/OpenCV/Pillow. No production/original resource is modified.
"""
from pathlib import Path
import json,hashlib
import numpy as np
import cv2
from PIL import Image,ImageDraw
R=Path(__file__).resolve().parents[2];folder=R/'assets/actors/shared_skin_pilot/girtas_267/torso_turn';W,H=427,495
skin=json.loads((R/'data/animation/girtas_shared_skin.json').read_text())['skin']
def rgba(path):return np.asarray(Image.open(path).convert('RGBA'),dtype=np.float32)/255
A=Image.open(R/skin['parts']['torso']['texture'].removeprefix('res://')).convert('RGBA');A.alpha_composite(Image.open(R/skin['parts']['shoulder_armor']['texture'].removeprefix('res://')).convert('RGBA'))
A=np.asarray(A,dtype=np.float32)/255
raw=Image.open(folder/'authored_source.png').convert('RGBA').resize((W,H),Image.Resampling.LANCZOS)
# Fixed neck/waist registration, not per-frame bounding-box normalization.
b=np.asarray(raw,dtype=np.float32)/255
M=np.float32([[1,-4/115,-7+120*4/115],[0,1,0]])
b=cv2.warpAffine(b,M,(W,H),flags=cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)
def poly(points):
 m=Image.new('L',(W,H));ImageDraw.Draw(m).polygon(points,fill=255);return np.asarray(m,dtype=np.float32)/255
core=poly([(188,134),(230,110),(280,109),(338,120),(357,153),(361,210),(346,246),(240,246),(235,214),(215,194),(190,183)])
# Preserve the original head, limbs, hand/weapon and pelvis outside this authoring region.
for k in ['head','upper_arm','forearm','far_arm','weapon_hand']:
 if k=='weapon_hand': continue # lower than torso partition
 b[:,:,3]*=1-poly(skin['parts'][k]['polygon'])
b[247:,:,3]=0
core=cv2.GaussianBlur(core,(5,5),0.8)
bPrem=b[:,:,:3]*b[:,:,3:4]
# Corresponding painted landmarks: identity anchors stay fixed; plate/shoulder planes change.
pa=np.float32([(0,0),(426,0),(426,494),(0,494),(0,246),(426,246),(150,80),(190,50),(250,80),(360,80),(400,150),(80,190),(140,240),(275,100),(325,100),(298,120),(320,125),(304,235),(250,235),(350,235),(214,135),(211,157),(193,175),(226,178),(275,175),(315,165),(351,195),(341,140),(270,200),(260,220),(350,210)])
# Preserve the number/identity of back spikes while authoring their perspective.
pa=np.vstack([pa,np.float32([(60,70),(125,25),(195,22),(230,65),(370,45),(390,70),(420,112)])])
pb=pa.copy();changes={6:(158,78),7:(198,52),31:(82,81),32:(143,38),33:(207,32),34:(238,70),35:(361,53),36:(378,79),37:(405,120),20:(208,133),21:(202,150),22:(185,170),23:(211,178),24:(286,175),25:(326,165),26:(341,195),27:(337,136),28:(258,200),29:(250,220),30:(345,210)}
for i,p in changes.items():pb[i]=p
sub=cv2.Subdiv2D((0,0,W,H))
for p in pa:sub.insert(tuple(map(float,p)))
tris=[]
for tr in sub.getTriangleList():
 pts=tr.reshape(3,2);ids=[int(np.argmin(np.linalg.norm(pa-v,axis=1))) for v in pts]
 if len(set(ids))==3 and all(np.linalg.norm(pa[j]-v)<.01 for j,v in zip(ids,pts)):tris.append(ids)
def warp(src,points,dest):
 out=np.zeros_like(src)
 for ids in tris:
  sp=points[ids];dp=dest[ids]
  # Reject a folding authoring mesh rather than hiding it with alpha blending.
  su=sp[1]-sp[0];sv=sp[2]-sp[0];du=dp[1]-dp[0];dv=dp[2]-dp[0];sa=su[0]*sv[1]-su[1]*sv[0];da=du[0]*dv[1]-du[1]*dv[0];assert sa*da>0, ids
  matrix=cv2.getAffineTransform(sp,dp);warped=cv2.warpAffine(src,matrix,(W,H),flags=cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)
  mask=np.zeros((H,W),np.uint8);cv2.fillConvexPoly(mask,np.round(dp).astype(np.int32),255)
  out[mask>0]=warped[mask>0]
 return out
def premul(v):return np.dstack([v[:,:,:3]*v[:,:,3:4],v[:,:,3]])
def sdf(a):
 mask=(a>.1).astype(np.uint8);return cv2.distanceTransform(mask,cv2.DIST_L2,3)-cv2.distanceTransform(1-mask,cv2.DIST_L2,3)
def save(v,path):
 v=np.clip(v,0,1);v[v[:,:,3]<.005,:3]=0;Image.fromarray(np.round(v*255).astype(np.uint8),'RGBA').save(path)
# The retained back armor uses registered original pixels at the authored depth pose.
# Its geometry, not the whole character or head, changes with chest orientation.
back=warp(premul(A),pa,pb)
alpha=back[:,:,3]*(1-core)+b[:,:,3]*core
prem=back[:,:,:3]*(1-core[:,:,None])+bPrem*core[:,:,None]
B=np.dstack([prem/np.maximum(alpha[:,:,None],1e-6),alpha])
Image.fromarray(np.round(np.clip(B,0,1)*255).astype(np.uint8),'RGBA').save(folder/'authored_key_torso.png')
guardA=poly(skin['parts']['shoulder_armor']['polygon']);guardB=warp(guardA,pa,pb)
frames=[]
for n in range(17):
 q=n/16;dest=pa*(1-q)+pb*q
 if n==0:
  frames.append({'q':q,'torso':skin['parts']['torso']['texture'],'shoulder_armor':skin['parts']['shoulder_armor']['texture'],'guard_pivot':[226,178],'near_offset':skin['rig']['shoulder_offset'],'far_offset':[(351-304)*skin['body_scale'],(195-235)*skin['body_scale']]});continue
 wa=warp(premul(A),pa,dest);wb=warp(premul(B),pb,dest)
 mix=wa*(1-q)+wb*q
 # One registered contour, not two ghosted silhouettes. Appearance blends only after geometric registration.
 distance=sdf(wa[:,:,3])*(1-q)+sdf(wb[:,:,3])*q
 alpha=np.clip(distance+.5,0,1)
 rgb=mix[:,:,:3]/np.maximum(mix[:,:,3:4],1e-6)
 full=np.dstack([rgb,alpha])
 ga=warp(guardA,pa,dest);gb=warp(guardB,pb,dest);g=np.clip(ga*(1-q)+gb*q,0,1)
 guard=full.copy();guard[:,:,3]*=g
 torso=full.copy();torso[:,:,3]*=1-g
 # Copied armor backing is authoring, confined to the detached joint.
 px=int(round(229-15*q));patch=A[190:210,290:306].copy();target=torso[161:181,px:px+16];am=patch[:,:,3:4]*g[161:181,px:px+16,None];target[:,:,:3]=patch[:,:,:3]*am+target[:,:,:3]*(1-am);target[:,:,3]=np.maximum(target[:,:,3],am[:,:,0])
 tp=folder/f'torso_{n:02}.png';gp=folder/f'pauldron_{n:02}.png';save(torso,tp);save(guard,gp)
 near=[226-15*q,178];far=[351-10*q,195]
 frames.append({'q':q,'torso':'res://'+str(tp.relative_to(R)),'shoulder_armor':'res://'+str(gp.relative_to(R)),'guard_pivot':near,'near_offset':[(near[0]-304)*skin['body_scale'],(near[1]-235)*skin['body_scale']],'far_offset':[(far[0]-304)*skin['body_scale'],(far[1]-235)*skin['body_scale']]})
for f in frames:
 for k in ['torso','shoulder_armor']:f[k+'_sha256']=hashlib.sha256((R/f[k].removeprefix('res://')).read_bytes()).hexdigest()
meta={'schema':1,'direction':'E','scope':'authored chest/pauldron pose attachments; original head/limbs/weapon/pelvis retained; no independent animation clock','authored_source_sha256':hashlib.sha256((folder/'authored_source.png').read_bytes()).hexdigest(),'original_source_sha256':skin['source_sha256'],'method':'two registered painted key appearances; correspondence-triangle 2D morph with single signed-distance contour; new authoring, not recovered original motion','core_polygon':[(188,134),(230,110),(280,109),(338,120),(357,153),(361,210),(346,246),(240,246),(235,214),(215,194),(190,183)],'landmarks_a':pa.tolist(),'landmarks_b':pb.tolist(),'frames':frames}
(R/'data/animation/girtas_torso_turns.json').write_text(json.dumps(meta,indent=2)+'\n')
print('Authored torso pose pack:',len(frames),'states; original attachments at q=0')
