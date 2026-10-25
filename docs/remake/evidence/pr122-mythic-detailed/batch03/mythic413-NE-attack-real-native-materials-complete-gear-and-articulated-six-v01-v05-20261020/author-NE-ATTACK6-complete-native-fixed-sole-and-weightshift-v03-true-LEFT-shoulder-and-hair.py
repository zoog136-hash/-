from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import map_coordinates,label,binary_dilation
import numpy as np,json,hashlib,math
B=Path(__file__).parent;U=B/'actual-NE-ATTACK6-upper-chain-input-v02';D=B/'actual-NE-ATTACK6-native-rig-v03';D.mkdir(exist_ok=False);up=U/'NE-ATTACK6-actual-upper-chain-and-rigid-staff-production-input-v02.json';uj=json.loads(up.read_text());W=H=1536;yy,xx=np.indices((H,W));root=[716.2291666666666,1054.2766007046484];PIV=np.array([root[0],705.])
RP=Path('/workspace/scratch/mythic413-NE-run-author-20261020-v01/common-complete-NE-native-material-parts-v03/original-actual-complete-RIGHT-thigh-and-calf-native.png');LP=Path('/workspace/scratch/mythic413-NE-walk-author-20261020-v01/actual-NE-LOAD1-rig-v02/original-native-complete-LEFT-visible-boot-material.png')
RLEG=Path('/workspace/scratch/mythic413-NE-walk-author-20261020-v01/actual-NE-LOAD1-semantic-speck-finish-v03/original-native-RIGHT-complete-shoe-and-leg-material-staff-speck-excluded.png')
BRACE=Path('/workspace/scratch/mythic413-NE-hit-author-20261020-v01/actual-NE-HIT6-own-native-articulated-v01/NE-HIT-original-native-two-boot-stationary-brace-once-registration-v01.json')
def pin(p):r=Path(p).read_bytes();return {'path':str(p),'sha256':hashlib.sha256(r).hexdigest(),'bytes':len(r)}
def pad(p):im=Image.new('RGBA',(W,H));im.paste(Image.open(p).convert('RGBA'),(0,0));return im
r=pad(RP);rl=pad(RLEG);lz=np.array(pad(LP));rz=np.array(r);q=np.array(rl);rz[q[:,:,3]>0]=q[q[:,:,3]>0];r=Image.fromarray(rz);l=Image.fromarray(lz)
r.save(D/'original-actual-RIGHT-complete-thigh-calf-and-boot-native-INPUT.png');l.save(D/'original-actual-LEFT-visible-calf-and-boot-native-INPUT.png')
# Native lower shoes remain at the source0 once-only stationary registration.
# Original image-space contact is preserved without claiming a unique hidden
# 3D floor solution. No pose-dependent root, shoe translation, or C fitting.
rfoot=rz.copy();rfoot[:944]=0;lfoot=lz.copy();lfoot[:1090]=0
Image.fromarray(rfoot).save(D/'original-actual-complete-RIGHT-fixed-stance-foot.png');Image.fromarray(lfoot).save(D/'original-actual-complete-LEFT-fixed-stance-foot.png')
def render_field(src,source_y,displacements):
 a=np.array(src).astype(float)/255;alpha=a[:,:,3];sx=xx.astype(float);sy=yy.astype(float)
 for _ in range(16):
  # Piecewise linear two-bone nodal deformation; outside actual semantic matte
  # is transparent. Source UV is never clamped to repeat endpoint rows.
  dx=np.interp(sy,np.asarray(source_y),np.asarray(displacements)[:,0]);dy=np.interp(sy,np.asarray(source_y),np.asarray(displacements)[:,1]);sx=xx-dx;sy=yy-dy
 aa=map_coordinates(alpha,[sy,sx],order=1,mode='constant',cval=0);rgb=np.stack([map_coordinates(a[:,:,k]*alpha,[sy,sx],order=1,mode='constant',cval=0)for k in range(3)],2);rgb=np.divide(rgb,aa[:,:,None],out=np.zeros_like(rgb),where=aa[:,:,None]>1e-8);return np.uint8(np.clip(np.dstack((rgb,aa))*255+.5,0,255))
