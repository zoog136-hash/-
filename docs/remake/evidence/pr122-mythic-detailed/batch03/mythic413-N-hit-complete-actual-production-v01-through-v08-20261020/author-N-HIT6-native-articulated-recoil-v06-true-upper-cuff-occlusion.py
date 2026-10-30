from pathlib import Path
from PIL import Image
from scipy.ndimage import map_coordinates,label
import numpy as np,json,hashlib,ast,math
B=Path(__file__).parent;D=B/'actual-N-HIT6-articulated-rig-v06';D.mkdir(exist_ok=False)
N=Path('/workspace/scratch/mythic413-N-walk-load-author-fresh-20261020-v01');S=N/'actual-N-skin-joint-finish-v05/N-contact0-native-skin-joint-finished-v05.png';A=B/'N-HIT-moving-LEFT-forearm-white-sleeve-bracer-hand-material-v06.png';source=Image.open(S).convert('RGBA');arm=Image.open(A).convert('RGBA');src=np.array(source);aa=np.array(arm);H,W=src.shape[:2];yy,xx=np.indices((H,W));base=src.copy();base[aa[:,:,3]>0]=0
# Native actual material; bounded longitudinal sampling is transparent outside
# the declared real forearm/hand material. No endpoint row extrapolation.
tree=ast.parse((N/'author-actual-N-LOAD1-rig-v03.py').read_text());fns=[n for n in tree.body if isinstance(n,ast.FunctionDef)];print_names=[n.name for n in fns];name='project_bone' if 'project_bone'in print_names else 'bone';
# Keep an explicit affine semantic projection here instead of importing script
# top-level mutations. Distal cap is real complete-hand semantic, not clamping.
def forearm(C,F):
 A0=np.array([556.,535.]);B0=np.array([487.,602.]);C=np.array(C,float);F=np.array(F,float);V=B0-A0;T=F-C;vl=np.linalg.norm(V);tl=np.linalg.norm(T);u=V/vl;n=np.array([-u[1],u[0]]);ut=T/tl;nt=np.array([-ut[1],ut[0]]);part=aa.copy();long=(xx-A0[0])*u[0]+(yy-A0[1])*u[1];part[(long<-12)|(long>vl+60)]=0;M=np.column_stack((ut,nt))@np.diag([tl/vl,1.])@np.column_stack((u,n)).T;off=C-M@A0;inv=np.linalg.inv(M);io=-inv@off;out=Image.fromarray(part).transform(source.size,Image.Transform.AFFINE,tuple(inv[0])+(io[0],)+tuple(inv[1])+(io[1],),Image.Resampling.BICUBIC);return out,{'C':C.tolist(),'F':F.tolist(),'matrix':M.tolist(),'offset':off.tolist(),'source_elbow':A0.tolist(),'source_wrist':B0.tolist(),'source_native_hand_semantic_cap':60,'unclamped_longitudinal_outside_real_material_transparent':True}
# Original planted native shoes stay exact. The real spine recoils, free LEFT
# forearm guards the torso, while the braced RIGHT grip/staff stays stable.
phases=[dict(name='stable_guard',head=[0,0],wrist=[505,610],cloth=[0,0]),dict(name='impact_response',head=[8,24],wrist=[465,490],cloth=[3,4]),dict(name='maximum_stagger_recoil',head=[25,44],wrist=[485,480],cloth=[9,10]),dict(name='counterbalance',head=[17,18],wrist=[470,500],cloth=[11,6]),dict(name='regaining_control',head=[3,4],wrist=[475,580],cloth=[5,3]),dict(name='recovered_guard',head=[-1,-1],wrist=[503,608],cloth=[-1,0])]
def field(x,y,head,cloth):
 # Cubic interpolation of explicit head/spine node recoil. Cranial material
 # translates as one node; spine blends to a fixed pelvis, rather than moving
 # the whole figure. Full original feet/leg shafts below y730 are unchanged.
 t=np.clip((638-y)/248,0,1);weight=t*t*(3-2*t);right=np.clip((750-x)/40,0,1);right=right*right*(3-2*right);rig=weight*right;dx=head[0]*rig;dy=head[1]*rig
 # Existing left distal blue/gold cloth responds behind the body. Keep seams,
 # coat roots and the anatomical RIGHT weapon/hand entirely fixed.
 cx=np.clip((x-370)/200,0,1);cy=np.clip((y-610)/240,0,1);lag=np.sin(np.pi*cx)**2*np.sin(np.pi*cy)**2*((x>=370)&(x<=570)&(y>=610)&(y<=850));dx=dx+cloth[0]*lag;dy=dy+cloth[1]*lag;return dx,dy
