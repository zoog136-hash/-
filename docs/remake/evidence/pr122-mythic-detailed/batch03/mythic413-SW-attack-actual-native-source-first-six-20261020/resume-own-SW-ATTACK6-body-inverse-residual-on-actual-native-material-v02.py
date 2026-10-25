from pathlib import Path
from PIL import Image
from scipy.ndimage import map_coordinates,label
import numpy as np,json,hashlib,math
B=Path(__file__).parent;D=B/'actual-SW-ATTACK6-native-articulated-rig-v01';D.mkdir(exist_ok=True)
P=B/'native-source-parts-v01/SW-exact-own-native-semantic-parts-and-rig-controls-v01.json';j=json.loads(P.read_text());REG=Path('/workspace/scratch/mythic413-SW-hit-author-20261020-v01/SW-new-native-one-time-body-density-C2496-root-registration-v02.json');reg=json.loads(REG.read_text());ROOT=reg['common_rig_root_in_unpadded_frame'];C=reg['new_SW_fixed_C'];UNIT=reg['new_SW_fixed_bodyunit'];PAD=np.array([384,128]);SIZE=1792;H=W=1254;yy,xx=np.indices((SIZE,SIZE));worldx=xx-PAD[0];worldy=yy-PAD[1];ledger=B/'private-image-byte-ledger-v01.jsonl'
def pin(p):
 p=Path(p);b=p.read_bytes();return dict(path=str(p),bytes=len(b),sha256=hashlib.sha256(b).hexdigest())
def save_result(im,path,role):
 im.save(path,lossless=True,exact=True,method=6);q=pin(path);rows=[json.loads(s)for s in ledger.read_text().splitlines()];total=rows[-1]['cumulative_bytes']+q['bytes'];assert total<=6000000,(role,total)
 with ledger.open('a')as f:f.write(json.dumps(dict(sequence=len(rows)+1,role=role,**q,cumulative_bytes=total))+'\n')
 assert np.array_equal(np.array(Image.open(path).convert('RGBA')),np.array(im));return q
parts={}
for name,r in j['parts'].items():
 a=np.zeros((H,W,4),np.uint8);x0,y0,x1,y1=r['native_crop_box'];a[y0:y1,x0:x1]=np.array(Image.open(r['path']).convert('RGBA'));parts[name]=a
