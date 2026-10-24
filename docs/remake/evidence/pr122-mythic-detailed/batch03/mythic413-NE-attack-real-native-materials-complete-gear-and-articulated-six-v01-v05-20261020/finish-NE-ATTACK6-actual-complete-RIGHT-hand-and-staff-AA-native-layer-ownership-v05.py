from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import map_coordinates,label
import numpy as np,json,hashlib,math
B=Path(__file__).parent;V=B/'actual-NE-ATTACK6-native-rig-v04';U=B/'actual-NE-ATTACK6-upper-chain-input-v02';R=B/'actual-NE-ATTACK6-native-rig-v03';D=B/'actual-NE-ATTACK6-native-rig-v05';D.mkdir(exist_ok=False);P=V/'NE-ATTACK6-actual-complete-native-fixed-sole-weightshift-contract-v04.json';j=json.loads(P.read_text());W=H=1536;yy,xx=np.indices((H,W));PIV=np.array([716.2291666666666,705.]);core0=np.array(Image.open(V/'actual-native-body-core-original-coat-goldtrim-restored.png'));core=core0.copy();rf0=np.array(Image.open(B/'own-native-directional-materials-v04/original-actual-NE-RIGHT-forearm-hand-material.png'));rf=rf0.copy();st0=np.array(Image.open(B/'own-native-directional-materials-v04/original-actual-NE-complete-rigid-RIGHT-staff-material.png'));st=st0.copy();src=np.zeros_like(core);src[:1254,:1254]=np.array(Image.open('/workspace/scratch/mythic413-NE-walk-author-20261020-v01/NE-contact0-actual-native-background-AA-clean-r002.png').convert('RGBA'))
# Exact original native visible hand fringes and gold forecuff AA, never a
# transparent connector or hidden geometry. Same RGBA now follows its own limb.
m=(core[:,:,3]>0)&(xx>870)&(yy>480)&(yy<640)
hand=m&(xx>=960)&(yy>=520)&(yy<565);fore=m&(xx<890);pole=m&~(hand|fore)
assert np.all(src[m]==core[m]);assert int(core[pole,3].max())<=9
rf[hand|fore]=src[hand|fore];st[pole]=src[pole];core[m]=0
cp=D/'actual-native-body-core-complete-old-hand-and-pole-AA-removed.png';fp=D/'actual-native-complete-RIGHT-forearm-hand-with-original-skin-AA.png';sp=D/'actual-native-complete-rigid-RIGHT-staff-with-original-edge-AA.png';mp=D/'actual-original-old-forearm-hand-and-pole-AA-transfer-mask.png'
for p,a in [(cp,core),(fp,rf),(sp,st)]:Image.fromarray(a).save(p)
Image.fromarray(m.astype('uint8')*255).save(mp)
def pin(p):r=Path(p).read_bytes();return {'path':str(p),'sha256':hashlib.sha256(r).hexdigest(),'bytes':len(r)}
def aff(im,A,t):v=np.linalg.inv(A);q=-v@np.asarray(t);return im.transform((W,H),Image.Transform.AFFINE,tuple(v[0])+(q[0],)+tuple(v[1])+(q[1],),Image.Resampling.BICUBIC)
def bone(im,a,b,c,d):
 a,b,c,d=map(lambda v:np.asarray(v,float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);M=np.column_stack((v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]))@np.column_stack((u,[-u[1],u[0]])).T;off=c-M@a;return aff(im,M,off),M,off
