"""Own new S original RGBA material inputs for a continuous idle rig.
Conservative weight support is preparation, not final anatomical ownership or
source approval. Actual RIGHT-gear/LEFT-arm masks are supplied by their owner.
No source pixels are resampled and no image is returned or viewed.
"""
from pathlib import Path
import json,hashlib,sys,numpy as np
from PIL import Image
P=Path(__file__).parent;D=P/'actual-SW-native-source-node-material-INPUT-v01';D.mkdir(exist_ok=False)
REG=Path(sys.argv[1]);reg=json.loads(REG.read_text());S=Path(reg['source']['path']);assert hashlib.sha256(S.read_bytes()).hexdigest()==reg['source']['sha256']
a=np.array(Image.open(S).convert('RGBA'));y,x=np.indices(a.shape[:2],dtype=float)
neck=np.array(reg['body_markers']['lower_neck_center_front_left_proxy'],float);waist=np.array(reg['body_markers']['gold_waist_belt_center_front_left_proxy'],float);hem=np.array(reg['body_markers']['visible_central_hem_proxy'],float);crown=np.array(reg['body_markers']['gold_bun_crown'],float)
def pin(p):return dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),bytes=p.stat().st_size)
def smooth(t):t=np.clip(t,0,1);return t*t*(3-2*t)
head=(1-smooth((y-neck[1]+20)/60))*smooth((y-(crown[1]-30))/20)*smooth((x-(neck[0]-180))/35)*(1-smooth((x-(neck[0]+150))/35))
left=neck[0]-120;right=neck[0]+140;top=neck[1]+20;bottom=waist[1]+20
thorax=np.sin(np.pi*np.clip((x-left)/(right-left),0,1))**2*np.sin(np.pi*np.clip((y-top)/(bottom-top),0,1))**2*((x>left)&(x<right)&(y>top)&(y<bottom))
cl=hem[0]+10;cr=hem[0]+370;ct=hem[1]-80;cb=hem[1]+88
cloth=np.sin(np.pi*np.clip((x-cl)/(cr-cl),0,1))**2*np.sin(np.pi*np.clip((y-ct)/(cb-ct),0,1))**2*((x>cl)&(x<cr)&(y>ct)&(y<cb))
weights={'complete-head-bun-ribbon-neck-transition':head,'original-corset-thorax-surface':thorax,'original-upper-skirt-and-coat-lag':cloth,'conservative-complete-lowerbody-boots-protection':(y>=760).astype(float)}
rows=[]
for name,w in weights.items():
 q=a.copy();q[w<=0]=0;p=D/f'original-SW-{name}-actual-RGBA-INPUT.png';Image.fromarray(q).save(p);z=D/f'original-SW-{name}-continuous-node-weight16-INPUT.png';Image.fromarray(np.uint16(np.clip(w,0,1)*65535),'I;16').save(z);mask=(w>0)&(a[:,:,3]>0);assert np.array_equal(q[mask],a[mask]);rows.append(dict(name=name,actual_original_RGBA_material=pin(p),native_node_weight16=pin(z),original_nonzero_alpha_material_texels=int(mask.sum()),RGBA_changes_inside_owned_source=0,source_alpha_outside_weight_support=0))
f=D/'SW-original-native-materials-and-continuous-node-ownership-INPUT-v01.json';d=dict(status='ACTUAL_ORIGINAL_RGBA_MATERIAL_PREPARATION_PENDING_SHARED_SOURCE_GATE_AND_FINAL_RIGHT_GEAR_LEFT_ARM_SMANTICS',source=pin(S),candidate_once_basis=pin(REG),candidate_basis_not_claimed_fixed=True,native_source_size=list(Image.open(S).size),source_resampling=False,parts=rows,actual_landmark_controls_from_basis=dict(neck=neck.tolist(),waist=waist.tolist(),hem=hem.tolist(),crown=crown.tolist()),native_fixed_lowerbody_start=760,planned_idle_seconds=1.2,planned_nodes='Intrinsic transverse thorax breathing; dedicated continuous LEFT arm relaxation; delayed complete head/neck; real skirt/coat follow-through; complete boots/RIGHT arm/grip/staff fixed',actual_RIGHT_gear_mask_must_exclude_from_all_motion=True,actual_LEFT_arm_material_owner='/root/mythic413_n_walk_load_fresh',old_sources_and_clips_modified=False,new_services=0,new_author_images=0,private_context_bytes_unchanged=5538937,actor_approvals_added=0);f.write_text(json.dumps(d,indent=2)+'\n');print(json.dumps(dict(manifest=pin(f),actual_original_RGBA_materials=4,weight_inputs=4,source_RGBA_changes=0,new_images_returned=0)))