core=np.zeros((H,W,4),np.uint8)
for n in ['BODY-own-chest-waist-ribbons','HEAD-own-hair-face-crown','NECK-own-skin-collar-gems','COAT-own-native-UV-tails']:core+=parts[n]
def smooth(v):v=np.clip(v,0,1);return v*v*(3-2*v)
def rot(deg):a=math.radians(deg);return np.array([[math.cos(a),-math.sin(a)],[math.sin(a),math.cos(a)]])
ctl=j['controls'];SR=np.array(ctl['RIGHT_shoulder']);ER=np.array(ctl['RIGHT_elbow']);WR=np.array(ctl['RIGHT_wrist']);G=np.array(ctl['RIGHT_grip']);SL=np.array(ctl['LEFT_shoulder']);EL=np.array(ctl['LEFT_elbow']);WL=np.array(ctl['LEFT_wrist']);PIV=np.array([655.,539.]);NECK=np.array([628.,331.])
phases=[dict(role='READY',torso=[0,0],body_deg=0,head_deg=0,upper_deg=0,fore_deg=0,left_upper=0,left_fore=0,cloth=[0,0],ribbon=[0,0]),dict(role='LOAD',torso=[6,4],body_deg=1,head_deg=-1,upper_deg=-15,fore_deg=28,left_upper=5,left_fore=-18,cloth=[3,1],ribbon=[2,1]),dict(role='WINDUP',torso=[10,7],body_deg=2,head_deg=-2,upper_deg=-27,fore_deg=48,left_upper=8,left_fore=-32,cloth=[8,3],ribbon=[4,2]),dict(role='STRIKE',torso=[-10,-7],body_deg=-2,head_deg=2,upper_deg=25,fore_deg=-80,left_upper=-10,left_fore=-58,cloth=[-6,-2],ribbon=[-5,-1]),dict(role='FOLLOW',torso=[-15,-5],body_deg=-3,head_deg=3,upper_deg=32,fore_deg=-96,left_upper=-15,left_fore=-48,cloth=[-13,1],ribbon=[-9,-2]),dict(role='RECOVER',torso=[1,1],body_deg=.2,head_deg=.3,upper_deg=-3,fore_deg=-8,left_upper=2,left_fore=-5,cloth=[-4,1],ribbon=[-2,0])]
def field(x,y,p):
 weight=smooth((650-y)/300);a=math.radians(p['body_deg']);px=x-PIV[0];py=y-PIV[1];dx=((math.cos(a)-1)*px-math.sin(a)*py+p['torso'][0])*weight;dy=(math.sin(a)*px+(math.cos(a)-1)*py+p['torso'][1])*weight
 headweight=smooth((355-y)/55);a=math.radians(p['head_deg']);px=x-NECK[0];py=y-NECK[1];dx+=((math.cos(a)-1)*px-math.sin(a)*py)*headweight;dy+=(math.sin(a)*px+(math.cos(a)-1)*py)*headweight
 # Native cloth UVs lag at both outer tails; anatomical legs/full boots are a separate fixed node.
 clothweight=smooth((y-610)/230)*smooth((1020-y)/80)*(1-smooth((x-425)/70)) + smooth((y-610)/230)*smooth((1020-y)/80)*smooth((x-850)/100)
 dx+=p['cloth'][0]*clothweight;dy+=p['cloth'][1]*clothweight
 ribbon=np.sin(np.pi*np.clip((x-700)/180,0,1))**2*np.sin(np.pi*np.clip((y-180)/340,0,1))**2
 ribbon*=((x>700)&(x<880)&(y>180)&(y<520));dx+=p['ribbon'][0]*ribbon;dy+=p['ribbon'][1]*ribbon
 return dx,dy
def bodypoint(v,p):x,y=v;dx,dy=field(np.asarray(x),np.asarray(y),p);return np.array([x+dx,y+dy])
def sampled(a,sx,sy):
 af=a.astype(np.float32)/255;alpha=af[:,:,3];outalpha=map_coordinates(alpha,[sy,sx],order=1,mode='constant',cval=0,prefilter=False);rgb=np.stack([map_coordinates(af[:,:,k]*alpha,[sy,sx],order=1,mode='constant',cval=0,prefilter=False)for k in range(3)],2);rgb=np.divide(rgb,outalpha[:,:,None],out=np.zeros_like(rgb),where=outalpha[:,:,None]>1e-8);out=np.uint8(np.clip(np.dstack((rgb,outalpha))*255+.5,0,255));return Image.fromarray(out)
def affine(a,M,o):
 inv=np.linalg.inv(M);o=np.array(o);sx=inv[0,0]*(worldx-o[0])+inv[0,1]*(worldy-o[1]);sy=inv[1,0]*(worldx-o[0])+inv[1,1]*(worldy-o[1]);return sampled(a,sx,sy)