rows=[]
for i,z in enumerate(j['frames']):
 p=z['actual_upper_rig_nodes'];t=math.radians(p['ang']);M=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]]);off=PIV+np.asarray(p['delta'])-M@PIV;a=core.astype(float)/255;alpha=a[:,:,3];w=np.clip((yy-650)/300,0,1)*np.clip((680-xx)/350,0,1);sx=xx-p['cloth']*w;sy=yy-abs(p['cloth'])*.1*w;al=map_coordinates(alpha,[sy,sx],order=1,mode='constant',cval=0);rgb=np.stack([map_coordinates(a[:,:,k]*alpha,[sy,sx],order=1,mode='constant',cval=0)for k in range(3)],2);rgb=np.divide(rgb,al[:,:,None],out=np.zeros_like(rgb),where=al[:,:,None]>1e-8);body=aff(Image.fromarray(np.uint8(np.clip(np.dstack((rgb,al))*255+.5,0,255))),M,off)
 near,FM,FO=bone(Image.fromarray(rf),[807,552],[903,552],p['re'],p['rw']);G=np.array([944.,536.]);grip=FM@G+FO;stt=math.radians(p['staff']);SM=np.array([[math.cos(stt),-math.sin(stt)],[math.sin(stt),math.cos(stt)]]);staff=aff(Image.fromarray(st),SM,grip-SM@G)
 body.save(D/f'phase{i}-actual-head-torso-coat-node.png');near.save(D/f'phase{i}-actual-RIGHT-complete-forearm-hand-node.png');staff.save(D/f'phase{i}-actual-complete-RIGHT-staff-node.png')
 out=Image.new('RGBA',(W,H));out.alpha_composite(Image.open(V/f'phase{i}-actual-LEFT-brace-leg-node.png').convert('RGBA'));out.alpha_composite(Image.open(R/f'phase{i}-actual-RIGHT-weightshift-leg-node.png').convert('RGBA'))
 for n in ['LEFT-upper-arm','LEFT-forearm-hand']:out.alpha_composite(Image.open(U/f'phase{i}-actual-{n}-node.png').convert('RGBA'))
 out.alpha_composite(body);out.alpha_composite(Image.open(U/f'phase{i}-actual-RIGHT-upper-arm-node.png').convert('RGBA'));out.alpha_composite(staff);out.alpha_composite(near)
 path=D/f'thunder_female-NE-attack-{i}-{p["name"]}-actual-native-v05.png';out.save(path);ar=np.array(out);c,cn=label(ar[:,:,3]>100);sz=np.bincount(c.ravel());sz[0]=0;sm=[]
 for v in range(1,cn+1):
  if sz[v]>=3 and v!=sz.argmax():
   y,x=np.where(c==v);sm.append({'area':int(sz[v]),'bbox':[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]})
 old=np.array(Image.open(z['path']));rows.append({**z,'path':str(path),'sha256':pin(path)['sha256'],'strong_alpha100_components_ge200':[int(v)for v in sz if v>=200],'smaller_alpha100_components_ge3':sm,'v04_native_RGBA_changed':int(np.any(old!=ar,2).sum()),'RIGHT_grip_same_forearm_affine_target':grip.tolist(),'RIGHT_staff_rigid_matrix':SM.tolist(),'status':'ACTUAL_COMPLETE_NEW_NE_ATTACK_SOURCE_PENDING_INDEPENDENT_QC'})
j['frames']=rows;j['prior_native_contract']=pin(P);j['actual_complete_old_hand_staff_AA_native_ownership']={'total_native_pixels':int(m.sum()),'original_skin_hand_RGBA_native_pixels':int(hand.sum()),'original_forecuff_fringe_RGBA_native_pixels':int(fore.sum()),'original_staff_AA_native_pixels':int(pole.sum()),'poleAA_maxalpha':int(core0[pole,3].max()),'source_RGBA_difference':0,'outside_transfer_mask_CORE_RGBA_changed':int(np.any(core0[~m]!=core[~m],1).sum()),'core':pin(cp),'RIGHT_forearm_hand':pin(fp),'complete_staff':pin(sp),'semantic_mask':pin(mp),'LEFT_arm_and_complete_both_sole_leg_nodes_changed':0};p=D/'NE-ATTACK6-actual-complete-native-fixed-sole-weightshift-contract-v05.json';p.write_text(json.dumps(j,indent=2)+'\n')
board=Image.new('RGB',(1320,960),(72,72,75));dr=ImageDraw.Draw(board)
for i,z in enumerate(rows):
 im=Image.open(z['path']);im.thumbnail((430,450));xy=((i%3)*440,(i//3)*480+25);board.paste(im,xy,im);dr.text(((i%3)*440+5,(i//3)*480+5),z['name'],fill='white')
board.save(D/'private-NE-ATTACK6-full-native-six-one-shot-board-v05.jpg',quality=85)
print(json.dumps({'contract':pin(p),'AA_native_transfers':[int(hand.sum()),int(fore.sum()),int(pole.sum())],'strong_counts':[len(z['strong_alpha100_components_ge200'])for z in rows],'detached_alpha100_ge3':[len(z['smaller_alpha100_components_ge3'])for z in rows],'changed_RGBA':[z['v04_native_RGBA_changed']for z in rows]}))
