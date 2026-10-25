from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import label,binary_dilation,map_coordinates
import numpy as np,json,hashlib,math
B=Path(__file__).parent;V=B/'actual-NE-ATTACK6-native-rig-v03';U=B/'actual-NE-ATTACK6-upper-chain-input-v02';D=B/'actual-NE-ATTACK6-native-rig-v04';D.mkdir(exist_ok=False);P=V/'NE-ATTACK6-actual-complete-native-fixed-sole-weightshift-contract-v03.json';j=json.loads(P.read_text());W=H=1536;yy,xx=np.indices((H,W));PIV=np.array([716.2291666666666,705.]);src=np.zeros((H,W,4),np.uint8);src[:1254,:1254]=np.array(Image.open('/workspace/scratch/mythic413-NE-walk-author-20261020-v01/NE-contact0-actual-native-background-AA-clean-r002.png').convert('RGBA'));l=np.array(Image.open(V/'original-actual-LEFT-visible-calf-and-boot-native-INPUT.png'));cc,n=label(l[:,:,3]>100);ids=[]
for z in range(1,n+1):
 y,x=np.where(cc==z)
 if len(x)==118 and [int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]==[531,916,554,926]:ids.append(z)
assert len(ids)==1;mask=binary_dilation(np.isin(cc,ids),iterations=2)&(l[:,:,3]>0);assert not np.any(src[mask]!=l[mask]);core0=np.array(Image.open(B/'own-native-directional-materials-v04/actual-native-NE-head-torso-coat-old-arms-staff-removed-INPUT.png'));core=core0.copy();core[mask]=src[mask];lnew=l.copy();lnew[mask]=0
cp=D/'actual-native-body-core-original-coat-goldtrim-restored.png';lp=D/'original-actual-LEFT-calf-foreign-coat-goldtrim-excluded-INPUT.png';mp=D/'actual-native-coat-goldtrim-semantic-transfer-mask.png';Image.fromarray(core).save(cp);Image.fromarray(lnew).save(lp);Image.fromarray(mask.astype('uint8')*255).save(mp)
def pin(p):r=Path(p).read_bytes();return {'path':str(p),'sha256':hashlib.sha256(r).hexdigest(),'bytes':len(r)}
def aff(im,A,t):v=np.linalg.inv(A);q=-v@np.asarray(t);return im.transform((W,H),Image.Transform.AFFINE,tuple(v[0])+(q[0],)+tuple(v[1])+(q[1],),Image.Resampling.BICUBIC)
def field(a,delta):
 az=a.astype(float)/255;aa=az[:,:,3];sx=xx.astype(float);sy=yy.astype(float)
 for _ in range(16):
  dx=np.interp(sy,[0,950,1090,H],[delta[0],delta[0],0,0]);dy=np.interp(sy,[0,950,1090,H],[delta[1],delta[1],0,0]);sx=xx-dx;sy=yy-dy
 al=map_coordinates(aa,[sy,sx],order=1,mode='constant',cval=0);rgb=np.stack([map_coordinates(az[:,:,k]*aa,[sy,sx],order=1,mode='constant',cval=0)for k in range(3)],2);rgb=np.divide(rgb,al[:,:,None],out=np.zeros_like(rgb),where=al[:,:,None]>1e-8);return np.uint8(np.clip(np.dstack((rgb,al))*255+.5,0,255))