def bend(a,U,uo,F,fo,elbow,tangent):
 # Smooth source-material elbow bend, exact continuous projected joint maps.
 def forward(x,y):
  s=((x-elbow[0])*tangent[0]+(y-elbow[1])*tangent[1]);z=smooth((s+18)/36);ux=U[0,0]*x+U[0,1]*y+uo[0];uy=U[1,0]*x+U[1,1]*y+uo[1];fx=F[0,0]*x+F[0,1]*y+fo[0];fy=F[1,0]*x+F[1,1]*y+fo[1];return ux*(1-z)+fx*z,uy*(1-z)+fy*z
 inv=np.linalg.inv(F);sx=inv[0,0]*(worldx-fo[0])+inv[0,1]*(worldy-fo[1]);sy=inv[1,0]*(worldx-fo[0])+inv[1,1]*(worldy-fo[1])
 for _ in range(12):
  fx,fy=forward(sx,sy);ex,ey=forward(sx+.01,sy);hx,hy=forward(sx,sy+.01);j00=(ex-fx)/.01;j10=(ey-fy)/.01;j01=(hx-fx)/.01;j11=(hy-fy)/.01;det=j00*j11-j01*j10;det=np.where(abs(det)<.01,.01,det);rx=fx-worldx;ry=fy-worldy;dx=(j11*rx-j01*ry)/det;dy=(-j10*rx+j00*ry)/det;damping=np.minimum(1,20/np.maximum(np.maximum(abs(dx),abs(dy)),1e-7));sx-=dx*damping;sy-=dy*damping
 return sampled(a,sx,sy)
records=[]
for i,p in enumerate(phases):
 sx=worldx.astype(float);sy=worldy.astype(float)
 for _ in range(18):dx,dy=field(sx,sy,p);sx=worldx-dx;sy=worldy-dy
 dx,dy=field(sx,sy,p);support=map_coordinates(core[:,:,3],[sy,sx],order=0,mode='constant',cval=0,prefilter=False)>0;res=float(max(np.max(abs(sx+dx-worldx)[support]),np.max(abs(sy+dy-worldy)[support])));assert res<.0001,res
 body=sampled(core,sx,sy)
 rshoulder=bodypoint(SR,p);RU=rot(p['body_deg']+p['upper_deg']);ruo=rshoulder-RU@SR;relbow=RU@ER+ruo;RF=rot(p['fore_deg']);rfo=relbow-RF@ER;rgrip=RF@G+rfo
 lshoulder=bodypoint(SL,p);LU=rot(p['body_deg']+p['left_upper']);luo=lshoulder-LU@SL;lelbow=LU@EL+luo;LF=rot(p['left_fore']);lfo=lelbow-LF@EL
 # Staff, complete fingers/cuff, and puff retain identical forearm rigid matrix.
 layers=[('LEFT-full-upper-arm',affine(parts['LEFT-full-upper-arm'],LU,luo)),('LEFT-complete-curved-cuff-forearm-free-fingers',bend(parts['LEFT-complete-curved-cuff-forearm-free-fingers'],LU,luo,LF,lfo,EL,(WL-EL)/np.linalg.norm(WL-EL))),('BODY-HEAD-NECK-COAT-native-material',body),('LEGS-original-full-boots-fixed',affine(parts['LEGS-original-full-boots-fixed'],np.eye(2),[0,0])),('RIGHT-full-upper-arm-and-shoulder',affine(parts['RIGHT-full-upper-arm-and-shoulder'],RU,ruo)),('complete-rigid-RIGHT-staff',affine(parts['complete-rigid-RIGHT-staff'],RF,rfo)),('RIGHT-white-puff-elbow',affine(parts['RIGHT-white-puff-elbow'],RF,rfo)),('RIGHT-complete-forearm-cuff-grip-fingers',affine(parts['RIGHT-complete-forearm-cuff-grip-fingers'],RF,rfo))]
 out=Image.new('RGBA',(SIZE,SIZE))
 for name,im in layers:out.alpha_composite(im)
 # Actual fixed original full boots are copied losslessly; no alpha box or foot fit enters rigging.
 ar=np.array(out);foot=parts['LEGS-original-full-boots-fixed'];sel=foot[:,:,3]>0;view=ar[PAD[1]:PAD[1]+H,PAD[0]:PAD[0]+W];view[sel]=foot[sel];out=Image.fromarray(ar)
 q=D/f'thunder_female-SW-attack-{i}-{p["role"]}-actual-native-v01.webp';qpin=pin(q) if q.exists() else save_result(out,q,'actual-native-SW-ATTACK-frame');assert np.array_equal(np.array(Image.open(q).convert('RGBA')),np.array(out))
 lab,n=label(ar[:,:,3]>100);sizes=np.bincount(lab.ravel());edge=int((ar[:3,:,3]>16).sum()+(ar[-3:,:,3]>16).sum()+(ar[:,:3,3]>16).sum()+(ar[:,-3:,3]>16).sum());assert edge==0
 records.append(dict(phase=i,role=p['role'],source=qpin,native_canvas=[SIZE,SIZE],C=C,bodyunit=UNIT,common_rig_root_unpadded=ROOT,storage_translation=PAD.tolist(),stored_common_root=(np.array(ROOT)+PAD).tolist(),actual_phase_parameters=p,RIGHT_shoulder=rshoulder.tolist(),RIGHT_elbow=relbow.tolist(),RIGHT_wrist=(RF@WR+rfo).tolist(),RIGHT_actual_grip=rgrip.tolist(),RIGHT_upper_matrix=RU.tolist(),RIGHT_upper_offset=ruo.tolist(),RIGHT_forearm_puff_fullstaff_identical_rigid_matrix=RF.tolist(),RIGHT_forearm_puff_fullstaff_identical_offset=rfo.tolist(),RIGHT_staff_Gram_maximum_error=float(np.max(abs(RF.T@RF-np.eye(2)))),LEFT_shoulder=lshoulder.tolist(),LEFT_elbow=lelbow.tolist(),LEFT_wrist=(LF@WL+lfo).tolist(),LEFT_upper_matrix=LU.tolist(),LEFT_upper_offset=luo.tolist(),LEFT_forearm_matrix=LF.tolist(),LEFT_forearm_offset=lfo.tolist(),LEFT_source_visible_proximal_cuff_is_not_shoulder=True,actual_composition_nodes=[n for n,_ in layers],native_full_legs_boots_RGBA_changed=0,body_inverse_residual=res,alpha16_storage_edge_pixels=edge,strong_alpha100_components_ge200=sorted([int(v)for v in sizes[1:]if v>=200],reverse=True),status='ACTUAL_NATIVE_SW_ATTACK_POSE_PENDING_INDEPENDENT_SOURCE_QC'))
 print(json.dumps(dict(phase=i,bytes=qpin['bytes'],sha256=qpin['sha256'],components=records[-1]['strong_alpha100_components_ge200'],ledger=json.loads(ledger.read_text().splitlines()[-1])['cumulative_bytes'])),flush=True)
