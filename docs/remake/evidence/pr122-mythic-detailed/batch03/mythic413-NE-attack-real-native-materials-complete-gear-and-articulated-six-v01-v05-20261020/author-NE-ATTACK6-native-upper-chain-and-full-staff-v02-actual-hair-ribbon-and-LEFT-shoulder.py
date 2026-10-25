from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import map_coordinates,label
import numpy as np,json,hashlib,math
B=Path(__file__).parent;D=B/'actual-NE-ATTACK6-upper-chain-input-v02';D.mkdir(exist_ok=False);P=B/'own-native-directional-materials-v04/NE-ATTACK-native-own-material-input-and-controls-v04.json';j=json.loads(P.read_text());W=H=1536;yy,xx=np.indices((H,W));parts={k:Image.open(v['path']).convert('RGBA') for k,v in j['parts'].items()};core=Image.open(j['body_core']['path']).convert('RGBA');controls=j['actual_native_controls']
SR=np.array(controls['RIGHT_shoulder'],float);ER=np.array(controls['RIGHT_cuff_hinge'],float);WR=np.array(controls['RIGHT_wrist'],float);G=np.array(controls['RIGHT_grip'],float);SL=np.array([611.,483.]);EL=np.array(controls['LEFT_elbow'],float);WL=np.array(controls['LEFT_wrist'],float);PIV=np.array([716.2291666666666,705.]);root=[716.2291666666666,1054.2766007046484]
def pin(p):r=Path(p).read_bytes();return {'path':str(p),'sha256':hashlib.sha256(r).hexdigest(),'bytes':len(r)}
def aff(im,A,t):v=np.linalg.inv(A);q=-v@np.asarray(t);return im.transform((W,H),Image.Transform.AFFINE,tuple(v[0])+(q[0],)+tuple(v[1])+(q[1],),Image.Resampling.BICUBIC)
def bone(im,a,b,c,d):
 a,b,c,d=map(lambda v:np.asarray(v,float),(a,b,c,d));u=(b-a)/np.linalg.norm(b-a);v=(d-c)/np.linalg.norm(d-c);M=np.column_stack((v*np.linalg.norm(d-c)/np.linalg.norm(b-a),[-v[1],v[0]]))@np.column_stack((u,[-u[1],u[0]])).T;off=c-M@a;return aff(im,M,off),M,off