frames=[]
for i,p in enumerate(phases):
 # Invert the continuous forward native surface deformation by a fixed finite
 # 8 steps; no optimization/search or pose-dependent body-scale normalization.
 sx=xx.astype(float);sy=yy.astype(float)
 for _ in range(8):dx,dy=field(sx,sy,p['head'],p['cloth']);sx=xx-dx;sy=yy-dy
 arr=np.stack([map_coordinates(base[:,:,c],[sy,sx],order=1,mode='constant',cval=0,prefilter=False)for c in range(4)],axis=2).astype('uint8');body=Image.fromarray(arr)
 ex,ey=field(np.array(556.),np.array(535.),p['head'],p['cloth']);elbow=[556+float(ex),535+float(ey)];node,rig=forearm(elbow,p['wrist']);body.alpha_composite(node)
 # Restore exact native upper cuff cap on its transformed original pixels;
 # old forearm/hand remains erased. Smooth real AA material supplies the seam.
 original_cuff=src.copy();cap=(np.array(Image.open(B/'N-HIT-complete-actual-LEFT-forearm-hand-cuff-semantic-material-v03.png'))[:,:,3]>0)&(yy<=523);original_cuff[~cap]=0;cuff=np.stack([map_coordinates(original_cuff[:,:,c],[sy,sx],order=1,mode='constant',cval=0,prefilter=False)for c in range(4)],axis=2).astype('uint8');body.alpha_composite(Image.fromarray(cuff));out=np.array(body)
 q=D/f'N-hit-phase{i}-{p["name"]}-actual-native-v06.png';body.save(q);node.save(D/f'phase{i}-actual-LEFT-guard-arm-node.png');Image.fromarray(arr).save(D/f'phase{i}-actual-spine-cloth-body-node.png');cc,n=label(out[:,:,3]>100);sizes=np.bincount(cc.ravel());big=sorted([int(s)for s in sizes[1:]if s>=200],reverse=True)
 footROI=(yy>=730)&(xx>=570)&(xx<=735);footdiff=int(np.any(out[footROI]!=src[footROI],1).sum());staffROI=(xx>=750);staffdiff=int(np.any(out[staffROI]!=src[staffROI],1).sum());frames.append({'phase':i,'role_phase':p['name'],'path':str(q),'sha256':hashlib.sha256(q.read_bytes()).hexdigest(),'native_canvas':[W,H],'physical_C':1920,'bodyunit':1.875,'common_rig_root_in_unpadded_frame':[662.8125,917.6920531878804],'storage_translation':[0,0],'head_and_upper_spine_recoil_native':p['head'],'left_cloth_lag_native':p['cloth'],'LEFT_actual_guard_arm_rig':rig,'fixed_native_legs_and_stilettos_RGBA_changes':footdiff,'fixed_original_RIGHT_staff_and_grip_region_x750plus_RGBA_changes':staffdiff,'strong_alpha100_components_ge200':big,'actor_approval_added':0})
(D/'actual-N-HIT6-native-articulated-recoil-contract-v06.json').write_text(json.dumps({'status':'ACTUAL_DEDICATED_N_HIT6_NEW_RIG_SOURCE_PENDING_INDEPENDENT_QC','action':'hit','direction':'N','source0':{'path':str(S),'sha256':hashlib.sha256(S.read_bytes()).hexdigest()},'actual_complete_LEFT_forearm_hand':{'path':str(A),'sha256':hashlib.sha256(A.read_bytes()).hexdigest()},'role_contract':['stable guard','impact response','maximum stagger / recoil','counterbalance','regaining control','recovered guard'],'facing_anatomical_RIGHT_staff_and_grip_preserved':True,'planted_guard_dedicated_recoil_not_locomotion_attack_or_death':True,'wholeframe_translation_rotation_recolor_or_mirror':False,'perpose_C_root_footfit_alphaheight_normalization':False,'profile_or_game_timing_modified':False,'frames':frames,'actor_approval_added':0},indent=2)+'\n')
# Private finite 6-pose board; never root/user chat.
board=Image.new('RGB',(3*420,2*420),(195,202,210))
for f in frames:
 im=Image.open(f['path']).convert('RGBA');im.thumbnail((420,420));cell=Image.new('RGBA',(420,420),(195,202,210,255));cell.alpha_composite(im);board.paste(cell.convert('RGB'),((f['phase']%3)*420,(f['phase']//3)*420))
p=D/'private-N-HIT6-actual-board-v06.jpg';board.save(p,quality=83,optimize=True);assert p.stat().st_size<150000;print(json.dumps({'frames':[{'phase':f['phase'],'sha256':f['sha256'],'footdiff':f['fixed_native_legs_and_stilettos_RGBA_changes'],'staffdiff':f['fixed_original_RIGHT_staff_and_grip_region_x750plus_RGBA_changes'],'strong':f['strong_alpha100_components_ge200']}for f in frames],'private_preview_bytes':p.stat().st_size}))