contract=dict(schema='MYTHIC413_SW_ATTACK6_ACTUAL_OWN_NATIVE_ARTICULATED_V01',status='ACTUAL_SW_ATTACK6_PENDING_INDEPENDENT_SOURCE_AND_ONE_SHOT_REVIEW',direction='SW',action='attack',source=j['source'],exact_once_registration=pin(REG),exact_native_parts_contract=pin(P),C=C,bodyunit=UNIT,common_rig_root_unpadded=ROOT,storage_translation=PAD.tolist(),storage_translation_inverse=(-PAD).tolist(),storage_padding_is_common_integer_only=True,native_canvas=[SIZE,SIZE],source_native_canvas=[W,H],role_seconds=.42,phase_seconds=.42/6,contact_phase=3,loop=False,phases=['READY','LOAD','WINDUP','STRIKE','FOLLOW','RECOVER'],frames=records,native_source_recolored_resized_mirrored=False,perpose_C_root_alpha_bbox_or_footfit=False,body_basis_direction_scope='Original stationary shallow SW front-left brace, source near boot turnout preserved; no SW RUN or WALK direction approval',actual_hidden_material_generated=False,actor_approvals_added=0)
f=D/'SW-ATTACK6-actual-native-fixed-registration-and-separate-rig-contract-v01.json';f.write_text(json.dumps(contract,indent=2)+'\n');print(json.dumps(dict(contract=pin(f),ledger_bytes=json.loads(ledger.read_text().splitlines()[-1])['cumulative_bytes'])))