phases=[dict(name='READY',ang=0,delta=[0,0],re=[807,552],rw=[903,552],le=[559,550],lw=[481,645],staff=0,cloth=0),dict(name='WINDUP',ang=-3,delta=[-6,7],re=[748,564],rw=[828,510],le=[551,561],lw=[555,685],staff=-23,cloth=7),dict(name='COIL',ang=-6,delta=[-10,13],re=[731,571],rw=[810,516],le=[551,572],lw=[576,693],staff=-30,cloth=13),dict(name='STRIKE3',ang=6,delta=[17,-10],re=[901,418],rw=[994,393],le=[585,530],lw=[503,618],staff=65,cloth=-8),dict(name='FOLLOW',ang=8,delta=[26,-3],re=[909,443],rw=[1006,440],le=[595,533],lw=[510,621],staff=82,cloth=-17),dict(name='RECOVER',ang=0,delta=[0,0],re=[809,551],rw=[905,552],le=[560,551],lw=[483,646],staff=3,cloth=-3)]
records=[]
for i,p in enumerate(phases):
 t=math.radians(p['ang']);M=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]]);off=PIV+np.array(p['delta'])-M@PIV
 def point(v):return M@np.asarray(v)+off
 a=np.array(core).astype(float)/255;al=a[:,:,3];w=np.clip((yy-650)/300,0,1)*np.clip((680-xx)/350,0,1);sx=xx-p['cloth']*w;sy=yy-abs(p['cloth'])*.1*w;aa=map_coordinates(al,[sy,sx],order=1,mode='constant',cval=0);rgb=np.stack([map_coordinates(a[:,:,k]*al,[sy,sx],order=1,mode='constant',cval=0)for k in range(3)],2);rgb=np.divide(rgb,aa[:,:,None],out=np.zeros_like(rgb),where=aa[:,:,None]>1e-8);cloth=Image.fromarray(np.uint8(np.clip(np.dstack((rgb,aa))*255+.5,0,255)));body=aff(cloth,M,off)
 ru,UM,Uoff=bone(parts['RIGHT-upper-arm'],SR,ER,point(SR),p['re']);rf,FM,Foff=bone(parts['RIGHT-forearm-hand'],ER,WR,p['re'],p['rw']);grip=FM@G+Foff;st=math.radians(p['staff']);SM=np.array([[math.cos(st),-math.sin(st)],[math.sin(st),math.cos(st)]]);staff=aff(parts['complete-rigid-RIGHT-staff'],SM,grip-SM@G)
 lu,_,_=bone(parts['LEFT-upper-arm'],SL,EL,point(SL),p['le']);lf,_,_=bone(parts['LEFT-complete-cuff-forearm-hand'],EL,WL,p['le'],p['lw'])
 # Dedicated NE near/far occlusion order. Real legs are not part of this
 # intermediate INPUT; final full6 will add a separately registered brace rig.
 out=Image.new('RGBA',(W,H))
 for n,im in [('LEFT-upper-arm',lu),('LEFT-forearm-hand',lf),('head-torso-coat',body),('RIGHT-upper-arm',ru),('complete-RIGHT-staff',staff),('RIGHT-forearm-hand',rf)]:
  im.save(D/f'phase{i}-actual-{n}-node.png');out.alpha_composite(im)
 q=D/f'NE-attack-{i}-{p["name"]}-actual-upper-chain-ONLY-INPUT-v02.png';out.save(q);ar=np.array(out);c,n=label(ar[:,:,3]>100);sizes=np.bincount(c.ravel())[1:]
 records.append({'phase':i,'name':p['name'],'path':str(q),'sha256':pin(q)['sha256'],'actual_upper_rig_nodes':p,'physical_C':2432,'bodyunit':2.375,'common_rig_root_in_unpadded_frame':root,'storage_translation':[0,0],'native_size':[1536,1536],'RIGHT_grip_same_forearm_affine_target':grip.tolist(),'RIGHT_staff_rigid_matrix':SM.tolist(),'RIGHT_staff_orthogonality_error':float(np.max(abs(SM.T@SM-np.eye(2)))),'RIGHT_staff_actual_top_tip_target':(SM@np.array([975.,72.])+grip-SM@G).tolist(),'strong_upper_components_ge200':[int(v) for v in sizes if v>=200],'status':'UPPER_CHAIN_ONLY_INPUT_LEGS_AND_FULL_SOURCE_QC_PENDING'})
jj={'schema':'PR122-actual-NE-attack-six-upper-chain-production-input-v1','status':'ACTUAL_NEW_NE_ATTACK_UPPER_CHAIN6_INPUT_PENDING_LEGS_SOURCE_AND_STRIKE3_QC','own_native_materials':pin(P),'C':2432,'bodyunit':2.375,'common_rig_root':root,'whole_actor_mirrored_or_C_changed':False,'one_shot':True,'fps':6/.42,'role_seconds_preserved':.42,'intended_contact_frame':3,'frames':records,'game_binding_or_actor_approvals_added':0}
p=D/'NE-ATTACK6-actual-upper-chain-and-rigid-staff-production-input-v02.json';p.write_text(json.dumps(jj,indent=2)+'\n');print(json.dumps({'contract':pin(p),'actual_upper_phases':6,'full_source_approvals':0}))
board=Image.new('RGB',(3*440,2*480),(72,72,75));d=ImageDraw.Draw(board)
for i,r in enumerate(records):
 im=Image.open(r['path']);im.thumbnail((430,450));xy=((i%3)*440,(i//3)*480+25);board.paste(im,xy,im);d.text(((i%3)*440+5,(i//3)*480+5),r['name']+' UPPER INPUT',fill='white')
board.save(D/'private-NE-ATTACK6-dedicated-upper-chain-INPUT-board-v02.jpg',quality=83)