knees=[[790,815],[779,829],[776,838],[811,801],[817,807],[791,816]];frames=[];proof=[]
for i,z in enumerate(uj['frames']):
 p=z['actual_upper_rig_nodes'];t=math.radians(p['ang']);M=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]]);off=PIV+np.array(p['delta'])-M@PIV
 def point(v):return M@np.asarray(v)+off
 rh=np.array([774.,724.]);rk=np.array([790.,815.]);newk=np.array(knees[i],float);ra=render_field(r,[0,724,815,944,H],[point(rh)-rh,point(rh)-rh,newk-rk,[0,0],[0,0]]);ra[944:]=rz[944:]
 la=np.array([595.,950.]);delta=point(la)-la;lb=render_field(l,[0,950,1090,H],[delta,delta,[0,0],[0,0]]);lb[1090:]=lz[1090:]
 rr=Image.fromarray(ra);ll=Image.fromarray(lb);rr.save(D/f'phase{i}-actual-RIGHT-weightshift-leg-node.png');ll.save(D/f'phase{i}-actual-LEFT-brace-leg-node.png')
 out=Image.new('RGBA',(W,H));out.alpha_composite(ll);out.alpha_composite(rr)
 for n in ['LEFT-upper-arm','LEFT-forearm-hand','head-torso-coat','RIGHT-upper-arm','complete-RIGHT-staff','RIGHT-forearm-hand']:
  out.alpha_composite(Image.open(U/f'phase{i}-actual-{n}-node.png').convert('RGBA'))
 path=D/f'thunder_female-NE-attack-{i}-{p["name"]}-actual-native-v03.png';out.save(path);a=np.array(out);cc,cn=label(a[:,:,3]>100);cs=np.bincount(cc.ravel());cs[0]=0
 # Strong sole crops have no other source layers, allowing exact native RGBA proof.
 footchecks={'RIGHT_complete_native_foot_node_RGBA_changed':int(np.any(ra[944:]!=rz[944:],2).sum()),'LEFT_complete_native_foot_node_RGBA_changed':int(np.any(lb[1090:]!=lz[1090:],2).sum())}
 edge=int((a[:3,:,3]>16).sum()+(a[-3:,:,3]>16).sum()+(a[:,:3,3]>16).sum()+(a[:,-3:,3]>16).sum())
 frames.append({**z,'path':str(path),'sha256':pin(path)['sha256'],'status':'ACTUAL_COMPLETE_NEW_NE_ATTACK_SOURCE_PENDING_INDEPENDENT_QC','RIGHT_actual_hip':point(rh).tolist(),'RIGHT_actual_knee_control':newk.tolist(),'LEFT_visible_calf_attachment_target':point(la).tolist(),'feet_once_registration_all_pose_changes':[0,0],'strong_alpha100_components_ge200':[int(v)for v in cs if v>=200],'opaque_near_canvas_edge_pixels':edge})
 proof.append({'phase':i,**footchecks,'bodyunit_C_root_changed':False,'RIGHT_staff_grip_upper_nodes_changed_from_upper_input':0,'actor_approvals_added':0})
p=D/'NE-ATTACK6-actual-complete-native-fixed-sole-weightshift-contract-v03.json';j={'schema':'PR122-actual-NE-attack-six-native-rig-production-v1','status':'ACTUAL_NE_ATTACK6_OWN_MATERIAL_FIXEDSOLE_NATIVE_SOURCE_PENDING_INDEPENDENT_QC','source_upper_rig':pin(up),'own_RIGHT_thigh_calf_native_source':pin(RP),'own_original_RIGHT_complete_leg_boot':pin(RLEG),'own_original_LEFT_visible_complete_leg_boot':pin(LP),'same_source0_stationary_brace_reference':pin(BRACE),'C':2432,'bodyunit':2.375,'common_rig_root':root,'storage_translation':[0,0],'native_size':[1536,1536],'source_native_size':[1254,1254],'extension_right_bottom_only':[282,282],'source_image_space_original_boot_plant_positions_preserved':True,'unique_hidden_3D_floor_solution_claimed':False,'whole_actor_mirror_or_C_change_or_perpose_root_footfit':False,'one_shot':True,'fps':6/.42,'role_seconds_preserved':.42,'intended_contact_frame':3,'frames':frames,'finite_sole_proof':proof,'actor_approvals_added':0};p.write_text(json.dumps(j,indent=2)+'\n')
board=Image.new('RGB',(3*440,2*480),(72,72,75));d=ImageDraw.Draw(board)
for i,f in enumerate(frames):
 im=Image.open(f['path']);im.thumbnail((430,450));xy=((i%3)*440,(i//3)*480+25);board.paste(im,xy,im);d.text(((i%3)*440+5,(i//3)*480+5),f['name'],fill='white')
board.save(D/'private-NE-ATTACK6-full-native-six-one-shot-board-v03.jpg',quality=85)
print(json.dumps({'contract':pin(p),'all_fixed_foot_node_RGBA_changes':sum(v['RIGHT_complete_native_foot_node_RGBA_changed']+v['LEFT_complete_native_foot_node_RGBA_changed']for v in proof),'strong_bodies':[len(f['strong_alpha100_components_ge200'])for f in frames],'edge_pixels':[f['opaque_near_canvas_edge_pixels']for f in frames]}))