rows=[]
for i,z in enumerate(j['frames']):
 p=z['actual_upper_rig_nodes'];t=math.radians(p['ang']);M=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]]);off=PIV+np.asarray(p['delta'])-M@PIV;a=core.astype(float)/255;alpha=a[:,:,3];w=np.clip((yy-650)/300,0,1)*np.clip((680-xx)/350,0,1);sx=xx-p['cloth']*w;sy=yy-abs(p['cloth'])*.1*w;al=map_coordinates(alpha,[sy,sx],order=1,mode='constant',cval=0);rgb=np.stack([map_coordinates(a[:,:,k]*alpha,[sy,sx],order=1,mode='constant',cval=0)for k in range(3)],2);rgb=np.divide(rgb,al[:,:,None],out=np.zeros_like(rgb),where=al[:,:,None]>1e-8);body=aff(Image.fromarray(np.uint8(np.clip(np.dstack((rgb,al))*255+.5,0,255))),M,off);body.save(D/f'phase{i}-actual-head-torso-coat-node.png')
 la=np.array([595.,950.]);delta=M@la+off-la;left=field(lnew,delta);left[1090:]=lnew[1090:];li=Image.fromarray(left);li.save(D/f'phase{i}-actual-LEFT-brace-leg-node.png')
 out=Image.new('RGBA',(W,H));out.alpha_composite(li);out.alpha_composite(Image.open(V/f'phase{i}-actual-RIGHT-weightshift-leg-node.png').convert('RGBA'))
 nodes=[]
 for n in ['LEFT-upper-arm','LEFT-forearm-hand','head-torso-coat','RIGHT-upper-arm','complete-RIGHT-staff','RIGHT-forearm-hand']:
  npth=D/f'phase{i}-actual-head-torso-coat-node.png'if n=='head-torso-coat'else U/f'phase{i}-actual-{n}-node.png';out.alpha_composite(Image.open(npth).convert('RGBA'));nodes.append(pin(npth))
 path=D/f'thunder_female-NE-attack-{i}-{p["name"]}-actual-native-v04.png';out.save(path);ar=np.array(out);c,cn=label(ar[:,:,3]>100);sizes=np.bincount(c.ravel());sizes[0]=0;small=[]
 for v in range(1,cn+1):
  if sizes[v]>=3 and v!=sizes.argmax():
   y,x=np.where(c==v);small.append({'area':int(sizes[v]),'bbox':[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]})
 old=np.array(Image.open(z['path']));rows.append({**z,'path':str(path),'sha256':pin(path)['sha256'],'strong_alpha100_components_ge200':[int(v)for v in sizes if v>=200],'smaller_alpha100_components_ge3':small,'v03_native_RGBA_changed':int(np.any(old!=ar,2).sum()),'unchanged_upper_and_Rleg_nodes':nodes,'LEFT_complete_native_foot_node_RGBA_changed':int(np.any(left[1090:]!=l[1090:],2).sum())})
j['frames']=rows;j['status']='ACTUAL_NE_ATTACK6_OWN_NATIVE_SOURCE_PENDING_INDEPENDENT_SOURCE_AND_STRIKE3_CYCLE_QC';j['prior_native_contract']=pin(P);j['actual_coat_goldtrim_layer_transfer']={'source_component_alpha100':118,'native_bbox':[531,916,554,926],'transferred_native_actual_RGBA_pixels':int(mask.sum()),'source_RGBA_changed':0,'outside_CORE_transfer_mask_RGBA_changed':int(np.any(core0[~mask]!=core[~mask],1).sum()),'outside_LEFT_transfer_mask_RGBA_changed':int(np.any(l[~mask]!=lnew[~mask],1).sum()),'restore_as_actual_COAT_not_boot':True,'core_material':pin(cp),'LEFT_calf_material':pin(lp),'semantic_mask':pin(mp)}
p=D/'NE-ATTACK6-actual-complete-native-fixed-sole-weightshift-contract-v04.json';p.write_text(json.dumps(j,indent=2)+'\n')
board=Image.new('RGB',(3*440,2*480),(72,72,75));dr=ImageDraw.Draw(board)
for i,z in enumerate(rows):
 im=Image.open(z['path']);im.thumbnail((430,450));xy=((i%3)*440,(i//3)*480+25);board.paste(im,xy,im);dr.text(((i%3)*440+5,(i//3)*480+5),z['name'],fill='white')
board.save(D/'private-NE-ATTACK6-full-native-six-one-shot-board-v04.jpg',quality=85)
print(json.dumps({'contract':pin(p),'coattrim_native_pixels':int(mask.sum()),'strong_counts':[len(z['strong_alpha100_components_ge200'])for z in rows],'detached_alpha100_ge3':[len(z['smaller_alpha100_components_ge3'])for z in rows],'RGBA_changed':[z['v03_native_RGBA_changed']for z in rows]}))
